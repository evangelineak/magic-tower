extends SceneTree
const W=preload("res://scripts/endless_world_v21.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var writes=0
 func read():return {"ok":true,"snapshot":{},"revision":0,"records":[]}
 func commit(_s,_r):writes+=1;return {"ok":false,"status":"unexpected_write"}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui);await process_frame;ui.set_process(false)
 check(ui.battle_hero_contribution({})=="","legacy no hero fields has no fabricated contribution")
 check("消耗2专注" in ui.battle_hero_contribution({"hero_skill_used":true,"hero_reduction":7,"hero_pierce":0,"skill_cost":2}),"actual overload cost is not hardcoded one")
 check("消耗0专注" in ui.battle_hero_contribution({"hero_skill_used":false,"skill_cost":2}),"unspent skill never claims focus was spent")
 for id in ["warden","ranger","scholar"]:
  ui.world=W.new_run(42);ui.world.act("hero_"+id);ui.world.act("legacy_none");ui.world.act("skill_use")
  var target=Vector2i(3,7);var info=ui.world.preview(target)
  # Actual forecast fields, displayed only. No claim this test executed a fight.
  ui.battle=info;ui.modal="";var before=ui.world.save_data()
  for remaining in [2.3,1.5,0.4]:
   ui.battle_time=remaining;ui.queue_redraw();await process_frame
  check(ui.world.save_data()==before,"cosmetic progression never mutates world")
  var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_RIGHT;ui.battle_time=2.0;await ui._unhandled_input(key)
  check(ui.battle_time==0 and ui.world.save_data()==before and memory.writes==0,"skip keyboard consumed without movement or repeat settlement")
  var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(300,300);ui.battle_time=2;await ui._unhandled_input(click)
  check(ui.battle_time==0 and memory.writes==0,"skip mouse performs no commit")
 ui.battle={"hero_skill_used":false,"rounds":0,"damage":180,"heal_after":0,"token":"r","title":"截击斥候"};ui.battle_time=1.8;ui.queue_redraw();await process_frame
 check(ui.battle.rounds==0 and memory.writes==0,"zero player strikes draws no fake hero attack")
 ui.queue_free();await process_frame
 print("BATTLE EFFECT UI: %s (%d checks; cosmetics only)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
