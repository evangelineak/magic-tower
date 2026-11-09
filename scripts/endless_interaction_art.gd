class_name TowerEndlessInteractionArt
extends RefCounted
## Original flat interaction props; centered 64px design. No lettering or faux 3D.
## On success restores identity draw transform. Unknown tokens do not touch it.
const A=preload("res://scripts/endless_actor_art.gd")
const TOKENS=["S","C","M","a","h","k","D"]
const WOOD=Color("94724e")
const RED=Color("bc6b68")
static func supports(token:String)->bool:return token in TOKENS
static func box(c:CanvasItem,r:Rect2,color:Color):
 c.draw_rect(r,color);c.draw_rect(r,A.INK,false,2.2)
static func draw_token(c:CanvasItem,center:Vector2,token:String,size:float=64.0)->bool:
 if not supports(token) or size<=0 or not is_finite(size):return false
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 match token:
  "S": # Permanent training stele: forked crown, inset sword and stone footing.
   A.poly(c,[[-17,22],[-17,-21],[-10,-29],[0,-22],[10,-29],[17,-21],[17,22]],A.DARK_STEEL)
   A.poly(c,[[-23,22],[23,22],[27,29],[-27,29]],A.STEEL)
   A.poly(c,[[0,-18],[6,-10],[3,5],[-3,5],[-6,-10]],A.LIGHT)
   A.line(c,Vector2(-9,6),Vector2(9,6),A.GOLD,4)
   A.line(c,Vector2(0,8),Vector2(0,17),A.GOLD,4)
   for x in [-12,12]:A.line(c,Vector2(x,-10),Vector2(x,15),A.TEAL,2)
  "C": # Squat strapped transport crate with carry handles and hanging wax seal.
   A.line(c,Vector2(-26,-6),Vector2(-26,7),A.GOLD,4)
   A.line(c,Vector2(26,-6),Vector2(26,7),A.GOLD,4)
   box(c,Rect2(-22,-19,44,42),WOOD)
   A.line(c,Vector2(-19,-5),Vector2(19,-5),A.INK,2)
   A.line(c,Vector2(-19,11),Vector2(19,11),A.INK,2)
   box(c,Rect2(-16,-21,6,46),A.LIGHT);box(c,Rect2(10,-21,6,46),A.LIGHT)
   A.poly(c,[[-7,-20],[7,-20],[7,11],[0,7],[-7,11]],A.TEAL)
   A.poly(c,[[-5,7],[-8,22],[0,18],[7,25],[6,8]],A.LIGHT)
   A.disk(c,Vector2(0,7),7,RED)
   A.line(c,Vector2(-3,7),Vector2(3,7),A.LIGHT,2)
  "M": # Travelling tent wagon: high striped roof, open stall and visible wheels.
   A.disk(c,Vector2(-16,23),6,A.GOLD);A.disk(c,Vector2(16,23),6,A.GOLD)
   for x in [-21,21]:box(c,Rect2(x-2,-10,4,33),WOOD)
   A.poly(c,[[-29,-8],[-16,-26],[16,-26],[29,-8]],A.TEAL)
   A.poly(c,[[-13,-25],[-5,-25],[-9,-9],[-20,-9]],A.LIGHT)
   A.poly(c,[[5,-25],[13,-25],[20,-9],[9,-9]],A.LIGHT)
   box(c,Rect2(-27,-9,54,7),A.CLOTH)
   box(c,Rect2(-23,13,46,9),WOOD)
   A.poly(c,[[-16,11],[-17,3],[-12,0],[-8,3],[-9,11]],A.LIGHT)
   A.disk(c,Vector2(13,7),7,A.GOLD);A.line(c,Vector2(13,3),Vector2(13,11),WOOD,2)
  "a": # Consumable field-training kit: compact crossed practice blade and buckler.
   A.poly(c,[[-23,10],[-16,3],[5,23],[0,29]],WOOD)
   A.poly(c,[[23,-26],[25,-11],[-7,18],[-14,11]],A.STEEL)
   A.line(c,Vector2(20,-20),Vector2(-8,11),A.LIGHT,2)
   A.line(c,Vector2(-17,4),Vector2(-1,20),A.GOLD,5)
   A.poly(c,[[-24,-16],[-11,-22],[3,-16],[1,2],[-11,14],[-23,2]],A.GOLD)
   A.poly(c,[[-19,-12],[-11,-16],[-2,-12],[-4,0],[-11,7],[-18,0]],A.CLOTH)
   A.line(c,Vector2(-11,-12),Vector2(-11,4),A.LIGHT,2)
  "h": # Teal round flask, cork and tied label; large negative-space neck.
   box(c,Rect2(-7,-27,14,7),WOOD)
   A.poly(c,[[-6,-20],[6,-20],[6,-10],[17,-2],[20,9],[15,23],[-15,23],[-20,9],[-17,-2],[-6,-10]],A.TEAL)
   A.line(c,Vector2(-6,-15),Vector2(6,-15),A.GOLD,4)
   A.line(c,Vector2(-11,0),Vector2(-14,7),A.LIGHT,3)
   A.poly(c,[[1,0],[12,4],[8,16],[-3,12]],A.LIGHT)
   A.line(c,Vector2(1,-14),Vector2(7,3),WOOD,2)
  "k": # Open circular bow and two unambiguous teeth, not an ornament.
   A.disk(c,Vector2(-12,-10),12,A.GOLD)
   A.disk(c,Vector2(-12,-10),6,A.INK)
   A.line(c,Vector2(-3,0),Vector2(21,24),A.INK,8)
   A.line(c,Vector2(-3,0),Vector2(21,24),A.GOLD,5)
   A.line(c,Vector2(11,14),Vector2(18,7),A.GOLD,5)
   A.line(c,Vector2(18,21),Vector2(25,14),A.GOLD,5)
  "D": # Closed portal fills tile: stone jambs and central keyhole, not chest.
   A.poly(c,[[-27,29],[-27,-17],[-17,-29],[17,-29],[27,-17],[27,29]],A.DARK_STEEL)
   A.poly(c,[[-18,28],[-18,-13],[-10,-21],[10,-21],[18,-13],[18,28]],WOOD)
   A.line(c,Vector2(0,-19),Vector2(0,27),A.INK,2)
   for y in [-9,18]:A.line(c,Vector2(-17,y),Vector2(17,y),A.GOLD,4)
   A.disk(c,Vector2(0,4),9,A.GOLD)
   A.disk(c,Vector2(0,2),3,A.INK)
   A.poly(c,[[-2,3],[2,3],[3,9],[-3,9]],A.INK)
 c.draw_set_transform(Vector2.ZERO)
 return true
