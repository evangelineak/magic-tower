extends SceneTree
const Fixture=preload("res://tests/ui_fixture.gd")
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;push_error(note)
func _initialize():call_deferred("run_tests")
func run_tests():
 var scene=load("res://main.tscn").instantiate()
 Fixture.attach(scene);root.add_child(scene)
 await Fixture.bind(scene,World.new(0))
 scene.growth=false;scene.language="en"
 await scene.move(Vector2i.RIGHT) # manually collect starting ruby before safe walking
 scene.battle_time=0.0
 var before=scene.world.save_data().duplicate(true)
 var writes=scene.session.adapter.writes
 scene.hover=scene.world.pos
 check(scene.hover_walk_info().state=="current","current position is not mistaken for unreachable")
 scene.hover=Vector2i(-1,0)
 check(scene.hover_walk_info().state=="outside","outside board has no route")
 scene.hover=Vector2i(0,0)
 check(scene.hover_walk_info().state=="wall","wall clearly blocked")
 var target=Vector2i(-1,-1)
 for y in range(1,10):
  for x in range(1,10):
   if not scene.world.safe_walk_path(Vector2i(x,y)).is_empty():target=Vector2i(x,y)
 check(target.x>=0,"real starting map contains safe walk target")
 scene.hover=target
 var info=scene.hover_walk_info()
 check(info.state=="ready" and info.route==scene.world.safe_walk_path(target),"hover previews exact safe path")
 var refreshes=scene.hover_walk_refresh_count
 for i in range(20):scene.hover_walk_info()
 check(scene.hover_walk_refresh_count==refreshes,"unchanged repeated render reuses route")
 info.route.clear()
 check(not scene.hover_walk_info().route.is_empty(),"consumer cannot mutate cached route")
 check(scene.world.save_data()==before and scene.session.adapter.writes==writes,"all hover operations are pure, no autosave")
 scene.start_walk(target)
 check(not scene.walk_route.is_empty(),"click accepts safe route")
 var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE
 scene._unhandled_input(event)
 check(scene.walk_route.is_empty(),"Escape cancels active walking")
 # Every non-empty real tile remains information-only, even zero-damage enemies.
 for y in range(11):
  for x in range(11):
   var p=Vector2i(x,y)
   if scene.world.tile(p)==".":continue
   scene.start_walk(p)
   check(scene.walk_route.is_empty(),"nonfloor click never creates action route")
   check(scene.world.save_data()==before,"object click never spends, fights, picks up or traverses")
 # A synthetic wall insertion models a changed map after hover without touching
 # counters; click must independently re-prove the cached path.
 scene.hover=target;scene.invalidate_hover_walk()
 var path=scene.hover_walk_info().route
 if not path.is_empty():
  var p:Vector2i=path[0];var old=scene.world.tile(p)
  scene.world.floors[0][p.y][p.x]="#"
  scene.start_walk(target)
  check(scene.walk_route==scene.world.safe_walk_path(target),"click re-proves route even if stale hover cache exists")
  scene.world.floors[0][p.y][p.x]=old
 scene.cancel_walk();scene.invalidate_hover_walk()
 # Visible object-specific instructions and bilingual tooltip fit.
 for token in ["k","D","L","s",">"]:
  for y in range(11):
   for x in range(11):
    if scene.world.tile(Vector2i(x,y))!=token:continue
    scene.hover=Vector2i(x,y)
    var adjacent=absi(scene.hover.x-scene.world.pos.x)+absi(scene.hover.y-scene.world.pos.y)==1
    check(("Click" if adjacent else "WASD") in scene.hover_walk_info().hint,"object explains adjacent click or distant manual approach")
    for lang in ["en","zh"]:
     scene.language=lang
     var lines=scene.tooltip_lines();var rect=scene.tooltip_rect(lines)
     check(Rect2(8,8,1264,784).encloses(rect),"object tooltip fits viewport in "+lang)
 scene.language="zh"
 check("安全" in scene.display("No safe route. Clear the way manually first."),"blocked hint translated")
 check("步" in scene.display("Safe route: 4 steps. Click to walk; any key or click stops."),"step count template translated")
 scene.hover=target;scene.invalidate_hover_walk();scene.hover_walk_info();refreshes=scene.hover_walk_refresh_count
 await scene.move(Vector2i.RIGHT)
 scene.battle_time=0.0
 scene.hover_walk_info()
 check(scene.hover_walk_refresh_count>refreshes,"committed movement invalidates hover cache")
 await scene.undo();scene.hover_walk_info()
 check(scene.world.pos==Vector2i(2,1),"normal undo still restores origin")
 check(scene.session.adapter.writes>writes,"only explicit actual movement and undo persisted")
 scene.queue_free();await process_frame
 print("MOUSE GUIDANCE: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
