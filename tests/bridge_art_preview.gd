extends Node2D
const Art=preload("res://scripts/endless_bridge_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(35,45),"FLAT BRIDGE MECHANISM | 40 / 64 / 128 px",0,-1,24,Art.A.GOLD)
 for i in 4:
  var x=175+i*300
  draw_string(font,Vector2(x-115,100),["RAISED: GAP","OPEN: PLANKS","LOCKED: CROSS-PINS","KEYED WINCH"][i],0,-1,17,Art.A.TEAL)
  for row in 3:
   var y=170+row*170
   draw_rect(Rect2(x-36,y-36,72,72),Color("263c4b"))
   var size=[40.0,64.0,128.0][row]
   if i<3:Art.draw_bridge(self,Vector2(x,y),["raised","open","locked"][i],false,size)
   else:Art.draw_winch(self,Vector2(x,y),false,size)
 Art.draw_bridge(self,Vector2(175,685),"raised",true)
 Art.draw_bridge(self,Vector2(475,685),"open",true)
 Art.draw_bridge(self,Vector2(775,685),"locked",true)
 Art.draw_winch(self,Vector2(1075,685),true)
