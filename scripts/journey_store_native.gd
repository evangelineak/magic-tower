class_name TowerJourneyStoreNative
extends "res://scripts/legacy_store_native.gd"
## Production namespace, full World payloads, and idempotent operation receipts.
## Does not import or mutate journey-v4.json or the isolated prototype store.
const Strategy=preload("res://scripts/legacy_strategy.gd")
const World=preload("res://scripts/world.gd")
var _snapshot_cache:Dictionary={}
func _init(path:String="user://journeys-v1"):
 var allowed=path=="user://journeys-v1" or path.begins_with("user://journeys-v1-test-")
 var tail=path.trim_prefix("user://")
 for c in tail:
  if not c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":allowed=false
 safe_path=allowed;root=ProjectSettings.globalize_path(path) if allowed else ""
func _snapshot(value)->Dictionary:
 if not value is Dictionary or (value.get("version")!=13 and value.get("version")!=14 and value.get("version")!=15 and value.get("version")!=16 and value.get("version")!=17 and value.get("version")!=18 and value.get("version")!=19) or value.get("run_id","")=="":return {}
 # World validates both live modes and replay-verified terminal death records.
 if value.get("mode") not in ["safe","risk"]:return {}
 var digest=JSON.stringify(value).sha256_text()
 if _snapshot_cache.has(digest):return _snapshot_cache[digest].duplicate(true)
 var probe=World.from_snapshot(value)
 if probe==null:return {}
 var canonical=probe.save_data().duplicate(true)
 if _snapshot_cache.size()>=256:_snapshot_cache.clear()
 _snapshot_cache[digest]=canonical
 return canonical.duplicate(true)
func _summary(snapshot,outcome)->Dictionary:
 var probe=World.from_snapshot(snapshot)
 if probe==null or probe.mode not in ["safe","risk"]:return {}
 var result=probe.settlement_summary(str(outcome))
 return result.get("summary",{}) if result.get("ok",false) else {}
func _fresh()->Dictionary:
 var data=super._fresh();data.schema=2;return data
func _valid(data)->bool:
 if not data is Dictionary or data.get("schema")!=2 or not data.get("runs") is Dictionary:return false
 if not _keys(data,["schema","storageRevision","profile","runs","slot"]):return false
 if not data.profile is Dictionary or not Profile.validate(data.profile.get("profile")).ok or not data.slot is Dictionary or not data.slot.has("activeRunId"):return false
 var entitled=Strategy.pool_from_profile(data.profile.profile)
 var plain=data.duplicate(true);plain.schema=1
 for id in data.runs:
  var run=data.runs[id]
  if not _keys(run,["id","revision","status","snapshot","last_op"]):return false
  if not Profile.valid_run_id(id):return false
  if run.status!="abandoned" and (not run.snapshot is Dictionary or run.snapshot.get("run_id")!=id):return false
  if run.status=="active" and run.snapshot.get("ended_reason","")!="":return false
  if run.status=="archived" and run.snapshot.get("ended_reason","")=="":return false
  if run.snapshot!=null:
   var verified=_snapshot(run.snapshot)
   if verified.is_empty():return false
   for strategy in verified.draft.pool:
    if not strategy in entitled:return false
  var op=run.last_op
  if not _keys(op,["request_id","kind","expected_slot","expected_revision","hash","result_slot","result_revision"]):return false
  if not Profile.valid_run_id(op.request_id) or op.kind not in ["create","save","settle","death","strategy"]:return false
  if not _int(op.expected_slot) or not _int(op.expected_revision,-1) or not _int(op.result_slot) or not _int(op.result_revision):return false
  if not op.hash is String or op.hash.length()!=64 or op.result_revision!=run.revision:return false
  if op.kind=="create" and (op.request_id!=id or op.expected_revision!=-1 or run.revision!=0):return false
  for c in op.hash:
   if not c in "0123456789abcdef":return false
  if op.kind=="create" and op.result_slot!=op.expected_slot+1:return false
  if op.kind!="create" and (op.expected_revision<0 or op.result_revision!=op.expected_revision+1 or op.result_slot!=op.expected_slot+(1 if op.kind in ["settle","death"] else 0)):return false
  if (run.status=="archived")!=(op.kind in ["settle","death"]):return false
  if run.status=="archived" and ((run.snapshot.get("ended_reason")=="death")!=(op.kind=="death")):return false
  if run.status=="abandoned" and run.snapshot==null:
   if data.slot.activeRunId==id or data.profile.profile.receipts.has(id):return false
   plain.runs.erase(id)
  else:plain.runs[id].erase("last_op")
 return super._valid(plain)
