extends Node2D
const Base=preload("res://scripts/endless_actor_art.gd")
const Seven=preload("res://scripts/endless_enemy_v7_art.gd")
const Art=preload("res://scripts/endless_enemy_v12_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(32,42),"EIGHT ENEMY SILHOUETTES | 64 / 40 / 24 / 128 px",0,-1,24,Base.GOLD)
 var tokens=["g","b","w","V","r","c","t","p"]
 var names=["WARDEN","BLADES","ROBED","BULWARK","SCOUT","HAMMER","THORNS","RENEWAL"]
 for i in 8:
  var x=80+i*160
  draw_string(font,Vector2(x-60,90),names[i],0,-1,15,Base.TEAL)
  for row in 4:
   var y=155+row*140
   draw_rect(Rect2(x-35,y-35,70,70),Color("263c4b"))
   var size=[64.0,40.0,24.0,128.0][row]
   if not Art.draw_enemy(self,Vector2(x,y),tokens[i],size):
    if not Seven.draw_enemy(self,Vector2(x,y),tokens[i],size):Base.draw_enemy(self,Vector2(x,y),tokens[i],size)
 draw_string(font,Vector2(32,735),"Thorns: radial wreath and four roots. Renewal: hollow mask, exposed limbs and branching crook.",0,-1,18,Base.TEAL)
