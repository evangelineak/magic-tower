class_name TowerEndlessBridgeArt
extends RefCounted
## Original flat top-down mechanism. Gap, continuous planks and cross-pins differ by shape.
const A=preload("res://scripts/endless_actor_art.gd")
const WOOD=Color("94724e")
const GAP=Color("09131e")
static func draw_bridge(c:CanvasItem,center:Vector2,state:String,vertical:bool=false,size:float=64.0)->bool:
 if state not in ["raised","open","locked"] or size<=0 or not is_finite(size):return false
 c.draw_set_transform(center,PI/2 if vertical else 0.0,Vector2.ONE*size/64.0)
 c.draw_rect(Rect2(-31,-25,62,50),GAP)
 for x in [-29,29]:
  A.line(c,Vector2(x,-26),Vector2(x,26),A.STEEL,5)
  A.disk(c,Vector2(x,-23),3,A.GOLD);A.disk(c,Vector2(x,23),3,A.GOLD)
 if state=="open":
  A.poly(c,[[-30,-18],[30,-18],[30,18],[-30,18]],WOOD)
  for x in [-20,-10,0,10,20]:A.line(c,Vector2(x,-17),Vector2(x,17),A.INK,2)
  for y in [-22,22]:A.line(c,Vector2(-29,y),Vector2(29,y),A.GOLD,2)
 else:
  # Folded board stacks stay against the banks, leaving a real visible middle gap.
  for side in [-1,1]:
   A.poly(c,[[side*30,-18],[side*18,-18],[side*15,-10],[side*18,18],[side*30,18]],WOOD)
   for y in [-9,0,9]:A.line(c,Vector2(side*20,y),Vector2(side*29,y),A.INK,2)
   A.line(c,Vector2(side*20,-22),Vector2(side*29,-22),A.GOLD,2)
  if state=="locked":
   A.line(c,Vector2(-14,-15),Vector2(14,15),A.INK,9)
   A.line(c,Vector2(-14,15),Vector2(14,-15),A.INK,9)
   A.line(c,Vector2(-14,-15),Vector2(14,15),A.STEEL,5)
   A.line(c,Vector2(-14,15),Vector2(14,-15),A.STEEL,5)
   A.disk(c,Vector2.ZERO,6,A.GOLD)
 c.draw_set_transform(Vector2.ZERO);return true
static func draw_winch(c:CanvasItem,center:Vector2,used:bool=false,size:float=64.0):
 if size<=0 or not is_finite(size):return
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 A.poly(c,[[-23,-19],[23,-19],[27,23],[-27,23]],A.DARK_STEEL)
 for side in [-1,1]:
  A.line(c,Vector2(side*10,-6),Vector2(side*28,-27),A.GOLD,3)
  A.line(c,Vector2(side*17,-16),Vector2(side*23,-10),A.STEEL,2)
 A.disk(c,Vector2(0,0),19,WOOD);A.disk(c,Vector2.ZERO,13,A.GOLD)
 for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:A.line(c,Vector2.ZERO,d*16,A.INK,3)
 A.disk(c,Vector2.ZERO,5,A.STEEL)
 if used:A.line(c,Vector2(-17,19),Vector2(17,19),A.STEEL,5)
 else:
  A.line(c,Vector2(0,0),Vector2(13,-19),A.LIGHT,4)
  A.disk(c,Vector2(14,-21),4,A.LIGHT)
 c.draw_set_transform(Vector2.ZERO)
static func draw_tool_cache(c:CanvasItem,center:Vector2,size:float=64.0):
 if size<=0 or not is_finite(size):return
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 A.poly(c,[[-25,-3],[-18,-12],[18,-12],[25,-3],[25,25],[-25,25]],WOOD)
 A.line(c,Vector2(-23,5),Vector2(23,5),A.INK,3)
 for x in [-18,18]:A.line(c,Vector2(x,-9),Vector2(x,24),A.STEEL,4)
 A.poly(c,[[-20,-23],[-4,-23],[-5,-9],[-12,-2],[-19,-9]],A.TEAL)
 A.line(c,Vector2(-12,-20),Vector2(-12,-7),A.LIGHT,2)
 A.poly(c,[[12,-29],[17,-21],[14,-4],[9,-4],[7,-21]],A.STEEL)
 A.line(c,Vector2(6,-5),Vector2(19,-5),A.GOLD,3)
 A.line(c,Vector2(12,-3),Vector2(12,3),A.GOLD,4)
 c.draw_set_transform(Vector2.ZERO)