func _operation(data:Dictionary,op:String,args:Dictionary)->Dictionary:
 if op in ["claim","renew"]:return super._operation(data,op,args)
 if op in ["settle","death"]:return _settle(data,args,op=="death")
 if op=="strategy":return _choose(data,args)
 if op not in ["create","save"]:return _error("UNSUPPORTED_OPERATION")
 var request_id=args.get("request_id","")
 if not Profile.valid_run_id(request_id):return _error("INVALID_REQUEST_ID")
 var copied=_snapshot(args.get("snapshot"))
 if copied.is_empty():return _error("INVALID_SNAPSHOT")
 var id:String=request_id if op=="create" else str(args.get("id",""))
 if copied.run_id!=id:return _error("IDENTITY_MISMATCH")
 var slot:Dictionary=data.slot
 var fence_auth:Dictionary=args.auth.duplicate() if args.auth is Dictionary else {}
 fence_auth.expectedSlotRevision=slot.revision
 var error=_auth(slot,fence_auth)
 if error!="":return _error(error)
 var expected_revision:int=-1 if op=="create" else int(args.expected)
 var digest=JSON.stringify(copied).sha256_text()
 if data.runs.has(id) and data.runs[id].last_op.request_id==request_id:
  var existing=data.runs[id];var last=existing.last_op
  var same_hash=last.hash==digest or (existing.snapshot is Dictionary and existing.snapshot.get("version",19)<19 and _snapshot(existing.snapshot)==copied)
  if last.kind!=op or not same_hash or (op=="save" and last.expected_slot!=args.auth.expectedSlotRevision) or last.expected_revision!=expected_revision:return _error("REQUEST_CONFLICT")
  if slot.activeRunId!=id or slot.revision!=last.result_slot or existing.revision!=last.result_revision or existing.status!="active":return _error("SUPERSEDED_OPERATION")
  return {"ok":true,"run":existing.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"duplicate":true,"changed":false}
 error=_auth(slot,args.auth)
 if error!="":return _error(error)
 if op=="create":
  if data.runs.has(id) or data.profile.profile.receipts.has(id):return _error("ID_COLLISION")
  if data.runs.size()>=4096:return _error("RUNS_FULL")
  if copied.mode not in ["safe","risk"]:return _error("UNSUPPORTED_MODE")
  var fresh=World.new(int(copied.seed_value),int(copied.layout_revision),id,copied.mode,false,Strategy.pool_from_profile(data.profile.profile)).save_data()
  if copied!=fresh:return _error("NOT_FRESH_RUN")
  if slot.activeRunId!=null and data.runs[slot.activeRunId].status=="active":
   if not args.get("replace",false):return _error("ACTIVE_RUN_EXISTS")
   # Retain exact history without rewriting its operation receipt.
   data.runs[slot.activeRunId].status="abandoned"
   data.runs[slot.activeRunId].snapshot=null
  var record={"id":id,"revision":0,"status":"active","snapshot":copied,"last_op":{}}
  slot.activeRunId=id;slot.revision=int(slot.revision)+1
  record.last_op={"request_id":request_id,"kind":op,"expected_slot":args.auth.expectedSlotRevision,"expected_revision":-1,"hash":digest,"result_slot":slot.revision,"result_revision":0}
  data.runs[id]=record
  slot.writer.leaseUntil=_now()+60000
  return {"ok":true,"run":record.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"changed":true}
 if slot.activeRunId!=id or not data.runs.has(id) or data.runs[id].status!="active":return _error("NOT_ACTIVE_RUN")
 var run:Dictionary=data.runs[id]
 if not _int(args.expected) or run.revision!=args.expected:return _error("STALE_REVISION")
 if copied.ended_reason!="" or copied.hp<=0:return _error("SETTLEMENT_NOT_ENABLED")
 if copied.mode!=run.snapshot.mode:return _error("MODE_IMMUTABLE")
 var prior=_snapshot(run.snapshot)
 if prior.is_empty() or copied.draft!=prior.draft:return _error("DRAFT_IMMUTABLE")
 if copied.talent_draft!=prior.talent_draft:return _error("TALENT_DRAFT_IMMUTABLE")
 if copied.legacy_points!=prior.legacy_points:return _error("LEGACY_POINTS_IMMUTABLE")
 if copied.cargo.version!=prior.cargo.version or copied.cargo.destination!=prior.cargo.destination:return _error("CARGO_BIRTH_IMMUTABLE")
 if copied.rope.version!=prior.rope.version:return _error("ROPE_BIRTH_IMMUTABLE")
 if prior.draft.choice=="" and copied!=prior:return _error("DRAFT_PENDING")
 run.snapshot=copied;run.revision=int(run.revision)+1
 run.last_op={"request_id":request_id,"kind":op,"expected_slot":args.auth.expectedSlotRevision,"expected_revision":args.expected,"hash":digest,"result_slot":slot.revision,"result_revision":run.revision}
 slot.writer.leaseUntil=_now()+60000
 return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"changed":true}
