extends Node2D
const Art=preload("res://scripts/endless_vault_art.gd")
const Seal=preload("res://scripts/endless_revisit_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(50,60),"宝库四种箱体 · 金币 / 药柜 / 护符织囊 / 凿甲钉架",0,-1,25,Art.A.LIGHT)
 for row in 3:
  var size:float=[40.0,64.0,128.0][row];var y=190+row*220
  for col in 4:
   var c=Vector2(165+col*310,y)
   draw_rect(Rect2(c-Vector2.ONE*size/2,Vector2.ONE*size),Color("263c4b"))
   Art.draw_cache(self,c,["gold","medicine","ward","pierce"][col],size)
   if row==1 and col>0:Seal.draw_seal(self,c,size)
   draw_string(font,c+Vector2(-30,size/2+35),"%d px" % size,0,-1,18,Art.A.GOLD)
