extends SceneTree
# Actual generated v15 journeys; no position/stat/geometry grants.
const W=preload("res://scripts/endless_world_v15.gd")
const G=preload("res://scripts/endless_generation_v15.gd")
var checks=0
var failures=0
class ReadUI:
 extends "res://scripts/endless_ui.gd"
 func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");set_process(false);queue_redraw()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func go(w,target:Vector2i)->bool:
 var q:Array[Vector2i]=[w.pos];var parent:Dictionary={w.pos:w.pos};var head=0
 var excluded:Array=G.routes(w.seed,w.floor_number)[1].points
 while head<q.size():
  var p=q[head];head+=1
  if p==target:break
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n=p+d;var token=w.tile(n)
   if parent.has(n) or token in ["#","D","V","M","S"] or n in excluded:continue
   if token in ["<",">"] and n!=target:continue
   parent[n]=p;q.append(n)
 if not parent.has(target):check(false,"legal route target reachable %s" % target);return false
 var path:Array=[];var p=target
 while p!=w.pos:path.push_front(p);p=parent[p]
 for n in path:
  if w.tile(n)=="C":check(w.act("cargo_leave").get("changed",false),"legally decline box without consuming heal budget")
  var result=w.step(n-w.pos)
  if not result.get("changed",false) or w.ended:check(false,"real step survives toward %s" % target);return false
 return true
func merchant(w)->Vector2i:
 var found=Vector2i(-1,-1)
 for y in 15:
  for x in 15:
   if w.tile(Vector2i(x,y))=="M":
    check(found.x<0,"generated camp unique");found=Vector2i(x,y)
 return found
func _initialize():call_deferred("run")
func run():
 var ui=ReadUI.new();ui.world=W.new_run(0);root.add_child(ui);await process_frame
 var families:Dictionary={};var moved=0
 for seed_value in range(16):
  var w=W.new_run(seed_value)
  for f in [1,2]:
   check(w.floor_number==f,"floor reached by real stair movement")
   families[G.layout_name(seed_value,f)]=true
   var y=1 if f%2 else 13
   if not go(w,Vector2i(2 if f%2 else 12,y)):break
   if not go(w,Vector2i(3 if f%2 else 11,y)):break
   var camp=merchant(w);check(camp.x>=0,"actual M found")
   var near=absi(camp.x-w.pos.x)+absi(camp.y-w.pos.y)==1
   if not near:
    for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     var anchor=camp+d
     if w.tile(anchor)=="." and not w.safe_path(anchor).is_empty():
      for step in w.safe_path(anchor):check(w.step(step-w.pos).get("changed",false),"safe generated camp approach")
      near=true;break
   check(near,"camp approachable from actual entry without combat")
   ui.world=w;ui.center_camera();ui.queue_redraw();await process_frame
   var region=ui.camp_floor_cells()
   check(region.has(camp) and region.size()>1,"relocated camp retains paved identity and connected floor")
   check(region.size()<=9,"new geometry retains small visual footprint")
   for p in region:
    check(w.tile(p) in [".","M"],"paving never covers blocker after repairs")
    check(absi(p.x-camp.x)<=1 and absi(p.y-camp.y)<=1,"paving centered on actual camp, not legacy anchor")
   var old_camp=G.G14.camp_position(seed_value,f)
   if old_camp!=camp:
    moved+=1;check(not region.has(old_camp),"old station does not retain ghost plaza")
   var screen=camp-ui.camera
   check(screen.x>=0 and screen.y>=0 and screen.x<ui.VIEW and screen.y<ui.VIEW,"camera following legal camp approach keeps landmark visible")
   if seed_value==0 and f==1:
    ui.camera=Vector2i(4,0)
    for former_island in [Vector2i(13,5),Vector2i(13,8)]:
     check(w.tile(former_island)==".","former isolated floor preserved as actual floor, not hidden wall")
     var pixel=ui.ORIGIN+Vector2(former_island-ui.camera)*ui.CELL+Vector2(32,32)
     check(ui.screen_tile(pixel)==former_island,"scrolled viewport maps repaired floor to correct world cell")
     check(not ui.camp_floor_cells().has(former_island),"repaired distant floor does not gain false camp identity")
    ui.queue_redraw();await process_frame
    ui.center_camera()
   # Return shortcut at camp must not fabricate movement.
   check(not w.camp_return_view().available,"already-near camp is correctly recognised after relocation")
   if f==1 and not go(w,G.anchors(f).exit):break
  var restored=W.from_data(w.save_data())
  check(restored!=null and restored.pos==w.pos,"legal journey and relocated camp replay")
 check(moved>0,"matrix includes actual relocated legacy camps")
 check(families.size()>=5,"matrix covers distinct geometry families")
 ui.queue_free();await process_frame
 print("V15 VISUAL UI: %s (%d checks; %d families; %d relocated camp cases)" % ["PASS" if failures==0 else "FAIL",checks,families.size(),moved]);quit(0 if failures==0 else 1)
