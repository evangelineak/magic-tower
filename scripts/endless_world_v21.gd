class_name TowerEndlessWorldV21
extends "res://scripts/endless_world_v20.gd"
const Combat21=preload("res://scripts/endless_combat_v21.gd")
var talents:Array[String]=[]
var last_kill_kind:String=""
var legacy_id:String=""
var legacy_coin_used:bool=false
var _draft_seed:int=-1
var _draft:Array=[]
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v21.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=21 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 21
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=21;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
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
	var data:Dictionary={"layout":Generation19.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation19.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
		sim.hero_id=hero_id;sim.focus=focus;sim.skill_armed=skill_armed
		sim.talents=talents.duplicate();sim.last_kill_kind=last_kill_kind;sim.legacy_id=legacy_id;sim.legacy_coin_used=legacy_coin_used
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
			healed+=int(info.heal_after);sim.hp=sim.hp-int(info.damage)+int(info.heal_after);sim._consume_armed_item();sim._consume_hero_skill();sim.last_kill_kind=sim.tile(point)
		rows.append({"label":route.label,"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":count,"gold":reward})
	data.routes=rows;return data
func hero_view()->Dictionary:
	var row:Dictionary={"id":"","name":"尚未选择英雄","skill_name":"","skill_description":"请选择开局英雄。","focus_recovery":""}
	for candidate in hero_catalog():
		if candidate.id==hero_id:row=candidate.duplicate(true)
	row.focus=focus;row.focus_cap=focus_capacity();row.focus_cost=skill_cost();row.armed=skill_armed;row.next_focus_floor=(int(max_floor/4)+1)*4;row.options=hero_options()
	row.heal_actual=mini(skill_heal(),HP_CAP-hp) if hero_id=="scholar" else 0
	row.skill_description=skill_description()
	row.focus_recovery="初始专注由传承决定，上限%d；首次到达新最高4/8/12…层+1，满额溢出丢失，回访不恢复。" % focus_capacity()
	return row
func hero_options()->Array:
	if hero_id=="" or legacy_id=="" or ended or actions.size()>=MAX_ACTIONS-1:return []
	if skill_armed:return [{"id":"skill_cancel","label":"取消预备，不消耗专注"}]
	if focus<skill_cost():return []
	if hero_id=="scholar":return [{"id":"skill_use","label":"%d专注：实际恢复%d生命" % [skill_cost(),mini(skill_heal(),HP_CAP-hp)]}] if hp<HP_CAP else []
	return [{"id":"skill_use","label":"预备下一战技能；实际开战才消耗%d专注" % skill_cost()}]
func act(id:String)->Dictionary:
	if id.begins_with("legacy_"):return _choose_legacy(id)
	if id.begins_with("hero_"):
		if ended or not actions.is_empty() or hero_id!="":return _reply("英雄只能作为新局第一项选择，之后不可更换。")
		var chosen:String=id.trim_prefix("hero_")
		if chosen not in ["warden","ranger","scholar"]:return _reply("未知英雄。")
		hero_id=chosen;_record(id);return _reply("已选择"+hero_view().name+"，基础属性相同，技能消耗有限专注。",true)
	if hero_id=="":return _reply("请先选择英雄，尚未开始旅程。")
	if legacy_id=="":return _reply("请先选择本局传承，可选择不携带。")
	if id.begins_with("tal_"):return _choose_talent(id)
	if id=="buy_potion" and "mender" in talents:
		var result:Dictionary=super.act(id)
		if result.get("changed",false):hp=mini(HP_CAP,hp+4);result.message="已购买修复学药剂，治疗上限54，实际受当前生命上限限制。"
		return result
	if id not in ["skill_use","skill_cancel"]:return super.act(id)
	if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能使用技能。")
	if id=="skill_cancel":
		if not skill_armed:return _reply("没有已预备技能。")
		skill_armed=false;_record(id);return _reply("已取消预备，没有消耗专注。",true)
	if focus<skill_cost():return _reply("需要%d专注；首次到达新最高4的倍数层可补充。" % skill_cost())
	if skill_armed:return _reply("技能已经预备，不重复记录。")
	if hero_id=="scholar":
		if hp>=HP_CAP:return _reply("生命已满，没有消耗专注。")
		var heal:=mini(skill_heal(),HP_CAP-hp);hp+=heal;focus-=skill_cost();_record(id);return _reply("消耗%d专注，实际恢复%d生命。" % [skill_cost(),heal],true)
	skill_armed=true;_record(id);return _reply("已预备下一战技能；确认或查看不耗专注，实际战斗消耗%d点。" % skill_cost(),true)
func apply_code(code:String)->Dictionary:
	if code.begins_with("hero_") or code.begins_with("legacy_") or code.begins_with("tal_") or code in ["skill_use","skill_cancel"]:return act(code)
	if hero_id=="" or legacy_id=="":return _reply("缺少英雄与传承选择前缀。")
	return super.apply_code(code)
func _consume_hero_skill():
	if skill_armed and focus>=skill_cost() and hero_id in ["warden","ranger"]:focus-=skill_cost();skill_armed=false
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if hero_id=="" or legacy_id=="":return _reply("请先完成英雄和传承选择。")
	var old_max:=max_floor;var old_focus:=focus;var old_kills:=kills;var token:=tile(pos+delta)
	var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false):
		if not ended and kills>old_kills:last_kill_kind=token
		if token=="$" and legacy_id=="coin" and vault_kind()=="gold":legacy_coin_used=true
		if not ended and max_floor>old_max:
			var gained:int=int(max_floor/4)-int(old_max/4)
			if gained>0:
				var actual:int=mini(gained,focus_capacity()-old_focus);focus=old_focus+actual
				result.message=str(result.message).split(" 新最高层专注")[0]+" 新最高层专注+%d，溢出%d丢失。" % [actual,gained-actual]
	return result
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target)
	if token not in enemy_tokens():return super.preview(target)
	var foe:=enemy(token)
	if Generation19.has_bridge(seed,floor_number) and target==Vector2i(6,4) and token=="c":foe.gold=22
	var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var input:Dictionary={"foe":foe,"token":token,"rune":_rune_kind(),"armed":skill_armed,"focus":focus,"hero":hero_id,"atk":combat_attack(),"defense":combat_defense(),"hp":hp,"pierce":pierce,"brace":3+effective_level() if tactic=="brace" else 0,"cloak":4 if gear=="cloak" else 0,"ward":6 if armed_item=="ward" and items.ward>0 else 0,"reap":2+effective_level() if tactic=="reap" else 0}
	input.talents=talents;input.last_kill_kind=last_kill_kind;input.gear=gear;input.item=armed_item;input.has_item=armed_item!="" and int(items.get(armed_item,0))>0
	var info:Dictionary=Combat21.simulate(input)
	info.title={"g":"铁甲关尉","b":"持久哨兵","w":"烈法守卫","V":"旧层宝库守卫","r":"截击斥候","c":"蓄势重卫","t":"棘甲守卫","p":"回春祭司"}[token]
	info.token=token;info.combat_atk=info.effective_atk;info.combat_def=combat_defense();info.gear=gear;info.item=armed_item;info.pierce=pierce;info.enemy_base_def=base_enemy(token).def;info.tactic=tactic;info.effective_level=effective_level();info.rune=input.rune;info.hero=hero_id
	info.mechanic_note="按命中、反伤、反击和回复顺序结算；死亡立即停止。"
	if token=="r":info.mechanic_note="先制在玩家出手前；护卫可挡，反击固定减伤不挡先制。"
	elif token=="c":info.mechanic_note="首反击蓄力；先固定减伤，再计护卫格挡。"
	elif token=="t":info.mechanic_note="每次命中含击杀都反伤，护卫不挡；反伤致死无奖励。"
	elif token=="p":info.mechanic_note="反击实际伤害大于0且玩家存活才回复；循环拒战不耗资源。"
	if not info.valid:info.mechanic_note="无法破防或再生循环，拒战不扣生命、道具或专注。"
	elif not info.survivable:info.mechanic_note+=" 当前不能存活。"
	info.lines=[info.mechanic_note,"实战攻%d/防%d；敌原防%d，最终有效防%d" % [info.combat_atk,info.combat_def,info.enemy_base_def,info.effective_enemy_def],"首击%d / 后续%d；出手%d次" % [info.first_hit,info.later_hit,info.rounds],"先制实际%d / 反伤%d / 敌回复%d" % [info.opening_damage,info.reflection_damage,info.regen_total],"固定及英雄总减免%d，其中英雄减免%d；英雄额外忽防%d" % [info.reduction,info.hero_reduction,info.hero_pierce],"实际承伤%d / 胜后回复%d / 净损耗%d" % [info.damage,info.heal_after,info.net_damage],"只有存活才获得%d金币；实际战斗才消耗预备道具与技能。" % foe.gold]
	info.lines.append("天赋固定减免%d / 额外忽防%d / 敌每主动加伤%d。" % [info.talent_reduction,info.talent_pierce,info.counter_surcharge])
	if info.hero_skill_used:info.lines.append("本次实际战斗消耗%d专注；危险确认和拒战不消耗。" % skill_cost())
	return info
