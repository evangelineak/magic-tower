class_name TowerEndlessWorldV2
extends RefCounted
## Separate deterministic expedition. Old TowerWorld/schema19 are untouched.
const Generator=preload("res://scripts/endless_generation_v2.gd")
const Navigation=preload("res://scripts/navigation.gd")
const MAX_ACTIONS:=100000
const MAX_FLOOR:=1000000
const MAX_STAT:=10000000
const MAX_HP:=3000
const DIRECTIONS={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
const ACTION_IDS=["buy_potion","buy_sword","buy_armor","skill_power","skill_guard","skill_mend","retire","cargo_use","cargo_accept","cargo_open","cargo_deliver","cargo_mod_power","cargo_mod_guard","cargo_mod_keys"]
var cargo:Dictionary={"state":"fresh","source":0,"target":0,"reward":""}
var seed:=0
var floor_number:=1
var pos:=Vector2i(1,1)
var hp:=150
var atk:=20
var defense:=10
var gold:=0
var keys:=0
var kills:=0
var max_floor:=1
var ended:=false
var ended_reason:=""
var actions:Array[String]=[]
var deltas:Dictionary={}
var choices:Dictionary={}
var _maps:Dictionary={}
static func new_run(run_seed:int):
	if run_seed<0 or run_seed>2147483647:return null
	var w=load("res://scripts/endless_world_v2.gd").new()
	w.seed=run_seed
	return w
static func from_data(data:Dictionary):
	if data.size()!=4 or data.get("version")!=2 or data.get("mode")!="endless":return null
	var raw_seed=data.get("seed")
	if not (raw_seed is int or raw_seed is float) or not is_finite(float(raw_seed)) or raw_seed!=floor(float(raw_seed)) or raw_seed<0 or raw_seed>2147483647:return null
	if not data.get("actions") is Array or data.actions.size()>MAX_ACTIONS:return null
	var w=new_run(int(raw_seed))
	for action in data.actions:
		if not action is String or action.length()>16:return null
		var result:Dictionary=w.apply_code(action)
		if not result.get("changed",false) or w.actions.back()!=action:return null
	return w
func clone():
	var w=new_run(seed)
	for key in ["floor_number","pos","hp","atk","defense","gold","keys","kills","max_floor","ended","ended_reason"]:w.set(key,get(key))
	w.cargo=cargo.duplicate(true)
	w.actions=actions.duplicate();w.deltas=deltas.duplicate(true);w.choices=choices.duplicate(true);w._maps=_maps.duplicate(true)
	return w
func apply_code(code:String)->Dictionary:
	if code in ["U","D","L","R","U!","D!","L!","R!"]:
		var direction:Vector2i=DIRECTIONS[code.trim_suffix("!")]
		if code.ends_with("!"):
			var target:=pos+direction;var token:=tile(target)
			if token!="D" and (token not in enemy_tokens() or preview(target).survivable):return _reply("此动作无需确认。")
		return step(direction,code.ends_with("!"))
	if code in ACTION_IDS:return act(code)
	return _reply("未知指令。")
func save_data()->Dictionary:
	return {"version":2,"mode":"endless","seed":seed,"actions":actions.duplicate()}
func _base(f:int)->Array:
	if not _maps.has(f):
		_maps.clear()
		_maps[f]=Generator.generate(seed,f).grid
	return _maps[f]
func rule_version()->int:return 2
func enemy_tokens()->Array[String]:return ["g","b","w","V"]
func station_tokens()->Array[String]:return ["M","S","C"]
func grid()->Array:
	var result:Array=_base(floor_number).duplicate(true)
	for index in deltas.get(floor_number,{}):result[index/15][index%15]="."
	return result
func tile(point:Vector2i)->String:
	if point.x<0 or point.y<0 or point.x>=15 or point.y>=15:return "#"
	if deltas.get(floor_number,{}).has(point.y*15+point.x):return "."
	return _base(floor_number)[point.y][point.x]
func _consume(point:Vector2i):
	if not deltas.has(floor_number):deltas[floor_number]={}
	deltas[floor_number][point.y*15+point.x]=true
func _adjacent(point:Vector2i)->bool:return absi(point.x-pos.x)+absi(point.y-pos.y)==1
func _near(token:String)->bool:
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if tile(pos+d)==token:return true
	return false
func _used(id:String)->bool:return choices.get(floor_number,{}).get(id,false)
func _mark(id:String):
	if not choices.has(floor_number):choices[floor_number]={}
	choices[floor_number][id]=true
func _reply(message:String,changed:bool=false)->Dictionary:return {"changed":changed,"message":message}
func _record(action:String):actions.append(action)
func enemy(token:String)->Dictionary:
	var f:=floor_number
	match token:
		"g":return {"hp":30,"atk":14+2*f,"def":9+3*f,"gold":18}
		"b":return {"hp":24,"atk":13+2*f,"def":3+3*f,"gold":5}
		"w":return {"hp":30,"atk":18+2*f,"def":3+3*f,"gold":25}
	return {"hp":70,"atk":28+2*f,"def":17+3*f,"gold":35}
func preview(target:Vector2i)->Dictionary:
	var token:=tile(target)
	var names:Dictionary={"g":"铁甲关尉：高防短路","b":"双刃矮兵：两哨低赏","w":"法袍守卫：高攻高赏","C":"封存补给：立即用或跨层运输","V":"宝库守卫：可成长后回访","a":"旅途训练：攻击 +3，防御 +2","h":"补给：生命 +20（上限3000）","k":"钥匙 +1","D":"宝库门：消耗1钥匙","$":"金币箱：+40金币","T":"宝库遗物：攻击+6，防御+4，生命+50","M":"旅行商人","S":"本层技能抉择","<":"下楼",">":"上楼",".":"安全空地","#":"墙"}
	var info:Dictionary={"title":names.get(token,token),"lines":[],"damage":0,"survivable":true,"valid":true,"token":token}
	if token in enemy_tokens():
		var foe:=enemy(token);var hit:int=maxi(0,atk-int(foe.def))
		var turns:int=ceili(float(foe.hp)/hit) if hit>0 else 0
		var damage:int=maxi(0,turns-1)*maxi(0,int(foe.atk)-defense)
		info.damage=damage;info.valid=hit>0;info.survivable=hit>0 and damage<hp
		info.enemy=foe;info.rounds=turns
		info.lines=["敌人生命%d / 攻击%d / 防御%d" % [foe.hp,foe.atk,foe.def],"预计损失%d生命；胜利+%d金币" % [damage,foe.gold] if hit>0 else "无法破防，先成长再回来。"]
	elif token=="D":info.lines=["钥匙%d；门后40金币。" % keys]
	else:info.lines=[str(info.title)]
	return info
func step(delta:Vector2i,confirmed:bool=false)->Dictionary:
	if ended:return _reply("旅程已结束。")
	if actions.size()>=MAX_ACTIONS-1:return _reply("达到本原型10万次动作安全上限，请保存后开始新旅程。")
	if absi(delta.x)+absi(delta.y)!=1:return _reply("只能正交移动一格。")
	var target:=pos+delta;var token:=tile(target)
	if token=="#":return _reply("这里是墙。")
	if token in station_tokens():return {"changed":false,"message":"选择一个选项。","options":options(target)}
	if token=="<" and floor_number==1:return _reply("已经位于入口层。")
	if token==">" and floor_number>=MAX_FLOOR:return _reply("达到100万层数值安全边界；仍可回访。")
	if token=="D" and keys<1:return _reply("需要一把钥匙。")
	if token=="D" and not confirmed:return {"changed":false,"confirm":true,"message":"消耗1把钥匙打开宝库门？"}
	var battle:Dictionary={}
	if token in enemy_tokens():
		battle=preview(target)
		if not battle.valid:return _reply("无法破防，先成长再回来。")
		if not battle.survivable and not confirmed:return {"changed":false,"confirm":true,"message":"这场战斗会结束旅程，确认仍要进攻？","battle":battle}
		if not battle.survivable:
			hp=0;ended=true;ended_reason="death"
		else:
			hp-=int(battle.damage);kills+=1;gold=mini(MAX_STAT,gold+int(battle.enemy.gold));_consume(target)
	elif token=="D":keys-=1;_consume(target)
	elif token=="a":atk=mini(MAX_STAT,atk+3);defense=mini(MAX_STAT,defense+2);_consume(target)
	elif token=="h":hp=mini(MAX_HP,hp+20);_consume(target)
	elif token=="k":keys=mini(MAX_STAT,keys+1);_consume(target)
	elif token=="$":gold=mini(MAX_STAT,gold+40);_consume(target)
	elif token=="T":atk=mini(MAX_STAT,atk+6);defense=mini(MAX_STAT,defense+4);hp=mini(MAX_HP,hp+50);_consume(target)
	if not ended:
		pos=target
		if token in ["<",">"]:
			floor_number+=1 if token==">" else -1
			max_floor=maxi(max_floor,floor_number)
			# Alternating anchors place the paired staircase at this exact coordinate.
			_base(floor_number)
	var code:String=""
	for key in DIRECTIONS:
		if DIRECTIONS[key]==delta:code=key
	# Confirmation is recorded only for genuinely fatal battles, not arbitrary moves.
	if ended or token=="D":code+="!"
	_record(code)
	var result:=_reply("旅程结束。" if ended else "已行动。",true)
	if not battle.is_empty():result.battle=battle
	return result
func options(target:Vector2i)->Array:
	if ended or not (_adjacent(target) or target==pos):return []
	var token:=tile(target);var result:Array=[]
	if token=="M":
		for offer in [["buy_potion","15金币：恢复50生命"],["buy_sword","25金币：攻击+3"],["buy_armor","20金币：防御+2"]]:
			if not _used(offer[0]):result.append({"id":offer[0],"label":offer[1]+"（每层一次）"})
	if token=="C":
		result.append({"id":"cargo_use","label":"现在使用补给：恢复20生命"})
		if cargo.state=="fresh" and floor_number<=MAX_FLOOR-2:result.append({"id":"cargo_accept","label":"运输到第%d层商人：放弃现在的20生命，换一次装备改造" % (floor_number+2)})
	if token in ["C","M"]:
		if cargo.state=="carried":
			result.append({"id":"cargo_open","label":"拆开运输中的旧箱：恢复20生命，放弃改造奖励"})
			if token=="M" and floor_number==cargo.target:result.append({"id":"cargo_deliver","label":"交付运输箱：开启一次三选一改造"})
		if token=="M" and floor_number==cargo.target and cargo.state=="delivered" and cargo.reward=="":
			result.clear()
			result.append_array([{"id":"cargo_mod_power","label":"改造武器：攻击+4"},{"id":"cargo_mod_guard","label":"改造护甲：防御+3"},{"id":"cargo_mod_keys","label":"领取工具：钥匙+2"}])
	if token=="S" and not _used("skill"):
		result=[{"id":"skill_power","label":"破甲训练：攻击+2"},{"id":"skill_guard","label":"守势训练：防御+1"},{"id":"skill_mend","label":"急救：恢复35生命；放弃本层永久成长"}]
	return result
func act(id:String)->Dictionary:
	if ended or actions.size()>=MAX_ACTIONS:return _reply("当前不能行动。")
	if id=="retire":
		ended=true;ended_reason="retired";_record(id)
		return _reply("已安全结束旅程。",true)
	if actions.size()>=MAX_ACTIONS-1:return _reply("达到动作安全上限，可以结束旅程并结算。")
	if id not in ACTION_IDS:return _reply("未知选项。")
	if id.begins_with("cargo_"):return _cargo_action(id)
	if id.begins_with("buy_"):
		if not _near("M") or _used(id):return _reply("需在商人旁，且本层尚未购买。")
		var price:int={"buy_potion":15,"buy_sword":25,"buy_armor":20}[id]
		if gold<price:return _reply("金币不足。")
		if id=="buy_potion" and hp>=MAX_HP:return _reply("生命已满，无需购买。")
		gold-=price;_mark(id)
		if id=="buy_potion":hp=mini(MAX_HP,hp+50)
		elif id=="buy_sword":atk=mini(MAX_STAT,atk+3)
		else:defense=mini(MAX_STAT,defense+2)
	else:
		if not _near("S") or _used("skill"):return _reply("需在技能石旁，每层只能选择一次。")
		_mark("skill")
		if id=="skill_power":atk=mini(MAX_STAT,atk+2)
		elif id=="skill_guard":defense=mini(MAX_STAT,defense+1)
		else:hp=mini(MAX_HP,hp+35)
	_record(id);return _reply("选择已生效。",true)
func safe_path(target:Vector2i)->Array[Vector2i]:
	if ended:return []
	return Navigation.walk_path(grid(),pos,target)
# A concrete rule witness, not an assertion based only on connectivity. Stations
# are skirted, and the starting weapon/food are collected before crossing the gate.
func witness_targets()->Array[Vector2i]:
	if floor_number%2==1:return [Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),Vector2i(4,3),Vector2i(3,3),Vector2i(3,13),Vector2i(13,13)]
	return [Vector2i(12,13),Vector2i(11,13),Vector2i(4,13),Vector2i(4,10),Vector2i(3,10),Vector2i(3,1),Vector2i(1,1)]
