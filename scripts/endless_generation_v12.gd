class_name TowerEndlessGenerationV12
extends "res://scripts/endless_generation_v10.gd"
const G10=preload("res://scripts/endless_generation_v10.gd")
static func roster12(seed:int,f:int)->Array:
	var base:Array=G10.roster(seed,f).duplicate()
	for i in 3:
		var h:int=G10.mix(seed,f,1601+i*37)%6
		if h==0:base[i]="t"
		elif h==1:base[i]="p"
	return base
static func routes(seed:int,f:int)->Array:
	var rr:Array=G10.routes(seed,f).duplicate(true);var types:=roster12(seed,f)
	var names:Dictionary={"g":"铁甲关尉","w":"烈法守卫","r":"截击斥候","c":"蓄势重卫","b":"持久哨兵","t":"棘甲守卫","p":"回春祭司"}
	rr[0].label="单关："+names[types[0]];rr[1].label="双关："+names[types[1]]+" / "+names[types[2]];return rr
static func manifest(seed:int,f:int)->Dictionary:
	var data:Dictionary=G10.manifest(seed,f);data.route_label=routes(seed,f)[data.route].label;return data
static func generate(seed:int,f:int)->Dictionary:
	var data:Dictionary=G10.generate(seed,f)
	if not data.ok:return data
	var rr:=routes(seed,f);var types:=roster12(seed,f);var pts:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]]
	for i in 3:data.grid[pts[i].y][pts[i].x]=types[i]
	data.routes=rr;data.contract=manifest(seed,f);data.revision=12;data.proof=validate(data);data.ok=data.proof.ok;return data
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int:return {"ok":false}
	if data.seed<0 or data.seed>2147483647 or data.floor<1 or data.floor>1000000:return {"ok":false}
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false}
	for row in data.grid:
		if not row is Array or row.size()!=15:return {"ok":false}
	var rr:=routes(data.seed,data.floor);var types:=roster12(data.seed,data.floor);var old:Array=G10.roster(data.seed,data.floor)
	var pts:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]];var normalized:Dictionary=data.duplicate(true)
	for i in 3:
		if data.grid[pts[i].y][pts[i].x]!=types[i]:return {"ok":false}
		normalized.grid[pts[i].y][pts[i].x]=old[i]
	if data.get("contract",{})!=manifest(data.seed,data.floor):return {"ok":false}
	normalized.contract=G10.manifest(data.seed,data.floor)
	return G10.validate(normalized)
