extends SceneTree
const W=preload("res://scripts/endless_world_v3.gd")
const V1=preload("res://scripts/endless_world_v1.gd")
const G=preload("res://scripts/endless_generation_v3.gd")
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
	print("ENDLESS V3: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
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