# Inductive minimum-budget certificate for this version's mandatory route.
# Optional guard fights/purchases may invalidate the player's assumptions; this
# does not promise all choices win. The real route is exercised in tests.
static func minimum_budget(f:int)->Dictionary:
	if f<1 or f>MAX_FLOOR:return {"valid":false}
	return {"valid":true,"floor":f,"entry_atk":20+3*(f-1),"entry_defense":10+2*(f-1),"entry_hp_min":1,"training_atk":3,"training_defense":2,"healing":20,"gate_damage":8,"min_exit_hp":13,"requires_optional_reward":false,"requires_immediate_supply":true}
func _cargo_action(id:String)->Dictionary:
	var box:=Vector2i(-1,-1)
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if tile(pos+d)=="C":box=pos+d;break
	if id in ["cargo_use","cargo_accept"]:
		if box.x<0:return _reply("需要在未领补给箱旁。")
		if id=="cargo_accept":
			if cargo.state!="fresh" or floor_number>MAX_FLOOR-2:return _reply("本局只有一次运输委托，或目标层超出安全边界。")
			cargo={"state":"carried","source":floor_number,"target":floor_number+2,"reward":""}
		else:hp=mini(MAX_HP,hp+20)
		_consume(box)
	elif id=="cargo_open":
		if cargo.state!="carried" or (box.x<0 and not _near("M")):return _reply("到补给箱或商人旁才能拆封运输箱。")
		hp=mini(MAX_HP,hp+20);cargo.state="opened"
	elif id=="cargo_deliver":
		if cargo.state!="carried" or floor_number!=cargo.target or not _near("M"):return _reply("尚未到达约定层的商人。")
		cargo.state="delivered"
	else:
		if id not in ["cargo_mod_power","cargo_mod_guard","cargo_mod_keys"] or cargo.state!="delivered" or cargo.reward!="" or floor_number!=cargo.target or not _near("M"):return _reply("没有可领取的改造奖励。")
		cargo.reward=id
		if id=="cargo_mod_power":atk=mini(MAX_STAT,atk+4)
		elif id=="cargo_mod_guard":defense=mini(MAX_STAT,defense+3)
		else:keys=mini(MAX_STAT,keys+2)
	_record(id);return _reply("补给选择已记录。",true)
