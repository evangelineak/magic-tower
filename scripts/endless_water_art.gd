class_name TowerEndlessWaterArt
extends RefCounted
## Flat flood basin: exposed stone bed vs continuous deep water, not just a hue swap.
const A=preload("res://scripts/endless_actor_art.gd")
const DEEP=Color("102d40")
const WAVE=Color("365b6b")
const SILT=Color("665f50")
static func draw_pool(c:CanvasItem,p:Vector2,deep:bool,edges:int=15,size:float=64):
 c.draw_set_transform(p,0,Vector2.ONE*size/64.0)
 c.draw_rect(Rect2(-32,-32,64,64),DEEP if deep else Color("394747"))
 if deep:
  # Quiet open water; no collectible-looking sparkles.
  for row in [-13,11]:
   c.draw_polyline(PackedVector2Array([Vector2(-24,row),Vector2(-14,row-2),Vector2(-3,row+1),Vector2(8,row-1),Vector2(19,row+1)]),WAVE,1.5)
 else:
  A.poly(c,[[-26,-23],[-7,-26],[2,-17],[-1,-3],[-23,-2]],A.DARK_STEEL)
  A.poly(c,[[8,-21],[25,-18],[26,3],[8,7],[4,-5]],A.STEEL.darkened(0.2))
  A.poly(c,[[-19,7],[0,4],[17,15],[11,27],[-17,25]],A.STEEL.darkened(0.12))
  for point in [Vector2(-27,15),Vector2(23,24),Vector2(5,-28)]:c.draw_circle(point,2,SILT)
 var segments=[PackedVector2Array([Vector2(-32,-29),Vector2(-11,-27),Vector2(12,-30),Vector2(32,-28)]),PackedVector2Array([Vector2(28,-32),Vector2(30,-9),Vector2(27,12),Vector2(29,32)]),PackedVector2Array([Vector2(-32,29),Vector2(-9,27),Vector2(12,30),Vector2(32,28)]),PackedVector2Array([Vector2(-29,-32),Vector2(-27,-12),Vector2(-30,9),Vector2(-28,32)])]
 for i in 4:
  if edges & (1<<i):c.draw_polyline(segments[i],Color("61716c") if deep else Color("58615a"),3 if deep else 1)
 c.draw_set_transform(Vector2.ZERO)
static func draw_valve(c:CanvasItem,p:Vector2,state:String,available:bool=true,size:float=64):
 c.draw_set_transform(p,0,Vector2.ONE*size/64.0)
 A.poly(c,[[-26,-20],[26,-20],[28,26],[-28,26]],A.DARK_STEEL)
 # Two basin gauges: water ripples versus exposed stone, mapping the upper/lower pools.
 for i in 2:
  var y=-12+i*24
  var wet=(state=="A" and i==1) or (state=="B" and i==0)
  c.draw_rect(Rect2(-20,y-6,25,14),DEEP if wet else A.STEEL)
  if wet:c.draw_line(Vector2(-18,y+2),Vector2(2,y+2),A.TEAL,2)
  else:c.draw_line(Vector2(-12,y-5),Vector2(-8,y+6),A.INK,2)
 A.line(c,Vector2(14,-22),Vector2(14,23),A.STEEL,4)
 var y=-12 if state=="A" else 12
 A.line(c,Vector2(14,y),Vector2(25,y-5),A.GOLD,5)
 A.disk(c,Vector2(25,y-5),5,A.LIGHT if available else A.GOLD)
 c.draw_set_transform(Vector2.ZERO)
