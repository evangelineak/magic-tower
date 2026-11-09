extends SceneTree
const W=preload("res://scripts/endless_world_v10.gd")
const G=preload("res://scripts/endless_generation_v10.gd")
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
func _init():
	for bad in [[-1,1],[2147483648,1],[1,0],[1,-1],[1,1000001]]:
		check(not G.generate(bad[0],bad[1]).ok,"generation rejects invalid identity")
		var forged:=G.generate(9,1);forged.seed=bad[0];forged.floor=bad[1]
		check(not G.validate(forged).ok,"validator rejects forged identity")
	for bad in [{"seed":1.0,"floor":1},{"seed":1,"floor":1.0},{"seed":"1","floor":1},{"seed":1}]:
		check(not G.validate(bad).ok,"validator rejects noninteger or missing identity")
	var channels:=0
	for seed in 128:
		for f in [1,2,3,4,50,1000000]:
			var g:=G.generate(seed,f);check(g.ok and G.validate(g).ok,"geometry validates seed%d floor%d %s" % [seed,f,str(g.get("proof",{}))])
			if G.is_channel(seed,f):channels+=1
	check(channels>100,"new topology broadly distributed")
	for seed in [0,42]:
		for alternate in [false,true]:
			var w=W.new_run(seed);var macro_count:=0
			for f in range(1,101):
				first_supply(w,alternate);camp(w,alternate)
				if w.hp<=130 and w.gold>=15:w.act("buy_potion")
				w.act("tactic_brace")
				var rr:=G.routes(seed,f)
				var pts:Array=rr[1 if alternate else 0].points.duplicate()
				if f%2==0:pts.reverse()
				for point in pts:
					if w.tile(point) in w.enemy_tokens():go(w,point,alternate)
				var view:Dictionary=w.camp_return_view()
				if view.available:
					var before:int=w.actions.size();var oldhp:int=w.hp;var oldgold:int=w.gold
					var result:Dictionary=w.return_to_camp()
					check(result.changed and w.actions.size()==before+view.steps and w._near("M"),"one trigger expands exact movement")
					check(w.hp==oldhp and w.gold==oldgold and w.floor_number==f,"macro no interaction or floor change")
					check(not w.return_to_camp().changed,"already at camp no event")
					macro_count+=1
				go(w,G.anchors(f).exit,alternate)
				check(w.floor_number==f+1 and not w.ended,"real100 survives")
			var replay=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
			check(replay!=null and replay.hp==w.hp and replay.pos==w.pos and replay.actions==w.actions,"expanded replay identical")
			print("V10 seed%d alt%s macros%d actions%d" % [seed,alternate,macro_count,w.actions.size()])
	var limit=W.new_run(0);first_supply(limit);go(limit,Vector2i(4,1))
	var view:Dictionary=limit.camp_return_view();check(view.available,"fixture safe path")
	limit.actions.resize(99999);limit.actions.fill("R");var oldpos:Vector2i=limit.pos
	check(not limit.return_to_camp().changed and limit.pos==oldpos,"full batch budget refusal atomic")
	var bare=W.new_run(0);check(not bare.apply_code("camp_walk").changed,"no macro replay injection")
	var data=bare.save_data();data.actions=["camp_walk"];check(W.from_data(data)==null,"forged macro DTO rejected")
	# Synthetic corridor isolates every forbidden auto-travel token.
	for token in ["g","b","r","c","w","D","V","a","C","$","T","k","<",">"]:
		var fixture=W.new_run(0);var grid:Array=[]
		for y in 15:
			var row:Array=[]
			for x in 15:row.append("#")
			grid.append(row)
		grid[5][5]=".";grid[4][5]=token;grid[3][5]=".";grid[2][5]="M"
		fixture._maps={1:grid};fixture.pos=Vector2i(5,5)
		check(not fixture.camp_return_view().available and not fixture.return_to_camp().changed and fixture.actions.is_empty(),"macro refuses " + token)
	print("Endless V10: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
