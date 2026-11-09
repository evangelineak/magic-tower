class_name TowerEndlessWorldV9
extends "res://scripts/endless_world_v8.gd"
const Generation9=preload("res://scripts/endless_generation_v9.gd")
var contract:Dictionary={}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v9.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=9 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 9
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=9;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func _job_manifest()->Dictionary:
	return Generation9.manifest(seed,int(contract.get("source",floor_number)))
func _job_remaining()->int:
	var offer:=_job_manifest();var count:=0
	for point in offer.points:
		if not deltas.get(offer.source,{}).has(point.y*15+point.x):count+=1
	return count
func _job_phase()->String:
	if not contract.is_empty():
		if contract.phase=="active" and _job_remaining()==0:return "complete"
		return contract.phase
	return "closed" if _used("job") else "offer"
func contract_options()->Array:
	if ended or actions.size()>=MAX_ACTIONS-1 or not _near("M"):return []
	var phase:=_job_phase();var offer:=_job_manifest()
	if phase=="offer":
		var rows:Array=[{"id":"job_buyward","label":"直接买护符1件：12金币"},{"id":"job_buypierce","label":"直接买凿甲钉1件：18金币"}]
		if _job_remaining()==offer.points.size():rows.append({"id":"job_accept","label":"接路线订单：暂押12金币"})
		return rows
	if floor_number!=offer.source:return []
	if phase=="active":return [{"id":"job_cancel","label":"取消未履约订单：损失12金币押金"}]
	if phase=="complete":return [{"id":"job_refund","label":"履约退回12金币押金（库存不限）"}]
	if phase=="voucher":return [{"id":"job_ward","label":"花8金币兑换护符%d件" % offer.reward_count},{"id":"job_pierce","label":"花8金币兑换凿甲钉%d件" % offer.reward_count},{"id":"job_decline","label":"放弃兑换资格：免费，不再扣钱"}]
	return []
func contract_view()->Dictionary:
	var offer:=_job_manifest();var phase:=_job_phase();var remaining:=_job_remaining()
	var status:String={"offer":"本层订单未使用。直接买或接单只能选一次。","active":"尚余%d名指定守卫；返回第%d层营地办理。" % [remaining,offer.source],"complete":"指定守卫已清除；回第%d层营地先退押金。" % offer.source,"voucher":"押金已退；在第%d层营地可选折价兑换或免费放弃。" % offer.source,"closed":"本层订单机会已使用。"}[phase]
	if ended:status="旅程已结束，未退押金不结算；不能再领取或采购。"
	var rows:=contract_options()
	return {"title":"营地军需订单","body":"先押12金币，清指定路线后回原层退12。再自愿花8金币换%d件道具；不兑换不扣钱。无超时；取消未履约或旅程结束损失未退押金。" % offer.reward_count,"status":status,"phase":phase,"source":offer.source,"remaining":remaining,"route_label":offer.route_label,"target_points":offer.points,"reward_count":offer.reward_count,"deposit":12,"exchange_price":8,"available":not rows.is_empty(),"options":rows}
func apply_code(code:String)->Dictionary:
	if code.begins_with("job_"):return act(code)
	return super.apply_code(code)
func act(id:String)->Dictionary:
	if not id.begins_with("job_"):return super.act(id)
	if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能办理订单；仍可结束旅程。")
	var wanted:String="job_cancel" if id=="job_cancel!" else id
	var offered:=false
	for row in contract_options():
		if row.id==wanted:offered=true
	if not offered:return _reply("当前地点或订单状态不允许此操作。")
	if id=="job_cancel":return {"changed":false,"confirm":true,"message":"确定取消？已交12金币押金不退，订单机会和兑换资格永久放弃。"}
	var offer:=_job_manifest()
	if id=="job_accept":
		if gold<12:return _reply("需要12金币押金，未扣钱。")
		gold-=12;_mark("job");contract={"source":floor_number,"phase":"active"}
	elif id=="job_refund":
		gold+=12;contract.phase="voucher"
	elif id in ["job_cancel!","job_decline"]:contract={}
	elif id in ["job_ward","job_pierce","job_buyward","job_buypierce"]:
		var direct:bool=id.begins_with("job_buy")
		var item:String="ward" if id in ["job_ward","job_buyward"] else "pierce"
		var count:int=1 if direct else int(offer.reward_count)
		var price:int=(12 if item=="ward" else 18) if direct else 8
		if int(items[item])+count>9:return _reply("库存需完整容纳%d件（上限9）；不扣钱，订单资格保留。" % count)
		if gold<price:return _reply("需要%d金币；没有扣钱或消耗资格。" % price)
		gold-=price;items[item]+=count;_mark("job")
		if not direct:contract={}
	_record(id)
	return _reply({"job_accept":"已押12金币接单；不设期限，尚未支付兑换价。","job_refund":"已退12金币；可自愿花8金币兑换，或免费放弃。","job_cancel!":"已取消，12金币押金不退。","job_decline":"已免费放弃兑换资格。"}.get(id,"军需采购完成，金币和完整数量道具已结算。"),true)