func create_journey(auth,snapshot,replace_active:bool,request_id:String)->Dictionary:
 return _mutate("create",{"auth":auth,"snapshot":snapshot,"replace":replace_active,"request_id":request_id})
func save_journey(id:String,auth,expected_revision,snapshot,request_id:String)->Dictionary:
 return _mutate("save",{"id":id,"auth":auth,"expected":expected_revision,"snapshot":snapshot,"request_id":request_id})

func _settle(data:Dictionary,args:Dictionary,is_death:bool=false)->Dictionary:
 var id=str(args.get("id",""));var request_id=str(args.get("request_id",""));var outcome="defeat" if is_death else str(args.get("outcome",""))
 var operation="death" if is_death else "settle"
 if is_death and (not args.get("delta") is Vector2i or abs(args.delta.x)+abs(args.delta.y)!=1):return _error("INVALID_DELTA")
 if not Profile.valid_run_id(request_id) or outcome not in (["defeat"] if is_death else ["withdrawn","chapter1","victory"]):return _error("INVALID_OUTCOME")
 var slot:Dictionary=data.slot
 var fence_auth:Dictionary=args.auth.duplicate(true) if args.auth is Dictionary else {}
 fence_auth.expectedSlotRevision=slot.revision
 var error=_auth(slot,fence_auth)
 if error!="":return _error(error)
 if not data.runs.has(id):return _error("NOT_ACTIVE_RUN")
 var run:Dictionary=data.runs[id];var last:Dictionary=run.last_op
 if last.request_id==request_id:
  if last.kind!=operation or last.expected_slot!=args.auth.expectedSlotRevision or last.expected_revision!=args.expected:return _error("REQUEST_CONFLICT")
  var receipt=data.profile.profile.receipts.get(id,{})
  if receipt.get("summary",{}).get("outcome")!=outcome:return _error("REQUEST_CONFLICT")
  if is_death:
   var record=run.snapshot.get("death_record",{})
   if record.get("x")!=run.snapshot.x+args.delta.x or record.get("y")!=run.snapshot.y+args.delta.y:return _error("REQUEST_CONFLICT")
  if slot.activeRunId!=id or slot.revision!=last.result_slot or run.revision!=last.result_revision or run.status!="archived":return _error("SUPERSEDED_OPERATION")
  return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"receipt":receipt.duplicate(true),"profile":data.profile.profile.duplicate(true),"duplicate":true,"changed":false}
 error=_auth(slot,args.auth,id)
 if error!="":return _error(error)
 if run.status!="active":return _error("RUN_NOT_ACTIVE")
 if not _int(args.expected) or run.revision!=args.expected:return _error("STALE_REVISION")
 var world=World.from_snapshot(run.snapshot)
 if world==null or world.ended_reason!="":return _error("INVALID_OUTCOME")
 if is_death:
  if world.mode!="risk" or not world.lethal_fight(args.delta):return _error("INVALID_LETHAL_FIGHT")
 elif not world.finish_run(outcome):return _error("INVALID_OUTCOME")
 var ended=world.save_data();var summary=world.settlement_summary(outcome)
 if not summary.get("ok",false):return _error("INVALID_OUTCOME")
 var decision=Profile.settle(data.profile.profile,id,summary.summary)
 if not decision.ok or decision.status!="applied":return _error("PROFILE_"+str(decision.status).to_upper())
 data.profile.profile=decision.profile;data.profile.commitRevision=int(data.profile.commitRevision)+1
 if test_fail_at=="after_profile":return _error("INJECTED_AFTER_PROFILE")
 run.snapshot=ended;run.status="archived";run.revision=int(run.revision)+1
 if test_fail_at=="after_archive":return _error("INJECTED_AFTER_ARCHIVE")
 slot.revision=int(slot.revision)+1;slot.writer.leaseUntil=_now()+60000
 run.last_op={"request_id":request_id,"kind":operation,"expected_slot":args.auth.expectedSlotRevision,"expected_revision":args.expected,"hash":JSON.stringify(ended).sha256_text(),"result_slot":slot.revision,"result_revision":run.revision}
 if test_fail_at=="after_slot":return _error("INJECTED_AFTER_SLOT")
 return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"receipt":decision.receipt.duplicate(true),"profile":decision.profile.duplicate(true),"changed":true}
