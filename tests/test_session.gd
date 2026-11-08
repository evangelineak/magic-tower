extends SceneTree
const Session=preload("res://scripts/session.gd")
const Profile=preload("res://scripts/legacy_profile.gd")
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
 var json_transport=false
 var response_patch:Dictionary={}
 var profile=Profile.fresh()
 func failure(status:String,retryable=false): return {"ok":false,"status":status,"reason":status,"retryable":retryable}
 func response():
  var result=record.duplicate(true);result.ok=true;result.status="archived" if record.get("status")=="archived" else "active";result.reason=""
  result.profile=profile.duplicate(true)
  result.merge(response_patch,true)
  return JSON.parse_string(JSON.stringify(result)) if json_transport else result
 func read_active(): return failure("empty") if record.is_empty() else response()
 func reacquire_and_read(): conflict=false;return read_active()
 func create_run(seed_value,layout=2,mode="safe",replace=false,request=""):
  var sig=JSON.stringify([seed_value,layout,mode,replace])
  if conflict:return failure("conflict")
  if op==request:
   return response() if signature==sig else failure("conflict")
  if fail_before:fail_before=false;return failure("io_error",true)
  if not record.is_empty() and record.get("status", "active")=="active" and not replace:return failure("active_exists")
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
  if record.get("status", "active")!="active":return failure("archived")
  if record.is_empty() or expected_slot!=record.slot or expected_revision!=record.revision or run_id!=record.run_id:return failure("conflict")
  record.snapshot=snapshot.duplicate(true);record.revision+=1;op=request;signature=sig;writes+=1
  if lost_ack:lost_ack=false;return failure("ack_lost",true)
  return response()
 func settle_run(expected_slot,expected_revision,run_id,outcome,request):
  if delay: await Engine.get_main_loop().process_frame
  var sig=JSON.stringify([expected_slot,expected_revision,run_id,outcome])
  if conflict:return failure("conflict")
  if op==request:return response() if signature==sig else failure("conflict")
  if fail_before:fail_before=false;return failure("io_error",true)
  if record.is_empty() or expected_slot!=record.slot or expected_revision!=record.revision or run_id!=record.run_id or record.get("status","active")!="active":return failure("conflict")
  var candidate=World.from_snapshot(record.snapshot)
  if candidate==null or not candidate.finish_run(outcome):return failure("invalid")
  var derived=candidate.settlement_summary(outcome)
  if not derived.ok:return failure("invalid")
  var settled=Profile.settle(profile,run_id,derived.summary)
  if not settled.ok:return failure("invalid")
  profile=settled.profile
  record.snapshot=candidate.save_data();record.revision+=1;record.slot+=1
  record.status="archived";record.receipt=settled.receipt;record.profile=profile.duplicate(true)
  op=request;signature=sig;writes+=1
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
 await settlement_cases()
 print("SESSION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)

func settlement_cases():
 var store=FakeStore.new();var session=Session.new(store)
 check((await session.new_run(0)).ok,"settlement fixture creates new run")
 # Synthetic but fully restore-valid visited-floor fixture; real-route tests live
 # at the storage/World integration layer, not in this controller unit test.
 store.record.snapshot.floor_seen=[true,true,true,false,false]
 check((await session.open_current()).ok,"load visited floor fixture")
 check((await session.action("hero_ranger")).ok,"history available before settlement")
 var before=session.world.save_data().duplicate(true);var history=session.history.duplicate(true)
 for invalid in ["retired","defeat","victory","chapter1",""]:
  check(not (await session.finish(invalid)).ok and session.world.save_data()==before,"only presently legal safe outcomes allowed")
 store.fail_before=true
 var result=await session.finish("withdrawn")
 check(not result.ok and not session.terminal and session.world.save_data()==before and session.history==history and store.profile.receipts.is_empty(),"settlement fault before write preserves live world and all history")
 check((await session.action("arm")).status=="pending","no new gameplay while settlement pending")
 store.lost_ack=true
 result=await session.retry_pending()
 check(not result.ok and not result.has("effect") and session.world.save_data()==before and session.history==history and store.profile.receipts.size()==1,"lost settlement ack cannot publish or erase undo")
 var writes=store.writes;var committed_slot=store.record.slot;var committed_rev=store.record.revision
 result=await session.retry_pending()
 check(result.ok and result.effect=={"operation":"settle","input":"withdrawn"} and session.terminal and not session.read_only,"retry publishes terminal once after acknowledgement")
 check(session.history.is_empty() and session.receipt.unlocked==["legacy_scout"] and session.profile.receipts.size()==1,"unique receipt and cleared history")
 check(store.writes==writes and session.slot==committed_slot and session.revision==committed_rev,"retry doesn't increment profile or CAS counters twice")
 for operation in ["save","undo"]:
  check((await session.call(operation)).status=="terminal","terminal blocks "+operation)
 check((await session.step(Vector2i.RIGHT)).status=="terminal" and (await session.action("expedition")).status=="terminal","terminal blocks movement and continuation")
 check((await session.finish("withdrawn")).status=="terminal" and not (await session.retry_pending()).has("effect"),"terminal cannot claim/replay settlement again")
 var loaded=Session.new(store)
 result=await loaded.open_current()
 check(result.ok and not result.committed and not result.has("effect") and loaded.terminal and loaded.receipt==session.receipt,"startup restores archived world without repeating effects")
 var ended=session.world.save_data().duplicate(true)
 var archived=store.record.duplicate(true)
 for field in ["receipt","profile"]:
  store.record=archived.duplicate(true);store.record[field]={}
  if field=="profile":store.response_patch={"profile":{}}
  check(not (await loaded.open_current()).ok and loaded.world.save_data()==ended and loaded.terminal,"malformed archive "+field+" preserves display")
 store.response_patch={}
 store.record=archived.duplicate(true);store.record.receipt.summary.moves+=1
 check(not (await loaded.open_current()).ok,"receipt mismatching profile refused")
 store.record=archived.duplicate(true)
 var fake_profile=Profile.fresh()
 var fake_summary=store.record.receipt.summary.duplicate();fake_summary.moves+=1
 var fake=Profile.settle(fake_profile,store.record.run_id,fake_summary)
 store.record.receipt=fake.receipt;store.response_patch={"profile":fake.profile}
 check(not (await loaded.open_current()).ok,"valid profile with summary mismatching ended World refused")
 store.response_patch={}
 store.record=archived.duplicate(true);store.record.status="active"
 check(not (await loaded.open_current()).ok,"ended snapshot cannot be revived by active label")
 store.record=archived.duplicate(true);store.record.snapshot=before
 check(not (await loaded.open_current()).ok,"archived label cannot accept live snapshot")
 store.record=archived.duplicate(true)
 check((await loaded.reacquire_and_reload()).ok and loaded.terminal,"valid archive explicitly recoverable")
 var old_id=loaded.world.run_id
 check((await loaded.new_run(42)).ok and not loaded.terminal and loaded.world.run_id!=old_id and loaded.receipt.is_empty() and loaded.profile.receipts.size()==1,"explicit new journey has new ID, clears receipt display and retains permanent profile")
 check(store.profile.receipts.size()==1,"new journey doesn't erase permanent ledger")
 # Pending old settlement cannot publish over another writer's newly created run.
 check((await loaded.action("hero_ranger")).ok,"new active run usable")
 store.lost_ack=true
 check(not (await loaded.finish("withdrawn")).ok,"second settlement loses ack")
 var live=loaded.world.save_data().duplicate(true)
 check((await store.create_run(1,2,"safe",true,"another_run_0123456789")).ok,"another writer creates a new current run")
 check(not (await loaded.retry_pending()).ok and loaded.read_only and loaded.world.save_data()==live,"old pending settle cannot overwrite newer active slot")
 check((await loaded.reacquire_and_reload()).ok and not loaded.terminal and loaded.world.run_id=="another_run_0123456789","explicit reload follows newer run not old receipt")
 # Bad acknowledgement of a committed settlement must not publish anything.
 for patch in [{"slot":0},{"revision":0},{"eligible":false},{"receipt":{}},{"profile":{}}]:
  var broken=FakeStore.new();var controller=Session.new(broken)
  check((await controller.new_run(0)).ok,"bad-ack fixture active")
  var original=controller.world.save_data().duplicate(true)
  broken.response_patch=patch
  check(not (await controller.finish("withdrawn")).ok and not controller.terminal and controller.world.save_data()==original,"invalid settlement acknowledgement leaves live view unchanged")

 # A self-consistent but unrelated receipt must not sneak into the known ledger.
 var injected_store=FakeStore.new();var injected=Session.new(injected_store)
 check((await injected.new_run(0)).ok,"ledger injection fixture")
 var final_candidate=World.from_snapshot(injected.world.save_data())
 final_candidate.finish_run("withdrawn")
 var expected=Profile.settle(Profile.fresh(),injected.world.run_id,final_candidate.settlement_summary("withdrawn").summary)
 var extra=Profile.settle(expected.profile,"unrelated_run_0123456789",{"seed":1,"max_floor":8,"moves":12,"outcome":"victory"})
 check(Profile.validate(extra.profile).ok,"malicious extra ledger is independently structurally valid")
 injected_store.response_patch={"profile":extra.profile}
 var old_live=injected.world.save_data().duplicate(true)
 check(not (await injected.finish("withdrawn")).ok and injected.world.save_data()==old_live and not injected.terminal,"known baseline rejects unrelated but valid profile receipts")
 for invalid_profile in [null,{},true,[]]:
  var corrupt_store=FakeStore.new();var corrupt=Session.new(corrupt_store)
  corrupt_store.response_patch={"profile":invalid_profile}
  check(not (await corrupt.new_run(0)).ok and corrupt.world==null,"active acknowledgements require a valid full profile")

 var json_store=FakeStore.new();json_store.json_transport=true
 var json_session=Session.new(json_store)
 check((await json_session.new_run(0)).ok,"JSON create canonicalizes integer metadata")
 check((await json_session.action("hero_ranger")).ok,"JSON commit preserves full payload")
 check((await json_session.finish("withdrawn")).ok and json_session.terminal,"JSON receipt matches integer summary and expected pure ledger")
 check((await json_session.open_current()).ok and json_session.terminal,"JSON archive reload validates numeric receipt")

 var preserve_store=FakeStore.new();var preserve=Session.new(preserve_store)
 check((await preserve.new_run(0)).ok and (await preserve.finish("withdrawn")).ok,"profile retention fixture")
 var saved_profile=preserve.profile.duplicate(true);var saved_end=preserve.world.save_data().duplicate(true)
 preserve_store.response_patch={"profile":Profile.fresh()}
 check(not (await preserve.new_run(42)).ok and preserve.profile==saved_profile and preserve.world.save_data()==saved_end and preserve.terminal,"new run acknowledgement cannot erase previous ledger")
