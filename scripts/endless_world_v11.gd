class_name TowerEndlessWorldV11
extends "res://scripts/endless_world_v10.gd"
var gear:=""
var owned_gear:Dictionary={"cloak":false,"lens":false}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v11.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=11 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 11
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=11;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.gear=gear;w.owned_gear=owned_gear.duplicate(true)
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation10.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation10.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
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
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target)
	if token not in enemy_tokens():return super.preview(target)
	var base:=base_enemy(token);var foe:=enemy(token)
	var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var hit:int=maxi(0,combat_attack()-maxi(0,int(foe.def)-pierce));var turns:int=ceili(float(foe.hp)/hit) if hit>0 else 0
	var per_hit:int=maxi(0,int(foe.atk)-combat_defense());var opening:int=per_hit if token=="r" else 0
	var opening_fatal:bool=hit>0 and opening>=hp
	var counters:int=maxi(0,turns-1) if not opening_fatal else 0
	var normal:int=counters*per_hit;var extra:int=per_hit if token=="c" and counters>0 else 0
	var first:int=per_hit+(per_hit if token=="c" else 0) if counters>0 else 0
	var block:int=mini(3+effective_level(),first) if tactic=="brace" else 0
	var gear_block:int=mini(4,maxi(0,first-block)) if gear=="cloak" else 0
	var tool_block:int=mini(6,maxi(0,first-block-gear_block)) if armed_item=="ward" and items.ward>0 else 0
	var raw:int=opening+normal+extra;var loss:int=maxi(0,raw-block-gear_block-tool_block)
	var valid:bool=hit>0;var survive:bool=valid and loss<hp
	var potential:int=mini(2+effective_level(),loss) if tactic=="reap" and valid else 0
	var recovery:int=potential if survive else 0
	var base_hit:int=maxi(0,combat_attack()-int(base.def));var base_turns:int=ceili(float(base.hp)/base_hit) if base_hit>0 else 0
	var base_counters:int=maxi(0,base_turns-1) if not opening_fatal else 0
	var names:Dictionary={"g":"铁甲关尉","w":"烈法守卫","r":"截击斥候","c":"蓄势重卫","b":"持久哨兵","V":"旧层宝库守卫"}
	var info:Dictionary={"title":names[token],"token":token,"enemy":foe,"valid":valid,"survivable":survive,"rounds":0 if opening_fatal else turns,"opening_damage":opening,"opening_lethal":opening_fatal,"normal_counter_damage":normal,"charge_extra":extra,"charge_extra_damage":extra,"first_counter_raw":first,"raw_damage":raw,"reduction":block+gear_block+tool_block,"gear_reduction":gear_block,"combat_atk":combat_attack(),"combat_def":combat_defense(),"gear":gear,"item_reduction":tool_block,"damage":loss,"potential_heal":potential,"heal_after":recovery,"net_damage":loss-recovery,"pierce":pierce,"enemy_base_def":base.def,"base_valid":base_hit>0,"base_damage":opening+base_counters*per_hit+(per_hit if token=="c" and base_counters>0 else 0),"tactic":tactic,"effective_level":effective_level(),"item":armed_item,"item_pierce":6 if armed_item=="pierce" and items.pierce>0 else 0}
	info.mechanic_note="先制立即致死，玩家未出手，无胜利奖励。" if opening_fatal else "先制%d / 首反击蓄力额外%d，均已计入承伤。" % [opening,extra]
	info.lines=["固定档案：生命%d / 攻击%d / 原防%d → 道具后%d → 战术后%d" % [foe.hp,foe.atk,base.def,foe.def,maxi(0,int(foe.def)-pierce)],"先制%d + 普通反击%d + 蓄力%d = 原伤害%d" % [opening,normal,extra,raw],"架盾减%d / 披肩减%d / 护符减%d；承伤%d" % [block,gear_block,tool_block,loss],"胜后回复%d / 净损耗%d；先活过承伤才能回复。" % [recovery,loss-recovery]]
	info.lines.insert(0,"玩家实战攻击%d（基础%d）/ 防御%d（基础%d）" % [combat_attack(),atk,combat_defense(),defense])
	if not valid:info.lines.append("无法破防，拒战不消耗道具。")
	elif not survive:info.lines.append(info.mechanic_note if opening_fatal else "无法存活，不获击杀/金币/回复。")
	else:info.lines.append("胜利获得%d金币；没有暗骰或跟随玩家动态升级。" % foe.gold)
	if armed_item!="":info.lines.append("实际战斗结算消耗一件已装备道具，查看不耗。")
	return info
func combat_attack()->int:return maxi(0,atk+(-2 if gear=="cloak" else (3 if gear=="lens" else 0)))
func combat_defense()->int:return maxi(0,defense-(3 if gear=="lens" else (1 if gear=="cloak" else 0)))
func gear_options()->Array:
	if ended or actions.size()>=MAX_ACTIONS-1 or not _near("M"):return []
	var rows:Array=[]
	for id in ["cloak","lens"]:
		var name:String="壁垒披肩" if id=="cloak" else "猎手镜"
		if not owned_gear[id]:rows.append({"id":"buy_"+id,"label":"购买%s：40金币，本局永久持有" % name})
		elif gear!=id:rows.append({"id":"gear_"+id,"label":"免费装备"+name})
	if gear!="":rows.append({"id":"gear_none","label":"免费卸下装备，恢复无装备战斗值"})
	return rows
func gear_view()->Dictionary:
	var entries:Array=[]
	for id in ["cloak","lens"]:
		entries.append({"id":id,"name":"壁垒披肩" if id=="cloak" else "猎手镜","owned":owned_gear[id],"equipped":gear==id,"price":40,"effects":"实战攻击-2、防御-1（最低0）；首个反击最多减4，不挡先制。" if id=="cloak" else "实战攻击+3、防御-3（最低0）；可能少一轮，也可能受到更多伤害。"})
	return {"title":"持久装备：仅一个槽位","gear":gear,"owned":owned_gear.duplicate(true),"base_atk":atk,"base_def":defense,"effective_atk":combat_attack(),"effective_def":combat_defense(),"body":"每件40金币，本局只买一次；购买不自动穿戴。只在营地切换或卸下，永久成长不变，不恢复生命。","status":"仅可查看：请回营地操作。" if not _near("M") else ("旅程已结束。" if ended else "已装备："+{"":"无","cloak":"壁垒披肩","lens":"猎手镜"}[gear]),"entries":entries,"options":gear_options()}
func apply_code(code:String)->Dictionary:
	if code in ["buy_cloak","buy_lens","gear_cloak","gear_lens","gear_none"]:return act(code)
	return super.apply_code(code)
func act(id:String)->Dictionary:
	if id not in ["buy_cloak","buy_lens","gear_cloak","gear_lens","gear_none"]:return super.act(id)
	if ended or actions.size()>=MAX_ACTIONS-1 or not _near("M"):return _reply("需在本层营地旁，旅程尚未结束且有行动额度。")
	var selected:String=id.trim_prefix("buy_") if id.begins_with("buy_") else id.trim_prefix("gear_")
	if id.begins_with("buy_"):
		if owned_gear[selected]:return _reply("已经持有，不重复扣费。")
		if gold<40:return _reply("购买需要40金币，没有扣钱。")
		gold-=40;owned_gear[selected]=true
	else:
		if selected=="none":selected=""
		if selected==gear:return _reply("装备未变化，不重复记录。")
		if selected!="" and not owned_gear[selected]:return _reply("尚未购买这件装备。")
		gear=selected
	_record(id);return _reply("装备选择已保存；基础成长、生命和已持有装备不变。",true)
