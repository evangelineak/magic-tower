extends Node2D
const Art=preload("res://scripts/endless_progress_art.gd")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 var ids=["none","kit","coin","mind","reserve","tracker","laststand","alert","light","wardweave","deepdrill","mender","overload"]
 for i in ids.size():
  var x=90+(i%7)*180;var y=70+int(i/7)*365
  draw_string(font,Vector2(x-50,y),ids[i],0,-1,15,Art.A.GOLD)
  for row in 3:
   var size:float=[40.0,64.0,128.0][row]
   Art.draw_icon(self,Vector2(x,y+45+row*100),ids[i],size)
