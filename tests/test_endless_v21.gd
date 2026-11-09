extends SceneTree
var W=preload("res://scripts/endless_world_v21.gd")
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
func _init():
	var counts:Array=[]
	for i in 9:counts.append({})
	for seed in range(5000):
		var w=W.new_run(seed);var draft:Array=w.talent_draft();var all:Array=[]
		for tier in 3:all.append_array(draft[tier])
		var distinct:Dictionary={}
		for id in all:distinct[id]=true
		check(all.size()==9 and distinct.size()==9,"nine seeded cards split without repeats")
		for i in 9:counts[i][all[i]]=int(counts[i].get(all[i],0))+1
	for row in counts:
		check(row.size()==9,"every slot samples every talent")
		for count in row.values():check(count>=400 and count<=700,"finite sample guards strong shuffle bias")
	for tier in 3:
		for id in W.talent_catalog():
			var count:int=counts[tier*3][id]+counts[tier*3+1][id]+counts[tier*3+2][id]
			check(count>=1400 and count<=1900,"tier inclusion finite-sample balance")
	var pending=W.new_run(42);pending.act("hero_ranger")
	check(not pending.step(Vector2i.RIGHT).changed and not pending.act("skill_use").changed,"hero alone cannot start")
	check(not pending.act("legacy_bad").changed,"unknown legacy refused")
	check(pending.act("legacy_none").changed,"no legacy remains free choice")
	check(not pending.act("legacy_kit").changed,"legacy cannot be changed")
	check(W.from_data({"version":21,"mode":"endless","seed":42,"actions":["hero_ranger","R"]})==null,"missing legacy prefix rejects replay")
	for id in ["none","kit","coin","mind"]:
		var w=make("scholar",id);var expected_focus:int={"none":2,"kit":1,"coin":1,"mind":3}[id]
		check(w.focus==expected_focus and w.hp==(120 if id=="mind" else 150),"legacy actual starting exchange")
		check(w.items.ward==(1 if id=="kit" else 0) and w.items.pierce==(1 if id=="kit" else 0),"kit tools exact")
		var saved=W.from_data(w.save_data());check(saved!=null and saved.focus==w.focus and saved.hp==w.hp and saved.items==w.items,"startup prefix replays independently of device profile")
	var delayed=make();var draft:Array=delayed.talent_draft();var f:int=delayed.focus
	check(not delayed.talent_view().available,"cannot pick before kills")
	delayed.kills=15;delayed.act("skill_use")
	check(not delayed.act("tal_"+draft[0][0]).changed,"must cancel prepared skill before changing talent cost")
	delayed.act("skill_cancel")
	for tier in 3:
		check(delayed.talent_view().offers[0].id==draft[tier][0],"deferred tiers keep fixed offers")
		check(delayed.act("tal_"+draft[tier][0]).changed,"delayed sequential pick")
		check(delayed.focus==f,"learning never refills focus")
	check(not delayed.talent_view().available and delayed.talents.size()==3,"hard three-talent cap")
	var potion=make("scholar");potion.talents.append("mender");potion.hp=100;potion.gold=15;potion.pos=Vector2i(2,1)
	var q:Dictionary=potion.action_quote("buy_potion");check(q.heal_actual==54 and potion.act("buy_potion").changed and potion.hp==154 and potion.gold==0,"mender potion quote and charge exact")
	potion.talents.append("overload");potion.focus=2;potion.hp=100
	check(potion.act("skill_use").changed and potion.hp==146 and potion.focus==0,"overload+mender scholar46 costs2")
	var reserve=make();reserve.talents.append("reserve");reserve.floor_number=3;reserve.max_floor=3;reserve.pos=Vector2i(12,13);reserve.focus=3
	check(reserve.step(Vector2i.RIGHT).changed and reserve.floor_number==4 and reserve.focus==4,"reserve milestone really reaches cap4")
	reserve.floor_number=7;reserve.max_floor=7;reserve.pos=Vector2i(12,13)
	check(reserve.step(Vector2i.RIGHT).changed and reserve.focus==4,"full cap4 overflow does not shrink to old cap3")
	var coin=make("ranger","coin",42)
	for floor in range(1,5):
		first_supply(coin);camp(coin)
		if coin.vault_kind()=="gold":
			go(coin,Vector2i(3,3));go(coin,Vector2i(9,3));check(coin.step(Vector2i.RIGHT,true).changed,"real coin legacy door costs key")
			go(coin,Vector2i(11,3));var old:int=coin.gold;var quote:Dictionary=coin.vault_quote()
			check(quote.gold==52 and coin.step(Vector2i.RIGHT).changed and coin.gold-old==52 and coin.legacy_coin_used,"first real treasury gets one legacy bonus")
			break
		go(coin,G.anchors(floor).exit)
	var coin_saved=W.from_data(coin.save_data());check(coin_saved!=null and coin_saved.legacy_coin_used and coin_saved.gold==coin.gold,"earned treasury bonus fully replays")
	var overflow=make("ranger","coin");
	for floor in range(1,5):
		if overflow.vault_kind(floor)=="gold":overflow.floor_number=floor;break
	overflow.pos=Vector2i(11,3);overflow.gold=overflow.MAX_STAT
	check(not overflow.step(Vector2i.RIGHT).changed and not overflow.legacy_coin_used,"zero gold capacity preserves cache and bonus")
	overflow.gold-=1;q=overflow.vault_quote();check(q.gold==1 and q.coin_bonus_actual==0,"bonus overflow quote does not promise12")
	check(overflow.step(Vector2i.RIGHT).changed and overflow.legacy_coin_used,"partial ceiling payout consumes whole one-shot entitlement")
	use_skills=true
	for seed in [0,42]:
		for hero in ["warden","ranger","scholar"]:
			for drafting in [false,true]:
				var legacy:String={"warden":"kit","ranger":"coin","scholar":"mind"}[hero] if drafting else "none"
				var w=make(hero,legacy,seed);var alternate:bool=seed==42;var medicine:=0;journey_loss=0
				for floor in range(1,101):
					if drafting:choose_cards(w)
					first_supply(w,alternate);camp(w,alternate)
					if hero=="scholar" and w.focus>=w.skill_cost() and w.hp<=180-w.skill_heal():w.act("skill_use")
					if w.hp<=130 and w.gold>=15:
						if w.act("buy_potion").changed:medicine+=15
					go(w,G.anchors(floor).exit,alternate)
					if w.ended:break
					if floor==50:print("BUILD21 HALF ",[seed,hero,drafting,w.hp,w.gold,w.focus,medicine,w.talents])
				check(not w.ended and w.max_floor==101,"real first-card policy survives100 without vault requirement")
				var restored=W.from_data(w.save_data())
				check(restored!=null and restored.save_data()==w.save_data() and restored.hero_view()==w.hero_view() and restored.talent_view()==w.talent_view() and restored.last_kill_kind==w.last_kill_kind,"complete 100-floor build history replays")
				print("BUILD21 FULL ",[seed,hero,drafting,w.hp,w.gold,w.focus,medicine,w.talents,journey_loss])
	print("Endless V21 core: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
