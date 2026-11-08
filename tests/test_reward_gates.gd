extends SceneTree
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
var checks:=0
var failures:=0
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func at_gate(floor_number: int):
	var w=World.new(0)
	w.enter_floor(floor_number); w.pos=Vector2i(3,9)
	return w
func _init():
	for index in [0,2,3]:
		var w=at_gate(index); w.keys=1
		var before: Dictionary=state(w)
		check(not w.step(Vector2i.LEFT) and state(w)==before,"one key cannot enter double lock")
		w.keys=2; before=state(w)
		check(w.step(Vector2i.LEFT) and w.keys==0 and w.tile(Vector2i(2,9))==".","double lock consumes exactly two keys")
		var opened: Dictionary=state(w)
		var old_hp: int=w.hp; var old_atk: int=w.atk; var old_gold: int=w.gold; var old_focus: int=w.focus
		check(w.step(Vector2i.LEFT),"opened lock allows reward pickup")
		if index==0: check(w.gold==old_gold+60,"treasury awards exactly sixty gold")
		elif index==2: check(w.atk==old_atk+5,"edge awards exactly five attack")
		else: check(w.hp==old_hp+140 and w.focus==mini(w.focus_cap,old_focus+1),"provisions grant HP and capped focus")
		var paid: Dictionary=state(w)
		w.step(Vector2i.RIGHT); w.step(Vector2i.LEFT)
		check(w.hp==paid.hp and w.atk==paid.atk and w.gold==paid.gold and w.focus==paid.focus and w.keys==0,"revisiting claimed cage cannot duplicate reward or charge keys")
		check(w.restore(opened) and w.hp==old_hp and w.atk==old_atk and w.gold==old_gold,"reward rollback restores resource and unclaimed token together")
		check(w.restore(before) and w.keys==2 and w.tile(Vector2i(2,9))=="L","lock rollback restores keys and gate together")
		check(w.restore(JSON.parse_string(JSON.stringify(paid))) and state(w)==paid,"claimed reward JSON roundtrip")
	var w=World.new(0); w.pos=Vector2i(2,1); w.action("borrow"); w.gold=0; w.settle_checkpoint(2)
	w.pos=Vector2i(3,9); w.keys=2
	check(w.step(Vector2i.LEFT) and w.step(Vector2i.LEFT) and w.debt()==0 and w.gold==10,"overdue treasury income pays fifty debt and leaves ten")
	w=at_gate(3); w.focus=1; w.keys=2
	check(w.step(Vector2i.LEFT) and w.step(Vector2i.LEFT) and w.focus==2,"provisions restore one missing focus")
	for seed_number in [0,1,42,834]:
		w=World.new(seed_number)
		var total_keys:=0; var total_locks:=0; var per_floor_ok:=true
		for grid in w.floors:
			var floor_keys:=0
			for row in grid:
				for token in row:
					if token=="k": floor_keys+=1
					if token=="L": total_locks+=1
			total_keys+=floor_keys
			if floor_keys!=1: per_floor_ok=false
		check(per_floor_ok and total_keys==5 and total_locks==3 and total_keys<total_locks*2,"seed preserves scarce five-key / six-key-cage budget")
		for index in [0,2,3]:
			check(w.floors[index][8][1]=="#" and w.floors[index][9][2]=="L" and w.floors[index][9][1] in ["$","A","P"],"seed preserves sealed reward alcove")
		var proof: Dictionary=Generator.validate(w.floors)
		check(proof.solvable,"main route still has no-lock witness")
		var avoids_locks:=true
		var collected_keys:=0
		for symbol in proof.route:
			var d: Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[symbol]
			if w.tile(w.pos+d)=="k": collected_keys+=1
			if w.tile(w.pos+d) in ["L","D"] or not w.step(d): avoids_locks=false; break
		check(avoids_locks and w.won and w.hp>0 and w.keys==collected_keys,"main route wins without paying any key gate")
	print("REWARD GATES: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
