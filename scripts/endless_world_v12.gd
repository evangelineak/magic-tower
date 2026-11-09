class_name TowerEndlessWorldV12
extends "res://scripts/endless_world_v11.gd"
const Generation12=preload("res://scripts/endless_generation_v12.gd")
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v12.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=12 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 12
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=12;return data
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
	var data:Dictionary={"layout":Generation12.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation12.routes(seed,floor_number):
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
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation12.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:return Generation12.manifest(seed,int(contract.get("source",floor_number)))
func enemy_tokens()->Array[String]:return ["g","b","w","V","r","c","t","p"]
func base_enemy(token:String)->Dictionary:
	if token=="t":return {"hp":32,"atk":14+2*floor_number,"def":2+3*floor_number,"gold":22}
	if token=="p":return {"hp":34,"atk":18+2*floor_number,"def":1+3*floor_number,"gold":24}
	return super.base_enemy(token)
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if absi(delta.x)+absi(delta.y)==1 and tile(pos+delta) in ["t","p"]:
		var info:=preview(pos+delta)
		if not info.valid:return _reply(info.mechanic_note)
	return super.step(delta,confirmed)
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target)
	if token not in ["t","p"]:return super.preview(target)
	var foe:=enemy(token);var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var hit:int=maxi(0,combat_attack()-maxi(0,int(foe.def)-pierce));var per_hit:int=maxi(0,int(foe.atk)-combat_defense())
	var block:int=mini(3+effective_level(),per_hit) if tactic=="brace" else 0
	var cloth:int=mini(4,maxi(0,per_hit-block)) if gear=="cloak" else 0
	var ward:int=mini(6,maxi(0,per_hit-block-cloth)) if armed_item=="ward" and items.ward>0 else 0
	var info:Dictionary={"title":"棘甲守卫" if token=="t" else "回春祭司","token":token,"enemy":foe,"valid":hit>0,"survivable":false,"rounds":0,"damage":0,"raw_damage":0,"reduction":0,"gear_reduction":0,"item_reduction":0,"heal_after":0,"potential_heal":0,"net_damage":0,"reflection_damage":0,"regen_total":0,"healed_turns":0,"termination_reason":"victory","opening_damage":0,"opening_lethal":false,"charge_extra":0,"charge_extra_damage":0,"combat_atk":combat_attack(),"combat_def":combat_defense(),"gear":gear,"item":armed_item,"pierce":pierce,"enemy_base_def":base_enemy(token).def,"tactic":tactic,"effective_level":effective_level()}
	var events:Array=[];var health:int=foe.hp;var turn:=0
	# First retaliation can be completely blocked. Only after that special phase
	# is the stable-cycle no-progress criterion applicable.
	while health>0 and hit>0:
		if turn>=1 and token=="p" and per_hit>0 and hit<=3 and health>hit:
			info.valid=false;info.termination_reason="regeneration_stall";break
		turn+=1;health-=hit
		var counter:int=per_hit if health>0 else 0
		var prevented:int=block+cloth+ward if turn==1 and health>0 else 0
		var dealt:int=counter-prevented
		var healing:int=mini(3,int(foe.hp)-health) if token=="p" and dealt>0 and health>0 else 0
		health+=healing
		events.append({"counter":counter,"prevented":prevented,"dealt":dealt,"healing":healing,"reflection":2 if token=="t" else 0})
	if hit<=0:info.termination_reason="no_penetration"
	var left:=hp
	if info.valid:
		for event in events:
			info.rounds+=1
			info.reflection_damage+=event.reflection;info.raw_damage+=event.reflection;left-=event.reflection
			if left<=0:info.termination_reason="reflection_death";break
			info.raw_damage+=event.counter;info.reduction+=event.prevented;left-=event.dealt
			if info.rounds==1 and event.counter>0:info.gear_reduction=cloth;info.item_reduction=ward
			if left<=0:info.termination_reason="counter_death";break
			info.regen_total+=event.healing
			if event.healing>0:info.healed_turns+=1
		info.damage=hp-left;info.survivable=left>0
		info.potential_heal=mini(2+effective_level(),int(info.damage)) if tactic=="reap" else 0
		info.heal_after=info.potential_heal if info.survivable else 0
		info.net_damage=info.damage-info.heal_after
	info.mechanic_note="每次命中反伤2，击杀一击也反伤；先死无胜利奖励。" if token=="t" else "实际反击伤害>0才回3；完全格挡不回血，死亡后不回。"
	if not info.valid:info.mechanic_note="每轮回复抵消伤害，战斗无法结束：拒战，不扣生命或道具。" if hit>0 else "无法破防，拒战不消耗生命或道具。"
	elif info.termination_reason=="reflection_death":info.mechanic_note="命中反伤立即致死：没有后续反击、胜利奖励或收割回复。"
	info.lines=[info.mechanic_note,"玩家实战攻%d/防%d；敌生命%d/攻%d/防%d（战术后%d）" % [combat_attack(),combat_defense(),foe.hp,foe.atk,foe.def,maxi(0,int(foe.def)-pierce)],("玩家出手%d次；逐击反伤合计%d" % [info.rounds,info.reflection_damage] if token=="t" else "玩家出手%d次；实际回复%d（%d次）" % [info.rounds,info.regen_total,info.healed_turns]),"已发生原伤害%d，首反击总减免%d；实际承伤%d" % [info.raw_damage,info.reduction,info.damage],"胜后回复%d，净损耗%d；只有存活才领取%d金币。" % [info.heal_after,info.net_damage,foe.gold]]
	if not info.survivable and info.valid:info.lines.append("不能存活；确认后本局结束，反伤和反击按发生顺序停止。")
	if armed_item!="":info.lines.append("实际战斗才消耗已备道具；拒战或取消确认不消耗。")
	return info
