class_name TowerEndlessGenerationV22
extends "res://scripts/endless_generation_v19.gd"
const G19=preload("res://scripts/endless_generation_v19.gd")
static func is_water(seed:int,f:int)->bool:
	if f<4 or f%2:return false
	var block:int=int((f-4)/8)
	return f==block*8+4+2*(G19.mix(seed,block+1,4603)%2)
static func water_manifest(seed:int,f:int)->Dictionary:
	if not is_water(seed,f):return {"present":false}
	var variant:int=G19.mix(G19.mix(seed,f,4621),f,71)%2
	var north:Array=[];var south:Array=[]
	for y in [5,6,8,9]:
		for x in range(6,9):
			if variant==1 and Vector2i(x,y) in [Vector2i(6,6),Vector2i(7,6),Vector2i(7,8),Vector2i(8,8)]:continue
			if y<7:north.append(Vector2i(x,y))
			else:south.append(Vector2i(x,y))
	return {"present":true,"floor":f,"variant":variant,"initial_state":G19.mix(G19.mix(G19.mix(seed,f,4637),f,113),f,151)%2,"pools":{"north":north,"south":south},"controls":[Vector2i(5,3),Vector2i(5,7),Vector2i(5,11)],"island":[Vector2i(6,7),Vector2i(7,7),Vector2i(8,7),Vector2i(9,7)],"guardians":{"main":Vector2i(3,7),"north":Vector2i(7,4) if variant==0 else Vector2i(6,4),"south":Vector2i(7,10) if variant==0 else Vector2i(8,10),"vault":Vector2i(10,7)},"relic":Vector2i(12,7),"entry":Vector2i(13,13),"exit":Vector2i(1,1),"focus_rect":Rect2i(3,2,11,11)}
static func layout_name(seed:int,f:int)->String:return "双池洪闸" if is_water(seed,f) else G19.layout_name(seed,f)
static func routes(seed:int,f:int)->Array:
	var rows:Array=G19.routes(seed,f).duplicate(true)
	if is_water(seed,f):
		var info:=water_manifest(seed,f);rows[0].points=[info.guardians.main];rows[0].label="干岸主路"
		rows[1].points=[info.guardians.north,info.guardians.south];rows[1].label="洪闸水路：须在干岛换水位"
	return rows
static func manifest(seed:int,f:int)->Dictionary:
	var data:Dictionary=G19.manifest(seed,f);var route:Dictionary=routes(seed,f)[data.route]
	data.points=route.points.duplicate();data.route_label=route.label;return data
static func state_grid(seed:int,f:int,state:int)->Array:
	if not is_water(seed,f) or state not in [0,1]:return []
	var lines:Array=["###############","#>............#","#.........#####","#....F....D.$##","#.....#b#.#####","#....#AAA######","#....#AAA######","###g#F....V.T##","#....#BBB######","#....#BBB#....#","#.....#b#.....#","#....F.....k..#","#..........SM.#","#..........Ca<#","###############"]
	var info:=water_manifest(seed,f)
	if info.variant==1:lines[4]="#.....b##.#####";lines[6]="#....###A######";lines[8]="#....#B########";lines[10]="#.....##b.....#"
	var g:Array=[]
	for line in lines:
		var row:Array=[]
		for x in 15:
			var token:String=line[x]
			if token=="A":token="." if state==0 else "~"
			if token=="B":token="." if state==1 else "~"
			row.append(token)
		g.append(row)
	var roster:=G19.roster12(seed,f)
	for i in 3:
		var p:Vector2i=info.guardians[["main","north","south"][i]];g[p.y][p.x]=roster[i]
	return g
static func generate(seed:int,f:int)->Dictionary:
	if seed<0 or seed>2147483647 or f<1 or f>1000000:return {"ok":false,"errors":["identity"]}
	if not is_water(seed,f):return G19.generate(seed,f)
	var info:=water_manifest(seed,f)
	var data:Dictionary={"ok":true,"seed":seed,"floor":f,"revision":22,"grid":state_grid(seed,f,info.initial_state),"entry":info.entry,"exit":info.exit,"layout":"water","routes":routes(seed,f),"contract":manifest(seed,f),"rune":G19.rune_info(seed,f),"water":info}
	data.proof=validate(data);data.ok=data.proof.ok;return data
