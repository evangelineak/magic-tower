class_name TowerGenerator
extends RefCounted
const Progression = preload("res://scripts/progression.gd")

# Bounded, reproducible variation of an authored tower, not unconstrained rooms.
# Every accepted map carries a conservative no-loan/no-skill winning witness.
const MAX_ATTEMPTS := 16
const LOOT := ["a", "d", "h", "k", "s", "g", "u", "b", "w"]
const ENEMIES := {
	"s": {"hp":35, "atk":14, "def":3},
	"g": {"hp":75, "atk":25, "def":10},
	"u": {"name":"Veil Stalker", "hp":95, "atk":42, "def":14, "first_strike":true},
	"b": {"name":"Briar Sentinel", "hp":90, "atk":35, "def":12, "thorns":2},
	"w": {"name":"Brass Juggernaut", "hp":180, "atk":32, "def":20, "heavy_every":3},
	"K": {"hp":450, "atk":65, "def":40}
}
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
# These authored patches exclude stairs, specials, water, the left cage walls,
# the cage doors, and the third-floor vault. A template may add AND remove
# walls; ordinary tokens inside a patch are moved onto its new walkable cells.
const ROOM_REGIONS := [
	{"id":"lower_left", "origin":Vector2i(2,6), "size":Vector2i(3,2), "templates":[
		{"id":"arch", "rows":["...","#.."]},
		{"id":"west_turn", "rows":["..#","..."]},
		{"id":"east_turn", "rows":["#..","..."]},
		{"id":"split_entry", "rows":[".#.","..."]}
	]},
	{"id":"lower_right", "origin":Vector2i(6,6), "size":Vector2i(3,3), "templates":[
		{"id":"north_bend", "rows":["..#","#..","..."]},
		{"id":"south_bend", "rows":["...","..#","#.."]},
		{"id":"pillar", "rows":["...",".#.","..."]},
		{"id":"zigzag", "rows":[".#.","...",".#."]}
	]}
]
const GEOMETRY_REVISION := 1

static func in_room(p: Vector2i) -> bool:
	for region in ROOM_REGIONS:
		if Rect2i(region.origin,region.size).has_point(p): return true
	return false

static func apply_room(grid: Array, region: Dictionary, template: Dictionary, rng: RandomNumberGenerator) -> bool:
	var tokens: Array=[]
	var positions: Array=[]
	for y in range(region.size.y):
		for x in range(region.size.x):
			var p: Vector2i=region.origin+Vector2i(x,y)
			var token: String=grid[p.y][p.x]
			# Future authored specials win: skip the entire room atomically.
			if token not in ["#","."] and token not in LOOT: return false
			if token in LOOT: tokens.append(token)
			if template.rows[y][x]==".": positions.append(p)
	if positions.size()<tokens.size(): return false
	for y in range(region.size.y):
		for x in range(region.size.x):
			var p: Vector2i=region.origin+Vector2i(x,y)
			grid[p.y][p.x]=template.rows[y][x]
	for token in tokens:
		var index := rng.randi_range(0,positions.size()-1)
		var p: Vector2i=positions.pop_at(index)
		grid[p.y][p.x]=token
	return true

static func authored_rooms(floor_count: int) -> Array:
	var result: Array=[]
	for _floor in range(floor_count):
		var ids := {}
		for region in ROOM_REGIONS: ids[region.id]="authored"
		result.append(ids)
	return result

static func normalize(base_maps: Array) -> Array:
	var result: Array = []
	for rows in base_maps:
		var grid: Array = []
		for row in rows:
			var cells: Array = []
			for c in row: cells.append("." if c=="@" else c)
			grid.append(cells)
		result.append(grid)
	if result.size()>0 and result[0].size()>5 and result[0][5].size()>2:
		result[0][5][2]="E"
	return result

