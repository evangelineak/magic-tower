extends RefCounted
# Test-only storage injection. Never selected by the production factory.
const Session=preload("res://scripts/session.gd")
const World=preload("res://scripts/world.gd")
static var serial:int=0
class MemoryAdapter:
 extends RefCounted
 var record:Dictionary={}
 var receipts:Dictionary={}
 var writes:int=0
 var last_request:String=""
 func failure(status:String): return {"ok":false,"status":status,"reason":status,"retryable":false}
 func response():
  var result=record.duplicate(true); result.ok=true; result.status="ok"; result.reason=""; return result
 func read_active(): return failure("empty") if record.is_empty() else response()
 func reacquire_and_read(): return read_active()
 func replay(request:String,signature:String):
  if not receipts.has(request): return null
  return receipts[request].result.duplicate(true) if last_request==request and receipts[request].signature==signature else failure("conflict")
 func remember(request:String,signature:String):
  last_request=request
  var result=response(); receipts[request]={"signature":signature,"result":result.duplicate(true)}; writes+=1; return result
 func create_run(seed_value,layout=2,mode="safe",replace=false,request=""):
  var signature=JSON.stringify(["create",seed_value,layout,mode,replace])
  var prior=replay(request,signature)
  if prior!=null:return prior
  if not record.is_empty() and not replace:return failure("active_exists")
  var candidate=World.new(seed_value,layout,request,mode)
  if not candidate.generation_valid or not candidate.reward_eligible():return failure("invalid")
  record={"snapshot":candidate.save_data(),"run_id":request,"slot":record.get("slot",0)+1,"revision":0,"eligible":true}
  return remember(request,signature)
 func commit_run(expected_slot,expected_revision,run_id,snapshot,request):
  var signature=JSON.stringify(["commit",expected_slot,expected_revision,run_id,snapshot])
  var prior=replay(request,signature)
  if prior!=null:return prior
  if record.is_empty() or record.slot!=expected_slot or record.revision!=expected_revision or record.run_id!=run_id:return failure("conflict")
  var candidate=World.from_snapshot(snapshot)
  if candidate==null or candidate.run_id!=run_id or not candidate.reward_eligible():return failure("invalid")
  record.snapshot=snapshot.duplicate(true); record.revision+=1
  return remember(request,signature)
static func attach(scene):
 scene.session=Session.new(MemoryAdapter.new())
static func prepare(scene): attach(scene)
static func bind(scene,world):
 if scene.session==null or not scene.session.adapter is MemoryAdapter: attach(scene)
 serial+=1
 var data:Dictionary=world.save_data().duplicate(true)
 data.run_id="ui_fixture_%020d"%serial
 data.mode="safe";data.ended_reason=""
 var candidate=World.from_snapshot(data)
 assert(candidate!=null,"Synthetic fixture must satisfy full World validation")
 var adapter=scene.session.adapter
 adapter.record={"snapshot":data,"run_id":data.run_id,"slot":adapter.record.get("slot",0)+1,"revision":0,"eligible":true}
 adapter.receipts.clear()
 scene.session=Session.new(adapter)
 await scene.load_game()
 assert(scene.world!=null and scene.world.run_id==data.run_id)
static func sync(scene):
 # Explicit test-only resnapshot after controlled field setup. Preserve identity/history.
 var history:Array=scene.history.duplicate(true)
 var data:Dictionary=scene.world.save_data().duplicate(true)
 var candidate=World.from_snapshot(data)
 assert(candidate!=null,"Controlled fixture mutation must remain valid")
 var adapter=scene.session.adapter
 adapter.record={"snapshot":data,"run_id":data.run_id,"slot":adapter.record.slot+1,"revision":0,"eligible":true}
 adapter.receipts.clear()
 scene.apply_session_result(await scene.session.open_current())
 scene.session.history=history;scene.history=scene.session.history
static func snapshot(scene)->Dictionary:
 return {"record":scene.session.adapter.record.duplicate(true),"writes":scene.session.adapter.writes}
