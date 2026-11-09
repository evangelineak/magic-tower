extends SceneTree
const W=preload("res://scripts/endless_world_v8.gd")
const G=preload("res://scripts/endless_generation_v8.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func path(w,target:Vector2i,alternate:bool=false)->Array[Vector2i]:
	var avoid:Array=G.routes(w.seed,w.floor_number)[0 if alternate else 1].points
	var queue:Array[Vector2i]=[w.pos];var parents:Dictionary={w.pos:w.pos};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		if p==target:
			var result:Array[Vector2i]=[]
			while p!=w.pos:result.push_front(p);p=parents[p]
			return result
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d;var t:String=w.tile(q)
			if parents.has(q) or q in avoid or t in ["#","M","S","D","V"] or (t in ["<",">"] and q!=target):continue
			parents[q]=p;queue.append(q)
	return []
func go(w,target:Vector2i,alternate:bool=false)->bool:
	var route:=path(w,target,alternate)
	check(w.pos==target or not route.is_empty(),"legal route exists")
	for p in route:
		if w.tile(p)=="C":
			var supply:Dictionary=w.act("cargo_use")
			if not supply.changed:check(w.act("cargo_leave").changed,"free discard preserves path")
		var result:Dictionary=w.step(p-w.pos)
		if not result.changed or w.ended:
			check(false,"live route survives: "+str(result));return false
	return true
func first_supply(w,alternate:bool=false):
	var y:int=1 if w.floor_number%2 else 13
	go(w,Vector2i(2 if w.floor_number%2 else 12,y),alternate)
	go(w,Vector2i(3 if w.floor_number%2 else 11,y),alternate)
func camp(w,alternate:bool=false):
	go(w,Vector2i(2,1 if w.floor_number%2 else 13),alternate)
func _init():
	for seed in range(32):
		for f in [1,2,3,4,99,1000000]:
			var generated:=G.generate(seed,f)
			check(generated.ok and generated==G.generate(seed,f),"immutable generated roster and geometry")
		for block in range(10):
			var types:Dictionary={}
			for f in range(block*4+1,block*4+5):types[G.roster(seed,f)[0]]=true
			check(types.size()==4,"four enemy profiles in each seed-fixed segment")
	for seed in [0,42]:
		for alternate in [false,true]:
			var w=W.new_run(seed);var potions:=0;var hp50:=0;var gold50:=0
			for f in range(1,101):
				first_supply(w,alternate);camp(w,alternate)
				if w.hp<=130 and w.gold>=15:
					var bought:Dictionary=w.act("buy_potion")
					if bought.changed:potions+=1
				if not alternate:
					w.act("tactic_brace")
					go(w,Vector2i(3,1 if f%2 else 13),alternate)
					if w.lessons_used<6:
						if w.bonus_def<4:w.act("skill_guard")
						elif w.bonus_atk<6:w.act("skill_power")
				go(w,G.anchors(f).exit,alternate)
				check(w.floor_number==f+1 and w.hp<=180 and w.bonus_atk<=6 and w.bonus_def<=4,"actual budget and bounds each floor")
				if f==50:hp50=w.hp;gold50=w.gold
			var paid_boxes:int=w.actions.count("cargo_use")-10
			check(w.floor_number==101 and not w.ended and (potions>0 or paid_boxes>0),"100 real floors with actual paid healing")
			check(w.relief_remaining==0,"free supplies exhaust rather than regenerate")
			var replay=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
			check(replay!=null and replay.hp==w.hp and replay.training_packs==w.training_packs and replay.relief_remaining==0 and replay.bonus_def==w.bonus_def,"100-floor full event replay")
			print("V8 REAL seed=%d alt=%s hp50=%d gold50=%d hp100=%d gold100=%d potions=%d paid_boxes=%d" % [seed,alternate,hp50,gold50,w.hp,w.gold,potions,paid_boxes])
	var source=W.new_run(3);go(source,Vector2i(2,1))
	check(source.act("cargo_accept").changed and source.relief_remaining==9 and source.hp==150,"transport consumes exact free credit not health")
	check(source.act("cargo_open").changed and source.relief_remaining==9 and source.hp==158,"open original shipment does not double charge")
	var full=W.new_run(1);go(full,Vector2i(2,1));full.hp=180
	check(not full.act("cargo_use").changed and full.relief_remaining==10,"full hp does not waste free credit")
	check(full.act("cargo_leave").changed and full.relief_remaining==10 and full.tile(Vector2i(3,1))==".","free discard clears route")
	var paid=W.new_run(1);go(paid,Vector2i(2,1));paid.relief_remaining=0;paid.gold=4;paid.hp=179
	check(paid.act("cargo_use").changed and paid.hp==180 and paid.gold==0,"paid box respects actual one-health gap")
	var capped=W.new_run(1);go(capped,Vector2i(2,1));capped.bonus_atk=6;capped.bonus_def=4;capped.atk+=6;capped.defense+=4;capped.gold=100
	check(not capped.act("buy_sword").changed and not capped.act("buy_armor").changed and capped.gold==100,"capped shop never charges")
	capped.lessons_used=6;go(capped,Vector2i(3,1))
	check(not capped.act("skill_mend").changed and capped.options(Vector2i(3,2)).is_empty(),"six global lessons shared and explained")
	# Every optional source uses the same gain capture; old-layer baseline never follows current depth.
	var borrowed=W.new_run(5);first_supply(borrowed)
	var original:Dictionary=borrowed.base_enemy("V")
	borrowed.training_packs=20;borrowed.bonus_atk=6;borrowed.bonus_def=4;borrowed.atk=86;borrowed.defense=54
	check(borrowed.base_enemy("V")==original,"old enemy unchanged by player's stronger build")
	borrowed._apply_growth(80,50)
	check(borrowed.bonus_atk==6 and borrowed.bonus_def==4,"all extra gains share cap")
	var growing=W.new_run(0)
	for f in range(1,13):
		first_supply(growing);camp(growing);growing.act("tactic_brace")
		if growing.hp<=130 and growing.gold>=15:growing.act("buy_potion")
		go(growing,Vector2i(3,1 if f%2 else 13))
		if growing.lessons_used<6:growing.act("skill_guard" if growing.bonus_def<4 else "skill_power")
		go(growing,G.anchors(f).exit)
	check(growing.lessons_used==6 and growing.bonus_atk==4 and growing.bonus_def==4,"real six lessons finite shared budget")
	growing.step(Vector2i.DOWN);growing.step(Vector2i.UP)
	while growing.floor_number>3:go(growing,G.anchors(growing.floor_number).entry)
	go(growing,Vector2i(9,10));check(growing.step(Vector2i.RIGHT).changed,"legal old vault battle")
	go(growing,Vector2i(12,10))
	check(growing.bonus_atk==6 and growing.bonus_def==4 and growing.relic_bonus==1,"real treasure clips shared gains but keeps tactical reward")
	go(growing,G.anchors(3).exit);go(growing,Vector2i(2,13))
	check(growing.act("case_read").changed,"real messenger with full defense budget")
	var answer:String=G.solve_case(growing.case_view().grid)[0]
	growing.act("case_"+answer.to_lower());growing.act("case_help")
	go(growing,G.anchors(4).exit);growing.step(Vector2i.DOWN);growing.step(Vector2i.UP);go(growing,Vector2i(2,13))
	var before_reward:int=growing.gold
	check(growing.act("case_reward").changed and growing.bonus_def==4 and growing.gold==before_reward+24,"full defense quest reward converts explicitly instead of lost gain")
	var growth_replay=W.from_data(growing.save_data())
	check(growth_replay!=null and growth_replay.bonus_atk==6 and growth_replay.bonus_def==4 and growth_replay.training_packs==growing.training_packs,"all source cap and old-floor growth replays")
	var showcase=W.new_run(42);first_supply(showcase);showcase.bonus_atk=6;showcase.bonus_def=4;showcase.atk+=6;showcase.defense+=4;showcase.training_level=3;showcase.relic_bonus=2;showcase.tactic="reap"
	var nonzero:=0
	for f in range(49,101):
		showcase.floor_number=f;showcase.training_packs=f;showcase.atk=20+3*f+6;showcase.defense=10+2*f+4
		var forecast:Dictionary=showcase.summary().routes[0]
		if forecast.net_damage>0:nonzero+=1
	check(nonzero>=26,"maximum build retains positive losses in half of fixed segment profiles")
	check(not W.minimum_budget(100).valid,"no misleading old eight-loss certificate")
	var display_check=W.new_run(7);display_check.bonus_atk=6;display_check.bonus_def=4;display_check.hp=180;display_check.relic_bonus=2
	var treasure_text:Dictionary=display_check.preview(Vector2i(12,10))
	check(not str(treasure_text.title).contains("攻击+6") and str(treasure_text.lines).contains("实际+0"),"treasure title and detail show capped actual gains")
	display_check._maps={1:G.generate(7,1).grid};display_check._maps[1][1][2]="h"
	check(str(display_check.preview(Vector2i(2,1)).title).contains("180") and not str(display_check.preview(Vector2i(2,1)).title).contains("3000"),"legacy healing tile title uses correct health cap")
	display_check.hp=179
	check(display_check.step(Vector2i.RIGHT).changed and display_check.hp==180,"legacy healing tile clamps actual recovery")
	print("ENDLESS V8: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)
