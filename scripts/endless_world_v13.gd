class_name TowerEndlessWorldV13
extends "res://scripts/endless_world_v12.gd"
const Generation13=preload("res://scripts/endless_generation_v13.gd")
var runes:Dictionary={}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v13.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=13 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 13
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=13;return data
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
	var data:Dictionary={"layout":Generation13.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation13.routes(seed,floor_number):
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
	if not _maps.has(f):_maps.clear();_maps[f]=Generation13.generate(seed,f).grid
	return _maps[f]
func _rune_kind()->String:return Generation13.rune_info(seed,floor_number).kind if runes.get(floor_number,false) else ""
func rune_view()->Dictionary:
	var data:=Generation13.rune_info(seed,floor_number);var entry:Vector2i=data.entry
	var near:bool=pos==entry or absi(pos.x-entry.x)+absi(pos.y-entry.y)==1
	var active:bool=runes.get(floor_number,false)
	var before=clone();before.runes.erase(floor_number)
	var after=clone();after.runes[floor_number]=true
	var effect:=false
	for y in 15:
		for x in 15:
			var p:=Vector2i(x,y)
			if tile(p) not in enemy_tokens():continue
			var a:Dictionary=before.preview(p);var b:Dictionary=after.preview(p)
			if data.kind=="silence":
				# Do not mistake the new lethal-event truncation for a rune effect.
				if int(a.get("heal_after",0))>0 or (tile(p)=="p" and (int(a.get("regen_total",0))>0 or a.valid!=b.valid)):effect=true
			else:
				for key in ["damage","net_damage","valid","survivable","rounds","heal_after","reflection_damage","regen_total"]:
					if a.get(key,0)!=b.get(key,0):effect=true
	var reason:=""
	if ended:reason="旅程已结束。"
	elif active:reason="本层铭文已生效，永久保留，不能重复付费或撤销。"
	elif not near:reason="需站在本层入口楼梯上或正交相邻；出口不能激活。"
	elif not effect:reason="当前剩余敌人与构筑没有实际效果，不收金币。"
	elif gold<data.price:reason="需要%d金币，当前%d；没有扣费。" % [data.price,gold]
	elif actions.size()>=MAX_ACTIONS-1:reason="行动额度不足；没有扣费。"
	var allowed:bool=reason==""
	data.active=active;data.available=allowed;data.near_entry=near;data.reason=reason;data.floor=floor_number
	data.body="付18金币永久改变本层：每战玩家首击×2；敌首次主动攻击×2（斥候先制优先、蓄势首反击×4）；棘甲首次反伤4。固定减伤不翻倍。" if data.kind=="shock" else "付10金币永久改变本层：双方战斗内不能回血，祭司恢复与收割均失效；战斗外药物、补给正常。"
	data.before_routes=before.summary().routes;data.after_routes=after.summary().routes
	data.options=[{"id":"rune_on","label":"支付%d金币，永久激活本层%s" % [data.price,data.title]}] if allowed else []
	return data
func rune_options()->Array:return rune_view().options
func act(id:String)->Dictionary:
	if id not in ["rune_on","rune_on!"]:return super.act(id)
	var view:=rune_view()
	if not view.available:return _reply(view.reason)
	if id=="rune_on":return {"changed":false,"confirm":true,"message":"支付%d金币激活%s？本层永久生效，回访保留，不能撤销；不消耗已备道具。" % [view.price,view.title]}
	gold-=int(view.price);runes[floor_number]=true;_record(id)
	return _reply("已支付%d金币，本层%s永久生效。" % [view.price,view.title],true)
func apply_code(code:String)->Dictionary:
	if code=="rune_on!":return act(code)
	if code=="rune_on":return _reply("未确认的铭文动作不能进入存档。")
	return super.apply_code(code)
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target);var kind:=_rune_kind()
	if kind=="" or token not in enemy_tokens():return super.preview(target)
	var shock:bool=kind=="shock";var silent:bool=kind=="silence"
	var foe:=enemy(token);var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var hit:int=maxi(0,combat_attack()-maxi(0,int(foe.def)-pierce));var per_hit:int=maxi(0,int(foe.atk)-combat_defense())
	var opening:int=per_hit*(2 if shock else 1) if token=="r" else 0
	var first:int=per_hit*(2 if token=="c" else 1)*(2 if shock and token!="r" else 1)
	var block:int=mini(3+effective_level(),first) if tactic=="brace" else 0
	var cloth:int=mini(4,maxi(0,first-block)) if gear=="cloak" else 0
	var ward:int=mini(6,maxi(0,first-block-cloth)) if armed_item=="ward" and items.ward>0 else 0
	var names:Dictionary={"g":"铁甲关尉","b":"持久哨兵","w":"烈法守卫","V":"旧层宝库守卫","r":"截击斥候","c":"蓄势重卫","t":"棘甲守卫","p":"回春祭司"}
	var info:Dictionary={"title":names[token],"token":token,"enemy":foe,"valid":hit>0,"survivable":false,"rounds":0,"damage":0,"raw_damage":0,"reduction":0,"gear_reduction":0,"item_reduction":0,"heal_after":0,"potential_heal":0,"net_damage":0,"reflection_damage":0,"regen_total":0,"healed_turns":0,"termination_reason":"victory","opening_damage":0,"opening_lethal":false,"charge_extra":0,"charge_extra_damage":0,"combat_atk":combat_attack(),"combat_def":combat_defense(),"gear":gear,"item":armed_item,"pierce":pierce,"enemy_base_def":base_enemy(token).def,"tactic":tactic,"effective_level":effective_level(),"rune":kind,"first_hit":hit*(2 if shock else 1),"later_hit":hit,"first_counter_raw":first}
	var events:Array=[];var health:int=foe.hp;var turn:=0
	while health>0 and hit>0:
		if turn>=1 and token=="p" and not silent and per_hit>0 and hit<=3 and health>hit:
			info.valid=false;info.termination_reason="regeneration_stall";break
		turn+=1;health-=hit*(2 if shock and turn==1 else 1)
		var counter:int=(first if turn==1 else per_hit) if health>0 else 0
		var prevented:int=block+cloth+ward if turn==1 and health>0 else 0
		var dealt:int=counter-prevented
		var healing:int=mini(3,int(foe.hp)-health) if token=="p" and not silent and dealt>0 and health>0 else 0
		health+=healing
		events.append({"counter":counter,"prevented":prevented,"dealt":dealt,"healing":healing,"reflection":(4 if shock and turn==1 else 2) if token=="t" else 0})
	if hit<=0:info.termination_reason="no_penetration"
	var left:=hp
	if info.valid:
		left-=opening;info.opening_damage=opening;info.raw_damage=opening
		if left<=0:info.termination_reason="opening_death";info.opening_lethal=true
		else:
			for event in events:
				info.rounds+=1
				info.reflection_damage+=event.reflection;info.raw_damage+=event.reflection;left-=event.reflection
				if left<=0:info.termination_reason="reflection_death";break
				info.raw_damage+=event.counter;info.reduction+=event.prevented;left-=event.dealt
				if info.rounds==1 and event.counter>0:
					info.gear_reduction=cloth;info.item_reduction=ward
					if token=="c":info.charge_extra=per_hit*(2 if shock else 1);info.charge_extra_damage=info.charge_extra
				if left<=0:info.termination_reason="counter_death";break
				info.regen_total+=event.healing
				if event.healing>0:info.healed_turns+=1
		info.damage=hp-left;info.survivable=left>0
		info.potential_heal=mini(2+effective_level(),int(info.damage)) if tactic=="reap" and not silent else 0
		info.heal_after=info.potential_heal if info.survivable else 0;info.net_damage=info.damage-info.heal_after
	info.mechanic_note="震击：玩家首击×2，敌首次主动攻击×2；棘甲首反伤4。" if shock else "寂静：本层祭司与收割均不能在战斗内回血。"
	if not info.valid:info.mechanic_note="无法净推进战斗，拒战不扣生命或道具。"
	elif not info.survivable:info.mechanic_note+=" 按实际事件停止，死亡无奖励。"
	info.lines=[info.mechanic_note,"实战攻%d/防%d；首击伤害%d，后续每击%d" % [combat_attack(),combat_defense(),info.first_hit,hit],"先制%d / 首反击原伤害%d，固定减免最多%d" % [info.opening_damage,first,block+cloth+ward],"已出手%d次；实际反伤%d，敌恢复%d" % [info.rounds,info.reflection_damage,info.regen_total],"实际承伤%d / 胜后回复%d / 净损耗%d" % [info.damage,info.heal_after,info.net_damage],"只有存活才获得%d金币；不恢复已消耗道具。" % foe.gold]
	return info
