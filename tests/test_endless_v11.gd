extends SceneTree
const W=preload("res://scripts/endless_world_v11.gd")
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
	for seed in [0,42]:
		for alternate in [false,true]:
			for equipment in ["","cloak","lens"]:
				var w=W.new_run(seed);var spent:=0
				for f in range(1,101):
					first_supply(w,alternate);camp(w,alternate)
					if w.hp<=130 and w.gold>=15:w.act("buy_potion")
					if equipment!="" and not w.owned_gear[equipment] and w.gold>=80:
						check(w.act("buy_"+equipment).changed,"actual funded purchase")
						check(w.gear=="","purchase does not auto equip")
						check(w.act("gear_"+equipment).changed,"camp equip");spent+=40
					var oldatk:int=w.atk;var olddef:int=w.defense;var h:int=w.hp;var money:int=w.gold
					if equipment!="" and w.owned_gear[equipment]:
						check(not w.act("buy_"+equipment).changed,"already owned no rebuy")
						w.act("gear_none");w.act("gear_"+equipment)
						check(w.atk==oldatk and w.defense==olddef and w.hp==h and w.gold==money,"equip never farms growth health money")
					go(w,G.anchors(f).exit,alternate)
					check(w.training_packs==f and w.atk==20+f*3 and w.defense==10+f*2,"equipment never enters permanent budget")
					if f==50:print("V11 half seed%d alt%s gear%s hp%d gold%d" % [seed,alternate,equipment,w.hp,w.gold])
				var replay=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
				check(w.floor_number==101 and not w.ended and replay!=null,"100 real floors and replay")
				if replay!=null:check(replay.gear==w.gear and replay.owned_gear==w.owned_gear and replay.hp==w.hp and replay.gold==w.gold,"loaded equipment no repayment")
				check(spent==(0 if equipment=="" else 40),"exact lifetime purchase cost")
				print("V11 seed%d alt%s gear%s hp%d gold%d" % [seed,alternate,equipment,w.hp,w.gold])
	for equipment in ["","cloak","lens"]:
		for alternate in [false,true]:
			var route_world=W.new_run(1);first_supply(route_world,alternate);route_world.gear=equipment
			var expected:Dictionary=route_world.summary().routes[1 if alternate else 0];var hp_before:int=route_world.hp
			for point in G.routes(1,1)[1 if alternate else 0].points:go(route_world,point,alternate)
			check(hp_before-route_world.hp==expected.net_damage,"route simulation uses current equipment not v10")
	var trade=W.new_run(0);first_supply(trade);var point:=Vector2i(5,5);trade._maps[1]=trade.grid()
	trade._maps[1][5][5]="g";var normal:int=trade.preview(point).damage;trade.gear="cloak"
	check(normal==18 and trade.preview(point).damage==24,"final cloak atk-2 def-1 makes armored foe cost24 vs18")
	trade._maps[1][5][5]="w";trade.gear="";normal=trade.preview(point).damage;trade.gear="cloak"
	check(normal==14 and trade.preview(point).damage==11,"final cloak still helps heavy first counter11 vs14")
	trade.atk+=6;trade.defense+=4;trade._maps[1][5][5]="c";trade.gear="";normal=trade.preview(point).damage;trade.gear="lens"
	check(trade.preview(point).damage<normal,"lens reaches real one-shot threshold")
	# Isolated exact combat mechanics, not claimed as full legal journey fixtures.
	var w=W.new_run(0);first_supply(w);var p:=Vector2i(5,5);w.pos=Vector2i(5,4);w._maps[1]=w.grid();w._maps[1][5][5]="c"
	w.tactic="brace";w.gear="cloak";w.owned_gear.cloak=true;w.items.ward=1;w.armed_item="ward"
	var info:Dictionary=w.preview(p)
	check(info.gear_reduction==mini(4,maxi(0,info.first_counter_raw-4)),"cloak after brace")
	check(info.item_reduction==mini(6,maxi(0,info.first_counter_raw-4-info.gear_reduction)),"ward after cloak")
	var oldhp:int=w.hp;var result:Dictionary=w.step(Vector2i.DOWN)
	check(result.changed and oldhp-w.hp==info.net_damage and result.battle.damage==info.damage,"actual battle matches equipped preview")
	var lethal=W.new_run(0);first_supply(lethal);lethal.pos=Vector2i(5,4);lethal._maps[1]=lethal.grid();lethal._maps[1][5][5]="r"
	lethal.gear="lens";lethal.owned_gear.lens=true;lethal.tactic="reap";lethal.hp=11
	info=lethal.preview(p);var before:int=lethal.gold
	check(info.opening_lethal and info.rounds==0 and info.heal_after==0,"lens opening lethality precedes player attack and reap")
	result=lethal.step(Vector2i.DOWN,true)
	check(lethal.ended and lethal.gold==before and lethal.kills==0,"lethal opening no reward")
	var remote=W.new_run(0);check(not remote.act("buy_cloak").changed and not remote.act("gear_lens").changed,"remote changes refused")
	camp(remote);remote.gold=39;check(not remote.act("buy_cloak").changed and remote.gold==39,"poor purchase atomic")
	remote.gold=80;remote.act("buy_cloak");remote.act("buy_lens");remote.act("gear_lens")
	var clone=remote.clone();check(clone.gear=="lens" and clone.owned_gear==remote.owned_gear,"deep clone equipment")
	clone.owned_gear.cloak=false;check(remote.owned_gear.cloak,"clone ownership independent")
	remote.actions.resize(99999);remote.actions.fill("R");check(not remote.act("gear_none").changed,"action limit refuses equipment mutation")
	remote.act("retire");check(not remote.act("gear_none").changed,"ended refuses equipment mutation")
	print("Endless V11: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
