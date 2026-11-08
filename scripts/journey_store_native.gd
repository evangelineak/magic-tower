class_name TowerJourneyStoreNative
extends "res://scripts/legacy_store_native.gd"
## Production namespace, full World payloads, and idempotent operation receipts.
## Does not import or mutate journey-v4.json or the isolated prototype store.
const World=preload("res://scripts/world.gd")
var _snapshot_cache:Dictionary={}
func _init(path:String="user://journeys-v1"):
 var allowed=path=="user://journeys-v1" or path.begins_with("user://journeys-v1-test-")
 var tail=path.trim_prefix("user://")
 for c in tail:
  if not c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":allowed=false
 safe_path=allowed;root=ProjectSettings.globalize_path(path) if allowed else ""
func _snapshot(value)->Dictionary:
 if not value is Dictionary or value.get("version")!=13 or value.get("run_id","")=="":return {}
 # Risk mode remains outside this storage batch. Archived safe runs are validated below.
 if value.get("mode")!="safe" :return {}
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
 if probe==null or probe.mode!="safe":return {}
 var result=probe.settlement_summary(str(outcome))
 return result.get("summary",{}) if result.get("ok",false) else {}
func _fresh()->Dictionary:
 var data=super._fresh();data.schema=2;return data
func _valid(data)->bool:
 if not data is Dictionary or data.get("schema")!=2 or not data.get("runs") is Dictionary:return false
 var plain=data.duplicate(true);plain.schema=1
 for id in data.runs:
  var run=data.runs[id]
  if not _keys(run,["id","revision","status","snapshot","last_op"]):return false
  if not Profile.valid_run_id(id):return false
  if run.status!="abandoned" and (not run.snapshot is Dictionary or run.snapshot.get("run_id")!=id):return false
  if run.status=="active" and run.snapshot.get("ended_reason","")!="":return false
  if run.status=="archived" and run.snapshot.get("ended_reason","")=="":return false
  var op=run.last_op
  if not _keys(op,["request_id","kind","expected_slot","expected_revision","hash","result_slot","result_revision"]):return false
  if not Profile.valid_run_id(op.request_id) or op.kind not in ["create","save","settle"]:return false
  if not _int(op.expected_slot) or not _int(op.expected_revision,-1) or not _int(op.result_slot) or not _int(op.result_revision):return false
  if not op.hash is String or op.hash.length()!=64 or op.result_revision!=run.revision:return false
  if op.kind=="create" and (op.request_id!=id or op.expected_revision!=-1 or run.revision!=0):return false
  for c in op.hash:
   if not c in "0123456789abcdef":return false
  if op.kind=="create" and op.result_slot!=op.expected_slot+1:return false
  if op.kind!="create" and (op.expected_revision<0 or op.result_revision!=op.expected_revision+1 or op.result_slot!=op.expected_slot+(1 if op.kind=="settle" else 0)):return false
  if (run.status=="archived")!=(op.kind=="settle"):return false
  if run.status=="abandoned" and run.snapshot==null:
   if data.slot.activeRunId==id or data.profile.profile.receipts.has(id):return false
   plain.runs.erase(id)
  else:plain.runs[id].erase("last_op")
 return super._valid(plain)
func _operation(data:Dictionary,op:String,args:Dictionary)->Dictionary:
 if op in ["claim","renew"]:return super._operation(data,op,args)
 if op=="settle":return _settle(data,args)
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
  if last.kind!=op or last.hash!=digest or (op=="save" and last.expected_slot!=args.auth.expectedSlotRevision) or last.expected_revision!=expected_revision:return _error("REQUEST_CONFLICT")
  if slot.activeRunId!=id or slot.revision!=last.result_slot or existing.revision!=last.result_revision or existing.status!="active":return _error("SUPERSEDED_OPERATION")
  return {"ok":true,"run":existing.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"duplicate":true,"changed":false}
 error=_auth(slot,args.auth)
 if error!="":return _error(error)
 if op=="create":
  if data.runs.has(id) or data.profile.profile.receipts.has(id):return _error("ID_COLLISION")
  if data.runs.size()>=4096:return _error("RUNS_FULL")
  if copied.mode!="safe":return _error("UNSUPPORTED_MODE")
  var fresh=World.new(int(copied.seed_value),int(copied.layout_revision),id,"safe").save_data()
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
 if copied.ended_reason!="":return _error("SETTLEMENT_NOT_ENABLED")
 run.snapshot=copied;run.revision=int(run.revision)+1
 run.last_op={"request_id":request_id,"kind":op,"expected_slot":args.auth.expectedSlotRevision,"expected_revision":args.expected,"hash":digest,"result_slot":slot.revision,"result_revision":run.revision}
 slot.writer.leaseUntil=_now()+60000
 return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"profile":data.profile.profile.duplicate(true),"changed":true}