static func talent_catalog()->Dictionary:
	var data:Dictionary={
	"reserve":["储备","专注上限+1至4，不补充当前专注。"],
	"tracker":["追猎","与上次存活击杀同种敌人时，玩家首击+3；首杀无效。"],
	"laststand":["背水","战前生命≤60，玩家首击×1.2向下取整；不在战中重新判定。"],
	"alert":["留神","未预备英雄技能且保有至少1专注时，敌首次主动攻击额外固定减2；含先制，不挡反伤。"],
	"light":["轻装","未穿持久装备时，首反击额外固定减3；装备披肩或镜后失效。"],
	"wardweave":["护符编织","实际装备护符的这场首反击再减3，但本战实战攻击-1。"],
	"deepdrill":["深凿","实际装备凿甲钉时额外忽防2，但敌每次主动原伤害+2，先加再计算蓄力与震击。"],
	"mender":["修复学","商人药剂及学者技能标称治疗+4；收割胜后回复-2，最低0。不增强免费箱或遗物。"],
	"overload":["透支","英雄技能每次耗2专注：护卫减75%，游侠忽防14，学者治疗42；修复学可再+4。"]}
	var rows:Dictionary={}
	for id in data:rows[id]={"id":id,"title":data[id][0],"name":data[id][0],"description":data[id][1],"action":"tal_"+id}
	return rows
