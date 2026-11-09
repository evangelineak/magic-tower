class_name TowerEndlessGenerationV16
extends "res://scripts/endless_generation_v15.gd"
const G15=preload("res://scripts/endless_generation_v15.gd")
static func has_bridge(seed:int,f:int)->bool:return f%2==1 and G15.mix(seed,f,2707)%4==0
static func layout_name(seed:int,f:int)->String:return "双臂绞盘院" if has_bridge(seed,f) else G15.layout_name(seed,f)
static func routes(seed:int,f:int)->Array:
	var rows:Array=G15.routes(seed,f).duplicate(true)
	if has_bridge(seed,f):rows[0].points=[Vector2i(3,8)];rows[1].points=[Vector2i(8,8),Vector2i(8,9)]
	return rows
static func manifest(seed:int,f:int)->Dictionary:
	var data:Dictionary=G15.manifest(seed,f);data.points=routes(seed,f)[data.route].points.duplicate();return data
static func bridge_info(seed:int,f:int)->Dictionary:
	return {"present":has_bridge(seed,f),"winch":Vector2i(5,6),"short":[Vector2i(7,8)],"loot":[Vector2i(6,5)],"bypassed":Vector2i(8,8),"remaining":Vector2i(8,9),"guardian":Vector2i(6,4),"reward":Vector2i(6,3)}
static func generate(seed:int,f:int)->Dictionary:
	if seed<0 or seed>2147483647 or f<1 or f>1000000:return {"ok":false,"errors":["identity"]}
	if not has_bridge(seed,f):return G15.generate(seed,f)
	var g:Array=[]
	for y in 15:
		var row:Array=[]
		for x in 15:row.append("#" if x==0 or y==0 or x==14 or y==14 else ".")
		g.append(row)
	for x in range(1,14):g[8][x]="#"
	g[9][6]="#";g[10][7]="#";g[8][7]="u"
	for y in range(2,6):g[y][5]="#";g[y][7]="#"
	g[2][6]="#";g[3][6]="B";g[4][6]="c";g[5][6]="v";g[6][5]="N"
	for y in [3,10]:
		for x in range(10,14):g[y-1][x]="#";g[y+1][x]="#"
		g[y][10]="D" if y==3 else "V";g[y][11]=".";g[y][12]="$" if y==3 else "T";g[y][13]="#"
	g[1][2]="a";g[1][3]="C";g[2][2]="M";g[2][3]="S";g[3][3]="k"
	g[1][1]="<";g[13][13]=">"
	var rr:=routes(seed,f);var types:=G15.roster12(seed,f)
	var points:Array=[rr[0].points[0],rr[1].points[0],rr[1].points[1]]
	for i in 3:g[points[i].y][points[i].x]=types[i]
	var data:Dictionary={"ok":true,"seed":seed,"floor":f,"revision":16,"grid":g,"entry":Vector2i(1,1),"exit":Vector2i(13,13),"layout":"winch","routes":rr,"contract":manifest(seed,f),"rune":G15.rune_info(seed,f),"bridge":bridge_info(seed,f)}
	data.proof=validate(data);data.ok=data.proof.ok;return data
static func bridge_reach(g:Array,start:Vector2i,state:String,guards:Array,open_d:bool=false,open_v:bool=false)->Dictionary:
	var queue:Array[Vector2i]=[start];var seen:Dictionary={start:true};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d
			if q.x<0 or q.y<0 or q.x>=15 or q.y>=15 or seen.has(q):continue
			var t:String=g[q.y][q.x]
			if t in ["#","N","M","S"]:continue
			if t=="u" and state not in ["short","both"]:continue
			if t=="v" and state not in ["loot","both"]:continue
			if t=="D" and not open_d:continue
			if t=="V" and not open_v:continue
			if t in ["g","b","w","r","c","t","p"] and q not in guards:continue
			seen[q]=true;queue.append(q)
	return seen
