class_name TowerEndlessCartArt
extends RefCounted
## Original flat stone/bronze mechanism; grooves are restricted to the actual board.
const A=preload("res://scripts/endless_actor_art.gd")
const BRONZE=Color("b39b64")
const STONE=Color("9caeaf")
static func start(c:CanvasItem,p:Vector2,size:float):c.draw_set_transform(p,0,Vector2.ONE*size/64.0)
static func finish(c:CanvasItem):c.draw_set_transform(Vector2.ZERO)
static func mark(c:CanvasItem,kind:String,at:Vector2=Vector2.ZERO,scale_value:float=1):
 if kind=="supply":
  for x in [-7,7]:A.line(c,at+Vector2(x,-10)*scale_value,at+Vector2(x,10)*scale_value,A.GOLD,3*scale_value)
 else:
  for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
   A.line(c,at+d*10*scale_value,at+Vector2(d.x*4,d.y*10)*scale_value,A.GOLD,3*scale_value)
   A.line(c,at+d*10*scale_value,at+Vector2(d.x*10,d.y*4)*scale_value,A.GOLD,3*scale_value)
static func draw_track(c:CanvasItem,p:Vector2,origin:bool=false,size:float=64):
 start(c,p,size)
 for x in [-25,25]:c.draw_line(Vector2(x,-31),Vector2(x,31),Color("354956"),2)
 for y in [-25,25]:c.draw_line(Vector2(-31,y),Vector2(31,y),Color("354956"),2)
 if origin:
  for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
   c.draw_line(d*19,Vector2(d.x*11,d.y*19),BRONZE,2)
 finish(c)
static func draw_socket(c:CanvasItem,p:Vector2,kind:String,active:bool=false,size:float=64):
 start(c,p,size)
 c.draw_rect(Rect2(-28,-28,56,56),A.INK)
 c.draw_rect(Rect2(-28,-28,56,56),BRONZE if active else STONE,false,3)
 mark(c,kind,Vector2.ZERO,1.7)
 if active:
  for x in [-25,25]:A.line(c,Vector2(x,-22),Vector2(x,22),A.LIGHT,3)
 finish(c)
static func draw_cart(c:CanvasItem,p:Vector2,fixed:bool=false,size:float=64):
 start(c,p,size)
 for x in [-24,24]:
  for y in [-17,17]:A.poly(c,[[x-4,y-6],[x+4,y-6],[x+4,y+6],[x-4,y+6]],A.DARK_STEEL)
 A.poly(c,[[-20,-25],[15,-25],[22,-17],[22,22],[-20,22]],STONE)
 A.poly(c,[[-8,-17],[10,-17],[10,-8],[-8,-8]],A.INK)
 A.line(c,Vector2(-13,3),Vector2(12,3),A.DARK_STEEL,2)
 A.line(c,Vector2(1,3),Vector2(-4,15),A.DARK_STEEL,2)
 A.line(c,Vector2(-21,20),Vector2(22,20),BRONZE,4)
 if fixed:
  A.line(c,Vector2(-16,-1),Vector2(17,16),A.INK,7)
  A.line(c,Vector2(-16,-1),Vector2(17,16),BRONZE,3)
 finish(c)
static func draw_gate(c:CanvasItem,p:Vector2,kind:String,opened:bool,locked:bool=false,size:float=64):
 start(c,p,size)
 for x in [-27,27]:A.line(c,Vector2(x,-29),Vector2(x,29),STONE,5)
 A.line(c,Vector2(-28,-26),Vector2(28,-26),BRONZE,4)
 if not opened:
  for x in [-17,-6,6,17]:A.line(c,Vector2(x,-22),Vector2(x,29),A.STEEL,4)
 else:
  for x in [-22,22]:A.line(c,Vector2(x,-22),Vector2(x,26),A.STEEL,3)
 mark(c,kind,Vector2(0,-17),0.55)
 if locked:
  A.line(c,Vector2(-25,14),Vector2(25,14),BRONZE,6)
  A.disk(c,Vector2(18,14),5,A.INK)
 finish(c)
static func draw_reset(c:CanvasItem,p:Vector2,available:bool=true,size:float=64):
 start(c,p,size)
 A.poly(c,[[-24,-18],[23,-18],[27,26],[-27,26]],A.DARK_STEEL)
 A.poly(c,[[-16,-10],[6,-10],[6,12],[-16,12]],STONE)
 A.line(c,Vector2(14,17),Vector2(23,1),BRONZE,5)
 A.disk(c,Vector2(24,-3),5,A.LIGHT if available else A.STEEL)
 A.line(c,Vector2(16,-19),Vector2(-17,-19),A.GOLD,3)
 A.line(c,Vector2(-17,-19),Vector2(-17,-5),A.GOLD,3)
 A.line(c,Vector2(-17,-5),Vector2(-23,-11),A.GOLD,3)
 A.line(c,Vector2(-17,-5),Vector2(-11,-11),A.GOLD,3)
 finish(c)
static func draw_reward(c:CanvasItem,p:Vector2,kind:String,forfeited:bool=false,size:float=64):
 start(c,p,size)
 A.poly(c,[[-24,-17],[24,-17],[24,26],[-24,26]],A.DARK_STEEL)
 mark(c,kind,Vector2(0,-6),1.25)
 A.line(c,Vector2(-23,16),Vector2(23,16),BRONZE,4)
 A.disk(c,Vector2(0,16),8,A.TEAL)
 A.line(c,Vector2(0,9),Vector2(0,23),A.LIGHT,2)
 if forfeited:
  A.line(c,Vector2(-23,-11),Vector2(23,23),A.INK,9)
  A.line(c,Vector2(-23,-11),Vector2(23,23),STONE,4)
 finish(c)
static func draw_wire(c:CanvasItem,points:PackedVector2Array,active:bool=false):
 if points.size()<2:return
 c.draw_polyline(points,A.INK,5)
 c.draw_polyline(points,A.GOLD if active else BRONZE,2)
 for p in points:c.draw_circle(p,2,STONE)
