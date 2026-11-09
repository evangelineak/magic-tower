class_name TowerEndlessGenerationV7
extends "res://scripts/endless_generation_v6.gd"
const Previous=preload("res://scripts/endless_generation_v6.gd")
static func primary_token(seed:int,f:int)->String:
	var h:int=(seed%2147483646+(f%2147483646)*193+11)%2147483647
	h=(h*48271)%2147483647;h=(h*48271)%2147483647
	if h%4==1:return "r"
	if h%4==2:return "c"
	return "g" if Previous.layout(seed,f) in ["courtyard","bastions"] else "w"
static func routes(seed:int,f:int)->Array:
	var rows:Array=Previous.routes(seed,f).duplicate(true)
	var token:=primary_token(seed,f)
	if token=="r":rows[0].label="截击斥候关：先制"
	elif token=="c":rows[0].label="蓄势重卫关：首反击双倍"
	return rows
static func generate(seed:int,f:int)->Dictionary:
	var data:Dictionary=Previous.generate(seed,f)
	if not data.ok:return data
	var point:Vector2i=Previous.routes(seed,f)[0].points[0]
	data.grid[point.y][point.x]=primary_token(seed,f)
	data.revision=7;data.routes=routes(seed,f);data.proof=validate(data);data.ok=data.proof.ok
	return data
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int or data.floor<1 or data.seed<0 or data.seed>2147483647:return {"ok":false,"errors":["identity"]}
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	for row in data.grid:
		if not row is Array or row.size()!=15:return {"ok":false,"errors":["width"]}
	var point:Vector2i=Previous.routes(data.seed,data.floor)[0].points[0]
	if data.grid[point.y][point.x]!=primary_token(data.seed,data.floor):return {"ok":false,"errors":["primary identity"]}
	var copy:Dictionary=data.duplicate(true)
	copy.grid[point.y][point.x]="g" if Previous.layout(data.seed,data.floor) in ["courtyard","bastions"] else "w"
	return Previous.validate(copy)
