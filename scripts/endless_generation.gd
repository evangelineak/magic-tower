class_name TowerEndlessGeneration
extends RefCounted
## Standalone geometry prototype. No World/save integration or combat guarantee.
const SIZE:=15
const REVISION:=1
const DIRS: Array[Vector2i]=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
const A:=Vector2i(1,1)
const B:=Vector2i(13,13)
const DOOR:=Vector2i(10,3)
const REWARD:=Vector2i(12,3)
const KEY:=Vector2i(3,3)
const GUARD:=Vector2i(10,10)
const VAULT:=Vector2i(12,10)
# Modular arithmetic keeps high floor numbers deterministic without overflowing
# seed * floor or depending on the engine's global random stream.
static func valid_input(seed:int,floor_number:int)->bool:
	return seed>=0 and seed<=2147483647 and floor_number>=1
static func anchors(floor_number:int)->Dictionary:
	return {"entry":A if floor_number%2==1 else B,"exit":B if floor_number%2==1 else A}
static func next_random(state:int)->int:
	return (state*48271)%2147483647
static func generate(seed:int,floor_number:int)->Dictionary:
	if not valid_input(seed,floor_number): return {"ok":false,"reason":"Invalid seed or floor"}
	var state:int=(seed%2147483646+(floor_number%2147483646)*97+1)%2147483647
	if state==0: state=1
	var grid:Array=[]
	for y in SIZE:
		var row:Array=[]
		for x in SIZE: row.append("#")
		grid.append(row)
	# A perimeter spine links both anchors; every optional western branch joins it.
	for x in range(1,14): grid[1][x]=".";grid[13][x]="."
	for y in range(1,14): grid[y][1]=".";grid[y][13]="."
	for y in [3,5,7,10]:
		for x in range(1,10): grid[y][x]="."
	for y in range(1,14):grid[y][3]="."
	# Seeded loops and alcoves, strictly outside the authored guarded rooms.
	for y in [2,4,6,8,9,11,12]:
		for x in range(5,10):
			state=next_random(state)
			if state%3!=0:grid[y][x]="."
	# Both rooms have one west entrance, a solid east wall, floor/ceiling walls.
	for y in [3,10]:
		for x in range(10,14):grid[y-1][x]="#";grid[y+1][x]="#"
		grid[y][10]="D" if y==3 else "V"
		grid[y][11]=".";grid[y][12]="$" if y==3 else "T";grid[y][13]="#"
	# Keep the outer spine connected without opening a room's east boundary:
	# the western rail plus north/south halls suffice; right rail is optional.
	grid[KEY.y][KEY.x]="k"
	var pair:=anchors(floor_number)
	grid[pair.entry.y][pair.entry.x]="<"
	grid[pair.exit.y][pair.exit.x]=">"
	var result:Dictionary={"ok":true,"revision":REVISION,"seed":seed,"floor":floor_number,"grid":grid,"entry":pair.entry,"exit":pair.exit,"door":DOOR,"reward":REWARD,"key":KEY,"guard":GUARD,"vault":VAULT,"combat_budget_verified":false}
	var proof:=validate(result)
	result.ok=proof.ok;result.proof=proof
	return result
static func tile(grid:Array,p:Vector2i)->String:
	if p.x<0 or p.y<0 or p.y>=grid.size() or not grid[p.y] is Array or p.x>=grid[p.y].size():return "#"
	return grid[p.y][p.x] if grid[p.y][p.x] is String else "#"
static func reachable(grid:Array,start:Vector2i,open_door:bool=false,defeat_guard:bool=false)->Dictionary:
	var seen:Dictionary={}
	if tile(grid,start)=="#":return seen
	var queue:Array[Vector2i]=[start];seen[start]=true;var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		for d in DIRS:
			var q:=p+d;var t:=tile(grid,q)
			if t=="#" or (t=="D" and not open_door) or (t=="V" and not defeat_guard) or seen.has(q):continue
			seen[q]=true;queue.append(q)
	return seen
static func validate(data:Dictionary)->Dictionary:
	var failed:Array[String]=[]
	if not data.get("seed") is int or data.seed<0 or data.seed>2147483647 or data.get("revision")!=REVISION:return {"ok":false,"errors":["identity"]}
	if not data.get("grid") is Array or data.grid.size()!=SIZE:return {"ok":false,"errors":["height"]}
	var grid:Array=data.grid
	var counts:Dictionary={}
	for y in SIZE:
		if not grid[y] is Array or grid[y].size()!=SIZE:return {"ok":false,"errors":["width"]}
		for x in SIZE:
			var t=grid[y][x]
			if not t is String or not t in ["#",".","<",">","D","V","k","$","T"]:return {"ok":false,"errors":["token"]}
			counts[t]=counts.get(t,0)+1
			if (x==0 or y==0 or x==SIZE-1 or y==SIZE-1) and t!="#":failed.append("boundary")
	if not data.get("floor") is int or data.floor<1:return {"ok":false,"errors":["floor"]}
	var pair:=anchors(data.floor)
	for name in ["entry","exit"]:
		if data.get(name)!=pair[name]:failed.append("anchor metadata")
	for name in ["door","reward","key","guard","vault"]:
		if data.get(name)!={"door":DOOR,"reward":REWARD,"key":KEY,"guard":GUARD,"vault":VAULT}[name]:failed.append("object metadata")
	for token in ["<",">","D","V","k","$","T"]:
		if counts.get(token,0)!=1:failed.append("unique "+token)
	if tile(grid,pair.entry)!="<" or tile(grid,pair.exit)!=">":failed.append("stairs")
	for p in {DOOR:"D",REWARD:"$",KEY:"k",GUARD:"V",VAULT:"T"}:
		if tile(grid,p)!={DOOR:"D",REWARD:"$",KEY:"k",GUARD:"V",VAULT:"T"}[p]:failed.append("object location")
	var closed:=reachable(grid,pair.entry)
	var opened:=reachable(grid,pair.entry,true)
	var defeated:=reachable(grid,pair.entry,false,true)
	if not closed.has(pair.exit):failed.append("main route blocked")
	if not closed.has(KEY):failed.append("key inaccessible")
	if closed.has(REWARD) or not opened.has(REWARD):failed.append("door bypass or sealed reward")
	if closed.has(VAULT) or not defeated.has(VAULT):failed.append("guard bypass or sealed vault")
	if not closed.has(GUARD+Vector2i.LEFT):failed.append("guard not discoverable")
	return {"ok":failed.is_empty(),"errors":failed,"reachable_without_cost":closed.size(),"key_outside":closed.has(KEY),"stairs_aligned":pair.exit==anchors(data.floor+1).entry if data.floor<9223372036854775807 else pair.exit==(A if data.floor%2==0 else B),"door_is_cut":not closed.has(REWARD) and opened.has(REWARD),"guard_is_optional":closed.has(pair.exit) and not closed.has(VAULT),"combat_budget_verified":false}
