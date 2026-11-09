class_name TowerEndlessEnemyV12Art
extends RefCounted
## Original planar silhouettes. Thorn wreath and hollow-mask branch priest.
const A=preload("res://scripts/endless_actor_art.gd")
static func draw_enemy(c:CanvasItem,center:Vector2,token:String,size:float=64.0)->bool:
 if token not in ["t","p"] or size<=0 or not is_finite(size):return false
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 if token=="t":
  # Four grasping roots; round open body with radial armor thorns, not a shield.
  A.poly(c,[[-14,9],[-25,17],[-29,28],[-19,23],[-11,26],[-7,15]],Color("94724e"))
  A.poly(c,[[14,9],[25,17],[29,28],[19,23],[11,26],[7,15]],Color("94724e"))
  A.poly(c,[[-5,16],[-11,30],[-2,25],[2,16]],A.CLOTH)
  A.poly(c,[[5,16],[11,30],[2,25],[-2,16]],A.CLOTH)
  A.poly(c,[[0,-31],[7,-22],[20,-27],[20,-14],[31,-9],[23,0],[28,13],[15,13],[8,25],[0,18],[-8,25],[-15,13],[-28,13],[-23,0],[-31,-9],[-20,-14],[-20,-27],[-7,-22]],A.GOLD)
  A.disk(c,Vector2(0,-3),22,A.CLOTH)
  A.disk(c,Vector2(0,-3),13,A.INK)
  A.poly(c,[[-12,-8],[-4,-5],[-7,1],[-12,-1]],A.LIGHT)
  A.poly(c,[[12,-8],[4,-5],[7,1],[12,-1]],A.LIGHT)
  A.line(c,Vector2(-13,11),Vector2(-20,4),A.TEAL,3)
  A.line(c,Vector2(13,-18),Vector2(20,-10),A.TEAL,3)
 else:
  # Floating narrow mask, exposed root limbs, branching crook; deliberately no robe.
  A.poly(c,[[-6,0],[-13,16],[-24,27],[-12,24],[-3,13],[1,27],[8,29],[7,11],[12,19],[20,23],[14,12],[8,-1]],A.CLOTH)
  A.poly(c,[[-11,-19],[-7,-28],[4,-31],[12,-23],[10,-5],[0,7],[-10,-5]],A.LIGHT)
  A.poly(c,[[-6,-18],[-3,-24],[4,-23],[7,-16],[4,-7],[0,-2],[-5,-9]],A.INK)
  A.line(c,Vector2(-6,-13),Vector2(5,-15),A.TEAL,2)
  A.poly(c,[[-13,-2],[-23,5],[-28,16],[-20,13],[-16,7],[-7,5]],A.STEEL)
  A.line(c,Vector2(24,-19),Vector2(22,29),A.INK,7)
  A.line(c,Vector2(24,-19),Vector2(22,29),A.GOLD,3)
  A.line(c,Vector2(24,-16),Vector2(15,-28),A.GOLD,3)
  A.line(c,Vector2(24,-19),Vector2(31,-26),A.GOLD,3)
  A.poly(c,[[24,-26],[29,-17],[24,-8],[19,-17]],A.TEAL)
  A.line(c,Vector2(20,-17),Vector2(23,-17),A.LIGHT,2)
  A.line(c,Vector2(23,-17),Vector2(25,-21),A.LIGHT,2)
  A.line(c,Vector2(25,-21),Vector2(27,-15),A.LIGHT,2)
  A.poly(c,[[7,4],[17,1],[23,5],[21,10],[12,10]],A.STEEL)
 c.draw_set_transform(Vector2.ZERO)
 return true
