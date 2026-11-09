class_name TowerEndlessWorldV8
extends "res://scripts/endless_world_v7.gd"
const Generation8=preload("res://scripts/endless_generation_v8.gd")
const HP_CAP:=180
const BONUS_ATK_CAP:=6
const BONUS_DEF_CAP:=4
const LESSON_CAP:=6
const SUPPLY_HEAL:=8
var training_packs:=0
var bonus_atk:=0
var bonus_def:=0
var lessons_used:=0
var relief_remaining:=10
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v8.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=8 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 8
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=8;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation8.generate(seed,f).grid
	return _maps[f]
func _cargo_summary()->String:
	match cargo.state:
		"carried":return "运输中：第%d层箱 → 第%d层商人。可在箱/商人旁拆封取8生命，放弃奖励。" % [cargo.source,cargo.target]
		"opened":return "运输箱已拆封，改造奖励已放弃。"
		"delivered":return "已交付：在目标层商人旁三选一改造。" if cargo.reward=="" else "本局运输委托已完成，改造只领取一次。"
	return "本局可接一次委托：把入口8生命补给运到两层后，换三选一改造。"
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation8.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation8.routes(seed,floor_number):
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
func _apply_growth(old_atk:int,old_def:int,foundation:bool=false):
	var a:int=maxi(0,atk-old_atk-(3 if foundation else 0));var d:int=maxi(0,defense-old_def-(2 if foundation else 0))
	if foundation:training_packs+=1
	bonus_atk=mini(BONUS_ATK_CAP,bonus_atk+a);bonus_def=mini(BONUS_DEF_CAP,bonus_def+d)
	atk=20+3*training_packs+bonus_atk;defense=10+2*training_packs+bonus_def;hp=mini(HP_CAP,hp)
func apply_code(code:String)->Dictionary:
	if code=="cargo_leave":return act(code)
	return super.apply_code(code)
func act(id:String)->Dictionary:
	if id=="cargo_leave":
		if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能行动。")
		for direction in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if tile(pos+direction)=="C":
				_consume(pos+direction);_record(id);return _reply("已免费放弃本箱并让出通路；救济额度和金币不变。",true)
		return _reply("需要在未领补给箱旁。")
	if id in ["cargo_use","cargo_open"] and hp>=HP_CAP:return _reply("生命已满，没有消耗箱子、额度或金币。")
	if id in ["cargo_use","cargo_accept"] and relief_remaining<=0 and gold<4:return _reply("全旅程10份救济已用完；本箱需4金币，可免费放弃开路。")
	if id in ["skill_power","skill_guard","skill_mend"] and lessons_used>=LESSON_CAP:return _reply("全旅程6课时已经用完；可购买药物或一次性道具。")
	if id in ["skill_power","buy_sword"] and bonus_atk>=BONUS_ATK_CAP:return _reply("额外攻击+6预算已满，没有扣费；可选择急救、防御或消耗品。")
	if id in ["skill_guard","buy_armor"] and bonus_def>=BONUS_DEF_CAP:return _reply("额外防御+4预算已满，没有扣费；可选择急救、攻击或消耗品。")
	if id in ["buy_potion","enc_medicine","skill_mend"] and hp>=HP_CAP:return _reply("生命已达180，没有扣费。")
	if id=="cargo_mod_power" and bonus_atk>=6:return _reply("攻击预算已满；请选择防御或钥匙，不消耗改造机会。")
	if id=="cargo_mod_guard" and bonus_def>=4:return _reply("防御预算已满；请选择攻击或钥匙，不消耗改造机会。")
	var a:=atk;var d:=defense;var h:=hp;var result:Dictionary=super.act(id)
	if result.get("changed",false):
		if id in ["cargo_use","cargo_open"]:hp=mini(HP_CAP,h+SUPPLY_HEAL)
		if id in ["cargo_use","cargo_accept"]:
			if relief_remaining>0:relief_remaining-=1
			else:gold-=4
		if id in ["skill_power","skill_guard","skill_mend"]:lessons_used+=1
		if id=="case_reward":
			var converted:int=8*maxi(0,3-(BONUS_DEF_CAP-bonus_def));gold+=converted
			if converted>0:result.message=str(result.get("message",""))+" 超出防御预算部分改为%d金币。" % converted
		_apply_growth(a,d)
		if atk>a or defense>d or hp>h:result.message=str(result.get("message",""))+" 实际攻击+%d、防御+%d、恢复%d生命（生命上限180）。" % [atk-a,defense-d,maxi(0,hp-h)]
	return result
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	var token:=tile(pos+delta)
	if token=="S" and lessons_used>=LESSON_CAP:return _reply("全旅程6课时已用完，跨层共享；仍可查看状态。")
	var a:=atk;var d:=defense;var h:=hp;var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false):
		_apply_growth(a,d,token=="a" and not ended)
		if token in ["T","a","h"] and not ended:result.message="实际攻击+%d、防御+%d、恢复%d生命；额外预算攻击%d/6、防御%d/4。" % [atk-a,defense-d,maxi(0,hp-h),bonus_atk,bonus_def]
	return result
