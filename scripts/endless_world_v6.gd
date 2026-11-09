class_name TowerEndlessWorldV6
extends "res://scripts/endless_world_v5.gd"
const Generation6=preload("res://scripts/endless_generation_v6.gd")
const EXTRA_ACTIONS:=["enc_ward","enc_pierce","enc_blood_key","enc_medicine","enc_key_pierce","enc_blood_ward","enc_leave","arm_ward","arm_pierce","arm_none"]
const ITEM_CAP:=9
var items:Dictionary={"ward":0,"pierce":0}
var armed_item:=""
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v6.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=6 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 6
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=6;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func apply_code(code:String)->Dictionary:
	if code in EXTRA_ACTIONS:return act(code)
	return super.apply_code(code)
func encounter_options()->Array:
	if ended or not _near("M") or _used("encounter"):return []
	var rows:Array=[]
	match Generation6.encounter_kind(seed,floor_number):
		"quartermaster":rows=[{"id":"enc_ward","label":"支付12金币：获得1护符，下一战首次反击再减免最多6"},{"id":"enc_pierce","label":"支付18金币：获得1凿甲钉，下一战敌防-6"}]
		"medicine":rows=[{"id":"enc_blood_key","label":"支付30生命：获得1钥匙，必须留下至少1生命"},{"id":"enc_medicine","label":"支付12金币：立即恢复35生命"}]
		"altar":rows=[{"id":"enc_key_pierce","label":"支付1钥匙：获得1凿甲钉，下一战敌防-6"},{"id":"enc_blood_ward","label":"支付20生命：获得1护符，必须留下至少1生命"}]
	rows.append({"id":"enc_leave","label":"离开：本层不再接受任何遭遇选项"})
	return rows
func encounter_view()->Dictionary:
	var kind:=Generation6.encounter_kind(seed,floor_number)
	return {"title":{"quartermaster":"路边军需商","medicine":"伤药交换柜","altar":"旧誓祭坛"}[kind],"kind":kind,"resolved":_used("encounter"),"available":not ended and _near("M") and not _used("encounter"),"status":"本层已结算，其余选项已放弃。" if _used("encounter") else "当前金币%d / 生命%d / 钥匙%d" % [gold,hp,keys],"body":"每层一种固定遭遇，选择一次后其余选项永久放弃；无随机伤害。道具每种最多9件，满库存不会扣费。","options":encounter_options()}
func item_options()->Array:
	if ended:return []
	var rows:Array=[]
	if items.ward>0 and armed_item!="ward":rows.append({"id":"arm_ward","label":"装备护符：下一战首次反击再减免最多6"})
	if items.pierce>0 and armed_item!="pierce":rows.append({"id":"arm_pierce","label":"装备凿甲钉：下一战敌防再降低6"})
	if armed_item!="":rows.append({"id":"arm_none","label":"收起道具：不消耗库存"})
	return rows
func item_view()->Dictionary:
	return {"title":"一次性战斗道具","armed":armed_item,"inventory":items.duplicate(true),"counts":items.duplicate(true),"count":int(items.ward)+int(items.pierce),"status":"已装备："+{"":"无","ward":"护符","pierce":"凿甲钉"}[armed_item],"body":"只可装备一件，可随时收起或更换。确认战斗结算后消耗1件，包括致死和零伤战斗；拒战或取消确认不消耗。可与营地战术叠加，但减伤不超过真实伤害，收割不能挽救致死。","options":item_options()}
