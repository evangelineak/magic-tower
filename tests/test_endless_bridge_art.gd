extends SceneTree
const Art=preload("res://scripts/endless_bridge_art.gd")
class Canvas:
 extends Node2D
 var draws=0
 func _draw():
  for size in [24.0,40.0,64.0,128.0]:
   for vertical in [false,true]:
    for state in ["raised","open","locked"]:
     assert(Art.draw_bridge(self,Vector2(100,100),state,vertical,size));draws+=1
   for used in [false,true]:Art.draw_winch(self,Vector2(220,100),used,size);draws+=1
  assert(not Art.draw_bridge(self,Vector2.ZERO,"unknown"))
  assert(not Art.draw_bridge(self,Vector2.ZERO,"open",false,NAN))
func _initialize():call_deferred("run")
func run():
 var c=Canvas.new();root.add_child(c)
 for i in 3:await process_frame
 if c.draws<32:push_error("Bridge draw callback did not execute");quit(1);return
 print("BRIDGE ART: PASS (%d actual draw calls; native visual review required)" % c.draws)
 c.queue_free();quit()