func options(target:Vector2i)->Array:
	var rows:Array=super.options(target);var result:Array=[]
	for row in rows:
		if row.id in ["skill_power","skill_guard","skill_mend"] and lessons_used>=LESSON_CAP:continue
		match row.id:
			"skill_power":row.label="攻击+%d；实际战术训练+%d；用1课时（全局剩%d）" % [mini(2,BONUS_ATK_CAP-bonus_atk),mini(1,3-training_level),LESSON_CAP-lessons_used]
			"skill_guard":row.label="防御+%d；实际战术训练+%d；用1课时（全局剩%d）" % [mini(1,BONUS_DEF_CAP-bonus_def),mini(1,3-training_level),LESSON_CAP-lessons_used]
			"skill_mend":row.label="实际恢复%d生命；战术训练+%d；用1课时（全局剩%d）" % [mini(35,HP_CAP-hp),mini(1,3-training_level),LESSON_CAP-lessons_used]
			"buy_potion":row.label="15金币：实际恢复%d生命（上限180）" % mini(50,HP_CAP-hp)
			"buy_sword":row.label="25金币：实际攻击+%d（额外上限6）" % mini(3,BONUS_ATK_CAP-bonus_atk)
			"buy_armor":row.label="20金币：实际防御+%d（额外上限4）" % mini(2,BONUS_DEF_CAP-bonus_def)
			"cargo_use":row.label="%s：实际恢复%d生命（上限180）" % ["消耗1份救济（全局剩%d）" % relief_remaining if relief_remaining>0 else "支付4金币",mini(SUPPLY_HEAL,HP_CAP-hp)]
			"cargo_open":row.label="拆封运输箱：恢复最多8生命，放弃改造"
			"cargo_accept":row.label="%s；放弃现在8生命，运至第%d层换改造" % ["消耗1份救济" if relief_remaining>0 else "支付4金币",floor_number+2]
			"cargo_mod_power":row.label="改造：实际攻击+%d（额外上限6）" % mini(4,BONUS_ATK_CAP-bonus_atk)
			"cargo_mod_guard":row.label="改造：实际防御+%d（额外上限4）" % mini(3,BONUS_DEF_CAP-bonus_def)
		result.append(row)
	if tile(target)=="C" and not ended and (_adjacent(target) or target==pos):result.append({"id":"cargo_leave","label":"免费放弃此箱：清出通路，不消耗救济或金币"})
	return result
