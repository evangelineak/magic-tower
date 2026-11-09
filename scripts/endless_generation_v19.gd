class_name TowerEndlessGenerationV19
extends "res://scripts/endless_generation_v16.gd"
const G16=preload("res://scripts/endless_generation_v16.gd")
static func cart_floors(seed:int)->Array:
	var result:Array=[]
	for window in [[3,5],[9,11]]:
		var candidates:Array=[]
		for f in window:
			if not G16.has_bridge(seed,f):candidates.append(f)
		if not candidates.is_empty():result.append(candidates[G16.mix(seed,window[0],3901)%candidates.size()])
	return result
static func has_cart(seed:int,f:int)->bool:return f in cart_floors(seed)
static func cart_manifest(seed:int,f:int)->Dictionary:
	if not has_cart(seed,f):return {"present":false}
	var variant:int=1 if f<9 else 2
	var pillar:=Vector2i(7,5) if variant==1 else Vector2i(6,6)
	var board:Array=[]
	for y in range(4,8):
		for x in range(5,9):
			if Vector2i(x,y)!=pillar:board.append(Vector2i(x,y))
	return {"present":true,"floor":f,"variant":variant,"board":board,"pillar":pillar,"cart_origin":Vector2i(7,6) if variant==1 else Vector2i(7,7),"sockets":{"supply":Vector2i(5,5),"archive":Vector2i(6,4)},"gates":{"supply":Vector2i(5,3),"archive":Vector2i(8,3)},"rewards":{"supply":Vector2i(5,1),"archive":Vector2i(8,1)},"guardian":Vector2i(8,2),"reset":Vector2i(4,7),"focus_rect":Rect2i(3,0,11,11)}
static func layout_name(seed:int,f:int)->String:return "运石岔庭" if has_cart(seed,f) else G16.layout_name(seed,f)
static func skill_position(seed:int,f:int)->Vector2i:return Vector2i(2,4) if has_cart(seed,f) else G16.skill_position(seed,f)
static func routes(seed:int,f:int)->Array:
	var rows:Array=G16.routes(seed,f).duplicate(true)
	if has_cart(seed,f):rows[0].points=[Vector2i(3,9)];rows[1].points=[Vector2i(6,9),Vector2i(6,10)]
	return rows
static func manifest(seed:int,f:int)->Dictionary:
	var data:Dictionary=G16.manifest(seed,f);data.points=routes(seed,f)[data.route].points.duplicate();return data
static func _cart_grid(seed:int,f:int)->Array:
	var lines:Array=["###############","#<aC#J##L######","#.M.#.##V######","#..k#u##v.D.$##","#.S.#.q...#####","#...#o.#......#","#......O......#","#...R.........#","#.............#","###g##b########","#....#b#..V.T##","#.........#####","#.............#","#............>#","###############"]
	var g:Array=[]
	for line in lines:
		var row:Array=[]
		for x in 15:row.append(line[x])
		g.append(row)
	var info:=cart_manifest(seed,f)
	if info.variant==2:g[5][7]=".";g[6][6]="#";g[6][7]=".";g[7][7]="O"
	var tokens:=G16.roster12(seed,f);var points:Array=[Vector2i(3,9),Vector2i(6,9),Vector2i(6,10)]
	for i in 3:g[points[i].y][points[i].x]=tokens[i]
	return g
static func generate(seed:int,f:int)->Dictionary:
	if seed<0 or seed>2147483647 or f<1 or f>1000000:return {"ok":false,"errors":["identity"]}
	if not has_cart(seed,f):return G16.generate(seed,f)
	var data:Dictionary={"ok":true,"seed":seed,"floor":f,"revision":19,"grid":_cart_grid(seed,f),"entry":Vector2i(1,1),"exit":Vector2i(13,13),"layout":"cart","routes":routes(seed,f),"contract":manifest(seed,f),"rune":G16.rune_info(seed,f),"cart":cart_manifest(seed,f)}
	data.proof=validate(data);data.ok=data.proof.ok;return data
