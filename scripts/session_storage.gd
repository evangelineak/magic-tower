class_name TowerSessionStorage
extends RefCounted
## Unified async adapter for registered full Worlds; no legacy-slot imports.
const World=preload("res://scripts/world.gd")
const Profile=preload("res://scripts/legacy_profile.gd")
const Native=preload("res://scripts/journey_store_native.gd")
signal web_reply
var owner:String=Crypto.new().generate_random_bytes(16).hex_encode()
var auth:Dictionary={}
var native
var web_bridge
var web_callback
var web_pending:Dictionary={}
var serial:=0
var ready:=false
var use_web:=false
var path:String
var test_drop_next_ack:=false
var web_timeout_seconds:=12.0
func _init(test_path:String=""):
 path="user://journeys-v1" if test_path=="" else test_path
 use_web=OS.has_feature("web") and test_path==""
 if not use_web:native=Native.new(path)
func _result(ok:bool,status:String,reason:String="",snapshot:Dictionary={},slot:int=0,revision:int=0)->Dictionary:
 return {"ok":ok,"status":status,"reason":reason,"snapshot":snapshot.duplicate(true),"run_id":str(snapshot.get("run_id","")),"slot":slot,"revision":revision,"eligible":ok and snapshot.get("run_id","")!="" and status=="active","retryable":false,"readonly":not ok or status!="active"}
func _failure(code:String)->Dictionary:
 var retryable=code in ["AMBIGUOUS_COMMIT","WRITE_FAILED","RENAME_FAILED","BACKUP_FAILED","STORE_LOCKED","INJECTED_AFTER_PROFILE","INJECTED_AFTER_ARCHIVE","INJECTED_AFTER_SLOT","INJECTED_BEFORE_TEMP","INJECTED_AFTER_TEMP","INJECTED_BEFORE_RENAME","WEB_IO","WEB_TIMEOUT","ACK_LOST","AbortError","UnknownError"]
 var conflict=code in ["WRITER_BUSY","STALE_WRITER","STALE_SLOT_REVISION","STALE_REVISION","NOT_ACTIVE_RUN","SUPERSEDED_OPERATION","REQUEST_CONFLICT","ACTIVE_RUN_EXISTS","ID_COLLISION"]
 var result=_result(false,"io_error" if retryable else ("conflict" if conflict else "invalid"),code)
 result.retryable=retryable;result.readonly=not retryable
 return result
func _on_web_reply(arguments:Array):
 if arguments.size()!=1:return
 var parsed=JSON.parse_string(str(arguments[0]))
 if not parsed is Dictionary or not parsed.has("request"):return
 var request=int(parsed.request)
 if not web_pending.has(request) or not web_pending[request].get("waiting",false):return
 web_pending[request]=parsed.get("result",{"ok":false,"code":"WEB_IO"})
 web_reply.emit()
func _web(operation:String,args:Dictionary)->Dictionary:
 serial+=1;var id=serial
 web_pending[id]={"waiting":true}
 var timer=Engine.get_main_loop().create_timer(web_timeout_seconds)
 timer.timeout.connect(func():
  if web_pending.has(id) and web_pending[id].get("waiting",false):
   web_pending[id]={"ok":false,"code":"WEB_TIMEOUT"};web_reply.emit()
 ,CONNECT_ONE_SHOT)
 web_bridge.request(JSON.stringify({"request":id,"operation":operation,"args":args}),web_callback)
 while web_pending.has(id) and web_pending[id].get("waiting",false):await web_reply
 var result:Dictionary=web_pending[id];web_pending.erase(id);return result
func _initialize_store()->Dictionary:
 if ready:return {"ok":true}
 if use_web:
  var source=FileAccess.get_file_as_string("res://scripts/profile_storage_web.js")
  if source=="":return {"ok":false,"code":"WEB_SCRIPT_MISSING"}
  JavaScriptBridge.eval(source,true)
  web_bridge=JavaScriptBridge.get_interface("MagicTowerJourneys")
  if web_bridge==null:return {"ok":false,"code":"WEB_BRIDGE_MISSING"}
  web_callback=JavaScriptBridge.create_callback(_on_web_reply)
  var response=await _web("open",{})
  ready=response.get("ok",false);return response
 var initialized:Dictionary=native.initialize();ready=initialized.get("ok",false);return initialized
