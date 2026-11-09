class_name TowerEndlessActorArt
extends RefCounted
## Original flat heraldic characters. Draw within a 64px square, not 3D models.
## Calls restore the local draw transform to identity, matching MapSymbols.
const INK=Color("111f2c")
const GOLD=Color("dfbd72")
const LIGHT=Color("f2dfac")
const TEAL=Color("72b7ad")
const CLOTH=Color("397b78")
const STEEL=Color("a9bec9")
const DARK_STEEL=Color("526d80")
const STANCES=["none","pierce","guard","harvest"]
static func poly(c:CanvasItem,points:Array,color:Color):
 var p=PackedVector2Array()
 for v in points:p.append(Vector2(v[0],v[1]))
 c.draw_colored_polygon(p,color);p.append(p[0]);c.draw_polyline(p,INK,2.2,true)
static func line(c:CanvasItem,a:Vector2,b:Vector2,color:Color=GOLD,width:float=2.0):c.draw_line(a,b,color,width,true)
static func disk(c:CanvasItem,p:Vector2,r:float,color:Color):
 c.draw_circle(p,r,color);c.draw_arc(p,r,0,TAU,28,INK,2,true)
static func boots(c:CanvasItem):
 poly(c,[[-12,15],[-3,15],[-3,27],[-16,27]],DARK_STEEL)
 poly(c,[[3,15],[12,15],[16,27],[3,27]],DARK_STEEL)
static func draw_hero(c:CanvasItem,center:Vector2,stance:String,size:float=64.0):
 if size<=0 or not is_finite(size):return
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 boots(c)
 match stance:
  "pierce":
   # Tall split pennant, narrow breastplate, long spear outside body silhouette.
   poly(c,[[-8,-10],[-20,-3],[-27,19],[-13,13],[-6,25],[1,8]],CLOTH)
   poly(c,[[-11,-8],[8,-8],[12,13],[0,22],[-11,13]],STEEL)
   line(c,Vector2(-4,-4),Vector2(-4,13),LIGHT,3)
   poly(c,[[-10,-11],[-11,-22],[-3,-29],[8,-23],[10,-10]],DARK_STEEL)
   poly(c,[[-5,-27],[3,-32],[11,-27],[8,-20]],TEAL)
   line(c,Vector2(-6,-17),Vector2(5,-17),LIGHT,3)
   line(c,Vector2(18,-18),Vector2(18,28),INK,6)
   line(c,Vector2(18,-18),Vector2(18,28),GOLD,3)
   poly(c,[[18,-32],[25,-18],[18,-12],[11,-18]],STEEL)
   poly(c,[[19,-12],[30,-8],[20,-3]],TEAL)
   poly(c,[[4,-2],[14,-5],[19,1],[13,5],[6,5]],DARK_STEEL)
  "guard":
   # Broad crenellated shoulders and kite shield; helmet stays visible above it.
   poly(c,[[-19,-10],[-27,-5],[-23,22],[0,29],[23,22],[27,-5],[19,-10]],CLOTH)
   poly(c,[[-26,-12],[-13,-17],[-8,-7],[-17,1],[-28,-1]],STEEL)
   poly(c,[[26,-12],[13,-17],[8,-7],[17,1],[28,-1]],STEEL)
   poly(c,[[-11,-12],[-11,-24],[-5,-29],[5,-29],[11,-24],[11,-12]],DARK_STEEL)
   line(c,Vector2(-7,-19),Vector2(7,-19),LIGHT,3)
   poly(c,[[-22,-5],[22,-5],[19,18],[0,31],[-19,18]],GOLD)
   poly(c,[[-16,0],[16,0],[13,15],[0,24],[-13,15]],DARK_STEEL)
   poly(c,[[0,1],[8,10],[0,20],[-8,10]],TEAL)
   line(c,Vector2(0,3),Vector2(0,17),LIGHT,2)
  "harvest":
   # Crooked hood and open crescent blade, visibly different from spear/shield.
   poly(c,[[-14,-5],[-27,23],[-13,20],[-6,29],[2,19],[14,27],[18,-5]],CLOTH)
   poly(c,[[-12,-11],[-10,-25],[5,-31],[15,-17],[10,-8]],TEAL)
   poly(c,[[-7,-12],[-6,-21],[3,-23],[8,-15],[5,-10]],INK)
   line(c,Vector2(-4,-15),Vector2(3,-16),LIGHT,2)
   poly(c,[[-10,-2],[5,-5],[10,10],[2,18],[-12,11]],DARK_STEEL)
   line(c,Vector2(-10,6),Vector2(7,6),GOLD,3)
   line(c,Vector2(14,-7),Vector2(24,26),INK,6)
   line(c,Vector2(14,-7),Vector2(24,26),GOLD,3)
   poly(c,[[11,-13],[15,-23],[25,-27],[31,-22],[24,-20],[21,-14],[23,-8],[29,-6],[22,-2],[14,-5]],STEEL)
   poly(c,[[-17,3],[-23,7],[-21,15],[-13,12]],GOLD)
  _:
   # Traveller keeps the established hood, small buckler and upright sword.
   poly(c,[[-13,-8],[13,-8],[25,27],[0,19],[-25,27]],CLOTH)
   poly(c,[[-10,-5],[10,-5],[10,20],[-10,20]],STEEL)
   disk(c,Vector2(0,-15),10,GOLD)
   poly(c,[[-13,-12],[-10,-26],[0,-31],[10,-26],[13,-12]],TEAL)
   line(c,Vector2(-6,-16),Vector2(6,-16),INK,3)
   poly(c,[[-25,-1],[-9,-1],[-10,16],[-17,23],[-24,16]],GOLD)
   poly(c,[[18,-25],[22,-18],[22,14],[18,14]],STEEL)
   line(c,Vector2(13,8),Vector2(27,8),GOLD,3)
 c.draw_set_transform(Vector2.ZERO)
