class_name TowerExpedition
extends RefCounted
const Generator = preload("res://scripts/generation.gd")
const Progression = preload("res://scripts/progression.gd")
const ENEMIES = {"Z":{"name":"Ashen Castellan","hp":720,"atk":65,"def":45,"gold":160},"H":{"name":"Ferry Warden","hp":180,"atk":62,"def":30,"gold":60,"first_strike":true}}
const INITIAL = {"hp":121,"atk":73,"def":24}
const DIRS = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
const IDS = ["low_causeway","split_court","high_gallery"]

# A vertical gorge separates entry and destination. The paid bridge is an
# alternative to a guarded southern crossing, never a bypass of the final boss.
# Layouts relocate the crossing and a second transverse wall, not just loot.
static func build(floor_index:int, variant:int) -> Array:
	var grid:Array=[]
	for y in range(11):
		var row:Array=[]
		for x in range(11): row.append("#" if x==0 or y==0 or x==10 or y==10 else ".")
		grid.append(row)
	var cross_y:int=[8,7,6][variant]
	for y in range(1,10): grid[y][5]="#"
	grid[3][5]="="
	grid[cross_y][5]="H"
	# Each route has a different courtyard approach. These walls never block
	# the camp, its sightline toward the bridge, or the two-key reward cage.
	if variant==0:
		for x in range(6,9): grid[6][x]="#"
	elif variant==1:
		for x in range(2,5): grid[5][x]="#"
		for x in range(7,10): grid[5][x]="#"
	else:
		for x in range(1,4): grid[4][x]="#"
		for x in range(6,9): grid[7][x]="#"
	grid[1][1]="<"
	grid[9][9]=">" if floor_index<2 else "."
	grid[2][2]="U" if floor_index==0 else "."
	grid[3][2]="Y" if floor_index==0 else "."
	grid[3][3]="h"; grid[1][3]="h"; grid[2][3]="a"; grid[1][4]="d"
	grid[8][2]="k"; grid[8][1]="#"; grid[9][2]="L"
	grid[9][1]=["$","A","P"][floor_index]
	grid[1][7]="h"; grid[2][8]="a"
	grid[8][8]="w"; grid[9][7]="k"
	if floor_index==2: grid[3][8]="Z"
	return grid

static func generate(seed_value:int) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value ^ 0x51A72
	var maps:Array=[]; var ids:Array=[]
	for f in range(3):
		var variant:=f if seed_value==0 else rng.randi_range(0,2)
		maps.append(build(f,variant)); ids.append(IDS[variant])
	var proof:=validate(maps)
	return {"maps":maps,"validation":proof,"witness":proof.get("route",""),"solvable":proof.solvable,"attempts":1,"fallback":false,"floor_skeletons":ids}

static func damage(token:String,stats:Dictionary)->int:
	var enemy:Dictionary=ENEMIES.get(token,Generator.ENEMIES.get(token,{}))
	if enemy.is_empty(): return -1
	var p:=Progression.battle(stats.atk,stats.def,stats.hp,enemy,"warden",false,"balanced",[])
	return int(p.damage) if p.valid else -1

static func path_to(grid:Array,start:Vector2i,goal:Vector2i,stats:Dictionary)->Array:
	var queue:Array=[start]; var parents:Dictionary={start:Vector2i(-1,-1)}; var head:=0
	while head<queue.size():
		var p:Vector2i=queue[head]; head+=1
		if p==goal:
			var path:Array=[]
			while p!=start:
				var previous:Vector2i=parents[p]; path.push_front(p-previous); p=previous
			return path
		for d in DIRS:
			var n:Vector2i=p+d
			if parents.has(n): continue
			var token:=Generator.tile(grid,n)
			if token in ["#","=","L","D"]: continue
			if token in ["<",">","Z"] and n!=goal: continue
			if token in Generator.ENEMIES or token in ENEMIES:
				var cost:=damage(token,stats)
				if cost<0 or cost>=stats.hp: continue
			parents[n]=p; queue.append(n)
	return []

static func execute(grid:Array,start:Vector2i,path:Array,stats:Dictionary)->Dictionary:
	var pos:=start; var route:=""
	for d in path:
		pos+=d
		var token:=Generator.tile(grid,pos)
		if token in ["#","=","L","D"]: return {"ok":false}
		if token in Generator.ENEMIES or token in ENEMIES:
			var cost:=damage(token,stats)
			if cost<0 or cost>=stats.hp: return {"ok":false}
			stats.hp-=cost
		elif token=="a": stats.atk+=5
		elif token=="d": stats.def+=4
		elif token=="h": stats.hp+=70
		if token in Generator.LOOT or token in ["H","Z"]: grid[pos.y][pos.x]="."
		route+="U" if d==Vector2i.UP else ("D" if d==Vector2i.DOWN else ("L" if d==Vector2i.LEFT else "R"))
	return {"ok":true,"pos":pos,"route":route}

static func validate(maps:Array)->Dictionary:
	if maps.size()!=3: return {"solvable":false,"reason":"Expected three expedition floors"}
	for grid in maps:
		if not grid is Array or grid.size()!=11: return {"solvable":false,"reason":"Invalid expedition grid"}
		for row in grid:
			if not row is Array or row.size()!=11: return {"solvable":false,"reason":"Invalid expedition row"}
	var work:=maps.duplicate(true); var stats:=INITIAL.duplicate(); var route:=""
	for f in range(3):
		var grid:Array=work[f]; var pos:=Vector2i(1,1)
		for _pass in range(81):
			var best:Array=[]; var score:=100000
			for y in range(1,10):
				for x in range(1,10):
					var t:String=grid[y][x]
					if t not in Generator.LOOT and t!="H": continue
					var path:=path_to(grid,pos,Vector2i(x,y),stats)
					if path.is_empty(): continue
					var rank:int=path.size()+(30 if t in Generator.ENEMIES or t=="H" else 0)
					if rank>=score: continue
					if execute(grid.duplicate(true),pos,path,stats.duplicate()).ok: best=path; score=rank
			if best.is_empty(): break
			var result:=execute(grid,pos,best,stats)
			if not result.ok: return {"solvable":false,"reason":"Expedition path lethal"}
			pos=result.pos; route+=result.route
		var goal:=Vector2i(8,3) if f==2 else Vector2i(9,9)
		if Generator.tile(grid,goal)!=("Z" if f==2 else ">"): return {"solvable":false,"reason":"Missing expedition goal"}
		var path:=path_to(grid,pos,goal,stats)
		if path.is_empty(): return {"solvable":false,"reason":"No expedition path"}
		var end:=execute(grid,pos,path,stats)
		if not end.ok: return {"solvable":false,"reason":"Expedition boss lethal"}
		route+=end.route
	return {"solvable":true,"route":route,"hp":stats.hp,"atk":stats.atk,"def":stats.def,"moves":route.length()}
