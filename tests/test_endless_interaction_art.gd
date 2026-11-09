extends SceneTree
const Art=preload("res://scripts/endless_interaction_art.gd")
class TestCanvas:
 extends Node2D
 var draws=0
 func _draw():
  for size in [16.0,24.0,40.0,64.0,128.0]:
   for token in Art.TOKENS:
    assert(Art.draw_token(self,Vector2(100,100),token,size));draws+=1
  for token in [".","#","g","T","unknown"]:
   assert(not Art.draw_token(self,Vector2.ZERO,token))
  for size in [0.0,-1.0,NAN,INF]:assert(not Art.draw_token(self,Vector2.ZERO,"S",size))
func _initialize():call_deferred("run")
func run():
 var c=TestCanvas.new();root.add_child(c)
 for i in 3:await process_frame
 if c.draws<35:
  push_error("Interaction draw callback did not execute");quit(1);return
 print("INTERACTION ART: PASS (%d actual draw calls; native visual review still required)"%c.draws)
 c.queue_free();quit()
