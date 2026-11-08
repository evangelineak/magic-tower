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
func geometry_key(maps: Array) -> String:
	var key := ""
	for grid in maps:
		for row in grid:
			for token in row: key+="#" if token=="#" else "."
	return key
func graph_distances(grid: Array, excluded:=Vector2i(-1,-1)) -> Dictionary:
	var start := Vector2i(1,1)
	var distances := {start:0}
	var queue: Array=[start]
	var head := 0
	while head<queue.size():
		var p: Vector2i=queue[head]; head+=1
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n: Vector2i=p+d
			if n.x<0 or n.x>10 or n.y<0 or n.y>10 or n==excluded or distances.has(n): continue
			if grid[n.y][n.x] in ["#","D","L","~","V"]: continue
			distances[n]=distances[p]+1; queue.append(n)
	return distances
func wet_loot_budget(grid: Array) -> Dictionary:
	var closed := Generator.reachable(grid,["#","D","L","~","V","K"])
	var drained := Generator.reachable(grid,["#","D","L","V","K"])
	var budget := {}
	for y in range(1,10):
		for x in range(1,10):
			if grid[y][x] not in Generator.LOOT: continue
			var p := Vector2i(x,y)
			if not closed.has(p):
				check(drained.has(p),"ordinary loot is not lost behind a cage, boss or disconnected wall")
				var token: String=grid[y][x]
				budget[token]=budget.get(token,0)+1
	return budget