func create_journey(auth,snapshot,replace_active:bool,request_id:String)->Dictionary:
 return _mutate("create",{"auth":auth,"snapshot":snapshot,"replace":replace_active,"request_id":request_id})
func save_journey(id:String,auth,expected_revision,snapshot,request_id:String)->Dictionary:
 return _mutate("save",{"id":id,"auth":auth,"expected":expected_revision,"snapshot":snapshot,"request_id":request_id})

func _settle(data:Dictionary,args:Dictionary)->Dictionary:
 var id=str(args.get("id",""));var request_id=str(args.get("request_id",""));var outcome=str(args.get("outcome",""))
 if not Profile.valid_run_id(request_id) or outcome not in ["withdrawn","chapter1","victory"]:return _error("INVALID_OUTCOME")
 var slot:Dictionary=data.slot
 var fence_auth:Dictionary=args.auth.duplicate(true) if args.auth is Dictionary else {}
 fence_auth.expectedSlotRevision=slot.revision
 var error=_auth(slot,fence_auth)
 if error!="":return _error(error)
 if not data.runs.has(id):return _error("NOT_ACTIVE_RUN")
 var run:Dictionary=data.runs[id];var last:Dictionary=run.last_op
 if last.request_id==request_id:
  if last.kind!="settle" or last.expected_slot!=args.auth.expectedSlotRevision or last.expected_revision!=args.expected:return _error("REQUEST_CONFLICT")
  var receipt=data.profile.profile.receipts.get(id,{})
  if receipt.get("summary",{}).get("outcome")!=outcome:return _error("REQUEST_CONFLICT")
  if slot.activeRunId!=id or slot.revision!=last.result_slot or run.revision!=last.result_revision or run.status!="archived":return _error("SUPERSEDED_OPERATION")
  return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"receipt":receipt.duplicate(true),"profile":data.profile.profile.duplicate(true),"duplicate":true,"changed":false}
 error=_auth(slot,args.auth,id)
 if error!="":return _error(error)
 if run.status!="active":return _error("RUN_NOT_ACTIVE")
 if not _int(args.expected) or run.revision!=args.expected:return _error("STALE_REVISION")
 var world=World.from_snapshot(run.snapshot)
 if world==null or world.mode!="safe" or world.ended_reason!="" or not world.finish_run(outcome):return _error("INVALID_OUTCOME")
 var ended=world.save_data();var summary=world.settlement_summary(outcome)
 if not summary.get("ok",false):return _error("INVALID_OUTCOME")
 var decision=Profile.settle(data.profile.profile,id,summary.summary)
 if not decision.ok or decision.status!="applied":return _error("PROFILE_"+str(decision.status).to_upper())
 data.profile.profile=decision.profile;data.profile.commitRevision=int(data.profile.commitRevision)+1
 if test_fail_at=="after_profile":return _error("INJECTED_AFTER_PROFILE")
 run.snapshot=ended;run.status="archived";run.revision=int(run.revision)+1
 if test_fail_at=="after_archive":return _error("INJECTED_AFTER_ARCHIVE")
 slot.revision=int(slot.revision)+1;slot.writer.leaseUntil=_now()+60000
 run.last_op={"request_id":request_id,"kind":"settle","expected_slot":args.auth.expectedSlotRevision,"expected_revision":args.expected,"hash":JSON.stringify(ended).sha256_text(),"result_slot":slot.revision,"result_revision":run.revision}
 if test_fail_at=="after_slot":return _error("INJECTED_AFTER_SLOT")
 return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"leaseUntil":slot.writer.leaseUntil,"receipt":decision.receipt.duplicate(true),"profile":decision.profile.duplicate(true),"changed":true}
func settle_journey(id:String,auth,expected_revision,outcome:String,request_id:String)->Dictionary:
 return _mutate("settle",{"id":id,"auth":auth,"expected":expected_revision,"outcome":outcome,"request_id":request_id})
