extends Node2D
const Art=preload("res://scripts/endless_gear_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(48,55),"ORIGINAL FLAT GEAR | 24 / 40 / 64 / 128 px",0,-1,26,Art.A.GOLD)
 for i in 2:
  var x=360+i*560
  draw_string(font,Vector2(x-120,105),["BASTION MANTLE","HUNTER LENS"][i],0,-1,23,Art.A.TEAL)
  for row in 4:
   var y=170+row*145
   draw_rect(Rect2(x-40,y-40,80,80),Color("263c4b"))
   Art.draw_gear(self,Vector2(x,y),["cloak","lens"][i],[24.0,40.0,64.0,128.0][row])
