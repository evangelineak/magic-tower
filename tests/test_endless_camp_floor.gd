extends SceneTree
const Art=preload("res://scripts/endless_camp_floor_art.gd")
const W=preload("res://scripts/endless_world_v13.gd")
var checks=0
var failures=0
class Tiles:
 extends RefCounted
 var marks={Vector2i(7,7):"M"}
 var reads=0
 var actions=[]
 var floor_number=1
 func tile(p:Vector2i)->String:
  reads+=1
  return "#" if p.x<0 or p.y<0 or p.x>=15 or p.y>=15 else marks.get(p,".")
class TracedUI:
 extends "res://scripts/endless_ui.gd"
 var trace:Array=[]
 func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");set_process(false);queue_redraw()
 func _draw():trace.clear();super._draw()
 func draw_ground_tile(c:Vector2,p:Vector2i,region:Dictionary):trace.append("ground");super.draw_ground_tile(c,p,region)
 func draw_token(c:Vector2,t:String):trace.append("token");super.draw_token(c,t)
 func draw_path_marker(c:Vector2):trace.append("path");super.draw_path_marker(c)
 func draw_hero(c:Vector2):trace.append("hero");super.draw_hero(c)
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var t=Tiles.new();var region=Art.cells(t)
 check(region.size()==9,"open camp paving limited to nine cells")
 for p in region:check(absi(p.x-7)<=1 and absi(p.y-7)<=1,"paving remains within 3x3")
 t.marks[Vector2i(6,7)]="#";t.marks[Vector2i(7,6)]="#"
 region=Art.cells(t)
 check(not region.has(Vector2i(6,6)),"no diagonal connection through blocking walls")
 check(not region.has(Vector2i(6,7)),"wall itself never paved")
 for token in ["D","g","t","p","C","a","k","<",">"]:
  t.marks={Vector2i(7,7):"M",Vector2i(6,7):"#",Vector2i(7,6):"#",Vector2i(7,8):"#",Vector2i(8,7):token}
  check(Art.cells(t).size()==1,"blocker %s prevents paving beyond it" % token)
 t.marks.erase(Vector2i(8,7));region=Art.cells(t)
 check(region.has(Vector2i(7,7)) and region.has(Vector2i(8,7)),"camp landmark remains after resource disappears")
 t.marks[Vector2i(4,4)]="M";check(Art.cells(t).is_empty(),"ambiguous camp anchors fail closed")
 t.marks={};check(Art.cells(t).is_empty(),"no camp no invented landmark")
 var ui=TracedUI.new();ui.world=W.new_run(41);ui.world.step(Vector2i.RIGHT);ui.walk=[Vector2i(1,2)];root.add_child(ui)
 await process_frame
 check(ui.trace.count("ground")==121 and ui.trace.count("token")==121,"every viewed cell gets one ground then token pass")
 for i in range(0,242,2):
  check(ui.trace[i]=="ground" and ui.trace[i+1]=="token","floor drawn below each token")
 check(ui.trace.find("path")>ui.trace.rfind("ground"),"safe route dots drawn after all ground")
 check(ui.trace.find("hero")>ui.trace.find("path"),"hero remains above ground and path")
 var mock=Tiles.new();ui.world=mock
 var first=ui.camp_floor_cells();var reads=mock.reads
 ui.camp_floor_cells();check(mock.reads==reads,"unchanged frame reuses region without BFS or scan")
 mock.actions.append("R");ui.camp_floor_cells();check(mock.reads>reads,"new committed action invalidates region")
 ui.world=null;ui.queue_free();await process_frame
 print("CAMP FLOOR UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
