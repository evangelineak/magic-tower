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
	var w = World.new()
	check(not w.step(Vector2i.LEFT),"wall blocks")
	check(w.pos==Vector2i(1,1),"wall preserves position")
	check(w.damage("s")==12,"first-strike damage formula")
	w.atk=3
	check(w.damage("s")==-1,"zero damage impossible")
	w=World.new()
	w.pos=Vector2i(5,3)
	check(not w.step(Vector2i.RIGHT),"keyless door blocks")
	w.keys=1
	check(w.step(Vector2i.RIGHT) and w.keys==0,"door consumes one key")
	w=World.new(); w.hp=12; w.pos=Vector2i(5,3)
	check(not w.step(Vector2i.LEFT) and w.hp==12,"lethal combat blocked")
	w=World.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.save_data()))
	check(w.restore(data),"JSON save roundtrip")
	data.x=99
	check(not w.restore(data) and w.pos==Vector2i(1,1),"invalid save rejected atomically")
	check(not w.restore({"version":1}),"incomplete save rejected")
	w=World.new()
	var route := ""
	for floor_num in range(3):
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
		var target := Vector2i(9,9) if floor_num<2 else Vector2i(8,3)
		var path := find_path(w,target)
		check(not path.is_empty(),"goal reachable on floor %d"%floor_num)
		for direction in path:
			check(w.step(direction),"goal step legal")
			route += direction_name(direction)
		check(w.floor_index==mini(floor_num+1,2),"stairs transition")
	check(w.won,"all three floors can be won")
	check(w.hp>0,"winning route survives")
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
			if t=="#" or (t in ["<",">"] and n!=goal) or (t=="B" and n!=goal): continue
			if t=="D": continue # safe route does not require optional doors
			if World.ENEMIES.has(t) and (w.damage(t)<0 or w.damage(t)>=w.hp): continue
			visited[n]=true
			var next: Array=item[1].duplicate(); next.append(d)
			queue.append([n,next])
	return []
