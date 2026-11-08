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
# Whole-floor authored skeletons, not mirrors and not local wall-removal patches.
# Every floor keeps its authored stairs, special objects, gates and gate walls.
# All ordinary items/enemies are then scattered under the original floor budget.
const SKELETONS := {
	"ring": [
		"###########","#.........#","#..##.###.#","#.........#",
		"#..#......#","#......#..#","#.#####...#","#.........#",
		"##..#####.#","#.........#","###########"
	],
	"courtyards": [
		"###########","#....#....#","#..##...#.#","#.###.....#",
		"#...#.###.#","#.........#","####.####.#","#....#....#",
		"##.#.#.##.#","#....#....#","###########"
	],
	"spine": [
		"###########","#.....#...#","#..####.#.#","#...#...#.#",
		"#...#.#...#","##..#.....#","#...#####.#","#..#......#",
		"##..####..#","#.........#","###########"
	]
}
const GEOMETRY_REVISION := 2

static func protected_walls(base_grid: Array) -> Array:
	var result: Array=[]
	if base_grid[9][1] in ["$","A","P"]: result.append(Vector2i(1,8))
	if base_grid[3][9]=="T": result.append(Vector2i(9,2)); result.append(Vector2i(9,4))
	for row in base_grid:
		if "R" in row:
			result.append(Vector2i(6,1))
			break
	return result

static func build_skeleton(base_grid: Array, id: String) -> Array:
	if not SKELETONS.has(id): return []
	var grid: Array=[]
	for row in SKELETONS[id]:
		var cells: Array=[]
		for c in row: cells.append(c)
		grid.append(cells)
	for y in range(11):
		for x in range(11):
			var token: String=base_grid[y][x]
			if token not in ["#","."] and token not in LOOT: grid[y][x]=token
	for p in protected_walls(base_grid): grid[p.y][p.x]="#"
	return grid

static func reachable_without(grid: Array, excluded: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	var work := grid.duplicate(true)
	if excluded.x>=0 and excluded.y>=0: work[excluded.y][excluded.x]="#"
	return reachable(work,["#","D","L","~","V"])

# Semantic identity checks after fixed anchors are overlaid. A ring must retain
# two vertex-disjoint entry/goal routes; courtyards and spine use different
# mandatory junctions. This prevents protected anchors from erasing the design.
static func skeleton_valid(grid: Array, id: String, floor_index: int) -> bool:
	var goal := Vector2i(8,3) if floor_index==4 else Vector2i(9,9)
	var cells := reachable_without(grid)
	if not cells.has(goal): return false
	if id=="courtyards": return not reachable_without(grid,Vector2i(4,5)).has(goal)
	if id=="spine": return tile(grid,Vector2i(4,5))=="#" and not reachable_without(grid,Vector2i(2,8)).has(goal)
	if id!="ring": return false
	for p in cells:
		if p in [Vector2i(1,1),goal]: continue
		if not reachable_without(grid,p).has(goal): return false
	return true

static func scatter_loot(grid: Array, baseline: Array, rng: RandomNumberGenerator) -> bool:
	var dry_tokens: Array=[]
	var wet_tokens: Array=[]
	var baseline_closed := reachable(baseline,["#","D","L","~","V","K"])
	var baseline_drained := reachable(baseline,["#","D","L","V","K"])
	for y in range(1,10):
		for x in range(1,10):
			if baseline[y][x] not in LOOT: continue
			var p := Vector2i(x,y)
			if baseline_closed.has(p): dry_tokens.append(baseline[y][x])
			else:
				# Preserve exact gated item categories, not merely their count:
				# the optional flooded ruby cannot become a main-route key or
				# push that ruby into the free main-route growth budget.
				if not baseline_drained.has(p): return false
				wet_tokens.append(baseline[y][x])
	var closed := reachable(grid,["#","D","L","~","V","K"])
	var drained := reachable(grid,["#","D","L","V","K"])
	var dry_slots: Array=[]
	var wet_slots: Array=[]
	for y in range(1,10):
		for x in range(1,10):
			var p := Vector2i(x,y)
			if grid[y][x]!="." or p in [Vector2i(1,1),Vector2i(9,9)]: continue
			if closed.has(p): dry_slots.append(p)
			elif drained.has(p): wet_slots.append(p)
	if wet_slots.size()<wet_tokens.size() or dry_slots.size()<dry_tokens.size(): return false
	for pair in [[wet_tokens,wet_slots],[dry_tokens,dry_slots]]:
		var tokens: Array=pair[0]
		var slots: Array=pair[1]
		for i in range(tokens.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var temp = tokens[i]; tokens[i]=tokens[j]; tokens[j]=temp
		for token in tokens:
			var p: Vector2i=slots.pop_at(rng.randi_range(0,slots.size()-1))
			grid[p.y][p.x]=token
	return true

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
	var authored: Array=[]
	for _floor in baseline.size(): authored.append("authored")
	if seed_value==0:
		return {"maps":baseline,"attempts":0,"fallback":false,"validation":validate(baseline),"floor_skeletons":authored,"geometry_revision":GEOMETRY_REVISION}
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var skeleton_ids: Array=SKELETONS.keys()
	for attempt in range(1,MAX_ATTEMPTS+1):
		var candidate: Array=[]
		var selected: Array=[]
		var valid := true
		for floor_index in baseline.size():
			var id: String=skeleton_ids[rng.randi_range(0,skeleton_ids.size()-1)]
			var grid := build_skeleton(baseline[floor_index],id)
			if not skeleton_valid(grid,id,floor_index) or not scatter_loot(grid,baseline[floor_index],rng):
				valid=false
				break
			candidate.append(grid); selected.append(id)
		if not valid: continue
		var proof := validate(candidate)
		if proof.solvable:
			return {"maps":candidate,"attempts":attempt,"fallback":false,"validation":proof,"floor_skeletons":selected,"geometry_revision":GEOMETRY_REVISION}
	# A failed proof never opens an unverified run. World checks this flag too.
	return {"maps":baseline,"attempts":MAX_ATTEMPTS,"fallback":true,"validation":validate(baseline),"floor_skeletons":authored,"geometry_revision":GEOMETRY_REVISION}

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
		# Test each reward gate in isolation: opening an ordinary one-key
		# door must never bypass its two-key lock, guardian or flooded route.
		var guard_closed := reachable(grid,["#","~","V","K"])
		var cages_closed := reachable(grid,["#","~","L","K"])
		var water_closed := reachable(grid,["#","~","K"])
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
					if water_closed.has(p): return {"valid":false,"reason":"The flooded reward has a dry bypass"}
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
