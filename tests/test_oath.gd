extends SceneTree
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
const Fixture=preload("res://tests/ui_fixture.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
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
  var stair=Vector2i(1,1) if w.floor_index>floor_id else Vector2i(9,9)
  if w.pos==stair:
   if not w.step(Vector2i.RIGHT if stair.x==1 else Vector2i.LEFT): return false
  if not walk(w,stair): return false
 return false
func key(scene,code):
 var event=InputEventKey.new(); event.pressed=true; event.keycode=code; scene._unhandled_input(event)
func _initialize(): call_deferred("run_tests")
func run_tests():
 var w=World.new(0,1)
 reject(w,"oath_accept"); reject(w,"oath_renounce")
 for name in ["expedition","repeater","supplies"]:
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema7-"+name+".json"))
  check(w.restore(old) and w.oath_state=="fresh","real old schema7 state upgrades with fresh oath: "+name)
  var now=state(w); now.erase("oath_state"); now.version=7
  for field in ["travel_anchors","audit_puzzle","audit_read","audit_solved","audit_reward","winch_choice","maul_claimed","layout_revision","attunement_version","gear_offers","gear_choices","run_id","mode","ended_reason","death_record"]: now.erase(field)
  check(JSON.parse_string(JSON.stringify(now))==old,"migration preserves all old resources, maps, NPC choices, inventory: "+name)
  restore_check(w)
  if name=="supplies": check(w.camp_medicine_left==3 and w.camp_focus_left==3,"old earned camp expansion is not clamped to two")
 w=World.new(0,1)
 for version in [4,5,6,7]:
  var old=state(w); old.version=version; old.erase("oath_state")
  var copy=World.new(0,1)
  check(copy.restore(JSON.parse_string(JSON.stringify(old))) and copy.oath_state=="fresh","old schema migration: "+str(version))
 # Controlled combat matrix isolates gear, armed skills and oath from route economics.
 for gear in ["balanced","buckler","duelist","repeater"]:
  for kind in ["H","b","w"]:
   w=World.new(0,1); w.inventory=["balanced"] if gear=="balanced" else ["balanced",gear]; w.equipped=gear
   w.oath_state="active"; w.hp=1500; w.atk=80; w.defense=30; w.skill_armed=true
   w.floors[0][1][2]=kind
   var before=state(w); var preview=w.battle_preview(kind)
   check(preview.valid and preview.oath_active and w.battle_preview(kind,gear)==preview and state(w)==before,"owned override inherits identical live context: "+gear+kind)
   check(not w.battle_preview(kind,"missing").valid and state(w)==before,"unowned comparison cannot borrow gear")
   check(w.step(Vector2i.RIGHT) and w.hp==1500-int(preview.damage)+int(preview.heal_after) and w.focus==int(before.focus)-1,"oath gear actual loss/focus equals preview: "+gear+kind)
 w=World.new(0,1); w.floor_seen=[true,true,true,true,false]; w.enter_floor(3); w.pos=Vector2i(1,3); w.skill_armed=true
 var before=state(w)
 check(w.action("oath_accept") and w.oath_state=="active","bind only at inscription")
 restore_check(w); reject(w,"oath_accept")
 var active=state(w)
 check(w.action("oath_renounce") and w.oath_state=="spent","release at inscription without fee")
 for field in ["hp","atk","def","gold","focus","focus_cap","skill_armed","inventory","talents","floors"]:
  check(state(w)[field]==active[field],"release changes no resource or combat preparation: "+field)
 reject(w,"oath_accept"); reject(w,"oath_renounce"); restore_check(w)
 check(w.restore(active) and w.oath_state=="active" and w.restore(before) and w.oath_state=="fresh","undo restores oath state and complete world")
 var valid=state(w)
 for value in [true,2,"watch",null]:
  var bad=valid.duplicate(true); bad.oath_state=value
  check(not w.restore(bad) and state(w)==valid,"malformed oath rejects atomically")
 # A real run chooses oath for the expedition's ambushers, then returns to N
 # to give up its protection permanently before the heavily armoured finale.
 w=World.new(0,1)
 check(replay(w,Generator.validate(w.floors,1).route) and w.action("expedition"),"fresh real route reaches expedition")
 check(travel(w,3) and walk(w,Vector2i(1,3)) and w.action("oath_accept"),"real cross-chapter detour binds oath")
 check(travel(w,5),"real return enters expedition through stairs")
 var proof=Expedition.validate(w.floors.slice(5),1); var route_ok=true; var ambushes=0
 for c in proof.route:
  var d:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
  var token=w.tile(w.pos+d)
  if token=="Z": break
  if token=="H":
   ambushes+=1
   check(w.battle_preview(token).first_strike_suppressed,"real oath cancels each expedition ambush")
  if not w.step(d): route_ok=false; break
 check(route_ok and ambushes==3 and w.floor_index==7,"real oath route defeats all three H crossings")
 check(travel(w,3) and walk(w,Vector2i(1,3)) and w.action("oath_renounce"),"real return to N permanently releases oath")
 check(travel(w,7) and walk(w,Vector2i(8,3)) and w.won and w.oath_state=="spent","released oath route returns to Z and wins")
 print("OATH REAL ROUTE: ",w.moves," moves; ",w.hp," HP")
 var scene=load("res://main.tscn").instantiate(); Fixture.prepare(scene); root.add_child(scene); await process_frame
 scene.growth=false
 scene.world=World.new(0,1); scene.world.inventory=["balanced","buckler"]; scene.world.chest_claimed=true; scene.world.oath_state="active"; scene.world.skill_armed=true
 scene.world.atk=50; scene.world.defense=15; scene.world.hp=500; scene.hover=Vector2i(4,3)
 await Fixture.bind(scene,scene.world)
 await scene.save_game(); var disk=Fixture.snapshot(scene); before=state(scene.world); var events=scene.sound_event_count; var history=scene.history.duplicate(true)
 key(scene,KEY_V)
 check(scene.comparison and scene.comparison_rows().size()==2,"V opens only real hovered enemy and owned equipment")
 for row in scene.comparison_rows():
  check(row.preview==scene.world.battle_preview("s",row.id) and row.preview.oath_active,"V uses exactly live oath and armed preview")
 for code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_1,KEY_U,KEY_R,KEY_L,KEY_E,KEY_C,KEY_H,KEY_J,KEY_SPACE]: key(scene,code)
 key(scene,KEY_F2)
 check(scene.comparison and state(scene.world)==before and scene.history==history and scene.sound_event_count==events and Fixture.snapshot(scene)==disk,"comparison modal blocks gameplay with no state/history/save/audio changes; F2 keeps it open")
 key(scene,KEY_ESCAPE); check(not scene.comparison,"Esc closes forecast")
 scene.hover=Vector2i(2,2); key(scene,KEY_V); check(not scene.comparison,"empty tile cannot open fabricated enemy comparison")
 scene.hover=Vector2i(4,3); scene.world.atk=1; key(scene,KEY_V)
 check(scene.comparison_rows()[0].after_hp==-1 and not scene.comparison_rows()[0].preview.valid,"unbreakable armor shows unavailable post HP")
 scene.world.atk=80; scene.world.hp=1; scene.world.oath_state="fresh"; scene.world.skill_armed=false; scene.world.talents=["iron_skin","trained_focus","battle_medic"]
 scene.compare_pos=Vector2i(4,3); scene.world.floors[0][3][4]="H"
 check(scene.comparison_rows()[0].preview.valid and not scene.comparison_rows()[0].preview.survivable and scene.comparison_rows()[0].after_hp==-1,"lethal forecast cannot apply post-victory recovery to survive")
 # Legacy files are kept untouched. L reads only the registered active slot.
 var old_text=FileAccess.get_file_as_string("res://tests/fixtures/schema7-supplies.json")
 var legacy_path="user://oath-readonly-test.json"
 var file=FileAccess.open(legacy_path,FileAccess.WRITE); file.store_string(old_text); file.close()
 await scene.load_game()
 check(FileAccess.get_file_as_string(legacy_path)==old_text and state(scene.world)==before,"L reloads registered active slot without importing or rewriting schema7 file")
 var old_world=World.new(); check(old_world.restore(JSON.parse_string(old_text)) and old_world.camp_medicine_left==3 and old_world.oath_state=="fresh" and not old_world.reward_eligible(),"World keeps legacy finite supplies and original oath without eligible identity")
 scene.queue_free(); await process_frame
 print("OATH: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
