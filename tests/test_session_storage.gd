extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const ClockedStore=preload("res://tests/clocked_journey_store.gd")
const World=preload("res://scripts/world.gd")
class SilentBridge:
 extends RefCounted
 func request(_encoded,_callback):pass
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func require_ok(result:Dictionary,label:String)->bool:
 if result.get("ok",false):return true
 check(false,label+": "+str(result))
 print("SESSION STORAGE: FAIL (",checks," checks; stopped before dependent fixture access)")
 quit(1)
 return false
func nonce()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
func _initialize():call_deferred("run")
func run():
 var Session=load("res://scripts/session.gd")
 var bootstrap=Session.new(Store.new("user://journeys-v1-test-bootstrap-"+nonce()))
 var opened=await bootstrap.open_current()
 check(not opened.ok and opened.status=="empty" and not bootstrap.read_only,"real Session opens empty storage without locking fresh startup")
 var started=await bootstrap.new_run(0)
 check(started.ok and bootstrap.world!=null and bootstrap.world.run_id!="","real empty Session can create its first bound World")
 var published=bootstrap.world.save_data().duplicate(true)
 bootstrap.adapter.test_drop_next_ack=true
 var pending=await bootstrap.step(Vector2i.RIGHT)
 check(not pending.ok and bootstrap.world.save_data()==published and bootstrap.history.is_empty(),"real Session does not publish a lost-ack speculative move")
 var recovered=await bootstrap.retry_pending()
 check(recovered.ok and bootstrap.world.pos==Vector2i(2,1) and bootstrap.history.size()==1,"real Session retry publishes one durable action exactly once")
 var path="user://journeys-v1-test-"+nonce();var adapter=Store.new(path)
 var empty=await adapter.read_active();check(not empty.ok and empty.status=="empty" and not empty.readonly,"independent storage begins empty")
 var id=nonce();adapter.test_drop_next_ack=true
 var lost=await adapter.create_run(0,2,"safe",false,id)
 check(not lost.ok and lost.retryable,"create committed but lost response stays pending")
 var created=await adapter.create_run(0,2,"safe",false,id)
 check(created.ok and created.run_id==id and created.revision==0 and created.slot==1,"same create retry acknowledges one stable identity")
 var loaded=await adapter.read_active();check(loaded.ok and loaded.snapshot==created.snapshot,"full schema13 World roundtrip")
 var candidate=World.from_snapshot(created.snapshot);check(candidate.step(Vector2i.RIGHT),"candidate makes legal move")
 var operation=nonce();adapter.test_drop_next_ack=true
 lost=await adapter.commit_run(created.slot,0,id,candidate.save_data(),operation)
 check(not lost.ok and lost.retryable,"save response lost after durable commit")
 var saved=await adapter.commit_run(created.slot,0,id,candidate.save_data(),operation)
 check(saved.ok and saved.revision==1 and saved.snapshot==candidate.save_data(),"same save retry returns original commit not double action")
 var stale=await adapter.commit_run(created.slot,0,id,created.snapshot,nonce())
 check(not stale.ok and stale.readonly and stale.status=="conflict","stale revision cannot overwrite current world")
 var before=saved.snapshot.duplicate(true);candidate.step(Vector2i.LEFT)
 adapter.native.test_fail_at="before_rename"
 var failed=await adapter.commit_run(saved.slot,1,id,candidate.save_data(),nonce())
 check(not failed.ok and failed.retryable,"write failure reported without success")
 adapter.native.test_fail_at=""
 loaded=await adapter.read_active();check(loaded.ok and loaded.snapshot==before,"failed write preserves previous full world")
 var other=Store.new(path);var busy=await other.read_active()
 check(not busy.ok and busy.readonly and busy.reason=="WRITER_BUSY","second process owner cannot acquire active writer")
 var newer=await adapter.create_run(42,2,"safe",true,nonce())
 check(newer.ok and newer.slot==2,"explicit replacement publishes fresh run once")
 var old_retry=await adapter.commit_run(saved.slot,0,id,before,operation)
 check(not old_retry.ok and old_retry.readonly,"old operation retry cannot reactivate superseded run")
 var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema11-layout1.json"))
 var invalid=await adapter.commit_run(newer.slot,0,newer.run_id,legacy,nonce())
 check(not invalid.ok,"legacy payload cannot be grafted onto eligible new run")
 var different=candidate.save_data();different.run_id=newer.run_id
 invalid=await adapter.commit_run(newer.slot,0,id,different,nonce())
 check(not invalid.ok,"storage key and snapshot identity must agree")
 # Production adapter deliberately supports only active safe-mode payloads.
 # A risk World is valid in the model but must not enter this storage batch.
 var risk=World.new(42,2,newer.run_id,"risk").save_data()
 check(World.from_snapshot(risk)!=null,"risk negative fixture is a valid World, not malformed data")
 for unsupported in [risk, newer.snapshot.duplicate(true)]:
  if unsupported.mode=="safe":unsupported.ended_reason="withdrawn"
  var rejected=await adapter.commit_run(newer.slot,0,newer.run_id,unsupported,nonce())
  check(not rejected.ok and rejected.readonly,"adapter rejects unsupported mode or sealed payload on write")
  var direct=adapter.native.save_journey(newer.run_id,adapter.auth,0,unsupported,nonce())
  check(not direct.ok,"native store independently rejects unsupported mode or sealed payload")
  var fake_read={"ok":true,"slotRevision":newer.slot,"run":{"id":newer.run_id,"status":"active","revision":0,"snapshot":unsupported}}
  check(not adapter._normalize(fake_read).ok,"adapter rejects unsupported mode or sealed payload on read")
  var container=adapter.native.read().data.duplicate(true)
  container.runs[newer.run_id].snapshot=unsupported
  check(not adapter.native._valid(container),"native container rejects tampered active mode/ended metadata")
 loaded=await adapter.read_active()
 check(loaded.ok and loaded.snapshot==newer.snapshot,"all rejected unsupported writes preserve active safe snapshot")
 # Frozen test clock separates lease semantics from CPU/filesystem speed. Real
 # 60-second production leases and default-clock roundtrips above stay unchanged.
 var live=Store.new("user://journeys-v1-test-lease-"+nonce())
 var clocked=ClockedStore.new(live.path)
 clocked.delay_ms=maxi(0,int(OS.get_environment("TOWER_TEST_STORAGE_DELAY_MS")))
 live.native=clocked
 var live_run=await live.create_run(0,2,"safe",false,nonce())
 if not require_ok(live_run,"clocked run setup"):return
 var shortened=clocked.renewWriter(live.auth,80)
 if not require_ok(shortened,"clocked short lease setup"):return
 live.auth=shortened.auth.duplicate(true)
 var original_expiry:int=int(live.auth.leaseUntil)
 OS.delay_msec(150) # Deliberately exceed 80ms wall time; only explicit logical advances expire the lease.
 var live_world=World.from_snapshot(live_run.snapshot)
 if live_world==null or not live_world.step(Vector2i.RIGHT):
  require_ok({"ok":false},"clocked candidate setup");return
 # Opt-in negative harness proves a rejected prerequisite exits promptly, not nil/hang.
 if OS.get_environment("TOWER_TEST_EXPIRE_BEFORE_WRITE")=="1":clocked.now_ms=original_expiry
 live_run=await live.commit_run(live_run.slot,live_run.revision,live_run.run_id,live_world.save_data(),nonce())
 if not require_ok(live_run,"first clocked commit"):return
 check(int(live.auth.leaseUntil)==clocked.now_ms+60000,"successful write renews lease inside the same transaction")
 clocked.now_ms=original_expiry+1
 if not live_world.step(Vector2i.LEFT):
  require_ok({"ok":false},"second clocked candidate setup");return
 live_run=await live.commit_run(live_run.slot,live_run.revision,live_run.run_id,live_world.save_data(),nonce())
 if not require_ok(live_run,"second clocked commit"):return
 check(live_run.ok,"continuous writes survive the original short lease expiry")
 shortened=clocked.renewWriter(live.auth,60)
 if not require_ok(shortened,"clocked expiry setup"):return
 live.auth=shortened.auth.duplicate(true)
 clocked.now_ms=int(live.auth.leaseUntil) # Boundary is expired at equality, not just after.
 var stale_world=World.from_snapshot(live_run.snapshot)
 if stale_world==null or not stale_world.step(Vector2i.RIGHT):
  require_ok({"ok":false},"expired candidate setup");return
 var expired=await live.commit_run(live_run.slot,live_run.revision,live_run.run_id,stale_world.save_data(),nonce())
 check(not expired.ok and expired.readonly and expired.reason=="STALE_WRITER","expired writer cannot silently reclaim and overwrite")
 var reacquired=await live.reacquire_and_read()
 if not require_ok(reacquired,"clocked explicit reacquisition"):return
 check(reacquired.snapshot==live_run.snapshot,"explicit reacquire reads actual latest state, not stale candidate")
 var silent=Store.new("user://journeys-v1-test-timeout-"+nonce());silent.web_bridge=SilentBridge.new();silent.web_timeout_seconds=0.01
 var timeout=await silent._web("read",{})
 check(not timeout.ok and timeout.code=="WEB_TIMEOUT" and silent.web_pending.is_empty(),"missing callback completes with bounded retryable uncertainty")
 silent._on_web_reply([JSON.stringify({"request":1,"result":{"ok":true}})])
 check(silent.web_pending.is_empty(),"late callbacks cannot publish or accumulate expired requests")
 print("SESSION STORAGE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
