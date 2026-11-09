extends SceneTree
const Art=preload("res://scripts/endless_actor_art.gd")
class TestCanvas:
 extends Node2D
 var draws=0
 func _draw():
  for size in [16.0,40.0,64.0,128.0]:
   for stance in ["none","pierce","guard","harvest","unknown"]:
    Art.draw_hero(self,Vector2(100,100),stance,size);draws+=1
   for token in ["g","b","w","V"]:
    assert(Art.draw_enemy(self,Vector2(200,200),token,size));draws+=1
  assert(not Art.draw_enemy(self,Vector2.ZERO,"unknown"))
  Art.draw_hero(self,Vector2.ZERO,"guard",0)
  Art.draw_hero(self,Vector2.ZERO,"guard",NAN)
func _initialize():call_deferred("run")
func run():
 var c=TestCanvas.new();root.add_child(c)
 for i in 3:await process_frame
 # Verify the callback actually executed: this is not a no-op load-only test.
 if c.draws<36:
  push_error("Actor art draw callback did not execute");quit(1);return
 print("ACTOR ART: PASS (syntax/API smoke; %d draw calls executed; native visual preview required)"%c.draws)
 c.queue_free();quit()
