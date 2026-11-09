extends SceneTree
const W=preload("res://scripts/endless_world_v16.gd")
const G=preload("res://scripts/endless_generation_v16.gd")
var checks:=0
var failures:=0
var journey_loss:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func path(w,target:Vector2i,alternate:bool=false)->Array[Vector2i]:
	var avoid:Array=G.routes(w.seed,w.floor_number)[0 if alternate else 1].points.duplicate()
	if alternate and G.has_bridge(w.seed,w.floor_number) and w.bridges.get(w.floor_number,"")=="short":avoid.append(Vector2i(8,8))
	var queue:Array[Vector2i]=[w.pos];var parents:Dictionary={w.pos:w.pos};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		if p==target:
			var result:Array[Vector2i]=[]
			while p!=w.pos:result.push_front(p);p=parents[p]
			return result
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d;var t:String=w.tile(q)
			if parents.has(q) or q in avoid or t in ["#","M","S","D","V","N","u","v"] or (t in ["<",">"] and q!=target):continue
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
		if result.get("battle") is Dictionary:journey_loss+=int(result.battle.get("net_damage",result.battle.damage))
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
func replay(w):
	var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
	check(restored!=null and restored.bridges==w.bridges and restored.pos==w.pos and restored.hp==w.hp and restored.items==w.items and restored.keys==w.keys,"bridge history replay exact")
func _init():
	for seed in 128:
		for f in [1,2,3,50,999999,1000000]:
			var map:=G.generate(seed,f);check(map.ok and G.validate(map).ok,"conditional geometry seed%d f%d" % [seed,f])
			if f%2==0:check(not G.has_bridge(seed,f),"bridge only authored odd floors")
	for side in ["short","loot"]:
		var w=W.new_run(1);first_supply(w);go(w,Vector2i(4,6))
		check(w.keys==0 and not w.act("bridge_"+side+"!").changed,"no key refusal")
		go(w,Vector2i(3,3));go(w,Vector2i(4,6));var before=w.save_data();var hp:int=w.hp
		check(w.act("bridge_"+side).get("confirm",false) and w.save_data()==before and w.keys==1,"confirmation and cancellation free")
		check(w.act("bridge_"+side+"!").changed and w.keys==0 and w.hp==hp,"one key opens one side without moving or fighting")
		check(not w.act("bridge_"+side+"!").changed and not w.act("bridge_"+("loot" if side=="short" else "short")+"!").changed,"mutually exclusive permanent choice")
		check(w.tile(Vector2i(7,8))==("." if side=="short" else "u") and w.tile(Vector2i(6,5))==("." if side=="loot" else "v"),"only chosen tiles become safe floor")
		replay(w)
		if side=="short":
			go(w,Vector2i(8,9),true)
			check(w.tile(Vector2i(8,8)) in w.enemy_tokens() and w.tile(Vector2i(8,9))==".","short actually skips first but fights second")
			check(w.summary().routes[1].remaining==0,"short route summary excludes still-living bypassed enemy")
		else:
			go(w,Vector2i(6,4));var money:int=w.gold
			var full=w.clone();full.items.ward=9
			check(not full.step(Vector2i.UP).changed and full.pos==Vector2i(6,4) and full.tile(Vector2i(6,3))=="B","full inventory preserves complete chest")
			check(w.step(Vector2i.UP).changed and w.items.ward==1 and w.items.pierce==1 and w.gold==money,"box two existing tools zero gold")
			w.step(Vector2i.DOWN);w.step(Vector2i.UP)
			check(w.items.ward==1 and w.items.pierce==1,"box no repeated payout")
			replay(w)
		go(w,G.anchors(1).exit,side=="short");w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT)
		check(w.floor_number==1 and w.bridges.get(1)==side,"choice survives physical revisit")
		replay(w)
	for seed in [0,42]:
		for alternate in [false,true]:
			for policy in ["none","short","loot"]:
				var w=W.new_run(seed);var picked:=0;var medicine:=0;journey_loss=0
				for f in range(1,101):
					first_supply(w,alternate);camp(w,alternate)
					if w.hp<=130 and w.gold>=15:
						if w.act("buy_potion").changed:medicine+=15
					if G.has_bridge(seed,f) and policy!="none":
						go(w,Vector2i(3,3),alternate);go(w,Vector2i(4,6),alternate)
						check(w.act("bridge_"+policy+"!").changed,"real seeded floor chooses paid bridge")
						picked+=1
						if policy=="loot" and w.items.ward<9 and w.items.pierce<9:go(w,Vector2i(6,3),alternate)
					go(w,G.anchors(f).exit,alternate)
					check(w.floor_number==f+1 and not w.ended,"real100 all bridge policies survive")
					if f==50:print("V16 half seed%d alt%s %s hp%d gold%d" % [seed,alternate,policy,w.hp,w.gold])
				replay(w);print("V16 seed%d alt%s %s hp%d gold%d choices%d battle_loss%d medicine%d" % [seed,alternate,policy,w.hp,w.gold,picked,journey_loss,medicine])
	var fake=W.new_run(1).save_data();fake.actions=["bridge_short"]
	check(W.from_data(fake)==null,"unconfirmed macro never replayed")
	var locked=W.new_run(1);locked.bridges[1]="short";locked.gold=100
	for y in 15:
		for x in 15:
			var p:=Vector2i(x,y)
			if p!=Vector2i(6,4) and locked.tile(p) in locked.enemy_tokens():locked._consume(p)
	check(not locked.rune_view().available and not locked.act("rune_on!").changed and locked.gold==100,"locked island cannot justify zero-effect rune purchase")
	var bounded=W.new_run(1);bounded.pos=Vector2i(4,6);bounded.keys=1;bounded.actions.resize(99999);bounded.actions.fill("R")
	check(not bounded.act("bridge_short!").changed and bounded.keys==1,"bridge refuses over action limit without key loss")
	bounded.act("retire");check(not bounded.act("bridge_loot!").changed and bounded.keys==1,"ended bridge refuses payment")
	print("Endless V16: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
