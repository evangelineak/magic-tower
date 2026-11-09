extends SceneTree
const Art=preload("res://scripts/endless_enemy_v7_art.gd")
class TestCanvas:
 extends Node2D
 var draws=0
 func _draw():
  for size in [16.0,24.0,40.0,64.0,128.0]:
   for token in Art.TOKENS:
    assert(Art.draw_enemy(self,Vector2(100,100),token,size));draws+=1
  for token in [".","g","V","C","R","unknown"]:assert(not Art.draw_enemy(self,Vector2.ZERO,token))
  for size in [0.0,-1.0,NAN,INF]:assert(not Art.draw_enemy(self,Vector2.ZERO,"r",size))
func _initialize():call_deferred("run")
func run():
 var c=TestCanvas.new();root.add_child(c)
 for i in 3:await process_frame
 if c.draws<10:
  push_error("Enemy v7 draw callback did not execute");quit(1);return
 print("ENEMY V7 ART: PASS (%d actual draw calls; native visual review still required)"%c.draws)
 c.queue_free();quit()
