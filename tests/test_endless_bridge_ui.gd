extends SceneTree
const W=preload("res://scripts/endless_world_v16.gd")
const G=preload("res://scripts/endless_generation_v16.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var failing=false
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit(_s,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  revision+=1;writes+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func prepared(seed_value:int):
 var w=W.new_run(seed_value)
 check(w.step(Vector2i.RIGHT).changed,"real training pickup")
 check(w.act("cargo_leave").changed,"real optional box decline")
 for d in [Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.DOWN,Vector2i.LEFT]:check(w.step(d).changed,"real step to key")
 check(w.keys==1,"one key earned by actual pickup")
 return w
func finish_walk(ui):
 var guard=0
 while not ui.walk.is_empty() and guard<225:
  await ui._process(0.14);guard+=1
 check(guard<225,"safe approach terminates")
func _initialize():call_deferred("run")
func run():
 var seed_value=0
 for candidate in 100:
  if G.has_bridge(candidate,1):seed_value=candidate;break
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 ui.world=prepared(seed_value);ui.modal="";var winch:Vector2i=ui.bridge_data().winch
 var before=ui.world.save_data();await ui.map_click(winch)
 check(not ui.walk.is_empty() and ui.modal=="" and ui.world.save_data()==before,"far winch only queues safe approach, no activation")
 for p in ui.walk:check(ui.world.tile(p)==".","approach does not cross any uncleared object")
 var path=ui.walk.duplicate();await ui.map_click(winch)
 check(ui.walk==path and memory.writes==0,"repeat far click does not spend or move twice")
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_ESCAPE;await ui._unhandled_input(key)
 check(ui.walk.is_empty() and ui.world.keys==1,"Escape cancels approach without key charge")
 await ui.map_click(winch);await finish_walk(ui)
 check(ui.bridge_data().near and ui.modal=="" and ui.world.keys==1,"arrival stops beside winch without auto interaction")
 var keyboard_before=ui.world.save_data();var keyboard_writes=memory.writes
 key.keycode={Vector2i.UP:KEY_UP,Vector2i.DOWN:KEY_DOWN,Vector2i.LEFT:KEY_LEFT,Vector2i.RIGHT:KEY_RIGHT}[winch-ui.world.pos]
 await ui._unhandled_input(key)
 check(ui.modal=="bridge" and ui.world.save_data()==keyboard_before and memory.writes==keyboard_writes,"direction key at winch opens comparison directly without intermediate choice or payment")
 key.keycode=KEY_ESCAPE;await ui._unhandled_input(key)
 await ui.map_click(winch)
 check(ui.modal=="bridge" and ui.bridge_data().available,"adjacent winch opens actual two-arm comparison")
 ui.queue_redraw();await process_frame
 before=ui.world.save_data();await ui._unhandled_input(key)
 check(ui.modal=="" and ui.world.save_data()==before,"closing comparison is free")
 await ui.map_click(winch);await ui.confirm_modal()
 check(ui.world.save_data()==before and "明确选择" in ui.modal_notice,"Enter does not silently pick an arm")
 memory.failing=true;await ui.confirm_bridge("short")
 check(ui.world.keys==1 and ui.bridge_data().choice=="","failed save leaves key and both bridges unchanged")
 memory.failing=false;await ui.confirm_bridge("short")
 check(ui.world.keys==0 and ui.bridge_data().choice=="short" and ui.modal=="","explicit short confirmation pays once")
 check(ui.bridge_data().arms[0].state=="lowered" and ui.bridge_data().arms[1].state=="locked","physical states reflect actual persisted choice")
 var writes=memory.writes;ui.open_bridge();await ui.confirm_bridge("loot")
 check(memory.writes==writes and ui.world.keys==0,"locked alternative cannot charge or switch")
 ui.modal="";var bridge:Vector2i=ui.bridge_data().arms[0].cells[0]
 await ui.map_click(bridge);await finish_walk(ui)
 check(ui.world.pos==bridge and ui.world.keys==0,"walking on opened bridge is ordinary safe movement, never charges again")
 check(ui.world.tile(Vector2i(8,8)) in ui.world.enemy_tokens() and ui.world.tile(Vector2i(8,9)) in ui.world.enemy_tokens(),"short bridge does not secretly kill either guard")
 ui.queue_redraw();await process_frame
 # A separate legal key acquisition chooses the other arm.
 ui.world=prepared(seed_value);ui.modal="";await ui.map_click(winch);await finish_walk(ui);await ui.map_click(winch)
 await ui.confirm_bridge("loot")
 check(ui.bridge_data().choice=="loot" and ui.bridge_data().arms[0].state=="locked","loot choice closes shortcut instead")
 check(ui.world.tile(Vector2i(6,5))=="." and ui.world.tile(Vector2i(6,4))=="c","loot bridge opens but leaves its guardian")
 ui.open_bridge();ui.queue_redraw();await process_frame;ui.modal=""
 ui.world=W.new_run(seed_value);ui.world.pos=Vector2i(5,7);ui.modal=""
 key.keycode=KEY_UP;await ui._unhandled_input(key)
 check(ui.modal=="bridge" and not ui.bridge_data().available,"no-key directional interaction still opens read-only bridge explanation")
 # This isolated no-key UI branch does not claim a legal play route.
 writes=memory.writes;await ui.confirm_bridge("short")
 check(memory.writes==writes and "钥匙" in ui.modal_notice,"unfunded confirmation cannot activate")
 ui.modal="";ui.world=load("res://scripts/endless_world_v15.gd").new_run(0)
 check(ui.bridge_data().is_empty(),"older journeys retain no bridge UI")
 ui.queue_free();await process_frame
 print("BRIDGE UI: %s (%d checks; paid branches use legal key/approach actions)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
