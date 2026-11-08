class_name TowerWorld
extends RefCounted
const Generator = preload("res://scripts/generation.gd")
const Progression = preload("res://scripts/progression.gd")

const MAPS = [
["###########","#@.k..#..a#","#JM#..#...#","#h.#s.D.s.#","#..#..#...#","#..a..#h..#","#.###.###.#","#...s...k.#","#d..#..s..#","#...#....>#","###########"],
["###########","#<....#.Ra#","#.##s.#~~~#","#k.#..D.b.#","#OC#..#...#","#h.d..#h..#","#.###.###.#","#...g...k.#","#a..#..s..#","#...#....>#","###########"],
["###########","#<.hE.#..a#","#..#g.#..##","#k.#..D.VT#","#..#..#..##","#..a..#h..#","#.###.###.#","#...g...k.#","#dI.#..g..#","#...#....>#","###########"],
["###########","#<.a..#..a#","#..#g.#...#","#N.#..D.g.#","#.X#..#...#","#h.F..#h..#","#.###.###.#","#...u...k.#","#a..#..g..#","#...#....>#","###########"],
["###########","#<.a..#..a#","#..#g.#...#","#Q.#..D.K.#","#..#..#...#","#h.a..#h..#","#.###.###.#","#...g...k.#","#d..#..g..#","#...#.....#","###########"]]
const ENEMIES = {
"s": {"name":"Mossling", "hp":35, "atk":14, "def":3, "gold":8},
"g": {"name":"Sentinel", "hp":75, "atk":25, "def":10, "gold":18},
"u": {"name":"Veil Stalker", "hp":40, "atk":20, "def":4, "gold":12, "first_strike":true},
"b": {"name":"Briar Sentinel", "hp":70, "atk":22, "def":8, "gold":16, "thorns":2},
"V": {"name":"Vault Colossus", "hp":180, "atk":100, "def":65, "gold":30},
"K": {"name":"Astral Regent", "hp":450, "atk":65, "def":40, "gold":100},
"B": {"name":"Hollow King", "hp":220, "atk":42, "def":20, "gold":100}}
var seed_value := 0
var generation_attempts := 0
var generation_fallback := false
var generation_valid := true
var hero_id := "warden"
var focus := 2
var focus_cap := 3
var skill_armed := false
var equipped := "balanced"
var inventory: Array = ["balanced"]
var talents: Array = []
var kills := 0
var floor_seen: Array = [true,false,false,false,false]
var quest_state := 0
var event_done := false
var event_kind := "bargain"
var water_choice := ""
var chest_claimed := false
var last_battle: Dictionary = {}
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
func _init(run_seed: int = 0):
	seed_value=clampi(run_seed,0,2147483647)
	event_kind=["bargain","smuggler","oath"][seed_value%3]
	var generated: Dictionary = Generator.generate(seed_value, MAPS)
	floors=generated.maps
	generation_attempts=generated.attempts
	generation_fallback=generated.fallback
	generation_valid=bool(generated.validation.solvable)
	if not generation_valid: message="Map validation failed. This run is blocked; choose another seed."
func tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= 11 or p.y >= 11: return "#"
	return floors[floor_index][p.y][p.x]
func battle_preview(kind: String) -> Dictionary:
	return Progression.battle(atk,defense,hp,ENEMIES[kind],hero_id,skill_armed and focus>0,equipped,talents)
func damage(kind: String) -> int:
	var preview := battle_preview(kind)
	return int(preview.damage) if preview.valid else -1
func enter_floor(number: int):
	floor_index=number
	if not floor_seen[number]:
		floor_seen[number]=true
		focus=mini(focus_cap,focus+1)
func step(direction: Vector2i) -> bool:
	if not generation_valid or won or absi(direction.x)+absi(direction.y)!=1: return false
	var target := pos + direction
	var t := tile(target)
	if t == "#": return false
	if t == "~" and water_choice!="drain":
		message="Flooded. The valve offers a route or healing, not both."
		return false
	if (t == ">" and floor_index >= MAPS.size()-1) or (t == "<" and floor_index == 0): return false
	if t == "D" and keys == 0:
		message = "Locked. A gold key is needed."
		return false
	if ENEMIES.has(t):
		var cost := damage(t)
		if cost < 0 or cost >= hp:
			message = "Too dangerous. Find more crystals first."
			return false
		last_battle=battle_preview(t).duplicate(true)
		last_battle["enemy"]=t
		hp -= cost
		hp += int(last_battle.heal_after)
		if last_battle.skill_consumed:
			focus-=1
			skill_armed=false
		kills+=1
		gain_gold(ENEMIES[t].gold)
		message = "%s defeated. -%d HP" % [ENEMIES[t].name, cost]
		if t == "K": won = true
	elif t == "I":
		quest_state=2
		message="Recovered survey: return to the cartographer on floor 1."
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
	elif t in ["M","E","F","Q","J","O","R","X"]:
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
		enter_floor(floor_index+1)
		if floor_index >= 3: settle_checkpoint(floor_index - 2)
		pos = Vector2i(1,1)
		message = "Floor %d. Debt %d. Interest settles only on first entry to floors 4 / 5." % [floor_index + 1, debt()]
	elif t == "<":
		floor_index -= 1
		pos = Vector2i(9,9)
		message = "Backtracking is wisdom, not defeat."
	elif not t in [".","M","E","F","N","Q","J","O","R","X","~"]: floors[floor_index][target.y][target.x] = "."
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
func event_title() -> String:
	return {"bargain":"The tower keeper", "smuggler":"The locked-road smuggler", "oath":"The well of resolve"}[event_kind]
