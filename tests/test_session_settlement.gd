extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func nonce()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
func fresh():return Store.new("user://journeys-v1-test-settle-"+nonce())
func _initialize():call_deferred("run")
func replay(w,route:String)->bool:
 for c in route:
  if not w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]):return false
 return true
func run():
 var store=fresh();var active=await store.create_run(0,2,"safe",false,nonce())
 var original=store.native.read().data
 for bad in ["chapter1","victory","defeat","invalid"]:
  var rejected=await store.settle_run(active.slot,active.revision,active.run_id,bad,nonce())
  check(not rejected.ok and store.native.read().data==original,"invalid outcome never grants or seals")
 for point in ["after_profile","after_archive","after_slot","before_temp","after_temp","after_backup","before_rename"]:
  store.native.test_fail_at=point
  var failed=await store.settle_run(active.slot,active.revision,active.run_id,"withdrawn",nonce())
  store.native.test_fail_at=""
  check(not failed.ok,"fault fails at "+point)
  check(store.native.read().data==original,"all fields rollback at "+point)
 var op=nonce();store.test_drop_next_ack=true
 var lost=await store.settle_run(active.slot,active.revision,active.run_id,"withdrawn",op)
 check(not lost.ok and lost.retryable,"lost settlement response remains retryable")
 var settled=await store.settle_run(active.slot,active.revision,active.run_id,"withdrawn",op)
 check(settled.ok and settled.status=="archived" and settled.eligible and settled.readonly,"archived response is eligible terminal not active")
 check(settled.slot==active.slot+1 and settled.revision==active.revision+1 and settled.snapshot.ended_reason=="retired","one atomic end and both revisions")
 check(Store.Profile._summary(settled.receipt.summary)=={"seed":0,"max_floor":1,"moves":0,"outcome":"withdrawn"} and settled.profile.receipts.size()==1,"summary derives real stored World")
 var again=await store.settle_run(active.slot,active.revision,active.run_id,"withdrawn",op)
 check(again==settled,"same settlement acknowledges exact result")
 var reopened=Store.new(store.path);reopened.owner=store.owner
 var read=await reopened.read_active()
 check(read.ok and read.status=="archived" and read.snapshot==settled.snapshot and read.receipt==settled.receipt,"new adapter restart reads terminal and receipt")
 var restart_retry=await reopened.settle_run(active.slot,active.revision,active.run_id,"withdrawn",op)
 check(restart_retry.ok and restart_retry.revision==settled.revision,"restart duplicate does not grant twice")
 var bad_outcome=await reopened.settle_run(active.slot,active.revision,active.run_id,"chapter1",op)
 check(not bad_outcome.ok,"same nonce conflicting outcome rejected")
 var denied=await reopened.commit_run(settled.slot,settled.revision,active.run_id,active.snapshot,nonce())
 check(not denied.ok,"archived run cannot be unsealed by save")
 var data=reopened.native.read().data
 for variant in ["missing","wrong_summary","unsealed","active_receipt"]:
  var damaged=data.duplicate(true)
  match variant:
   "missing":damaged.profile.profile.receipts.clear()
   "wrong_summary":damaged.profile.profile.receipts[active.run_id].summary.moves+=1
   "unsealed":damaged.runs[active.run_id].snapshot.ended_reason=""
   "active_receipt":damaged.runs[active.run_id].status="active"
  check(not reopened.native._valid(damaged),"corrupt archive/receipt rejected: "+variant)
 for field in ["expected_slot","expected_revision","result_slot","result_revision"]:
  for value in [true,"1",1.5,1e100,-2]:
   var damaged=data.duplicate(true);damaged.runs[active.run_id].last_op[field]=value
   check(not reopened.native._valid(damaged),"malformed op counter rejected "+field)
 var damaged=data.duplicate(true);damaged.runs[active.run_id].last_op.hash="x".repeat(64)
 check(not reopened.native._valid(damaged),"nonhex operation hash rejected")
 damaged=data.duplicate(true);damaged.runs[active.run_id].last_op.extra=1
 check(not reopened.native._valid(damaged),"unknown operation field rejected")
 var replacement=await reopened.create_run(1,2,"safe",true,nonce())
 check(replacement.ok,"explicit new journey after archive")
 denied=await reopened.settle_run(active.slot,active.revision,active.run_id,"withdrawn",op)
 check(not denied.ok and denied.reason=="SUPERSEDED_OPERATION","old archived request cannot replace newer active slot")
 var ambiguous=fresh();var a=await ambiguous.create_run(0,2,"safe",false,nonce());var once=nonce()
 ambiguous.native.test_fail_at="after_rename"
 var no_ack=await ambiguous.settle_run(a.slot,a.revision,a.run_id,"withdrawn",once)
 check(not no_ack.ok and no_ack.retryable,"actual rename succeeded but acknowledgement failed")
 ambiguous.native.test_fail_at=""
 var acknowledged=await ambiguous.settle_run(a.slot,a.revision,a.run_id,"withdrawn",once)
 check(acknowledged.ok and acknowledged.revision==1 and acknowledged.profile.receipts.size()==1,"actual ambiguous rename retries one receipt")
 var rival=Store.new(ambiguous.path)
 var busy=await rival.read_active();check(not busy.ok and busy.reason=="WRITER_BUSY","second window cannot steal archived writer")
 var shortened=ambiguous.native.renewWriter(ambiguous.auth,50);check(shortened.ok,"short lease setup")
 OS.delay_msec(80)
 var takeover=await rival.reacquire_and_read();check(takeover.ok and takeover.status=="archived","new writer reads actual terminal after expiry")
 var stale_writer=await ambiguous.settle_run(a.slot,a.revision,a.run_id,"withdrawn",once)
 check(not stale_writer.ok and stale_writer.reason=="STALE_WRITER","old fence cannot use duplicate settlement to bypass takeover")
 # Actual legal route, without fixture stat/map injection, reaches K and then Z.
 var world=World.new(0,2,nonce(),"safe")
 check(replay(world,Generator.generate(0,World.MAPS).validation.route),"actual K witness")
 for outcome in ["chapter1","victory"]:
  if outcome=="victory":
   check(world.action("expedition"),"K can continue without automatic settlement")
   check(replay(world,Expedition.generate(0).validation.route),"actual Z witness")
  var branch=fresh();var created=await branch.create_run(0,2,"safe",false,world.run_id)
  var saved=await branch.commit_run(created.slot,created.revision,world.run_id,world.save_data(),nonce())
  check(saved.ok,"store actual witness state "+outcome)
  var result=await branch.settle_run(saved.slot,saved.revision,world.run_id,outcome,nonce())
  check(result.ok and result.receipt.summary.max_floor==(5 if outcome=="chapter1" else 8),"correct actual victory summary "+outcome)
  check(result.profile.milestones==([3,5] if outcome=="chapter1" else [3,5,8]),"only reached milestones "+outcome)
  check(World.from_snapshot(result.snapshot)!=null,"terminal full payload valid "+outcome)
 print("SESSION SETTLEMENT: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
