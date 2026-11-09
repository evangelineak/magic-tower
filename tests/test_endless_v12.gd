extends SceneTree
const W=preload("res://scripts/endless_world_v12.gd")
const G=preload("res://scripts/endless_generation_v12.gd")
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
func fixture(token:String):
	var w=W.new_run(0);w.pos=Vector2i(5,4);w._maps[1]=w.grid();w._maps[1][5][5]=token;return w
func _init():
	for seed in 128:
		for f in [1,2,3,50,1000000]:
			var data:=G.generate(seed,f);check(data.ok and G.validate(data).ok,"new roster preserves topology")
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
					if f==50:print("V12 half seed%d alt%s gear%s hp%d gold%d" % [seed,alternate,equipment,w.hp,w.gold])
				var replay=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
				check(w.floor_number==101 and not w.ended and replay!=null,"100 real floors and replay")
				if replay!=null:check(replay.gear==w.gear and replay.owned_gear==w.owned_gear and replay.hp==w.hp and replay.gold==w.gold,"loaded equipment no repayment")
				check(spent==(0 if equipment=="" else 40),"exact lifetime purchase cost")
				print("V12 seed%d alt%s gear%s hp%d gold%d" % [seed,alternate,equipment,w.hp,w.gold])
	var target:=Vector2i(5,5)
	var thorn=fixture("t");thorn.atk=100;thorn.hp=2;thorn.tactic="reap";thorn.items.ward=1;thorn.armed_item="ward"
	var info:Dictionary=thorn.preview(target)
	check("反伤" in info.lines[2] and "回复" not in info.lines[2],"thorn copy excludes priest terminology")
	check(info.valid and not info.survivable and info.damage==2 and info.rounds==1 and info.reflection_damage==2,"killing hit reflection can kill")
	check(info.termination_reason=="reflection_death" and info.heal_after==0,"reflection lethal no harvest")
	var before=thorn.save_data();check(thorn.step(Vector2i.DOWN).get("confirm",false) and thorn.save_data()==before,"fatal prompt leaves inventory/history untouched")
	check(thorn.step(Vector2i.DOWN,true).changed and thorn.ended and thorn.kills==0 and thorn.gold==0 and thorn.items.ward==0,"real reflection death no victory consumes equipped tool")
	var priest=fixture("p");priest.atk=7;priest.hp=1;priest.items.ward=1;priest.armed_item="ward"
	info=priest.preview(target);before=priest.save_data()
	check(not info.valid and info.termination_reason=="regeneration_stall" and info.damage==0,"stable regeneration cycle rejected before lethal simulation")
	check(not priest.step(Vector2i.DOWN,true).changed and priest.save_data()==before and priest.items.ward==1 and priest.hp==1,"stall refusal never consumes resources")
	priest=fixture("p");priest.atk=21;priest.defense=10;priest.hp=180
	info=priest.preview(target);check("回复" in info.lines[2] and "反伤" not in info.lines[2],"priest copy excludes thorn terminology");check(info.rounds==3 and info.regen_total==6,"unblocked priest adds a whole attack")
	priest.tactic="brace";priest.items.ward=1;priest.armed_item="ward"
	info=priest.preview(target);check(info.rounds==2 and info.damage==0 and info.regen_total==0,"blocking first counter prevents heal and reaches final hit")
	var result:Dictionary=priest.step(Vector2i.DOWN)
	check(result.changed and priest.kills==1 and priest.gold==24 and priest.items.ward==0 and priest.hp==180,"new token enters actual combat and consumes tool")
	var dying=fixture("p");dying.atk=21;dying.hp=10
	info=dying.preview(target);check(info.termination_reason=="counter_death" and info.regen_total==0 and info.rounds==1,"priest does not heal after player death")
	for equipment in ["","cloak","lens"]:
		for alternate in [false,true]:
			var w=W.new_run(9);first_supply(w,alternate);w.gear=equipment
			var forecast:Dictionary=w.summary().routes[1 if alternate else 0];var h:int=w.hp
			for point in G.routes(9,1)[1 if alternate else 0].points:go(w,point,alternate)
			check(h-w.hp==forecast.net_damage,"v12 ordered summary actual loss with gear")
	print("Endless V12: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
