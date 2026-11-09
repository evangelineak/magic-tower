extends Node2D
const Symbols=preload("res://scripts/map_symbols.gd")
func _draw():
	draw_rect(Rect2(0,0,960,560),Color("101b27"))
	for i in Symbols.TOKENS.size():
		var pos:=Vector2(22+(i%8)*116,26+(i/8)*250)
		draw_rect(Rect2(pos,Vector2(108,228)),Color("233442"))
		Symbols.draw_icon(self,Symbols.TOKENS[i],Rect2(pos+Vector2(6,8),Vector2(96,96)))
		Symbols.draw_icon(self,Symbols.TOKENS[i],Rect2(pos+Vector2(22,118),Vector2(64,64)))
		Symbols.draw_icon(self,Symbols.TOKENS[i],Rect2(pos+Vector2(38,188),Vector2(32,32)))
