class_name TowerEndlessWorldV19
extends "res://scripts/endless_world_v18.gd"
const Generation19=preload("res://scripts/endless_generation_v19.gd")
var carts:Dictionary={}
var _cart_cache_key:String=""
var _cart_cache:Dictionary={}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v19.gd").new();w.seed=run_seed;return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=19 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func rule_version()->int:return 19
func save_data()->Dictionary:
	var data:Dictionary=super.save_data();data.version=19;return data
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason","tactic","training_level","relic_bonus"]:w.set(key,get(key))
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
			healed+=int(info.heal_after);sim.hp=sim.hp-int(info.damage)+int(info.heal_after);sim._consume_armed_item()
		rows.append({"label":route.label,"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":count,"gold":reward})
	data.routes=rows;return data
func _base(f:int)->Array:
	if not _maps.has(f):_maps.clear();_maps[f]=Generation19.generate(seed,f).grid
	return _maps[f]
func _job_manifest()->Dictionary:return Generation19.manifest(seed,int(contract.get("source",floor_number)))
func _cart_state()->Dictionary:
	var info:=_cart_manifest()
	if not info.present:return {}
	return carts.get(floor_number,{"pos":info.cart_origin,"claim":""})
func _cart_open(side:String)->bool:
	var info:=_cart_manifest();var state:=_cart_state()
	if not info.present:return false
	return state.claim==side if state.claim!="" else state.pos==info.sockets[side]
func tile(point:Vector2i)->String:
	var token:String=super.tile(point)
	var info:=_cart_manifest()
	if not info.present:return token
	if point==_cart_state().pos:return "O"
	if token in ["O","o","q"]:return "."
	if token=="u" and _cart_open("supply"):return "."
	if token=="v" and _cart_open("archive"):return "."
	return token
func grid()->Array:
	if not _cart_manifest().present:return super.grid()
	var result:Array=[]
	for y in 15:
		var row:Array=[]
		for x in 15:row.append(tile(Vector2i(x,y)))
		result.append(row)
	return result
func cart_reward_quote(side:String)->Dictionary:
	var info:=_cart_manifest()
	var reason:="";var q:Dictionary={"side":side,"title":"物资箱：1护符与1凿甲钉" if side=="supply" else "档案遗物：按实际预算结算","ward":1 if side=="supply" else 0,"pierce":1 if side=="supply" else 0,"gold":0}
	if side=="archive":q.merge(relic_quote(),true)
	if not info.present or side not in ["supply","archive"]:reason="此处没有运石奖励。"
	elif ended:reason="旅程已结束。"
	elif actions.size()>=MAX_ACTIONS-1:reason="行动容量不足，请结束本局。"
	elif _cart_state().claim!="":reason="共享机会已经使用；另一份奖励作废，不会重复领取。"
	elif side=="supply" and (int(items.ward)>=9 or int(items.pierce)>=9):reason="两种道具各需1空位，整箱保留，暂不锁定选择。"
	elif side=="archive" and not q.allowed:reason=q.reason
	q.allowed=reason=="";q.reason=reason
	return q
func cart_push_quote(delta:Vector2i)->Dictionary:
	var info:=_cart_manifest();var reason:=""
	if not info.present:reason="本层没有石车。"
	elif ended or actions.size()>=MAX_ACTIONS-1:reason="当前不能行动。"
	elif absi(delta.x)+absi(delta.y)!=1:reason="只能正交推一格。"
	elif _cart_state().claim!="":reason="奖励已领取，石车固定，选中门保持打开。"
	elif pos+delta!=_cart_state().pos:reason="需站在石车正交相邻格，向车方向推。"
	elif _cart_state().pos+delta not in info.board:reason="前方不在轨道或有石柱，不能出轨。"
	elif tile(_cart_state().pos+delta)!=".":reason="前方不是空轨道，不能推入物品、怪物或机关。"
	return {"delta":delta,"allowed":reason=="","reason":reason}
func _cart_reset_reason()->String:
	var info:=_cart_manifest()
	if not info.present:return "本层没有复位站。"
	if ended or actions.size()>=MAX_ACTIONS-1:return "当前不能行动。"
	if not _adjacent(info.reset):return "需要站在复位站正交相邻格。"
	if _cart_state().claim!="":return "已领取奖励，石车固定，不能复位改选。"
	if pos==info.cart_origin:return "玩家占据石车原点，不能复位。"
	if _cart_state().pos==info.cart_origin:return "石车已在原点，没有动作。"
	return ""
func cart_view()->Dictionary:
	var info:=_cart_manifest()
	if not info.present:return {"present":false}
	var view:Dictionary=info.duplicate(true);var state:=_cart_state()
	view.origin=info.cart_origin;view.cart_pos=state.pos;view.claim=state.claim
	view.reset_reason=_cart_reset_reason();view.reset_allowed=view.reset_reason==""
	view.gates={};view.rewards={};view.pushes=[]
	for side in ["supply","archive"]:
		view.gates[side]={"pos":info.gates[side],"open":_cart_open(side),"locked":state.claim!="" and state.claim!=side}
		view.rewards[side]={"pos":info.rewards[side],"quote":cart_reward_quote(side)}
	for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:view.pushes.append(cart_push_quote(delta))
	return view
func station_tokens()->Array[String]:
	var result:Array[String]=super.station_tokens();result.append("R");return result
func options(target:Vector2i)->Array:
	if tile(target)=="R":return [{"id":"cart_reset","label":"免费复位石车；未领取前可重试"}] if _adjacent(target) and _cart_reset_reason()=="" else []
	return super.options(target)
