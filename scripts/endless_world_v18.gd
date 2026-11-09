class_name TowerEndlessWorldV18
extends "res://scripts/endless_world_v17.gd"
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v18.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=18 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 18
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=18;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.bridges=bridges.duplicate(true)
	w.runes=runes.duplicate(true)
	w.gear=gear;w.owned_gear=owned_gear.duplicate(true)
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation16.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation16.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
		sim.bridges=bridges.duplicate(true)
		sim.runes=runes.duplicate(true)
		sim.items=items.duplicate(true);sim.deltas={floor_number:deltas.get(floor_number,{}).duplicate(true)};sim._maps={floor_number:_base(floor_number)}
		var points:Array=route.points.duplicate()
		if Generation16.has_bridge(seed,floor_number) and bridges.get(floor_number,"")=="short" and points.size()==2:
			points.erase(Vector2i(8,8));route.label="钥匙短桥：仍需第二守卫"
		if floor_number%2==0:points.reverse()
		var damage:=0;var healed:=0;var count:=0;var valid:=true;var alive:=true;var reward:=0
		for point in points:
			if sim.tile(point) not in enemy_tokens():continue
			count+=1
			var info:Dictionary=sim.preview(point);valid=valid and info.valid;reward+=int(info.enemy.gold)
			if not alive:continue
			damage+=int(info.damage)
			if not info.survivable:alive=false;continue
			healed+=int(info.heal_after);sim.hp=sim.hp-int(info.damage)+int(info.heal_after);sim._consume_armed_item()
		rows.append({"label":route.label,"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":count,"gold":reward})
	data.routes=rows;return data
func vault_kind(f:int=-1)->String:
	if f<0:f=floor_number
	if f<1 or f>MAX_FLOOR:return ""
	var block:int=int((f-1)/4)
	var kinds:Array=["gold","medicine","ward","pierce"]
	var state:int=Generation16.mix(seed,block+1,3109)
	for i in range(3,0,-1):
		state=Generation16.mix(state,block+1,47*i)
		var j:int=state%(i+1)
		var swap=kinds[i];kinds[i]=kinds[j];kinds[j]=swap
	return kinds[(f-1)%4]
func vault_quote(target:Vector2i=Vector2i(12,3))->Dictionary:
	var kind:=vault_kind();var names:Dictionary={"gold":"钱库：40金币","medicine":"药库：直接恢复最多100生命","ward":"护符库：整批6件","pierce":"凿甲钉库：整批3件"}
	var nominal:int={"gold":40,"medicine":100,"ward":6,"pierce":3}[kind]
	var actual:=nominal
	if kind=="medicine":actual=mini(nominal,maxi(0,HP_CAP-hp))
	if kind=="gold":actual=mini(nominal,maxi(0,MAX_STAT-gold))
	var spaces:Dictionary={"ward":6 if kind=="ward" else 0,"pierce":3 if kind=="pierce" else 0}
	var available:bool=target==Vector2i(12,3) and tile(target)=="$"
	var reason:=""
	if not available:reason="此处宝库奖励已领取或不是宝库箱。"
	elif ended:reason="旅程已结束。"
	elif actions.size()>=MAX_ACTIONS-1:reason="动作容量不足，请结束本局。"
	elif kind=="medicine" and actual==0:reason="生命已满，药库保留，可受伤后回访。"
	elif kind=="gold" and actual==0:reason="金币达到安全上限，钱库保留。"
	elif int(items.ward)+spaces.ward>9 or int(items.pierce)+spaces.pierce>9:reason="需完整容纳%d件%s；整批保留，不能部分领取。" % [nominal,"护符" if kind=="ward" else "凿甲钉"]
	return {"kind":kind,"title":names[kind],"nominal":nominal,"actual":actual,"heal":actual if kind=="medicine" else 0,"gold":actual if kind=="gold" else 0,"ward":6 if kind=="ward" else 0,"pierce":3 if kind=="pierce" else 0,"allowed":reason=="","reason":reason,"required_spaces":spaces,"available":available,"hp_before":hp,"hp_after":hp+(actual if kind=="medicine" else 0),"overflow":nominal-actual if kind=="medicine" else 0}
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if absi(delta.x)+absi(delta.y)!=1:return super.step(delta,confirmed)
	var target:=pos+delta;var token:=tile(target)
	if token=="D" and not confirmed:
		var result:Dictionary=super.step(delta,confirmed)
		if result.get("confirm",false):
			var q:=vault_quote()
			var detail:="实际可得%d金币。" % q.gold
			if q.kind=="medicine":detail="生命%d → %d，实际恢复%d；未用药效%d不保留。" % [q.hp_before,q.hp_after,q.heal,q.overflow]
			elif q.kind in ["ward","pierce"]:detail="当前%d/9，整批%d件需%d空位。" % [items[q.kind],q.nominal,q.nominal]
			result.message="消耗1把钥匙开门？门后%s。%s%s" % [q.title,detail,"现在可领取。" if q.allowed else q.reason+"仍可开门，奖励原地保留。"]
			result.vault_quote=q
		return result
	if token!="$":return super.step(delta,confirmed)
	var q:=vault_quote(target)
	if not q.allowed:return _reply(q.reason)
	gold+=int(q.gold);hp+=int(q.heal);items.ward+=int(q.ward);items.pierce+=int(q.pierce)
	_consume(target);pos=target
	for code in DIRECTIONS:
		if DIRECTIONS[code]==delta:_record(code);break
	return _reply("已领取%s：实际%d%s；不会重复领取。" % [q.title,q.actual,"生命" if q.kind=="medicine" else ("金币" if q.kind=="gold" else "件")],true)
func preview(target:Vector2i)->Dictionary:
	var info:Dictionary=super.preview(target)
	if tile(target) in ["$","D"]:
		var q:=vault_quote();info.vault_quote=q
		info.title=q.title if tile(target)=="$" else "宝库门：消耗1钥匙，门后"+q.title
		info.lines=["内容由楼层种子固定；每4层钱、药、护符、凿甲钉各一库。"]
		if q.kind=="medicine":info.lines.append("直接治疗：生命%d → %d，实际+%d；未用药效%d不会装入背包。" % [q.hp_before,q.hp_after,q.heal,q.overflow])
		elif q.kind in ["ward","pierce"]:info.lines.append("整批%d件；需要%d个空位，容量不足不会领取。" % [q.nominal,q.nominal])
		else:info.lines.append("实际可得%d金币。" % q.gold)
		info.lines.append("现在可领取；步入宝箱领取。" if q.allowed else q.reason)
		if tile(target)=="D":info.lines.append("当前不能领取也可确认开门，奖励留待回访。")
	return info
func bridge_view()->Dictionary:
	var view:Dictionary=super.bridge_view()
	for arm in view.arms:
		if arm.id=="loot":arm.body="花1钥匙进入宝岛：额外守卫胜利赏22金，箱给2护符+2凿甲钉（总标价24），两库存各需空2格。要承担战损；普通宝库内容须看本层预览，可成长后回访。"
	return view
