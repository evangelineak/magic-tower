extends SceneTree
const W=preload("res://scripts/endless_world_v12.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var writes=0
 func read():return {"ok":true,"snapshot":{},"revision":0,"records":[]}
 func commit(_s,_r):writes+=1;return {"ok":true,"revision":writes,"records":[]}
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 ui.world=W.new_run(41);ui.modal="";ui.camera=Vector2i.ZERO
 var target=Vector2i(3,2);ui.hover=target
 var before=ui.world.save_data()
 await ui.map_click(target)
 check(not ui.target_feedback.is_empty() and ui.tooltip_target()==target,"distant interaction feedback anchored to clicked object")
 check("先靠近" in ui.target_status(target),"local hint explains adjacency instead of only sidebar")
 check(ui.walk.is_empty() and memory.writes==0 and ui.world.save_data()==before,"distant object does not start walking or battle")
 ui.feedback_remaining=0.1;await ui.map_click(target)
 check(ui.feedback_remaining==2.5 and ui.target_feedback.size()==4,"repeat click refreshes one hint without stacking")
 ui.hover=Vector2i(3,1)
 check(ui.tooltip_target()==ui.hover,"another hovered interactive preserves full details instead of pinned hint")
 ui.hover=Vector2i(0,0)
 check(ui.tooltip_target()==target,"noninteractive hover can retain nearby failed-click explanation")
 var drag=InputEventMouseButton.new();drag.button_index=MOUSE_BUTTON_RIGHT;drag.pressed=true;drag.position=Vector2(250,250)
 await ui._unhandled_input(drag)
 check(ui.target_feedback.is_empty(),"map dragging clears stale anchored feedback")
 drag.pressed=false;await ui._unhandled_input(drag)
 ui.show_target_feedback(target,"nearby");ui.camera=Vector2i(4,4);ui.validate_target_feedback()
 check(ui.target_feedback.is_empty(),"scrolling target out of viewport clears it")
 ui.camera=Vector2i.ZERO;ui.show_target_feedback(target,"nearby");ui.world.floor_number=2;ui.validate_target_feedback()
 check(ui.target_feedback.is_empty(),"floor transition clears target from previous floor")
 ui.world=W.new_run(41);ui.show_target_feedback(target,"nearby");ui.feedback_remaining=0;ui.validate_target_feedback()
 check(ui.target_feedback.is_empty(),"hint expires without blinking or persistence")
 ui.show_target_feedback(target,"nearby");ui.world._consume(target);ui.validate_target_feedback()
 check(ui.target_feedback.is_empty(),"changed target token clears stale hint")
 ui.world=W.new_run(41);ui.hover=Vector2i(2,1)
 check("相邻" in ui.target_status(ui.hover),"adjacent object advertises direct interaction")
 ui.show_target_feedback(target,"nearby");await ui.map_click(Vector2i(2,1))
 check(ui.target_feedback.is_empty() and ui.world.pos==Vector2i(2,1),"adjacent pickup unchanged and removes failed-click message")
 ui.hover=target;ui.queue_redraw();await process_frame
 ui.show_target_feedback(target,"nearby");await ui.reload_run()
 check(ui.target_feedback.is_empty(),"reload clears feedback")
 ui.queue_free();await process_frame
 print("TARGET FEEDBACK UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
