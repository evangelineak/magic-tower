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
 for reward in ["medicine","retrain"]:
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema9-"+reward+".json"))
  check(w.restore(old) and w.expedition_revision==2 and w.winch_choice=="" and not w.maul_claimed,"old begun revision2 gains no new room or reward")
  var upgraded=state(w); upgraded.erase("winch_choice"); upgraded.erase("maul_claimed"); upgraded.erase("layout_revision"); upgraded.version=9
  for field in ["attunement_version","gear_offers","gear_choices","run_id","mode","ended_reason","death_record","draft","talent_draft","last_kill_kind","legacy_points","legacy_reserves","cargo","rope"]: upgraded.erase(field)
  check(JSON.parse_string(JSON.stringify(upgraded))==old,"migration conserves solved audit/anchors/oath/NPC resources: "+reward)
  reject(w,"winch_rescue"); reject(w,"winch_armory"); restore_check(w)
 w=World.new(0,1)
 check(replay(w,Generator.validate(w.floors,1).route) and w.won,"actual first chapter wins")
 var victory=state(w)
 var legacy=victory.duplicate(true); legacy.version=9; legacy.erase("winch_choice"); legacy.erase("maul_claimed")
 check(w.restore(legacy) and w.action("expedition") and w.expedition_revision==3,"old unstarted chapter explicitly generates revision3")
 var begun=state(w)
 # Grow naturally through chapter two, stopping before final Z to take branches.
 var route_ok=true
 for c in Expedition.validate(w.floors.slice(5),1).route:
  var d:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
  if w.tile(w.pos+d)=="Z": break
  if not w.step(d): route_ok=false; break
 check(route_ok and travel(w,6) and walk(w,Vector2i(7,4)),"real grown character returns to winch")
 var at_winch=state(w)
 reject(w,"winch_unknown")
 for tile_pos in [Vector2i(8,1),Vector2i(8,4),Vector2i(9,4)]:
  var bad=at_winch.duplicate(true); bad.x=tile_pos.x; bad.y=tile_pos.y
  check(not w.restore(bad) and state(w)==at_winch,"cannot load inside locked gate or uncollected armory pickup")
 check(walk(w,Vector2i(9,2)) and walk(w,Vector2i(7,4)),"actual guard-first route returns to untouched winch")
 reject(w,"winch_rescue")
 check(w.winch_offers().size()==1 and w.winch_offers()[0][0]=="winch_armory","dead guard cannot sell now-useless rescue choice")
 check(walk(w,Vector2i(9,1)) and walk(w,Vector2i(7,4)),"already rescued Mira can return to winch")
 reject(w,"winch_rescue")
 check(w.action("winch_armory") and walk(w,Vector2i(9,4)) and w.maul_claimed,"guard-first rescue still permits useful armory reward")
 w.restore(at_winch)
 for branch in ["rescue","armory"]:
  w.restore(at_winch); var before=state(w)
  check(w.action("winch_"+branch) and w.winch_choice==branch,"one permanent winch choice: "+branch)
  var opened=state(w); restore_check(w)
  reject(w,"winch_rescue"); reject(w,"winch_armory")
  check(w.restore(before) and w.winch_choice=="" and w.restore(opened),"winch undo restores both closed routes")
  if branch=="rescue":
   var hp_before=w.hp; var kills_before=w.kills; var gold_before=w.gold
   check(walk(w,Vector2i(9,1)) and w.rescue_state==2 and w.tile(Vector2i(9,2))=="W","north route rescues Mira while gaoler remains alive")
   check(w.hp==hp_before and w.kills==kills_before and w.gold==gold_before and not w.inventory.has("maul") and not walk(w,Vector2i(9,4)),"rescue bypass spends no combat resources but permanently loses maul")
   restore_check(w)
  else:
   check(walk(w,Vector2i(9,4)) and w.maul_claimed and w.inventory.has("maul") and w.equipped=="maul","armory route actually collects and equips unique maul")
   restore_check(w)
   var inventory_before=w.inventory.duplicate(); check(w.step(Vector2i.LEFT) and w.step(Vector2i.RIGHT) and w.inventory==inventory_before,"revisiting empty armory cannot duplicate weapon")
   check(w.action("equip_balanced") and walk(w,Vector2i(9,2)) and walk(w,Vector2i(9,1)) and w.rescue_state==2,"armory branch still fights gaoler to rescue Mira")
  var rescued=state(w)
  check(travel(w,0) and walk(w,Vector2i(1,2)) and w.action("rescue_repeater"),"either rescue route can return Mira home for separate gear")
  if branch=="armory":
   # Chest fixture is a source-validation check, distinct from real path proof.
   var earned=state(w); w.inventory.append("buckler"); w.chest_claimed=true
   restore_check(w); check(w.inventory.size()==4,"balanced plus chest plus rescue plus armory persist as independent sources"); w.restore(earned)
  check(w.action("equip_balanced") and travel(w,7) and walk(w,Vector2i(8,3)) and w.won,"actual "+branch+" branch completes final battle")
  print("WINCH REAL ",branch,": ",w.moves," moves; ",w.hp," HP")
  w.restore(rescued)
  var valid=state(w)
  for patch in [{"winch_choice":"both"},{"maul_claimed":"yes"},{"expedition_revision":2},{"maul_claimed":not w.maul_claimed}]:
   var bad=valid.duplicate(true); bad.merge(patch,true)
   check(not w.restore(bad) and state(w)==valid,"invalid winch/weapon source rejects atomically")
 # Controlled positional combat uses real H positions on actual revision3 maps.
 w.restore(begun)
 var target=Vector2i.ZERO
 for y in range(1,10):
  for x in range(1,10):
   if w.tile(Vector2i(x,y))=="H": target=Vector2i(x,y)
 for gear in ["balanced","buckler","duelist","repeater","maul"]:
  for oath in ["fresh","active"]:
   w.restore(begun); w.pos=target+Vector2i.RIGHT; w.inventory=["balanced"] if gear=="balanced" else ["balanced",gear]; w.equipped=gear; w.oath_state=oath; w.atk=100; w.defense=30; w.hp=1200; w.skill_armed=true
   var before=state(w); var ordinary=w.battle_preview("H"); var preview=w.battle_preview("H",gear,target)
   check(not ordinary.flank_active and preview.flank_active and preview.first_strike_suppression=="flank" and preview.flank_blocked>0 and preview.oath_blocked==0,"explicit east approach grants one ambush suppression, no oath double credit: "+gear+oath)
   check(state(w)==before and w.step(Vector2i.LEFT) and w.hp==1200-int(preview.damage)+int(preview.heal_after) and w.last_battle.damage==preview.damage,"actual step uses the exact positional preview once: "+gear+oath)
   w.restore(before); w.pos=target+Vector2i.LEFT
   check(not w.battle_preview("H",gear,target).flank_active,"west approach cannot claim east flank")
 w.restore(begun); w.pos=target+Vector2i.RIGHT
 check(not w.battle_preview("H","",target+Vector2i.UP).flank_active,"wrong target cell cannot fabricate positional benefit")
 w.expedition_revision=2
 check(not w.battle_preview("H","",target).flank_active,"old chapter revision has no new positional rule")
 # Two-step UI confirmation; cancellation, F2 and modal behavior cannot spend choice.
 var scene=load("res://main.tscn").instantiate(); Fixture.prepare(scene); root.add_child(scene); await process_frame
 scene.growth=false
 await Fixture.bind(scene,World.from_snapshot(at_winch))
 var before=state(scene.world)
 await scene.perform_action("winch_armory")
 check(scene.winch_pending=="winch_armory" and state(scene.world)==before,"winch first click only requests confirmation")
 key(scene,KEY_F2)
 check(scene.winch_pending=="winch_armory" and state(scene.world)==before,"F2 preserves pending irreversible choice")
 await scene.perform_action("winch_cancel")
 check(scene.winch_pending=="" and state(scene.world)==before,"cancel commits nothing")
 await scene.perform_action("winch_rescue"); await scene.perform_action("winch_confirm")
 check(scene.world.winch_choice=="rescue" and scene.history.size()==1,"explicit confirmation commits exactly one reversible history entry")
 await scene.undo(); check(state(scene.world)==before,"controller undo restores original winch state")
 scene.world=World.from_snapshot(begun); scene.world.pos=target+Vector2i.RIGHT; scene.world.atk=100; scene.world.hp=1000; scene.hover=target; scene.interaction=false; scene.battle_time=0
 await Fixture.bind(scene,scene.world)
 scene.open_comparison()
 check(scene.comparison_rows()[0].preview.flank_active,"V passes actual hovered position into shared preview")
 # Presentation-only five-row fixture exercises paging without claiming five gear sources are legal.
 var original_inventory=scene.world.inventory.duplicate()
 scene.close_comparison() # Synthetic inventory changes require a fresh modal, like a Session publish.
 scene.world.inventory=["balanced","buckler","duelist","repeater","maul"]
 scene.open_comparison()
 key(scene,KEY_BRACKETRIGHT); key(scene,KEY_F2)
 check(scene.compare_page==1 and scene.comparison and scene.comparison_rows().size()==5,"comparison paging and F2 retain the fifth presented equipment row")
 scene.world.inventory=original_inventory
 scene.comparison=false; var forecast=scene.world.battle_preview("H","",target)
 await scene.move(Vector2i.LEFT)
 check(scene.battle_details.flank_active and scene.battle_details.damage==forecast.damage and scene.world.last_battle.damage==forecast.damage,"animation snapshots actual resolved position, not post-move recomputation")
 var active_snapshot=state(scene.world)
 var old_text=FileAccess.get_file_as_string("res://tests/fixtures/schema9-retrain.json")
 var legacy_path="user://winch-flank-test.json"
 var file=FileAccess.open(legacy_path,FileAccess.WRITE); file.store_string(old_text); file.close()
 await scene.load_game()
 check(FileAccess.get_file_as_string(legacy_path)==old_text and state(scene.world)==active_snapshot,"L preserves schema9 bytes and reads current registered run instead")
 var old_world=World.new(); check(old_world.restore(JSON.parse_string(old_text)) and old_world.expedition_revision==2 and old_world.audit_reward=="retrain" and not old_world.reward_eligible(),"World legacy audit migration does not spawn new rooms or award identity")
 scene.queue_free(); await process_frame
 print("WINCH FLANK: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