static func cart_reach(g:Array,start:Vector2i,gate:String,guards:Array,open_d:bool=false,open_v:bool=false,allow_stairs:bool=true)->Dictionary:
	var queue:Array=[start];var seen:Dictionary={start:true};var head:=0
	while head<queue.size():
		var p:Vector2i=queue[head];head+=1
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d
			if q.x<0 or q.y<0 or q.x>=15 or q.y>=15 or seen.has(q):continue
			var t:String=g[q.y][q.x]
			if t in ["#","M","S","R","O"]:continue
			if not allow_stairs and t in ["<",">"]:continue
			if t=="u" and gate not in ["supply","both"]:continue
			if t=="v" and gate not in ["archive","both"]:continue
			if t=="D" and not open_d:continue
			if t=="V" and q==Vector2i(10,10) and not open_v:continue
			if t in ["g","b","w","r","c","t","p","V"] and q not in guards and not (t=="V" and q==Vector2i(10,10) and open_v):continue
			seen[q]=true;queue.append(q)
	return seen
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int:return {"ok":false,"errors":["identity"]}
	if data.seed<0 or data.seed>2147483647 or data.floor<1 or data.floor>1000000:return {"ok":false,"errors":["identity"]}
	if not has_cart(data.seed,data.floor):return G16.validate(data)
	var errors:Array=[]
	if data.get("grid")!=_cart_grid(data.seed,data.floor):return {"ok":false,"errors":["cart geometry identity"]}
	if data.get("cart")!=cart_manifest(data.seed,data.floor) or data.get("contract")!=manifest(data.seed,data.floor) or data.get("rune")!=G16.rune_info(data.seed,data.floor) or data.get("routes")!=routes(data.seed,data.floor):errors.append("metadata")
	if data.get("entry")!=Vector2i(1,1) or data.get("exit")!=Vector2i(13,13):errors.append("stairs")
	if G16.has_bridge(data.seed,data.floor):errors.append("bridge collision")
	var g:Array=data.grid;var main:=Vector2i(3,9);var one:=Vector2i(6,9);var two:=Vector2i(6,10);var guardian:=Vector2i(8,2)
	for gate in ["","supply","archive"]:
		for start in [Vector2i(1,1),Vector2i(13,13)]:
			var finish:=Vector2i(13,13) if start==Vector2i(1,1) else Vector2i(1,1)
			if cart_reach(g,start,gate,[]).has(finish):errors.append("zero battle bypass")
			if not cart_reach(g,start,gate,[main]).has(finish) or not cart_reach(g,start,gate,[one,two]).has(finish):errors.append("route absent")
			for alone in [one,two]:
				if cart_reach(g,start,gate,[alone]).has(finish):errors.append("alternate guard bypass")
			var all:Array=[main,one,two,guardian]
			if cart_reach(g,start,gate,all,false,true).has(Vector2i(12,3)):errors.append("key vault bypass")
			if cart_reach(g,start,gate,all,true,false).has(Vector2i(12,10)):errors.append("old relic bypass")
			if not cart_reach(g,start,gate,all,true,true).has(Vector2i(12,3)) or not cart_reach(g,start,gate,all,true,true).has(Vector2i(12,10)):errors.append("old reward inaccessible")
			if cart_reach(g,start,gate,[main,one,two],true,true).has(Vector2i(8,1)):errors.append("archive guardian bypass")
			if cart_reach(g,start,gate,all,true,true).has(Vector2i(8,1))!=(gate=="archive"):errors.append("archive gate")
			if cart_reach(g,start,gate,all,true,true).has(Vector2i(5,1))!=(gate=="supply"):errors.append("supply gate")
	var safe:=cart_reach(g,Vector2i(3,1),"",[],false,false,false)
	if not safe.has(Vector2i(3,7)):errors.append("supply pocket requires stair transition")
	for station in [Vector2i(2,2),skill_position(data.seed,data.floor)]:
		var reachable:=false
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if safe.has(station+d):reachable=true
		if not reachable:errors.append("entry station inaccessible")
	var potential:Array=g.duplicate(true);var origin:Vector2i=cart_manifest(data.seed,data.floor).cart_origin;potential[origin.y][origin.x]="."
	var all_seen:=cart_reach(potential,Vector2i(1,1),"both",[main,one,two,guardian],true,true)
	for y in 15:
		for x in 15:
			if potential[y][x] not in ["#","M","S","R"] and not all_seen.has(Vector2i(x,y)):errors.append("potential floor disconnected")
	return {"ok":errors.is_empty(),"errors":errors}
