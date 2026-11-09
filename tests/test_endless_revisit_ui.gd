extends SceneTree
const Art=preload("res://scripts/endless_revisit_art.gd")
const W=preload("res://scripts/endless_world_v17.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var w=W.new_run(1);var b=Vector2i(6,3);var t=Vector2i(12,10)
 check(not Art.status(w,b).blocked,"roomy box has no seal")
 w.items.ward=8;w.items.pierce=7
 check(Art.status(w,b).blocked and "护符还缺1格" in Art.status(w,b).reason,"real two-item reward missing one space")
 w.pos=Vector2i(5,3);var before=w.save_data();var result=w.step(Vector2i.RIGHT)
 check(not result.changed and w.save_data()==before and Art.status(w,b).blocked,"rejected box stays sealed without mutation")
 w.items.ward-=1
 check(not Art.status(w,b).blocked,"using an item releases capacity seal immediately")
 w.items.pierce+=1
 check(Art.status(w,b).blocked,"receiving another item can make capacity blocked")
 w.items.pierce-=1;w.step(Vector2i.RIGHT)
 check(Art.status(w,b).is_empty(),"consumed box has no ghost marker")
 w.hp=180;w.bonus_atk=6;w.bonus_def=4;w.relic_bonus=2
 check(Art.status(w,t).blocked,"zero-benefit relic sealed")
 w.hp=179
 check(not Art.status(w,t).blocked,"one injury releases relic seal")
 var old=load("res://scripts/endless_world_v16.gd").new_run(1);old.items.ward=8;old.items.pierce=8
 check(not Art.status(old,b).blocked,"v16 needs only one space each")
 old.items.ward=9
 check(Art.status(old,b).blocked,"v16 full slot blocked")
 check(Art.status(old,t).is_empty(),"legacy relic has no unsupported quote marker")
 var older=load("res://scripts/endless_world_v15.gd").new_run(1)
 check(Art.status(older,b).is_empty(),"prebridge version unchanged")
 check(Art.status(w,Vector2i(6,4)).is_empty(),"enemy never gains treasure marker")
 check(Art.quote_status({"allowed":false,"reason":"generic"}).reason=="generic","generic quote adapter")
 var preview=load("res://tests/revisit_art_preview.tscn").instantiate();root.add_child(preview)
 await process_frame
 for scale_value in [0.625,1.0,1.5]:
  preview.scale=Vector2.ONE*scale_value;preview.queue_redraw();await process_frame
  check(is_instance_valid(preview),"actual preview drawing at scaled viewport content")
 preview.queue_free();await process_frame
 print("REVISIT UI: %s (%d checks; isolated states, not acquisition proof)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
