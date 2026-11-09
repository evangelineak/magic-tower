class_name TowerEndlessWorldV15
extends "res://scripts/endless_world_v14.gd"
const Generation15=preload("res://scripts/endless_generation_v15.gd")
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v15.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=15 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 15
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=15;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.runes=runes.duplicate(true)
	w.gear=gear;w.owned_gear=owned_gear.duplicate(true)
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation15.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation15.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
		sim.runes=runes.duplicate(true)
		sim.items=items.duplicate(true);sim.deltas={floor_number:deltas.get(floor_number,{}).duplicate(true)};sim._maps={floor_number:_base(floor_number)}
		var points:Array=route.points.duplicate()
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
	if not _maps.has(f):_maps.clear();_maps[f]=Generation15.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:return Generation15.manifest(seed,int(contract.get("source",floor_number)))
