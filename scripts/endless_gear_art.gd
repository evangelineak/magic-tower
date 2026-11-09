class_name TowerEndlessGearArt
extends RefCounted
## Original flat persistent equipment symbols; no letters or recolored duplicates.
const A=preload("res://scripts/endless_actor_art.gd")
static func draw_gear(c:CanvasItem,center:Vector2,id:String,size:float=64.0)->bool:
 if id not in ["cloak","lens"] or size<=0 or not is_finite(size):return false
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 if id=="cloak":
  A.poly(c,[[-11,-22],[-24,-12],[-29,25],[-13,20],[0,29],[13,20],[29,25],[24,-12],[11,-22]],A.CLOTH)
  A.poly(c,[[-11,-22],[-3,-13],[-10,-2],[-24,-12]],A.LIGHT)
  A.poly(c,[[11,-22],[3,-13],[10,-2],[24,-12]],A.LIGHT)
  A.line(c,Vector2(-14,-2),Vector2(-18,16),A.TEAL,3)
  A.line(c,Vector2(14,-2),Vector2(18,16),A.TEAL,3)
  A.poly(c,[[-11,-8],[11,-8],[9,6],[0,14],[-9,6]],A.GOLD)
  A.poly(c,[[-5,-3],[5,-3],[4,3],[0,7],[-4,3]],A.DARK_STEEL)
  A.line(c,Vector2(0,17),Vector2(0,24),A.GOLD,2)
 else:
  # A single large optical lens with hooked aiming arm and open crosshair.
  A.poly(c,[[-25,12],[-10,8],[5,19],[19,15],[23,22],[4,28],[-12,16],[-24,20]],A.DARK_STEEL)
  A.line(c,Vector2(11,-15),Vector2(27,-15),A.GOLD,5)
  A.line(c,Vector2(26,-24),Vector2(26,-6),A.GOLD,4)
  A.disk(c,Vector2(-5,-5),21,A.GOLD)
  A.disk(c,Vector2(-5,-5),15,A.CLOTH)
  A.line(c,Vector2(-13,-13),Vector2(-7,-18),A.LIGHT,3)
  for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:A.line(c,Vector2(-5,-5)+d*7,Vector2(-5,-5)+d*12,A.LIGHT,2)
  A.disk(c,Vector2(-5,-5),2,A.LIGHT)
 c.draw_set_transform(Vector2.ZERO)
 return true