func _claim(explicit:bool=false,for_write:bool=false)->Dictionary:
 var initialized=await _initialize_store()
 if not initialized.get("ok",false):return initialized
 if not auth.is_empty() and not explicit:
  if for_write:return {"ok":true,"auth":auth}
  var remaining=int(auth.get("leaseUntil",0))-int(Time.get_unix_time_from_system()*1000.0)
  if remaining<=0:return {"ok":false,"code":"STALE_WRITER"}
  if remaining<20000:
   var renewed:Dictionary=await _web("renew",{"auth":auth,"lease_ms":60000}) if use_web else native.renewWriter(auth,60000)
   if not renewed.get("ok",false):return renewed
   auth=renewed.auth.duplicate(true)
  return {"ok":true,"auth":auth}
 var result:Dictionary=await _web("claim",{"owner":owner,"lease_ms":60000}) if use_web else native.claimWriter(owner,60000)
 if result.get("ok",false):auth=result.auth.duplicate(true)
 return result
func _canonical(snapshot:Dictionary,allow_ended:bool=false)->Dictionary:
 if snapshot.get("mode") not in ["safe","risk"] or (not allow_ended and snapshot.get("ended_reason")!=""):return {}
 var probe=World.from_snapshot(snapshot)
 return {} if probe==null else probe.save_data().duplicate(true)
func _normalize(raw:Dictionary)->Dictionary:
 if not raw.get("ok",false):return _failure(str(raw.get("code","WEB_IO")))
 var run=raw.get("run")
 if run==null:
  var empty=_result(false,"empty");empty.readonly=false;return empty
 if not run is Dictionary or not run.get("snapshot") is Dictionary:return _failure("INVALID_RESPONSE")
 var snapshot=_canonical(run.snapshot,run.get("status")=="archived")
 if snapshot.is_empty() or snapshot.run_id!=run.get("id") or snapshot.run_id=="":return _failure("INVALID_RESPONSE")
 var status="active" if run.get("status")=="active" else "archived"
 var slot:int=int(raw.get("slotRevision",0))
 var result=_result(true,status,"",snapshot,slot,int(run.get("revision",0)))
 var ledger=raw.get("profile",{})
 if not Profile.validate(ledger).ok:return _failure("INVALID_PROFILE")
 if status=="active" and ledger.receipts.has(snapshot.run_id):return _failure("INVALID_RECEIPT")
 result.profile=ledger.duplicate(true)
 if status=="archived":
  var profile=raw.get("profile",{});var receipt=raw.get("receipt",{})
  if not Profile.validate(profile).ok or profile.receipts.get(snapshot.run_id)!=receipt:return _failure("INVALID_RECEIPT")
  var probe=World.from_snapshot(snapshot)
  var summary=probe.settlement_summary(str(receipt.get("summary",{}).get("outcome","")))
  if not summary.get("ok",false) or summary.summary!=Profile._summary(receipt.get("summary")):return _failure("INVALID_RECEIPT")
  result.receipt=receipt.duplicate(true);result.profile=profile.duplicate(true);result.eligible=true
 if status in ["active","archived"]:
  auth.expectedSlotRevision=slot
  if raw.has("leaseUntil"):auth.leaseUntil=raw.leaseUntil
 return result
func _read_raw()->Dictionary:
 if use_web:return await _web("read",{})
 var response:Dictionary=native.read()
 if not response.ok:return response
 var data:Dictionary=response.data;var id=data.slot.activeRunId
 return {"ok":true,"run":data.runs.get(id) if id!=null else null,"slotRevision":data.slot.revision,"profile":data.profile.profile,"receipt":data.profile.profile.receipts.get(id,{})}
func read_active()->Dictionary:
 var claim=await _claim()
 if not claim.get("ok",false):return _failure(str(claim.get("code","WEB_IO")))
 return _normalize(await _read_raw())
func reacquire_and_read()->Dictionary:
 auth.clear()
 var claim=await _claim(true)
 if not claim.get("ok",false):return _failure(str(claim.get("code","WEB_IO")))
 return _normalize(await _read_raw())
func create_run(seed:int,layout:int=2,mode:String="safe",replace_active:bool=false,request_id:String="")->Dictionary:
 if not World.valid_run_id(request_id) or request_id=="":return _failure("INVALID_REQUEST_ID")
 if mode not in ["safe","risk"] or seed<0 or seed>2147483647 or layout not in [1,2]:return _failure("INVALID_NEW_RUN")
 var claim=await _claim(false,true)
 if not claim.get("ok",false):return _failure(str(claim.get("code","WEB_IO")))
 var fresh=World.new(seed,layout,request_id,mode)
 if not fresh.generation_valid:return _failure("INVALID_NEW_RUN")
 var snapshot=fresh.save_data()
 var raw:Dictionary=await _web("create",{"auth":auth,"snapshot":snapshot,"replace":replace_active,"request_id":request_id}) if use_web else native.create_journey(auth,snapshot,replace_active,request_id)
 if raw.get("ok",false) and test_drop_next_ack:test_drop_next_ack=false;return _failure("ACK_LOST")
 return _normalize(raw)