func event_offers() -> Array:
	match event_kind:
		"smuggler": return [["smuggler_sell","Trade 1 gold key for 45 gold / one offer only"],["smuggler_buy","Pay 30 gold for 2 keys / one offer only"],["bargain_leave","Decline this encounter permanently"]]
		"oath": return [["oath_power","Surrender ALL focus (at least 2) for +7 ATK"],["oath_renew","Pay 60 HP to restore 2 focus (up to capacity)"],["bargain_leave","Decline this encounter permanently"]]
	return [["bargain_blood","Blood bargain: pay 80 HP / gain +6 ATK"],["bargain_gold","Ward bargain: pay 25 gold / gain +5 DEF"],["bargain_leave","Decline this encounter permanently"]]
func action(id: String) -> bool:
	if not generation_valid or won: return false
	if id.begins_with("hero_"):
		var choice:=id.trim_prefix("hero_")
		if moves!=0 or not Progression.HEROES.has(choice): return false
		hero_id=choice
		message="%s chosen. Every hero can clear the main route." % Progression.HEROES[choice].name
		moves+=1
		return true
	if id.begins_with("equip_"):
		var choice:=id.trim_prefix("equip_")
		if not choice in inventory or choice==equipped: return false
		equipped=choice
		message="Equipment changed. Scout the new battle forecast."
		moves+=1
		return true
	if id.begins_with("talent_"):
		var choice:=id.trim_prefix("talent_")
		if not choice in Progression.talent_options(kills,talents): return false
		talents.append(choice)
		message="Talent learned: %s" % Progression.TALENTS[choice].name
		moves+=1
		return true
	match id:
		"arm":
			if hero_id=="scholar" or focus<=0: return false
			skill_armed=not skill_armed
			message="Next battle skill %s. Preview includes its effect." % ("armed" if skill_armed else "off")
		"mend":
			if hero_id!="scholar" or focus<=0: return false
			focus-=1; hp+=Progression.mend_heal(talents)
			message="Focus spent to mend. Charges return only on new floors."
		"quest_accept":
			if not nearby("J") or quest_state!=0: return false
			quest_state=1
			message="Find the lost survey on floor 3. Return for one of two rewards."
		"quest_gold","quest_scroll":
			if not nearby("J") or quest_state!=2: return false
			quest_state=3
			if id=="quest_gold":
				gain_gold(45)
				message="Survey delivered: 45 gold. The focus training is forgone."
			else:
				focus_cap=4; focus=4
				message="Survey delivered: focus capacity 4 and full refill. Gold forgone."
		"drain","spring":
			if not nearby("O") or water_choice!="": return false
			water_choice=id
			if id=="spring": hp+=120
			message="Water drained: north relic vault accessible; healing forgone." if id=="drain" else "Spring consumed: +120 HP. Northern vault stays flooded."
		"relic_buckler","relic_duelist":
			if not nearby("R") or chest_claimed: return false
			var choice:=id.trim_prefix("relic_")
			chest_claimed=true; inventory.append(choice); equipped=choice
			message="Relic chosen: %s. The other relic is sealed away." % Progression.GEAR[choice].name
		"smuggler_sell","smuggler_buy":
			if not nearby("X") or event_done or event_kind!="smuggler": return false
			if id=="smuggler_sell":
				if keys<1: return false
				keys-=1; gain_gold(45)
			else:
				if gold<30: return false
				gold-=30; keys+=2
			event_done=true
			message="The smuggler departs. The other offer is gone."
		"oath_power","oath_renew":
			if not nearby("X") or event_done or event_kind!="oath": return false
			if id=="oath_power":
				if focus<2: return false
				focus=0; skill_armed=false; atk+=7
			else:
				if hp<=60 or focus>=focus_cap: return false
				hp-=60; focus=mini(focus_cap,focus+2)
			event_done=true
			message="The well falls silent. Your exchange cannot be repeated."
		"bargain_blood","bargain_gold","bargain_leave":
			if not nearby("X") or event_done: return false
			if id!="bargain_leave" and event_kind!="bargain": return false
			if id=="bargain_blood":
				if hp<=80: return false
				hp-=80; atk+=6
			elif id=="bargain_gold":
				if gold<25: return false
				gold-=25; defense+=5
			event_done=true
			message="The keeper accepts your choice. This offer will not return."
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
			enter_floor(2 if floor_index==0 else 0)
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
	return {"version":3,"floors":floors,"floor":floor_index,"x":pos.x,"y":pos.y,"hp":hp,"atk":atk,"def":defense,"keys":keys,"gold":gold,"won":won,"moves":moves,
	"seed_value":seed_value,"generation_attempts":generation_attempts,"generation_fallback":generation_fallback,
	"hero_id":hero_id,"focus":focus,"focus_cap":focus_cap,"skill_armed":skill_armed,"equipped":equipped,"inventory":inventory,"talents":talents,"kills":kills,"floor_seen":floor_seen,
	"quest_state":quest_state,"event_done":event_done,"event_kind":event_kind,"water_choice":water_choice,"chest_claimed":chest_claimed,
	"core":core,"core_use":core_use,"weapon":weapon,"secret":secret,"clue":clue,"principal":principal,"fees":fees,"interest":interest,"loan_used":loan_used,"overdue":overdue,"checkpoints":checkpoints}
