class_name TowerEndlessCampFloorArt
extends RefCounted
## Quiet flat paving under a camp. Center deliberately blank for actors/path dots.
const STONE=Color("203442")
const EDGE=Color("526875")
const SEAM=Color("344c5b")
static func cells(world)->Dictionary:
 var camp=Vector2i(-1,-1)
 for y in 15:
  for x in 15:
   if world.tile(Vector2i(x,y))=="M":
    if camp.x>=0:return {} # Ambiguous camps: don't invent an anchor.
    camp=Vector2i(x,y)
 if camp.x<0:return {}
 var out:Dictionary={camp:true};var queue:Array[Vector2i]=[camp];var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n=p+d
   if absi(n.x-camp.x)>1 or absi(n.y-camp.y)>1 or out.has(n):continue
   if n.x<0 or n.y<0 or n.x>=15 or n.y>=15:continue
   if world.tile(n)!=".":continue
   out[n]=true;queue.append(n)
 return out
static func draw_floor(c:CanvasItem,center:Vector2,p:Vector2i,region:Dictionary,size:float=64.0):
 if not region.has(p) or size<=0 or not is_finite(size):return
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 c.draw_rect(Rect2(-31,-31,62,62),STONE)
 # Boundary stays inset; connected tiles meet at low-contrast masonry seams.
 for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
  var joined:bool=region.has(p+d)
  var along=Vector2(-d.y,d.x)
  var edge=Vector2(d)*(31 if joined else 26)
  c.draw_line(edge-along*26,edge+along*26,SEAM if joined else EDGE,1.5 if joined else 2.0,true)
  if not joined:
   for side in [-1,1]:
    var corner=edge+along*side*21
    c.draw_line(corner,corner-Vector2(d)*5,SEAM,2,true)
 c.draw_set_transform(Vector2.ZERO)
