class_name TowerEndlessWorldV5
extends "res://scripts/endless_world_v4.gd"
const Generation5=preload("res://scripts/endless_generation_v5.gd")
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v5.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=5 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 5
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=5;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func _base(f:int)->Array:
	if not _maps.has(f):
		_maps.clear();_maps[f]=Generation5.generate(seed,f).grid
	return _maps[f]
func options(target:Vector2i)->Array:
	var rows:Array=super.options(target)
	for row in rows:
		if row.id=="skill_mend":row.label="急救：恢复35生命；放弃攻防增长，仍获战术训练（普通上限3）"
		elif row.id in ["skill_power","skill_guard"]:row.label+="；战术训练+1（普通上限3）"
	return rows
func witness_targets()->Array[Vector2i]:
	var y:int=1 if floor_number%2==1 else 13
	return [Vector2i(2 if floor_number%2==1 else 12,y),Vector2i(3 if floor_number%2==1 else 11,y),Generation5.anchors(floor_number).exit]
func summary()->Dictionary:
	var data:Dictionary=super.summary();data.tactic=tactic_data()
	var routes:Array=[]
	for route in Generation5.routes(seed,floor_number):
		var points:Array=route.points.duplicate()
		if floor_number%2==0:points.reverse()
		var hp_left:int=hp;var damage:=0;var recovery:=0;var remaining:=0;var valid:=true;var survivable:=true;var gold_reward:=0
		for point in points:
			if tile(point) not in enemy_tokens():continue
			remaining+=1
			var info:=preview(point);valid=valid and info.valid;gold_reward+=int(info.enemy.gold)
			if not survivable:continue
			if not info.valid or int(info.damage)>=hp_left:survivable=false;damage+=int(info.damage);continue
			damage+=int(info.damage);var heal:int=mini(int(info.potential_heal),int(info.damage))
			recovery+=heal;hp_left=hp_left-int(info.damage)+heal
		routes.append({"label":route.label,"damage":damage,"net_damage":damage-recovery,"heal_after":recovery,"valid":valid,"survivable":survivable,"remaining":remaining,"gold":gold_reward})
	data.routes=routes;data.layout=Generation5.layout_name(seed,floor_number)
	return data
func preview(target:Vector2i)->Dictionary:
	var info:Dictionary=super.preview(target)
	match tile(target):
		"S":info.lines=["每层三选一：攻击+2 / 防御+1 / 恢复35生命。","三种选择均获战术训练+1，普通训练上限3。","急救放弃本层攻防增长，但不放弃战术训练。"]
		"T":info.lines=["一次领取：攻击+6、防御+4、恢复50生命。","同时获得额外战术等级+1；遗物加成最多2级。","普通训练最多3，含遗物有效战术等级最多5。"]
		"M":info.lines=["商店每层各限购一次：药15金币 / 武器25 / 护甲20。","在商人旁按B可免费切换战术，不消耗资源。","运输交付和已知事件也在对应楼层营地办理。"]
		"C":info.lines=["立即使用：恢复20生命，并移除箱子。","或本局一次运输：牺牲现在20生命，运至两层后的商人。","运输途中可在箱或商人旁拆封，取回20生命但放弃改造。"]
		"a":info.lines=["拾取后攻击+3、防御+2，每层一次。","这是基础路线预算中的训练资源，不提升战术训练等级。"]
	return info