func settle_journey(id:String,auth,expected_revision,outcome:String,request_id:String)->Dictionary:
 return _mutate("settle",{"id":id,"auth":auth,"expected":expected_revision,"outcome":outcome,"request_id":request_id})

func settle_death_journey(id:String,auth,expected_revision,delta:Vector2i,request_id:String)->Dictionary:
 return _mutate("death",{"id":id,"auth":auth,"expected":expected_revision,"delta":delta,"request_id":request_id})

func _choose(data:Dictionary,args:Dictionary)->Dictionary:
 var id=str(args.get("id",""));var request_id=str(args.get("request_id",""));var choice=args.get("choice")
 if not Profile.valid_run_id(request_id) or not choice is String:return _error("INVALID_STRATEGY")
 var allocation=args.get("allocation",{})
 if not allocation is Dictionary:return _error("INVALID_ALLOCATION")
 if allocation.is_empty():allocation={"study":0,"reserve":0}
 if not _keys(allocation,["study","reserve"]) or not _int(allocation.study,0,2) or not _int(allocation.reserve,0,2):return _error("INVALID_ALLOCATION")
 var slot:Dictionary=data.slot
 var fence_auth:Dictionary=args.auth.duplicate(true) if args.auth is Dictionary else {}
 fence_auth.expectedSlotRevision=slot.revision
 var error=_auth(slot,fence_auth)
 if error!="":return _error(error)
 if not data.runs.has(id):return _error("NOT_ACTIVE_RUN")
 if slot.activeRunId!=id:return _error("SUPERSEDED_OPERATION")
 var run:Dictionary=data.runs[id];var last:Dictionary=run.last_op
 if last.request_id==request_id:
  if last.kind!="strategy" or last.expected_slot!=args.auth.expectedSlotRevision or last.expected_revision!=args.expected:return _error("REQUEST_CONFLICT")
  if slot.activeRunId!=id or slot.revision!=last.result_slot or run.revision!=last.result_revision or run.status!="active":return _error("SUPERSEDED_OPERATION")
  if run.snapshot.get("draft",{}).get("choice")!=choice:return _error("REQUEST_CONFLICT")
  var points=_snapshot(run.snapshot).get("legacy_points",{})
  if points.get("study")!=allocation.study or points.get("reserve")!=allocation.reserve:return _error("REQUEST_CONFLICT")
  return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"duplicate":true,"changed":false}
 error=_auth(slot,args.auth,id)
 if error!="":return _error(error)
 if run.status!="active":return _error("RUN_NOT_ACTIVE")
 if not _int(args.expected) or run.revision!=args.expected:return _error("STALE_REVISION")
 var world=World.from_snapshot(run.snapshot)
 if world==null or not world.choose_strategy(choice,allocation):return _error("INVALID_STRATEGY")
 var chosen=world.save_data()
 run.snapshot=chosen;run.revision=int(run.revision)+1;slot.writer.leaseUntil=_now()+60000
 run.last_op={"request_id":request_id,"kind":"strategy","expected_slot":args.auth.expectedSlotRevision,"expected_revision":args.expected,"hash":JSON.stringify(chosen).sha256_text(),"result_slot":slot.revision,"result_revision":run.revision}
 if test_fail_at=="after_choice":return _error("INJECTED_AFTER_CHOICE")
 return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"changed":true}
func choose_strategy(id:String,auth,expected_revision,choice:String,request_id:String,allocation:Dictionary={})->Dictionary:
 return _mutate("strategy",{"id":id,"auth":auth,"expected":expected_revision,"choice":choice,"request_id":request_id,"allocation":allocation})