static func legacy_catalog()->Array:
	return [{"id":"none","name":"不携带","title":"不携带","cost":0,"description":"保持150生命、2专注与原始物品，无额外收益或代价。"},{"id":"kit","name":"行囊","title":"行囊","cost":1,"description":"初始专注2→1，获得1护符与1凿甲钉；用一次技能机会换两种道具。"},{"id":"coin","name":"探库者","title":"探库者","cost":2,"description":"初始专注2→1，本局首次领取钱库额外12金币；不影响怪赏、退款、其他宝库，只一次。"},{"id":"mind","name":"冥想","title":"冥想","cost":2,"description":"初始生命150→120，专注2→3；用30生命换一份可安排的技能，不降低生命上限。"}]
func talent_draft()->Array:
	if _draft_seed!=seed:
		var pool:Array=talent_catalog().keys();pool.sort()
		var state:int=Generation19.mix(seed,1,4127)
		for i in range(pool.size()-1,0,-1):
			state=Generation19.mix(state,1,53*i);var j:int=state%(i+1)
			var swap=pool[i];pool[i]=pool[j];pool[j]=swap
		_draft=[pool.slice(0,3),pool.slice(3,6),pool.slice(6,9)];_draft_seed=seed
	return _draft.duplicate(true)
func talent_view()->Dictionary:
	var tier:=talents.size();var threshold:int=[3,8,15][tier] if tier<3 else 0;var reason:=""
	if hero_id=="" or legacy_id=="":reason="先完成本局英雄与传承选择。"
	elif ended:reason="旅程已结束。"
	elif tier>=3:reason="已选择3项天赋，本局不再增加。"
	elif kills<threshold:reason="第%d轮需要累计%d次存活击杀。" % [tier+1,threshold]
	elif skill_armed:reason="请先免费取消已预备英雄技能，再选择天赋。"
	elif actions.size()>=MAX_ACTIONS-1:reason="行动容量不足。"
	var catalog:=talent_catalog();var chosen:Array=[];var offers:Array=[]
	for id in talents:chosen.append(catalog[id].duplicate(true))
	if tier<3:
		for id in talent_draft()[tier]:
			var card:Dictionary=catalog[id].duplicate(true);card.allowed=reason=="";card.reason=reason;offers.append(card)
	return {"tier":tier,"chosen":chosen,"offers":offers,"next_kills":threshold,"kills":kills,"available":reason=="","reason":reason}
