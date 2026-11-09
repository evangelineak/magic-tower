extends SceneTree
const W=preload("res://scripts/endless_world_v14.gd")
const G=preload("res://scripts/endless_generation_v14.gd")
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
	var p:=G.camp_position(w.seed,w.floor_number)
	go(w,p+Vector2i.UP if w.floor_number%2 else p+Vector2i.DOWN,alternate)
func local_distance(g:Array,left:bool)->int:
	var start:=Vector2i(7,6);var end:=Vector2i(7,8);var queue:Array[Vector2i]=[start];var distance:Dictionary={start:0};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		if p==end:return distance[p]
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d
			if q.y<6 or q.y>8 or q.x<(5 if left else 7) or q.x>(7 if left else 9) or g[q.y][q.x]=="#" or distance.has(q):continue
			distance[q]=distance[p]+1;queue.append(q)
	return -1
func _init():
	var variants:Dictionary={}
	for seed in 512:
		for f in [1,2]:
			if not G.is_ring(seed,f):continue
			var data:=G.generate(seed,f);variants[data.variant]=true
			check(local_distance(data.grid,true)==(6 if data.variant>=1 else 4),"left ring branch has seeded detour")
			check(local_distance(data.grid,false)==(6 if data.variant==2 else 4),"right ring branch has seeded detour")
			var broken:Dictionary=data.duplicate(true);broken.grid[6][6]="#";broken.grid[6][5]="#"
			check(not G.validate(broken).ok,"reject one-sided courtyard even though global route survives")
			broken=data.duplicate(true);broken.grid[7][7]="."
			check(not G.validate(broken).ok,"reject filled central well")
	check(variants.size()==3,"all three ring variants sampled")
	for seed in 128:
		for f in [1,2,50,1000000]:
			var data:=G.generate(seed,f);check(data.ok and G.validate(data).ok,"rune identity and geometry")
			if data.rune.kind=="silence":check("p" in G.roster12(seed,f),"silence requires priest roster")
	for seed in [0,42]:
		for alternate in [false,true]:
			for policy in ["none","always","forecast"]:
				var w=W.new_run(seed);var activations:=0;var paid:=0
				for f in range(1,101):
					first_supply(w,alternate)
					go(w,Vector2i(2,1) if f%2 else Vector2i(12,13),alternate)
					var before=w.save_data();var oldpos:Vector2i=w.pos;var hp:int=w.hp;var money:int=w.gold
					var view:Dictionary=w.rune_view()
					check(w.save_data()==before and w.pos==oldpos and w.hp==hp and w.gold==money,"forecast is side-effect free")
					var chosen:bool=policy=="always" or (policy=="forecast" and view.after_routes[1 if alternate else 0].survivable and view.after_routes[1 if alternate else 0].net_damage<view.before_routes[1 if alternate else 0].net_damage)
					if chosen and view.available:
						check(w.act("rune_on").get("confirm",false) and w.save_data()==before,"confirmation prompt neither charges nor logs")
						check(w.act("rune_on!").changed and w.gold==money-view.price,"activation charges exact price")
						check(not w.act("rune_on!").changed,"once per floor activation")
						activations+=1;paid+=view.price
					camp(w,alternate)
					if w.hp<=130 and w.gold>=15:w.act("buy_potion")
					go(w,G.anchors(f).exit,alternate)
					check(w.floor_number==f+1 and not w.ended,"real100 rune journey survives")
					if f==50:print("V14 half seed%d alt%s %s hp%d gold%d" % [seed,alternate,policy,w.hp,w.gold])
				var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
				check(restored!=null and restored.runes==w.runes and restored.hp==w.hp and restored.gold==w.gold,"100 floor replay remembers paid floor flags")
				print("V14 seed%d alt%s %s hp%d gold%d activated%d paid%d" % [seed,alternate,policy,w.hp,w.gold,activations,paid])
	# Frozen-v12 baseline preview equality without activation, including old fatal totals.
	var Old=load("res://scripts/endless_world_v12.gd")
	for token in ["g","b","w","r","c","t","p","V"]:
		for health in [1,180]:
			var fresh=W.new_run(0);var old=Old.new_run(0)
			for w in [fresh,old]:
				w._maps[1]=w.grid();w._maps[1][5][5]=token;w.hp=health;w.tactic="reap";w.gear="cloak"
			check(fresh.preview(Vector2i(5,5))==old.preview(Vector2i(5,5)),"inactive exact legacy preview")
	# Inventory and event-limit boundary fixtures never masquerade as real funded histories.
	var x=W.new_run(0);x.gold=100;x.items.ward=1;x.armed_item="ward"
	var preview:Dictionary=x.rune_view();var source:Vector2i=preview.entry
	check(x.act("rune_on!").changed and x.items.ward==1 and x.armed_item=="ward","activation does not consume prepared tool")
	var snap=x.save_data();snap.actions=["rune_on"]
	check(W.from_data(snap)==null,"unconfirmed activation not replayable")
	var far=W.new_run(0);far.pos=G.anchors(1).exit;far.gold=100
	check(not far.act("rune_on!").changed,"exit staircase not activation entrance")
	var full=W.new_run(0);full.gold=100;full.actions.resize(99999);full.actions.fill("R")
	check(not full.act("rune_on!").changed and full.gold==100,"action cap activation atomic")
	var empty=W.new_run(0);empty.gold=100
	for y in 15:
		for xx in 15:
			if empty.tile(Vector2i(xx,y)) in empty.enemy_tokens():empty._consume(Vector2i(xx,y))
	check(not empty.act("rune_on!").changed and empty.gold==100,"no remaining enemies no fee")
	var found_quiet:=false
	for candidate in 128:
		if G.rune_info(candidate,1).kind!="silence":continue
		var quiet=W.new_run(candidate);quiet.gold=100
		for y in 15:
			for xx in 15:
				if quiet.tile(Vector2i(xx,y))=="p":quiet._consume(Vector2i(xx,y))
		check(not quiet.rune_view().available and not quiet.act("rune_on!").changed and quiet.gold==100,"silence no priest and no reap refuses zero-effect fee")
		found_quiet=true;break
	check(found_quiet,"silence fixture uses actual seeded altar")
	print("Endless V14: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
