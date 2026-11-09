class_name TowerEndlessGenerationV3
extends RefCounted
const Base=preload("res://scripts/endless_generation_v2.gd")
const PRIMARY:=Vector2i(3,7)
static func anchors(f:int)->Dictionary:return Base.anchors(f)
static func layout(seed:int,f:int)->String:return Base.layout(seed,f)
static func alternate_points(seed:int,f:int)->Array[Vector2i]:return Base.alternate_points(seed,f)
static func generate(seed:int,f:int)->Dictionary:return Base.generate(seed,f)
# The historical survey is a separate immutable inset, NOT today's floor map.
# s=start, T=bell tower (must visit), W=well (forbidden), D=locked gate.
# Candidate letters identify locations, never whether the messenger is there.
static func historical_map(seed:int)->Array:
	var letters:Array=["A","B","C"]
	# Use T for tower so candidate B remains unambiguous.
	var rows:Array=["#######","#s.T..#","###.#.#","#...#.#","#D###W#","#.###.#","#######"]
	var grid:Array=[]
	for row in rows:
		var cells:Array=[]
		for token in row:cells.append(token)
		grid.append(cells)
	var slot:int=seed%3
	grid[1][5]=letters[slot]
	grid[5][1]=letters[(slot+1)%3]
	grid[5][5]=letters[(slot+2)%3]
	if seed%2==1:grid[4][1]="g"
	for turn in (seed/3)%4:
		var rotated:Array=[]
		for y in 7:
			var row:Array=[]
			for x in 7:row.append(grid[6-x][y])
			rotated.append(row)
		grid=rotated
	return grid
static func solve_case(grid:Array,allow:Array=[])->Array[String]:
	var answer:Array[String]=[]
	if grid.size()!=7:return answer
	var start:=Vector2i(-1,-1);var counts:Dictionary={}
	for y in 7:
		if not grid[y] is Array or grid[y].size()!=7:return []
		for x in 7:
			var t=grid[y][x]
			if not t is String or t not in ["#",".","s","T","W","D","A","B","C","g"]:return []
			counts[t]=counts.get(t,0)+1
			if t=="s":start=Vector2i(x,y)
	for t in ["s","T","A","B","C"]:
		if counts.get(t,0)!=1:return []
	var queue:Array=[{"p":start,"tower":false}];var seen:Dictionary={};var head:=0
	while head<queue.size():
		var state:Dictionary=queue[head];head+=1
		var p:Vector2i=state.p;var tower:bool=state.tower or grid[p.y][p.x]=="T"
		var key:=Vector3i(p.x,p.y,1 if tower else 0)
		if seen.has(key):continue
		seen[key]=true
		if tower and grid[p.y][p.x] in ["A","B","C"] and grid[p.y][p.x] not in answer:answer.append(grid[p.y][p.x])
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d
			if q.x<0 or q.y<0 or q.x>=7 or q.y>=7 or grid[q.y][q.x]=="#" or (grid[q.y][q.x] in ["D","W","g"] and grid[q.y][q.x] not in allow):continue
			queue.append({"p":q,"tower":tower})
	answer.sort();return answer

static func wrong_reason(seed:int,letter:String)->String:
	var grid:=historical_map(seed)
	if letter in solve_case(grid,["W"]):return "到达这里必须经过水井，但收件记录明确说他没经过水井。"
	if letter in solve_case(grid,["D"]):return "到达这里必须打开锁门，但出发记录说明他没有钥匙。"
	if letter in solve_case(grid,["g"]):return "到达这里必须越过守卫，但出发记录说明他没有战斗能力。"
	return "没有符合记录的路线。请检查是否经过钟楼。"

static func validate(data:Dictionary)->Dictionary:return Base.validate(data)