func _init():
	var suite_started := Time.get_ticks_usec()
	var model = World.new(0)
	check(model.hp==280 and model.atk==18 and model.defense==8,"proof baseline matches World starting stats")
	for enemy_id in Generator.ENEMIES:
		for field in ["hp","atk","def"]:
			check(Generator.ENEMIES[enemy_id][field]==World.ENEMIES[enemy_id][field],"proof enemy stats match World: %s.%s"%[enemy_id,field])
		for field in ["first_strike","thorns","heavy_every"]:
			var default_value = false if field=="first_strike" else 0
			check(Generator.ENEMIES[enemy_id].get(field,default_value)==World.ENEMIES[enemy_id].get(field,default_value),"proof enemy trait matches World: %s.%s"%[enemy_id,field])
	for enemy_id in World.ENEMIES:
		if enemy_id not in ["B","V","Z","H"]: check(Generator.ENEMIES.has(enemy_id),"proof includes each non-optional enemy")
	check(Generator.damage("w",{"hp":500,"atk":38,"def":8})==288,"proof includes every-third-retaliation heavy damage")
	var baseline := Generator.normalize(World.MAPS)
	var zero := Generator.generate(0,World.MAPS)
	check(zero.maps==baseline,"seed zero keeps authored baseline")
	check(zero.validation.solvable,"authored baseline has conservative proof")
	check(zero.attempts==0 and not zero.fallback,"seed zero bypasses random generation")
	check(zero.floor_skeletons==["authored","authored","authored","authored","authored"],"seed zero labels all floors authored")
	check(zero.geometry_revision==2,"whole-floor geometry revision is explicit")
	check(Generator.build_skeleton(baseline[0],"missing").is_empty(),"unknown skeleton is rejected")
	# Verify all 15 overlay combinations before any seed can select them. The
	# tests use an independent graph traversal, not just skeleton_valid().
	for floor_index in baseline.size():
		var goal := Vector2i(8,3) if floor_index==4 else Vector2i(9,9)
		var signatures := {}
		for id in Generator.SKELETONS:
			var grid := Generator.build_skeleton(baseline[floor_index],id)
			signatures[geometry_key([grid])]=true
			check(Generator.topology([grid]).valid,"each whole-floor mask preserves gate topology")
			check(Generator.skeleton_valid(grid,id,floor_index),"mask retains its semantic route identity")
			var graph := graph_distances(grid)
			check(graph.has(goal),"every skeleton has a geometric entry-to-goal route")
			if id=="ring":
				for p in graph:
					if p not in [Vector2i(1,1),goal]: check(graph_distances(grid,p).has(goal),"ring has no single internal entry/goal cut vertex")
			elif id=="courtyards": check(not graph_distances(grid,Vector2i(4,5)).has(goal),"courtyards use the central junction")
			elif id=="spine":
				check(grid[5][4]=="#","spine does not reuse courtyard junction")
				check(not graph_distances(grid,Vector2i(2,8)).has(goal),"spine uses the lower turn")
		check(signatures.size()==3,"three different full-floor wall layouts on every floor")
	var original := World.MAPS.duplicate(true)
	var same_a := Generator.generate(834,World.MAPS)
	var same_b := Generator.generate(834,World.MAPS)
	check(same_a==same_b,"same seed reproduces maps, skeleton choices, attempts and witness")
	check(World.MAPS==original,"generator never mutates authored maps")
	var potion_model = World.new(0)
	potion_model.floors[0][1][2]="h"
	var proof_grid: Array=potion_model.floors[0].duplicate(true)
	var proof_stats := {"hp":280,"atk":18,"def":8}
	var potion_proof := Generator.execute(proof_grid,Vector2i(1,1),[Vector2i.RIGHT],proof_stats)
	check(potion_model.step(Vector2i.RIGHT) and potion_model.hp==350,"World potion heals exactly 70")
	check(potion_proof.ok and proof_stats.hp==potion_model.hp,"proof potion healing matches World")
	var unique := {}
	var geometries := {}
	var coverage := {}
	var fallbacks := 0
	var max_attempts := 0
	var minimum_hp := 1000000
	var maximum_hp := 0
	var minimum_moves := 1000000
	var maximum_moves := 0
	var total_generation_usec := 0
	var maximum_generation_usec := 0
	for seed_value in range(1,201):
		var generation_started := Time.get_ticks_usec()
		var result := Generator.generate(seed_value,World.MAPS)
		var elapsed := Time.get_ticks_usec()-generation_started
		total_generation_usec+=elapsed; maximum_generation_usec=maxi(maximum_generation_usec,elapsed)
		unique[JSON.stringify(result.maps)]=true
		geometries[geometry_key(result.maps)]=true
		if result.fallback: fallbacks+=1
		max_attempts=maxi(max_attempts,result.attempts)
		check(result.attempts>=1 and result.attempts<=Generator.MAX_ATTEMPTS,"bounded attempts seed %d"%seed_value)
		check(result.validation.solvable,"accepted candidate has survival witness seed %d"%seed_value)
		check(result.validation.hp>0,"witness survives seed %d"%seed_value)
		check(Generator.validate(result.maps).solvable,"independent validator rerun seed %d"%seed_value)
		check(Generator.topology(result.maps).valid,"specials reachable and gates not bypassed")
		for floor_index in baseline.size():
			var id: String=result.floor_skeletons[floor_index]
			check(id=="authored" or Generator.SKELETONS.has(id),"diagnostic names a real full-floor skeleton")
			var coverage_key := "%d/%s" % [floor_index,id]
			coverage[coverage_key]=coverage.get(coverage_key,0)+1
			var expected: Array=baseline[floor_index] if id=="authored" else Generator.build_skeleton(baseline[floor_index],id)
			check(counts(result.maps[floor_index])==counts(baseline[floor_index]),"per-floor ordinary item/enemy quota preserved")
			check(wet_loot_budget(result.maps[floor_index])==wet_loot_budget(baseline[floor_index]),"exact flooded item categories stay gated, not shifted to main-route growth")
			check(counts(result.maps[floor_index]).get("k",0)==1 and wet_loot_budget(result.maps[floor_index]).get("k",0)==0,"one main key per floor stays outside the flooded reward budget")
			var added_walls := 0
			var removed_walls := 0
			for y in range(11):
				for x in range(11):
					var was: String=baseline[floor_index][y][x]
					var now: String=result.maps[floor_index][y][x]
					if was!="#" and now=="#": added_walls+=1
					if was=="#" and now!="#": removed_walls+=1
					check((now=="#")== (expected[y][x]=="#"),"full-floor geometry matches its selected mask")
					if x==0 or y==0 or x==10 or y==10: check(now==was,"boundary intact")
					elif was not in ["#","."] and was not in Generator.LOOT: check(now==was,"special object and gate remain at their authored position")
			check(id=="authored" or (added_walls>=8 and removed_walls>=6),"full-floor identity is not erased by protected anchors")
			if baseline[floor_index][9][1] in ["$","A","P"]:
				check(result.maps[floor_index][8][1]=="#","cage northern wall preserved")
				check(result.maps[floor_index][9][2]=="L","two-key cage lock stays in place")
		for p in [Vector2i(9,2),Vector2i(9,4),Vector2i(10,3)]: check(result.maps[2][p.y][p.x]=="#","vault wall remains intact")
		check(result.maps[2][3][8]=="V" and result.maps[2][3][9]=="T","vault guard/reward unmoved")
		check(result.maps[1][1][6]=="#","flooded alcove has no western dry bypass")
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
		check(not world.loan_used,"proof requires no borrowing")
		check(not spent_key and not entered_cage,"proof spends no keys and never enters a cage")
		check(world.water_choice=="" and world.talents.is_empty() and world.equipped=="balanced" and not world.skill_armed,"proof uses no draining, talents, specialized gear or armed skill")
		minimum_hp=mini(minimum_hp,world.hp); maximum_hp=maxi(maximum_hp,world.hp)
		minimum_moves=mini(minimum_moves,world.moves); maximum_moves=maxi(maximum_moves,world.moves)
	check(unique.size()>180,"seeds yield different complete item/geometry arrangements")
	# Three fixed skeletons over five floors offer 3^5 geometry combinations;
	# 200 samples need not be 200 unique geometries (ordinary loot varies too).
	check(geometries.size()>100,"many chapter geometry combinations are actually selected")
	for floor_index in 5:
		for id in Generator.SKELETONS: check(coverage.get("%d/%s"%[floor_index,id],0)>0,"every skeleton is accepted on every floor")
	for seed_value in [1,42,199]:
		var actual = World.new(seed_value)
		var expected := Generator.generate(seed_value,World.MAPS)
		check(actual.generation_valid and actual.floors==expected.maps,"World constructor uses requested skeleton seed")
		var encoded: Dictionary=JSON.parse_string(JSON.stringify(actual.save_data()))
		var loaded = World.new(seed_value+1)
		check(loaded.restore(encoded) and loaded.floors==actual.floors and loaded.seed_value==seed_value,"saved whole-floor maps load without rerolling")
	var bypass := baseline.duplicate(true)
	bypass[0][8][1]="."
	check(not Generator.validate(bypass).solvable,"cage-wall bypass rejected")
	bypass=baseline.duplicate(true); bypass[2][4][9]="."
	check(not Generator.validate(bypass).solvable,"vault-wall bypass rejected")
	bypass=baseline.duplicate(true); bypass[1][1][6]="."
	check(not Generator.validate(bypass).solvable,"dry flooded-reward bypass rejected")
	bypass=baseline.duplicate(true); bypass[0][8][1]="D"
	check(not Generator.validate(bypass).solvable,"one-key door cannot bypass a two-key reward cage")
	bypass=baseline.duplicate(true); bypass[2][4][9]="D"
	check(not Generator.validate(bypass).solvable,"one-key door cannot bypass the vault guardian")
	bypass=baseline.duplicate(true); bypass[1][1][6]="D"
	check(not Generator.validate(bypass).solvable,"one-key door cannot bypass the flooded route")
	bypass=baseline.duplicate(true)
	bypass[1][3][2]="#"; bypass[1][4][1]="#"; bypass[1][5][2]="#"
	check(not Generator.validate(bypass).solvable,"disconnected core rejected")
	var impossible := baseline.duplicate(true)
	impossible[4][3][8]="."
	check(not Generator.validate(impossible).solvable,"missing final goal rejected")
	var invalid_fallback := Generator.generate(42,impossible)
	check(invalid_fallback.fallback and invalid_fallback.attempts==Generator.MAX_ATTEMPTS,"invalid candidates terminate in bounded fallback")
	check(not invalid_fallback.validation.solvable,"invalid authored fallback is explicitly invalid")
	impossible=baseline.duplicate(true)
	impossible[0][1][2]="#"; impossible[0][2][1]="#"
	check(not Generator.validate(impossible).solvable,"sealed authored spawn rejected")
	check(not Generator.validate([]).solvable,"malformed map rejected")
	print("GENERATION: %s (%d checks, 200 seeds, %d unique arrangements, %d fallback, max attempts %d)" % ["PASS" if failures==0 else "FAIL",checks,unique.size(),fallbacks,max_attempts])
	print("SKELETONS: %d distinct chapter geometries; coverage %s" % [geometries.size(),JSON.stringify(coverage)])
	print("GENERATION RANGE: HP %d..%d, moves %d..%d; seed 0 HP %d ATK %d DEF %d moves %d" % [minimum_hp,maximum_hp,minimum_moves,maximum_moves,zero.validation.get("hp",-1),zero.validation.get("atk",-1),zero.validation.get("def",-1),zero.validation.get("moves",-1)])
	print("GENERATION TIMING: suite %.2f s; average new map %.2f ms, max %.2f ms" % [float(Time.get_ticks_usec()-suite_started)/1000000.0,float(total_generation_usec)/200000.0,float(maximum_generation_usec)/1000.0])
	quit(0 if failures==0 else 1)
