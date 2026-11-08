extends SceneTree
const Fixture=preload("res://tests/ui_fixture.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
const Layout=preload("res://scripts/layout.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func state(w)->Dictionary: return w.save_data().duplicate(true)
func key(scene,code):
 var event=InputEventKey.new(); event.pressed=true; event.keycode=code; await scene._unhandled_input(event)
func movement_only(before:Dictionary,after:Dictionary)->bool:
 var a=after.duplicate(true); var b=before.duplicate(true)
 for field in ["x","y","moves"]: a.erase(field); b.erase(field)
 return a==b and after.moves==before.moves+1
func find_walk(w)->Array:
 for y in range(1,10):
  for x in range(1,10):
   var route=w.safe_walk_path(Vector2i(x,y))
   if route.size()>=2:return route
 return []
func reachable(grid:Array,start:Vector2i,opened:Vector2i)->Dictionary:
 var seen={start:true}; var queue=[start]
 while not queue.is_empty():
  var p:Vector2i=queue.pop_front()
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d
   if n.x<0 or n.y<0 or n.x>=11 or n.y>=11 or seen.has(n):continue
   if grid[n.y][n.x] in ["#","~","V","K","Z","n","e","m","="]:continue
   if grid[n.y][n.x] in ["D","L"] and n!=opened:continue
   seen[n]=true; queue.append(n)
 return seen
func _initialize(): call_deferred("run_tests")
func run_tests():
 var w=World.new(0)
 # All planner outputs are absolute safe cells, never implicit actions.
 check(w.step(Vector2i.DOWN) and w.step(Vector2i.RIGHT),"walk to merchant through ordinary manual steps")
 var before=state(w); var route=find_walk(w)
 check(route.size()>=2 and state(w)==before,"planning finds a real multi-step safe route without world mutation")
 var previous=w.pos
 for next in route:
  check(w.tile(next)=="." and (next-previous).length_squared()==1,"route consists only of cardinal, empty absolute cells")
  before=state(w)
  check(w.safe_walk_step(next,w.floor_index,previous) and movement_only(before,state(w)),"each authorized auto-step changes only position and one move")
  previous=next
 # Refuse arbitrary teleport, stale origin, stale floor and side-effect tokens.
 before=state(w)
 check(not w.safe_walk_step(w.pos+Vector2i(2,0),w.floor_index,w.pos) and state(w)==before,"safe step cannot teleport")
 check(not w.safe_walk_step(w.pos+Vector2i.RIGHT,w.floor_index+1,w.pos) and state(w)==before,"stale floor aborts rather than changing floors")
 check(not w.safe_walk_step(w.pos+Vector2i.RIGHT,w.floor_index,w.pos+Vector2i.LEFT) and state(w)==before,"stale origin aborts")
 for token in ["s","D","L","k","h","a","d","N","I","C","T","$","A","P","<",">","M","J","O","R","X","U","Y","v","n","e","m","~","="]:
  w=World.new(0); var destination=w.pos+Vector2i.RIGHT
  w.floors[0][destination.y][destination.x]=token
  before=state(w)
  check(w.safe_walk_path(destination).is_empty() and not w.safe_walk_step(destination,0,w.pos) and state(w)==before,"auto-walk never enters side-effect or interaction token: "+token)
 # A plan does not authorize stepping onto subsequently changed content.
 w=World.new(0); w.step(Vector2i.DOWN); w.step(Vector2i.RIGHT); route=find_walk(w); var next:Vector2i=route[0]
 w.floors[w.floor_index][next.y][next.x]="h"; before=state(w)
 check(not w.safe_walk_step(next,w.floor_index,w.pos) and state(w)==before,"pickup inserted after planning cancels execution without collecting it")
 w=World.new(0); w.won=true; before=state(w)
 check(w.safe_walk_path(Vector2i(2,1)).is_empty() and not w.safe_walk_step(Vector2i(2,1),0,w.pos) and state(w)==before,"won game cannot auto-walk")
 # Actual new layout: each authored paid gate isolates its own advertised reward.
 w=World.new(0)
 check(w.layout_revision==2 and w.generation_valid,"new gameplay defaults to validated layout2")
 for f in range(5):
  var grid=w.floors[f]; var closed=reachable(grid,Layout.entry(f,2),Vector2i(-1,-1))
  for y in range(1,10):
   for x in range(1,10):
    if grid[y][x] not in ["D","L"]:continue
    var gate=Vector2i(x,y); var info=Layout.door_info(f,gate,2)
    check(not info.is_empty() and not closed.has(info.reward_pos) and reachable(grid,Layout.entry(f,2),gate).has(info.reward_pos),"single gate truly isolates meaningful advertised reward: floor %d %s" % [f+1,gate])
 var stairs=0
 for chapter in range(2):
  var proof=Generator.validate(w.floors) if chapter==0 else Expedition.validate(w.floors.slice(5))
  check(proof.solvable,"new layout chapter has valid global witness")
  for c in proof.route:
   var direction:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
   var target=w.pos+direction; var token=w.tile(target); var prior_floor=w.floor_index
   var ok=w.step(direction)
   if not ok:check(false,"new actual mainline step succeeds");break
   if token==">":
    stairs+=1
    check(w.floor_index==prior_floor+1 and w.pos==target and w.tile(w.pos)=="<","real upward stairs land at same coordinate on reciprocal stairs")
    var down=Layout.stair_destination(w.floors,2,w.floor_index,w.pos)
    check(down.ok and down.pos==target and down.floor==prior_floor,"reciprocal stair edge returns to exact source coordinate")
  check(w.won,"actual chapter witness wins")
  if chapter==0:check(w.action("expedition"),"explicit continuation retains new-layout stair contract")
 check(stairs==6,"actual run crossed all six inter-floor ascent edges")
 print("USABILITY NEW REAL ROUTE: ",w.moves," moves; ",w.hp," HP")
 # Physically repeat the first boundary in both directions, not just inspect metadata.
 w=World.new(0)
 var stair_route_ok=true
 for c in Generator.validate(w.floors).route:
  var direction:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
  var upstairs=w.tile(w.pos+direction)==">"
  if not w.step(direction):stair_route_ok=false;break
  if upstairs:break
 check(stair_route_ok and w.floor_index==1,"real initial route reaches first reciprocal stair")
 var at_landing=state(w)
 for repetition in range(3):
  check(w.step(Vector2i.LEFT) and w.step(Vector2i.RIGHT) and w.floor_index==0 and w.pos==Vector2i(9,9),"actual descent returns to identical coordinate")
  check(w.step(Vector2i.LEFT) and w.step(Vector2i.RIGHT) and w.floor_index==1 and w.pos==Vector2i(9,9),"actual ascent returns to identical coordinate without drift")
 check(w.hp==at_landing.hp and w.focus==at_landing.focus and w.keys==at_landing.keys and w.gold==at_landing.gold and w.checkpoints==at_landing.checkpoints,"repeated stair visits cannot farm resources or settle new checkpoints")
 # Real old schema10 saves preserve maps and reciprocal old corner semantics.
 for branch in ["rescue","armory"]:
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema10-"+branch+".json"))
  check(w.restore(old) and w.layout_revision==1,"old schema10 retains layout1")
  var migrated=state(w); migrated.erase("layout_revision"); migrated.version=10
  for field in ["attunement_version","gear_offers","gear_choices","run_id","mode","ended_reason","death_record","draft","talent_draft","last_kill_kind"]: migrated.erase(field)
  check(JSON.parse_string(JSON.stringify(migrated))==old,"old map, rewards, resources and coordinates are unchanged")
  var landing=Layout.stair_destination(w.floors,1,0,Vector2i(9,9))
  check(landing.ok and landing.pos==Vector2i(1,1),"old stair corner mapping remains compatible")
 # Main controller never converts a click into an interaction or combat.
 var scene=load("res://main.tscn").instantiate(); Fixture.attach(scene); root.add_child(scene); await process_frame
 await Fixture.bind(scene,World.new(0)); scene.growth=false
 check(scene.CELL==64 and scene.ORIGIN==Vector2(24,72),"new board uses 64px cells at the intended origin")
 scene.world.step(Vector2i.DOWN); scene.world.step(Vector2i.RIGHT)
 route=find_walk(scene.world); var target:Vector2i=route[-1]; before=state(scene.world)
 await scene.save_game(); var disk=Fixture.snapshot(scene); var sounds=scene.sound_event_count
 scene.start_walk(target)
 check(scene.walk_route==route and state(scene.world)==before and Fixture.snapshot(scene)==disk,"click planning does not commit a move or save")
 await scene.advance_walk(0.11)
 check(state(scene.world)==before and scene.history.is_empty(),"walking waits for its interval")
 await scene.advance_walk(0.02)
 check(movement_only(before,state(scene.world)) and scene.history.size()==1 and scene.sound_event_count==sounds+1,"one interval commits exactly one normal move and history entry")
 await scene.undo(); check(state(scene.world)==before and scene.walk_route.is_empty(),"undo cancels remaining route and restores exact pre-step world")
 for code in [KEY_ESCAPE,KEY_C,KEY_E,KEY_H,KEY_J,KEY_V,KEY_T,KEY_F2,KEY_UP]:
  scene.book=false; scene.journal=false; scene.growth=false; scene.interaction=false; scene.comparison=false; scene.travel_menu=false
  scene.start_walk(target); key(scene,code)
  check(scene.walk_route.is_empty(),"keyboard action cancels auto route before acting: "+str(code))
  scene.world.restore(before); await Fixture.sync(scene)
 scene.book=false; scene.journal=false; scene.growth=false; scene.interaction=false; scene.comparison=false; scene.travel_menu=false
 scene.start_walk(target); var upcoming:Vector2i=scene.walk_route[0]
 scene.world.floors[scene.world.floor_index][upcoming.y][upcoming.x]="h"; var changed=state(scene.world); var count=scene.history.size()
 await scene.advance_walk(0.2)
 check(scene.walk_route.is_empty() and state(scene.world)==changed and scene.history.size()==count,"changed route stops without pickup, reroute or history entry")
 scene.world.restore(before); await Fixture.sync(scene); scene.start_walk(Vector2i(4,3))
 check(scene.walk_route.is_empty() and state(scene.world)==before,"clicking a monster never arms automatic battle")
 scene.start_walk(target); scene.book=true; await scene.advance_walk(0.2)
 check(scene.walk_route.is_empty() and state(scene.world)==before,"modal opening stops movement")
 scene.book=false
 for corner in [Vector2i(1,1),Vector2i(9,1),Vector2i(1,9),Vector2i(9,9),Vector2i(4,3)]:
  scene.hover=corner; var prior=state(scene.world); var lines=scene.tooltip_lines(); var rect=scene.tooltip_rect(lines)
  check(Rect2(0,0,1280,800).encloses(rect) and not rect.intersects(Rect2(scene.ORIGIN+Vector2(corner)*scene.CELL,Vector2(scene.CELL,scene.CELL))),"tooltip is on-screen and does not cover its hovered tile")
  var widths_ok=true
  for line in lines:
   if scene.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>298.1:widths_ok=false
  check(widths_ok and state(scene.world)==prior,"tooltip pixel wrap is bounded and entirely read only")
 var old_text=FileAccess.get_file_as_string("res://tests/fixtures/schema10-armory.json")
 var legacy_path="user://usability-test-legacy.json"
 var file=FileAccess.open(legacy_path,FileAccess.WRITE); file.store_string(old_text); file.close()
 var expected=state(scene.world); var durable=Fixture.snapshot(scene)
 scene.start_walk(target); await scene.load_game()
 check(scene.walk_route.is_empty() and state(scene.world)==expected and Fixture.snapshot(scene)==durable and FileAccess.get_file_as_string(legacy_path)==old_text,"load cancels route, reads active slot, and never grafts old map bytes")
 DirAccess.remove_absolute(legacy_path)
 scene.queue_free(); await process_frame
 print("USABILITY: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