func commit_run(expected_slot:int,expected_revision:int,run_id:String,snapshot:Dictionary,request_id:String="")->Dictionary:
 if not World.valid_run_id(request_id) or request_id=="":return _failure("INVALID_REQUEST_ID")
 var candidate=_canonical(snapshot)
 if candidate.is_empty() or candidate.run_id!=run_id or run_id=="" or candidate.ended_reason!="":return _failure("INVALID_SNAPSHOT")
 var claim=await _claim(false,true)
 if not claim.get("ok",false):return _failure(str(claim.get("code","WEB_IO")))
 var supplied=auth.duplicate(true);supplied.expectedSlotRevision=expected_slot
 var raw:Dictionary=await _web("save",{"auth":supplied,"id":run_id,"expected":expected_revision,"snapshot":candidate,"request_id":request_id}) if use_web else native.save_journey(run_id,supplied,expected_revision,candidate,request_id)
 if raw.get("ok",false) and test_drop_next_ack:test_drop_next_ack=false;return _failure("ACK_LOST")
 return _normalize(raw)

func settle_run(expected_slot:int,expected_revision:int,run_id:String,outcome:String,request_id:String="")->Dictionary:
 if not World.valid_run_id(request_id) or request_id=="" or outcome not in ["withdrawn","chapter1","victory"]:return _failure("INVALID_OUTCOME")
 var claim=await _claim(false,true)
 if not claim.get("ok",false):return _failure(str(claim.get("code","WEB_IO")))
 var supplied=auth.duplicate(true);supplied.expectedSlotRevision=expected_slot
 var raw:Dictionary
 if use_web:
  var current=await _read_raw()
  if not current.get("ok",false):return _failure(str(current.get("code","WEB_IO")))
  var run=current.get("run",{})
  if run.get("id")!=run_id:return _failure("SUPERSEDED_OPERATION")
  var base=_canonical(run.get("snapshot",{}),run.get("status")=="archived")
  if base.is_empty():return _failure("INVALID_SNAPSHOT")
  var probe=World.from_snapshot(base)
  if not probe.finish_run(outcome):return _failure("INVALID_OUTCOME")
  raw=await _web("settle",{"auth":supplied,"id":run_id,"expected":expected_revision,"outcome":outcome,"request_id":request_id,"base":run.snapshot,"ended":probe.save_data()})
 else:raw=native.settle_journey(run_id,supplied,expected_revision,outcome,request_id)
 if raw.get("ok",false) and test_drop_next_ack:test_drop_next_ack=false;return _failure("ACK_LOST")
 return _normalize(raw)

func settle_death(expected_slot:int,expected_revision:int,run_id:String,delta:Vector2i,request_id:String="")->Dictionary:
 if not World.valid_run_id(request_id) or request_id=="" or abs(delta.x)+abs(delta.y)!=1:return _failure("INVALID_DELTA")
 var claim=await _claim(false,true)
 if not claim.get("ok",false):return _failure(str(claim.get("code","WEB_IO")))
 var supplied=auth.duplicate(true);supplied.expectedSlotRevision=expected_slot
 var raw:Dictionary
 if use_web:
  var current=await _read_raw()
  if not current.get("ok",false):return _failure(str(current.get("code","WEB_IO")))
  var run=current.get("run",{})
  if run.get("id")!=run_id:return _failure("SUPERSEDED_OPERATION")
  var base=_canonical(run.get("snapshot",{}),run.get("status")=="archived")
  if base.is_empty():return _failure("INVALID_SNAPSHOT")
  var probe=World.from_snapshot(base)
  if probe.ended_reason=="":
   if not probe.lethal_fight(delta):return _failure("INVALID_LETHAL_FIGHT")
  elif probe.ended_reason!="death":return _failure("INVALID_LETHAL_FIGHT")
  raw=await _web("death",{"auth":supplied,"id":run_id,"expected":expected_revision,"delta":[delta.x,delta.y],"request_id":request_id,"base":run.snapshot,"ended":probe.save_data()})
 else:raw=native.settle_death_journey(run_id,supplied,expected_revision,delta,request_id)
 if raw.get("ok",false) and test_drop_next_ack:test_drop_next_ack=false;return _failure("ACK_LOST")
 return _normalize(raw)
