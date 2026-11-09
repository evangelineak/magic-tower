extends SceneTree
const W=preload("res://scripts/endless_world_v9.gd")
const G=preload("res://scripts/endless_generation_v9.gd")
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
func fund(w,alternate:bool=false):
	first_supply(w,alternate);go(w,Vector2i(3,3),alternate);go(w,Vector2i(9,3),alternate)
	check(w.step(Vector2i.RIGHT,true).changed,"real key opens treasury")
	go(w,Vector2i(12,3),alternate);camp(w,alternate)
func replay(w,label:String):
	var copy=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
	check(copy!=null,label+" replay accepted")
	if copy!=null:check(copy.save_data()==w.save_data() and copy.contract==w.contract and copy.gold==w.gold and copy.items==w.items,label+" exact state")
func _init():
	for seed in 128:
		for f in [1,2,50,1000000]:
			var map:=G.generate(seed,f)
			check(map.ok and G.validate(map).ok,"preserved geometry and deterministic manifest")
			check(map.contract==G.manifest(seed,f),"contract identity")
	for seed in [0,3,4,7,8,11,12,15]:
		var w=W.new_run(seed);var offer:=G.manifest(seed,1);var alternate:bool=offer.route==1
		fund(w,alternate)
		var before:int=w.gold
		check(w.act("job_accept").changed and w.gold==before-12,"accept locks exactly12")
		check(not w.act("job_accept").changed,"cannot accept twice")
		check(w.act("job_cancel").get("confirm",false),"cancel requires confirmation")
		check(w.gold==before-12,"cancel prompt no change")
		replay(w,"active")
		for point in offer.points:go(w,point,alternate)
		if seed==0:
			go(w,G.anchors(1).exit,alternate)
			check(w.contract_view().source==1 and not w.act("job_refund").changed,"remote completed contract requires return")
			replay(w,"cross floor pending")
			w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT)
		camp(w,alternate)
		check(w.contract_view().phase=="complete","actual required guards complete")
		var clone=w.clone();check(clone.contract==w.contract and clone.rule_version()==9,"clone keeps job")
		before=w.gold
		check(w.act("job_refund").changed and w.gold==before+12,"refund before item with no fee")
		check(not w.act("job_refund").changed,"no duplicate refund")
		replay(w,"voucher")
		before=w.gold
		check(w.act("job_ward").changed and w.gold==before-8 and w.items.ward==offer.reward_count,"optional full quantity discounted purchase")
		check(not w.act("job_pierce").changed,"one reward only")
		replay(w,"fulfilled")
		# Cleared first-floor offer cannot be recreated by going away and back.
		go(w,G.anchors(1).exit,alternate);w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT)
		camp(w,alternate);check(not w.act("job_accept").changed,"floor chance persists on revisit")
		replay(w,"revisited")
	var direct=W.new_run(0);fund(direct);var gold:int=direct.gold
	check(direct.act("job_buyward").changed and direct.gold==gold-12 and direct.items.ward==1,"direct procurement")
	check(not direct.act("job_accept").changed,"direct replaces same floor job")
	replay(direct,"direct")
	var cancel=W.new_run(0);fund(cancel);gold=cancel.gold;cancel.act("job_accept")
	check(cancel.act("job_cancel!").changed and cancel.gold==gold-12,"confirmed cancel loses only12")
	check(not cancel.act("job_cancel!").changed and not cancel.act("job_refund").changed,"cancel cannot duplicate or refund")
	replay(cancel,"cancel")
	var dead=W.new_run(0);fund(dead);dead.act("job_accept");gold=dead.gold;dead.act("retire")
	check(not dead.act("job_refund").changed and dead.gold==gold,"retire does not return unsettled deposit")
	replay(dead,"retire")
	# Boundary fixtures deliberately isolate inventory and cash conditions.
	var full=W.new_run(0);fund(full);full.act("job_accept")
	for p in G.manifest(0,1).points:full._consume(p)
	full.items.ward=9;full.items.pierce=9;gold=full.gold
	check(full.act("job_refund").changed and full.gold==gold+12,"full inventory never blocks refundable deposit")
	gold=full.gold;check(not full.act("job_ward").changed and full.gold==gold and full.contract_view().phase=="voucher","full stock preserves voucher")
	check(full.act("job_decline").changed and full.gold==gold,"free decline after refund")
	var poor=W.new_run(0);camp(poor);poor.gold=11
	check(not poor.act("job_accept").changed and poor.contract.is_empty(),"insufficient deposit atomic")
	var remote=W.new_run(0);check(not remote.act("job_accept").changed,"remote denied")
	var late=W.new_run(0);fund(late)
	var chosen:=G.manifest(0,1);go(late,chosen.points[0],chosen.route==1);camp(late,chosen.route==1)
	check(not late.act("job_accept").changed,"cannot retroactively accept already killed target")
	var invalid=cancel.save_data();invalid.actions.append("job_cancel")
	check(W.from_data(invalid)==null,"unconfirmed cancellation cannot enter replay")
	print("Endless V9: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
