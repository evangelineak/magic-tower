extends Node2D
const Art=preload("res://scripts/endless_actor_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(42,48),"ORIGINAL FLAT ACTORS · 64 / 40 / 128 px",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Art.GOLD)
 var stances=["none","pierce","guard","harvest"]
 var labels=["TRAVELLER","PIERCE · SPEAR","GUARD · SHIELD","HARVEST · CRESCENT"]
 for i in 4:
  var x=170+i*300
  draw_string(font,Vector2(x-110,92),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Art.TEAL)
  for row in 3:
   var y=150+row*135
   draw_rect(Rect2(x-40,y-40,80,80),Color("263c4b"))
   Art.draw_hero(self,Vector2(x,y),stances[i],[64.0,40.0,128.0][row])
  draw_string(font,Vector2(x-105,545),["IRON WARDEN","TWIN-BLADE SCOUT","ROBED WATCHER","VAULT BULWARK"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Art.TEAL)
  Art.draw_enemy(self,Vector2(x,605),["g","b","w","V"][i],64)
  Art.draw_enemy(self,Vector2(x,700),["g","b","w","V"][i],40)
