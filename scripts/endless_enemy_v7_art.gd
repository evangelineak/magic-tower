class_name TowerEndlessEnemyV7Art
extends RefCounted
## Original flat silhouettes for deterministic v7 combat mechanics.
## r: ready crossbow intercepts before the hero. c: overhead hammer charges retaliation.
const A=preload("res://scripts/endless_actor_art.gd")
const TOKENS=["r","c"]
static func draw_enemy(canvas:CanvasItem,center:Vector2,token:String,size:float=64.0)->bool:
 if token not in TOKENS or size<=0 or not is_finite(size):return false
 canvas.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 match token:
  "r":
   # Asymmetric forward lean, flying short cape, low sweeping crossbow.
   A.poly(canvas,[[-9,-13],[-21,-10],[-29,8],[-18,3],[-20,13],[-6,6]],A.CLOTH)
   A.poly(canvas,[[-8,10],[2,11],[-4,28],[-17,28]],A.DARK_STEEL)
   A.poly(canvas,[[2,10],[10,7],[18,23],[25,27],[12,28],[3,20]],A.DARK_STEEL)
   A.poly(canvas,[[-10,-14],[4,-18],[13,-3],[8,14],[-4,18],[-13,6]],Color("94724e"))
   A.line(canvas,Vector2(-8,-5),Vector2(7,8),A.GOLD,3)
   A.poly(canvas,[[-5,-18],[-7,-27],[3,-30],[12,-23],[9,-14],[0,-13]],A.STEEL)
   A.poly(canvas,[[-10,-24],[-7,-30],[5,-31],[15,-24],[7,-22]],A.CLOTH)
   A.line(canvas,Vector2(4,-20),Vector2(10,-20),A.INK,3)
   # Bow limbs make a broad horizontal open chevron, unlike all existing weapons.
   A.poly(canvas,[[-28,1],[-24,-9],[-19,-13],[-18,-7],[-23,2],[0,8],[23,2],[18,-7],[19,-13],[24,-9],[28,1],[25,8],[0,15],[-25,8]],A.STEEL)
   A.line(canvas,Vector2(-19,-10),Vector2(0,8),A.LIGHT,1.7)
   A.line(canvas,Vector2(19,-10),Vector2(0,8),A.LIGHT,1.7)
   A.poly(canvas,[[-3,-8],[3,-8],[3,20],[-3,20]],A.GOLD)
   A.poly(canvas,[[0,-16],[4,-7],[-4,-7]],A.LIGHT)
   A.poly(canvas,[[-14,-2],[-8,0],[-4,7],[-10,10]],Color("bb9771"))
  "c":
   # Squat mass beneath an overhead hammer; no shield or horned helmet.
   A.poly(canvas,[[-19,12],[-5,12],[-5,28],[-23,28]],A.DARK_STEEL)
   A.poly(canvas,[[5,12],[19,12],[23,28],[5,28]],A.DARK_STEEL)
   A.poly(canvas,[[-21,-4],[-10,-12],[10,-12],[21,-4],[18,18],[0,24],[-18,18]],Color("a57a62"))
   A.poly(canvas,[[-16,-1],[16,-1],[13,16],[0,21],[-13,16]],A.DARK_STEEL)
   A.line(canvas,Vector2(-11,7),Vector2(11,7),A.GOLD,4)
   A.poly(canvas,[[-10,-12],[-10,-23],[-4,-28],[6,-27],[12,-19],[9,-10]],A.STEEL)
   A.line(canvas,Vector2(-6,-17),Vector2(6,-17),A.INK,4)
   # Both raised arms wrap around a diagonal haft before its impact.
   A.poly(canvas,[[-21,3],[-28,-4],[-28,-18],[-20,-21],[-18,-7],[-11,-2]],A.STEEL)
   A.poly(canvas,[[13,1],[22,-5],[17,-19],[10,-17],[13,-8],[7,-4]],A.STEEL)
   A.line(canvas,Vector2(-21,-18),Vector2(18,-27),A.INK,8)
   A.line(canvas,Vector2(-21,-18),Vector2(18,-27),A.GOLD,4)
   A.poly(canvas,[[10,-32],[27,-32],[31,-14],[14,-11]],A.DARK_STEEL)
   A.poly(canvas,[[11,-31],[16,-32],[20,-12],[15,-11]],A.LIGHT)
   A.line(canvas,Vector2(22,-28),Vector2(25,-17),A.TEAL,3)
   A.poly(canvas,[[-25,-21],[-18,-23],[-15,-16],[-22,-13]],Color("bb9771"))
 canvas.draw_set_transform(Vector2.ZERO)
 return true
