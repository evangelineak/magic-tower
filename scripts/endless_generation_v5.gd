class_name TowerEndlessGenerationV5
extends RefCounted
const Legacy=preload("res://scripts/endless_generation_v3.gd")
const DIRS:Array[Vector2i]=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
static func anchors(f:int)->Dictionary:return Legacy.anchors(f)
static func historical_map(seed:int)->Array:return Legacy.historical_map(seed)
static func solve_case(g:Array,allow:Array=[])->Array[String]:return Legacy.solve_case(g,allow)
static func wrong_reason(seed:int,letter:String)->String:return Legacy.wrong_reason(seed,letter)
static func layout(seed:int,f:int)->String:return ["courtyard","causeway","bastions","switchback"][(seed%4+f%4)%4]
static func routes(seed:int,f:int)->Array:
	match layout(seed,f):
		"bastions":return [{"label":"北堡重甲关","points":[Vector2i(7,3)]},{"label":"南堡双哨线","points":[Vector2i(7,10),Vector2i(8,10)]}]
		"switchback":return [{"label":"峡口猛攻关","points":[Vector2i(3,5)]},{"label":"折廊双哨线","points":[Vector2i(8,9),Vector2i(8,10)]}]
	var alternate_x:int=8 if layout(seed,f)=="courtyard" else 6
	return [{"label":"重甲短路" if layout(seed,f)=="courtyard" else "猛攻关隘","points":[Vector2i(3,7)]},{"label":"双哨巡逻线","points":[Vector2i(alternate_x,7),Vector2i(alternate_x,8)]}]
static func layout_name(seed:int,f:int)->String:return {"courtyard":"双关隘庭院","causeway":"断壁回廊","bastions":"纵向双堡","switchback":"折线峡关"}[layout(seed,f)]
static func generate(seed:int,f:int)->Dictionary:
	if seed<0 or seed>2147483647 or f<1:return {"ok":false,"reason":"Invalid seed or floor"}
	var kind:=layout(seed,f)
	var g:Array=[]
	if kind in ["courtyard","causeway"]:
		# Select the original geometry family without changing the run's seed used
		# for history/cargo. Only this map's authored base receives the adjusted seed.
		var map_seed:int=seed if Legacy.layout(seed,f)==kind else (seed+1)%2147483648
		g=Legacy.generate(map_seed,f).grid
	else:
		for y in 15:
			var row:Array=[]
			for x in 15:row.append("#" if x==0 or y==0 or x==14 or y==14 else ".")
			g.append(row)
		if kind=="bastions":
			for y in range(1,14):g[y][7]="#"
			# Paired courtyard islands force choices of approach, not a rotated rail.
			for p in [Vector2i(4,4),Vector2i(4,5),Vector2i(4,9),Vector2i(4,10),Vector2i(10,6),Vector2i(11,6),Vector2i(10,7)]:g[p.y][p.x]="#"
		else:
			for x in range(1,8):g[5][x]="#"
			for y in range(5,10):g[y][7]="#"
			for x in range(7,14):g[9][x]="#"
			for p in [Vector2i(4,3),Vector2i(5,3),Vector2i(3,9),Vector2i(4,9),Vector2i(11,6),Vector2i(11,7)]:g[p.y][p.x]="#"
		# Two single-entry rooms. Walls are separate from the main-route partition.
		for y in [3,10]:
			for x in range(10,14):g[y-1][x]="#";g[y+1][x]="#"
			g[y][10]="D" if y==3 else "V";g[y][11]=".";g[y][12]="$" if y==3 else "T";g[y][13]="#"
		var route_info:=routes(seed,f)
		var first:Vector2i=route_info[0].points[0]
		g[first.y][first.x]="g" if kind=="bastions" else "w"
		for point in route_info[1].points:g[point.y][point.x]="b"
		# Close lateral exits after the first alternate guard so both are required.
		if kind=="bastions":g[9][8]="#";g[11][8]="#"
		else:g[9][7]="#";g[9][9]="#"
		g[3][3]="k"
		var y:int=1 if f%2==1 else 13
		g[y][2 if f%2==1 else 12]="a";g[y][3 if f%2==1 else 11]="C"
		g[2 if f%2==1 else 12][3]="S";g[2 if f%2==1 else 12][2]="M"
		var pair:=anchors(f);g[pair.entry.y][pair.entry.x]="<";g[pair.exit.y][pair.exit.x]=">"
	var result:Dictionary={"ok":true,"revision":5,"seed":seed,"floor":f,"layout":kind,"grid":g,"entry":anchors(f).entry,"exit":anchors(f).exit,"routes":routes(seed,f)}
	result.proof=validate(result);result.ok=result.proof.ok;return result
