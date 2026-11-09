extends Node2D
const Art=preload("res://scripts/endless_revisit_art.gd")
const Bridge=preload("res://scripts/endless_bridge_art.gd")
const Symbols=preload("res://scripts/map_symbols.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(50,65),"回访封签：留在原地，条件解除自动撤签（不代表安全可达）",0,-1,25,Art.A.LIGHT)
 for row in 3:
  var size:float=[40.0,64.0,128.0][row];var y=180+row*220
  for col in 4:
   var c=Vector2(170+col*300,y)
   draw_rect(Rect2(c-Vector2.ONE*size/2,Vector2.ONE*size),Color("263c4b"))
   if col<2:Bridge.draw_tool_cache(self,c,size)
   else:Symbols.draw_icon(self,"T",Rect2(c-Vector2.ONE*size/2,Vector2.ONE*size))
   if col%2==0:Art.draw_seal(self,c,size)
   draw_string(font,c+Vector2(-65,size/2+32),"暂留 · %dpx" % size if col%2==0 else "可领取 · %dpx" % size,0,-1,18,Art.A.GOLD)