static func generate(seed_value: int, base_maps: Array) -> Dictionary:
	var baseline := normalize(base_maps)
	if seed_value==0:
		return {"maps":baseline,"attempts":0,"fallback":false,"validation":validate(baseline),"room_templates":authored_rooms(baseline.size()),"geometry_revision":GEOMETRY_REVISION}
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	for attempt in range(1,MAX_ATTEMPTS+1):
		var candidate := baseline.duplicate(true)
		var room_templates: Array=[]
		for floor_index in candidate.size():
			var grid: Array=candidate[floor_index]
			var room_ids := {}
			for region in ROOM_REGIONS:
				var template: Dictionary=region.templates[rng.randi_range(0,region.templates.size()-1)]
				room_ids[region.id]=template.id if apply_room(grid,region,template,rng) else "authored"
			room_templates.append(room_ids)
			var slots: Array=[]
			var tokens: Array=[]
			for y in range(1,10):
				for x in range(1,10):
					if grid[y][x] in LOOT:
						slots.append(Vector2i(x,y)); tokens.append(grid[y][x])
			# Explicit Fisher-Yates: never use Array.shuffle's global RNG.
			for i in range(tokens.size()-1,0,-1):
				var j := rng.randi_range(0,i)
				var temp = tokens[i]; tokens[i]=tokens[j]; tokens[j]=temp
			for i in slots.size(): grid[slots[i].y][slots[i].x]=tokens[i]
		# Authored water is preserved. The proof never needs to cross it.
		var proof := validate(candidate)
		if proof.solvable:
			return {"maps":candidate,"attempts":attempt,"fallback":false,"validation":proof,"room_templates":room_templates,"geometry_revision":GEOMETRY_REVISION}
	# A seed is never silently allowed to create an unverified impossible map.
	return {"maps":baseline,"attempts":MAX_ATTEMPTS,"fallback":true,"validation":validate(baseline),"room_templates":authored_rooms(baseline.size()),"geometry_revision":GEOMETRY_REVISION}

static func damage(kind: String, stats: Dictionary) -> int:
	if not ENEMIES.has(kind): return -1
	var preview := Progression.battle(stats.atk,stats.def,stats.hp,ENEMIES[kind],"warden",false,"balanced",[])
	return int(preview.damage) if preview.valid else -1

static func tile(grid: Array, p: Vector2i) -> String:
	if p.x<0 or p.y<0 or p.x>=11 or p.y>=11: return "#"
	return grid[p.y][p.x]

# Return a shortest geometric path that never crosses a special obstruction.
# HP may change along it; execute() rechecks the exact cumulative cost.
static func path_to(grid: Array, start: Vector2i, goal: Vector2i, stats: Dictionary) -> Array:
	var queue: Array=[start]
	var parents := {start:Vector2i(-99,-99)}
	var head := 0
	while head<queue.size():
		var p: Vector2i=queue[head]; head+=1
		if p==goal:
			var path: Array=[]
			while p!=start:
				var previous: Vector2i=parents[p]
				path.push_front(p-previous); p=previous
			return path
		for d in DIRS:
			var next: Vector2i=p+d
			if parents.has(next): continue
			var token := tile(grid,next)
			if token in ["#","D","L","~","V","T","B"]: continue
			if token in ["<",">","K"] and next!=goal: continue
			if ENEMIES.has(token):
				var cost := damage(token,stats)
				if cost<0 or cost>=stats.hp: continue
			parents[next]=p; queue.append(next)
	return []

static func execute(grid: Array, start: Vector2i, path: Array, stats: Dictionary) -> Dictionary:
	var pos := start
	var route := ""
	for d in path:
		var next: Vector2i=pos+d
		var token := tile(grid,next)
		if token in ["#","D","L","~","V","T","B"]: return {"ok":false}
		if ENEMIES.has(token):
			var cost := damage(token,stats)
			if cost<0 or cost>=stats.hp: return {"ok":false}
			stats.hp-=cost
		elif token=="a": stats.atk+=5
		elif token=="d": stats.def+=4
		elif token=="h": stats.hp+=70
		if token in LOOT or token=="K": grid[next.y][next.x]="."
		pos=next
		route += "U" if d==Vector2i.UP else ("D" if d==Vector2i.DOWN else ("L" if d==Vector2i.LEFT else "R"))
	return {"ok":true,"pos":pos,"route":route}