func growth_view()->Dictionary:
	var y:int=1 if floor_number%2 else 13
	return {"title":"有限成长与当前预算","base_atk":20+3*training_packs,"base_def":10+2*training_packs,"training_packs":training_packs,"bonus_atk":bonus_atk,"bonus_def":bonus_def,"bonus_atk_cap":6,"bonus_def_cap":4,"remaining_atk":6-bonus_atk,"remaining_def":4-bonus_def,"hp_cap":180,"supply_heal":8,"relief_remaining":relief_remaining,"relief_total":10,"supply_price":0 if relief_remaining>0 else 4,"lessons_used":lessons_used,"lesson_cap":6,"lessons_remaining":6-lessons_used,"local_pack_available":tile(Vector2i(2 if floor_number%2 else 12,y))=="a","local_supply_available":tile(Vector2i(3 if floor_number%2 else 11,y))=="C","description":"补给全旅程共享10份免费额度，之后8生命/4金币，可免费放弃开路。基础按实际领包增长，回访不回落；可选永久攻防共享+6/+4预算。全旅程6课时跨层共享，路线预览不等于保证通关。","routes":summary().routes}
func build_view()->Dictionary:
	var view:Dictionary=super.build_view();view.description="战术训练上限3，遗物额外2，有效等级最多5；不同于攻防额外+6/+4预算。全旅程6课时共享三种技能选择。";return view
func base_enemy(token:String)->Dictionary:
	var profile:Array={"g":[44,16,8,18],"w":[34,24,0,25],"r":[26,18,2,20],"c":[24,17,4,22],"b":[44,16,1,12],"V":[70,28,17,35]}.get(token,[44,16,1,12])
	return {"hp":profile[0],"atk":int(profile[1])+2*floor_number,"def":int(profile[2])+3*floor_number,"gold":profile[3]}
