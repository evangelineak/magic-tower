extends SceneTree
const Fixture=preload("res://tests/ui_fixture.gd")
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
const Progression=preload("res://scripts/progression.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func state(w)->Dictionary: return w.save_data().duplicate(true)
func reject(w,id:String):
 var before=state(w)
 check(not w.action(id) and state(w)==before,"rejected without mutation: "+id)
func restore_check(w):
 var copy=World.new(0,1)
 check(copy.restore(JSON.parse_string(JSON.stringify(state(w)))) and state(copy)==state(w),"legal rescue state JSON roundtrip")
func replay(w,route:String)->bool:
 for c in route:
  if not w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]): return false
 return true
func walk(w,goal:Vector2i)->bool:
 if w.pos==goal: return true
 var queue:Array=[[w.pos,[]]]; var seen:Dictionary={w.pos:true}
 while not queue.is_empty():
  var row:Array=queue.pop_front(); var p:Vector2i=row[0]
  if p==goal:
   for d in row[1]:
    if not w.step(d): return false
   return true
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d
   if seen.has(n): continue
   var token:String=w.tile(n)
   if token in ["#","L","D"]: continue
   if token=="n" and w.winch_choice!="rescue": continue
   if token=="e" and w.winch_choice!="armory": continue
   if token=="m" and n!=goal: continue
   if token=="=" and not w.expedition_bridge: continue
   if token=="~" and not w.bridge_built and w.water_choice!="drain": continue
   if token in ["<",">","W","Z","K","V","t"] and n!=goal: continue
   if World.ENEMIES.has(token) and (w.damage(token)<0 or w.damage(token)>=w.hp): continue
   seen[n]=true; var path:Array=row[1].duplicate(); path.append(d); queue.append([n,path])
 return false
func travel(w,floor_id:int)->bool:
 for i in range(12):
  if w.floor_index==floor_id: return true
  if not walk(w,Vector2i(1,1) if w.floor_index>floor_id else Vector2i(9,9)): return false
 return false
func key(scene,code):
 var event=InputEventKey.new(); event.pressed=true; event.keycode=code; await scene._unhandled_input(event)
