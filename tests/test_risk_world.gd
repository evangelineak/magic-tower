extends SceneTree
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const ID="risk_world_test_000001"
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func state(w)->Dictionary:return w.save_data().duplicate(true)
func fixture(mode:String="risk"):
 var w=W.new(0,2,ID,mode)
 # Controlled low-HP snapshot at a real authored adjacent enemy, without map edits.
 w.pos=Vector2i(4,2);w.hp=1
 check(W.from_snapshot(state(w))!=null,"synthetic test fixture passes full production restore")
 return w
func rejected(w,delta:Vector2i):
 var before=state(w)
 check(not w.lethal_fight(delta) and state(w)==before,"invalid lethal attempt cannot mutate saved state")
func _init():
 var w=fixture("safe");rejected(w,Vector2i.DOWN)
 w=fixture();var before=state(w)
 check(not w.step(Vector2i.DOWN) and state(w)==before,"risk ordinary movement still refuses lethal fight")
 check(not w.finish_run("defeat") and state(w)==before,"finish_run cannot turn a living player into defeat")
 for delta in [Vector2i.ZERO,Vector2i(1,1),Vector2i(0,2),Vector2i.LEFT]:rejected(w,delta)
 w.hp=280;rejected(w,Vector2i.DOWN)
 w.hp=1;w.atk=1;rejected(w,Vector2i.DOWN)
 for armed in [false,true]:
  w=fixture();w.skill_armed=armed;before=state(w)
  var expected=w.battle_timeline(w.pos+Vector2i.DOWN)
  check(expected.valid and expected.fatal,"bounded timeline confirms actual fatal event")
  check(w.lethal_fight(Vector2i.DOWN),"explicit risk confirmation executes fatal prefix")
  check(w.hp==0 and w.ended_reason=="death" and not w.won and w.moves==int(before.moves)+1,"death ends only risk run")
  check(w.pos==Vector2i(4,2) and w.tile(Vector2i(4,3))=="s" and w.kills==before.kills and w.gold==before.gold,"death neither moves nor deletes enemy nor awards kill/gold")
  check(w.last_battle==expected.merged({"enemy":"s"},true) and w.last_battle.damage==1 and w.last_battle.heal_after==0,"actual event prefix retained without imaginary victory or heal")
  check(w.focus==int(before.focus)-(1 if armed else 0) and not w.skill_armed,"real committed battle skill consumes focus at opening")
  for key in before:
   if key in ["hp","ended_reason","moves","death_record","focus","skill_armed"]:continue
   check(state(w)[key]==before[key],"death leaves unrelated saved field unchanged: "+key)
  var dead=state(w);var restored=W.from_snapshot(JSON.parse_string(JSON.stringify(dead)))
  check(restored!=null and state(restored)==dead and restored.last_battle==w.last_battle,"death restore recomputes actual timeline and preserves exact state")
  check(w.settlement_summary("defeat").summary=={"seed":0,"max_floor":1,"moves":1,"outcome":"defeat"},"only actual death derives defeat summary")
  check(not w.step(Vector2i.UP) and not w.action("arm") and not w.finish_run("withdrawn") and not w.finish_run("defeat") and w.safe_walk_path(Vector2i(5,2)).is_empty(),"terminal cannot act, retire as survivor or undo via World action")
  rejected(w,Vector2i.DOWN)
  for patch in [{"mode":"safe"},{"hp":1},{"won":true},{"moves":0},{"death_record":{}},{"ended_reason":"retired"},{"version":13},{"skill_armed":true}]:
   var bad=dead.duplicate(true);bad.merge(patch,true)
   var receiver=fixture();var untouched=state(receiver)
   check(not receiver.restore(bad) and state(receiver)==untouched,"invalid death patch rejects atomically: "+str(patch))
  for patch in [{"x":1},{"enemy":"Z"},{"start_hp":1000000},{"extra":1},{"skill_armed":"yes"},{"floor":4294967296},{"x":INF},{"start_hp":true}]:
   var bad=dead.duplicate(true);bad.death_record.merge(patch,true)
   var receiver=fixture();var untouched=state(receiver)
   check(not receiver.restore(bad) and state(receiver)==untouched,"invalid record rejects atomically: "+str(patch))
 # An armed flag without available focus is not secretly charged on reload.
 w=fixture();w.skill_armed=true;w.focus=0
 check(w.lethal_fight(Vector2i.DOWN) and w.focus==0 and w.skill_armed and W.from_snapshot(state(w))!=null,"no available focus means no skill consumed or fabricated on restore")
 # Genuine fresh run, no HP/map/position setup: decline stat pickups and
 # approach the second-floor briar guard with insufficient remaining life.
 w=W.new(0,2,ID,"risk")
 for symbol in "DRDDDLDDRRRRRRRRDDLLLLUULL":
  check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[symbol]),"real fresh risk route legal step")
 check(w.floor_index==1 and w.pos==Vector2i(3,7) and w.hp==268 and w.atk==18 and w.defense==8,"actual resource/route choices produce lethal briar encounter")
 before=state(w)
 check(not w.step(Vector2i.LEFT) and state(w)==before,"real risky route still requires explicit confirmation")
 check(w.lethal_fight(Vector2i.LEFT) and w.hp==0 and w.tile(Vector2i(2,7))=="b" and w.gold==before.gold and w.kills==before.kills,"real encounter stops on fatal without kill reward")
 check(W.from_snapshot(state(w))!=null and w.settlement_summary("defeat").summary.max_floor==2,"actual defeat survives full restore with real exploration peak")
 # Real pre-schema14 active and archived journeys keep their identity and ledger semantics.
 for name in ["schema13-active-store.json","schema13-archived-store.json"]:
  var envelope=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name))
  var data=JSON.parse_string(envelope.payload)
  var old:Dictionary=data.runs[data.slot.activeRunId].snapshot
  var migrated=W.from_snapshot(old)
  check(migrated!=null and migrated.run_id==old.run_id and migrated.mode==old.mode and migrated.ended_reason==old.ended_reason and migrated.death_record.is_empty(),"real schema13 keeps identity/mode/end without invented death")
  var normalized=JSON.parse_string(JSON.stringify(state(migrated)))
  for key in old:
   if key=="version":continue
   check(normalized[key]==old[key],"schema13 field unchanged: "+key)
  if old.ended_reason!="":
   var receipt=data.profile.profile.receipts[old.run_id]
   check(JSON.parse_string(JSON.stringify(migrated.settlement_summary(receipt.summary.outcome).summary))==receipt.summary,"schema13 archived receipt still derives same summary")
 print("RISK WORLD: %d checks, failures=%d"%[checks,failures])
 quit(1 if failures else 0)
