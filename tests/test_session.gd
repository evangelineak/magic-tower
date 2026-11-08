extends SceneTree
const Session=preload("res://scripts/session.gd")
const World=preload("res://scripts/world.gd")
var checks=0
var failures=0
var busy_probe=false
class FakeStore:
 extends RefCounted
 var record:Dictionary={}
 var op=""
 var signature=""
 var lost_ack=false
 var fail_before=false
 var conflict=false
 var writes=0
 var delay=false
 var response_patch:Dictionary={}
 func failure(status:String,retryable=false): return {"ok":false,"status":status,"reason":status,"retryable":retryable}
 func response():
  var result=record.duplicate(true);result.ok=true;result.status="ok";result.reason=""
  result.merge(response_patch,true)
  return result
 func read_active(): return failure("empty") if record.is_empty() else response()
 func reacquire_and_read(): conflict=false;return read_active()
 func create_run(seed_value,layout=2,mode="safe",replace=false,request=""):
  var sig=JSON.stringify([seed_value,layout,mode,replace])
  if conflict:return failure("conflict")
  if op==request:
   return response() if signature==sig else failure("conflict")
  if fail_before:fail_before=false;return failure("io_error",true)
  if not record.is_empty() and not replace:return failure("active_exists")
  var w=World.new(seed_value,layout,request,mode)
  record={"snapshot":w.save_data(),"run_id":request,"slot":record.get("slot",0)+1,"revision":0,"eligible":true}
  op=request;signature=sig;writes+=1
  if lost_ack:lost_ack=false;return failure("ack_lost",true)
  return response()
 func commit_run(expected_slot,expected_revision,run_id,snapshot,request):
  if delay: await Engine.get_main_loop().process_frame
  var sig=JSON.stringify([expected_slot,expected_revision,run_id,snapshot])
  if conflict:return failure("conflict")
  if op==request:
   return response() if signature==sig else failure("conflict")
  if fail_before:fail_before=false;return failure("io_error",true)
  if record.is_empty() or expected_slot!=record.slot or expected_revision!=record.revision or run_id!=record.run_id:return failure("conflict")
  record.snapshot=snapshot.duplicate(true);record.revision+=1;op=request;signature=sig;writes+=1
  if lost_ack:lost_ack=false;return failure("ack_lost",true)
  return response()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _init(): call_deferred("run")
func probe_busy(session):
 busy_probe=(await session.action("arm")).status=="busy"
