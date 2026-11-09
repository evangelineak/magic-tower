class_name TowerEndlessWorldV20
extends "res://scripts/endless_world_v19.gd"
const Combat20=preload("res://scripts/endless_combat_v20.gd")
var hero_id:String=""
var focus:int=2
var skill_armed:bool=false
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v20.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=20 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 20
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=20;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.hero_id=hero_id;w.focus=focus;w.skill_armed=skill_armed
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
	var data:Dictionary={"layout":Generation19.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation19.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
		sim.hero_id=hero_id;sim.focus=focus;sim.skill_armed=skill_armed
		sim.bridges=bridges.duplicate(true);sim.carts=carts.duplicate(true)
		sim.runes=runes.duplicate(true)
		sim.items=items.duplicate(true);sim.deltas={floor_number:deltas.get(floor_number,{}).duplicate(true)};sim._maps={floor_number:_base(floor_number)}
		var points:Array=route.points.duplicate()
		if Generation19.has_bridge(seed,floor_number) and bridges.get(floor_number,"")=="short" and points.size()==2:
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
			healed+=int(info.heal_after);sim.hp=sim.hp-int(info.damage)+int(info.heal_after);sim._consume_armed_item();sim._consume_hero_skill()
		rows.append({"label":route.label,"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":count,"gold":reward})
	data.routes=rows;return data
static func hero_catalog()->Array:
	var recovery:="初始2点专注，上限3；首次到达新最高4/8/12…层+1，满额溢出丢失，回访不恢复。"
	return [{"id":"warden","name":"护卫","description":"基础面板相同，用有限专注控制危险攻击。","skill_name":"双重格挡","skill_description":"预备下一战：敌前两次主动攻击在固定减伤后再减50%（减免向下取整）；含先制，零伤攻击也占次数，不挡反伤。","focus_recovery":recovery},{"id":"ranger","name":"游侠","description":"基础面板相同，集中专注跨过护甲与出手次数阈值。","skill_name":"精准穿甲","skill_description":"预备下一战：所有玩家攻击额外忽略8防御，敌防最低0；与战术及凿甲钉叠加。","focus_recovery":recovery},{"id":"scholar","name":"学者","description":"基础面板相同，将有限专注转为途中治疗。","skill_name":"修复术","skill_description":"战斗外消耗1专注，直接恢复最多24生命，上限180；满血拒绝，不是战后复活。","focus_recovery":recovery}]
func hero_view()->Dictionary:
	var row:Dictionary={"id":"","name":"尚未选择英雄","skill_name":"","skill_description":"请选择开局英雄。","focus_recovery":""}
	for candidate in hero_catalog():
		if candidate.id==hero_id:row=candidate.duplicate(true)
	row.focus=focus;row.focus_cap=3;row.armed=skill_armed;row.next_focus_floor=(int(max_floor/4)+1)*4;row.options=hero_options()
	row.heal_actual=mini(24,HP_CAP-hp) if hero_id=="scholar" else 0
	return row
func hero_options()->Array:
	if hero_id=="" or ended or actions.size()>=MAX_ACTIONS-1:return []
	if skill_armed:return [{"id":"skill_cancel","label":"取消预备，不消耗专注"}]
	if focus<=0:return []
	if hero_id=="scholar":return [{"id":"skill_use","label":"1专注：实际恢复%d生命" % mini(24,HP_CAP-hp)}] if hp<HP_CAP else []
	return [{"id":"skill_use","label":"预备下一战技能；实际开战才消耗1专注"}]
func act(id:String)->Dictionary:
	if id.begins_with("hero_"):
		if ended or not actions.is_empty() or hero_id!="":return _reply("英雄只能作为新局第一项选择，之后不可更换。")
		var chosen:String=id.trim_prefix("hero_")
		if chosen not in ["warden","ranger","scholar"]:return _reply("未知英雄。")
		hero_id=chosen;_record(id);return _reply("已选择"+hero_view().name+"，基础属性相同，技能消耗有限专注。",true)
	if hero_id=="":return _reply("请先选择英雄，尚未开始旅程。")
	if id not in ["skill_use","skill_cancel"]:return super.act(id)
	if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能使用技能。")
	if id=="skill_cancel":
		if not skill_armed:return _reply("没有已预备技能。")
		skill_armed=false;_record(id);return _reply("已取消预备，没有消耗专注。",true)
	if focus<=0:return _reply("专注不足；首次到达新最高4的倍数层可补充。")
	if skill_armed:return _reply("技能已经预备，不重复记录。")
	if hero_id=="scholar":
		if hp>=HP_CAP:return _reply("生命已满，没有消耗专注。")
		var heal:=mini(24,HP_CAP-hp);hp+=heal;focus-=1;_record(id);return _reply("消耗1专注，实际恢复%d生命。" % heal,true)
	skill_armed=true;_record(id);return _reply("已预备下一战技能；确认或查看不耗专注，实际战斗消耗1点。",true)
func apply_code(code:String)->Dictionary:
	if code.begins_with("hero_") or code in ["skill_use","skill_cancel"]:return act(code)
	if hero_id=="":return _reply("缺少首条英雄选择。")
	return super.apply_code(code)
func _consume_hero_skill():
	if skill_armed and focus>0 and hero_id in ["warden","ranger"]:focus-=1;skill_armed=false
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if hero_id=="":return _reply("请先选择英雄。")
	var old_max:=max_floor
	var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false):
		if result.get("battle") is Dictionary:_consume_hero_skill()
		if not ended and max_floor>old_max:
			var gained:int=int(max_floor/4)-int(old_max/4)
			if gained>0:
				var actual:int=mini(gained,3-focus);focus+=actual
				result.message=str(result.message)+" 新最高层专注+%d，溢出%d丢失。" % [actual,gained-actual]
	return result
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target)
	if token not in enemy_tokens():return super.preview(target)
	var foe:=enemy(token)
	if Generation19.has_bridge(seed,floor_number) and target==Vector2i(6,4) and token=="c":foe.gold=22
	var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var input:Dictionary={"foe":foe,"token":token,"rune":_rune_kind(),"armed":skill_armed,"focus":focus,"hero":hero_id,"atk":combat_attack(),"defense":combat_defense(),"hp":hp,"pierce":pierce,"brace":3+effective_level() if tactic=="brace" else 0,"cloak":4 if gear=="cloak" else 0,"ward":6 if armed_item=="ward" and items.ward>0 else 0,"reap":2+effective_level() if tactic=="reap" else 0}
	var info:Dictionary=Combat20.simulate(input)
	info.title={"g":"铁甲关尉","b":"持久哨兵","w":"烈法守卫","V":"旧层宝库守卫","r":"截击斥候","c":"蓄势重卫","t":"棘甲守卫","p":"回春祭司"}[token]
	info.token=token;info.combat_atk=combat_attack();info.combat_def=combat_defense();info.gear=gear;info.item=armed_item;info.pierce=pierce;info.enemy_base_def=base_enemy(token).def;info.tactic=tactic;info.effective_level=effective_level();info.rune=input.rune;info.hero=hero_id
	info.mechanic_note="按命中、反伤、反击和回复顺序结算；死亡立即停止。"
	if token=="r":info.mechanic_note="先制在玩家出手前；护卫可挡，反击固定减伤不挡先制。"
	elif token=="c":info.mechanic_note="首反击蓄力；先固定减伤，再计护卫格挡。"
	elif token=="t":info.mechanic_note="每次命中含击杀都反伤，护卫不挡；反伤致死无奖励。"
	elif token=="p":info.mechanic_note="反击实际伤害大于0且玩家存活才回复；循环拒战不耗资源。"
	if not info.valid:info.mechanic_note="无法破防或再生循环，拒战不扣生命、道具或专注。"
	elif not info.survivable:info.mechanic_note+=" 当前不能存活。"
	info.lines=[info.mechanic_note,"实战攻%d/防%d；敌原防%d，最终有效防%d" % [info.combat_atk,info.combat_def,info.enemy_base_def,info.effective_enemy_def],"首击%d / 后续%d；出手%d次" % [info.first_hit,info.later_hit,info.rounds],"先制实际%d / 反伤%d / 敌回复%d" % [info.opening_damage,info.reflection_damage,info.regen_total],"固定及英雄总减免%d，其中英雄减免%d；英雄额外忽防%d" % [info.reduction,info.hero_reduction,info.hero_pierce],"实际承伤%d / 胜后回复%d / 净损耗%d" % [info.damage,info.heal_after,info.net_damage],"只有存活才获得%d金币；实际战斗才消耗预备道具与技能。" % foe.gold]
	if info.hero_skill_used:info.lines.append("本次实际战斗消耗1专注；危险确认和拒战不消耗。")
	return info
