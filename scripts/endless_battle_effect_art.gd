class_name TowerEndlessBattleEffectArt
extends RefCounted
## Cosmetic attack cues, never a simulated sequence of combat events.
const A=preload("res://scripts/endless_actor_art.gd")
static func draw_attack(c:CanvasItem,start:Vector2,finish:Vector2,hero:String,progress:float):
 var p=start.lerp(finish,clampf(progress,0,1))
 match hero:
  "ranger":
   c.draw_line(p-Vector2(25,0),p+Vector2(17,0),A.LIGHT,3)
   c.draw_colored_polygon(PackedVector2Array([p+Vector2(25,0),p+Vector2(13,-7),p+Vector2(13,7)]),A.GOLD)
   for y in [-1,1]:c.draw_line(p-Vector2(24,0),p+Vector2(-32,y*7),A.TEAL,3)
  "warden":
   c.draw_arc(p,20,-1.2,1.2,18,A.GOLD,5)
   c.draw_arc(p-Vector2(10,0),16,-1.2,1.2,18,A.STEEL,3)
   c.draw_line(p+Vector2(23,-5),p+Vector2(32,-9),A.LIGHT,2)
   c.draw_line(p+Vector2(23,5),p+Vector2(32,9),A.LIGHT,2)
  "scholar":
   c.draw_arc(p,15,0.3,5.7,20,A.TEAL,3)
   c.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(7,0),p+Vector2(0,10),p-Vector2(7,0)]),A.LIGHT)
   c.draw_line(p-Vector2(27,0),p-Vector2(19,0),A.TEAL,2)
  _:
   c.draw_line(p-Vector2(12,17),p+Vector2(12,-17),A.GOLD,4)
