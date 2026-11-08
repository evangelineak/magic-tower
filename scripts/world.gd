class_name TowerWorld
extends RefCounted

const MAPS = [
["###########","#@.k..#..a#","#.M#..#...#","#h.#s.D.s.#","#..#..#...#","#..a..#h..#","#.###.###.#","#...s...k.#","#d..#..s..#","#...#....>#","###########"],
["###########","#<....#..a#","#.##s.#...#","#k.#..D.g.#","#.C#..#...#","#h.d..#h..#","#.###.###.#","#...g...k.#","#a..#..s..#","#...#....>#","###########"],
["###########","#<.hE.#..a#","#..#g.#..##","#k.#..D.VT#","#..#..#..##","#..a..#h..#","#.###.###.#","#...g...k.#","#d..#..g..#","#...#....>#","###########"],
["###########","#<.a..#..a#","#..#g.#...#","#N.#..D.g.#","#..#..#...#","#h.F..#h..#","#.###.###.#","#...g...k.#","#a..#..g..#","#...#....>#","###########"],
["###########","#<.a..#..a#","#..#g.#...#","#Q.#..D.K.#","#..#..#...#","#h.a..#h..#","#.###.###.#","#...g...k.#","#d..#..g..#","#...#.....#","###########"]]
const ENEMIES = {
"s": {"name":"Mossling", "hp":35, "atk":14, "def":3, "gold":8},
"g": {"name":"Sentinel", "hp":75, "atk":25, "def":10, "gold":18},
"V": {"name":"Vault Colossus", "hp":180, "atk":100, "def":65, "gold":30},
"K": {"name":"Astral Regent", "hp":450, "atk":65, "def":40, "gold":100},
"B": {"name":"Hollow King", "hp":220, "atk":42, "def":20, "gold":100}}
var core := false
var core_use := ""
var weapon := false
var secret := false
var clue := false
var principal := 0
var fees := 0
var interest := 0
var loan_used := false
var overdue := false
var checkpoints := 0
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
	floors[0][5][2] = "E"
func tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= 11 or p.y >= 11: return "#"
	return floors[floor_index][p.y][p.x]
func damage(kind: String) -> int:
	var e: Dictionary = ENEMIES[kind]
	var hit: int = atk - e.def
	if hit <= 0: return -1
	return maxi(0, ceili(float(e.hp) / hit) - 1) * maxi(0, e.atk - defense)
func step(direction: Vector2i) -> bool:
	if won or absi(direction.x)+absi(direction.y)!=1: return false
	var target := pos + direction
	var t := tile(target)
	if t == "#": return false
	if (t == ">" and floor_index >= MAPS.size()-1) or (t == "<" and floor_index == 0): return false
	if t == "D" and keys == 0:
		message = "Locked. A gold key is needed."
		return false
	if ENEMIES.has(t):
		var cost := damage(t)
		if cost < 0 or cost >= hp:
			message = "Too dangerous. Find more crystals first."
			return false
		hp -= cost
		gain_gold(ENEMIES[t].gold)
		message = "%s defeated. -%d HP" % [ENEMIES[t].name, cost]
		if t == "K": won = true
	elif t == "C":
		core = true
		message = "Core: repair lift / forge +8 DEF / sell for 35. Choose once."
	elif t == "T":
		atk += 10
		gain_gold(45)
		message = "Star vault: +10 ATK and 45 gold. Worth returning for!"
	elif t == "N":
		clue = true
		message = "The silent bell opens when the old lift runs. Seek it above."
	elif t in ["M","E","F","Q"]:
		message = "Press E to inspect choices. Nothing is spent until you choose."
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
		if floor_index >= 3: settle_checkpoint(floor_index - 2)
		pos = Vector2i(1,1)
		message = "Floor %d. Debt %d. Interest settles only on first entry to floors 4 / 5." % [floor_index + 1, debt()]
	elif t == "<":
		floor_index -= 1
		pos = Vector2i(9,9)
		message = "Backtracking is wisdom, not defeat."
	elif not t in [".","M","E","F","N","Q"]: floors[floor_index][target.y][target.x] = "."
	return true
func debt() -> int:
	return principal + fees + interest
func nearby(token: String) -> bool:
	for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if tile(pos+d)==token: return true
	return false
func pay(amount: int):
	var paid := mini(amount, debt())
	gold -= paid
	var part := mini(paid, fees)
	fees -= part; paid -= part
	part = mini(paid, interest)
	interest -= part; paid -= part
	principal -= paid
	if debt()==0: overdue=false
func gain_gold(amount: int):
	gold += amount
	if overdue: pay(amount)
