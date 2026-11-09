class_name TowerEndlessGenerationV10
extends "res://scripts/endless_generation_v9.gd"
const G9=preload("res://scripts/endless_generation_v9.gd")
const G5=preload("res://scripts/endless_generation_v5.gd")
static func is_channel(seed:int,f:int)->bool:return G9.mix(seed,f,1201)%5==4
static func layout_name(seed:int,f:int)->String:return "分叉沟渠" if is_channel(seed,f) else G9.layout_name(seed,f)
static func routes(seed:int,f:int)->Array:
	if not is_channel(seed,f):return G9.routes(seed,f)
	var rows:Array=G9.routes(seed,f).duplicate(true)
	rows[0].points=[Vector2i(2,7)];rows[1].points=[Vector2i(6,5),Vector2i(8,8)]
	return rows
static func manifest(seed:int,f:int)->Dictionary:
	var data:Dictionary=G9.manifest(seed,f);var row:Dictionary=routes(seed,f)[data.route]
	data.points=row.points.duplicate();data.route_label=row.label;return data
static func camp_position(seed:int,f:int)->Vector2i:
	return Vector2i(12,12) if is_channel(seed,f) and f%2==0 else Vector2i(2,2 if f%2 else 12)
static func generate(seed:int,f:int)->Dictionary:
	if seed<0 or seed>2147483647 or f<1 or f>1000000:return {"ok":false,"errors":["identity"]}
	if not is_channel(seed,f):return G9.generate(seed,f)
	var g:Array=[]
	for y in 15:
		var row:Array=[]
		for x in 15:row.append("#")
		g.append(row)
	for y in range(1,4):
		for x in range(1,7):g[y][x]="."
	for y in range(11,14):
		for x in range(1,14):g[y][x]="."
	for y in range(3,12):g[y][2]="."
	for y in range(3,7):g[y][6]="."
	for x in range(6,9):g[6][x]="."
	for y in range(6,10):g[y][8]="."
	for x in range(6,9):g[9][x]="."
	for y in range(9,12):g[y][6]="."
	for x in range(6,13):g[3][x]="."
	for x in range(9,13):g[10][x]="."
	g[11][9]="."
	# Vault ceilings/floors stay sealed, including where the lower courtyard meets it.
	for y in [3,10]:
		for x in range(10,14):g[y-1][x]="#";g[y+1][x]="#"
		g[y][10]="D" if y==3 else "V";g[y][11]=".";g[y][12]="$" if y==3 else "T";g[y][13]="#"
	g[3][3]="k"
	var yy:int=1 if f%2 else 13
	g[yy][2 if f%2 else 12]="a";g[yy][3 if f%2 else 11]="C"
	var camp:=camp_position(seed,f);g[camp.y][camp.x]="M";g[camp.y][3 if f%2 else 11]="S"
	var pair:=anchors(f);g[pair.entry.y][pair.entry.x]="<";g[pair.exit.y][pair.exit.x]=">"
	var rr:=routes(seed,f);var types:=G9.roster(seed,f)
	var points:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]]
	for i in 3:g[points[i].y][points[i].x]=types[i]
	var data:Dictionary={"ok":true,"seed":seed,"floor":f,"revision":10,"grid":g,"entry":pair.entry,"exit":pair.exit,"routes":rr,"contract":manifest(seed,f),"layout":"channel"}
	data.proof=validate(data);data.ok=data.proof.ok;return data
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int:return {"ok":false,"errors":["identity"]}
	if data.seed<0 or data.seed>2147483647 or data.floor<1 or data.floor>1000000:return {"ok":false,"errors":["identity"]}
	if not is_channel(data.seed,data.floor):return G9.validate(data)
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	for row in data.grid:
		if not row is Array or row.size()!=15:return {"ok":false,"errors":["width"]}
	var errors:Array=[];var rr:=routes(data.seed,data.floor);var types:=G9.roster(data.seed,data.floor);var normalized:Array=data.grid.duplicate(true)
	var points:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]]
	for i in 3:
		var p:Vector2i=points[i]
		if normalized[p.y][p.x]!=types[i]:errors.append("roster")
		normalized[p.y][p.x]="g" if i==0 else "b"
	var counts:Dictionary={}
	for y in 15:
		for x in 15:
			var t=normalized[y][x]
			if not t is String or t not in ["#",".","g","b","D","V","$","T","k","a","C","M","S","<",">"]:errors.append("token")
			counts[t]=counts.get(t,0)+1
			if (x==0 or y==0 or x==14 or y==14) and t!="#":errors.append("boundary")
	for t in ["D","V","$","T","k","a","C","M","S","<",">"]:
		if counts.get(t,0)!=1:errors.append("unique")
	if counts.get("g",0)!=1 or counts.get("b",0)!=2:errors.append("guard count")
	var pair:=anchors(data.floor)
	if normalized[pair.entry.y][pair.entry.x]!="<" or normalized[pair.exit.y][pair.exit.x]!=">":errors.append("stairs")
	for start in [pair.entry,pair.exit]:
		var end:Vector2i=pair.exit if start==pair.entry else pair.entry
		if G5.reach(normalized,start,[]).has(end):errors.append("free bypass")
		for allowed in [["g"],["b"]]:
			if not G5.reach(normalized,start,allowed).has(end):errors.append("missing route")
	for p in rr[1].points:
		var copy:Array=normalized.duplicate(true);copy[p.y][p.x]="#"
		if G5.reach(copy,pair.entry,["b"]).has(pair.exit):errors.append("skippable guard")
	for target in [Vector2i(12,3),Vector2i(12,10)]:
		if G5.reach(normalized,pair.entry,["g","b"]).has(target):errors.append("reward bypass")
		if not G5.reach(normalized,pair.entry,["g","b","D" if target.y==3 else "V"]).has(target):errors.append("sealed reward")
	if data.get("contract",{})!=manifest(data.seed,data.floor):errors.append("manifest")
	return {"ok":errors.is_empty(),"errors":errors}
