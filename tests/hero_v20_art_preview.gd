extends Node2D
const Art=preload("res://scripts/endless_hero_v20_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(60,60),"三英雄身份固定 · 盾卫 / 弓手 / 学者（40 / 64 / 128）",0,-1,25,Art.A.LIGHT)
 for row in 3:
  for col in 3:
   var c=Vector2(230+col*400,180+row*220);var size:float=[40.0,64.0,128.0][row]
   draw_rect(Rect2(c-Vector2.ONE*size/2,Vector2.ONE*size),Color("263c4b"))
   Art.draw_hero(self,c,["warden","ranger","scholar"][col],size)
