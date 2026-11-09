class_name TowerEndlessWorldV4
extends "res://scripts/endless_world_v3.gd"
# V3 stays immutable; only tactical selection and deterministic battle effects differ.
const TACTICS:={"tactic_none":"none","tactic_pierce":"pierce","tactic_brace":"brace","tactic_reap":"reap"}
var tactic:="none"
var training_level:=1
var relic_bonus:=0
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v4.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=4 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 4
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=4;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func effective_level()->int:return mini(5,training_level+relic_bonus)
func tactic_data()->Dictionary:
	var level:=effective_level()
	return {"id":tactic,"level":level,"training_level":training_level,"training_cap":3,"relic_bonus":relic_bonus,"effective_cap":5,"pierce":2+level,"brace":3+level,"reap":2+level}
func tactic_options()->Array:
	if ended or not _near("M"):return []
	var result:Array=[];var powers:=tactic_data()
	for row in [["tactic_none","卸下战术：按基础规则战斗"],["tactic_pierce","破甲：敌防-%d" % powers.pierce],["tactic_brace","架盾：首次反击最多减免%d伤害" % powers.brace],["tactic_reap","收割：胜后恢复最多%d生命，不超过本场实际损伤" % powers.reap]]:
		if TACTICS[row[0]]!=tactic:result.append({"id":row[0],"label":row[1]})
	return result
func options(target:Vector2i)->Array:
	# Existing merchant/task menus stay small. UI opens a separate tactics panel.
	return super.options(target)
func apply_code(code:String)->Dictionary:
	if TACTICS.has(code):return act(code)
	return super.apply_code(code)
func act(id:String)->Dictionary:
	if TACTICS.has(id):
		if ended or actions.size()>=MAX_ACTIONS-1 or not _near("M"):return _reply("需要在商人营地旁切换战术。")
		if tactic==TACTICS[id]:return _reply("已经采用该战术，不会重复记录。")
		tactic=TACTICS[id];_record(id);return _reply("战术已切换；没有消耗资源。",true)
	var result:Dictionary=super.act(id)
	if result.get("changed",false) and id in ["skill_power","skill_guard","skill_mend"]:training_level=mini(3,training_level+1)
	return result
func preview(target:Vector2i)->Dictionary:
	var info:Dictionary=super.preview(target)
	if tile(target) not in enemy_tokens():return info
	var foe:Dictionary=info.enemy;var level:=effective_level()
	var base_hit:int=maxi(0,atk-int(foe.def))
	var base_rounds:int=ceili(float(foe.hp)/base_hit) if base_hit>0 else 0
	var per_hit:int=maxi(0,int(foe.atk)-defense)
	var base_damage:int=maxi(0,base_rounds-1)*per_hit if base_hit>0 else 0
	var pierce:int=2+level if tactic=="pierce" else 0
	var hit:int=maxi(0,atk-maxi(0,int(foe.def)-pierce))
	var rounds:int=ceili(float(foe.hp)/hit) if hit>0 else 0
	var raw:int=maxi(0,rounds-1)*per_hit
	var blocked:int=mini(3+level,per_hit) if tactic=="brace" and rounds>1 else 0
	var damage:int=maxi(0,raw-blocked)
	var heal:int=mini(2+level,damage) if tactic=="reap" and hit>0 else 0
	info.valid=hit>0;info.survivable=hit>0 and damage<hp
	info.rounds=rounds;info.raw_damage=raw;info.reduction=blocked;info.base_damage=base_damage;info.base_valid=base_hit>0
	info.damage=damage;info.heal_after=heal if info.survivable else 0;info.potential_heal=heal
	info.net_damage=damage-int(info.heal_after);info.effective_level=level;info.tactic=tactic;info.pierce=pierce
	info.lines=["敌人生命%d / 攻击%d / 防御%d" % [foe.hp,foe.atk,foe.def],"战术等级%d：%s；原伤害%d / 减伤%d / 实际承伤%d" % [level,{"none":"无","pierce":"破甲","brace":"架盾","reap":"收割"}[tactic],raw,blocked,damage],"胜后恢复%d / 净损耗%d。先承伤，致死不能靠回复获救。" % [info.heal_after,info.net_damage] if hit>0 else "无法破防，先成长再回来。"]
	if tactic=="pierce":info.lines.append("敌防减%d；未破甲预计损伤%s。" % [pierce,str(base_damage) if base_hit>0 else "无法破防"])
	return info
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	var token:String=tile(pos+delta)
	var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false):
		if token=="T" and not ended:relic_bonus=mini(2,relic_bonus+1)
		if result.get("battle") is Dictionary and not ended:
			hp=mini(MAX_HP,hp+int(result.battle.get("heal_after",0)))
	return result
func summary()->Dictionary:
	var data:Dictionary=super.summary();data.tactic=tactic_data()
	var routes:Array=[]
	for route in [{"label":"重甲短路" if Generator.layout(seed,floor_number)=="courtyard" else "猛攻关隘","points":[Generator.PRIMARY]},{"label":"双哨巡逻线","points":Generator.alternate_points(seed,floor_number)}]:
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
	data.routes=routes
	return data
func build_view()->Dictionary:
	var power:=tactic_data()
	return {"stance":tactic,"title":{"none":"旅行者（无战术）","pierce":"破甲","brace":"架盾","reap":"收割"}[tactic],"training_level":training_level,"relic_bonus":relic_bonus,"effective_level":effective_level(),"description":"每层技能抉择同时提升战术训练，普通上限3；宝库遗物额外+1，最多两次，有效等级上限5。只能在商人旁免费切换，同战术不重复记录。","effects":["破甲：敌防-%d" % power.pierce,"架盾：首次反击最多减免%d" % power.brace,"收割：胜后回复最多%d，且不超过实际损伤；致死不能回复" % power.reap],"options":tactic_options()}
