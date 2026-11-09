extends SceneTree
const World=preload("res://scripts/endless_world_v1.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func path(w,target:Vector2i)->Array[Vector2i]:
	var queue:Array[Vector2i]=[w.pos];var parents:Dictionary={w.pos:w.pos};var head:=0
	while head<queue.size():
		var p:Vector2i=queue[head];head+=1
		if p==target:
			var route:Array[Vector2i]=[]
			while p!=w.pos:route.push_front(p);p=parents[p]
			return route
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n:Vector2i=p+d;var t:String=w.tile(n)
			if parents.has(n) or t in ["#","M","S","D","V"] or (t in ["<",">"] and n!=target):continue
			parents[n]=p;queue.append(n)
	return []
func go(w,target:Vector2i):
	var route:=path(w,target)
	check(w.pos==target or not route.is_empty(),"witness path exists")
	for p in route:
		var r:Dictionary=w.step(p-w.pos)
		check(r.changed and not w.ended,"witness real action succeeds")
func clear_floor(w):
	for point in w.witness_targets():go(w,point)
func _init():
	for seed in [0,1,42,2147483647]:
		var w=World.new_run(seed)
		for f in range(1,41):
			check(w.floor_number==f,"floor entered")
			clear_floor(w)
			check(w.floor_number==f+1 and w.kills==f,"mandatory gate prevents free depth")
		check(w.hp>0 and w.max_floor==41,"40-floor real budget witness")
		var restored=World.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
		check(restored!=null and restored.hp==w.hp and restored.grid()==w.grid() and restored.deltas==w.deltas,"JSON replay exact")
	for f in [1,40,1000,1000000]:
		var budget:Dictionary=World.minimum_budget(f)
		check(budget.valid and budget.gate_damage==8 and budget.min_exit_hp>0,"inductive route budget")
	var capped=World.new_run(42)
	capped.actions.resize(World.MAX_ACTIONS-1)
	check(not capped.step(Vector2i.RIGHT).changed and capped.act("retire").changed,"action cap retains retirement slot")
	var w=World.new_run(42)
	go(w,Vector2i(3,3));go(w,Vector2i(9,3))
	var before:Dictionary=w.save_data()
	check(w.step(Vector2i.RIGHT).get("confirm",false) and w.save_data()==before,"door confirmation is read-only")
	check(w.step(Vector2i.RIGHT,true).changed and w.keys==0,"door costs key")
	go(w,Vector2i(12,3));check(w.gold==40,"reward collected once")
	go(w,Vector2i(2,1));check(w.atk==23 and w.defense==12,"guaranteed training")
	go(w,Vector2i(2,1));check(w.options(Vector2i(2,2)).size()==3,"adjacent shop options")
	check(w.act("buy_sword").changed and w.gold==15 and w.atk==26,"shop cost real")
	check(not w.act("buy_sword").changed,"shop finite per floor")
	go(w,Vector2i(3,1));check(w.act("skill_power").changed,"skill choice")
	check(not w.act("skill_guard").changed,"skill choice exclusive")
	go(w,Vector2i(3,13));go(w,Vector2i(13,13));check(w.floor_number==2 and w.pos==Vector2i(13,13),"same coordinate up")
	check(w.step(Vector2i.LEFT).changed,"leave landing")
	check(w.step(Vector2i.RIGHT).changed and w.floor_number==1 and w.pos==Vector2i(13,13),"same coordinate down")
	check(w.tile(Vector2i(12,3))=="." and w.tile(Vector2i(10,3))=="." and w.tile(Vector2i(2,1))==".","revisit retains consumed deltas")
	var fresh=World.new_run(7)
	go(fresh,Vector2i(3,1));go(fresh,Vector2i(9,10))
	var forecast:Dictionary=fresh.preview(Vector2i(10,10))
	check(not forecast.survivable,"early vault too strong")
	check(fresh.step(Vector2i.RIGHT).get("confirm",false) and not fresh.ended,"fatal fight requires confirmation")
	check(fresh.step(Vector2i.RIGHT,true).changed and fresh.ended and fresh.ended_reason=="death","confirmed death")
	check(World.from_data(fresh.save_data())!=null,"death replay")
	var revisit=World.new_run(42)
	for f in 3:clear_floor(revisit)
	check(revisit.floor_number==4,"grown through three floors")
	revisit.step(Vector2i.LEFT);revisit.step(Vector2i.RIGHT)
	while revisit.floor_number>1:go(revisit,World.Generator.anchors(revisit.floor_number).entry)
	go(revisit,Vector2i(9,10))
	check(revisit.preview(Vector2i(10,10)).survivable,"grown hero can return for old vault")
	check(revisit.step(Vector2i.RIGHT).changed,"return fight wins")
	var vault_atk:int=revisit.atk
	go(revisit,Vector2i(12,10));check(revisit.atk==vault_atk+6,"vault grants meaningful growth")
	var copy=w.clone();check(copy.act("retire").changed and not w.ended,"clone independent and retirement")
	check(World.from_data(copy.save_data()).ended_reason=="retired","retire replay")
	var bad:Dictionary=w.save_data();bad["hp"]=999999;check(World.from_data(bad)==null,"reject injected stat")
	bad={"version":1,"mode":"endless","seed":0,"actions":["buy_sword"]};check(World.from_data(bad)==null,"reject impossible purchase")
	bad.actions=["U"];check(World.from_data(bad)==null,"reject blocked action")
	bad.actions=["R!"];check(World.from_data(bad)==null,"reject noncanonical confirmation")
	bad={"version":1,"mode":"endless","seed":0,"actions":["retire","R"]};check(World.from_data(bad)==null,"no actions after ending")
	bad={"version":1,"mode":"endless","seed":0.5,"actions":[]};check(World.from_data(bad)==null,"fractional seed rejected")
	var bad_code=World.new_run(1);check(not bad_code.apply_code("R!").changed and bad_code.actions.is_empty(),"noncanonical event cannot mutate")
	check(not w.safe_path(Vector2i(10,10)).size(),"safe path cannot auto fight")
	print("ENDLESS WORLD: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)
