extends SceneTree
const W=preload("res://scripts/endless_world_v19.gd")
const G=preload("res://scripts/endless_generation_v19.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var failing=false
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit(_s,_r):
  if failing:return {"ok":false,"status":"io_error"}
  revision+=1;writes+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func fixture(variant:int):
 for seed_value in range(30):
  for f in G.cart_floors(seed_value):
   if G.cart_manifest(seed_value,f).variant==variant:
    var w=W.new_run(seed_value);w.floor_number=f;return w
 return null
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 for variant in [1,2]:
  ui.world=fixture(variant);ui.modal="";var origin:Vector2i=ui.world.cart_view().origin
  ui.world.pos=Vector2i(4,6);ui.center_camera();var before=ui.world.save_data();var writes=memory.writes
  await ui.map_click(origin)
  check(ui.world.save_data()==before and memory.writes==writes and ui.walk.is_empty(),"far cart click never pushes or auto walks")
  ui.world.pos=origin+Vector2i.RIGHT;ui.center_camera();ui.cart_cache_key=""
  check(ui.camera==Vector2i(3,0),"whole causal region remains in fixed viewport")
  ui.world.pos=origin+Vector2i.DOWN;ui.cart_cache_key=""
  if variant==1:
   writes=memory.writes;await ui.map_click(origin)
   check(ui.world.cart_view().cart_pos==origin and memory.writes==writes and "石柱" in ui.notice,"blocked push gives concrete obstruction without state change")
  ui.world.pos=origin+Vector2i.RIGHT;ui.cart_cache_key=""
  before=ui.world.save_data();memory.failing=true;await ui.map_click(origin)
  check(ui.world.save_data()==before and ui.world.cart_view().cart_pos==origin and ui.camera==Vector2i(3,0),"failed push commit keeps world icon and camera unchanged")
  memory.failing=false;await ui.map_click(origin)
  check(ui.world.cart_view().cart_pos==origin+Vector2i.LEFT and ui.world.pos==origin and ui.modal=="","adjacent cart click pushes exactly once without menu")
  check(ui.camera==Vector2i(3,0),"successful push does not recenter whole puzzle")
  ui.world.pos=Vector2i(4,6);ui.cart_cache_key="";await ui.map_click(Vector2i(4,7))
  check(ui.world.cart_view().cart_pos==origin and ui.modal=="","adjacent reset immediately restores origin without intermediate menu")
  ui.world.pos=origin+Vector2i.RIGHT;ui.cart_cache_key=""
  var direction=InputEventKey.new();direction.pressed=true;direction.keycode=KEY_LEFT;await ui._unhandled_input(direction)
  check(ui.world.cart_view().cart_pos==origin+Vector2i.LEFT,"keyboard push matches adjacent click")
  ui.world.pos=Vector2i(4,6);ui.cart_cache_key="";await ui.map_click(Vector2i(4,7))
  writes=memory.writes;await ui.map_click(Vector2i(4,7))
  check(memory.writes==writes,"repeat reset in origin is no-op")
  ui.world.pos=Vector2i(8,2);ui.world.hp=180;ui.world.bonus_atk=6;ui.world.bonus_def=4;ui.world.relic_bonus=2;ui.cart_cache_key=""
  writes=memory.writes;await ui.map_click(Vector2i(8,1))
  check(memory.writes==writes and ui.world.cart_view().claim=="" and ui.world.tile(Vector2i(8,1))=="L","zero-gain archive refuses without consuming exclusive choice")
  # Isolated occupancy fixtures below test presentation/confirmation, not solution proof.
  ui.world.carts[ui.world.floor_number]={"pos":Vector2i(5,5),"claim":""};ui.world.pos=Vector2i(5,2);ui.cart_cache_key=""
  ui.world.items.ward=9;writes=memory.writes;await ui.map_click(Vector2i(5,1))
  check(memory.writes==writes and ui.world.cart_view().claim=="" and ui.world.tile(Vector2i(5,1))=="J","full tool inventory refuses reward without locking cart")
  ui.world.items.ward=0;ui.world.items.pierce=0;await ui.map_click(Vector2i(5,1))
  check(ui.modal=="confirm" and ui.world.cart_view().claim=="" and "另一奖励作废" in ui.notice,"only reward claim asks irreversible shared-opportunity confirmation")
  var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;await ui._unhandled_input(escape)
  check(ui.modal=="" and ui.world.cart_view().claim=="","cancel claim preserves choice")
  await ui.map_click(Vector2i(5,1));await ui.confirm_modal()
  check(ui.world.cart_view().claim=="supply" and ui.world.items.ward==1 and ui.world.items.pierce==1,"explicit confirmation grants one shared reward")
  var view=ui.world.cart_view()
  check(view.gates.supply.open and view.gates.archive.locked and not view.reset_allowed,"claimed side open opposite locked reset disabled")
  ui.queue_redraw();await process_frame
  ui.world.pos=Vector2i(1,1);ui.center_camera()
  check(ui.camera==Vector2i.ZERO,"leaving event restores normal camera")
 ui.world=load("res://scripts/endless_world_v18.gd").new_run(1)
 check(ui.cart_data().is_empty(),"old versions unchanged")
 ui.queue_free();await process_frame
 print("CART UI: %s (%d checks; isolated local fixtures, not acquisition proof)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
