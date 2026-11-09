class_name TowerEndlessGenerationV2
extends RefCounted
const Base=preload("res://scripts/endless_generation_v1.gd")
const PRIMARY:=Vector2i(3,7)
const ALTERNATE:Array[Vector2i]=[Vector2i(8,7),Vector2i(8,8)]
static func anchors(f:int)->Dictionary:return Base.anchors(f)
static func layout(seed:int,f:int)->String:return "courtyard" if (seed%2+f%2)%2==0 else "causeway"
static func alternate_points(seed:int,f:int)->Array[Vector2i]:
	var x:int=8 if layout(seed,f)=="courtyard" else 6
	return [Vector2i(x,7),Vector2i(x,8)]
static func generate(seed:int,f:int)->Dictionary:
	var data:=Base.generate(seed,f)
	if not data.ok:return data
	var g:Array=data.grid
	for x in range(1,14):g[7][x]="#"
	var alternate_x:int=alternate_points(seed,f)[0].x
	for y in range(1,14):g[y][alternate_x]="."
	for y in range(2,13):g[y][3]="."
	for y in [2,3,10,11,12]:g[y][4]="."
	g[7][3]="g" if layout(seed,f)=="courtyard" else "w"
	g[7][alternate_x]="b";g[8][alternate_x]="b"
	if layout(seed,f)=="courtyard":
		for x in range(3,9):g[4][x]="."
	else:
		# A second transverse wall creates a narrow two-aperture causeway,
		# unlike the courtyard hall. It never opens a treasure-room boundary.
		for x in range(1,14):g[6][x]="#"
		g[6][3]=".";g[6][alternate_x]="."
		for x in range(3,alternate_x+1):g[11][x]="."
	g[3][3]="k"
	var y:int=1 if f%2==1 else 13
	g[y][2 if f%2==1 else 12]="a"
	g[y][3 if f%2==1 else 11]="C"
	g[2 if f%2==1 else 12][3]="S"
	g[2 if f%2==1 else 12][2]="M"
	data.revision=2;data.layout=layout(seed,f)
	data.routes=[{"label":"重甲短路" if data.layout=="courtyard" else "猛攻关隘","points":[PRIMARY]},{"label":"双哨巡逻线","points":alternate_points(seed,f)}]
	data.proof=validate(data);data.ok=data.proof.ok
	return data
static func reach(g:Array,start:Vector2i,allowed:Array)->Dictionary:
	var seen:Dictionary={start:true};var queue:Array[Vector2i]=[start];var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		for d in Base.DIRS:
			var q:=p+d;var t:=Base.tile(g,q)
			if t=="#" or (t in ["D","V","g","w","b"] and t not in allowed) or seen.has(q):continue
			seen[q]=true;queue.append(q)
	return seen
static func validate(data:Dictionary)->Dictionary:
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	var g:Array=data.grid;var errors:Array=[];var count:Dictionary={}
	for y in 15:
		if not g[y] is Array or g[y].size()!=15:return {"ok":false,"errors":["width"]}
		for x in 15:
			var t=g[y][x]
			if not t is String or t not in ["#",".","<",">","D","V","g","w","b","k","$","T","a","C","M","S"]:return {"ok":false,"errors":["token"]}
			count[t]=count.get(t,0)+1
			if (x==0 or y==0 or x==14 or y==14) and t!="#":errors.append("boundary")
	if not data.get("seed") is int or not data.get("floor") is int or not Base.valid_input(data.seed,data.floor):return {"ok":false,"errors":["identity"]}
	var pair:=anchors(data.floor)
	for t in ["<",">","D","V","k","$","T","a","C","M","S"]:
		if count.get(t,0)!=1:errors.append("unique "+t)
	if count.get("b",0)!=2 or count.get("g",0)+count.get("w",0)!=1:errors.append("guards")
	if Base.tile(g,pair.entry)!="<" or Base.tile(g,pair.exit)!=">":errors.append("stairs")
	var free:=reach(g,pair.entry,[])
	var primary:=reach(g,pair.entry,["g","w"])
	var alternate:=reach(g,pair.entry,["b"])
	var all:=reach(g,pair.entry,["g","w","b"])
	if free.has(pair.exit):errors.append("free depth bypass")
	if not primary.has(pair.exit) or not alternate.has(pair.exit):errors.append("missing route")
	if all.has(Base.REWARD) or not reach(g,pair.entry,["g","w","b","D"]).has(Base.REWARD):errors.append("door bypass")
	if all.has(Base.VAULT) or not reach(g,pair.entry,["g","w","b","V"]).has(Base.VAULT):errors.append("vault bypass")
	if not all.has(Base.KEY):errors.append("key inaccessible")
	return {"ok":errors.is_empty(),"errors":errors,"primary_reachable":primary.has(pair.exit),"alternate_reachable":alternate.has(pair.exit),"free_exit":free.has(pair.exit),"combat_budget_verified":false}
