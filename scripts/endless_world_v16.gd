class_name TowerEndlessWorldV16
extends "res://scripts/endless_world_v15.gd"
const Generation16=preload("res://scripts/endless_generation_v16.gd")
var bridges:Dictionary={}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v16.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=16 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 16
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=16;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
	w.messenger=messenger.duplicate(true);w.cargo=cargo.duplicate(true)
	w.training_packs=training_packs;w.bonus_atk=bonus_atk;w.bonus_def=bonus_def;w.lessons_used=lessons_used;w.relief_remaining=relief_remaining
	w.items=items.duplicate(true);w.armed_item=armed_item
	w.bridges=bridges.duplicate(true)
	w.runes=runes.duplicate(true)
	w.gear=gear;w.owned_gear=owned_gear.duplicate(true)
	w.contract=contract.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func summary()->Dictionary:
	# Explicit metadata avoids the frozen v6 summary's v6-only simulator factory.
	var data:Dictionary={"layout":Generation16.layout_name(seed,floor_number),"cargo":_cargo_summary(),"messenger":case_status(),"goal":"先取训练与补给。先制在玩家出手前发生；蓄力是首反击双倍。路线提示只统计剩余守卫。","tactic":tactic_data(),"encounter":encounter_view(),"items":item_view()}
	var rows:Array=[]
	for route in Generation16.routes(seed,floor_number):
		var sim=new_run(seed)
		for key in ["floor_number","pos","hp","atk","defense","tactic","training_level","relic_bonus","armed_item","gear"]:sim.set(key,get(key))
		sim.bridges=bridges.duplicate(true)
		sim.runes=runes.duplicate(true)
		sim.items=items.duplicate(true);sim.deltas={floor_number:deltas.get(floor_number,{}).duplicate(true)};sim._maps={floor_number:_base(floor_number)}
		var points:Array=route.points.duplicate()
		if Generation16.has_bridge(seed,floor_number) and bridges.get(floor_number,"")=="short" and points.size()==2:
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
			healed+=int(info.heal_after);sim.hp=sim.hp-int(info.damage)+int(info.heal_after);sim._consume_armed_item()
		rows.append({"label":route.label,"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":count,"gold":reward})
	data.routes=rows;return data
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation16.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:return Generation16.manifest(seed,int(contract.get("source",floor_number)))
func tile(point:Vector2i)->String:
	var t:String=super.tile(point);var chosen:String=bridges.get(floor_number,"")
	if (t=="u" and chosen=="short") or (t=="v" and chosen=="loot"):return "."
	return t
func grid()->Array:
	var result:Array=super.grid();var chosen:String=bridges.get(floor_number,"")
	for y in 15:
		for x in 15:
			if (result[y][x]=="u" and chosen=="short") or (result[y][x]=="v" and chosen=="loot"):result[y][x]="."
	return result
func station_tokens()->Array[String]:return ["M","S","C","N"]
func _bridge_enemy(point:Vector2i)->Dictionary:
	if tile(point) not in enemy_tokens():return {"cleared":true,"target":point,"damage":0,"net_damage":0,"gold":0,"survivable":true,"valid":true,"title":"已清除"}
	var data:=preview(point);data.target=point;data.cleared=false;data.gold=int(data.enemy.gold);return data
func bridge_view()->Dictionary:
	var map:=Generation16.bridge_info(seed,floor_number);var choice:String=bridges.get(floor_number,"")
	var near:bool=map.present and _near("N");var reason:=""
	if not map.present:reason="本层没有双臂绞盘。"
	elif ended:reason="旅程已结束。"
	elif choice!="":reason="已落下一臂，另一臂永久锁死。"
	elif not near:reason="需站在绞盘正交相邻格操作；不会自动开桥或战斗。"
	elif keys<1:reason="需要1把钥匙；钥匙也可用于原宝库门。"
	elif actions.size()>=MAX_ACTIONS-1:reason="行动额度不足，没有扣钥匙。"
	var bypassed:Dictionary=_bridge_enemy(map.bypassed) if map.present else {}
	var remaining:Dictionary=_bridge_enemy(map.remaining) if map.present else {}
	var guardian:Dictionary=_bridge_enemy(map.guardian) if map.present else {}
	var arms:Array=[]
	for id in ["short","loot"]:
		var state:String="raised" if choice=="" else ("lowered" if choice==id else "locked")
		arms.append({"id":id,"cells":map[id].duplicate(),"state":state,"title":"绕哨短桥" if id=="short" else "守护宝桥","body":"花1钥匙绕过第一支路守卫，第二只仍挡路。未击杀怪留在原位，可以后回杀取金币；不绕宝库门。" if id=="short" else "花1钥匙进入额外守卫宝岛：1护符+1凿甲钉，无金币。两种库存各需空1格；不可胜可成长后回访。","bypassed":bypassed if id=="short" else {},"remaining":remaining if id=="short" else {},"guardian":guardian if id=="loot" else {},"reward":{"ward":1,"pierce":1,"gold":0} if id=="loot" else {}})
	var rows:Array=[{"id":"bridge_short","label":"1钥匙：绕过第一支路守卫，锁死宝桥"},{"id":"bridge_loot","label":"1钥匙：开放额外守卫宝岛，锁死短桥"}] if reason=="" else []
	return {"present":map.present,"winch":map.winch,"choice":choice,"near":near,"available":reason=="","reason":reason,"keys":keys,"floor":floor_number,"arms":arms,"options":rows}
