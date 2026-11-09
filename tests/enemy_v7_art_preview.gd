extends Node2D
const Old=preload("res://scripts/endless_actor_art.gd")
const Art=preload("res://scripts/endless_enemy_v7_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(32,42),"ENEMY SILHOUETTES | 64 / 40 / 24 / 128 px",0,-1,24,Old.GOLD)
 var tokens=["g","b","w","V","r","c"]
 var names=["IRON WARDEN","TWIN BLADES","ROBED WATCHER","VAULT BULWARK","INTERCEPT SCOUT","CHARGED HAMMER"]
 for i in tokens.size():
  var x=110+i*210
  draw_string(font,Vector2(x-91,90),names[i],0,-1,14,Old.TEAL)
  for row in 4:
   var y=155+row*140
   draw_rect(Rect2(x-35,y-35,70,70),Color("263c4b"))
   var size=[64.0,40.0,24.0,128.0][row]
   if not Art.draw_enemy(self,Vector2(x,y),tokens[i],size):Old.draw_enemy(self,Vector2(x,y),tokens[i],size)
 draw_string(font,Vector2(32,735),"New: readied crossbow intercept / raised two-handed hammer retaliation. Flat shapes; no lettering.",0,-1,18,Old.TEAL)
