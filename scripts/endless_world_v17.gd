class_name TowerEndlessWorldV17
extends "res://scripts/endless_world_v16.gd"
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v17.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=17 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 17
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=17;return data
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
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation16.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:return Generation16.manifest(seed,int(contract.get("source",floor_number)))
func base_enemy(token:String)->Dictionary:
	var foe:Dictionary=super.base_enemy(token)
	foe.gold={"g":4,"b":3,"w":6,"r":5,"c":5,"t":5,"p":6,"V":18}.get(token,foe.gold)
	return foe
func tool_price(item:String)->int:return 4 if item=="ward" else 8
func exchange_price(count:int)->int:return 2 if count==1 else 4
func relic_quote()->Dictionary:
	var a:int=mini(6,6-bonus_atk);var d:int=mini(4,4-bonus_def);var level:int=mini(1,2-relic_bonus);var heal:int=mini(50,maxi(0,180-hp))
	var useful:bool=a+d+level+heal>0
	return {"atk_gain":a,"def_gain":d,"relic_gain":level,"heal_actual":heal,"hp_before":hp,"hp_after":hp+heal,"allowed":useful and not ended,"reason":"当前四项收益均为0，遗物保留原地；受伤后可回来取恢复。" if not useful else "按当前预算领取实际收益，一次领取后遗物消失。"}
func action_quote(id:String)->Dictionary:
	var nominal:int={"buy_potion":50,"enc_medicine":35,"skill_mend":35,"cargo_use":8,"cargo_open":8,"case_take":40}.get(id,0)
	if nominal==0:return {}
	var cost:int={"buy_potion":15,"enc_medicine":12,"cargo_use":0 if relief_remaining>0 else 4}.get(id,0)
	var actual:int=mini(nominal,maxi(0,180-hp));var offered:=false
	match id:
		"buy_potion":offered=_near("M") and not _used(id)
		"enc_medicine":offered=_near("M") and not _used("encounter") and Generation6.encounter_kind(seed,floor_number)=="medicine"
		"skill_mend":offered=_near("S") and not _used("skill") and lessons_used<6
		"cargo_use":offered=_near("C")
		"cargo_open":offered=cargo.state=="carried" and (_near("C") or _near("M"))
		"case_take":offered=floor_number==4 and _near("M") and messenger.state=="found"
	var reason:=""
	if ended or actions.size()>=MAX_ACTIONS-1:reason="当前不能行动。"
	elif not offered:reason="当前位置或本次选择状态不允许。"
	elif actual==0:reason="生命已满，不消耗本次补给。"
	elif gold<cost:reason="金币不足。"
	return {"hp_before":hp,"hp_after":hp+actual,"heal_nominal":nominal,"heal_actual":actual,"overflow":nominal-actual,"cost_gold":cost,"allowed":reason=="","reason":reason}
func options(target:Vector2i)->Array:
	var rows:Array=super.options(target)
	for row in rows:
		var quote:=action_quote(row.id)
		if not quote.is_empty():row.quote=quote
	return rows
func encounter_options()->Array:
	var rows:Array=super.encounter_options()
	for row in rows:
		if row.id in ["enc_ward","enc_pierce"]:
			var item:String="ward" if row.id=="enc_ward" else "pierce"
			row.label="支付%d金币：获得1%s" % [tool_price(item),"护符" if item=="ward" else "凿甲钉"]
		var quote:=action_quote(row.id)
		if not quote.is_empty():row.quote=quote
	return rows
func contract_options()->Array:
	var rows:Array=super.contract_options();var count:int=_job_manifest().reward_count
	for row in rows:
		if row.id in ["job_buyward","job_buypierce"]:
			var item:String="ward" if row.id=="job_buyward" else "pierce"
			row.label="直接买%s1件：%d金币" % ["护符" if item=="ward" else "凿甲钉",tool_price(item)]
		elif row.id in ["job_ward","job_pierce"]:row.label="花%d金币兑换%s%d件" % [exchange_price(count),"护符" if row.id=="job_ward" else "凿甲钉",count]
	return rows
func contract_view()->Dictionary:
	var view:Dictionary=super.contract_view();view.exchange_price=exchange_price(view.reward_count)
	view.body="先押12金币，清指定路线后回原层退12。再自愿花%d金币换%d件道具；不兑换不扣钱。无超时；取消未履约损失押金。" % [view.exchange_price,view.reward_count]
	return view
