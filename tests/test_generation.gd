extends SceneTree
const Generator = preload("res://scripts/generation.gd")
const World = preload("res://scripts/world.gd")
var checks := 0
var failures := 0
func check(ok: bool, description: String):
	checks+=1
	if not ok:
		failures+=1
		push_error("Generation: "+description)
func counts(grid: Array) -> Dictionary:
	var result := {}
	for row in grid:
		for token in row:
			if token in Generator.LOOT: result[token]=result.get(token,0)+1
	return result
func _init():
	var model = World.new(0)
	check(model.hp==280 and model.atk==18 and model.defense==8,"proof baseline matches World starting stats")
	for enemy_id in Generator.ENEMIES:
		for field in ["hp","atk","def"]:
			check(Generator.ENEMIES[enemy_id][field]==World.ENEMIES[enemy_id][field],"proof enemy stats match World: %s.%s"%[enemy_id,field])
		check(Generator.ENEMIES[enemy_id].get("first_strike",false)==World.ENEMIES[enemy_id].get("first_strike",false),"proof first-strike trait matches World: "+enemy_id)
		check(Generator.ENEMIES[enemy_id].get("thorns",0)==World.ENEMIES[enemy_id].get("thorns",0),"proof thorns trait matches World: "+enemy_id)
	for enemy_id in World.ENEMIES:
		if enemy_id not in ["B","V"]:
			check(Generator.ENEMIES.has(enemy_id),"proof includes every non-optional World enemy: "+enemy_id)
	var baseline := Generator.normalize(World.MAPS)
	var zero := Generator.generate(0,World.MAPS)
	check(zero.maps==baseline,"seed zero keeps authored baseline")
	check(zero.validation.solvable,"authored baseline has conservative proof")
	check(zero.attempts==0 and not zero.fallback,"seed zero bypasses random generation")
	var original := World.MAPS.duplicate(true)
	var same_a := Generator.generate(834,World.MAPS)
	var same_b := Generator.generate(834,World.MAPS)
	check(same_a==same_b,"same seed reproduces maps, attempts and witness")
	check(World.MAPS==original,"generator never mutates authored maps")
	# Resource values must remain in lockstep with the proof, not only enemies.
	var potion_model = World.new(0)
	potion_model.floors[0][1][2]="h"
	var proof_grid: Array=potion_model.floors[0].duplicate(true)
	var proof_stats := {"hp":280,"atk":18,"def":8}
	var potion_proof := Generator.execute(proof_grid,Vector2i(1,1),[Vector2i.RIGHT],proof_stats)
	check(potion_model.step(Vector2i.RIGHT) and potion_model.hp==350,"World potion heals exactly 70")
	check(potion_proof.ok and proof_stats.hp==potion_model.hp,"proof potion healing matches World")
	var unique := {}
	var fallbacks := 0
	var max_attempts := 0
	var minimum_hp := 1000000
	var maximum_hp := 0
	var minimum_moves := 1000000
	var maximum_moves := 0
	for seed_value in range(1,201):
		var result := Generator.generate(seed_value,World.MAPS)
		unique[JSON.stringify(result.maps)]=true
		if result.fallback: fallbacks+=1
		max_attempts=maxi(max_attempts,result.attempts)
		check(result.attempts>=1 and result.attempts<=Generator.MAX_ATTEMPTS,"bounded attempts seed %d"%seed_value)
		check(result.validation.solvable,"accepted candidate has survival witness seed %d"%seed_value)
		check(result.validation.hp>0,"witness survives seed %d"%seed_value)
		check(Generator.validate(result.maps).solvable,"independent validator rerun seed %d"%seed_value)
		for floor_index in baseline.size():
			check(counts(result.maps[floor_index])==counts(baseline[floor_index]),"per-floor loot/enemy quotas preserved")
			for y in range(11):
				for x in range(11):
					var was: String=baseline[floor_index][y][x]
					var now: String=result.maps[floor_index][y][x]
					if x==0 or y==0 or x==10 or y==10:
						check(now==was,"boundary intact")
					elif not was in Generator.LOOT and was!="#":
						check(now==was,"authored special token/ordinary floor preserved")
					elif was=="#" and now!="#":
						check(Vector2i(x,y) in Generator.SHORTCUTS and now==".","wall changes only approved shortcuts")
		for p in [Vector2i(9,2),Vector2i(9,4),Vector2i(10,3)]:
			check(result.maps[2][p.y][p.x]=="#","vault wall remains intact")
		check(result.maps[2][3][8]=="V" and result.maps[2][3][9]=="T","vault guard/reward unmoved")
		# Replay with actual World rules, not just duplicated arithmetic. This
		# also makes future combat/map changes fail loudly if proof drifts.
		var world = World.new(0)
		world.floors=result.maps.duplicate(true)
		var replay_ok := true
		var spent_key := false
		var entered_cage := false
		for direction in result.validation.route:
			var d: Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[direction]
			var prior_keys: int=world.keys
			if world.tile(world.pos+d) in ["L","$","A","P"]: entered_cage=true
			if not world.step(d): replay_ok=false; break
			if world.keys<prior_keys: spent_key=true
		check(replay_ok and world.won and world.hp>0,"real World replays witness seed %d"%seed_value)
		check(not world.loan_used,"proof does not require borrowing")
		check(not spent_key and not entered_cage,"proof spends no keys and never enters a two-key cage")
		minimum_hp=mini(minimum_hp,world.hp); maximum_hp=maxi(maximum_hp,world.hp)
		minimum_moves=mini(minimum_moves,world.moves); maximum_moves=maxi(maximum_moves,world.moves)
		check(world.water_choice=="" and world.talents.is_empty() and world.equipped=="balanced" and not world.skill_armed,"proof uses no draining, talents, specialized gear or armed skill")
	check(unique.size()>180,"seeds yield materially distinct arrangements")
	var impossible := baseline.duplicate(true)
	impossible[4][3][8]="."
	check(not Generator.validate(impossible).solvable,"missing final goal rejected")
	impossible=baseline.duplicate(true)
	impossible[0][1][2]="#"; impossible[0][2][1]="#"
	check(not Generator.validate(impossible).solvable,"sealed spawn rejected")
	check(not Generator.validate([]).solvable,"malformed map rejected")
	print("GENERATION: %s (%d checks, 200 seeds, %d unique, %d fallback, max attempts %d)" % ["PASS" if failures==0 else "FAIL",checks,unique.size(),fallbacks,max_attempts])
	print("GENERATION RANGE: HP %d..%d, moves %d..%d; seed 0 HP %d ATK %d DEF %d moves %d" % [minimum_hp,maximum_hp,minimum_moves,maximum_moves,zero.validation.get("hp",-1),zero.validation.get("atk",-1),zero.validation.get("def",-1),zero.validation.get("moves",-1)])
	quit(0 if failures==0 else 1)
