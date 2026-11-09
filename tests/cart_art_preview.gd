extends Node2D
const Art=preload("res://scripts/endless_cart_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(25,38),"推石庭院 · 原创平面机械 / 40、64、128 px",0,-1,23,Art.A.LIGHT)
 for row in 3:
  var size:float=[40.0,64.0,128.0][row];var y=140+row*200
  Art.draw_cart(self,Vector2(90,y),row==2,size)
  Art.draw_socket(self,Vector2(240,y),"supply",row==1,size)
  Art.draw_socket(self,Vector2(390,y),"archive",row==1,size)
  Art.draw_gate(self,Vector2(540,y),"archive",row==1,row==2,size)
  Art.draw_reset(self,Vector2(690,y),row!=2,size)
 # Entire local causal region; real board footprint, wires are edge cables not walkways.
 for y in range(1,9):
  for x in range(4,10):
   var p=Vector2i(x,y);var c=Vector2(850+(x-4)*60,90+(y-1)*78)
   draw_rect(Rect2(c-Vector2(29,29),Vector2(58,58)),Color("213443"))
   if x>=5 and x<=8 and y>=4 and y<=7:Art.draw_track(self,c,p==Vector2i(7,6),56)
   if p==Vector2i(5,5):Art.draw_socket(self,c,"supply",false,56)
   if p==Vector2i(6,4):Art.draw_socket(self,c,"archive",false,56)
   if p==Vector2i(7,6):Art.draw_cart(self,c,false,56)
   if p==Vector2i(4,7):Art.draw_reset(self,c,true,56)
   if p==Vector2i(5,3) or p==Vector2i(8,3):Art.draw_gate(self,c,"supply" if x==5 else "archive",false,false,56)
   if p==Vector2i(5,1) or p==Vector2i(8,1):Art.draw_reward(self,c,"supply" if x==5 else "archive",false,56)
 Art.draw_wire(self,PackedVector2Array([Vector2(883,402),Vector2(883,246),Vector2(910,246)]))
 Art.draw_wire(self,PackedVector2Array([Vector2(970,297),Vector2(1117,297),Vector2(1117,246),Vector2(1090,246)]))
 draw_string(font,Vector2(25,760),"双槽/四齿与门同形；细线仅表示机械联动，不代表可走路径。右图为因果布局示意，非最终墙体。",0,-1,19,Art.A.GOLD)
