extends SceneTree
var W=preload("res://scripts/endless_world_v20.gd")
const G=preload("res://scripts/endless_generation_v19.gd")
var checks:=0
var failures:=0
var journey_loss:=0
var use_skills:=false
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
			if parents.has(q) or q in avoid or t in ["#","M","S","D","V","N","u","v","O","R","J","L"] or (t in ["<",">"] and q!=target):continue
			parents[q]=p;queue.append(q)
	return []
func go(w,target:Vector2i,alternate:bool=false)->bool:
	var route:=path(w,target,alternate)
	check(w.pos==target or not route.is_empty(),"legal route exists")
	for p in route:
		if w.tile(p)=="C":
			var supply:Dictionary=w.act("cargo_use") if w.relief_remaining>0 else {"changed":false}
			if not supply.changed:check(w.act("cargo_leave").changed,"free discard preserves path")
		if use_skills and w.tile(p) in w.enemy_tokens():
			if w.hero_id=="scholar" and w.focus>0 and w.hp<=156:check(w.act("skill_use").changed,"scholar legal pre-fight heal")
			elif w.hero_id!="scholar" and w.focus>0 and not w.skill_armed:
				var before:Dictionary=w.preview(p);var trial=w.clone();trial.act("skill_use");var after:Dictionary=trial.preview(p)
				if after.valid and (after.net_damage<before.net_damage or (after.survivable and not before.survivable)):check(w.act("skill_use").changed,"arm useful hero skill")
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
func make(hero:String):
	var w=W.new_run(42);check(w.act("hero_"+hero).changed,"first action selects hero");return w
func _init():
	var pending=W.new_run(42)
	check(not pending.step(Vector2i.RIGHT).changed and not pending.act("retire").changed,"unselected cannot play or retire")
	check(not pending.act("hero_unknown").changed,"unknown hero rejected")
	check(W.from_data({"version":20,"mode":"endless","seed":42,"actions":["R"]})==null,"missing hero first event cannot replay")
	for hero in ["warden","ranger","scholar"]:
		var w=make(hero);check(w.actions==["hero_"+hero] and w.focus==2,"hero event and initial focus")
		check(not w.act("hero_scholar").changed,"cannot reselect or refill")
		if hero=="scholar":
			w.hp=179;check(w.act("skill_use").changed and w.hp==180 and w.focus==1,"scholar caps actual heal without overflow")
			check(not w.act("skill_use").changed and w.focus==1,"full hp refuses cost")
			check(not w.act("skill_cancel").changed,"scholar cannot arm")
		else:
			check(w.act("skill_use").changed and w.focus==2 and w.skill_armed,"arming costs no focus")
			check(not w.act("skill_use").changed,"duplicate preparation refused")
			check(w.act("skill_cancel").changed and w.focus==2 and not w.skill_armed,"cancel refunds nothing because no cost")
			check(w.act("skill_use").changed,"can arm again")
			var clone=w.clone();check(clone.hero_view()==w.hero_view(),"clone preserves hero resources")
			var saved=W.from_data(w.save_data());check(saved!=null and saved.hero_view()==w.hero_view(),"hero actions replay")
			w.focus=0;w.skill_armed=false;check(not w.act("skill_use").changed,"no focus cannot arm")
		var limited=make(hero);limited.actions.resize(limited.MAX_ACTIONS-1)
		check(not limited.act("skill_use").changed,"action limit rejects skill")
		limited.actions.clear();limited.actions.append("hero_"+hero);limited.ended=true;check(not limited.act("skill_use").changed,"ended cannot use skill")
	# Route forecasts must consume the prepared skill at the first real battle.
	for hero in ["warden","ranger"]:
		var w=make(hero);w.training_packs=1;w.atk=23;w.defense=12;w.act("skill_use")
		for route_index in 2:
			var forecast:Dictionary=w.summary().routes[route_index];var sim=w.clone();var loss:=0;var healed:=0
			for point in G.routes(sim.seed,sim.floor_number)[route_index].points:
				sim.pos=point+Vector2i.LEFT;var battle:Dictionary=sim.preview(point)
				check(battle.valid and battle.survivable,"controlled route can survive")
				loss+=int(battle.damage);healed+=int(battle.heal_after)
				check(sim.step(Vector2i.RIGHT).changed,"route actual fight")
			check(forecast.damage==loss and forecast.net_damage==loss-healed,"summary matches sequential actual skill consumption")
	# Real first-depth refill, overflow loss, revisit cannot farm focus.
	var growth=make("scholar")
	for f in range(1,9):
		first_supply(growth);camp(growth)
		if growth.hp<=130 and growth.gold>=15:growth.act("buy_potion")
		if f<8:go(growth,G.anchors(f).exit)
	check(growth.max_floor==8 and growth.focus==3,"4 and 8 milestones cap with overflow discarded")
	check(growth.act("skill_use").changed and growth.focus==2,"use one finite focus after milestone")
	go(growth,G.anchors(8).entry);check(growth.floor_number==7,"real descend")
	for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if growth.tile(growth.pos+direction)==".":check(growth.step(direction).changed,"step off paired stair before returning");break
	go(growth,G.anchors(7).exit);check(growth.floor_number==8 and growth.focus==2,"return to old max gives no refill")
	var replay=W.from_data(growth.save_data());check(replay!=null and replay.focus==2 and replay.max_floor==8,"refill derives only from real history")
	use_skills=true
	for seed in [0,42]:
		for hero in ["warden","ranger","scholar"]:
			for alternate in [false,true]:
				var w=W.new_run(seed);w.act("hero_"+hero);var medicine:=0;journey_loss=0
				for f in range(1,101):
					first_supply(w,alternate);camp(w,alternate)
					if hero=="scholar" and w.focus>0 and w.hp<=156:w.act("skill_use")
					if w.hp<=130 and w.gold>=15:
						if w.act("buy_potion").changed:medicine+=15
					go(w,G.anchors(f).exit,alternate)
					if w.ended:break
					if f==50:print("HERO20 HALF ",[seed,hero,alternate,w.hp,w.gold,w.focus,medicine,w.actions.count("skill_use")])
				check(not w.ended and w.max_floor==101,"real 100-floor hero strategy survives")
				var loaded=W.from_data(w.save_data())
				check(loaded!=null and loaded.save_data()==w.save_data() and loaded.hero_view()==w.hero_view(),"complete 100-floor hero replay")
				print("HERO20 FULL ",[seed,hero,alternate,w.hp,w.gold,w.focus,medicine,w.actions.count("skill_use"),journey_loss])
	print("Endless V20 core: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