func settle_checkpoint(number: int):
	if number <= checkpoints: return
	for n in range(checkpoints+1, number+1):
		if principal>0: interest += ceili(principal*0.1)
	checkpoints=number
	if checkpoints>=2 and debt()>0: overdue=true
func action(id: String) -> bool:
	if won: return false
	match id:
		"borrow":
			if not nearby("M") or loan_used or checkpoints>0: return false
			principal=40; fees=2; loan_used=true; gold+=40
			message="Borrowed 40. Fee 2; max 50 due at floor 5. No real money."
		"repay":
			if gold<=0 or debt()==0: return false
			pay(gold)
			message="Payment applied: fee, interest, then principal. Debt %d." % debt()
		"buy":
			if not nearby("M") or weapon or gold<60: return false
			gold-=60; atk+=12; weapon=true
			message="Piercer purchased: +12 ATK. No resale."
		"sell_core":
			if not nearby("M") or not core: return false
			core=false; core_use="sold"; gain_gold(35)
			message="Core sold. Lift and forge are now unavailable this run."
		"elevator":
			if not nearby("E") or not core: return false
			core=false; core_use="elevator"
			message="Lift repaired: floors 1 / 3 linked. Forge and sale forgone."
		"forge":
			if not nearby("F") or not core: return false
			core=false; core_use="forge"; defense+=8
			message="Core forged into +8 DEF. Lift and sale forgone."
		"travel":
			if not nearby("E") or core_use!="elevator": return false
			floor_index=2 if floor_index==0 else 0
			pos=Vector2i(4,1) if floor_index==2 else Vector2i(2,5)
			message="The old lift remembers. No interest on revisits."
		"secret":
			if not nearby("Q") or not clue or core_use!="elevator" or secret: return false
			secret=true; hp+=80
			message="The bell rings! A forgotten traveler left +80 HP."
		_: return false
	moves+=1
	return true
func save_data() -> Dictionary:
	return {"version":2,"floors":floors,"floor":floor_index,"x":pos.x,"y":pos.y,"hp":hp,"atk":atk,"def":defense,"keys":keys,"gold":gold,"won":won,"moves":moves,
	"core":core,"core_use":core_use,"weapon":weapon,"secret":secret,"clue":clue,"principal":principal,"fees":fees,"interest":interest,"loan_used":loan_used,"overdue":overdue,"checkpoints":checkpoints}
func restore(d: Dictionary) -> bool:
	if d.get("version") != 2: return false
	for key in ["floor","x","y","hp","atk","def","keys","gold","moves","principal","fees","interest","checkpoints"]:
		if not d.has(key) or not (d[key] is float or d[key] is int): return false
		if not is_finite(float(d[key])) or float(d[key])!=floor(float(d[key])) or d[key]<0 or d[key]>1000000: return false
	for key in ["core","weapon","secret","clue","loan_used","overdue","won"]:
		if not d.get(key) is bool: return false
	if not d.get("core_use") in ["","sold","forge","elevator"]: return false
	if d.core and d.core_use!="": return false
	if d.principal>40 or d.fees>2 or d.interest>8 or d.checkpoints>2: return false
	var balance: int = int(d.principal+d.fees+d.interest)
	if not d.loan_used and balance>0: return false
	if d.overdue != (d.checkpoints==2 and balance>0): return false
	if d.secret and (not d.clue or d.core_use!="elevator"): return false
	if not d.get("floors") is Array or d.floors.size()!=MAPS.size(): return false
	var cores_remaining := 0
	for grid in d.floors:
		if not grid is Array or grid.size()!=11: return false
		for row in grid:
			if not row is Array or row.size()!=11: return false
			for c in row:
				if c=="C": cores_remaining+=1
				if not c is String or not c in ["#",".","k","D","h","a","d","s","g","B","K","V","T","M","C","E","F","N","Q","<",">"]: return false
	if cores_remaining>1 or (cores_remaining>0 and (d.core or d.core_use!="")): return false
	if d.floor >= MAPS.size() or d.x < 1 or d.x > 9 or d.y < 1 or d.y > 9 or d.hp <= 0 or d.atk <= 0: return false
	if d.floors[int(d.floor)][int(d.y)][int(d.x)] == "#": return false
	floors = d.floors.duplicate(true)
	floor_index = int(d.floor)
	pos = Vector2i(int(d.x),int(d.y))
	hp=int(d.hp); atk=int(d.atk); defense=int(d.def); keys=int(d.keys); gold=int(d.gold); moves=int(d.moves)
	core=d.core; core_use=d.core_use; weapon=d.weapon; secret=d.secret; clue=d.clue
	principal=int(d.principal); fees=int(d.fees); interest=int(d.interest); loan_used=d.loan_used; overdue=d.overdue; checkpoints=int(d.checkpoints)
	won = d.won
	message = "Your journey resumes."
	return true