func enemy(token:String)->Dictionary:
	var foe:=base_enemy(token)
	if armed_item=="pierce" and items.pierce>0:foe.def=maxi(0,int(foe.def)-6)
	return foe
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target)
	if token not in enemy_tokens():
		var info:Dictionary=super.preview(target)
		if token=="T":info.title="宝库遗物：实际收益受共享预算与180生命上限约束"
		elif token=="h":info.title="旧式药剂：最多恢复20生命，上限180"
		elif token=="S":info.title="营地技能：全旅程共6课时"
		elif token=="C":info.title="补给箱：8生命，全局救济或4金币"
		match token:
			"h":info.lines=["实际恢复%d生命（上限180）。" % mini(20,HP_CAP-hp)]
			"S":info.lines=["全旅程共6课时，跨层共享；剩余%d次。" % (6-lessons_used),"攻击/防御/急救共享课时，都提高战术训练（上限3）。","额外永久攻击最多+6、防御最多+4，所有来源共用。"]
			"T":info.lines=["实际攻击+%d、防御+%d，恢复最多%d生命。" % [mini(6,6-bonus_atk),mini(4,4-bonus_def),mini(50,180-hp)],"额外战术等级实际+%d；遗物最多2级，有效最多5。" % mini(1,2-relic_bonus),"原层敌人不随玩家升级，回访仍有价值但不无限堆攻防。"]
			"C":info.lines=["全旅程10份救济，剩%d份；用完后每箱4金币恢复8生命。" % relief_remaining,"可免费放弃箱子开路。满血不买、不扣额度；实际恢复受180上限约束。","接受运输同样消耗额度或4金币；拆封不重复付费，只取回8生命。"]
			"M":info.lines=["药物15金币恢复最多50生命，每层一次。","武器/护甲共享额外+6/+4预算，满额不收费。","基础训练不封顶；B战术、R遭遇、I道具、Q历史图。"]
		return info
	var base:=base_enemy(token);var foe:=enemy(token)
	var pierce:int=2+effective_level() if tactic=="pierce" else 0
	var hit:int=maxi(0,atk-maxi(0,int(foe.def)-pierce));var turns:int=ceili(float(foe.hp)/hit) if hit>0 else 0
	var per_hit:int=maxi(0,int(foe.atk)-defense);var opening:int=per_hit if token=="r" else 0
	var opening_fatal:bool=hit>0 and opening>=hp
	var counters:int=maxi(0,turns-1) if not opening_fatal else 0
	var normal:int=counters*per_hit;var extra:int=per_hit if token=="c" and counters>0 else 0
	var first:int=per_hit+(per_hit if token=="c" else 0) if counters>0 else 0
	var block:int=mini(3+effective_level(),first) if tactic=="brace" else 0
	var tool_block:int=mini(6,maxi(0,first-block)) if armed_item=="ward" and items.ward>0 else 0
	var raw:int=opening+normal+extra;var loss:int=maxi(0,raw-block-tool_block)
	var valid:bool=hit>0;var survive:bool=valid and loss<hp
	var potential:int=mini(2+effective_level(),loss) if tactic=="reap" and valid else 0
	var recovery:int=potential if survive else 0
	var base_hit:int=maxi(0,atk-int(base.def));var base_turns:int=ceili(float(base.hp)/base_hit) if base_hit>0 else 0
	var base_counters:int=maxi(0,base_turns-1) if not opening_fatal else 0
	var names:Dictionary={"g":"铁甲关尉","w":"烈法守卫","r":"截击斥候","c":"蓄势重卫","b":"持久哨兵","V":"旧层宝库守卫"}
	var info:Dictionary={"title":names[token],"token":token,"enemy":foe,"valid":valid,"survivable":survive,"rounds":0 if opening_fatal else turns,"opening_damage":opening,"opening_lethal":opening_fatal,"normal_counter_damage":normal,"charge_extra":extra,"charge_extra_damage":extra,"first_counter_raw":first,"raw_damage":raw,"reduction":block+tool_block,"item_reduction":tool_block,"damage":loss,"potential_heal":potential,"heal_after":recovery,"net_damage":loss-recovery,"pierce":pierce,"enemy_base_def":base.def,"base_valid":base_hit>0,"base_damage":opening+base_counters*per_hit+(per_hit if token=="c" and base_counters>0 else 0),"tactic":tactic,"effective_level":effective_level(),"item":armed_item,"item_pierce":6 if armed_item=="pierce" and items.pierce>0 else 0}
	info.mechanic_note="先制立即致死，玩家未出手，无胜利奖励。" if opening_fatal else "先制%d / 首反击蓄力额外%d，均已计入承伤。" % [opening,extra]
	info.lines=["固定档案：生命%d / 攻击%d / 原防%d → 道具后%d → 战术后%d" % [foe.hp,foe.atk,base.def,foe.def,maxi(0,int(foe.def)-pierce)],"先制%d + 普通反击%d + 蓄力%d = 原伤害%d" % [opening,normal,extra,raw],"架盾减%d / 护符减%d；实际承伤%d" % [block,tool_block,loss],"胜后回复%d / 净损耗%d；先活过承伤才能回复。" % [recovery,loss-recovery]]
	if not valid:info.lines.append("无法破防，拒战不消耗道具。")
	elif not survive:info.lines.append(info.mechanic_note if opening_fatal else "无法存活，不获击杀/金币/回复。")
	else:info.lines.append("胜利获得%d金币；没有暗骰或跟随玩家动态升级。" % foe.gold)
	if armed_item!="":info.lines.append("实际战斗结算消耗一件已装备道具，查看不耗。")
	return info
static func minimum_budget(f:int)->Dictionary:
	return {"valid":false,"floor":f,"reason":"v8使用有限成长与固定组合档案；需要结合实际路线、补给和商人支出验证，不继承旧8损保底。"}

func encounter_options()->Array:
	var rows:Array=super.encounter_options()
	for row in rows:
		if row.id=="enc_medicine":row.label="12金币：实际恢复%d生命（上限180）" % mini(35,HP_CAP-hp)
	return rows
func case_options()->Array:
	var rows:Array=super.case_options()
	for row in rows:
		if row.id=="case_take":row.label="当场取补给：实际恢复%d生命；放弃返程奖励" % mini(40,HP_CAP-hp)
		elif row.id=="case_reward":row.label="实际防御+%d；超出预算部分改为%d金币" % [mini(3,4-bonus_def),8*maxi(0,3-(4-bonus_def))]
	return rows
