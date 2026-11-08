extends SceneTree
const World = preload("res://scripts/world.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func _init():
	var w = World.new(0)
	check(not w.step(Vector2i.LEFT),"wall blocks")
	check(w.pos==Vector2i(1,1),"wall preserves position")
	check(w.damage("s")==12,"first-strike damage formula")
	w.atk=3
	check(w.damage("s")==-1,"zero damage impossible")
	w=World.new(0)
	w.pos=Vector2i(5,3)
	check(not w.step(Vector2i.RIGHT),"keyless door blocks")
	w.keys=1
	check(w.step(Vector2i.RIGHT) and w.keys==0,"door consumes one key")
	w=World.new(0); w.hp=12; w.pos=Vector2i(5,3)
	check(not w.step(Vector2i.LEFT) and w.hp==12,"lethal combat blocked")
	w=World.new(0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.save_data()))
	check(w.restore(data),"JSON save roundtrip")
	data.x=99
	check(not w.restore(data) and w.pos==Vector2i(1,1),"invalid save rejected atomically")
	check(not w.restore({"version":1}),"incomplete save rejected")
	w=World.new(0)
	var route := ""
	var before_boss: Dictionary = {}
	for floor_num in range(World.MAPS.size()):
		if floor_num==1:
			for direction in find_path(w,Vector2i(1,4)):
				check(w.step(direction),"reach water valve")
				route += direction_name(direction)
			check(w.action("drain"),"choose drainage instead of spring to reach optional growth")
		# Collect all safe items/enemies, prioritizing stat upgrades and potions.
		for pass_num in range(60):
			var best: Array = []
			var best_score := 10000
			for y in range(1,10):
				for x in range(1,10):
					var t: String=w.tile(Vector2i(x,y))
					if not t in ["a","d","h","k","s","g"]: continue
					var path := find_path(w,Vector2i(x,y))
					if path.is_empty(): continue
					var score: int=path.size() + (30 if t in ["s","g"] else 0)
					if score<best_score: best=path; best_score=score
			if best.is_empty(): break
			for direction in best:
				check(w.step(direction),"solver step legal")
				route += direction_name(direction)
		if floor_num==2: check(w.damage("V")==-1,"floor 3 vault cannot be brute-forced on first visit")
		if floor_num==4: before_boss=w.save_data().duplicate(true)
		var target := Vector2i(9,9) if floor_num<World.MAPS.size()-1 else Vector2i(8,3)
		var path := find_path(w,target)
		check(not path.is_empty(),"goal reachable on floor %d"%floor_num)
		for direction in path:
			check(w.step(direction),"goal step legal")
			route += direction_name(direction)
		check(w.floor_index==mini(floor_num+1,World.MAPS.size()-1),"stairs transition")
	check(w.won,"all five floors can be won")
	check(w.hp>0,"winning route survives")
	check(not w.loan_used and w.debt()==0,"baseline wins with no borrowing")
	var return_world = World.new(0)
	check(return_world.restore(before_boss),"restore later-growth state")
	# A late optional boss requires a build, not merely vacuuming floor loot.
	# Walk all the way back to the real merchant and pay with earned gold.
	for i in range(4):
		var path := find_path(return_world,Vector2i(1,1))
		check(not path.is_empty(),"merchant return stairs reachable")
		for direction in path: check(return_world.step(direction),"merchant return step legal")
	for direction in find_path(return_world,Vector2i(2,2)):
		check(return_world.step(direction),"walk to merchant")
	check(return_world.action("buy"),"earned gold buys real weapon for optional vault build")
	for talent in ["keen_edge","trained_focus","giant_slayer"]:
		check(return_world.action("talent_"+talent),"actual kills unlock build talent: "+talent)
	for i in range(2):
		var path := find_path(return_world,Vector2i(9,9))
		check(not path.is_empty(),"vault return stairs reachable")
		for direction in path: check(return_world.step(direction),"vault return step legal")
	check(return_world.action("arm"),"remaining legitimate focus prepares vault skill")
	check(return_world.floor_index==2,"returned to floor 3 after growth")
	check(return_world.damage("V")>0 and return_world.damage("V")<return_world.hp,"late vault now beatable")
	for goal in [Vector2i(8,3),Vector2i(9,3)]:
		var path := find_path(return_world,goal)
		check(not path.is_empty(),"vault goal reachable")
		for direction in path: check(return_world.step(direction),"vault approach legal")
	check(return_world.tile(Vector2i(9,3))==".","guarded treasure actually collected on revisit")
	if failures > 0:
		quit(1)
		return
	print("PASS: %d checks; winning route %d moves; HP=%d ATK=%d DEF=%d GOLD=%d" % [checks,w.moves,w.hp,w.atk,w.defense,w.gold])
	print("ROUTE: "+route)
	quit(0)
func direction_name(d: Vector2i) -> String:
	if d==Vector2i.UP: return "U"
	if d==Vector2i.DOWN: return "D"
	if d==Vector2i.LEFT: return "L"
	return "R"
func find_path(w, goal: Vector2i) -> Array:
	var queue: Array = [[w.pos,[]]]
	var visited := {w.pos:true}
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var p: Vector2i=item[0]
		if p==goal: return item[1]
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n: Vector2i=p+d
			if visited.has(n): continue
			var t: String=w.tile(n)
			if t=="#" or (t=="~" and w.water_choice!="drain") or (t in ["<",">"] and n!=goal) or (t in ["B","K","V"] and n!=goal): continue
			if t in ["D","L"]: continue # safe route does not require optional doors
			if World.ENEMIES.has(t) and (w.damage(t)<0 or w.damage(t)>=w.hp): continue
			visited[n]=true
			var next: Array=item[1].duplicate(); next.append(d)
			queue.append([n,next])
	return []
