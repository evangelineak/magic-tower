extends SceneTree
const W=preload("res://scripts/endless_world_v20.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var starts=0
 var failing=false
 var snapshot={}
 func read():return {"ok":true,"revision":revision,"snapshot":snapshot,"records":[]}
 func start_hero(data,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  snapshot=data.duplicate(true);revision+=1;writes+=1;starts+=1;return read()
 func commit(data,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  snapshot=data.duplicate(true);revision+=1;writes+=1;return read()
 func start(data,r):return await start_hero(data,r)
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 ui.world=load("res://scripts/endless_world_v19.gd").new_run(7);ui.modal=""
 var old=ui.world.save_data();await ui.start_run(42)
 check(ui.modal=="hero_setup" and ui.hero_setup_seed==42 and ui.world.save_data()==old and memory.starts==0,"prepare fixed seed without replacing old journey")
 await ui.confirm_hero_setup()
 check(memory.starts==0 and "选择" in ui.modal_notice,"no implicit hero on Enter")
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_2;await ui._unhandled_input(key)
 check(ui.hero_setup_selection=="ranger" and ui.hero_setup_seed==42,"selection leaves seed fixed")
 key.keycode=KEY_ESCAPE;await ui._unhandled_input(key)
 check(ui.world.save_data()==old and ui.modal=="" and memory.starts==0,"cancel retains old journey")
 await ui.start_run(42);ui.hero_setup_selection="ranger";memory.failing=true;await ui.confirm_hero_setup()
 check(ui.world.save_data()==old and ui.modal=="hero_setup" and ui.hero_setup_seed==42,"failed atomic start retains old journey and same pending seed")
 memory.failing=false;await ui.confirm_hero_setup()
 check(ui.world.hero_view().id=="ranger" and ui.world.actions==["hero_ranger"] and memory.starts==1,"successful atomic hero start records exactly one setup event")
 await ui.confirm_hero_setup();check(memory.starts==1,"repeat confirmation cannot restart active journey")
 ui.open_build();check(ui.build_tab=="hero" and ui.choices.size()>0,"B provides skill actions without new HUD button")
 var writes=memory.writes;var skill_before=ui.world.save_data();memory.failing=true;await ui.transact("act","skill_use")
 check(ui.world.save_data()==skill_before and not ui.world.hero_view().armed,"failed skill commit cannot arm or spend visible resources")
 memory.failing=false;await ui.transact("act","skill_use")
 check(ui.world.hero_view().armed and ui.modal=="build" and memory.writes==writes+1,"skill prepares and stays in build panel")
 await ui.transact("act","skill_cancel")
 check(not ui.world.hero_view().armed,"skill cancellation shown from actual state")
 key.keycode=KEY_TAB;await ui._unhandled_input(key)
 check(ui.build_tab=="tactic" and ui.world.hero_view().id=="ranger","tactic tab does not alter hero identity")
 ui.queue_redraw();await process_frame
 for id in ["warden","ranger","scholar"]:
  var candidate=W.new_run(1);candidate.act("hero_"+id);ui.world=candidate;ui.build_tab="hero";ui.open_build()
  check(ui.world.hero_view().id==id and not ui.world.hero_view().focus_recovery.is_empty(),"all identities and recovery explanation supplied by actual API")
  ui.queue_redraw();await process_frame
 ui.world.hp=180;writes=memory.writes;await ui.transact("act","skill_use")
 check(ui.world.hp==180 and memory.writes==writes,"full-health scholar refuses without saving or spending")
 ui.world.hp=150;var focus_before=ui.world.hero_view().focus;await ui.transact("act","skill_use")
 check(ui.world.hp==174 and ui.world.hero_view().focus==focus_before-1,"scholar actual healing follows finalized24 not old40")
 ui.modal="";await ui.start_run(11,19)
 check(ui.world.rule_version()==19 and ui.modal=="","explicit old-version creation remains supported")
 await ui.start_run(13);ui.queue_redraw();await process_frame
 check(ui.hero_catalog_rows().size()==3,"three actual catalog cards render")
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(220,260);await ui._unhandled_input(click)
 check(ui.hero_setup_selection=="warden" and ui.hero_setup_seed==13,"mouse selects card without changing pending seed")
 click.position=Vector2(850,670);await ui._unhandled_input(click)
 check(ui.world.hero_view().id=="warden" and ui.world.seed==13,"final mouse button creates selected hero exactly as previewed")
 ui.queue_free();await process_frame
 print("HERO V20 UI: %s (%d checks; UI fixtures, not balance proof)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