# Pure topology: ignore combat strength, but enforce every intended gate.
# Combat validation below then constructs a real no-key/no-water winning path.
static func reachable(grid: Array, blocked: Array) -> Dictionary:
	var start := Vector2i(1,1)
	if tile(grid,start) in blocked: return {}
	var seen := {start:true}
	var queue: Array=[start]
	var head := 0
	while head<queue.size():
		var p: Vector2i=queue[head]; head+=1
		for d in DIRS:
			var next: Vector2i=p+d
			if seen.has(next) or tile(grid,next) in blocked: continue
			seen[next]=true; queue.append(next)
	return seen

static func topology(maps: Array) -> Dictionary:
	for grid in maps:
		var closed := reachable(grid,["#","D","L","~","V","K"])
		var opened := reachable(grid,["#","D","~","K"])
		var guard_closed := reachable(grid,["#","D","~","V","K"])
		var cages_closed := reachable(grid,["#","D","~","L","K"])
		var drained := reachable(grid,["#","D","L","V","K"])
		for y in range(1,10):
			for x in range(1,10):
				var p := Vector2i(x,y)
				var token: String=grid[y][x]
				if token in ["M","C","E","F","N","Q","J","O","I","X"] and not closed.has(p):
					return {"valid":false,"reason":"A special object is disconnected"}
				if token in ["T","$","A","P"]:
					if (token=="T" and guard_closed.has(p)) or (token!="T" and cages_closed.has(p)):
						return {"valid":false,"reason":"A guarded reward has a bypass"}
					if not opened.has(p): return {"valid":false,"reason":"A guarded reward is sealed forever"}
				if token=="R":
					if closed.has(p): return {"valid":false,"reason":"The flooded reward has a dry bypass"}
					if not drained.has(p): return {"valid":false,"reason":"The flooded reward remains sealed after draining"}
	return {"valid":true}

static func validate(maps: Array) -> Dictionary:
	if maps.size()!=5: return {"solvable":false,"reason":"Expected five authored floors"}
	for grid in maps:
		if not grid is Array or grid.size()!=11: return {"solvable":false,"reason":"Invalid grid"}
		for row in grid:
			if not row is Array or row.size()!=11: return {"solvable":false,"reason":"Invalid row"}
	var connectivity := topology(maps)
	if not connectivity.valid: return {"solvable":false,"reason":connectivity.reason}
	var work := maps.duplicate(true)
	var stats := {"hp":280,"atk":18,"def":8}
	var route := ""
	for floor_index in work.size():
		var grid: Array=work[floor_index]
		var pos := Vector2i(1,1)
		# At most one successful collection per pass; 81 is a hard bound.
		for _pass in range(81):
			var best: Array=[]
			var best_score := 100000
			for y in range(1,10):
				for x in range(1,10):
					var token: String=grid[y][x]
					if not token in LOOT: continue
					var path := path_to(grid,pos,Vector2i(x,y),stats)
					if path.is_empty(): continue
					var score: int=path.size()+(30 if token in ["s","g","u","b","w"] else 0)
					if score>=best_score: continue
					# Reject geometrically legal paths that overspend HP before
					# reaching their destination; don't mutate the real proof.
					var dry := execute(grid.duplicate(true),pos,path,stats.duplicate())
					if dry.ok: best=path; best_score=score
			if best.is_empty(): break
			var moved := execute(grid,pos,best,stats)
			if not moved.ok: return {"solvable":false,"reason":"HP exhausted"}
			pos=moved.pos; route+=moved.route
		var goal := Vector2i(9,9) if floor_index<work.size()-1 else Vector2i(8,3)
		if tile(grid,goal)!=(">" if floor_index<work.size()-1 else "K"):
			return {"solvable":false,"reason":"Missing goal"}
		var finish := path_to(grid,pos,goal,stats)
		if finish.is_empty(): return {"solvable":false,"reason":"No conservative route"}
		var final_moved := execute(grid,pos,finish,stats)
		if not final_moved.ok: return {"solvable":false,"reason":"Final path lethal"}
		route+=final_moved.route
	return {"solvable":true,"route":route,"moves":route.length(),"hp":stats.hp,"atk":stats.atk,"def":stats.def}
