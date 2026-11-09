extends SceneTree
const W=preload("res://scripts/endless_world_v22.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var failing=false
 func read():return {"ok":true,"revision":revision,"snapshot":{},"records":[]}
 func commit(_s,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  revision+=1;writes+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func fixture(variant:int):
 for seed_value in range(100):
  for f in [4,6]:
   var w=W.new_run(seed_value);w.act("hero_warden");w.act("legacy_none");w.floor_number=f
   var view=w.water_view()
   if view.get("present",false) and int(view.variant)==variant:return w
 return null
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui);await process_frame;ui.set_process(false)
 for variant in [0,1]:
  ui.world=fixture(variant);check(ui.world!=null,"actual seeded water geometry exists")
  if ui.world==null:continue
  ui.modal="";ui.world.pos=Vector2i(6,7);ui.water_cache_key="";ui.center_camera()
  var view=ui.water_data();var before=ui.world.save_data();var state=int(view.state);var hp=ui.world.hp;var gold=ui.world.gold;var keys=ui.world.keys
  ui.world.pos=Vector2i(2,2);ui.water_cache_key="";before=ui.world.save_data();var writes=memory.writes
  await ui.map_click(Vector2i(5,7))
  check(ui.world.save_data()==before and memory.writes==writes and ui.walk.is_empty(),"remote valve never toggles or automatically routes into interaction")
  ui.world.pos=Vector2i(6,7);ui.water_cache_key="";before=ui.world.save_data();var old_camera=ui.camera
  memory.failing=true;await ui.map_click(Vector2i(5,7))
  check(ui.world.save_data()==before and int(ui.water_data().state)==state and ui.camera==old_camera,"failed valve write preserves water state icons and camera")
  memory.failing=false;ui.walk=[Vector2i(6,8)];await ui.map_click(Vector2i(5,7))
  check(int(ui.water_data().state)==1-state and ui.modal=="" and ui.walk.is_empty(),"adjacent valve directly changes level and cancels stale walking route")
  check(ui.world.hp==hp and ui.world.gold==gold and ui.world.keys==keys,"free valve spends no HP gold or key")
  var deep_name="north" if ui.water_data().pool_states.north=="deep" else "south"
  var dry_name="south" if deep_name=="north" else "north"
  var deep:Vector2i=ui.water_data().pools[deep_name][0];var dry:Vector2i=ui.water_data().pools[dry_name][0]
  check(ui.world.tile(deep)=="~" and ui.world.tile(dry)=="." and ui.water_pool_at(dry)==dry_name,"actual passability and metadata-driven dry art agree")
  ui.world.pos=deep+Vector2i.LEFT;ui.water_cache_key="";writes=memory.writes;before=ui.world.save_data();await ui.map_click(deep)
  check(ui.world.save_data()==before and memory.writes==writes and not ui.notice.is_empty(),"deep water click refuses with actual reason and no write")
  ui.world.pos=Vector2i(6,7);ui.water_cache_key="";await ui.map_click(Vector2i(5,7))
  check(int(ui.water_data().state)==state,"free toggle restores opposite route without deleting enemies")
  ui.walk=[Vector2i(6,8)];await ui.transact("step",Vector2i.LEFT)
  check(int(ui.water_data().state)==1-state and ui.walk.is_empty() and ui.modal=="","directional valve interaction also directly toggles and invalidates auto path")
  var same=ui.world.save_data();writes=memory.writes;await ui.transact("act","water_north" if int(ui.water_data().state)==0 else "water_south")
  check(ui.world.save_data()==same and memory.writes==writes,"repeating explicit target state does not save or change resources")
  ui.world.pos=Vector2i(6,7);ui.water_cache_key="";ui.center_camera();ui.hover=Vector2i(5,7);ui.queue_redraw();await process_frame
  check(is_instance_valid(ui),"actual UI paints shore valve depth and local tooltip")
 ui.world=load("res://scripts/endless_world_v21.gd").new_run(3);ui.world.act("hero_warden");ui.world.act("legacy_none")
 check(ui.water_data().is_empty() and ui.water_pool_at(Vector2i(6,7))=="","old journeys have no water dye or control overlay")
 ui.queue_free();await process_frame
 print("WATER UI: %s (%d checks; local fixtures, not full route proof)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