func _initialize(): call_deferred("run_tests")
func run_tests():
 var old_text=FileAccess.get_file_as_string("res://tests/fixtures/schema6-expedition.json")
 var old=JSON.parse_string(old_text)
 var w=World.new(0,1)
 check(old.version==6 and w.restore(old),"genuine pre-change schema6 fixture loads")
 check(w.expedition_revision==1 and w.rescue_state==0 and w.rescue_reward=="" and w.floors==old.floors,"old active expedition preserves maps and grants no quest progress")
 w.enter_floor(0); w.pos=Vector2i(1,2); reject(w,"rescue_accept"); reject(w,"rescue_repeater")
 check(w.npc_offers().is_empty(),"old revision cannot accept impossible new chain")
 restore_check(w)
 w=World.new(0,1); check(w.step(Vector2i.DOWN),"fresh hero walks to Ilen rather than teleporting")
 check(w.action("rescue_accept") and w.rescue_state==1 and w.quest_state==0,"Ilen rescue and old survey are independent")
 reject(w,"rescue_accept"); restore_check(w)
 # Actual first chapter witness starts at the original entrance after a legal detour.
 check(walk(w,Vector2i(1,1)) and replay(w,Generator.validate(w.floors,1).route) and w.won,"real accepted quest survives first chapter victory")
 var victory=state(w)
 for version in [4,5,6]:
  var legacy=victory.duplicate(true); legacy.version=version
  var copy=World.new(0,1)
  check(copy.restore(JSON.parse_string(JSON.stringify(legacy))) and copy.rescue_state==0 and copy.expedition_revision==0,"legacy unstarted chapter resets absent quest: "+str(version))
  check(copy.action("expedition") and copy.expedition_revision==3,"legacy unstarted chapter explicitly receives fresh content")
 check(w.action("expedition") and w.expedition_revision==3,"new expedition opts into rescue content")
 var begun=state(w)
 # Follow the guaranteed route until the final boss, then return to optional rescue.
 var proof=Expedition.validate(w.floors.slice(5),1); var route_ok=true; var first_guard_loss=-1; var first_guard_hp=-1
 for c in proof.route:
  var d:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
  if w.tile(w.pos+d)=="Z": break
  if w.floor_index==6 and first_guard_hp<0:
   first_guard_loss=w.damage("W"); first_guard_hp=w.hp
  if not w.step(d): route_ok=false; break
 check(route_ok and w.floor_index==7 and not w.won,"real route grows on floor eight without ending before rescue")
 print("RESCUE FIRST 7F: hp=",first_guard_hp," W loss=",first_guard_loss,"; after 8F hp=",w.hp," W loss=",w.damage("W"))
 check(travel(w,6) and walk(w,Vector2i(9,2)),"actual return defeats optional seventh-floor guard")
 var before_rescue=state(w)
 check(walk(w,Vector2i(9,1)) and w.rescue_state==2 and w.tile(Vector2i(9,1))==".","walking into guarded cell rescues Mira once")
 restore_check(w)
 var rescued=state(w)
 w.restore(before_rescue); w.rescue_state=0
 check(walk(w,Vector2i(9,1)) and w.rescue_state==2,"unaccepted quest permits discovering and rescuing Mira")
 w.restore(rescued)
 check(w.restore(before_rescue) and w.rescue_state==1 and w.restore(rescued),"rescue undo restores NPC and progress together")
 reject(w,"rescue_repeater"); reject(w,"rescue_supplies")
 check(travel(w,0) and walk(w,Vector2i(1,2)),"rescued Mira actually travels back to first-floor Ilen")
 var home=state(w)
 check(w.action("rescue_repeater") and w.rescue_state==3 and w.rescue_reward=="repeater" and w.equipped=="repeater" and not w.chest_claimed,"home reward adds equipment independently of relic chest")
 restore_check(w); reject(w,"rescue_repeater"); reject(w,"rescue_supplies")
 var gear_reward=state(w)
 check(w.restore(home) and not w.inventory.has("repeater") and w.rescue_state==2,"reward undo removes gear and restores choice")
 w.restore(gear_reward)
 check(w.action("equip_balanced"),"choose balanced equipment again for the long final fight")
 check(travel(w,7) and walk(w,Vector2i(8,3)) and w.won,"real rescue homecoming reward route still wins final chapter")
 print("RESCUE REAL ROUTE: ",w.moves," moves; ",w.hp," HP")
 reject(w,"rescue_repeater"); reject(w,"rescue_supplies"); reject(w,"rescue_accept")
 # Supplies branch starts at same legitimately rescued state, then targeted resources test exact economics.
 w.restore(rescued); check(travel(w,5) and walk(w,Vector2i(2,2)),"Mira can instead reach camp by real walking")
 w.camp_medicine_left=0; w.camp_focus_left=1; w.gold=5; w.loan_used=true; w.principal=30; w.fees=2; w.interest=8; w.checkpoints=2; w.overdue=true
 var before=state(w)
 check(w.action("rescue_supplies") and w.camp_medicine_left==1 and w.camp_focus_left==2 and w.gold==5 and w.debt()==0,"camp reward adds finite stock and forty gold repays overdue debt first")
 check(w.loan_used and w.checkpoints==2 and not w.inventory.has("repeater"),"camp reward cannot reset loan history or give gear")
 restore_check(w); reject(w,"rescue_supplies"); reject(w,"rescue_repeater")
 check(w.restore(before) and state(w)==before,"camp reward undo restores entire ledger and stocks")
 w.action("rescue_supplies"); w.gold=500; var hp_before=w.hp
 check(w.action("camp_medicine") and w.hp==hp_before+140 and w.gold==430 and w.camp_medicine_left==0,"expanded stock remains a paid one-use medicine")
 reject(w,"camp_medicine")
 # Both chest-before-quest and quest-before-chest sources must persist correctly.
 for first in [true,false]:
  w.restore(home)
  if first: w.inventory.append("buckler"); w.chest_claimed=true
  check(w.action("rescue_repeater"),"quest gear after independent chest source")
  if not first: w.inventory.append("duelist"); w.chest_claimed=true
  restore_check(w)
  check(w.inventory.size()==3,"balanced plus exactly one chest and one quest equipment")
 var valid=state(w)
 for patch in [{"rescue_state":4},{"rescue_state":2},{"rescue_reward":"supplies"},{"expedition_revision":1},{"camp_medicine_left":3}]:
  var bad=valid.duplicate(true); bad.merge(patch,true)
  check(not w.restore(bad) and state(w)==valid,"inconsistent quest/source/save rejects atomically")
 # Independent arithmetic for new gear versus real compound guard.
 for gear in ["balanced","buckler","duelist","repeater"]:
  var attack:int=90+Progression.GEAR[gear].atk; var defense:int=35+Progression.GEAR[gear].def
  var per_hit:int=attack-48+(8 if gear=="duelist" else 0)
  var rounds:int=ceili(260.0/per_hit); var hit:int=maxi(68-defense,0)
  var normal:int=maxi(rounds-(3 if gear=="repeater" else 1),0)
  var retaliation:int=normal+(1 if gear=="duelist" else 0)
  var raw:int=hit*(retaliation+retaliation/3)+rounds*6
  var expected:int=raw-(hit if gear=="buckler" and retaliation>0 else 0)
  var result=Progression.battle(90,35,1000,World.ENEMIES.W,"warden",false,gear,[])
  check(result.damage==expected and result.retaliations==retaliation,"independent thorns + heavy gear arithmetic: "+gear)
  w.restore(rescued); w.floors[6][2][9]="W"; w.rescue_state=1; w.floors[6][1][9]="t"; w.pos=Vector2i(9,3); w.hp=1000; w.atk=90; w.defense=35; w.inventory=["balanced"] if gear=="balanced" else ["balanced",gear]; w.equipped=gear
  before=state(w)
  check(w.battle_preview("W").damage==expected and state(w)==before and w.step(Vector2i.UP) and w.hp==1000-expected,"guard preview and actual deduction agree: "+gear)
 w.restore(rescued); w.floors[6][2][9]="W"; w.rescue_state=1; w.floors[6][1][9]="t"; w.pos=Vector2i(9,3); w.atk=90; w.defense=35; w.inventory=["balanced","repeater"]; w.equipped="repeater"; w.skill_armed=true
 w.hp=int(w.battle_preview("W").damage); before=state(w)
 check(not w.step(Vector2i.UP) and state(w)==before,"lethal compound battle consumes no focus, guard, HP or quest progress")
 var ambush={"hp":10,"atk":30,"def":0,"first_strike":true,"thorns":6,"heavy_every":3}
 var ambush_result=Progression.battle(50,20,5000,ambush,"warden",false,"repeater",[])
 check(ambush_result.damage==22 and ambush_result.retaliations==0 and ambush_result.thorns_damage==6 and ambush_result.first_strike_damage==16,"repeater one-shot still pays ambush and thorns, with no heavy counter")
 w.restore(rescued); w.enter_floor(5); w.pos=Vector2i(2,2)
 check(w.action("rescue_supplies") and w.camp_medicine_left==3 and w.camp_focus_left==3,"untouched camp expands to exactly three each")
 restore_check(w); reject(w,"rescue_supplies")
 var short_enemy={"hp":100,"atk":30,"def":0}
 var long_enemy={"hp":1000,"atk":30,"def":0}
 check(Progression.battle(50,20,5000,short_enemy,"warden",false,"repeater",[]).damage<Progression.battle(50,20,5000,short_enemy,"warden",false,"balanced",[]).damage,"repeater has genuine short-fight advantage")
 check(Progression.battle(50,20,5000,long_enemy,"warden",false,"repeater",[]).damage>Progression.battle(50,20,5000,long_enemy,"warden",false,"balanced",[]).damage,"repeater low defense loses in long fights")
 var scene=load("res://main.tscn").instantiate(); Fixture.attach(scene); root.add_child(scene); await process_frame
 await Fixture.bind(scene,World.from_snapshot(gear_reward)); scene.growth=true; scene.growth_tab=1
 # Four rows are deliberately a presentation fixture, not a legal inventory claim.
 scene.world.inventory=["balanced","buckler","duelist","repeater"]
 check(scene.visible_growth_actions().size()==3,"gear first page caps at three rows")
 key(scene,KEY_BRACKETRIGHT)
 check(scene.visible_growth_actions().size()==1 and scene.visible_growth_actions()[0][0]=="equip_repeater","second equipment page exposes fourth gear")
 before=state(scene.world); key(scene,KEY_F2)
 check(scene.gear_page==1 and state(scene.world)==before,"language switch preserves gear page and game state")
 check(scene.enemy_traits({"first_strike":true,"thorns":6,"heavy_every":3}).size()==3,"all simultaneous enemy traits display independently")
 # Legacy files are no longer imported into eligible Session identities.
 await Fixture.bind(scene,World.from_snapshot(gear_reward))
 var legacy_path="user://rescue-schema6-test.json"
 var file=FileAccess.open(legacy_path,FileAccess.WRITE); file.store_string(old_text); file.close()
 before=state(scene.world); var durable=Fixture.snapshot(scene)
 await scene.load_game()
 check(FileAccess.get_file_as_string(legacy_path)==old_text and state(scene.world)==before and Fixture.snapshot(scene)==durable,"L loads active slot and never imports or overwrites old expedition bytes")
 DirAccess.remove_absolute(legacy_path)
 scene.queue_free(); await process_frame
 print("RESCUE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