func case_options()->Array:
	var rows:Array=super.case_options()
	for row in rows:
		if row.id=="case_help":row.label="帮助信使：回访最多防御+3；领取时封顶部分每点转8金币"
		var quote:=action_quote(row.id)
		if not quote.is_empty():row.quote=quote
	return rows
func act(id:String)->Dictionary:
	var quote:=action_quote(id)
	if not quote.is_empty() and not quote.allowed:return _reply(quote.reason)
	if id not in ["enc_ward","enc_pierce","job_buyward","job_buypierce","job_ward","job_pierce"]:
		var result:Dictionary=super.act(id)
		if id=="job_refund" and result.get("changed",false):result.message="已退12金币；可自愿花%d金币兑换，或免费放弃。" % exchange_price(_job_manifest().reward_count)
		return result
	if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能交易。")
	var encounter:bool=id.begins_with("enc_");var offered:=false
	for row in (encounter_options() if encounter else contract_options()):
		if row.id==id:offered=true
	if not offered:return _reply("当前位置或交易状态不允许。")
	var item:String="ward" if id in ["enc_ward","job_buyward","job_ward"] else "pierce"
	var voucher:bool=id in ["job_ward","job_pierce"]
	var count:int=int(_job_manifest().reward_count) if voucher else 1
	var cost:int=exchange_price(count) if voucher else tool_price(item)
	if int(items[item])+count>9:return _reply("库存不足，交易完整保留，不扣金币。")
	if gold<cost:return _reply("需要%d金币，未扣费。" % cost)
	gold-=cost;items[item]+=count
	if encounter:_mark("encounter")
	else:_mark("job")
	if voucher:contract={}
	_record(id);return _reply("已支付%d金币，获得%d件%s。" % [cost,count,"护符" if item=="ward" else "凿甲钉"],true)
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	var token:=tile(pos+delta)
	if token=="T" and not relic_quote().allowed:return _reply(relic_quote().reason)
	if token=="B" and (int(items.ward)>7 or int(items.pierce)>7):return _reply("宝岛箱原地保留：护符与凿甲钉各需2个空位，不能部分领取。")
	var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false) and token=="B" and not ended:
		# Frozen v16 grants the first pair atomically; v17 adds the second pair.
		items.ward+=1;items.pierce+=1;result.message="宝岛箱：获得2护符与2凿甲钉，宝箱不给金币；不会重复领取。"
	return result
func preview(target:Vector2i)->Dictionary:
	var info:Dictionary=super.preview(target)
	if Generation16.has_bridge(seed,floor_number) and target==Vector2i(6,4) and tile(target)=="c":
		var old_reward:int=info.enemy.gold
		info.enemy=info.enemy.duplicate(true);info.enemy.gold=22;info.title="宝岛财宝守卫：专属赏金22"
		for i in info.lines.size():info.lines[i]=str(info.lines[i]).replace("%d金币" % old_reward,"22金币")
		info.lines.append("宝岛专属赏金22金币，仅胜利领取；普通蓄势守卫赏金不变。")
	if tile(target)=="B":
		info.title="宝岛箱：护符2件、凿甲钉2件"
		info.lines=["获得护符2件与凿甲钉2件，宝箱不给金币。","两种道具各需2个空位；不足时整箱保留可回访。"]
		info.reward={"ward":2,"pierce":2,"gold":0}
	if tile(target)=="T":
		var q:=relic_quote();info.relic_quote=q;info.title="宝库遗物：按当前预算结算，零收益保留"
		info.lines=["实际攻击+%d、防御+%d、遗物等级+%d，恢复%d生命。" % [q.atk_gain,q.def_gain,q.relic_gain,q.heal_actual],q.reason]
	return info
func bridge_view()->Dictionary:
	var view:Dictionary=super.bridge_view()
	for arm in view.arms:
		if arm.id=="loot":
			arm.reward={"ward":2,"pierce":2,"gold":0}
			arm.body="花1钥匙进入宝岛：额外守卫胜利赏22金，箱给2护符+2凿甲钉（总标价24），两库存各需空2格。要承担战损，不保证比宝库金币箱40金更优；可成长后回访。"
	return view
