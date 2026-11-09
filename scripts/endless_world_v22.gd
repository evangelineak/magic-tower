class_name TowerEndlessWorldV22
extends "res://scripts/endless_world_v21.gd"
const Generation22=preload("res://scripts/endless_generation_v22.gd")
var water_states:Dictionary={}
var _water_cache_key:String=""
var _water_cache:Dictionary={}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v22.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=22 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 22
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=22;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.water_states=water_states.duplicate(true)
	w.hero_id=hero_id;w.focus=focus;w.skill_armed=skill_armed
	w.talents=talents.duplicate();w.last_kill_kind=last_kill_kind;w.legacy_id=legacy_id;w.legacy_coin_used=legacy_coin_used
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.bridges=bridges.duplicate(true);w.carts=carts.duplicate(true)
	w.runes=runes.duplicate(true)
	w.gear=gear;w.owned_gear=owned_gear.duplicate(true)
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation22.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation22.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
		sim.water_states=water_states.duplicate(true)
		sim.hero_id=hero_id;sim.focus=focus;sim.skill_armed=skill_armed
		sim.talents=talents.duplicate();sim.last_kill_kind=last_kill_kind;sim.legacy_id=legacy_id;sim.legacy_coin_used=legacy_coin_used
		sim.bridges=bridges.duplicate(true);sim.carts=carts.duplicate(true)
		sim.runes=runes.duplicate(true)
		sim.items=items.duplicate(true);sim.deltas={floor_number:deltas.get(floor_number,{}).duplicate(true)};sim._maps={floor_number:_base(floor_number)}
		var points:Array=route.points.duplicate()
		if Generation22.has_bridge(seed,floor_number) and bridges.get(floor_number,"")=="short" and points.size()==2:
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
			healed+=int(info.heal_after);sim.hp=sim.hp-int(info.damage)+int(info.heal_after);sim._consume_armed_item();sim._consume_hero_skill();sim.last_kill_kind=sim.tile(point)
		rows.append({"label":route.label,"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":count,"gold":reward})
	data.routes=rows
	if _water_manifest().present:data.water={"state":water_state(),"note":"干岸一守卫；水路两守卫，须到干岛切换水位。岛上原遗物须击败守卫，可成长后回访。"}
	return data
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation22.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:return Generation22.manifest(seed,int(contract.get("source",floor_number)))
func _water_manifest()->Dictionary:
	var key:String=str(seed)+":"+str(floor_number)
	if key!=_water_cache_key:_water_cache=Generation22.water_manifest(seed,floor_number);_water_cache_key=key
	return _water_cache
func water_state()->int:
	var info:=_water_manifest()
	return int(water_states.get(floor_number,info.initial_state)) if info.present else -1
func tile(point:Vector2i)->String:
	var token:String=super.tile(point);var info:=_water_manifest()
	if not info.present:return token
	if point in info.pools.north:return "." if water_state()==0 else "~"
	if point in info.pools.south:return "." if water_state()==1 else "~"
	return token
func grid()->Array:
	var result:Array=super.grid();var info:=_water_manifest()
	if info.present:
		for side in ["north","south"]:
			for cell in info.pools[side]:result[cell.y][cell.x]="." if water_state()==(0 if side=="north" else 1) else "~"
	return result
func water_view()->Dictionary:
	var info:=_water_manifest()
	if not info.present:return {"present":false}
	var view:Dictionary=info.duplicate(true);var reason:="";var near:=false
	for control in info.controls:
		if _adjacent(control):near=true
	if hero_id=="" or legacy_id=="":reason="请先完成英雄与传承选择。"
	elif ended:reason="旅程已结束。"
	elif actions.size()>=MAX_ACTIONS-1:reason="行动容量不足，水位未改变。"
	elif not near:reason="需站在任一洪闸阀门正交相邻的永久干地操作。"
	elif pos in info.pools.north or pos in info.pools.south:reason="只能在永久干地转闸，不能淹没玩家。"
	view.state=water_state();view.pool_states={"north":"dry" if view.state==0 else "deep","south":"dry" if view.state==1 else "deep"}
	view.available=reason=="";view.reason=reason;view.action="water_south" if view.state==0 else "water_north"
	view.title="双池洪闸：北干南深" if view.state==0 else "双池洪闸：南干北深"
	view.description="转闸后北池蓄水、南池退水；深水不能走，干岛可再次恢复来路。" if view.state==0 else "转闸后南池蓄水、北池退水；深水不能走，干岛可再次恢复来路。"
	view.description+="免费可逆，不清怪、不复制奖励、不返钥匙或专注。"
	return view
func station_tokens()->Array[String]:
	var result:Array[String]=super.station_tokens();result.append("F");return result
func options(target:Vector2i)->Array:
	if tile(target)=="F":
		var view:=water_view()
		return [{"id":view.action,"label":view.description}] if _adjacent(target) and view.available else []
	return super.options(target)
func act(id:String)->Dictionary:
	if id not in ["water_turn","water_north","water_south"]:return super.act(id)
	var view:=water_view()
	if not view.present:return _reply("本层没有洪闸。")
	if not view.available:return _reply(view.reason)
	var action:String=view.action if id=="water_turn" else id
	var chosen:int=0 if action=="water_north" else 1
	if chosen==view.state:return _reply("已经是这个水位，不重复记录动作。")
	water_states[floor_number]=chosen;_record(action)
	return {"changed":true,"message":"洪闸已转动："+("北池退水、南池蓄水。" if chosen==0 else "南池退水、北池蓄水。")+"旧自动行走路线已失效，请按新水位重新寻路。","water_changed":true}
func apply_code(code:String)->Dictionary:
	if code in ["water_north","water_south"]:return act(code)
	if code=="water_turn":return _reply("存档须使用明确目标水位，不接受翻转别名。")
	return super.apply_code(code)
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if absi(delta.x)+absi(delta.y)!=1:return super.step(delta,confirmed)
	var token:=tile(pos+delta)
	if token=="~":return _reply("这里是深水，不能涉入；到干岸或干岛的阀门调整水位。")
	if token=="F":return act("water_turn")
	return super.step(delta,confirmed)
func preview(target:Vector2i)->Dictionary:
	var info:=_water_manifest();var token:=tile(target)
	if not info.present:return super.preview(target)
	if token=="F":
		var view:=water_view()
		return {"title":view.title,"token":token,"lines":[view.description,"水路两守卫；岛上遗物仍由原强敌守护，可成长后回访。",view.reason if not view.available else "相邻直接转闸，不消耗资源；不会自动走路或战斗。"],"valid":true,"survivable":true,"damage":0}
	if target in info.pools.north or target in info.pools.south:
		return {"title":"深水：不可通行" if token=="~" else "退水浅滩：可安全行走","token":token,"lines":["水位由三处相连阀门控制，没有计时或暗伤。","转闸会交换两池通行状态；玩家只能在永久干地操作。"],"valid":true,"survivable":true,"damage":0}
	return super.preview(target)
