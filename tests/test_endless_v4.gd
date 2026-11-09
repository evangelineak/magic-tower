extends SceneTree
const W=preload("res://scripts/endless_world_v4.gd")
const V1=preload("res://scripts/endless_world_v1.gd")
const G=preload("res://scripts/endless_generation_v4.gd")
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
func go(w,target:Vector2i,alternate:bool=false,transport:bool=false):
	var route:=path(w,target,alternate)
	check(w.pos==target or not route.is_empty(),"real path exists")
	for p in route:
		if w.tile(p)=="C":check(w.act("cargo_accept" if transport and w.cargo.state=="fresh" else "cargo_use").changed,"resolve actual supply cost")
		check(w.step(p-w.pos).changed and not w.ended,"actual route action survives")
func cross(w,alternate:bool=false,transport:bool=false):
	var f:int=w.floor_number
	var y:int=1 if f%2==1 else 13
	go(w,Vector2i(2 if f%2==1 else 12,y),alternate,transport)
	go(w,Vector2i(3 if f%2==1 else 11,y),alternate,transport)
	go(w,G.anchors(f).exit,alternate,transport)
func _init():
	for seed in range(64):
		for f in [1,2,3,40,1000000]:
			var generated:=G.generate(seed,f)
			check(generated.ok,"geometry gates and rewards validated")
			check(generated==G.generate(seed,f),"seed replay")
			check(generated.exit==G.anchors(f+1).entry,"aligned stairs")
	for seed in [0,1,42,2147483647]:
		for alternate in [false,true]:
			var w=W.new_run(seed)
			for f in range(1,41):cross(w,alternate)
			check(w.floor_number==41 and w.hp>0,"40 real budget floors")
			check(w.kills==80 if alternate else w.kills==40,"no costless depth")
			var loaded=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
			check(loaded!=null and loaded.hp==w.hp and loaded.deltas==w.deltas,"full replay exact")
	var w=W.new_run(42)
	go(w,Vector2i(2,1));var hp:int=w.hp
	check(w.act("cargo_accept").changed and w.hp==hp,"transport sacrifices actual 20hp")
	check(w.tile(Vector2i(3,1))=="." and not w.act("cargo_accept").changed,"source removed once")
	check(w.cargo.target==3,"delivery two floors later")
	check(not w.act("cargo_deliver").changed,"early delivery rejected")
	go(w,G.anchors(1).exit);cross(w)
	go(w,Vector2i(2,1))
	check(w.act("cargo_deliver").changed,"destination merchant delivery")
	check(w.options(Vector2i(2,2)).size()==3,"reward independent three choices")
	var old_atk:int=w.atk
	check(w.act("cargo_mod_power").changed and w.atk==old_atk+4,"reward actual upgrade")
	check(not w.act("cargo_mod_keys").changed and not w.act("cargo_deliver").changed,"no duplicate reward")
	check(W.from_data(w.save_data()).cargo==w.cargo,"cargo replay exact")
	var opened=W.new_run(9);go(opened,Vector2i(2,1));opened.act("cargo_accept")
	check(opened.act("cargo_open").changed and opened.hp==170,"opening restores original supply")
	check(not opened.act("cargo_open").changed and not opened.act("cargo_deliver").changed,"opened cargo cannot reward")
	var copy=w.clone();check(copy.cargo==w.cargo and copy.save_data()==w.save_data(),"clone task exact")
	var v1=V1.new_run(42);v1.step(Vector2i.RIGHT)
	check(v1.save_data().version==1 and V1.from_data(v1.save_data())!=null,"frozen v1 replay")
	check(W.from_data(v1.save_data())==null and V1.from_data(w.save_data())==null,"no cross-version replay")
	var malformed:Dictionary=w.save_data();malformed["cargo"]={"state":"delivered"}
	check(W.from_data(malformed)==null,"task injection rejected")
	var start=W.new_run(1);var routes:Array=start.summary().routes
	check(routes.size()==2 and routes[0].damage!=routes[1].damage,"different route costs exposed")
	check(not start.act("cargo_mod_power").changed,"no remote reward")
	var broken:=G.generate(1,1);broken.grid[7][1]="."
	check(not G.validate(broken).ok,"free route bypass rejected")
	broken=G.generate(1,1);broken.grid[2][12]="."
	check(not G.validate(broken).ok,"treasure bypass rejected")
	var identities:Dictionary={};var positions:Dictionary={}
	for event_seed in range(120):
		var historical:Array=G.historical_map(event_seed)
		var solutions:Array=independent_solutions(historical)
		check(solutions.size()==1 and solutions==G.solve_case(historical),"independent unique historical route")
		identities[solutions[0]]=true
		for yy in 7:
			for xx in 7:
				if historical[yy][xx]==solutions[0]:positions[Vector2i(xx,yy)]=true
	check(identities.size()==3 and positions.size()==4,"answer names and actual locations vary")
	for event_seed in [0,1,2]:
		var event_world=W.new_run(event_seed)
		for f in 3:cross(event_world)
		go(event_world,Vector2i(2,13))
		check(event_world.floor_number==4 and event_world.act("case_read").changed,"real middle-floor investigation")
		var interrupted=event_world.clone()
		check(interrupted.act("retire").changed and W.from_data(interrupted.save_data()).messenger.state=="reading","retire during unsolved investigation")
		var view:Dictionary=event_world.case_view()
		check(view.known and view.available and not view.has("answer"),"UI has history not hidden answer")
		var answers:Array=independent_solutions(view.grid)
		var before_hp:int=event_world.hp;var before_gold:int=event_world.gold
		for letter in ["A","B","C"]:
			if letter==answers[0]:continue
			var wrong:Dictionary=event_world.act("case_"+letter.to_lower())
			check(wrong.changed and event_world.hp==before_hp and event_world.gold==before_gold,"wrong investigation no penalty")
			check(not event_world.act("case_"+letter.to_lower()).changed,"duplicate wrong search no event spam")
		check(event_world.act("case_"+str(answers[0]).to_lower()).changed,"logical answer finds messenger")
		var take=event_world.clone();check(take.act("case_take").changed and take.hp==before_hp+40,"immediate branch")
		check(not take.act("case_help").changed and not take.act("case_take").changed,"take excludes future reward")
		check(event_world.act("case_help").changed and event_world.hp==before_hp,"help forgoes immediate heal")
		check(not event_world.act("case_reward").changed,"must advance after helping")
		var old_def:int=event_world.defense
		go(event_world,G.anchors(4).exit)
		# Leave the paired stair without taking the new training crystal, then return.
		event_world.step(Vector2i.DOWN);event_world.step(Vector2i.UP)
		check(event_world.floor_number==4,"return to old camp")
		go(event_world,Vector2i(2,13))
		check(event_world.case_view().grid==view.grid,"cleared guards and revisit do not rewrite history")
		check(event_world.act("case_reward").changed and event_world.defense==old_def+3,"delayed reward after forward and return")
		check(not event_world.act("case_reward").changed,"reward only once")
		go(event_world,Vector2i(9,3))
		check(event_world.step(Vector2i.RIGHT,true).changed,"real door opening for history audit")
		check(event_world.case_view().grid==view.grid,"opened current door does not alter historical lock")
		check(not event_world.case_view().available and event_world.case_options().is_empty(),"remote history remains read only")
		var restored=W.from_data(JSON.parse_string(JSON.stringify(event_world.save_data())))
		check(restored!=null and restored.messenger==event_world.messenger,"messenger full JSON replay")
		check(take.act("retire").changed and W.from_data(take.save_data()).ended,"mid-event retirement replay")
	var remote=W.new_run(42)
	check(not remote.act("case_read").changed and remote.case_options().is_empty(),"remote action blocked")
	var hero=W.new_run(1)
	check(hero.build_view().options.is_empty() and not hero.act("tactic_brace").changed,"no remote switching")
	go(hero,Vector2i(2,1));hero.act("cargo_use")
	check(hero.act("tactic_brace").changed and hero.tactic=="brace","camp stance recorded")
	check(not hero.act("tactic_brace").changed,"same stance does not spam history")
	var guarded:Dictionary=hero.preview(Vector2i(3,7))
	hero.act("tactic_reap");var harvested:Dictionary=hero.preview(Vector2i(3,7))
	check(guarded.net_damage==4 and harvested.net_damage==5,"brace wins actual baseline heavy guard")
	go(hero,Vector2i(3,3));go(hero,Vector2i(9,3));hero.step(Vector2i.RIGHT,true);go(hero,Vector2i(12,3));go(hero,Vector2i(2,1))
	check(hero.act("buy_armor").changed and hero.defense==14,"real armor purchase counterexample")
	hero.act("tactic_brace");guarded=hero.preview(Vector2i(3,7))
	hero.act("tactic_reap");harvested=hero.preview(Vector2i(3,7))
	check(guarded.net_damage==2 and harvested.net_damage==1,"reap beats brace after real armor investment")
	go(hero,Vector2i(3,6));var hp_before:int=hero.hp;var kill_before:int=hero.kills
	var exact:Dictionary=hero.preview(Vector2i(3,7))
	check(hero.step(Vector2i.DOWN).changed and hero.hp==hp_before-int(exact.net_damage) and hero.kills==kill_before+1,"reap execution matches preview")
	hero.step(Vector2i.UP);hero.step(Vector2i.DOWN)
	check(hero.hp==hp_before-int(exact.net_damage),"cleared enemy cannot farm recovery")
	var loaded_hero=W.from_data(hero.save_data())
	check(loaded_hero!=null and loaded_hero.tactic==hero.tactic and loaded_hero.hp==hero.hp,"stance and recovery replay")
	var trained=W.new_run(7)
	for f in range(1,5):
		var y:int=1 if f%2==1 else 13
		go(trained,Vector2i(3,y))
		check(trained.act("skill_guard").changed,"real per-floor training")
		check(trained.training_level==mini(3,f+1),"ordinary training cap")
		cross(trained)
	check(trained.training_level==3,"training cannot exceed three")
	var grown=W.new_run(1)
	for f in 3:cross(grown)
	grown.step(Vector2i.UP);grown.step(Vector2i.DOWN)
	while grown.floor_number>1:go(grown,G.anchors(grown.floor_number).entry)
	go(grown,Vector2i(2,1))
	check(grown.atk==29 and grown.defense==16,"real three-floor return-vault attributes")
	grown.act("tactic_pierce");var real_pierce:Dictionary=grown.preview(Vector2i(10,10))
	grown.act("tactic_brace");var real_brace:Dictionary=grown.preview(Vector2i(10,10))
	check(real_pierce.damage==70 and real_brace.damage==94,"pierce beats brace in fully replayable returned hero")
	grown.act("tactic_pierce");go(grown,Vector2i(9,10))
	check(grown.step(Vector2i.RIGHT).changed and not grown.ended,"real vault fight with pierce")
	go(grown,Vector2i(12,10));check(grown.relic_bonus==1,"real treasure adds tactical level")
	go(grown,Vector2i(3,1));check(grown.act("skill_power").changed,"first real growth plus relic")
	go(grown,G.anchors(1).exit);go(grown,Vector2i(3,13))
	check(grown.act("skill_guard").changed and grown.training_level==3 and grown.effective_level()==4,"relic genuinely exceeds ordinary level cap")
	go(grown,Vector2i(9,10));check(grown.step(Vector2i.RIGHT).changed and not grown.ended,"second real vault fight")
	go(grown,Vector2i(12,10));check(grown.relic_bonus==2 and grown.effective_level()==5,"two real relics reach five")
	var saved_growth=W.from_data(JSON.parse_string(JSON.stringify(grown.save_data())))
	check(saved_growth!=null and saved_growth.relic_bonus==2 and saved_growth.training_level==3 and saved_growth.hp==grown.hp,"full real growth and relic event replay")
	var bench=W.new_run(1)
	# Focused combat boundary fixture; full action replay tested independently above.
	bench.pos=Vector2i(9,10);bench.atk=29;bench.defense=16;bench.hp=200
	bench.tactic="pierce";var piercing:Dictionary=bench.preview(Vector2i(10,10))
	bench.tactic="brace";guarded=bench.preview(Vector2i(10,10))
	check(piercing.damage==70 and guarded.damage==94,"pierce wins return-vault threshold")
	bench.tactic="reap";bench.hp=98
	var fatal:Dictionary=bench.preview(Vector2i(10,10))
	check(fatal.damage==98 and not fatal.survivable and fatal.heal_after==0,"reap cannot rescue lethal incoming damage")
	check(bench.step(Vector2i.RIGHT).get("confirm",false),"fatal needs confirmation")
	var fatal_kills:int=bench.kills
	check(bench.step(Vector2i.RIGHT,true).changed and bench.ended and bench.hp==0 and bench.kills==fatal_kills,"confirmed death grants no kill or heal")
	var relic=W.new_run(1);relic.training_level=3;relic.pos=Vector2i(11,10)
	check(relic.step(Vector2i.RIGHT).changed and relic.effective_level()==4,"treasure lifts training ceiling")
	relic.floor_number=2;relic.pos=Vector2i(11,10)
	check(relic.step(Vector2i.RIGHT).changed and relic.effective_level()==5,"second treasure lifts effective cap to five")
	relic.floor_number=3;relic.pos=Vector2i(11,10);relic.step(Vector2i.RIGHT)
	check(relic.effective_level()==5,"extra treasures cannot exceed five")
	var lethal_route=W.new_run(1);lethal_route.hp=5;lethal_route.atk=23;lethal_route.defense=12;lethal_route.tactic="reap"
	var sequential:Dictionary=lethal_route.summary().routes[1]
	check(sequential.survivable and sequential.net_damage==0,"sequential low-hit wins refund only damage")
	lethal_route.hp=3
	check(not lethal_route.summary().routes[1].survivable,"net zero does not imply survives first blow")
	check(W.from_data({"version":4,"mode":"endless","seed":1,"actions":["tactic_brace"]})==null,"remote stance injection rejected")
	print("ENDLESS V4: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)

# Independent graph search over (cell, has-visited-clock); no expected answer table.
func independent_solutions(g:Array)->Array:
	var queue:Array=[];var visited:Dictionary={};var found:Array=[]
	for y in 7:
		for x in 7:
			if g[y][x]=="s":queue.append(Vector3i(x,y,0))
	while not queue.is_empty():
		var state:Vector3i=queue.pop_front()
		if g[state.y][state.x]=="T":state.z=1
		if visited.has(state):continue
		visited[state]=true
		var token:String=g[state.y][state.x]
		if state.z==1 and token in ["A","B","C"] and token not in found:found.append(token)
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var x:int=state.x+d.x;var y:int=state.y+d.y
			if x>=0 and y>=0 and x<7 and y<7 and g[y][x] not in ["#","D","W","g"]:queue.append(Vector3i(x,y,state.z))
	found.sort();return found
