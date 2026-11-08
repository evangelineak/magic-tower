extends SceneTree
const World=preload("res://scripts/world.gd")
const Riddle=preload("res://scripts/riddle.gd")
var checks:=0
var failures:=0
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func resources(w) -> Array:
	return [w.hp,w.atk,w.defense,w.keys,w.gold,w.focus,w.principal,w.fees,w.interest,w.checkpoints,w.loan_used]
func at_seal():
	var w=World.new(0)
	w.pos=Vector2i(2,1); w.action("seal_contract")
	w.enter_floor(1); w.pos=Vector2i(1,4); w.action("seal_water"); w.step(Vector2i.RIGHT)
	w.enter_floor(2); w.pos=Vector2i(4,1); w.action("elevator")
	w.enter_floor(3); w.pos=Vector2i(1,2); w.step(Vector2i.DOWN)
	w.enter_floor(4); w.pos=Vector2i(1,3)
	return w
func solve(w) -> bool:
	for id in Riddle.solution(w.seed_value):
		if not w.action("secret_ring_"+id): return false
	return w.seal_solved
func permutations(items: Array) -> Array:
	if items.is_empty(): return [[]]
	var result: Array=[]
	for i in items.size():
		var remainder:=items.duplicate(); var head= remainder.pop_at(i)
		for tail in permutations(remainder):
			var candidate: Array=[head]; candidate.append_array(tail); result.append(candidate)
	return result
func rejected(w,id: String):
	var before: Dictionary=state(w)
	check(not w.action(id) and state(w)==before,"rejected seal action atomic: "+id)
func _initialize():
	call_deferred("run_tests")