func summary()->Dictionary:
	var routes:Array=[]
	for route in [{"label":"重甲短路" if Generator.layout(seed,floor_number)=="courtyard" else "猛攻关隘","points":[Generator.PRIMARY]},{"label":"双哨巡逻线","points":Generator.alternate_points(seed,floor_number)}]:
		var damage:=0;var remaining:=0;var valid:=true;var reward:=0
		for point in route.points:
			if tile(point) not in enemy_tokens():continue
			var info:=preview(point);remaining+=1;damage+=int(info.damage);valid=valid and info.valid;reward+=int(info.enemy.gold)
		routes.append({"label":route.label,"damage":damage,"valid":valid,"remaining":remaining,"gold":reward})
	var description:String="本局可接一次委托：把入口20生命补给运到两层后，换三选一改造。"
	if cargo.state=="carried":description="运输中：第%d层箱 → 第%d层商人。可在箱/商人旁拆封取20生命，放弃奖励。" % [cargo.source,cargo.target]
	elif cargo.state=="opened":description="运输箱已拆封，改造奖励已放弃。"
	elif cargo.state=="delivered":description="已交付：在目标层商人旁三选一改造。" if cargo.reward=="" else "本局运输委托已完成，改造只领取一次。"
	return {"layout":"双关隘庭院" if Generator.layout(seed,floor_number)=="courtyard" else "断壁回廊","cargo":description,"routes":routes,"goal":"先取训练；补给可立即使用或运输。两路损失仅统计剩余守卫，不保证路线可达。"}
