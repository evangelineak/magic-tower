extends SceneTree
var W=preload("res://scripts/endless_world_v22.gd")
const G=preload("res://scripts/endless_generation_v22.gd")
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
			if parents.has(q) or q in avoid or t in ["#","M","S","D","V","N","u","v","O","R","J","L","~","F"] or (t in ["<",">"] and q!=target):continue
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
			if w.hero_id=="scholar" and w.focus>=w.skill_cost() and w.hp<=180-w.skill_heal():check(w.act("skill_use").changed,"scholar legal pre-fight heal")
			elif w.hero_id!="scholar" and w.focus>=w.skill_cost() and not w.skill_armed:
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
func make(hero:String="warden",legacy:String="none",seed:int=42):
	var w=W.new_run(seed);check(w.act("hero_"+hero).changed,"hero first");check(w.act("legacy_"+legacy).changed,"legacy second");return w
func choose_cards(w):
	if w.talents.size()>=3:return
	if w.kills>=[3,8,15][w.talents.size()] and w.skill_armed:w.act("skill_cancel")
	while w.talent_view().available:
		var view:Dictionary=w.talent_view();check(w.act(view.offers[0].action).changed,"actual first-offer selection")
func set_water(w,state:int):
	if w.water_state()!=state:check(w.act("water_north" if state==0 else "water_south").changed,"valve changes target state")
func water_cross(w,upward:bool=true):
	var info:Dictionary=w.water_view()
	var first:String="south" if upward else "north";var second:String="north" if upward else "south"
	go(w,Vector2i(5,12) if upward else Vector2i(4,3),true)
	set_water(w,1 if upward else 0)
	go(w,info.guardians[first],true);go(w,Vector2i(6,7),true)
	var before:Dictionary=w.save_data();var old_hp:int=w.hp;var old_gold:int=w.gold;var old_focus:int=w.focus;var old_keys:int=w.keys
	set_water(w,0 if upward else 1)
	check(w.hp==old_hp and w.gold==old_gold and w.focus==old_focus and w.keys==old_keys,"turning valve gives no resource or damage")
	check(w.save_data().actions.size()==before.actions.size()+1,"valve records exactly one canonical event")
	go(w,info.guardians[second],true)
	go(w,G.anchors(w.floor_number).exit if upward else G.anchors(w.floor_number).entry,true)
