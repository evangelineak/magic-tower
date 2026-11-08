extends SceneTree
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
const World = preload("res://scripts/world.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures+=1; push_error("FAIL: "+message)
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func merchant():
	var w=World.new(0,1)
	w.pos=Vector2i(2,1)
	return w
func _init():
	var w=merchant()
	check(w.action("borrow") and w.gold==40 and w.debt()==42,"loan credits exact cash with transparent fee")
	check(not w.action("borrow") and w.gold==40,"repeat borrowing blocked")
	for i in range(4):
		check(w.step(Vector2i.LEFT) and w.step(Vector2i.RIGHT),"walking remains legal")
	check(w.debt()==42,"exploring does not accrue interest")
	w.settle_checkpoint(1)
	check(w.debt()==46 and w.interest==4,"first chapter simple interest")
	w.settle_checkpoint(1)
	check(w.debt()==46,"same checkpoint cannot charge twice")
	w.settle_checkpoint(2)
	check(w.debt()==50 and w.interest==8 and w.overdue,"second checkpoint caps cost and marks overdue")
	w.settle_checkpoint(2)
	check(w.debt()==50,"overdue debt frozen on revisit")
	w.gain_gold(30)
	check(w.debt()==20 and w.gold==40,"new gold is swept while preexisting gold remains available")
	w.gain_gold(25)
	check(w.debt()==0 and w.gold==45 and not w.overdue,"overpayment preserves excess and clears overdue")
	check(not w.action("borrow"),"repaid loan does not regenerate allowance")
	w=merchant(); w.gold=20
	check(w.action("borrow") and w.action("buy"),"loan bridges weapon purchase gap")
	check(w.gold==0 and w.weapon and w.atk==30,"weapon purchase atomic")
	check(not w.action("buy"),"weapon cannot be purchased twice")
	w.gain_gold(30); w.pay(22)
	check(w.gold==8 and w.principal==20 and w.fees==0,"partial payment consumes fees before principal")
	w.settle_checkpoint(1)
	check(w.debt()==22,"early payment reduces next interest")
	w.gain_gold(25)
	check(w.action("repay") and w.gold==11 and w.debt()==0,"design cashflow leaves eleven")
	w=merchant(); w.action("borrow"); w.gold=3; w.settle_checkpoint(1); w.action("repay")
	check(w.fees==0 and w.interest==3 and w.principal==40,"payment priority fee then interest then principal")
	w=merchant(); w.action("borrow"); w.gold=41; w.action("repay"); w.settle_checkpoint(1)
	check(w.principal==1 and w.interest==1,"integer interest rounds up")
	w=merchant(); w.action("borrow"); w.gold=42; w.action("repay"); w.settle_checkpoint(1)
	check(w.debt()==0,"zero balance no interest")
	w=World.new(0,1)
	check(not w.action("borrow") and not w.action("buy"),"merchant actions need proximity")
	w=merchant(); w.settle_checkpoint(1)
	check(not w.action("borrow"),"loans close after first checkpoint")
	for choice in ["elevator","forge","sell_core"]:
		w=World.new(0,1); w.core=true; w.floors[1][4][2]="."
		if choice=="elevator": w.pos=Vector2i(2,5)
		elif choice=="forge":
			# Synthetic forge setup represents having traversed preceding floors.
			w.floor_seen=[true,true,true,true,false]
			w.enter_floor(3); w.pos=Vector2i(3,5)
		else: w.pos=Vector2i(2,1)
		check(w.action(choice) and not w.core,"core spent once: "+choice)
		check(not w.action(choice),"repeat core action blocked: "+choice)
		var snapshot: Dictionary=JSON.parse_string(JSON.stringify(state(w)))
		var restored=World.new(0,1)
		check(restored.restore(snapshot) and state(restored)==state(w),"choice survives JSON: "+choice)
		check(not restored.action(choice),"load cannot reclaim core: "+choice)
	w=World.new(0,1); w.core=true; w.floors[1][4][2]="."; w.pos=Vector2i(2,5); w.action("elevator")
	check(w.action("travel") and w.floor_index==2 and w.pos==Vector2i(4,1),"lift up arrives at actual lift")
	check(w.action("travel") and w.floor_index==0 and w.pos==Vector2i(2,5),"lift return keeps floor state")
	check(w.checkpoints==0,"lift does not create interest checkpoints")
	w.enter_floor(4); w.pos=Vector2i(1,3)
	check(not w.action("secret"),"secret requires clue")
	w.clue=true
	check(not w.action("secret"),"old single-clue flag cannot bypass three-clue calibration")
	w.enter_floor(0); w.pos=Vector2i(2,1); w.action("seal_contract")
	w.enter_floor(1); w.pos=Vector2i(1,4); w.action("seal_water")
	w.enter_floor(3); w.pos=Vector2i(1,2); w.step(Vector2i.DOWN)
	w.enter_floor(4); w.pos=Vector2i(1,3)
	check(not w.action("secret"),"three clues and lift still require correct sequence")
	for symbol in World.Riddle.solution(w.seed_value): w.action("secret_ring_"+symbol)
	var old_hp: int=w.hp
	check(w.action("secret") and w.hp==old_hp+80,"solved calibration and running lift grant one secret reward")
	check(not w.action("secret") and w.hp==old_hp+80,"secret rewards once")
	w=World.new(0,1); w.enter_floor(4); w.pos=Vector2i(1,3); w.clue=true
	check(not w.action("secret"),"clue alone insufficient")
	w=World.new(0,1); w.enter_floor(3); w.pos=Vector2i(1,2)
	check(w.step(Vector2i.DOWN) and w.clue and w.tile(Vector2i(1,3))=="N","clue found through actual movement remains readable")
	w=World.new(0,1); w.enter_floor(1); w.pos=Vector2i(1,4)
	check(w.step(Vector2i.RIGHT) and w.core,"core collected via actual movement")
	check(w.step(Vector2i.LEFT) and w.step(Vector2i.RIGHT) and w.tile(w.pos)==".","core pickup does not respawn")
	w=merchant(); var before: Dictionary=state(w); w.action("borrow")
	check(w.restore(before) and not w.loan_used and w.debt()==0 and w.gold==0,"undo restores debt and gold together")
	w=merchant(); w.action("borrow"); w.gold=60; before=state(w); w.action("buy")
	check(w.restore(before) and not w.weapon and w.atk==18 and w.gold==60 and w.debt()==42,"purchase undo cannot keep free weapon")
	w=World.new(0,1)
	var original: Dictionary=state(w)
	for key in ["floor","x","hp","gold","principal","interest","checkpoints"]:
		for value in [-1, 1.5, "bad", INF]:
			var bad: Dictionary=original.duplicate(true); bad[key]=value
			check(not w.restore(bad) and state(w)==original,"atomic invalid %s=%s" % [key,str(value)])
	for key in ["core","weapon","secret","clue","loan_used","overdue","won"]:
		var bad: Dictionary=original.duplicate(true); bad[key]=1
		check(not w.restore(bad) and state(w)==original,"boolean schema: "+key)
	var bad: Dictionary=original.duplicate(true); bad.floors[0][1][2]="?"
	check(not w.restore(bad) and state(w)==original,"unknown tile rejected atomically")
	bad=original.duplicate(true); bad.floors.pop_back()
	check(not w.restore(bad) and state(w)==original,"missing floor rejected")
	bad=original.duplicate(true); bad.core=true; bad.core_use="forge"
	check(not w.restore(bad) and state(w)==original,"spent core cannot remain held")
	bad=original.duplicate(true); bad.principal=40
	check(not w.restore(bad) and state(w)==original,"debt requires issued loan")
	bad=original.duplicate(true); bad.overdue=true
	check(not w.restore(bad) and state(w)==original,"empty debt cannot be overdue")
	bad=original.duplicate(true); bad.secret=true
	check(not w.restore(bad) and state(w)==original,"secret requires prerequisites in saved state")
	bad=original.duplicate(true); bad.core=true
	check(not w.restore(bad) and state(w)==original,"held core cannot also remain on map")
	var borrower=merchant(); borrower.action("borrow"); borrower.settle_checkpoint(2)
	var loaded=World.new(0,1)
	check(loaded.restore(JSON.parse_string(JSON.stringify(state(borrower)))) and state(loaded)==state(borrower),"overdue debt roundtrip preserves full ledger")
	borrower.floors[4][2][1]=">"; borrower.enter_floor(4); borrower.pos=Vector2i(1,1)
	check(not borrower.step(Vector2i.DOWN) and borrower.floor_index==4,"corrupt top stair cannot escape floor bounds")
	borrower.floors[0][2][1]="<"; borrower.enter_floor(0); borrower.pos=Vector2i(1,1)
	check(not borrower.step(Vector2i.DOWN) and borrower.floor_index==0,"corrupt bottom stair cannot escape floor bounds")
	check(not w.step(Vector2i(2,0)) and not w.step(Vector2i.ZERO),"movement cannot teleport or idle-farm")
	w=merchant(); w.action("borrow")
	var ledger_before: Dictionary=state(w)
	w.pay(-10); w.pay(0); w.gain_gold(-10); w.gain_gold(0); w.settle_checkpoint(-1)
	check(state(w)==ledger_before,"nonpositive internal money operations and negative checkpoint do nothing")
	w.gold=5; w.pay(100)
	check(w.gold==0 and w.debt()==37 and w.principal==37 and w.fees==0,"oversized repayment capped at actual funds")
	ledger_before=state(w); w.pay(100)
	check(state(w)==ledger_before,"empty wallet cannot reduce debt")
	w.settle_checkpoint(999)
	check(w.checkpoints==2 and w.debt()==45 and w.interest==8 and w.overdue,"out-of-range checkpoint clamps to two installments")
	ledger_before=state(w); w.settle_checkpoint(999); w.settle_checkpoint(-5)
	check(state(w)==ledger_before,"repeated oversized or backwards checkpoint cannot compound")
	w.gain_gold(100)
	check(w.debt()==0 and w.gold==55 and not w.overdue,"oversized overdue income pays debt once and preserves surplus")
	ledger_before=state(w); w.pay(100)
	check(state(w)==ledger_before,"debt-free oversized repayment cannot destroy money")
	print("CHOICES: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
