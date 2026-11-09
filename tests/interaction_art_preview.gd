extends Node2D
const Art=preload("res://scripts/endless_interaction_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(32,42),"ORIGINAL FLAT INTERACTIONS | 64 / 40 / 24 / 128 px",0,-1,24,Art.A.GOLD)
 var names=["TRAINING STELE","SEALED CARGO","CARAVAN","TRAINING KIT","HEALTH FLASK","KEY","VAULT DOOR"]
 for i in Art.TOKENS.size():
  var x=96+i*180
  draw_string(font,Vector2(x-78,90),names[i],0,-1,14,Art.A.TEAL)
  for row in 4:
   var y=155+row*140
   draw_rect(Rect2(x-35,y-35,70,70),Color("263c4b"))
   Art.draw_token(self,Vector2(x,y),Art.TOKENS[i],[64.0,40.0,24.0,128.0][row])
 draw_string(font,Vector2(32,735),"Retain existing treasure crowns, route signposts and stairs: fewer competing small details.",0,-1,18,Art.A.TEAL)
