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
func only_navigation(before:Dictionary,after:Dictionary)->bool:
 var b=before.duplicate(true); var a=after.duplicate(true)
 for field in ["floor","x","y","moves"]: b.erase(field); a.erase(field)
 return a==b and after.moves==before.moves+1
func _initialize(): call_deferred("run_tests")
func run_tests():
 var w=World.new(0,1)
 for reward in ["repeater","supplies"]:
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema8-"+reward+".json"))
  check(w.restore(old) and w.travel_anchors.is_empty() and not w.audit_read and not w.audit_solved and w.audit_reward=="","old seen floors do not create anchors or audit rewards")
  var upgraded=state(w)
  for field in ["travel_anchors","audit_puzzle","audit_read","audit_solved","audit_reward","winch_choice","maul_claimed","layout_revision","attunement_version","gear_offers","gear_choices","run_id","mode","ended_reason","death_record","draft","talent_draft","last_kill_kind"]: upgraded.erase(field)
  upgraded.version=8
  check(JSON.parse_string(JSON.stringify(upgraded))==old,"real old oath/NPC/stock state completely preserved: "+reward)
  reject(w,"fast_travel_3:1:3"); restore_check(w)
 var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema8-supplies.json"))
 w.restore(old)
 check(w.step(Vector2i.DOWN) and w.travel_anchors.is_empty(),"walking near N alone does not register landmark")
 check(w.step(Vector2i.UP) and w.travel_anchors.size()==1,"actually touching N registers exact landmark")
 var anchor_id:String=w.travel_options()[0].id
 reject(w,"fast_travel_"+anchor_id)
 check(travel(w,5) and walk(w,Vector2i(2,2)),"actual cleared stairs route reaches and touches camp")
 check(w.travel_anchors.size()>=2 and w.travel_options().any(func(row):return row.id==anchor_id and row.reachable),"registered old inscription is safely reachable from camp")
 w.skill_armed=true
 var camp=state(w)
 check(w.action("fast_travel_"+anchor_id) and only_navigation(camp,state(w)),"fast travel changes only exact location and one move, no resources or side effects")
 restore_check(w)
 check(w.restore(camp) and state(w)==camp,"whole-state undo returns to camp and retains anchor discoveries")
 # Block every exit from current tile; every proof must be recomputed from live map.
 for token in ["#","D","L","H","k","h","a","~","="]:
  w.restore(camp); w.expedition_bridge=false; w.bridge_built=false; w.water_choice=""
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var p=w.pos+d; w.floors[w.floor_index][p.y][p.x]=token
  reject(w,"fast_travel_"+anchor_id)
 w.restore(camp); w.won=true; reject(w,"fast_travel_"+anchor_id)
 w=World.new(0,1); reject(w,"fast_travel_0:1:2")
 w.restore(camp); var valid=state(w)
 for huge in [4294967296,4294967297,1e100]:
  for field in ["floor","x","y","marker_x","marker_y"]:
   var bad=valid.duplicate(true); bad.travel_anchors[0][field]=huge
   check(not w.restore(bad) and state(w)==valid,"overflowing anchor coordinate rejected atomically: "+field)
 # Audit is a local logical deduction, not a resource-paying random roll.
 w.restore(camp)
 check(w.audit_lines().is_empty() and w.audit_journal().is_empty(),"unread audit reveals no clues or solution")
 check(walk(w,Vector2i(4,2)),"walk away from audit desk")
 reject(w,"audit_read")
 check(walk(w,Vector2i(2,3)),"walk to engineering desk")
 check(w.action("audit_read") and w.audit_lines().size()==4 and w.audit_offers().size()==3,"reading gives complete public logic and three hypotheses")
 var read_state=state(w); reject(w,"audit_read"); reject(w,"audit_guess_3")
 var answers:Array=[]
 for candidate in range(3):
  var truths=0
  for claim in w.audit_puzzle.claims:
   if (int(claim.box)==candidate)==claim.positive: truths+=1
  if truths==int(w.audit_puzzle.truth_count): answers.append(candidate)
 check(answers.size()==1,"independent enumeration of displayed claims yields one solution")
 var solution:int=answers[0]
 var before=state(w)
 check(w.action("audit_guess_"+str((solution+1)%3)) and not w.audit_solved and only_navigation(before,state(w)),"wrong deduction changes only move, never HP/focus/gold/debt")
 check(w.restore(read_state) and w.action("audit_guess_"+str(solution)) and w.audit_solved and w.audit_lines().size()==8,"correct deduction reveals proof and persists")
 var solved=state(w); restore_check(w); reject(w,"audit_guess_"+str(solution))
 check(w.talents.is_empty(),"real branch has not spent its earned talent choices")
 reject(w,"audit_retrain")
 check(w.audit_reward=="" and w.action("talent_keen_edge") and w.action("talent_trained_focus") and w.action("talent_battle_medic"),"declined empty retrain preserves reward; actual earned tiers can be chosen")
 before=state(w)
 check(w.action("audit_retrain") and w.talents.is_empty() and w.audit_reward=="retrain","one retrain clears talent choices")
 for field in ["hp","focus","skill_armed","gold","kills","principal","fees","interest","oath_state"]:
  check(state(w)[field]==before[field],"retrain does not refund or change "+field)
 check(w.action("talent_iron_skin") and w.action("talent_last_stand") and w.action("talent_giant_slayer"),"retained kill thresholds permit all originally earned tiers")
 reject(w,"audit_retrain"); reject(w,"audit_medicine"); restore_check(w)
 check(w.restore(before) and state(w)==before,"undo restores old talent choices and unspent reward")
 w.restore(solved); var hp_before=w.hp
 check(w.action("audit_medicine") and w.hp==hp_before+140 and w.audit_reward=="medicine","alternative reward is exactly 140 immediate HP")
 reject(w,"audit_retrain"); reject(w,"audit_medicine"); restore_check(w)
 var claimed=state(w)
 for patch in [{"audit_read":false},{"audit_solved":false},{"audit_reward":"other"}]:
  var bad=claimed.duplicate(true); bad.merge(patch,true)
  check(not w.restore(bad) and state(w)==claimed,"inconsistent audit claims reject atomically")
 # UI snapshots may be cached, but a confirmation never authorizes stale routing.
 var scene=load("res://main.tscn").instantiate(); Fixture.prepare(scene); root.add_child(scene); await process_frame
 scene.growth=false
 await Fixture.bind(scene,World.from_snapshot(camp))
 var ui_camp=state(scene.world)
 await scene.save_game()
 var disk=Fixture.snapshot(scene); var sound=scene.sound_event_count; var history=scene.history.duplicate(true); before=state(scene.world)
 key(scene,KEY_T)
 var index=-1
 for i in scene.visible_travel_options().size():
  if scene.visible_travel_options()[i].id==anchor_id: index=i
 check(scene.travel_menu and index>=0,"T offers actually registered return anchor")
 scene.select_travel(index)
 check(scene.travel_pending==anchor_id and state(scene.world)==before,"selection only requests confirmation")
 var refreshes=scene.travel_refresh_count
 for frame in range(3):
  scene.queue_redraw(); await process_frame
 check(scene.travel_refresh_count==refreshes,"repeated rendered frames reuse cached route proofs")
 for code in [KEY_F2,KEY_BRACKETRIGHT,KEY_BRACKETLEFT,KEY_UP,KEY_1,KEY_C,KEY_E,KEY_H,KEY_J,KEY_V,KEY_U,KEY_R,KEY_L]: key(scene,code)
 check(scene.travel_menu and scene.travel_pending==anchor_id and scene.travel_refresh_count==refreshes and state(scene.world)==before and scene.sound_event_count==sound and scene.history==history and Fixture.snapshot(scene)==disk,"pending modal blocks gameplay; F2 does not recompute or change state")
 for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
  var p=scene.world.pos+d; scene.world.floors[scene.world.floor_index][p.y][p.x]="#"
 var blocked=state(scene.world); await scene.confirm_travel()
 check(state(scene.world)==blocked and scene.travel_pending=="","stale cached reachable option is refused after live route becomes blocked")
 scene.world.restore(ui_camp); scene.close_travel(); scene.open_travel(); scene.select_travel(index); await scene.confirm_travel()
 check(only_navigation(ui_camp,state(scene.world)),"confirmed safe return commits exactly navigation delta")
 await scene.undo(); check(state(scene.world)==ui_camp,"controller undo restores whole pre-travel state")
 # L never imports an unrelated legacy journey into the eligible active run.
 var old_text=FileAccess.get_file_as_string("res://tests/fixtures/schema8-repeater.json")
 var legacy_path="user://travel-audit-test.json"
 var file=FileAccess.open(legacy_path,FileAccess.WRITE); file.store_string(old_text); file.close()
 await scene.load_game()
 check(FileAccess.get_file_as_string(legacy_path)==old_text and state(scene.world)==ui_camp,"L preserves v8 bytes and reloads only registered active slot")
 var old_world=World.new(); check(old_world.restore(JSON.parse_string(old_text)) and old_world.oath_state=="active" and old_world.travel_anchors.is_empty() and old_world.inventory.has("repeater") and not old_world.reward_eligible(),"World legacy migration preserves oath/reward but invents neither anchor visits nor identity")
 scene.language="en"; scene.world.restore(camp)
 check(not str(scene.journal_lines()).contains("Label A:"),"journal hides unread audit statements")
 scene.world.restore(read_state); scene.interaction=true
 check(scene.available_actions().any(func(row): return row[0]=="audit_guess_0") and scene.available_actions().any(func(row): return row[0]=="audit_guess_2"),"engineering interaction exposes all three displayed hypotheses")
 check(str(scene.journal_lines()).contains("Label A:") and not str(scene.journal_lines()).contains("Only box"),"read journal exposes evidence but not hidden solution")
 scene.world.restore(solved)
 check(str(scene.journal_lines()).contains("Only box") and scene.available_actions().any(func(row): return row[0]=="audit_retrain") and scene.available_actions().any(func(row): return row[0]=="audit_medicine"),"solved journal explains unique solution and offers mutually exclusive rewards")
 scene.queue_free(); await process_frame
 print("TRAVEL AUDIT: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
