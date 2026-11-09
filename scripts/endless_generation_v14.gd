class_name TowerEndlessGenerationV14
extends "res://scripts/endless_generation_v13.gd"
const G13=preload("res://scripts/endless_generation_v13.gd")
static func is_ring(seed:int,f:int)->bool:return G13.mix(seed,f,2309)%6==5
static func ring_variant(seed:int,f:int)->int:return G13.mix(G13.mix(seed,f,2333),f+17,19)%3
static func layout_name(seed:int,f:int)->String:return "环井连桥" if is_ring(seed,f) else G13.layout_name(seed,f)
static func routes(seed:int,f:int)->Array:
	if not is_ring(seed,f):return G13.routes(seed,f)
	var rows:Array=G13.routes(seed,f).duplicate(true)
	rows[0].points=[Vector2i(2,7)];rows[1].points=[Vector2i(7,5),Vector2i(7,9)]
	return rows
static func manifest(seed:int,f:int)->Dictionary:
	var data:Dictionary=G13.manifest(seed,f);var row:Dictionary=routes(seed,f)[data.route]
	data.points=row.points.duplicate();data.route_label=row.label;return data
static func camp_position(seed:int,f:int)->Vector2i:
	if not is_ring(seed,f):return G13.camp_position(seed,f)
	return Vector2i(2,2) if f%2 else Vector2i(12,12)
static func generate(seed:int,f:int)->Dictionary:
	if seed<0 or seed>2147483647 or f<1 or f>1000000:return {"ok":false,"errors":["identity"]}
	if not is_ring(seed,f):return G13.generate(seed,f)
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
	for y in range(3,12):g[y][7]="."
	# Middle courtyard is a true cycle between two mandatory gate guards.
	for y in range(6,9):
		for x in range(5,10):g[y][x]="."
	g[7][7]="#"
	var variant:int=ring_variant(seed,f)
	if variant>=1:g[7][6]="#"
	if variant==2:g[7][8]="#"
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
	var rr:=routes(seed,f);var types:=G13.roster12(seed,f)
	var points:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]]
	for i in 3:g[points[i].y][points[i].x]=types[i]
	var data:Dictionary={"ok":true,"seed":seed,"floor":f,"revision":14,"grid":g,"entry":pair.entry,"exit":pair.exit,"routes":rr,"contract":manifest(seed,f),"layout":"ring","variant":variant,"rune":G13.rune_info(seed,f)}
	data.proof=validate(data);data.ok=data.proof.ok;return data
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int:return {"ok":false,"errors":["identity"]}
	if data.seed<0 or data.seed>2147483647 or data.floor<1 or data.floor>1000000:return {"ok":false,"errors":["identity"]}
	if not is_ring(data.seed,data.floor):return G13.validate(data)
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	for row in data.grid:
		if not row is Array or row.size()!=15:return {"ok":false,"errors":["width"]}
	var errors:Array=[];var rr:=routes(data.seed,data.floor);var types:=G13.roster12(data.seed,data.floor);var normalized:Array=data.grid.duplicate(true)
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
	if data.get("rune",{})!=G13.rune_info(data.seed,data.floor):errors.append("rune")
	var variant:int=ring_variant(data.seed,data.floor)
	if data.get("variant",-1)!=variant:errors.append("variant identity")
	if normalized[7][7]!="#" or normalized[7][6]!=("#" if variant>=1 else ".") or normalized[7][8]!=("#" if variant==2 else "."):errors.append("variant pillars")
	# Ring identity: two distinct local walks must survive around the center,
	# independently of the global two-route guarantee.
	for side in [-1,1]:
		var chamber:Array=[]
		for y in 15:
			var row:Array=[]
			for x in 15:
				row.append(normalized[y][x] if y>=6 and y<=8 and ((side==-1 and x>=5 and x<=7) or (side==1 and x>=7 and x<=9)) else "#")
			chamber.append(row)
		if not G5.reach(chamber,Vector2i(7,6),[]).has(Vector2i(7,8)):errors.append("missing local ring side")
	for x in range(5,10):
		if x!=7 and (normalized[5][x]!="#" or normalized[9][x]!="#"):errors.append("courtyard gate bypass")
	for y in range(6,9):
		if normalized[y][4]!="#" or normalized[y][10]!="#":errors.append("courtyard side leak")
	for y in range(4,11):
		if normalized[y][3]!="#" or normalized[y][4]!="#":errors.append("short bridge cross-link")
	return {"ok":errors.is_empty(),"errors":errors}