func _init():
	var old=load("res://scripts/endless_generation_v19.gd")
	var variants:Dictionary={}
	for seed in range(24):
		for block in range(4):
			var selected:=0
			for f in [block*8+4,block*8+6]:
				var built:Dictionary=G.generate(seed,f)
				check(built.ok,"generated water or old map validates")
				if G.is_water(seed,f):
					selected+=1;variants[built.water.variant]=true
					check(not old.has_cart(seed,f) and not old.has_bridge(seed,f),"water does not overwrite existing special events")
					check(G.state_grid(seed,f,0)!=G.state_grid(seed,f,1),"water level changes actual traversal grid")
				else:check(built==old.generate(seed,f),"non-water geometry remains unchanged")
			check(selected==1,"one deterministic even water floor per eight-depth block")
	check(variants.size()==2,"both geometry variants sampled")
	for bad in [{"seed":-1,"floor":4},{"seed":0,"floor":0},{"seed":2147483648,"floor":6},{"seed":0,"floor":1000001}]:check(not G.validate(bad).ok,"invalid generator identity refused")
	# Controlled local fixtures distinguish spatial refusals from earned history.
	for seed in [0,42]:
		var w=make("warden","none",seed)
		for f in [4,6]:
			if G.is_water(seed,f):w.floor_number=f;w.max_floor=f;break
		w.pos=Vector2i(6,7);var info:Dictionary=w.water_view()
		var origin:int=w.water_state();var held:Dictionary=w.save_data()
		check(not w.act("water_north" if origin==0 else "water_south").changed and w.save_data()==held,"same-state choice has no event")
		check(w.act("water_turn").changed and w.actions.back() in ["water_north","water_south"],"UI alias records explicit target")
		check(not w.apply_code("water_turn").changed,"saved alias rejected")
		set_water(w,0);var wet:Vector2i=info.pools.south[0]
		w.pos=wet+Vector2i.UP
		if w.tile(w.pos)!=".":w.pos=Vector2i(6,7);wet=Vector2i(6,8)
		check(not w.step(wet-w.pos).changed,"deep water explicitly refuses movement")
		check(w.safe_path(wet).is_empty(),"safe path refuses deep-water destination")
		w.pos=Vector2i(13,13);check(not w.act("water_south").changed,"remote turn refused")
		w.pos=Vector2i(6,7);check(w.act("water_south").changed,"dry island can restore southern retreat")
		check(w.tile(Vector2i(6,8))==".","retreated pool becomes real safe floor")
		var view:Dictionary=w.water_view();view.pools.south.clear();check(not w.water_view().pools.south.is_empty(),"view cannot mutate cached water manifest")
		check(w.clone().water_view()==w.water_view() and w.clone().rule_version()==22,"clone preserves new version and water state")
	# Real first encounter, failed strong-enemy approach, return after growth.
	var earned=make("scholar","none",42);var first_water:=0
	for f in range(1,21):
		first_supply(earned);camp(earned)
		if earned.hp<=156 and earned.focus>0:earned.act("skill_use")
		if earned.hp<=130 and earned.gold>=15:earned.act("buy_potion")
		if G.is_water(earned.seed,f) and first_water==0:
			first_water=f;var info:Dictionary=earned.water_view()
			go(earned,Vector2i(5,12),true);set_water(earned,1);go(earned,info.guardians.south,true);go(earned,Vector2i(9,7),true)
			var p:Dictionary=earned.preview(info.guardians.vault);var before:Dictionary=earned.save_data()
			if not p.survivable:check(not earned.step(Vector2i.RIGHT).changed and earned.save_data()==before,"unready island guard may be left without paying or dying")
			go(earned,Vector2i(6,7),true);set_water(earned,1);go(earned,Vector2i(5,12),true)
			check(not earned.ended,"retreat over cleared southern bank is real safe movement")
		if f<20:go(earned,G.anchors(f).exit)
	while earned.floor_number>first_water:go(earned,G.anchors(earned.floor_number).entry)
	go(earned,Vector2i(4,3));set_water(earned,0)
	go(earned,earned.water_view().guardians.north,true);go(earned,Vector2i(9,7),true)
	var relic_before:Dictionary=earned.relic_quote();check(earned.preview(Vector2i(10,7)).survivable,"earned growth makes old island guardian defeatable")
	var fight:Dictionary=earned.step(Vector2i.RIGHT)
	check(fight.changed and fight.get("battle") is Dictionary,"real island guardian defeated");go(earned,Vector2i(11,7))
	check(earned.step(Vector2i.RIGHT).changed and earned.tile(Vector2i(12,7))==".","island contains the original once-only relic")
	check(earned.relic_bonus==int(relic_before.relic_gain),"no duplicate extra relic added")
	var saved=W.from_data(earned.save_data());check(saved!=null and saved.water_view()==earned.water_view() and saved.save_data()==earned.save_data(),"island retreat/revisit/reward canonical history replays")
	use_skills=true
	for seed in [0,42]:
		for alternate in [false,true]:
			for drafting in [false,true]:
				var w=make("warden" if seed==0 else "ranger","none",seed);var medicine:=0;journey_loss=0
				for f in range(1,101):
					if drafting:choose_cards(w)
					first_supply(w,alternate);camp(w,alternate)
					if w.hp<=130 and w.gold>=15:
						if w.act("buy_potion").changed:medicine+=15
					if alternate and G.is_water(seed,f):water_cross(w)
					else:go(w,G.anchors(f).exit,alternate)
					if w.ended:break
					if f==50:print("WATER22 HALF ",[seed,alternate,drafting,w.hp,w.gold,medicine,w.water_states.size()])
				check(not w.ended and w.max_floor==101,"actual100floor route policy survives")
				var restored=W.from_data(w.save_data())
				check(restored!=null and restored.save_data()==w.save_data() and restored.water_states==w.water_states and restored.hero_view()==w.hero_view(),"actual100floor route and water events replay")
				print("WATER22 FULL ",[seed,alternate,drafting,w.hp,w.gold,medicine,w.water_states.size(),journey_loss])
	print("Endless V22 core: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