func _choose_talent(action:String)->Dictionary:
	var view:=talent_view();var id:=action.trim_prefix("tal_")
	if not view.available:return _reply(view.reason)
	if id not in talent_draft()[talents.size()]:return _reply("这张牌不在本轮种子候选中，不能重抽或跳轮。")
	talents.append(id);_record(action);return _reply("已选择"+str(talent_catalog()[id].title)+"；不改变其余轮次候选，不补充专注。",true)
func _choose_legacy(action:String)->Dictionary:
	if ended or hero_id=="" or actions.size()!=1 or actions[0]!="hero_"+hero_id or legacy_id!="":return _reply("传承只可作为英雄之后的第二项开局选择。")
	var id:=action.trim_prefix("legacy_")
	if id not in ["none","kit","coin","mind"]:return _reply("未知传承。")
	legacy_id=id
	if id in ["kit","coin"]:focus=1
	if id=="kit":items.ward+=1;items.pierce+=1
	if id=="mind":hp=120;focus=3
	_record(action);return _reply("本局传承已确定；资格由开始旅程的存储事务检查，局内不能更换。",true)
func focus_capacity()->int:return 4 if "reserve" in talents else 3
func skill_cost()->int:return 2 if "overload" in talents else 1
func skill_heal()->int:return (42 if "overload" in talents else 24)+(4 if "mender" in talents else 0)
func skill_description()->String:
	var text:=""
	if hero_id=="warden":text="预备下一战：敌前两次主动攻击在固定减伤后再减%d%%，向下取减免；含先制，零伤也占次数，不挡反伤。" % (75 if "overload" in talents else 50)
	elif hero_id=="ranger":text="预备下一战：全部玩家攻击额外忽略%d防御，最低0；叠加战术与凿甲钉。" % (14 if "overload" in talents else 8)
	elif hero_id=="scholar":text="战外治疗最多%d生命，实际+%d，上限180；满血拒绝，不能复活。" % [skill_heal(),mini(skill_heal(),HP_CAP-hp)]
	else:return "请先选择英雄。"
	return "%d专注：" % skill_cost()+text
func talent_preview(id:String,target:Vector2i=Vector2i(-1,-1))->Dictionary:
	if talents.size()>=3 or id not in talent_draft()[talents.size()]:return {"valid":false}
	var sim=clone();sim.talents.append(id)
	var result:Dictionary={"valid":true,"id":id,"before_hero":hero_view(),"after_hero":sim.hero_view(),"before":{},"after":{}}
	if tile(target) in enemy_tokens():result.before=preview(target);result.after=sim.preview(target)
	return result
func action_quote(id:String)->Dictionary:
	var q:Dictionary=super.action_quote(id)
	if id=="buy_potion" and "mender" in talents:
		q.heal_nominal=54;q.heal_actual=mini(54,HP_CAP-hp);q.hp_after=hp+int(q.heal_actual);q.overflow=54-int(q.heal_actual)
	return q
func options(target:Vector2i)->Array:
	var rows:Array=super.options(target)
	if "mender" in talents:
		for row in rows:
			if row.id=="buy_potion":row.label="15金币：修复学药剂实际恢复%d生命（标称54，每层一次）" % mini(54,HP_CAP-hp)
	return rows
func vault_quote(target:Vector2i=Vector2i(12,3))->Dictionary:
	var q:Dictionary=super.vault_quote(target)
	if legacy_id=="coin" and not legacy_coin_used and q.kind=="gold":
		q.nominal=52;q.actual=mini(52,maxi(0,MAX_STAT-gold));q.gold=q.actual;q.overflow=52-int(q.actual)
		q.title="钱库：40金币＋探库者一次12金币";q.coin_bonus_nominal=12;q.coin_bonus_actual=maxi(0,int(q.actual)-mini(40,maxi(0,MAX_STAT-gold)))
	return q
