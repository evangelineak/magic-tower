extends SceneTree
const Fixture=preload("res://tests/ui_fixture.gd")
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;push_error(note)
func _initialize():call_deferred("run_tests")
func setup(scene,token:String,mode:String="safe",hp:int=280)->Vector2i:
 var w=World.new(0,1,"",mode)
 w.hp=hp;w.keys=3
 if token=="$":
  w.pos=Vector2i(3,9);check(w.step(Vector2i.LEFT),"fixture opens treasury using real key cost")
  await Fixture.bind(scene,w);scene.growth=false;scene.language="en"
  return Vector2i(1,9)
 for y in range(1,10):
  for x in range(1,10):
   var p=Vector2i(x,y)
   if w.tile(p)!=token:continue
   for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if w.tile(p-delta)==".":
     w.pos=p-delta
     await Fixture.bind(scene,w)
     scene.growth=false;scene.language="en"
     return p
 check(false,"fixture token has adjacent empty tile: "+token)
 return Vector2i(-1,-1)
func run_tests():
 var scene=load("res://main.tscn").instantiate()
 Fixture.attach(scene);root.add_child(scene)
 # Controlled, fully validated fixtures compare click against the real model.
 # This is input parity testing, not a claim of a complete new-game route.
 for token in ["k","h","a","d","$","s"]:
  var target=await setup(scene,token)
  var expected=World.from_snapshot(scene.world.save_data())
  var before=scene.world.save_data().duplicate(true)
  var writes=scene.session.adapter.writes
  check(expected.step(target-expected.pos),"reference manual step succeeds "+token)
  await scene.map_click(target)
  check(scene.world.save_data()==expected.save_data(),"adjacent click equals manual step "+token)
  check(scene.session.adapter.writes==writes+1,"exactly one persisted action "+token)
  check(scene.walk_route.is_empty(),"no queued automatic continuation "+token)
  scene.battle_time=0.0
  await scene.undo()
  check(scene.world.save_data()==before,"undo restores clicked action "+token)
 for token in ["M","J"]:
  var target=await setup(scene,token)
  var gold=scene.world.gold;var debt=scene.world.debt()
  await scene.map_click(target)
  check(scene.interaction,"adjacent NPC opens choices "+token)
  var ids=[]
  for row in scene.available_actions():ids.append(row[0])
  check(("buy" in ids and not "quest_accept" in ids) if token=="M" else ("quest_accept" in ids and not "buy" in ids),"clicked NPC menu is target-specific "+token)
  var escape=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE
  scene._unhandled_input(escape)
  check(not scene.interaction,"Escape closes NPC choice")
  check(scene.world.gold==gold and scene.world.debt()==debt,"NPC click does not buy or borrow "+token)
 var door=await setup(scene,"D")
 var before=scene.world.save_data().duplicate(true)
 await scene.map_click(door)
 check(scene.interaction and scene.pending_reason=="door","door still requests confirmation")
 check(scene.world.save_data()==before,"door confirmation has not spent key")
 await scene.perform_action("cancel")
 # Rebinding also clears modal state independently of action-label semantics.
 var enemy=await setup(scene,"s","risk",1)
 before=scene.world.save_data().duplicate(true)
 await scene.map_click(enemy)
 check(scene.lethal_delta!=Vector2i.ZERO,"fatal risk click asks explicit confirmation")
 check(scene.world.save_data()==before,"fatal click has not killed player")
 enemy=await setup(scene,"s","safe",1)
 before=scene.world.save_data().duplicate(true)
 await scene.map_click(enemy)
 check(scene.world.save_data()==before,"safe mode refuses fatal mouse battle")
 await Fixture.bind(scene,World.new(0,1));scene.growth=false
 before=scene.world.save_data().duplicate(true)
 for target in [Vector2i(3,1),Vector2i(2,2),Vector2i(4,3),Vector2i(6,3)]:
  await scene.map_click(target)
  check(scene.world.save_data()==before,"distant/diagonal object never triggers")
  check(not scene.interaction and scene.lethal_delta==Vector2i.ZERO,"distant object opens no action")
 scene.growth=true
 await scene.map_click(Vector2i(2,1))
 check(scene.world.save_data()==before and scene.walk_route.is_empty(),"modal prevents map action")
 scene.growth=false;scene.session.read_only=true
 await scene.map_click(Vector2i(2,1))
 check(scene.world.save_data()==before,"read-only prevents click action")
 scene.queue_free();await process_frame
 print("ADJACENT CLICK: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
