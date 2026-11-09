class_name TowerEndlessRuneArt
extends RefCounted
## Small flat mechanical seal; open latches indicate permanent activation.
const A=preload("res://scripts/endless_actor_art.gd")
static func draw_rune(c:CanvasItem,center:Vector2,kind:String,active:bool,size:float=32.0):
 if size<=0 or not is_finite(size):return
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 A.poly(c,[[-20,-27],[20,-27],[27,-20],[27,20],[20,27],[-20,27],[-27,20],[-27,-20]],A.DARK_STEEL)
 A.disk(c,Vector2.ZERO,20,A.INK)
 if active:
  for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
   var p=d*27
   A.line(c,p-d*3,p+d*3,A.GOLD,5)
 else:
  A.line(c,Vector2(-20,-23),Vector2(20,-23),A.STEEL,3)
  A.line(c,Vector2(-20,23),Vector2(20,23),A.STEEL,3)
 if kind=="shock":
  A.poly(c,[[2,-18],[-13,2],[-2,2],[-7,19],[14,-5],[3,-5],[8,-18]],A.GOLD)
 else:
  c.draw_arc(Vector2.ZERO,12,0.2,2.7,18,A.TEAL,4,true)
  c.draw_arc(Vector2.ZERO,12,3.34,5.84,18,A.TEAL,4,true)
  A.line(c,Vector2(-14,14),Vector2(14,-14),A.LIGHT,5)
 c.draw_set_transform(Vector2.ZERO)