static func validate(data:Dictionary)->Dictionary:
	if not data.get("seed") is int or not data.get("floor") is int:return {"ok":false,"errors":["identity"]}
	if data.seed<0 or data.seed>2147483647 or data.floor<1 or data.floor>1000000:return {"ok":false,"errors":["identity"]}
	if not has_bridge(data.seed,data.floor):return G15.validate(data)
	if not data.get("grid") is Array or data.grid.size()!=15:return {"ok":false,"errors":["height"]}
	for row in data.grid:
		if not row is Array or row.size()!=15:return {"ok":false,"errors":["width"]}
	var g:Array=data.grid;var errors:Array=[];var rr:=routes(data.seed,data.floor);var types:=G15.roster12(data.seed,data.floor)
	var pts:Array=[Vector2i(3,8),Vector2i(8,8),Vector2i(8,9)]
	for i in 3:
		if g[pts[i].y][pts[i].x]!=types[i]:errors.append("main guard identity")
	var objects:Dictionary={Vector2i(5,6):"N",Vector2i(7,8):"u",Vector2i(6,5):"v",Vector2i(6,4):"c",Vector2i(6,3):"B",Vector2i(10,3):"D",Vector2i(12,3):"$",Vector2i(10,10):"V",Vector2i(12,10):"T",Vector2i(3,3):"k",Vector2i(2,1):"a",Vector2i(3,1):"C",Vector2i(2,2):"M",Vector2i(3,2):"S",Vector2i(1,1):"<",Vector2i(13,13):">"}
	var counts:Dictionary={}
	for y in 15:
		for x in 15:
			var t=g[y][x];var p:=Vector2i(x,y)
			if not t is String or t not in ["#",".","g","b","w","r","c","t","p","D","V","$","T","k","a","C","M","S","<",">","N","u","v","B"]:return {"ok":false,"errors":["token"]}
			counts[t]=counts.get(t,0)+1
			if (x==0 or y==0 or x==14 or y==14) and t!="#":errors.append("boundary")
			if t in ["g","b","w","r","c","t","p"] and p not in pts and p!=Vector2i(6,4):errors.append("undeclared enemy")
	for p in objects:
		if g[p.y][p.x]!=objects[p]:errors.append("object identity")
	for t in ["D","V","$","T","k","a","C","M","S","<",">","N","u","v","B"]:
		if counts.get(t,0)!=1:errors.append("object count")
	if data.get("entry")!=Vector2i(1,1) or data.get("exit")!=Vector2i(13,13):errors.append("stairs")
	if data.get("bridge",{})!=bridge_info(data.seed,data.floor) or data.get("contract",{})!=manifest(data.seed,data.floor) or data.get("rune",{})!=G15.rune_info(data.seed,data.floor):errors.append("metadata")
	var all:Array=pts.duplicate();all.append(Vector2i(6,4))
	for state in ["closed","short","loot"]:
		for start in [Vector2i(1,1),Vector2i(13,13)]:
			var end:Vector2i=Vector2i(13,13) if start==Vector2i(1,1) else Vector2i(1,1)
			if bridge_reach(g,start,state,[]).has(end):errors.append("zero battle bypass")
			if not bridge_reach(g,start,state,[pts[0]]).has(end):errors.append("main route absent")
			if not bridge_reach(g,start,state,[pts[2]] if state=="short" else [pts[1],pts[2]]).has(end):errors.append("alternate contract")
			if bridge_reach(g,start,state,[pts[1]]).has(end):errors.append("second alternate guard bypass")
			if state!="short" and bridge_reach(g,start,state,[pts[2]]).has(end):errors.append("first alternate guard bypass without payment")
		var closed:=bridge_reach(g,Vector2i(1,1),state,all)
		if closed.has(Vector2i(12,3)) or not bridge_reach(g,Vector2i(1,1),state,all,true).has(Vector2i(12,3)):errors.append("D gate bypass")
		if closed.has(Vector2i(12,10)) or not bridge_reach(g,Vector2i(1,1),state,all,false,true).has(Vector2i(12,10)):errors.append("V gate bypass")
		if closed.has(Vector2i(6,3))!=(state=="loot"):errors.append("optional reward access")
		if bridge_reach(g,Vector2i(1,1),state,pts).has(Vector2i(6,3)):errors.append("optional guardian bypass")
	var potential:=bridge_reach(g,Vector2i(1,1),"both",all,true,true)
	var safe:=bridge_reach(g,Vector2i(1,1),"closed",[])
	for y in 15:
		for x in 15:
			if g[y][x] not in ["#","M","S","N"] and not potential.has(Vector2i(x,y)):errors.append("unexplained isolated floor")
	for p in [Vector2i(2,2),Vector2i(3,2),Vector2i(5,6)]:
		var near:=false
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if safe.has(p+d):near=true
		if not near:errors.append("unsafe station")
	return {"ok":errors.is_empty(),"errors":errors,"conditional_bridge_contract":true}
