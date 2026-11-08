extends SceneTree
# Production native storage, isolated per run. Legal World actions are batched
# into one same-identity CAS checkpoint, not fabricated rewards or per-step I/O.
const World=preload("res://scripts/world.gd")
const Session=preload("res://scripts/session.gd")
const Store=preload("res://scripts/session_storage.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
const DIRECTIONS={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func normalized(value):return JSON.parse_string(JSON.stringify(value))
func nonce()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
func ledger(session)->Dictionary:return session.adapter.native.read().data.profile.profile.duplicate(true)
func state(session)->Dictionary:return session.world.save_data().duplicate(true)
func follow(w,route:String,stop_floor:int=-1):
 for direction in route:
  check(w.step(DIRECTIONS[direction]),"legal real route movement")
  if stop_floor>=0 and w.floor_index==stop_floor:return
func checkpoint(session,w):
 check(w.run_id==session.world.run_id and w.reward_eligible(),"route clone belongs to this newly registered run")
 var committed=await session.adapter.commit_run(session.slot,session.revision,w.run_id,w.save_data(),nonce())
 check(committed.ok,"legal route checkpoint uses current native slot/run CAS")
 var loaded=await session.open_current()
 check(loaded.ok and state(session)==w.save_data(),"Session reload fully validates checkpoint without reassigning identity")
func settled(session,outcome:String,peak:int,count:int):
 var before=state(session)
 var result=await session.finish(outcome)
 check(result.ok and result.committed and session.terminal and not session.read_only,"explicit terminal commit publishes only on native success")
 check(session.history.is_empty(),"settlement clears undo history")
 var expected={"seed":int(before.seed_value),"max_floor":peak,"moves":int(before.moves),"outcome":outcome}
 check(session.receipt.run_id==before.run_id and normalized(session.receipt.summary)==normalized(expected),"receipt summary comes from actual completed route")
 var current=ledger(session)
 check(current.receipts.size()==count and normalized(current.receipts[before.run_id])==normalized(session.receipt),"one authoritative ledger receipt for this run")
 var disk_before=session.adapter.native.read().data
 var terminal_before=state(session)
 check(not (await session.finish(outcome)).ok,"repeated explicit finish is terminal, not a second payout")
 check(not (await session.finish("withdrawn" if outcome!="withdrawn" else "chapter1")).ok,"conflicting outcome cannot replace terminal receipt")
 check(not (await session.undo()).ok and not (await session.step(Vector2i.RIGHT)).ok and not (await session.action("expedition")).ok,"terminal cannot undo, walk or continue chapter")
 check(state(session)==terminal_before and session.adapter.native.read().data==disk_before,"terminal retries change neither world nor durable ledger")
 var recovered=Session.new(session.adapter)
 check((await recovered.open_current()).ok and recovered.terminal and state(recovered)==terminal_before and normalized(recovered.receipt)==normalized(session.receipt),"new Session restores archived state and receipt, never auto-creates run")
func _initialize():call_deferred("run")
func run():
 var path="user://journeys-v1-test-routes-"+nonce()
 var session=Session.new(Store.new(path))
 var opened=await session.open_current()
 check(not opened.ok and opened.status=="empty","isolated native ledger starts genuinely empty")
 var proof=Generator.generate(0,World.MAPS).validation.route
 # Route A: actually visit floor 3, then voluntarily retire. No boss shortcut.
 check((await session.new_run(0)).ok,"create first genuine session identity")
 var first_id=session.world.run_id
 var w=World.from_snapshot(state(session));follow(w,proof,2)
 check(w.floor_index==2 and w.highest_seen_floor()==3 and not w.won,"first run reaches real third floor, not forged seen flags")
 await checkpoint(session,w)
 await settled(session,"withdrawn",3,1)
 check(normalized(ledger(session).milestones)==normalized([3]) and ledger(session).unlocked==["legacy_scout"],"third-floor retirement awards only reached milestone")
 var retained=ledger(session)
 # Route B: real K defeat then explicit first-chapter ending.
 check((await session.new_run(0)).ok and session.world.run_id!=first_id,"explicit replay creates fresh identity after settlement")
 check(ledger(session)==retained and not session.terminal,"new game preserves all previously earned ledger entries")
 check(session.world.strategy_pending() and (await session.choose_strategy("none")).ok,"earned pool requires explicit original strategy before replay route")
 w=World.from_snapshot(state(session));follow(w,proof)
 check(w.won and not w.expedition_started and w.ended_reason=="" and not w.chapter_offers().is_empty(),"K is resumable, not an automatic terminal payout")
 await checkpoint(session,w)
 check(ledger(session)==retained,"reaching K alone issues no receipt or milestone")
 await settled(session,"chapter1",5,2)
 check(session.receipt.milestones==[5] and ledger(session).unlocked==["legacy_scout","legacy_tactician"],"first-chapter finish adds only previously unearned milestone")
 retained=ledger(session)
 # Route C: K -> explicit continuation -> legal expedition witness -> Z.
 check((await session.new_run(0)).ok,"third real session starts")
 check(session.world.strategy_pending() and (await session.choose_strategy("none")).ok,"earned pool requires explicit original strategy before replay route")
 w=World.from_snapshot(state(session));follow(w,proof)
 await checkpoint(session,w)
 check((await session.action("expedition")).ok,"K continuation is committed by Session action")
 check(ledger(session)==retained and not session.terminal and not session.world.won,"continuation grants no cross-run reward and remains active")
 var expedition_route:String=Expedition.generate(0).witness
 w=World.from_snapshot(state(session));follow(w,expedition_route.substr(0,expedition_route.length()-1))
 await checkpoint(session,w)
 check(not session.world.won and (await session.step(DIRECTIONS[expedition_route[-1]])).ok,"final Z hit is a real Session action with durable Undo history")
 check(session.world.won and session.world.floor_index==7 and session.world.highest_seen_floor()==8 and session.world.ended_reason=="" and session.history.size()==1,"actual Z victory awaits settlement with real preceding action history")
 check(ledger(session)==retained,"Z alone still does not double-credit a run")
 await settled(session,"victory",8,3)
 check(session.receipt.milestones==[8] and ledger(session).unlocked==["legacy_scout","legacy_tactician","legacy_veteran"],"final victory adds only final milestone")
 retained=ledger(session)
 check((await session.new_run(42)).ok and ledger(session)==retained and session.history.is_empty(),"post-victory new seed preserves profile without restoring terminal undo")
 print("SETTLEMENT ROUTES: %d checks, failures=%d; real native store=%s"%[checks,failures,path])
 quit(1 if failures else 0)
