class_name TowerEndlessWorldV7
extends "res://scripts/endless_world_v6.gd"
const Generation7=preload("res://scripts/endless_generation_v7.gd")
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v7.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=7 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 7
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=7;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation7.generate(seed,f).grid
	return _maps[f]
func enemy_tokens()->Array[String]:return ["g","b","w","V","r","c"]
func enemy(token:String)->Dictionary:
	if token not in ["r","c"]:return super.enemy(token)
	var armor:int=3+3*floor_number
	if armed_item=="pierce" and items.pierce>0:armor=maxi(0,armor-6)
	return {"hp":24 if token=="r" else 20,"atk":14+2*floor_number,"def":armor,"gold":18 if token=="r" else 22}
func preview(target:Vector2i)->Dictionary:
	var info:Dictionary=super.preview(target);var token:=tile(target)
	if token not in ["r","c"]:return info
	var foe:Dictionary=enemy(token)
	var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var hit:int=maxi(0,atk-maxi(0,int(foe.def)-pierce))
	var turns:int=ceili(float(foe.hp)/hit) if hit>0 else 0
	var per_hit:int=maxi(0,int(foe.atk)-defense)
	var opening:int=per_hit if token=="r" else 0
	var opening_fatal:bool=hit>0 and opening>=hp
	var counters:int=maxi(0,turns-1) if not opening_fatal else 0
	var normal:int=counters*per_hit
	var charged:int=per_hit if token=="c" and counters>0 else 0
	var first_counter:int=per_hit+(per_hit if token=="c" else 0) if counters>0 else 0
	var stance_block:int=mini(3+effective_level(),first_counter) if tactic=="brace" else 0
	var item_block:int=mini(6,maxi(0,first_counter-stance_block)) if armed_item=="ward" and items.ward>0 else 0
	var reduction:int=stance_block+item_block
	var raw:int=opening+normal+charged
	var damage:int=maxi(0,raw-reduction)
	var can_live:bool=hit>0 and damage<hp
	var heal:int=mini(2+effective_level(),damage) if tactic=="reap" and hit>0 else 0
	var base_hit:int=maxi(0,atk-(3+3*floor_number))
	var base_turns:int=ceili(float(foe.hp)/base_hit) if base_hit>0 else 0
	var base_counters:int=maxi(0,base_turns-1) if not opening_fatal else 0
	info.base_valid=base_hit>0
	info.base_damage=opening+base_counters*per_hit+(per_hit if token=="c" and base_counters>0 else 0) if base_hit>0 else 0
	info.title="截击斥候：先制不可由架盾或护符减免" if token=="r" else "蓄势重卫：首个反击双倍"
	info.enemy=foe;info.valid=hit>0;info.survivable=can_live;info.rounds=0 if opening_fatal else turns
	info.opening_damage=opening;info.opening_lethal=opening_fatal;info.normal_counter_damage=normal;info.charge_extra_damage=charged;info.charge_extra=charged
	info.mechanic_note="先制%d立即致死：玩家未出手，无反击和胜利奖励。" % opening if opening_fatal else ("先制%d在玩家出手前；架盾/护符只减反击。" % opening if token=="r" else "首反击蓄力额外%d伤害，已计入总承伤。" % charged)
	info.first_counter_raw=first_counter;info.raw_damage=raw;info.reduction=reduction;info.item_reduction=item_block
	info.damage=damage;info.potential_heal=heal;info.heal_after=heal if can_live else 0;info.net_damage=damage-int(info.heal_after)
	info.pierce=pierce;info.enemy_base_def=3+3*floor_number
	info.lines=["生命%d / 攻击%d / 原防%d → 道具后%d → 战术后%d" % [foe.hp,foe.atk,info.enemy_base_def,foe.def,maxi(0,int(foe.def)-pierce)],"先制%d + 普通反击%d + 蓄力额外%d = 原伤害%d" % [opening,normal,charged,raw],"首反击：架盾减%d / 护符减%d；先制不享受这两种减伤。" % [stance_block,item_block],"实际承伤%d / 胜后恢复%d / 净损耗%d" % [damage,info.heal_after,info.net_damage]]
	if opening_fatal:info.lines.append("先制立即致死：玩家尚未出手，没有后续反击、击杀、金币或回复。")
	elif not info.valid:info.lines.append("无法破防；拒战不扣生命或道具。")
	elif not can_live:info.lines.append("这场战斗不能存活；不会获得胜利奖励或战后回复。")
	else:info.lines.append("胜利可获%d金币；没有随机伤害。" % foe.gold)
	if armed_item!="":info.lines.append("本场实际结算消耗1件已装备道具；仅查看或取消不消耗。")
	return info
func _cargo_summary()->String:
	match cargo.state:
		"carried":return "运输中：第%d层箱 → 第%d层商人。可在箱/商人旁拆封取20生命，放弃奖励。" % [cargo.source,cargo.target]
		"opened":return "运输箱已拆封，改造奖励已放弃。"
		"delivered":return "已交付：在目标层商人旁三选一改造。" if cargo.reward=="" else "本局运输委托已完成，改造只领取一次。"
	return "本局可接一次委托：把入口20生命补给运到两层后，换三选一改造。"
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation7.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation7.routes(seed,floor_number):
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
