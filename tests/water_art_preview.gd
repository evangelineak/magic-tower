extends Node2D
const Art=preload("res://scripts/endless_water_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(45,55),"双池洪闸：深水阻路 / 排干石床 / 上池干 / 下池干（40、64、128）",0,-1,23,Art.A.LIGHT)
 for row in 3:
  var size:float=[40.0,64.0,128.0][row];var y=165+row*220
  for col in 4:
   var p=Vector2(170+col*310,y)
   if col<2:Art.draw_pool(self,p,col==0,15,size)
   else:Art.draw_valve(self,p,"A" if col==2 else "B",true,size)
 # Joined water cells deliberately omit internal shoreline borders.
 Art.draw_pool(self,Vector2(520,720),true,13,64);Art.draw_pool(self,Vector2(584,720),true,7,64)
