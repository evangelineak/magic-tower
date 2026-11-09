extends Node2D
const Floor=preload("res://scripts/endless_camp_floor_art.gd")
const Props=preload("res://scripts/endless_interaction_art.gd")
const Actors=preload("res://scripts/endless_actor_art.gd")
class Tiles:
 extends RefCounted
 var marks:Dictionary={}
 func tile(p:Vector2i)->String:return marks.get(p,".")
var font:Font
func _ready():font=load("res://assets/fonts/MagicTowerCJK.otf");queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,800),Color("0b1420"))
 draw_string(font,Vector2(35,48),"CAMP PAVING | 64px cells | same geometry, no gameplay changes",0,-1,23,Actors.GOLD)
 for example in 3:
  var t=Tiles.new();t.marks={Vector2i(7,7):"M"}
  if example==0:t.marks[Vector2i(8,7)]="C";t.marks[Vector2i(6,7)]="a"
  if example==2:t.marks[Vector2i(6,7)]="#";t.marks[Vector2i(7,6)]="#"
  var region=Floor.cells(t);var origin=Vector2(50+example*410,140)
  draw_string(font,origin+Vector2(0,-25),["SUPPLIES REMAIN","AFTER PICKUPS","WALLS CUT THE PLAZA"][example],0,-1,18,Actors.TEAL)
  for y in 5:
   for x in 5:
    var p=Vector2i(x+5,y+5);var center=origin+Vector2(x,y)*64+Vector2(32,32)
    draw_rect(Rect2(center-Vector2(31,31),Vector2(62,62)),Color("152432") if (x+y)%2==0 else Color("192a38"))
    Floor.draw_floor(self,center,p,region)
    var token=t.tile(p)
    if token=="#":draw_rect(Rect2(center-Vector2(28,28),Vector2(56,56)),Color("293b4b"))
    else:Props.draw_token(self,center,token)
  for p in [Vector2(2,3),Vector2(3,3)]:draw_circle(origin+p*64+Vector2(32,32),4,Actors.TEAL)
  Actors.draw_hero(self,origin+Vector2(1,3)*64+Vector2(32,32),"none")
 draw_string(font,Vector2(40,540),"Only connected empty ground near the actual merchant. Walls, doors, foes and items stop the paving.",0,-1,19,Actors.TEAL)
 draw_string(font,Vector2(40,575),"Quiet edge seams leave the cell centers free. Hero, interaction icons and safe-route dots stay above it.",0,-1,19,Actors.TEAL)