func restore(d: Dictionary) -> bool:
	if d.get("version") != 3: return false
	for key in ["floor","x","y","hp","atk","def","keys","gold","moves","principal","fees","interest","checkpoints","generation_attempts","focus","focus_cap","kills","quest_state"]:
		if not d.has(key) or not (d[key] is float or d[key] is int): return false
		if not is_finite(float(d[key])) or float(d[key])!=floor(float(d[key])) or d[key]<0 or d[key]>1000000: return false
	for key in ["core","weapon","secret","clue","loan_used","overdue","won","generation_fallback","skill_armed","event_done","chest_claimed"]:
		if not d.get(key) is bool: return false
	if not (d.get("seed_value") is int or d.get("seed_value") is float): return false
	if not is_finite(float(d.seed_value)) or d.seed_value<0 or d.seed_value>2147483647 or d.seed_value!=floor(d.seed_value): return false
	if d.get("event_kind") != ["bargain","smuggler","oath"][int(d.seed_value)%3]: return false
	if not d.get("hero_id") is String or not Progression.HEROES.has(d.hero_id): return false
	if not d.get("equipped") is String or not Progression.GEAR.has(d.equipped): return false
	if not d.get("inventory") is Array or d.inventory.size()<1 or d.inventory.size()>2: return false
	var unique_gear: Dictionary={}
	for gear in d.inventory:
		if not gear is String or not Progression.GEAR.has(gear) or unique_gear.has(gear): return false
		unique_gear[gear]=true
	if not "balanced" in d.inventory or not d.equipped in d.inventory: return false
	if d.chest_claimed!=(d.inventory.size()==2): return false
	if not d.get("talents") is Array or not Progression.valid_talents(d.talents): return false
	if d.talents.size()>0 and d.kills<3: return false
	if d.talents.size()>1 and d.kills<7: return false
	if d.talents.size()>2 and d.kills<12: return false
	if not d.get("floor_seen") is Array or d.floor_seen.size()!=5: return false
	for seen in d.floor_seen:
		if not seen is bool: return false
	if not d.floor_seen[0]: return false
	if not d.get("water_choice") in ["","drain","spring"]: return false
	if int(d.focus_cap) not in [3,4] or d.focus>d.focus_cap or d.quest_state>3: return false
	if d.hero_id=="scholar" and d.skill_armed: return false
	if d.generation_attempts>16: return false
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
				if not c is String or not c in ["#",".","k","D","h","a","d","s","g","u","b","B","K","V","T","M","C","E","F","N","Q","J","I","O","R","X","~","<",">"]: return false
	if cores_remaining>1 or (cores_remaining>0 and (d.core or d.core_use!="")): return false
	if d.floor >= MAPS.size() or d.x < 1 or d.x > 9 or d.y < 1 or d.y > 9 or d.hp <= 0 or d.atk <= 0: return false
	if d.floors[int(d.floor)][int(d.y)][int(d.x)] == "#": return false
	if not d.floor_seen[int(d.floor)]: return false
	seed_value=int(d.seed_value); generation_attempts=int(d.generation_attempts); generation_fallback=d.generation_fallback
	hero_id=d.hero_id; focus=int(d.focus); focus_cap=int(d.focus_cap); skill_armed=d.skill_armed
	equipped=d.equipped; inventory=d.inventory.duplicate(); talents=d.talents.duplicate(); kills=int(d.kills); floor_seen=d.floor_seen.duplicate()
	quest_state=int(d.quest_state); event_done=d.event_done; event_kind=d.event_kind; water_choice=d.water_choice; chest_claimed=d.chest_claimed
	last_battle={}
	floors = d.floors.duplicate(true)
	floor_index = int(d.floor)
	pos = Vector2i(int(d.x),int(d.y))
	hp=int(d.hp); atk=int(d.atk); defense=int(d.def); keys=int(d.keys); gold=int(d.gold); moves=int(d.moves)
	core=d.core; core_use=d.core_use; weapon=d.weapon; secret=d.secret; clue=d.clue
	principal=int(d.principal); fees=int(d.fees); interest=int(d.interest); loan_used=d.loan_used; overdue=d.overdue; checkpoints=int(d.checkpoints)
	won = d.won
	message = "Your journey resumes."
	return true