static func reach(g:Array,start:Vector2i,allowed:Array)->Dictionary:
	var queue:Array[Vector2i]=[start];var seen:Dictionary={start:true};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		for d in DIRS:
			var q:=p+d
			if q.x<0 or q.y<0 or q.x>=15 or q.y>=15:continue
			var t:String=g[q.y][q.x]
			if t=="#" or (t in ["g","w","b","D","V"] and t not in allowed) or seen.has(q):continue
			seen[q]=true;queue.append(q)
	return seen
static func validate(data:Dictionary)->Dictionary:
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	if not data.get("floor") is int or data.floor<1 or not data.get("seed") is int or data.seed<0 or data.seed>2147483647:return {"ok":false,"errors":["identity"]}
	var errors:Array=[];var g:Array=data.grid;var counts:Dictionary={}
	for y in 15:
		if not g[y] is Array or g[y].size()!=15:return {"ok":false,"errors":["width"]}
		for x in 15:
			var t=g[y][x]
			if not t is String or t not in ["#",".","<",">","D","V","g","w","b","k","$","T","a","C","M","S"]:return {"ok":false,"errors":["token"]}
			counts[t]=counts.get(t,0)+1
			if (x==0 or y==0 or x==14 or y==14) and t!="#":errors.append("boundary")
	var pair:=anchors(data.floor)
	if g[pair.entry.y][pair.entry.x]!="<" or g[pair.exit.y][pair.exit.x]!=">":errors.append("stairs")
	for t in ["<",">","D","V","k","$","T","a","C","M","S"]:
		if counts.get(t,0)!=1:errors.append("unique "+t)
	if counts.get("b",0)!=2 or counts.get("g",0)+counts.get("w",0)!=1:errors.append("guards")
	var free:=reach(g,pair.entry,[]);var primary:=reach(g,pair.entry,["g","w"]);var alternate:=reach(g,pair.entry,["b"]);var all:=reach(g,pair.entry,["g","w","b"])
	if free.has(pair.exit):errors.append("free bypass")
	if not primary.has(pair.exit) or not alternate.has(pair.exit):errors.append("missing main route")
	if all.has(Vector2i(12,3)) or not reach(g,pair.entry,["g","w","b","D"]).has(Vector2i(12,3)):errors.append("door reward")
	if all.has(Vector2i(12,10)) or not reach(g,pair.entry,["g","w","b","V"]).has(Vector2i(12,10)):errors.append("vault")
	if g[3][3]!="k" or not all.has(Vector2i(3,3)):errors.append("outside key")
	# Every alternate guard separately cuts that route when the primary remains closed.
	for point in routes(data.seed,data.floor)[1].points:
		var blocked:Array=g.duplicate(true);blocked[point.y][point.x]="#"
		if reach(blocked,pair.entry,["b"]).has(pair.exit):errors.append("skippable alternate guard")
	return {"ok":errors.is_empty(),"errors":errors,"primary_reachable":primary.has(pair.exit),"alternate_reachable":alternate.has(pair.exit),"free_exit":free.has(pair.exit),"combat_budget_verified":false}