static func draw_enemy(c:CanvasItem,center:Vector2,token:String,size:float=64.0)->bool:
 if token not in ["g","b","w","V"] or size<=0 or not is_finite(size):return false
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 match token:
  "g":
   boots(c)
   poly(c,[[-23,-13],[-11,-21],[12,-21],[22,-12],[15,20],[-15,20]],DARK_STEEL)
   poly(c,[[-10,-26],[9,-26],[13,-11],[-13,-11]],STEEL)
   line(c,Vector2(-8,-18),Vector2(8,-18),INK,4)
   poly(c,[[-26,-2],[3,-2],[2,22],[-12,29],[-25,21]],Color("496b7b"))
   line(c,Vector2(-20,3),Vector2(-3,20),GOLD,3)
   line(c,Vector2(24,-26),Vector2(24,27),STEEL,4)
   poly(c,[[24,-31],[29,-21],[19,-21]],GOLD)
  "b":
   poly(c,[[-14,0],[14,0],[21,20],[8,23],[0,15],[-8,23],[-21,20]],Color("94724e"))
   poly(c,[[-27,-17],[-10,-13],[0,-25],[10,-13],[27,-17],[17,7],[0,14],[-17,7]],Color("bb9771"))
   line(c,Vector2(-11,-4),Vector2(-4,-1),INK,3);line(c,Vector2(4,-1),Vector2(11,-4),INK,3)
   poly(c,[[-26,4],[-20,7],[-9,24],[-15,27],[-28,10]],STEEL)
   poly(c,[[26,4],[20,7],[9,24],[15,27],[28,10]],STEEL)
   line(c,Vector2(-24,12),Vector2(-16,7),GOLD,3);line(c,Vector2(24,12),Vector2(16,7),GOLD,3)
  "w":
   poly(c,[[0,-29],[-15,-9],[-25,26],[0,18],[25,26],[15,-9]],Color("8b718f"))
   poly(c,[[-9,-13],[0,-22],[9,-13],[7,-2],[-7,-2]],INK)
   line(c,Vector2(-5,-9),Vector2(5,-9),TEAL,3)
   line(c,Vector2(0,3),Vector2(0,17),GOLD,2)
   line(c,Vector2(24,-17),Vector2(24,27),GOLD,3)
   disk(c,Vector2(24,-22),6,TEAL)
   poly(c,[[-24,4],[-14,2],[-12,14],[-25,17]],LIGHT)
  "V":
   poly(c,[[-29,-16],[-19,-24],[19,-24],[29,-16],[25,22],[0,30],[-25,22]],Color("a57a62"))
   poly(c,[[-14,-23],[14,-23],[18,-5],[-18,-5]],DARK_STEEL)
   poly(c,[[-17,-23],[-18,-31],[-8,-25]],GOLD);poly(c,[[17,-23],[18,-31],[8,-25]],GOLD)
   line(c,Vector2(-10,-13),Vector2(-4,-13),LIGHT,3);line(c,Vector2(4,-13),Vector2(10,-13),LIGHT,3)
   poly(c,[[-20,-1],[20,-1],[18,20],[0,31],[-18,20]],DARK_STEEL)
   poly(c,[[0,4],[11,13],[0,25],[-11,13]],GOLD)
   line(c,Vector2(0,6),Vector2(0,22),INK,2)
 c.draw_set_transform(Vector2.ZERO)
 return true