func run():
 var store=FakeStore.new();var session=Session.new(store)
 check((await session.open_current()).status=="empty" and session.world==null and not session.read_only,"empty does not create or overwrite")
 store.lost_ack=true
 var result=await session.new_run(0,2)
 check(not result.ok and not result.has("effect") and session.world==null and store.writes==1,"lost create ack does not publish speculative new run")
 var original_id=store.record.run_id
 check((await session.new_run(1,2)).status=="pending","new intent blocked while pending")
 result=await session.retry_pending()
 check(result.ok and result.committed and session.world.run_id==original_id and store.writes==1,"create retry reuses stable ID without replacement")
 check(result.effect=={"operation":"create"},"acklost create publishes effect only once after success")
 var initial=session.world.save_data().duplicate(true)
 var initial_revision=session.revision
 store.fail_before=true
 result=await session.action("hero_ranger")
 # Existing World uses hero_<id>; this action is valid in an untouched run.
 check(not result.ok and session.world.save_data()==initial and session.history.is_empty(),"failed commit keeps actual world and history unchanged")
 check(store.writes==1,"failed-before-commit creates no stored revision")
 result=await session.retry_pending()
 check(result.ok and session.world.hero_id=="ranger" and session.history.size()==1 and session.revision==initial_revision+1,"same pending candidate commits once")
 var ranger=session.world.save_data().duplicate(true)
 store.lost_ack=true
 result=await session.action("arm")
 check(not result.ok and session.world.save_data()==ranger and session.history.size()==1,"lost action ack leaves visible state unchanged")
 var writes=store.writes
 result=await session.retry_pending()
 check(result.ok and session.world.skill_armed and session.history.size()==2 and store.writes==writes,"action ack retry does not apply action twice")
 check(result.effect=={"operation":"action","input":"arm"},"acklost retry carries exact original action effect")
 check(not (await session.retry_pending()).has("effect"),"completed retry cannot replay effects again")
 var before_undo_revision=session.revision
 result=await session.undo()
 check(result.ok and not session.world.skill_armed and session.history.size()==1 and session.revision==before_undo_revision+1,"undo restores gameplay but advances storage revision")
 check(session.world.run_id==original_id,"undo preserves identity")
 var before=session.world.save_data().duplicate(true);var old_history=session.history.duplicate(true)
 store.conflict=true
 result=await session.action("arm")
 check(not result.ok and session.read_only and session.world.save_data()==before and session.history==old_history,"fence conflict changes no gameplay")
 check((await session.retry_pending()).status=="readonly","conflict cannot retry stale state")
 result=await session.reacquire_and_reload()
 check(result.ok and not session.read_only and session.history.is_empty(),"reacquire always reloads and discards pending/history")
 check((await session.undo()).status=="invalid","reload has no forged prior undo")
 before=session.world.save_data().duplicate(true);writes=store.writes
 result=await session.step(Vector2i(-1,0))
 check(not result.ok and result.status=="rejected" and session.world.save_data()==before and store.writes==writes,"rejected world action never commits")
 result=await session.safe_walk(Vector2i(9,9),0,session.world.pos)
 check(not result.ok and store.writes==writes,"safe walk invalid target cannot bypass world")
 result=await session.save()
 check(result.ok and session.history.is_empty() and store.writes==writes+1,"manual save uses CAS, does not add fake undo")
 session.busy=true
 check((await session.save()).status=="busy" and (await session.open_current()).status=="busy","async busy guard rejects overlapping intent")
 session.busy=false
 store.delay=true
 call_deferred("probe_busy",session)
 result=await session.action("arm")
 check(result.ok and busy_probe,"actual suspended adapter blocks concurrent intent")
 store.delay=false
 check((await session.step(Vector2i.RIGHT)).ok,"manual pickup opens a cleared walking tile")
 var route=[]
 for y in range(1,10):
  for x in range(1,10):
   var possible=session.world.safe_walk_path(Vector2i(x,y))
   if not possible.is_empty():route=possible;break
  if not route.is_empty():break
 check(not route.is_empty(),"fixture has a reachable safe dot")
 if not route.is_empty():
  before=session.world.save_data().duplicate(true)
  result=await session.safe_walk(route[0],session.world.floor_index,session.world.pos)
  var after=session.world.save_data()
  check(result.ok and after.moves==before.moves+1 and after.run_id==before.run_id,"safe step uses CAS and keeps identity")
  for key in before:
   if not key in ["x","y","moves"]:check(after[key]==before[key],"safe committed step changes no unrelated state: "+key)
  check((await session.undo()).ok and session.world.save_data()==before,"safe-step undo restores exact gameplay snapshot")
 var second=Session.new(store)
 check((await second.open_current()).ok and second.world.save_data()==session.world.save_data(),"fresh controller restores actual committed world")
 # Eligibility is authoritative envelope data, not inferred from a plausible ID.
 for eligibility in [false,null,1,"true"]:
  var saved_record=store.record.duplicate(true)
  var visible=second.world.save_data().duplicate(true)
  var visible_history=second.history.duplicate(true)
  if eligibility==null:store.record.erase("eligible")
  else:store.record.eligible=eligibility
  var invalid=await second.open_current()
  check(not invalid.ok and second.read_only and second.world.save_data()==visible and second.history==visible_history,"non-boolean-true eligibility rejects without publishing")
  store.record=saved_record
  check((await second.reacquire_and_reload()).ok,"valid eligible record recovers explicitly")
 # Another writer advances after our lost acknowledgement: don't replay stale op.
 store.lost_ack=true
 result=await session.action("arm")
 check(not result.ok,"second lost ack")
 store.op="another-operation";store.record.revision+=1
 check(not (await session.retry_pending()).ok and session.read_only,"advanced record after lost ack forces reload, never rebases")
 before=second.world.save_data().duplicate(true)
 store.record.snapshot.run_id="invalid"
 check(not (await second.open_current()).ok and second.world.save_data()==before and second.read_only,"corrupt load preserves existing visible world")
 for patch in [{"revision":1},{"revision":-1},{"slot":-1}]:
  var broken_store=FakeStore.new();broken_store.response_patch=patch
  var broken_session=Session.new(broken_store)
  check(not (await broken_session.new_run(0)).ok and broken_session.world==null,"create rejects invalid initial metadata")
 for patch in [{"revision":0},{"revision":2},{"slot":0},{"slot":2}]:
  var broken_store=FakeStore.new();var broken_session=Session.new(broken_store)
  check((await broken_session.new_run(0)).ok,"metadata fixture creates valid run")
  var old=broken_session.world.save_data().duplicate(true)
  broken_store.response_patch=patch
  check(not (await broken_session.action("hero_ranger")).ok and broken_session.world.save_data()==old and broken_session.history.is_empty(),"commit rejects wrong slot or non-CAS revision without publishing")
 print("SESSION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
