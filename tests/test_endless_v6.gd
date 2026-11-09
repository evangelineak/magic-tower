extends SceneTree
const W=preload("res://scripts/endless_world_v6.gd")
const G=preload("res://scripts/endless_generation_v6.gd")
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
			if parents.has(n) or t in ["#","M","S","D","V"] or (t=="b" and not alternate) or (t in ["g","w"] and alternate) or (t in ["<",">"] and n!=target):continue
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
			if t=="#" or (t in ["g","w","b","D","V"] and t not in allowed) or seen.has(n):continue
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
				check(independent_reach(generated.grid,start,["g","w"]).has(target),"primary bidirectional")
				check(independent_reach(generated.grid,start,["b"]).has(target),"alternate bidirectional")
			var cleared:Dictionary=independent_reach(generated.grid,generated.entry,["g","w","b"])
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
	var kinds:Dictionary={}
	for seed in range(100):
		for f in [1,2,3,99,1000000]:
			var kind:String=G.encounter_kind(seed,f);kinds[kind]=true
			check(kind==G.encounter_kind(seed,f),"stable encounter hash")
	check(kinds.size()==3,"all encounter families represented")
	var merchant_seed:int=find_kind("quartermaster")
	var tools=W.new_run(merchant_seed)
	go(tools,Vector2i(2,1));check(not tools.act("enc_pierce").changed,"insufficient gold no cost")
	train(tools);go(tools,Vector2i(3,3));go(tools,Vector2i(9,3));tools.step(Vector2i.RIGHT,true);go(tools,Vector2i(12,3));go(tools,Vector2i(2,1))
	var ward_purchase=tools.clone();var ward_gold:int=ward_purchase.gold
	check(ward_purchase.act("enc_ward").changed and ward_purchase.gold==ward_gold-12 and ward_purchase.items.ward==1,"alternative purchase exact cost")
	var old_routes:Array=ward_purchase.summary().routes
	ward_purchase.act("arm_ward")
	var new_routes:Array=ward_purchase.summary().routes
	check(old_routes[0].net_damage>old_routes[1].net_damage and new_routes[0].net_damage<new_routes[1].net_damage,"purchased item reverses real route preference")
	var before_route:int=ward_purchase.hp
	go(ward_purchase,G.anchors(1).exit,true)
	check(before_route-ward_purchase.hp==new_routes[1].net_damage and ward_purchase.items.ward==0,"actual double guard route uses purchased ward once")
	check(W.from_data(ward_purchase.save_data()).hp==ward_purchase.hp,"actual item route replay")
	var paid:int=tools.gold
	check(tools.act("enc_pierce").changed and tools.items.pierce==1 and tools.gold==paid-18,"real purchase price")
	check(not tools.act("enc_ward").changed and not tools.act("enc_leave").changed,"mutually exclusive encounter")
	check(tools.act("arm_pierce").changed and not tools.act("arm_pierce").changed,"portable arm and no duplicate event")
	var restored_tools=W.from_data(tools.save_data());check(restored_tools!=null and restored_tools.items==tools.items and restored_tools.armed_item==tools.armed_item,"armed save replay")
	var actual_guard:Vector2i=G.routes(tools.seed,1)[0].points[0]
	if tools.tile(actual_guard) not in tools.enemy_tokens():
		# Some layouts required this guard to reach the merchant. Use the untouched vault instead.
		actual_guard=Vector2i(10,10)
	var approach:=Vector2i(-1,-1)
	for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var candidate:Vector2i=actual_guard+d;var approach_route:=path(tools,candidate)
		var safe:bool=not approach_route.is_empty() or tools.pos==candidate
		for cell in approach_route:
			if tools.tile(cell) in tools.enemy_tokens():safe=false
		if safe:approach=candidate;break
	check(approach.x>=0,"reachable front side of actual guard")
	go(tools,approach)
	var pred:Dictionary=tools.preview(actual_guard)
	var count_before:int=tools.items.pierce
	var result:Dictionary=tools.step(actual_guard-tools.pos)
	if result.get("confirm",false):
		check(tools.items.pierce==count_before and tools.armed_item=="pierce","fatal confirmation does not consume")
		var reloaded=W.from_data(tools.save_data());check(reloaded.items==tools.items and reloaded.armed_item=="pierce","confirmation reload retains tool")
		result=tools.step(actual_guard-tools.pos,true)
	check(result.changed and tools.items.pierce==count_before-1 and tools.armed_item=="","only actual battle consumes tool")
	var altar=W.new_run(find_kind("altar"));go(altar,Vector2i(2,1));var old_hp:int=altar.hp
	check(altar.act("enc_blood_ward").changed and altar.hp==old_hp-20 and altar.items.ward==1,"actual blood price")
	check(altar.act("arm_ward").changed and altar.act("arm_none").changed and altar.items.ward==1,"disarm no consumption")
	var medicine=W.new_run(find_kind("medicine"));go(medicine,Vector2i(2,1));old_hp=medicine.hp
	check(medicine.act("enc_blood_key").changed and medicine.hp==old_hp-30 and medicine.keys==1,"blood for key changes door budget")
	var keyed=W.new_run(find_kind("altar"));train(keyed);go(keyed,Vector2i(3,3));go(keyed,Vector2i(2,1))
	var old_key:int=keyed.keys
	check(keyed.act("enc_key_pierce").changed and keyed.keys==old_key-1 and keyed.items.pierce==1,"key sacrificed for pierce tool")
	var medic=W.new_run(find_kind("medicine"));train(medic);go(medic,Vector2i(3,3));go(medic,Vector2i(9,3));medic.step(Vector2i.RIGHT,true);go(medic,Vector2i(12,3));go(medic,Vector2i(2,1))
	var cash:int=medic.gold;var health:int=medic.hp
	check(medic.act("enc_medicine").changed and medic.gold==cash-12 and medic.hp==health+35,"medicine exact gold and health exchange")
	var declined=W.new_run(0);go(declined,Vector2i(2,1));var before_decline:int=declined.hp
	check(declined.act("enc_leave").changed and declined.hp==before_decline and declined.encounter_options().is_empty(),"decline permanent with no hidden cost")
	altar.act("arm_none");train(altar);go(altar,Vector2i(9,10));altar.act("arm_ward")
	check(not altar.preview(Vector2i(10,10)).survivable,"real early vault is fatal even with ward")
	check(altar.step(Vector2i.RIGHT).get("confirm",false) and altar.items.ward==1,"fatal preview retains ward")
	var fatal_loaded=W.from_data(altar.save_data())
	check(fatal_loaded!=null and fatal_loaded.armed_item=="ward" and fatal_loaded.items.ward==1,"fatal confirm reload no accidental consumption")
	check(altar.step(Vector2i.RIGHT,true).changed and altar.ended and altar.items.ward==0,"fatal actual battle consumes exactly once")
	check(W.from_data(altar.save_data()).items.ward==0,"fatal consumption event replay")
	var poor=W.new_run(find_kind("medicine"));go(poor,Vector2i(2,1));poor.hp=30
	check(not poor.act("enc_blood_key").changed and poor.hp==30 and not poor._used("encounter"),"cannot pay down to death")
	var cap=W.new_run(merchant_seed);go(cap,Vector2i(2,1));cap.gold=100;cap.items.ward=9
	check(not cap.act("enc_ward").changed and cap.gold==100,"full inventory never charges")
	var bench=W.new_run(0);bench.atk=23;bench.defense=12;bench.items.ward=1;bench.armed_item="ward";bench.tactic="brace"
	# Keep the board authentic; only combat boundary stats are a focused fixture.
	var guard:Vector2i=G.routes(bench.seed,1)[0].points[0]
	var shielded:Dictionary=bench.preview(guard)
	check(shielded.damage>=0 and shielded.reduction<=shielded.raw_damage,"stacked block never negative")
	bench.atk=1
	check(not bench.preview(guard).valid,"tool does not fake armor penetration")
	bench.pos=guard+Vector2i.LEFT
	check(not bench.step(Vector2i.RIGHT).changed and bench.items.ward==1,"unbreakable rejection preserves tool")
	var one_shot=W.new_run(3);train(one_shot,true);one_shot.hp=100;one_shot.items.ward=1;one_shot.armed_item="ward"
	var route_report:Dictionary=one_shot.summary().routes[1]
	check(route_report.damage==3,"one ward helps first of two guards only")
	var inv_before:Dictionary=one_shot.items.duplicate(true)
	one_shot.summary();check(one_shot.items==inv_before and one_shot.armed_item=="ward","HUD forecast is read only")
	check(W.from_data({"version":6,"mode":"endless","seed":0,"actions":["arm_ward"]})==null,"no inventory injection")
	print("ENDLESS V6: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)

func find_kind(kind:String)->int:
	for seed in range(100):
		if G.encounter_kind(seed,1)==kind:return seed
	return -1