func act(id:String)->Dictionary:
	if id!="cart_reset":return super.act(id)
	var reason:=_cart_reset_reason()
	if reason!="":return _reply(reason)
	var info:=_cart_manifest()
	carts[floor_number]={"pos":info.cart_origin,"claim":""};_record(id)
	return _reply("石车已免费复位，未领取奖励，怪物与已清除格不重置。",true)
func apply_code(code:String)->Dictionary:
	if code=="cart_reset":return act(code)
	if code in ["U!","D!","L!","R!"]:
		var delta:Vector2i=DIRECTIONS[code.trim_suffix("!")]
		if tile(pos+delta) in ["J","L"]:return step(delta,true)
	return super.apply_code(code)
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if not _cart_manifest().present:return super.step(delta,confirmed)
	if ended or actions.size()>=MAX_ACTIONS-1:return _reply("当前不能行动。")
	if absi(delta.x)+absi(delta.y)!=1:return _reply("只能正交行动一格。")
	var target:=pos+delta;var token:=tile(target)
	if token=="O":
		var q:=cart_push_quote(delta)
		if not q.allowed:return _reply(q.reason)
		carts[floor_number]={"pos":target+delta,"claim":""};pos=target
		for code in DIRECTIONS:
			if DIRECTIONS[code]==delta:_record(code);break
		return _reply("石车推进一格；插槽与连线决定当前开门，尚未领取奖励。",true)
	if token=="R":return act("cart_reset")
	if token in ["u","v"]:return _reply("此门尚未由对应插槽打开，或另一份奖励已作废。")
	if token not in ["J","L"]:return super.step(delta,confirmed)
	var side:="supply" if token=="J" else "archive";var q:=cart_reward_quote(side)
	if not q.allowed:return _reply(q.reason)
	if not confirmed:
		var detail:="获得1护符与1凿甲钉。" if side=="supply" else "实际攻击+%d、防御+%d、遗物等级+%d、恢复%d生命。" % [q.atk_gain,q.def_gain,q.relic_gain,q.heal_actual]
		return {"changed":false,"confirm":true,"cart_claim":side,"message":detail+"领取后共享机会用尽，另一奖励作废；石车固定，当前门永久打开。确认领取？"}
	if side=="supply":items.ward+=1;items.pierce+=1
	else:
		bonus_atk+=int(q.atk_gain);bonus_def+=int(q.def_gain);relic_bonus+=int(q.relic_gain);hp+=int(q.heal_actual)
		atk=20+3*training_packs+bonus_atk;defense=10+2*training_packs+bonus_def
	carts[floor_number]={"pos":_cart_state().pos,"claim":side};_consume(target);pos=target
	for code in DIRECTIONS:
		if DIRECTIONS[code]==delta:_record(code+"!");break
	return _reply("已领取"+q.title+"；另一奖励作废，选中门保持打开，可以安全离开。",true)
func preview(target:Vector2i)->Dictionary:
	if not _cart_manifest().present:return super.preview(target)
	var info:=_cart_manifest();var token:=tile(target)
	if token not in ["O","R","u","v","J","L"] and target not in info.sockets.values():return super.preview(target)
	var title:="运石岔庭";var lines:Array=[]
	if token=="O":title="轨道石车：相邻推动";lines=["只可沿轨道推一格，不能推过石柱或出轨。","用不同插槽开不同门；领奖前可到复位站免费重试。"]
	elif token=="R":title="石车复位站";lines=["相邻操作，免费回原点；不复活怪物、不重新发奖励。",_cart_reset_reason()]
	elif token in ["J","L"]:
		var q:=cart_reward_quote("supply" if token=="J" else "archive");title=q.title
		lines=["共享一次机会：领取后另一奖励作废，石车固定，选门永久打开。"]
		if token=="J":lines.append("1护符+1凿甲钉，各需1空位，不能部分领取。")
		else:lines.append("实际攻击+%d、防御+%d、遗物等级+%d、恢复%d生命。" % [q.atk_gain,q.def_gain,q.relic_gain,q.heal_actual])
		lines.append("相邻领取需确认。" if q.allowed else q.reason)
	elif token in ["u","v"]:title="插槽连线门";lines=["对应插槽压上石车才打开；领取一份奖励后，另一门永久锁死。"]
	else:title="物资插槽" if target==info.sockets.supply else "档案插槽";lines=["将石车压上此槽，沿可见连线打开对应门；槽上空时可行走。"]
	return {"title":title,"token":token,"lines":lines,"valid":true,"survivable":true,"damage":0}
func rune_view()->Dictionary:
	var view:Dictionary=super.rune_view()
	if not view.available or not _cart_manifest().present or _cart_state().claim!="supply":return view
	# An archive permanently rejected by a supply claim cannot justify a paid rune.
	var before=clone();before.runes.erase(floor_number)
	var after=clone();after.runes[floor_number]=true
	var effect:=false
	for y in 15:
		for x in 15:
			var p:=Vector2i(x,y)
			if p==Vector2i(8,2) or tile(p) not in enemy_tokens():continue
			var a:Dictionary=before.preview(p);var b:Dictionary=after.preview(p)
			if view.kind=="silence":
				if int(a.get("heal_after",0))>0 or (tile(p)=="p" and (int(a.get("regen_total",0))>0 or a.valid!=b.valid)):effect=true
			else:
				for key in ["damage","net_damage","valid","survivable","rounds","heal_after","reflection_damage","regen_total"]:
					if a.get(key,0)!=b.get(key,0):effect=true
	if not effect:view.available=false;view.options=[];view.reason="可达战斗没有实际效果；已放弃档案的守卫不计入，不收金币。"
	return view

func _cart_manifest()->Dictionary:
	var key:String=str(seed)+":"+str(floor_number)
	if key!=_cart_cache_key:
		_cart_cache=Generation19.cart_manifest(seed,floor_number);_cart_cache_key=key
	return _cart_cache