func run_tests():
	var w=at_seal()
	check(w.seal_clues==7 and w.clue and w.core_use=="elevator","three distinct locations and repaired lift establish prerequisites")
	var solution: Array=Riddle.solution(w.seed_value)
	var before: Dictionary=state(w)
	check(w.action("secret_ring_"+solution[0]),"first unique symbol enters sequence")
	rejected(w,"secret_ring_"+solution[0])
	check(w.action("secret_ring_"+solution[1]),"second unique symbol enters sequence")
	var partial: Dictionary=state(w)
	var loaded=World.new(0)
	check(loaded.restore(JSON.parse_string(JSON.stringify(partial))) and state(loaded)==partial,"partial input and discovered clues survive JSON")
	check(w.action("secret_backspace") and w.seal_input.size()==1,"backspace removes only last symbol")
	check(w.action("secret_reset") and w.seal_input.is_empty(),"reset clears partial input")
	check(resources(w)==[before.hp,before.atk,before.def,before.keys,before.gold,before.focus,before.principal,before.fees,before.interest,before.checkpoints,before.loan_used],"editing puzzle costs no resources or interest")
	var solutions:=0
	for sequence in permutations(["sun","moon","tower","key"]):
		w=at_seal(); var before_resources:=resources(w)
		var accepted:=true
		for id in sequence:
			if not w.action("secret_ring_"+id): accepted=false
		check(accepted and resources(w)==before_resources,"complete unique-symbol attempt charges no resources")
		if w.seal_solved:
			solutions+=1
			check(sequence==Riddle.solution(w.seed_value),"only independently resolved ordering solves seal")
		else: check(w.seal_input.is_empty(),"wrong four-symbol ordering resets only its input")
	check(solutions==1,"24 permutations contain exactly one world-level success")
	w=World.new(0); w.enter_floor(4); w.pos=Vector2i(1,3)
	rejected(w,"secret_ring_sun"); rejected(w,"secret_provisions"); rejected(w,"secret_voucher")
	w=at_seal(); w.pos=Vector2i(9,9)
	rejected(w,"secret_ring_sun")
	w=at_seal(); w.won=true
	rejected(w,"secret_ring_sun"); rejected(w,"secret_provisions")
	w=at_seal(); check(solve(w),"seal can be solved for reward phase")
	before=state(w)
	check(w.action("secret_provisions") and w.secret and w.hp==int(before.hp)+80 and w.keys==int(before.keys)+1 and w.seal_reward=="provisions" and w.tile(Vector2i(1,3))==".","provisions grant exact HP/key and remove seal")
	rejected(w,"secret_provisions"); rejected(w,"secret_voucher")
	check(w.restore(before) and not w.secret and w.tile(Vector2i(1,3))=="Q","undo restores reward availability and removes its benefit together")
	var borrow=at_seal(); borrow.enter_floor(0); borrow.pos=Vector2i(2,1); borrow.action("borrow")
	borrow.gold=20; borrow.enter_floor(4); borrow.pos=Vector2i(1,3); solve(borrow)
	var debt_before: Dictionary=state(borrow)
	check(borrow.action("secret_voucher") and borrow.debt()==0 and borrow.gold==28 and borrow.loan_used and borrow.checkpoints==0,"voucher first offsets 42 debt and credits only eight remainder")
	var direct_result: Array=[borrow.gold,borrow.debt(),borrow.loan_used,borrow.checkpoints]
	var paid_voucher: Dictionary=state(borrow)
	var bad_voucher: Dictionary=paid_voucher.duplicate(true); bad_voucher.principal=1
	check(not borrow.restore(bad_voucher) and state(borrow)==paid_voucher,"completed fixed-value voucher cannot reload with residual debt")
	check(borrow.restore(debt_before),"voucher outcome can be rolled back atomically")
	borrow.action("repay"); borrow.action("secret_voucher")
	check([borrow.gold,borrow.debt(),borrow.loan_used,borrow.checkpoints]==direct_result,"repay-before-voucher has identical total value")
	w=at_seal(); w.enter_floor(0); w.pos=Vector2i(2,1); w.action("borrow"); w.gold=17; w.settle_checkpoint(2); w.enter_floor(4); w.pos=Vector2i(1,3); solve(w)
	check(w.action("secret_voucher") and w.gold==17 and w.debt()==0 and not w.overdue and w.loan_used and w.checkpoints==2,"overdue voucher offsets debt without double-sweeping or resetting loan history")
	w=at_seal(); solve(w); w.gold=5
	check(w.action("secret_voucher") and w.gold==55 and w.debt()==0,"debt-free voucher adds exactly fifty")
	# v4 migration deliberately distinguishes already-paid secrets from old clues.
	w=at_seal(); var legacy_resources:=resources(w); var old: Dictionary=state(w); old.version=4
	for key in ["seal_clues","seal_input","seal_solved","seal_reward"]: old.erase(key)
	old.secret=true
	loaded=World.new(0)
	check(loaded.restore(old) and loaded.secret and loaded.seal_solved and loaded.seal_reward=="legacy" and loaded.tile(Vector2i(1,3))==".","paid legacy secret migrates closed without paying again")
	check(resources(loaded)==legacy_resources,"legacy already-paid secret migration grants no extra reward")
	rejected(loaded,"secret_provisions"); rejected(loaded,"secret_voucher")
	old.secret=false
	check(loaded.restore(old) and not loaded.secret and not loaded.seal_solved and loaded.seal_clues==0 and loaded.seal_input.is_empty() and loaded.clue,"unpaid legacy run retains old inscription but must discover three new clues")
	rejected(loaded,"secret")
	w=at_seal(); var valid: Dictionary=state(w)
	for bad_fields in [{"version":5.5},{"version":true},{"seal_clues":8},{"seal_clues":-1},{"seal_input":["sun","sun"]},{"seal_input":["unknown"]},{"seal_solved":true},{"seal_solved":"yes"},{"seal_reward":"provisions"},{"seal_reward":"unknown"}]:
		var bad: Dictionary=valid.duplicate(true); bad.merge(bad_fields,true)
		check(not w.restore(bad) and state(w)==valid,"invalid calibration save rejected without changing live state")
	# Controller reward undo restores debt, map, puzzle and payout together.
	var scene=load("res://main.tscn").instantiate(); root.add_child(scene)
	scene.save_path="user://calibration-integration-test.json"; scene.world=at_seal(); scene.growth=false
	await process_frame
	var event:=InputEventKey.new(); event.pressed=true; event.keycode=KEY_E
	scene._unhandled_input(event)
	check(scene.interaction and scene.available_actions().size()==4,"ready Q opens four unique symbol actions")
	var input_resources:=resources(scene.world)
	event.keycode=KEY_1; scene._unhandled_input(event)
	check(scene.world.seal_input.size()==1 and scene.available_actions().size()==5,"choosing a symbol hides it and offers backspace/reset")
	var input_before: Dictionary=state(scene.world)
	event.keycode=KEY_D; scene._unhandled_input(event)
	event.keycode=KEY_F2; scene._unhandled_input(event); scene._unhandled_input(event)
	check(state(scene.world)==input_before and resources(scene.world)==input_resources,"calibration modal blocks movement and F2 does not change input or resources")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.interaction and state(scene.world)==input_before,"closing calibration preserves partial input")
	event.keycode=KEY_E; scene._unhandled_input(event)
	scene.perform_action("secret_backspace")
	check(scene.world.seal_input.is_empty(),"UI backspace edits only partial input")
	scene.perform_action("secret_ring_"+solution[0]); scene.perform_action("secret_reset")
	check(scene.world.seal_input.is_empty() and resources(scene.world)==input_resources,"UI reset is free")
	solve(scene.world); before=state(scene.world)
	scene.perform_action("secret_provisions")
	scene.undo()
	check(state(scene.world)==before,"controller reward undo restores full solved-unclaimed state")
	check(scene.world.restore(debt_before),"controller voucher fixture restores solved indebted state")
	var voucher_label:=""
	for row in scene.available_actions():
		if row[0]=="secret_voucher": voucher_label=row[1]
	check("repay 42" in voucher_label and "receive 8" in voucher_label,"reward menu predicts debt offset and cash remainder")
	before=state(scene.world)
	scene.perform_action("secret_voucher"); scene.undo()
	check(state(scene.world)==before,"controller voucher undo restores debt, cash, seal and loan history")
	# Loading legacy JSON creates a byte-preserving, one-time backup before upgrade.
	var backup_path: String=scene.save_path.get_basename()+".pre-schema5.json"
	if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(backup_path)
	var legacy_save: Dictionary=state(World.new(0)); legacy_save.version=4
	for key in ["seal_version","seal_clues","seal_input","seal_solved","seal_reward"]: legacy_save.erase(key)
	var original_bytes: String=JSON.stringify(legacy_save,"\t")
	write_file(scene.save_path,original_bytes)
	scene.load_game()
	check(FileAccess.file_exists(backup_path) and FileAccess.get_file_as_string(backup_path)==original_bytes,"legacy JSON backup preserves original bytes")
	var upgraded=JSON.parse_string(FileAccess.get_file_as_string(scene.save_path))
	check(upgraded is Dictionary and upgraded.version==6 and scene.world.seal_clues==0,"successful legacy load atomically writes current schema six")
	legacy_save.gold=1; write_file(scene.save_path,JSON.stringify(legacy_save))
	scene.load_game()
	check(scene.world.gold==1 and FileAccess.get_file_as_string(backup_path)==original_bytes,"second legacy load never overwrites first backup")
	DirAccess.remove_absolute(scene.save_path); DirAccess.remove_absolute(backup_path)
	scene.save_path="user://invalid-calibration-v4-test.json"
	backup_path=scene.save_path.get_basename()+".pre-schema5.json"
	write_file(scene.save_path,'{"version":4}')
	before=state(scene.world); scene.load_game()
	check(state(scene.world)==before and not FileAccess.file_exists(backup_path),"invalid legacy JSON creates no backup and changes no live state")
	DirAccess.remove_absolute(scene.save_path)
	scene.save_path="user://backup-failure-calibration-test.json"
	backup_path=scene.save_path.get_basename()+".pre-schema5.json"
	write_file(scene.save_path,original_bytes)
	DirAccess.make_dir_recursive_absolute(backup_path)
	before=state(scene.world)
	print("EXPECTED negative-path diagnostic: backup destination is deliberately a directory.")
	scene.load_game()
	check(state(scene.world)==before and FileAccess.get_file_as_string(scene.save_path)==original_bytes,"backup failure preserves current world and original legacy file")
	DirAccess.remove_absolute(backup_path); DirAccess.remove_absolute(scene.save_path)
	# Actual no-teleport route with an early missed cage and late return.
	w=World.new(0)
	check(walk(w,Vector2i(2,1)) and w.action("seal_contract"),"real route reads merchant clue")
	for floor_number in range(5):
		if floor_number==1:
			check(walk(w,Vector2i(1,4)) and w.action("seal_water") and w.action("drain"),"real route reads water clue and chooses drain")
			check(walk(w,Vector2i(2,4)) and w.core,"real route retrieves core")
		if floor_number==2:
			check(walk(w,Vector2i(4,1)) and w.action("elevator"),"real route repairs lift with collected core")
		if floor_number==3: check(walk(w,Vector2i(1,3)) and w.seal_clues==7,"real route reads third clue")
		check(collect_safe(w),"real route collects reachable resources")
		if floor_number==0:
			check(walk(w,Vector2i(3,9)) and w.keys==1 and not w.step(Vector2i.LEFT),"first visit leaves unaffordable two-key cage behind")
		if floor_number<4: check(walk(w,Vector2i(9,9)),"real route ascends")
	check(walk(w,Vector2i(1,3)) and solve(w),"real route reaches and solves discovered seal")
	var keys_before: int=w.keys; var hp_before: int=w.hp
	check(w.action("secret_provisions") and w.keys==keys_before+1 and w.hp==hp_before+80,"real route earns extra key and HP")
	for i in range(4): check(walk(w,Vector2i(1,1)),"actual return stairs to missed cage")
	check(walk(w,Vector2i(2,9)) and walk(w,Vector2i(1,9)) and w.tile(Vector2i(1,9))==".","return opens old cage and actually collects its reward")
	for i in range(4): check(walk(w,Vector2i(9,9)),"actual ascent after treasure return")
	check(walk(w,Vector2i(8,3)) and w.won and w.hp>0 and w.secret and not w.loan_used,"calibration / missed-cage return route really wins without loans")
	print("CALIBRATION: %s (%d checks; actual route %d moves, %d HP)" % ["PASS" if failures==0 else "FAIL",checks,w.moves,w.hp])
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
		var best: Array=[]; var best_score:=100000
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
	var queue: Array=[[w.pos,[]]]; var visited: Dictionary={w.pos:true}
	while not queue.is_empty():
		var item: Array=queue.pop_front(); var p: Vector2i=item[0]
		if p==goal: return item[1]
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n: Vector2i=p+d
			if visited.has(n): continue
			var token: String=w.tile(n)
			if token=="#" or (token in ["D","L"] and (n!=goal or w.keys<(2 if token=="L" else 1))): continue
			if token=="~" and w.water_choice!="drain" and not w.bridge_built: continue
			if token in ["<",">","V","K"] and n!=goal: continue
			if World.ENEMIES.has(token) and (w.damage(token)<0 or w.damage(token)>=w.hp): continue
			visited[n]=true
			var route: Array=item[1].duplicate(); route.append(d); queue.append([n,route])
	return []

func write_file(path_name: String, content: String):
	var file:=FileAccess.open(path_name,FileAccess.WRITE)
	file.store_string(content)
	file.close()
