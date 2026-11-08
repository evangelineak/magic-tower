class_name TowerWorld
extends RefCounted

const MAPS = [
["###########","#@.k..#..a#","#..#..#...#","#h.#s.D.s.#","#..#..#...#","#..a..#h..#","#.###.###.#","#...s...k.#","#d..#..s..#","#...#....>#","###########"],
["###########","#<....#..a#","#.##s.#...#","#k.#..D.g.#","#..#..#...#","#h.d..#h..#","#.###.###.#","#...g...k.#","#a..#..s..#","#...#....>#","###########"],
["###########","#<.h..#..a#","#..#g.#...#","#k.#..D.B.#","#..#..#...#","#..a..#h..#","#.###.###.#","#...g...k.#","#d..#..g..#","#...#.....#","###########"]]
const ENEMIES = {
"s": {"name":"Mossling", "hp":35, "atk":14, "def":3, "gold":8},
"g": {"name":"Sentinel", "hp":75, "atk":25, "def":10, "gold":18},
"B": {"name":"Hollow King", "hp":220, "atk":42, "def":20, "gold":100}}
var floors: Array = []
var floor_index := 0
var pos := Vector2i(1,1)
var hp := 360
var atk := 18
var defense := 8
var keys := 0
var gold := 0
var won := false
var moves := 0
var message := "Find the keys. Read your enemies. Ascend."
func _init():
	for rows in MAPS:
		var grid: Array = []
		for row in rows:
			var cells: Array = []
			for c in row: cells.append(c)
			grid.append(cells)
		floors.append(grid)
	floors[0][1][1] = "."
func tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= 11 or p.y >= 11: return "#"
	return floors[floor_index][p.y][p.x]
func damage(kind: String) -> int:
	var e: Dictionary = ENEMIES[kind]
	var hit: int = atk - e.def
	if hit <= 0: return -1
	return maxi(0, ceili(float(e.hp) / hit) - 1) * maxi(0, e.atk - defense)
func step(direction: Vector2i) -> bool:
	if won: return false
	var target := pos + direction
	var t := tile(target)
	if t == "#": return false
	if t == "D" and keys == 0:
		message = "Locked. A gold key is needed."
		return false
	if ENEMIES.has(t):
		var cost := damage(t)
		if cost < 0 or cost >= hp:
			message = "Too dangerous. Find more crystals first."
			return false
		hp -= cost
		gold += ENEMIES[t].gold
		message = "%s defeated. -%d HP" % [ENEMIES[t].name, cost]
		if t == "B": won = true
	elif t == "k":
		keys += 1
		message = "A gold key. Every door is a decision."
	elif t == "D":
		keys -= 1
		message = "The seal breaks."
	elif t == "h":
		hp += 100
		message = "Spring water: +100 HP"
	elif t == "a":
		atk += 5
		message = "Ruby of resolve: +5 ATK"
	elif t == "d":
		defense += 4
		message = "Sapphire ward: +4 DEF"
	pos = target
	moves += 1
	if t == ">":
		floor_index += 1
		pos = Vector2i(1,1)
		message = "Ascended to floor %d." % (floor_index + 1)
	elif t == "<":
		floor_index -= 1
		pos = Vector2i(9,9)
		message = "Backtracking is wisdom, not defeat."
	elif t != ".": floors[floor_index][target.y][target.x] = "."
	return true
func save_data() -> Dictionary:
	return {"version":1,"floors":floors,"floor":floor_index,"x":pos.x,"y":pos.y,"hp":hp,"atk":atk,"def":defense,"keys":keys,"gold":gold,"won":won,"moves":moves}
func restore(d: Dictionary) -> bool:
	if d.get("version") != 1: return false
	for key in ["floor","x","y","hp","atk","def","keys","gold","moves"]:
		if not d.has(key) or not (d[key] is float or d[key] is int): return false
	if not d.get("floors") is Array or d.floors.size()!=3: return false
	for grid in d.floors:
		if not grid is Array or grid.size()!=11: return false
		for row in grid:
			if not row is Array or row.size()!=11: return false
			for c in row:
				if not c is String or not c in ["#",".","k","D","h","a","d","s","g","B","<",">"]: return false
	if d.floor < 0 or d.floor > 2 or d.x < 1 or d.x > 9 or d.y < 1 or d.y > 9 or d.hp <= 0 or d.atk <= 0 or d.def < 0 or d.keys < 0: return false
	if d.floors[int(d.floor)][int(d.y)][int(d.x)] == "#": return false
	floors = d.floors.duplicate(true)
	floor_index = int(d.floor)
	pos = Vector2i(int(d.x),int(d.y))
	hp=int(d.hp); atk=int(d.atk); defense=int(d.def); keys=int(d.keys); gold=int(d.gold); moves=int(d.moves)
	won = d.get("won",false) == true
	message = "Your journey resumes."
	return true
