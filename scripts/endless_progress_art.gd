class_name TowerEndlessProgressArt
extends RefCounted
const A=preload("res://scripts/endless_actor_art.gd")
static func draw_icon(c:CanvasItem,p:Vector2,id:String,size:float=64):
 c.draw_set_transform(p,0,Vector2.ONE*size/64.0)
 match id:
  "none":
   c.draw_arc(Vector2.ZERO,23,0.3,5.7,24,A.STEEL,4)
   A.disk(c,Vector2.ZERO,5,A.TEAL)
  "kit":
   A.poly(c,[[-24,-9],[-12,-21],[12,-21],[24,-9],[24,24],[-24,24]],A.CLOTH)
   for x in [-15,15]:A.line(c,Vector2(x,-14),Vector2(x,24),A.GOLD,4)
   A.line(c,Vector2(-7,-23),Vector2(7,-23),A.LIGHT,4)
   A.poly(c,[[-8,-3],[8,-3],[7,10],[0,17],[-7,10]],A.STEEL)
  "coin":
   A.poly(c,[[-25,5],[-17,-8],[21,-8],[27,5],[20,25],[-22,25]],A.CLOTH)
   for pos in [Vector2(-10,0),Vector2(10,-10),Vector2(3,13)]:
    A.disk(c,pos,10,A.GOLD);A.line(c,pos+Vector2(0,-5),pos+Vector2(0,5),A.CLOTH,3)
  "mind","reserve":
   A.poly(c,[[-20,-3],[-13,-21],[0,-27],[13,-21],[20,-3],[13,20],[-13,20]],A.STEEL)
   if id=="mind":
    A.poly(c,[[0,-20],[10,-7],[0,12],[-10,-7]],A.TEAL)
    A.line(c,Vector2(-13,25),Vector2(13,25),A.GOLD,4)
   else:
    for y in [-12,0,12]:A.line(c,Vector2(-10,y),Vector2(10,y),A.TEAL,5)
  "tracker":
   for pos in [Vector2(-13,12),Vector2(9,-9)]:
    A.poly(c,[[pos.x-7,pos.y-12],[pos.x+6,pos.y-10],[pos.x+8,pos.y+8],[pos.x-4,pos.y+12],[pos.x-8,pos.y+4]],A.GOLD)
   A.line(c,Vector2(-20,-18),Vector2(-11,-26),A.TEAL,3)
  "laststand":
   A.poly(c,[[-23,-22],[23,-22],[19,9],[0,28],[-19,9]],A.STEEL)
   A.poly(c,[[0,-21],[-6,-6],[4,1],[-4,20],[10,-1],[0,-9]],A.INK)
   A.poly(c,[[-11,2],[-6,-3],[0,2],[6,-3],[11,2],[0,13]],A.GOLD)
  "alert":
   A.poly(c,[[-28,0],[-13,-13],[13,-13],[28,0],[13,13],[-13,13]],A.LIGHT)
   A.disk(c,Vector2.ZERO,9,A.TEAL);A.disk(c,Vector2.ZERO,4,A.INK)
   for x in [-16,0,16]:A.line(c,Vector2(x,-19),Vector2(x,-27),A.GOLD,3)
  "light":
   A.poly(c,[[-22,24],[-13,-3],[6,-25],[25,-29],[19,-8],[0,12]],A.LIGHT)
   A.line(c,Vector2(-20,27),Vector2(20,-23),A.GOLD,3)
   for i in 3:A.line(c,Vector2(-7+i*7,8-i*8),Vector2(5+i*6,9-i*8),A.TEAL,2)
  "wardweave":
   A.poly(c,[[-24,-21],[24,-21],[20,10],[0,29],[-20,10]],A.CLOTH)
   for i in [-1,0,1]:
    A.line(c,Vector2(-17,-13+i*8),Vector2(16,9+i*5),A.GOLD,3)
    A.line(c,Vector2(17,-13+i*8),Vector2(-16,9+i*5),A.TEAL,3)
  "deepdrill":
   A.poly(c,[[0,-29],[12,-12],[8,21],[-8,21],[-12,-12]],A.STEEL)
   for y in [-8,3,14]:A.line(c,Vector2(-11,y+5),Vector2(11,y-4),A.GOLD,4)
   A.line(c,Vector2(-17,24),Vector2(17,24),A.TEAL,5)
  "mender":
   A.poly(c,[[-26,11],[-16,-7],[0,-15],[17,-5],[27,12],[10,25],[-10,25]],A.TEAL)
   A.line(c,Vector2(-15,-4),Vector2(13,17),A.LIGHT,7)
   for d in [-7,2,11]:A.line(c,Vector2(d-4,d-7),Vector2(d+2,d-14),A.GOLD,3)
  "overload":
   c.draw_arc(Vector2.ZERO,25,0.3,2.7,16,A.STEEL,4)
   c.draw_arc(Vector2.ZERO,25,3.5,5.9,16,A.STEEL,4)
   A.poly(c,[[9,-30],[-16,4],[-2,4],[-9,30],[17,-7],[3,-7]],A.GOLD)
 c.draw_set_transform(Vector2.ZERO)
