class_name TowerEndlessHeroV20Art
extends RefCounted
const A=preload("res://scripts/endless_actor_art.gd")
static func draw_hero(c:CanvasItem,p:Vector2,id:String,size:float=64):
 if id=="warden":A.draw_hero(c,p,"guard",size);return
 c.draw_set_transform(p,0,Vector2.ONE*size/64.0)
 if id=="ranger":
  A.poly(c,[[-18,-10],[-5,-20],[13,-10],[19,23],[-23,27]],A.CLOTH)
  A.line(c,Vector2(-9,16),Vector2(-10,29),A.STEEL,7)
  A.line(c,Vector2(9,17),Vector2(13,28),A.STEEL,7)
  A.disk(c,Vector2(-1,-18),9,A.LIGHT)
  A.poly(c,[[-14,-15],[-10,-29],[3,-30],[12,-16],[1,-23]],A.TEAL)
  A.line(c,Vector2(-15,1),Vector2(17,-1),A.GOLD,5)
  A.line(c,Vector2(18,-26),Vector2(28,-12),A.GOLD,4)
  A.line(c,Vector2(28,-12),Vector2(29,11),A.GOLD,4)
  A.line(c,Vector2(29,11),Vector2(18,27),A.GOLD,4)
  A.line(c,Vector2(18,-26),Vector2(18,27),A.LIGHT,1.5)
  A.line(c,Vector2(-6,3),Vector2(30,3),A.STEEL,2)
 else:
  A.poly(c,[[-9,-9],[9,-9],[19,27],[-19,27]],A.CLOTH)
  A.disk(c,Vector2(0,-20),9,A.LIGHT)
  A.poly(c,[[-12,-17],[-8,-30],[8,-30],[12,-17],[0,-23]],A.STEEL)
  A.line(c,Vector2(24,-22),Vector2(24,27),A.GOLD,4)
  A.disk(c,Vector2(24,-23),6,A.TEAL)
  A.poly(c,[[-24,-2],[-8,-5],[0,0],[8,-5],[15,-2],[15,16],[0,20],[-24,15]],A.GOLD)
  A.poly(c,[[-20,1],[-8,-1],[0,4],[0,16],[-20,12]],A.LIGHT)
  A.poly(c,[[0,4],[8,-1],[11,1],[11,12],[0,16]],A.STEEL)
  A.line(c,Vector2(0,4),Vector2(0,17),A.INK,2)
 c.draw_set_transform(Vector2.ZERO)