func bridge_options()->Array:return bridge_view().options
func options(target:Vector2i)->Array:
	if tile(target)=="N":return bridge_options() if _adjacent(target) else []
	return super.options(target)
func act(id:String)->Dictionary:
	if id not in ["bridge_short","bridge_loot","bridge_short!","bridge_loot!"]:return super.act(id)
	var view:=bridge_view()
	if not view.available:return _reply(view.reason)
	var side:String="short" if id.begins_with("bridge_short") else "loot"
	if not id.ends_with("!"):return {"changed":false,"confirm":true,"bridge_choice":side,"message":"确认消耗1把钥匙落下%s？另一臂永久锁死，不会自动移动或战斗。" % ("绕哨短桥" if side=="short" else "守护宝桥")}
	keys-=1;bridges[floor_number]=side;_record(id)
	return _reply("已消耗1把钥匙落桥，另一臂永久锁死；怪物与宝库门原样保留。",true)
func apply_code(code:String)->Dictionary:
	if code in ["bridge_short!","bridge_loot!"]:return act(code)
	if code in ["bridge_short","bridge_loot"]:return _reply("未确认的桥动作不能进入存档。")
	return super.apply_code(code)
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	var token:=tile(pos+delta)
	if token in ["u","v"]:return _reply("桥臂尚未放下或已锁死；到绞盘旁选择，不能直接穿越。")
	if token=="B" and (int(items.ward)>=9 or int(items.pierce)>=9):return _reply("宝箱原地保留：护符与凿甲钉库存各需空1格，不能部分领取。")
	var result:Dictionary=super.step(delta,confirmed)
	if result.get("changed",false) and token=="B" and not ended:
		items.ward+=1;items.pierce+=1;_consume(pos);result.message="宝岛箱：获得1护符与1凿甲钉，无金币；不会重复领取。"
	return result
func preview(target:Vector2i)->Dictionary:
	var t:=tile(target)
	if t not in ["N","u","v","B"]:return super.preview(target)
	var names:Dictionary={"N":"双臂绞盘：一钥匙二择一","u":"绕哨短桥：未落下或已锁死","v":"守护宝桥：未落下或已锁死","B":"宝岛箱：护符1件、凿甲钉1件"}
	var lines:Array=["只有绞盘相邻可确认开桥；远处查看不消费钥匙。","两臂仅选一条，另一条本层永久锁死；普通路线不依赖机关。"]
	if t=="B":lines=["获得护符1件与凿甲钉1件，不给金币。","两种道具各需1个空位；不足时整箱保留可回访。"]
	return {"title":names[t],"token":t,"lines":lines,"valid":true,"survivable":true,"damage":0}
func rune_view()->Dictionary:
	var view:Dictionary=super.rune_view()
	if not view.available or not Generation16.has_bridge(seed,floor_number) or bridges.get(floor_number,"")!="short":return view
	# The rejected treasure island can never reopen. Its visible guardian must
	# not justify charging for a rune with no effect on any reachable battle.
	var before=clone();before.runes.erase(floor_number)
	var after=clone();after.runes[floor_number]=true
	var effect:=false
	for y in 15:
		for x in 15:
			var p:=Vector2i(x,y)
			if p==Vector2i(6,4) or tile(p) not in enemy_tokens():continue
			var a:Dictionary=before.preview(p);var b:Dictionary=after.preview(p)
			if view.kind=="silence":
				if int(a.get("heal_after",0))>0 or (tile(p)=="p" and (int(a.get("regen_total",0))>0 or a.valid!=b.valid)):effect=true
			else:
				for key in ["damage","net_damage","valid","survivable","rounds","heal_after","reflection_damage","regen_total"]:
					if a.get(key,0)!=b.get(key,0):effect=true
	if not effect:view.available=false;view.options=[];view.reason="可达战斗没有实际效果；已锁宝岛的守卫不计入，不收金币。"
	return view
