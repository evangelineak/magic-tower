extends SceneTree
const W=preload("res://scripts/endless_world_v10.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 signal released
 var revision=0
 var writes=0
 var failing=false
 var hold=false
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit_walk(_s,r):
  writes+=1
  if hold:await released
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  revision+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func fixture():
 var w=W.new_run(20)
 check(w.step(Vector2i.RIGHT).changed,"fixture picks actual training")
 check(w.act("cargo_leave").changed,"fixture clears supply by free legal leave")
 var best:Array=[]
 for y in 15:
  for x in 15:
   var path:Array=w.safe_path(Vector2i(x,y))
   if path.size()>best.size() and path.size()<=8:best=path
 for p in best:check(w.step(p-w.pos).changed,"fixture walks actual safe tile")
 check(w.camp_return_view().available,"legal fixture has return path")
 return w
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 ui.world=fixture();ui.modal=""
 var before=ui.world.save_data();var oldpos=ui.world.pos;var view=ui.world.camp_return_view()
 check("安全回营" in ui.camp_button_label(view) and "不能中途撤销" in ui.camp_tooltip(view),"button and tooltip describe fast atomic behavior")
 ui.walk=[Vector2i(8,8)];memory.hold=true
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_T
 ui._unhandled_input(key)
 check(ui.busy and ui.walk.is_empty() and memory.writes==1,"T stops ordinary walk and begins one atomic save")
 check(ui.world.pos==oldpos and ui.world.save_data()==before,"pending save does not advance visible position")
 await ui._unhandled_input(key)
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(800,680)
 await ui._unhandled_input(click)
 check(memory.writes==1,"repeat keyboard and mouse cannot reenter pending save")
 key.keycode=KEY_ESCAPE;await ui._unhandled_input(key)
 check(ui.busy and memory.writes==1,"Escape does not falsely cancel already submitted atomic save")
 memory.hold=false;memory.released.emit();await process_frame
 check(not ui.busy and ui.world.pos==view.target,"save completion advances exactly to camp target")
 check(ui.world.actions.size()==before.actions.size()+view.steps,"every traversed tile retained in action log")
 var after=ui.world.save_data();await ui._unhandled_input(click)
 check(memory.writes==1 and ui.world.save_data()==after,"already at camp repeated click writes nothing")
 ui.world=fixture();ui.modal="";before=ui.world.save_data();memory.failing=true
 await ui._unhandled_input(click)
 check(ui.world.save_data()==before and not ui.busy and ui.walk.is_empty(),"failed mouse return save leaves world and queued walk unchanged")
 check("未确认" in ui.notice,"failure directs player to reconcile uncertain persistence")
 memory.failing=false;ui.walk=[Vector2i(8,8)];key.keycode=KEY_ESCAPE
 await ui._unhandled_input(key)
 check(ui.walk.is_empty(),"Escape before triggering cancels ordinary walking")
 # Deliberately isolated UI geometry fixture for the unavailable branch.
 ui.world=W.new_run(20)
 var grid:Array=[]
 for y in 15:
  var row:Array=[]
  for x in 15:row.append("#")
  grid.append(row)
 grid[1][1]=".";grid[10][10]="M";ui.world._maps={1:grid}
 before=ui.world.save_data();key.keycode=KEY_T
 var writes=memory.writes;await ui._unhandled_input(key)
 check(memory.writes==writes and ui.world.save_data()==before,"blocked camp route does not start save")
 ui.world=load("res://scripts/endless_world_v9.gd").new_run(20);await ui._unhandled_input(key)
 check("旧规则" in ui.notice and memory.writes==writes,"old rules don't get new shortcut")
 ui.queue_redraw();await process_frame
 ui.queue_free();await process_frame
 print("ENDLESS CAMP UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