func act(id:String)->Dictionary:
	if id not in EXTRA_ACTIONS:return super.act(id)
	if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能行动；仍可结束旅程。")
	if id.begins_with("arm_"):
		var item:String={"arm_none":"","arm_ward":"ward","arm_pierce":"pierce"}[id]
		if item==armed_item:return _reply("道具装备未改变，不重复记录。")
		if item!="" and int(items[item])<=0:return _reply("没有该道具。")
		armed_item=item;_record(id);return _reply("已收起道具。" if item=="" else "道具已装备；下一场实际战斗才消耗。",true)
	if not _near("M") or _used("encounter"):return _reply("需在本层商人营地旁，且尚未结算遭遇。")
	var offered:=false
	for row in encounter_options():
		if row.id==id:offered=true
	if not offered:return _reply("这个选项不属于本层遭遇。")
	var item:String="ward" if id in ["enc_ward","enc_blood_ward"] else ("pierce" if id in ["enc_pierce","enc_key_pierce"] else "")
	if item!="" and int(items[item])>=ITEM_CAP:return _reply("该道具已有9件，没有扣费。")
	var price:int={"enc_ward":12,"enc_pierce":18,"enc_medicine":12}.get(id,0)
	var blood:int={"enc_blood_key":30,"enc_blood_ward":20}.get(id,0)
	if gold<price:return _reply("金币不足，没有改变本层遭遇。")
	if blood>0 and hp<=blood:return _reply("生命不足：必须支付后仍有至少1生命。")
	if id=="enc_key_pierce" and keys<1:return _reply("需要1把钥匙。")
	if id=="enc_medicine" and hp>=MAX_HP:return _reply("生命已满，没有扣费。")
	if id=="enc_blood_key" and keys>=MAX_STAT:return _reply("钥匙已达安全上限，没有扣费。")
	gold-=price;hp-=blood
	if id=="enc_key_pierce":keys-=1
	if id=="enc_blood_key":keys+=1
	if id=="enc_medicine":hp=mini(MAX_HP,hp+35)
	if item!="":items[item]=int(items[item])+1
	_mark("encounter");_record(id)
	return _reply("本层遭遇已结算，其余选项已放弃。",true)
func enemy(token:String)->Dictionary:
	var foe:Dictionary=super.enemy(token)
	if armed_item=="pierce" and items.pierce>0:foe.def=maxi(0,int(foe.def)-6)
	return foe
func preview(target:Vector2i)->Dictionary:
	var info:Dictionary=super.preview(target)
	if tile(target) not in enemy_tokens():return info
	info.item=armed_item;info.item_reduction=0;info.item_pierce=0
	if armed_item=="ward" and items.ward>0 and info.valid and int(info.rounds)>1:
		var first_hit:int=maxi(0,int(info.enemy.atk)-defense)
		var blocked:int=mini(6,maxi(0,first_hit-int(info.reduction)))
		info.item_reduction=blocked;info.reduction=int(info.reduction)+blocked;info.damage=maxi(0,int(info.damage)-blocked)
		info.survivable=int(info.damage)<hp
		info.potential_heal=mini(2+effective_level(),int(info.damage)) if tactic=="reap" else 0
		info.heal_after=int(info.potential_heal) if info.survivable else 0
		info.net_damage=int(info.damage)-int(info.heal_after)
	if armed_item=="pierce" and items.pierce>0:
		info.item_pierce=6;info.enemy_base_def=super.enemy(tile(target)).def
	if armed_item!="":
		# Replace pre-item totals so the nearby tooltip never contradicts itself.
		info.lines=["敌人生命%d / 攻击%d / 当前防御%d" % [info.enemy.hp,info.enemy.atk,info.enemy.def],"原伤害%d / 总减伤%d / 实际承伤%d / 胜后恢复%d / 净损耗%d" % [info.raw_damage,info.reduction,info.damage,info.heal_after,info.net_damage],"护符首反击额外减免%d；本次结算消耗1护符。" % info.item_reduction if armed_item=="ward" else "凿甲钉：原防%d → 道具后%d → 战术后%d；本次结算消耗1件。" % [info.enemy_base_def,info.enemy.def,maxi(0,int(info.enemy.def)-int(info.pierce))],"仍需先活过实际承伤；致死不能靠战后恢复获救。"]
		if not info.valid:info.lines.append("无法破防，拒战不消耗道具。")
	return info
func _consume_armed_item():
	if armed_item!="" and int(items.get(armed_item,0))>0:items[armed_item]=int(items[armed_item])-1
	armed_item=""
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false) and result.get("battle") is Dictionary:_consume_armed_item()
	return result
func summary()->Dictionary:
	var data:Dictionary=super.summary();data.encounter=encounter_view();data.items=item_view()
	var rows:Array=[]
	for route in Generation5.routes(seed,floor_number):
		# Combat-only copy: never duplicate a long action log on every HUD redraw.
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item"]:sim.set(key,get(key))
		sim.items=items.duplicate(true);sim.deltas={floor_number:deltas.get(floor_number,{}).duplicate(true)}
		sim._maps={floor_number:_base(floor_number)}
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
