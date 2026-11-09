class_name TowerEndlessGenerationV8
extends "res://scripts/endless_generation_v7.gd"
const Prior=preload("res://scripts/endless_generation_v7.gd")
static func mix(seed:int,block:int,salt:int)->int:
	var v:int=(seed%2147483646+(block%2147483646)*193+salt)%2147483647
	v=v*48271%2147483647;return v*48271%2147483647
static func roster(seed:int,f:int)->Array[String]:
	var h:=mix(seed,(f-1)/4,811);var order:Array[String]=["g","w","r","c"]
	if h%2==1:order.reverse()
	return [order[((f-1)%4+h%4)%4],["b","g","c"][mix(seed,f,83)%3],"w" if mix(seed,f,229)%2==0 else "r"]
static func routes(seed:int,f:int)->Array:
	var rows:Array=Prior.routes(seed,f).duplicate(true);var set:=roster(seed,f)
	var names:Dictionary={"g":"铁甲关尉","w":"烈法守卫","r":"截击斥候","c":"蓄势重卫","b":"持久哨兵"}
	rows[0].label="单关："+names[set[0]];rows[1].label="双关："+names[set[1]]+" / "+names[set[2]];return rows
static func generate(seed:int,f:int)->Dictionary:
	var data:Dictionary=Prior.generate(seed,f)
	if not data.ok:return data
	var rr:Array=Prior.routes(seed,f);var set:=roster(seed,f)
	var pts:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]]
	for i in 3:data.grid[pts[i].y][pts[i].x]=set[i]
	data.routes=routes(seed,f);data.revision=8;data.proof=validate(data);data.ok=data.proof.ok;return data
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int or data.floor<1 or data.seed<0 or data.seed>2147483647:return {"ok":false,"errors":["identity"]}
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	for row in data.grid:
		if not row is Array or row.size()!=15:return {"ok":false,"errors":["width"]}
	var rr:Array=Prior.routes(data.seed,data.floor);var set:=roster(data.seed,data.floor)
	var pts:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]];var copied:Dictionary=data.duplicate(true)
	for i in 3:
		if data.grid[pts[i].y][pts[i].x]!=set[i]:return {"ok":false,"errors":["roster identity"]}
		copied.grid[pts[i].y][pts[i].x]=Prior.primary_token(data.seed,data.floor) if i==0 else "b"
	return Prior.validate(copied)
