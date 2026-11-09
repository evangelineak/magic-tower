class_name TowerEndlessWorldV10
extends "res://scripts/endless_world_v9.gd"
const Generation10=preload("res://scripts/endless_generation_v10.gd")
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v10.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=10 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 10
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=10;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation10.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:
	return Generation10.manifest(seed,int(contract.get("source",floor_number)))
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation10.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation10.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item"]:sim.set(key,get(key))
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
func camp_return_view()->Dictionary:
	var result:Dictionary={"available":false,"reason":"没有完全安全的同层回营路线。","target":pos,"source_floor":floor_number,"path":[],"steps":0}
	if ended:result.reason="旅程已经结束。";return result
	if _near("M"):result.reason="已经在营地旁。";return result
	var queue:Array[Vector2i]=[pos];var parents:Dictionary={pos:pos};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		var adjacent:=false
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if tile(p+d)=="M":adjacent=true
		if adjacent and p!=pos:
			var route:Array[Vector2i]=[];var q:=p
			while q!=pos:route.push_front(q);q=parents[q]
			result.path=route;result.steps=route.size();result.target=p
			if actions.size()+route.size()>MAX_ACTIONS-1:result.reason="剩余行动额度不足以走完整条路，未移动。";return result
			result.available=true;result.reason="仅沿本层已清空地行走%d步，不穿越楼梯或互动对象。" % route.size();return result
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d
			if not parents.has(q) and tile(q)==".":parents[q]=p;queue.append(q)
	return result
func return_to_camp()->Dictionary:
	var view:=camp_return_view()
	if not view.available:return _reply(view.reason)
	# Preflight the exact entire path before touching this world.
	var sim=clone();var source:=floor_number
	for point in view.path:
		if sim.floor_number!=source or sim.tile(point)!=".":return _reply("回营路径已不安全，未移动。")
		var checked:Dictionary=sim.step(point-sim.pos)
		if not checked.get("changed",false):return _reply("无法走完整条安全路线，未移动。")
	for point in view.path:step(point-pos)
	return {"changed":true,"message":"已沿清空路径%d步回到本层营地；没有跨层或沿途互动。" % view.steps,"steps":view.steps}
func act(id:String)->Dictionary:
	if id=="camp_walk":return return_to_camp()
	return super.act(id)
func apply_code(code:String)->Dictionary:
	if code=="camp_walk":return _reply("回营存档只能包含逐格方向事件。")
	return super.apply_code(code)
