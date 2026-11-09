extends SceneTree
const W=preload("res://scripts/world.gd")
const P=preload("res://scripts/progression.gd")
const S=preload("res://scripts/legacy_strategy.gd")
const L=preload("res://scripts/legacy_points.gd")
const G=preload("res://scripts/generation.gd")
const ID="legacy_points_world_0001"
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func state(w)->Dictionary:return w.save_data().duplicate(true)
func _init():
 for capacity in range(4):
  var pool:Array=[] if capacity==0 else S.IDS.slice(0,capacity+3)
  var w=W.new(0,2,ID,"safe",false,pool)
  check(w.legacy_points==L.allocate(capacity) and w.legacy_reserves==0,"new capacity follows actual birth pool and has no free allocated points")
  check(w.strategy_pending()==(capacity>0),"empty pool skips setup, earned capacity waits for explicit setup")
  check(W.from_snapshot(JSON.parse_string(JSON.stringify(state(w)))).save_data()==state(w),"pending points normalize JSON integers")
 var w=W.new(0,2,ID,"safe",false,S.IDS)
 var initial=state(w)
 var preview=w.setup_preview("none",{"study":2,"reserve":1})
 check(preview.valid and preview.capacity==3 and preview.remaining==0 and preview.reserve_remaining==1 and preview.skill_level_info.legacy==4 and state(w)==initial,"setup previews allocation without spending or changing combat")
 for study in range(3):
  var all_heroes=w.setup_preview("none",{"study":study,"reserve":0})
  check(all_heroes.hero_effects=={"warden_block_percent":35+5*study,"ranger_ignore_def":10+2*study,"scholar_heal":80+10*study},"all three hero setup effects follow actual inherited level")
  for hero in ["warden","ranger","scholar"]:
   check(all_heroes.hero_skill_descriptions[hero]==P.skill_description(hero,[],"none","none",study),"all hero descriptions come from real progression functions")
 check(state(w)==initial,"three hero previews are read only")
 # Controlled high-level preview fixture, not a legal newborn training state.
 var cap_preview=W.new(0,2,ID,"safe",false,S.IDS)
 while "study" not in cap_preview.draft.offers:
  cap_preview=W.new(cap_preview.seed_value+1,2,ID,"safe",false,S.IDS)
 cap_preview.talents=["iron_skin","trained_focus"]
 cap_preview.equipped="buckler";cap_preview.inventory.append("buckler")
 cap_preview.gear_choices["buckler"]="focus_deep"
 var capped=cap_preview.setup_preview("study",{"study":2,"reserve":0})
 check(capped.skill_level_info.raw==24 and capped.skill_level_info.overflow==4,"preview explicitly reports raw level and overflow")
 check(capped.hero_effects=={"warden_block_percent":60,"ranger_ignore_def":20,"scholar_heal":130},"all three hero effects use capped level rather than raw overflow")
 for allocation in [{"study":2,"reserve":2},{"study":true,"reserve":0},{"study":-1,"reserve":0},{"study":1},{"study":1,"reserve":0,"extra":1}]:
  check(not w.choose_strategy("none",allocation) and state(w)==initial,"invalid allocation cannot partly lock strategy")
 check(not w.action("legacy_focus") and state(w)==initial,"pending setup cannot consume supplies")
 check(w.choose_strategy("none",{"study":2,"reserve":1}) and w.moves==0 and w.atk==18 and w.defense==8 and w.legacy_reserves==1,"one atomic explicit choice sets points and finite supply without base-stat edits")
 var before=state(w)
 check(not w.choose_strategy("none",{"study":0,"reserve":0}) and state(w)==before,"allocation cannot be revised after lock even before movement")
 check(w.action("legacy_focus") and w.focus==3 and w.legacy_reserves==0 and w.moves==1,"emergency supply adds one focus and consumes exactly one charge/move")
 check(W.from_snapshot(state(w))!=null,"consumed supply roundtrip validates")
 check(w.restore(before) and w.focus==2 and w.legacy_reserves==1 and w.moves==0,"whole-state undo restores spent supply and focus together")
 w.focus=w.focus_cap;before=state(w)
 check(not w.action("legacy_focus") and state(w)==before,"full focus never consumes reserve or move")
 w.focus=0;check(w.action("legacy_focus") and w.focus==1 and w.legacy_reserves==0,"supply works at empty focus")
 before=state(w);check(not w.action("legacy_focus") and state(w)==before,"exhausted reserve is not reusable")
 # Exact ownership, pool capacity and pending-state invariants, with raw JSON types.
 for patch in [{"version":true},{"capacity":2},{"study":3},{"reserve":3},{"extra":1}]:
  var bad=initial.duplicate(true);bad.legacy_points.merge(patch,true)
  var receiver=W.from_snapshot(initial)
  check(not receiver.restore(bad) and state(receiver)==initial,"malformed points reject atomically")
 for amount in [true,-1,1,3,1.5,INF,{},[]]:
  var bad=initial.duplicate(true);bad.legacy_reserves=amount
  check(W.from_snapshot(bad)==null,"pending or malformed remaining supply rejected")
 # Legacy reserve does not pay a battle cost or turn defeat into recovery.
 w=W.new(0,2,ID,"risk",false,S.IDS)
 check(w.choose_strategy("none",{"study":1,"reserve":2}) and w.action("legacy_focus"),"risk setup spends one finite supply before genuine route")
 for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":
  check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"real risk route with allocated finite supplies")
 before=state(w)
 check(w.lethal_fight(Vector2i.LEFT) and w.legacy_reserves==1 and w.focus==before.focus,"fatal fight neither auto-uses reserve nor grants recovery")
 var dead=state(w)
 check(W.from_snapshot(JSON.parse_string(JSON.stringify(dead))).save_data()==dead,"death replay preserves precise immutable points and remaining supply")
 check(not w.action("legacy_focus") and state(w)==dead,"supply cannot resurrect terminal run")
 # Genuine pre17 journeys keep all prior state and receive no retrospective points.
 for name in ["schema16-active.json","schema16-death.json"]:
  var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name))
  var restored=W.from_snapshot(old)
  check(restored!=null and restored.legacy_points==L.legacy() and restored.legacy_reserves==0,"old real journey receives zero capacity regardless existing strategy")
  if restored==null:continue
  var now=JSON.parse_string(JSON.stringify(state(restored)))
  for key in old:
   if key!="version":check(now[key]==old[key],"legacy gameplay conserved: "+key)
 # Controlled policy, real map actions: arm Brace whenever focus is available.
 # This is a deterministic route comparison, not a proof all allocations balance.
 var results=[]
 for study in range(3):
  w=W.new(0,2,ID,"safe",false,S.IDS);w.choose_strategy("none",{"study":study,"reserve":0})
  for c in G.generate(0,W.MAPS).validation.route:
   var delta:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
   if W.ENEMIES.has(w.tile(w.pos+delta)) and w.focus>0 and not w.skill_armed:check(w.action("arm"),"real route arms affordable Brace")
   check(w.step(delta),"real route still solves with finite optional study")
  check(w.won,"each study rank reaches actual K under fixed skill-use policy")
  results.append({"study":study,"hp":w.hp,"moves":w.moves,"focus":w.focus})
 print("LEGACY POINTS ROUTE COMPARISON: ",JSON.stringify(results))
 print("LEGACY POINTS WORLD: %d checks, failures=%d"%[checks,failures])
 quit(1 if failures else 0)
