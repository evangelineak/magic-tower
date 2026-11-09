extends SceneTree
const V8=preload("res://scripts/endless_world_v8.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
class Memory:
 extends RefCounted
 var snapshot={}
 var revision=0
 var writes=0
 var failing=false
 func read():return {"ok":true,"snapshot":snapshot.duplicate(true),"revision":revision,"records":[]}
 func commit(s,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  writes+=1;revision+=1;snapshot=s.duplicate(true);return read()
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame
 ui.world=V8.new_run(20);ui.modal="";memory.snapshot=ui.world.save_data()
 var snapshot=ui.world.save_data();var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_G
 await ui._unhandled_input(key)
 check(ui.modal=="growth","G opens current version growth budget")
 check(ui.growth_lines(ui.world.growth_view())[0].contains("攻击20 / 防御10"),"base stats come from actual packs, not floor")
 check(ui.growth_lines(ui.world.growth_view())[6].contains("全旅程"),"lessons clearly labelled whole journey")
 ui.queue_redraw();await process_frame
 await ui.confirm_modal()
 check(ui.modal=="" and memory.writes==0 and ui.world.save_data()==snapshot,"Enter closes without reset or mutation")
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(980,365)
 await ui._unhandled_input(click);check(ui.modal=="growth","visible G button supports mouse")
 click.position=Vector2(1000,710);await ui._unhandled_input(click)
 check(ui.modal=="" and memory.writes==0,"close button is read-only")
 await ui.map_click(Vector2i(2,1))
 check(ui.world.growth_view().training_packs==1,"adjacent training pickup updates actual pack count")
 check(ui.growth_lines(ui.world.growth_view())[0].contains("攻击23 / 防御12"),"UI displays fixed +3/+2 separately")
 var before=ui.world.save_data();memory.failing=true
 await ui.transact("act","cargo_use")
 check(ui.world.save_data()==before,"failed supply save keeps shown budget unchanged")
 memory.failing=false;await ui.transact("act","cargo_use")
 check(ui.world.growth_view().relief_remaining==9,"successful supply spends one journey allowance")
 await ui.reload_run()
 check(ui.world.rule_version()==8 and ui.world.growth_view().relief_remaining==9,"reload keeps v8 quota and version")
 ui.open_growth();ui.queue_redraw();await process_frame
 var cap_view=ui.world.growth_view();cap_view.bonus_atk=6;cap_view.bonus_def=4;cap_view.remaining_atk=0;cap_view.remaining_def=0;cap_view.lessons_used=6;cap_view.lessons_remaining=0
 check(ui.growth_lines(cap_view)[3].contains("还可增加0") and ui.growth_lines(cap_view)[6].contains("剩0"),"exhausted cap formatter shows zero, not a new floor refill")
 key.keycode=KEY_ESCAPE;await ui._unhandled_input(key)
 check(ui.modal=="","Escape closes budget")
 ui.world=load("res://scripts/endless_world_v7.gd").new_run(20);ui.modal=""
 ui.open_growth()
 check(ui.modal=="" and "旧规则" in ui.notice,"old run not shown v8 budget")
 check("全旅程10份" in ui.growth_help_text() and "4金币" in ui.growth_help_text(),"help explains global free quota and subsequent price")
 ui.queue_free();await process_frame
 print("ENDLESS GROWTH UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
