extends SceneTree
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+message)
func at_event(seed_number: int):
	var w=World.new(seed_number)
	w.enter_floor(3); w.pos=Vector2i(2,4)
	return w
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func unchanged_rejection(w,id: String):
	var before: Dictionary=state(w)
	check(not w.action(id) and state(w)==before,"rejected action remains atomic: "+id)
func roundtrip(w):
	var loaded=World.new(0)
	check(loaded.restore(JSON.parse_string(JSON.stringify(state(w)))) and state(loaded)==state(w),"event state JSON roundtrip: "+w.event_kind)
func _init():
	var action_kinds := {"bargain":["bargain_blood","bargain_gold"],"smuggler":["smuggler_sell","smuggler_buy"],"oath":["oath_power","oath_renew"]}
	for seed_number in range(3):
		var w=at_event(seed_number)
		check(w.event_kind==["bargain","smuggler","oath"][seed_number],"seed selects expected encounter")
		var offers: Array=w.event_offers()
		check(offers.size()==3 and offers[0][0]==action_kinds[w.event_kind][0] and offers[1][0]==action_kinds[w.event_kind][1] and offers[2][0]=="bargain_leave","offers match rule actions and include permanent decline")
		w.keys=10; w.gold=100; w.hp=300; w.focus=2
		for kind in action_kinds:
			if kind!=w.event_kind:
				for id in action_kinds[kind]: unchanged_rejection(w,id)
		check(w.action("bargain_leave") and w.event_done,"decline consumes event")
		for id in action_kinds[w.event_kind]: unchanged_rejection(w,id)
		roundtrip(w)
		w=World.new(seed_number); w.gold=100; w.keys=10
		for id in action_kinds[w.event_kind]: unchanged_rejection(w,id)
	var w=at_event(1)
	unchanged_rejection(w,"smuggler_sell")
	w.keys=1
	check(w.action("smuggler_sell") and w.keys==0 and w.gold==45 and w.event_done,"key sale exact exchange")
	unchanged_rejection(w,"smuggler_sell"); unchanged_rejection(w,"smuggler_buy")
	roundtrip(w)
	w=at_event(1); w.gold=29
	unchanged_rejection(w,"smuggler_buy")
	w.gold=30
	check(w.action("smuggler_buy") and w.gold==0 and w.keys==2,"key purchase exact exchange")
	unchanged_rejection(w,"smuggler_sell")
	w=World.new(1); w.pos=Vector2i(2,1); w.action("borrow"); w.gold=0
	w.settle_checkpoint(2); w.enter_floor(3); w.pos=Vector2i(2,4); w.keys=1
	check(w.action("smuggler_sell") and w.gold==0 and w.keys==0 and w.debt()==5,"sale proceeds repay overdue debt rather than bypassing it")
	roundtrip(w)
	w=at_event(2); w.focus=0
	unchanged_rejection(w,"oath_power")
	w.focus=1
	unchanged_rejection(w,"oath_power")
	w.focus=3; w.skill_armed=true
	var attack: int=w.atk
	check(w.action("oath_power") and w.focus==0 and not w.skill_armed and w.atk==attack+7,"oath consumes ALL focus and cancels armed skill")
	unchanged_rejection(w,"oath_renew"); roundtrip(w)
	w=at_event(2); w.focus=0; w.hp=60
	unchanged_rejection(w,"oath_renew")
	w.hp=61
	check(w.action("oath_renew") and w.hp==1 and w.focus==2,"renewal must survive and pays exact HP")
	unchanged_rejection(w,"oath_power")
	w=at_event(2); w.focus=w.focus_cap
	unchanged_rejection(w,"oath_renew")
	w.focus=w.focus_cap-1
	var hp: int=w.hp
	check(w.action("oath_renew") and w.focus==w.focus_cap and w.hp==hp-60,"renewal capped without creating excess focus")
	roundtrip(w)
	# Undo must return both offer availability and the price/reward, not only one.
	w=at_event(1); w.keys=1
	var before: Dictionary=state(w)
	w.action("smuggler_sell")
	check(w.restore(before) and w.keys==1 and w.gold==0 and not w.event_done,"sale rollback reverses gold and restores key together")
	check(w.action("smuggler_sell") and w.keys==0 and w.gold==45,"retry after rollback cannot multiply proceeds")
	var bad: Dictionary=state(w)
	bad.event_kind="oath"
	before=state(w)
	check(not w.restore(bad) and state(w)==before,"save cannot swap encounter kind while preserving seed")
	print("EVENTS: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
