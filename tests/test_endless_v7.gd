extends SceneTree
const W=preload("res://scripts/endless_world_v7.gd")
const G=preload("res://scripts/endless_generation_v7.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func path(w,target:Vector2i,alternate:bool=false)->Array[Vector2i]:
	var q:Array[Vector2i]=[w.pos];var parents:Dictionary={w.pos:w.pos};var head:=0
	while head<q.size():
		var p:=q[head];head+=1
		if p==target:
			var result:Array[Vector2i]=[]
			while p!=w.pos:result.push_front(p);p=parents[p]
			return result
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n:Vector2i=p+d;var t:String=w.tile(n)
			if parents.has(n) or t in ["#","M","S","D","V"] or (t=="b" and not alternate) or (t in ["g","w","r","c"] and alternate) or (t in ["<",">"] and n!=target):continue
			parents[n]=p;q.append(n)
	return []
func go(w,target:Vector2i,alternate:bool=false):
	var route:=path(w,target,alternate)
	check(w.pos==target or not route.is_empty(),"real route exists %s" % target)
	for p in route:
		if w.tile(p)=="C":check(w.act("cargo_use").changed,"resolve supplement")
		check(w.step(p-w.pos).changed and not w.ended,"actual action survives")
func train(w,alternate:bool=false):
	var f:int=w.floor_number;var y:int=1 if f%2 else 13
	go(w,Vector2i(2 if f%2 else 12,y),alternate)
	go(w,Vector2i(3 if f%2 else 11,y),alternate)
func cross(w,alternate:bool=false):
	train(w,alternate)
	var before:int=w.hp;var route:Dictionary=w.summary().routes[1 if alternate else 0]
	go(w,G.anchors(w.floor_number).exit,alternate)
	check(before-w.hp==route.net_damage,"live route loss equals correct layout forecast")
func independent_reach(g:Array,start:Vector2i,allowed:Array)->Dictionary:
	var q:Array[Vector2i]=[start];var seen:Dictionary={start:true}
	while not q.is_empty():
		var p:Vector2i=q.pop_front()
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n:Vector2i=p+d
			if n.x<0 or n.y<0 or n.x>=15 or n.y>=15:continue
			var t:String=g[n.y][n.x]
			if t=="#" or (t in ["g","w","r","c","b","D","V"] and t not in allowed) or seen.has(n):continue
			seen[n]=true;q.append(n)
	return seen
func _init():
	var layouts:Dictionary={}
	for seed in range(96):
		for f in [1,2,3,4,17,1000000]:
			var generated:=G.generate(seed,f);layouts[generated.layout]=true
			check(generated.ok,"geometry contract")
			check(generated==G.generate(seed,f),"fixed seed reproduction")
			check(generated.exit==G.anchors(f+1).entry,"paired stairs")
			for start in [generated.entry,generated.exit]:
				var target:Vector2i=generated.exit if start==generated.entry else generated.entry
				check(not independent_reach(generated.grid,start,[]).has(target),"no free depth in either direction")
				check(independent_reach(generated.grid,start,["g","w","r","c"]).has(target),"primary bidirectional")
				check(independent_reach(generated.grid,start,["b"]).has(target),"alternate bidirectional")
			var cleared:Dictionary=independent_reach(generated.grid,generated.entry,["g","w","r","c","b"])
			check(not cleared.has(Vector2i(12,3)) and not cleared.has(Vector2i(12,10)),"both reward rooms sealed")
	check(layouts.size()==4,"four distinct layouts")
	for seed in range(8):
		for alternate in [false,true]:
			var w=W.new_run(seed)
			for f in range(1,33):cross(w,alternate)
			check(w.floor_number==33 and w.kills==(64 if alternate else 32),"32 real floors with mandatory cost")
			var loaded=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
			check(loaded!=null and loaded.hp==w.hp and loaded.deltas==w.deltas and loaded.grid()==w.grid(),"version five complete replay")
	for seed in range(4):
		var w=W.new_run(seed);train(w);go(w,Vector2i(3,3));go(w,Vector2i(9,3))
		check(w.step(Vector2i.RIGHT).get("confirm",false),"door still asks confirmation")
		var keys:int=w.keys;check(w.step(Vector2i.RIGHT,true).changed and w.keys==keys-1,"door cost retained")
		go(w,Vector2i(12,3));var gold:int=w.gold
		check(gold>=40,"valuable reward collected")
		w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT);check(w.gold==gold,"reward cannot duplicate")
		var forecast_grid:Array=w.grid();check(W.from_data(w.save_data()).grid()==forecast_grid,"door delta replay")
	# Cargo, messenger, and tactical slot use unchanged rules through changed geometry.
	var journey=W.new_run(2)
	go(journey,Vector2i(2,1));check(journey.act("cargo_accept").changed,"cargo accepted")
	check(journey.act("tactic_brace").changed,"tactic selected at camp")
	go(journey,G.anchors(1).exit);cross(journey)
	go(journey,Vector2i(2,1));check(journey.act("cargo_deliver").changed,"cargo target camp reachable")
	check(journey.act("cargo_mod_guard").changed,"cargo reward")
	cross(journey);go(journey,Vector2i(2,13))
	check(journey.act("case_read").changed,"case reachable on fourth layout")
	var answer:String=G.solve_case(journey.case_view().grid)[0]
	check(journey.act("case_"+answer.to_lower()).changed and journey.act("case_help").changed,"historical case still solvable")
	go(journey,G.anchors(4).exit);journey.step(Vector2i.DOWN);journey.step(Vector2i.UP)
	go(journey,Vector2i(2,13));check(journey.act("case_reward").changed,"case return reward")
	var replay=W.from_data(journey.save_data())
	check(replay!=null and replay.cargo==journey.cargo and replay.messenger==journey.messenger and replay.tactic==journey.tactic,"all cross-system events replay")
	go(journey,Vector2i(3,13))
	var opts:Array=journey.options(Vector2i(3,12));var mend_label:=""
	for row in opts:
		if row.id=="skill_mend":mend_label=row.label
	check(mend_label.contains("仍获战术训练"),"mend describes actual training semantics")
	for token_pos in [Vector2i(3,12),Vector2i(12,10),Vector2i(2,12)]:check(journey.preview(token_pos).lines.size()>=3,"nearby detail explanations")
	var death=W.new_run(3);train(death,true);death.hp=3;death.tactic="reap"
	check(not death.summary().routes[1].survivable,"new summary cannot use refund to survive fatal damage")
	var mechanism_counts:Dictionary={}
	for seed in range(96):
		var token:String=G.primary_token(seed,1);mechanism_counts[token]=true
	check(mechanism_counts.has("r") and mechanism_counts.has("c"),"new identities occur deterministically")
	for token in ["r","c"]:
		var seed:int=find_primary(token)
		var fighter=W.new_run(seed);go(fighter,Vector2i(2,1));fighter.act("cargo_use")
		var target:Vector2i=G.routes(seed,1)[0].points[0]
		var baseline:Dictionary=fighter.preview(target)
		check(baseline.damage==8 and baseline.survivable,"new enemy minimum training budget still eight")
		fighter.act("tactic_brace");var brace:Dictionary=fighter.preview(target)
		fighter.act("tactic_pierce");var pierce:Dictionary=fighter.preview(target)
		fighter.act("tactic_reap");var reap:Dictionary=fighter.preview(target)
		if token=="r":
			check(brace.damage==4 and pierce.damage==8 and reap.net_damage==5,"scout prefers brace to baseline pierce and reap")
			check(brace.opening_damage==4 and brace.reduction==4,"brace never blocks opening")
		else:
			check(pierce.damage==0 and brace.damage==4 and reap.net_damage==5,"charged guard prefers armor break one-shot")
			check(baseline.charge_extra==4 and baseline.normal_counter_damage==4,"charge doubles exactly first counter")
		fighter.act("tactic_brace")
		var approach:Vector2i=front_of(fighter,target)
		go(fighter,approach)
		var before_hp:int=fighter.hp;var before_gold:int=fighter.gold
		var prediction:Dictionary=fighter.preview(target)
		check(fighter.step(target-fighter.pos).changed and fighter.hp==before_hp-prediction.net_damage,"actual new battle equals preview")
		check(fighter.gold>before_gold and fighter.kills==1,"victory rewards once")
		var restored=W.from_data(JSON.parse_string(JSON.stringify(fighter.save_data())))
		check(restored!=null and restored.hp==fighter.hp and restored.kills==1,"new battle fully replays")
	# Explicit boundary fixtures complement the real-game event checks above.
	var scout=W.new_run(find_primary("r"));train(scout);var scout_target:Vector2i=G.routes(scout.seed,1)[0].points[0]
	scout.hp=4;scout.items.ward=1;scout.armed_item="ward";scout.tactic="reap";scout.pos=front_of(scout,scout_target)
	var doomed:Dictionary=scout.preview(scout_target)
	check(doomed.opening_lethal and doomed.damage==4 and doomed.rounds==0 and doomed.normal_counter_damage==0 and doomed.charge_extra==0,"opening fatal stops all later phases")
	var gold_before:int=scout.gold;var kills_before:int=scout.kills
	check(scout.step(scout_target-scout.pos).get("confirm",false) and scout.items.ward==1,"opening fatal confirmation preserves tool")
	check(scout.step(scout_target-scout.pos,true).changed and scout.ended and scout.hp==0 and scout.gold==gold_before and scout.kills==kills_before,"opening death gives no gold kills or recovery")
	check(scout.items.ward==0,"actual fatal opening consumes armed tool once")
	var block=W.new_run(find_primary("c"));train(block);var block_target:Vector2i=G.routes(block.seed,1)[0].points[0]
	block.tactic="brace";block.items.ward=1;block.armed_item="ward"
	var combined:Dictionary=block.preview(block_target)
	check(combined.first_counter_raw==8 and combined.reduction==8 and combined.damage==0,"ward plus brace capped at doubled first counter")
	block.atk=100
	check(block.preview(block_target).damage==0 and block.preview(block_target).charge_extra==0,"one-shot skips charged counter")
	var rapid=W.new_run(find_primary("r"));train(rapid);rapid.atk=100
	var rapid_target:Vector2i=G.routes(rapid.seed,1)[0].points[0]
	check(rapid.preview(rapid_target).damage==4 and rapid.preview(rapid_target).opening_damage==4,"one-shot cannot skip first strike")
	for token in ["r","c"]:
		var item_hero=W.new_run(find_primary(token));train(item_hero)
		var target:Vector2i=G.routes(item_hero.seed,1)[0].points[0]
		item_hero.items.pierce=1;item_hero.armed_item="pierce";item_hero.tactic="pierce"
		var pierced:Dictionary=item_hero.preview(target)
		check(pierced.enemy.def>=0 and pierced.damage==(8 if token=="r" else 0),"tool plus tactical penetration respects armor floor and special phase")
		item_hero.items.ward=1;item_hero.armed_item="ward";item_hero.tactic="brace"
		var blocked:Dictionary=item_hero.preview(target)
		check(blocked.damage==(4 if token=="r" else 0) and blocked.reduction<=blocked.first_counter_raw,"combined wards never block first strike or over-block counter")
		check(blocked.base_damage==8,"baseline comparison includes enemy mechanism")
	var declining=W.new_run(find_primary("r"));train(declining);declining.atk=1;declining.items.ward=1;declining.armed_item="ward"
	var decline_target:Vector2i=G.routes(declining.seed,1)[0].points[0]
	declining.pos=front_of(declining,decline_target)
	var hp_untouched:int=declining.hp
	check(not declining.step(decline_target-declining.pos).changed and declining.hp==hp_untouched and declining.items.ward==1,"unbreakable scout refuses before opening and preserves item")
	print("ENDLESS V7: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)

func find_primary(token:String)->int:
	for seed in range(1000):
		if G.primary_token(seed,1)==token:return seed
	return -1
func front_of(w,target:Vector2i)->Vector2i:
	for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var p:Vector2i=target+d;var route:=path(w,p)
		var safe:bool=not route.is_empty() or w.pos==p
		for step_point in route:
			if w.tile(step_point) in w.enemy_tokens():safe=false
		if safe:return p
	return Vector2i(-1,-1)
