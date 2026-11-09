class_name TowerEndlessVaultArt
extends RefCounted
const A=preload("res://scripts/endless_actor_art.gd")
const WOOD=Color("94724e")
static func draw_cache(c:CanvasItem,center:Vector2,kind:String,size:float=64)->bool:
 if kind not in ["gold","medicine","ward","pierce"] or size<=0:return false
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 match kind:
  "gold":
   A.poly(c,[[-27,-9],[-18,-21],[18,-21],[27,-9],[27,25],[-27,25]],WOOD)
   for x in [-19,19]:A.line(c,Vector2(x,-17),Vector2(x,23),A.STEEL,5)
   A.line(c,Vector2(-24,0),Vector2(24,0),A.INK,3)
   for p in [Vector2(-9,10),Vector2(9,10),Vector2(0,0)]:
    A.disk(c,p,8,A.GOLD);A.line(c,p+Vector2(0,-4),p+Vector2(0,4),WOOD,2)
  "medicine":
   # Wide square medicine cabinet, unlike small round floor flask.
   A.poly(c,[[-28,-26],[28,-26],[28,28],[-28,28]],A.DARK_STEEL)
   A.poly(c,[[-22,-20],[22,-20],[22,22],[-22,22]],WOOD)
   A.poly(c,[[-7,-19],[7,-19],[7,-9],[16,-3],[16,20],[-16,20],[-16,-3],[-7,-9]],A.TEAL)
   A.line(c,Vector2(-8,-20),Vector2(8,-20),A.GOLD,5)
   A.line(c,Vector2(-9,8),Vector2(9,8),A.LIGHT,5)
   A.line(c,Vector2(0,-1),Vector2(0,17),A.LIGHT,5)
  "ward":
   # Broad soft textile bundle with looped cord and woven shield clasp.
   A.poly(c,[[-9,-14],[-21,-7],[-28,15],[-20,27],[19,27],[28,15],[20,-7],[8,-14]],A.TEAL)
   for side in [-1,1]:
    A.line(c,Vector2(0,-15),Vector2(side*17,-27),A.GOLD,4)
    A.line(c,Vector2(side*17,-27),Vector2(side*21,-16),A.GOLD,4)
    A.line(c,Vector2(side*21,-16),Vector2.ZERO+Vector2(0,-12),A.GOLD,4)
   A.line(c,Vector2(-12,-10),Vector2(12,-10),A.LIGHT,5)
   A.poly(c,[[-11,0],[11,0],[10,14],[0,22],[-10,14]],A.GOLD)
   A.line(c,Vector2(0,4),Vector2(0,15),A.CLOTH,3)
  "pierce":
   # Open low rack with three distinct spike tips, no lid/round silhouette.
   for i in 3:
    var x=-17+i*17;var y=-27+absi(i-1)*7
    A.poly(c,[[x,y],[x+6,y+10],[x+4,16],[x-4,16],[x-6,y+10]],A.STEEL)
    A.line(c,Vector2(x,y+6),Vector2(x,13),A.LIGHT,2)
   A.poly(c,[[-28,10],[28,10],[24,27],[-24,27]],WOOD)
   A.line(c,Vector2(-26,16),Vector2(26,16),A.GOLD,4)
 c.draw_set_transform(Vector2.ZERO);return true
