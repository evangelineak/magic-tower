extends SceneTree
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func sample_at_forge():
	var w=World.new(0,1)
	w.enter_floor(1); w.pos=Vector2i(1,4); w.step(Vector2i.RIGHT)
	w.enter_floor(2); w.pos=Vector2i(2,7); w.step(Vector2i.DOWN)
	w.enter_floor(3); w.pos=Vector2i(3,5)
	return w
func rejected(w, id: String):
	var before: Dictionary=state(w)
	check(not w.action(id) and state(w)==before,"rejected branch leaves resources and flags unchanged: "+id)
func _init():
	var w=sample_at_forge()
	var before: Dictionary=state(w)
	check(w.quest_state==2 and w.core,"fixture really picked up sample and separate core")
	check(w.action("quest_bridge") and w.bridge_built and w.quest_state==4,"sample can be committed to bridge")
	check(w.hp==before.hp and w.gold==before.gold and w.keys==before.keys and w.core and w.core_use=="" and w.focus==before.focus,"bridge consumes sample only, not core or other resources")
	rejected(w,"quest_bridge")
	w.enter_floor(0); w.pos=Vector2i(1,1)
	rejected(w,"quest_gold"); rejected(w,"quest_scroll")
	check(w.restore(before) and not w.bridge_built and w.quest_state==2 and w.core,"whole-state undo restores sample and removes bridge")
	w.pos=Vector2i(9,9); rejected(w,"quest_bridge")
	w=sample_at_forge(); w.enter_floor(1); w.pos=Vector2i(1,4)
	var hp_before: int=w.hp
	check(w.action("spring") and w.hp==hp_before+120,"spring first gives its exact recovery")
	w.enter_floor(3); w.pos=Vector2i(3,5)
	check(w.action("quest_bridge") and w.water_choice=="spring","bridge remains possible after spring")
	w.enter_floor(1); w.pos=Vector2i(8,3)
	check(w.step(Vector2i.UP),"bridge allows real movement over retained water")
	var loaded=World.new(0,1)
	check(loaded.restore(JSON.parse_string(JSON.stringify(state(w)))) and state(loaded)==state(w),"standing on bridged water survives save/load")
	w=sample_at_forge(); w.action("quest_bridge"); w.enter_floor(1); w.pos=Vector2i(1,4); hp_before=w.hp
	check(w.action("spring") and w.hp==hp_before+120 and w.bridge_built,"bridge first preserves later spring choice")
	rejected(w,"spring"); rejected(w,"drain")
	w=sample_at_forge(); w.enter_floor(1); w.pos=Vector2i(1,4); w.action("drain")
	w.enter_floor(3); w.pos=Vector2i(3,5); rejected(w,"quest_bridge")
	for reward in ["quest_gold","quest_scroll"]:
		w=sample_at_forge(); w.enter_floor(0); w.pos=Vector2i(1,1)
		check(w.action(reward) and w.quest_state==3,"researcher reward remains available: "+reward)
		w.enter_floor(3); w.pos=Vector2i(3,5); rejected(w,"quest_bridge")
	w=World.new(0,1); w.enter_floor(3); w.pos=Vector2i(3,5); rejected(w,"quest_bridge")
	# Old version-four saves must remain loadable without the newly added field.
	w=World.new(0,1)
	var old: Dictionary=state(w); old.version=4; old.erase("bridge_built")
	check(w.restore(old) and not w.bridge_built and w.quest_state==0,"old v4 save without bridge field defaults false")
	var valid: Dictionary=state(w)
	for invalid in [{"bridge_built":true,"quest_state":2},{"bridge_built":false,"quest_state":4},{"bridge_built":true,"quest_state":4,"water_choice":"drain"},{"bridge_built":"yes"}]:
		var bad: Dictionary=valid.duplicate(true)
		bad.merge(invalid,true)
		check(not w.restore(bad) and state(w)==valid,"invalid branch state rejected atomically")
	# Full movement journey: no teleports or injected resources in this portion.
	w=World.new(0,1)
	check(w.action("quest_accept"),"start real research quest")
	for floor_number in range(4):
		if floor_number==1:
			check(walk(w,Vector2i(1,4)) and w.action("spring"),"real route chooses spring before learning bridge")
			check(walk(w,Vector2i(2,4)) and w.core,"real route collects separate core")
		check(collect_safe(w),"collect legal resources on floor %d" % (floor_number+1))
		if floor_number==2:
			check(walk(w,Vector2i(2,8)) and w.quest_state==2,"real route retrieves survey")
		if floor_number<3: check(walk(w,Vector2i(9,9)),"real route ascends")
	check(walk(w,Vector2i(3,5)) and w.action("quest_bridge") and w.core,"real route forges bridge without spending core")
	for i in range(2): check(walk(w,Vector2i(1,1)),"backtrack by stairs to flooded floor")
	check(w.floor_index==1 and walk(w,Vector2i(8,2)),"real revisit crosses bridged water")
	check(w.action("relic_buckler") and w.chest_claimed,"return trip reaches formerly sealed relic")
	check(w.action("equip_balanced"),"restore original equipment for conservative route")
	check(walk(w,Vector2i(9,1)),"claim previously inaccessible ruby")
	for i in range(3): check(walk(w,Vector2i(9,9)),"return from side trip toward final floor")
	check(w.floor_index==4 and collect_safe(w) and walk(w,Vector2i(8,3)) and w.won and w.hp>0,"spring / sample / bridge / relic route genuinely wins")
	check(w.quest_state==4 and w.bridge_built and w.water_choice=="spring" and not w.loan_used,"victory preserves mutually exclusive branch outcome")
	print("BRANCHES: %s (%d checks; real route %d moves, %d HP)" % ["PASS" if failures==0 else "FAIL",checks,w.moves,w.hp])
	quit(0 if failures==0 else 1)
func walk(w, goal: Vector2i) -> bool:
	if w.pos==goal: return true
	var route:=path(w,goal)
	if route.is_empty(): return false
	for direction in route:
		if not w.step(direction): return false
	return true
func collect_safe(w) -> bool:
	for i in range(70):
		var best: Array=[]
		var best_score:=100000
		for y in range(1,10):
			for x in range(1,10):
				var token: String=w.tile(Vector2i(x,y))
				if not token in ["a","d","h","k","s","g"]: continue
				var route:=path(w,Vector2i(x,y))
				if route.is_empty(): continue
				var score: int=route.size()+(30 if token in ["s","g"] else 0)
				if score<best_score: best=route; best_score=score
		if best.is_empty(): return true
		for direction in best:
			if not w.step(direction): return false
	return false
func path(w, goal: Vector2i) -> Array:
	var queue: Array=[[w.pos,[]]]
	var visited: Dictionary={w.pos:true}
	while not queue.is_empty():
		var item: Array=queue.pop_front()
		var p: Vector2i=item[0]
		if p==goal: return item[1]
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n: Vector2i=p+d
			if visited.has(n): continue
			var token: String=w.tile(n)
			if token in ["#","D","L"]: continue
			if token=="~" and w.water_choice!="drain" and not w.bridge_built: continue
			if token in ["<",">","V","K"] and n!=goal: continue
			if World.ENEMIES.has(token) and (w.damage(token)<0 or w.damage(token)>=w.hp): continue
			visited[n]=true
			var route: Array=item[1].duplicate(); route.append(d)
			queue.append([n,route])
	return []