# Dynamic traversal includes real valve edges. Stairs are terminal goals, never
# reusable same-floor passageways. Combat feasibility is NOT asserted here.
static func water_reach(seed:int,f:int,start:Vector2i,goal:Vector2i,cleared:Array,open_d:bool=false,open_v:bool=false)->Dictionary:
	var info:=water_manifest(seed,f);var maps:Array=[state_grid(seed,f,0),state_grid(seed,f,1)]
	var initial:int=info.initial_state;var queue:Array=[initial*225+start.y*15+start.x];var seen:Dictionary={queue[0]:true};var head:=0
	while head<queue.size():
		var code:int=queue[head];head+=1;var state:int=int(code/225);var index:int=code%225;var p:=Vector2i(index%15,int(index/15))
		if p==goal:continue
		for control in info.controls:
			if absi(p.x-control.x)+absi(p.y-control.y)==1:
				var next:int=(1-state)*225+index
				if not seen.has(next):seen[next]=true;queue.append(next)
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+delta
			if q.x<0 or q.y<0 or q.x>=15 or q.y>=15:continue
			var next:int=state*225+q.y*15+q.x;var t:String=maps[state][q.y][q.x]
			if seen.has(next) or t in ["#","~","F","M","S"]:continue
			if t in ["<",">"] and q!=goal:continue
			if t=="D" and not open_d:continue
			if t=="V" and not open_v:continue
			if t in ["g","b","w","r","c","t","p"] and q not in cleared:continue
			seen[next]=true;queue.append(next)
	return seen
static func _seen(reach:Dictionary,point:Vector2i)->bool:return reach.has(point.y*15+point.x) or reach.has(225+point.y*15+point.x)
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int:return {"ok":false,"errors":["identity"]}
	if data.seed<0 or data.seed>2147483647 or data.floor<1 or data.floor>1000000:return {"ok":false,"errors":["identity"]}
	if not is_water(data.seed,data.floor):return G19.validate(data)
	var info:=water_manifest(data.seed,data.floor);var errors:Array=[]
	if data.get("grid")!=state_grid(data.seed,data.floor,info.initial_state):return {"ok":false,"errors":["water geometry identity"]}
	if data.get("water")!=info or data.get("routes")!=routes(data.seed,data.floor) or data.get("contract")!=manifest(data.seed,data.floor) or data.get("rune")!=G19.rune_info(data.seed,data.floor):errors.append("water metadata")
	if data.get("entry")!=info.entry or data.get("exit")!=info.exit:errors.append("stairs")
	var main:Vector2i=info.guardians.main;var north:Vector2i=info.guardians.north;var south:Vector2i=info.guardians.south;var all:Array=[main,north,south]
	for start in [info.entry,info.exit]:
		var goal:Vector2i=info.exit if start==info.entry else info.entry
		if _seen(water_reach(data.seed,data.floor,start,goal,[]),goal):errors.append("zero battle bypass")
		if not _seen(water_reach(data.seed,data.floor,start,goal,[main]),goal):errors.append("dry main route absent")
		if not _seen(water_reach(data.seed,data.floor,start,goal,[north,south]),goal):errors.append("dynamic water route absent")
		for one in [north,south]:
			if _seen(water_reach(data.seed,data.floor,start,goal,[one]),goal):errors.append("water guard bypass")
		if _seen(water_reach(data.seed,data.floor,start,goal,all,false,true),Vector2i(12,3)):errors.append("door bypass")
		if _seen(water_reach(data.seed,data.floor,start,goal,all,true,false),info.relic):errors.append("island relic bypass")
		var full:=water_reach(data.seed,data.floor,start,goal,all,true,true)
		if not _seen(full,Vector2i(12,3)) or not _seen(full,info.relic):errors.append("reward unreachable")
	var potential:=water_reach(data.seed,data.floor,info.entry,info.exit,all,true,true)
	for state in [0,1]:
		var cells:=state_grid(data.seed,data.floor,state)
		for y in 15:
			for x in 15:
				var token:String=cells[y][x]
				if token not in ["#","~","F","M","S","<",">"] and not potential.has(state*225+y*15+x):errors.append("potential traversable cell disconnected")
	var safe:=water_reach(data.seed,data.floor,Vector2i(11,13),Vector2i(-1,-1),[])
	if not _seen(safe,Vector2i(11,11)) or not _seen(safe,Vector2i(7,11)):errors.append("entrance supply/key pocket")
	for control in info.controls:
		for pool in info.pools.values():
			for cell in pool:
				if absi(cell.x-control.x)+absi(cell.y-control.y)<=1:errors.append("valve may submerge player")
	return {"ok":errors.is_empty(),"errors":errors}
