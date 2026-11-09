extends Node2D
const Art=preload("res://scripts/endless_rune_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(32,45),"ENTRY RUNE DEVICES | 28 / 40 / 64 / 128 px",0,-1,24,Art.A.GOLD)
 for i in 4:
  var x=170+i*300
  draw_string(font,Vector2(x-115,100),["SHOCK · CLOSED","SHOCK · OPEN","SILENCE · CLOSED","SILENCE · OPEN"][i],0,-1,18,Art.A.TEAL)
  for row in 4:
   var y=170+row*140
   draw_rect(Rect2(x-40,y-40,80,80),Color("263c4b"))
   Art.draw_rune(self,Vector2(x,y),"shock" if i<2 else "silence",i%2==1,[28.0,40.0,64.0,128.0][row])
