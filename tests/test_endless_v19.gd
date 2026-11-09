extends SceneTree
var W=preload("res://scripts/endless_world_v19.gd")
const G=preload("res://scripts/endless_generation_v19.gd")
var checks:=0
var failures:=0
var journey_loss:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func path(w,target:Vector2i,alternate:bool=false)->Array[Vector2i]:
	var avoid:Array=G.routes(w.seed,w.floor_number)[0 if alternate else 1].points.duplicate()
	if alternate and G.has_bridge(w.seed,w.floor_number) and w.bridges.get(w.floor_number,"")=="short":avoid.append(Vector2i(8,8))
	var queue:Array[Vector2i]=[w.pos];var parents:Dictionary={w.pos:w.pos};var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		if p==target:
			var result:Array[Vector2i]=[]
			while p!=w.pos:result.push_front(p);p=parents[p]
			return result
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d;var t:String=w.tile(q)
			if parents.has(q) or q in avoid or t in ["#","M","S","D","V","N","u","v","O","R","J","L"] or (t in ["<",">"] and q!=target):continue
			parents[q]=p;queue.append(q)
	return []
func go(w,target:Vector2i,alternate:bool=false)->bool:
	var route:=path(w,target,alternate)
	check(w.pos==target or not route.is_empty(),"legal route exists")
	for p in route:
		if w.tile(p)=="C":
			var supply:Dictionary=w.act("cargo_use") if w.relief_remaining>0 else {"changed":false}
			if not supply.changed:check(w.act("cargo_leave").changed,"free discard preserves path")
		var result:Dictionary=w.step(p-w.pos)
		if result.get("battle") is Dictionary:journey_loss+=int(result.battle.get("net_damage",result.battle.damage))
		if not result.changed or w.ended:
			check(false,"live route survives: "+str(result));return false
	return true
func first_supply(w,alternate:bool=false):
	var y:int=1 if w.floor_number%2 else 13
	go(w,Vector2i(2 if w.floor_number%2 else 12,y),alternate)
	go(w,Vector2i(3 if w.floor_number%2 else 11,y),alternate)
func camp(w,alternate:bool=false):
	var p:=G.camp_position(w.seed,w.floor_number)
	go(w,p+Vector2i.UP if w.floor_number%2 else p+Vector2i.DOWN,alternate)
func _init():
	cart_tests()
	# Finite sample regression against correlated linear-salt shuffles, not a statistical guarantee.
	var permutations:Dictionary={};var first_kinds:Dictionary={}
	for sd in 10000:
		var sample=W.new_run(sd);var order:Array=[]
		for f in range(1,5):order.append(sample.vault_kind(f))
		var signature:String="/".join(order)
		permutations[signature]=int(permutations.get(signature,0))+1
		first_kinds[order[0]]=int(first_kinds.get(order[0],0))+1
	check(permutations.size()==24,"sample includes all 24 reward orders")
	for count in permutations.values():check(count>=350 and count<=500,"sample permutation frequencies avoid prior severe salt correlation")
	for count in first_kinds.values():check(count>=2300 and count<=2700,"first-floor kinds not strongly skewed in fixed sample")
	for sd in [0,1,42,2147483647]:
		var v=W.new_run(sd)
		for block in [0,1,2,99,249999]:
			var kinds:Dictionary={}
			for offset in 4:kinds[v.vault_kind(block*4+offset+1)]=true
			check(kinds.size()==4,"every four floors contains each reward once")
	for kind in ["gold","medicine","ward","pierce"]:
		var v=W.new_run(42)
		for f in range(1,5):
			if v.vault_kind(f)==kind:v.floor_number=f;break
		v.pos=Vector2i(11,3);v.hp=150
		var q:Dictionary=v.vault_quote();var old_gold:int=v.gold
		check(q.kind==kind and q.allowed,"correct available vault quote")
		check(v.clone().vault_quote()==q,"clone reward forecast exact")
		check(v.step(Vector2i.RIGHT).changed,"vault actual pickup")
		check(v.gold-old_gold==q.gold and v.hp==q.hp_after,"gold and hp exact")
		check(v.items.ward==q.ward and v.items.pierce==q.pierce,"tools exact")
		check(v.tile(Vector2i(12,3))=="." and not v.vault_quote().allowed,"reward consumed once")
		var blocked=W.new_run(42);blocked.floor_number=v.floor_number;blocked.pos=Vector2i(11,3)
		if kind=="medicine":blocked.hp=180
		elif kind=="ward":blocked.items.ward=4
		elif kind=="pierce":blocked.items.pierce=7
		else:blocked.gold=blocked.MAX_STAT
		var prior:Dictionary=blocked.save_data()
		check(not blocked.step(Vector2i.RIGHT).changed and blocked.tile(Vector2i(12,3))=="$","unusable reward retained")
		check(blocked.save_data()==prior,"refusal records no event")
		blocked.pos=Vector2i(9,3);blocked.keys=1
		var prompt:Dictionary=blocked.step(Vector2i.RIGHT)
		check(prompt.get("confirm",false),"door still confirms blocked reward")
		if kind=="medicine":check("实际恢复0" in prompt.message,"door quotes actual capped healing")
		if kind in ["ward","pierce"]:check("/9" in prompt.message and "空位" in prompt.message,"door quotes held tools and required capacity")
		check(blocked.step(Vector2i.RIGHT,true).changed and blocked.keys==0,"may explicitly open for revisit")
	for candidate in ["final_b"]:
		W=load("res://scripts/endless_world_v19.gd")
		for seed in [0,42]:
			for alternate in [false,true]:
				for use_tools in [false,true]:
					var w=W.new_run(seed);var purchases:=0;var used:=0;var spent:=0;var medicine:=0
					journey_loss=0
					for f in range(1,101):
						first_supply(w,alternate);camp(w,alternate)
						if w.hp<=130 and w.gold>=15:
							var q:Dictionary=w.action_quote("buy_potion");var h:int=w.hp
							if w.act("buy_potion").changed:medicine+=15;check(w.hp==q.hp_after and w.hp-h==q.heal_actual,"potion quote exact")
						if use_tools:
							var points:Array=G.routes(seed,f)[1 if alternate else 0].points.duplicate()
							if f%2==0:points.reverse()
							var target:Vector2i=points[0];var base:Dictionary=w.preview(target);var choice:="";var saved:=0
							for item in ["ward","pierce"]:
								var sim=w.clone();sim.items[item]=maxi(1,int(sim.items[item]));sim.armed_item=item
								var forecast:Dictionary=sim.preview(target);var reduction:int=int(base.net_damage)-int(forecast.net_damage)
								if forecast.survivable and reduction>saved and w.gold>=15+w.tool_price(item):choice=item;saved=reduction
							if choice!="":
								var cost:int=w.tool_price(choice)
								if w.act("job_buyward" if choice=="ward" else "job_buypierce").changed:
									purchases+=1;spent+=cost;check(w.act("arm_"+choice).changed,"actual purchased tool armed")
						var inventory:int=w.items.ward+w.items.pierce
						go(w,G.anchors(f).exit,alternate)
						used+=inventory-int(w.items.ward+w.items.pierce)
						check(w.floor_number==f+1 and not w.ended,"candidate100 no-D reasonable reserve policy")
						if f==50:print("ECON19 HALF ",[candidate,seed,alternate,use_tools,w.hp,w.gold,purchases,spent,medicine])
					var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
					check(restored!=null and restored.hp==w.hp and restored.gold==w.gold and restored.items==w.items,"candidate replay uses same pricing")
					print("ECON19 FULL ",[candidate,seed,alternate,use_tools,w.hp,w.gold,purchases,used,spent,medicine,journey_loss])
		# Controlled quote/zero-yield boundary fixtures, separate from legal journeys.
		for h in [100,150,179,180]:
			var w=W.new_run(0);w.pos=Vector2i(2,1);w.hp=h;w.gold=100
			var q:Dictionary=w.action_quote("buy_potion");var result:Dictionary=w.act("buy_potion")
			check(w.hp==q.hp_after and w.hp-h==q.heal_actual,"cap prediction matches actual at%d" % h)
			check(w.gold==100-(15 if h<180 else 0) and result.changed==(h<180),"full hp no fee")
		var full=W.new_run(0);full.bonus_atk=6;full.bonus_def=4;full.relic_bonus=2;full.atk=26;full.defense=14;full.hp=180;full.pos=Vector2i(11,10)
		check(not full.step(Vector2i.RIGHT).changed and full.tile(Vector2i(12,10))=="T","zero reward relic retained")
		full.hp=150;var quote:Dictionary=full.relic_quote()
		check(full.step(Vector2i.RIGHT).changed and full.hp==quote.hp_after and full.hp==180 and full.tile(Vector2i(12,10))==".","injured return consumes relic for exact health without tools")
		check(full.items.ward==0 and full.items.pierce==0,"no invented fallback tools")
	W=load("res://scripts/endless_world_v19.gd")
	for armed in [false,true]:
		var treasure=W.new_run(1);treasure.bridges[1]="loot";treasure.pos=Vector2i(6,5);treasure.training_packs=1;treasure.atk=23;treasure.defense=12;treasure.hp=180
		if armed:treasure.runes[1]=true
		var forecast:Dictionary=treasure.preview(Vector2i(6,4));var oldhp:int=treasure.hp
		check(forecast.enemy.gold==22 and treasure.base_enemy("c").gold==5,"only positioned treasure guardian receives22")
		check(treasure.step(Vector2i.UP).changed and treasure.gold==22 and oldhp-treasure.hp==forecast.net_damage,"guardian preview reward and rune battle actual match")
		for inventory in [[8,0],[0,8],[8,8],[9,9]]:
			var full=treasure.clone();full.items.ward=inventory[0];full.items.pierce=inventory[1]
			check(not full.step(Vector2i.UP).changed and full.tile(Vector2i(6,3))=="B" and full.items.ward==inventory[0] and full.items.pierce==inventory[1],"two-slot box refusal atomic")
		treasure.items.ward=7;treasure.items.pierce=7
		check(treasure.step(Vector2i.UP).changed and treasure.items.ward==9 and treasure.items.pierce==9 and treasure.gold==22,"two pairs granted exactly and no box gold")
		var view:Dictionary=treasure.bridge_view();check(view.arms[1].reward.ward==2 and view.arms[1].reward.pierce==2,"bridge UI structured reward is real count")
	for count in [1,2]:
		for seed in 64:
			var deal=W.new_run(seed);deal.pos=Vector2i(2,1)
			if deal._job_manifest().reward_count!=count:continue
			deal.contract={"source":1,"phase":"voucher"};deal.gold=100
			check(deal.act("job_ward").changed and deal.gold==100-2*count and deal.items.ward==count,"single2 double4 actual exchange")
			check(not deal.act("job_pierce").changed,"exchange remains exclusive")
			break
	print("Endless V19 final: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func cart_walk(w,target:Vector2i)->bool:
	var route:Array=w.safe_path(target)
	if target==w.pos:return true
	check(not route.is_empty(),"empty-ground route to cart interaction exists")
	for p in route:
		if p==w.pos:continue
		if not w.step(p-w.pos).changed:check(false,"safe cart walk executes");return false
	return not route.is_empty()
func solve_cart(w,side:String):
	var view:Dictionary=w.cart_view()
	var moves:Array=[Vector2i.LEFT,Vector2i.LEFT,Vector2i.UP] if side=="supply" else [Vector2i.LEFT,Vector2i.UP,Vector2i.UP]
	if view.variant==2:moves=[Vector2i.UP,Vector2i.UP,Vector2i.LEFT,Vector2i.LEFT] if side=="supply" else [Vector2i.UP,Vector2i.UP,Vector2i.UP,Vector2i.LEFT]
	for direction in moves:
		var box:Vector2i=w.cart_view().cart_pos
		cart_walk(w,box-direction)
		check(w.cart_push_quote(direction).allowed,"intended push allowed after repositioning")
		var n:int=w.actions.size()
		check(w.step(direction).changed and w.actions.size()==n+1,"push is exactly one direction event")
	check(w.cart_view().gates[side].open,"socket opens chosen gate")
func cart_tests():
	var old=load("res://scripts/endless_generation_v16.gd")
	for seed in range(32):
		for f in range(1,13):
			var built:Dictionary=G.generate(seed,f)
			check(built.ok,"new generator accepts its authored geometry")
			if G.has_cart(seed,f):check(not old.has_bridge(seed,f),"cart never overlays frozen bridge family")
			else:check(built==old.generate(seed,f),"non-event generator remains identical")
	for f in G.cart_floors(0):
		for side in ["supply","archive"]:
			# Controlled board fixtures only; real event histories are checked below.
			var w=W.new_run(0);w.floor_number=f;w.pos=Vector2i(3,7)
			check(w.cart_view().present,"event has visible manifest")
			check(not w.act("cart_reset").changed,"reset at origin is a no-op")
			var origin:Vector2i=w.cart_view().cart_pos
			check(w.safe_path(origin).is_empty(),"safe walking never pushes cart")
			solve_cart(w,side)
			var moved:Vector2i=w.cart_view().cart_pos
			cart_walk(w,Vector2i(3,7));check(w.act("cart_reset").changed,"legal nearby free reset")
			check(w.cart_view().cart_pos==origin,"reset returns exact origin")
			check(not w.apply_code("cart_reset!").changed,"forged reset confirmation refused")
			solve_cart(w,side)
			if side=="archive":
				cart_walk(w,Vector2i(8,3));w.hp=1;w.atk=27+3*f
				var prior:Dictionary=w.save_data();var p:Dictionary=w.preview(Vector2i(8,2))
				check(not p.survivable,"early archive guardian is genuinely threatening")
				check(w.step(Vector2i.UP).get("confirm",false) and w.save_data()==prior,"fatal guardian waits for confirmation")
				var dying=w.clone();var kills:int=dying.kills;var gold:int=dying.gold
				check(dying.step(Vector2i.UP,true).changed and dying.ended and dying.kills==kills and dying.gold==gold,"confirmed death no reward")
				w.hp=180;w.atk=999;w.defense=999
				check(w.step(Vector2i.UP).changed,"controlled guardian cleared")
				w.bonus_atk=6;w.bonus_def=4;w.relic_bonus=2
				check(not w.step(Vector2i.UP).changed and w.cart_view().claim=="","zero-benefit relic preserves shared choice")
				w.hp=179
			else:
				cart_walk(w,Vector2i(5,2));w.items.ward=9
				check(not w.step(Vector2i.UP).changed and w.cart_view().claim=="","full tools preserve shared choice")
				w.items.ward=8
			var n:int=w.actions.size()
			check(w.step(Vector2i.UP).get("confirm",false) and w.actions.size()==n,"reward asks confirmation without spending")
			check(w.step(Vector2i.UP,true).changed and w.actions.back()=="U!","reward records actual confirmed direction")
			check(w.cart_view().claim==side and w.cart_view().gates[side].open,"claimed door latches open")
			check(not w.cart_reward_quote("archive" if side=="supply" else "supply").allowed,"other cache permanently forfeited")
			cart_walk(w,Vector2i(3,7));check(not w.act("cart_reset").changed,"claimed cart cannot reset")
			check(w.cart_view()==w.clone().cart_view(),"clone preserves full cart state")
	# Earned growth, actual movement and stored actions, no injected inventory/stats.
	var earned=W.new_run(0)
	for f in range(1,21):
		first_supply(earned);camp(earned)
		if earned.hp<=130 and earned.gold>=15:earned.act("buy_potion")
		if f<20:go(earned,G.anchors(f).exit)
	for f in G.cart_floors(0):
		for side in ["supply","archive"]:
			var w=earned.clone()
			while w.floor_number>f:go(w,G.anchors(w.floor_number).entry)
			solve_cart(w,side)
			if side=="archive":
				cart_walk(w,Vector2i(8,3));var p:Dictionary=w.preview(Vector2i(8,2));check(p.survivable,"earned return can beat old archive guardian")
				check(w.step(Vector2i.UP).changed,"real guardian victory")
				var earned_gold:int=w.gold;var earned_kills:int=w.kills
				cart_walk(w,Vector2i(3,7));check(w.act("cart_reset").changed,"real guardian cleared then reset is allowed")
				solve_cart(w,"supply")
				check(w.tile(Vector2i(8,2))=="." and w.gold==earned_gold and w.kills==earned_kills,"switching sockets never respawns guardian or duplicates bounty")
				cart_walk(w,Vector2i(3,7));check(w.act("cart_reset").changed,"real freely reconsider reward before claiming")
				solve_cart(w,"archive");cart_walk(w,Vector2i(8,2))
			else:cart_walk(w,Vector2i(5,2))
			check(w.step(Vector2i.UP).get("confirm",false),"real cache requests confirm")
			check(w.step(Vector2i.UP,true).changed,"real shared cache claimed")
			var restored=W.from_data(w.save_data())
			check(restored!=null and restored.save_data()==w.save_data() and restored.cart_view()==w.cart_view(),"complete real event history replays exactly")
			var forged:Dictionary=w.save_data();forged.actions[-1]="U"
			check(W.from_data(forged)==null,"unconfirmed reward event cannot replay")
			check(not w.apply_code("D!").changed,"gratuitous confirmation on empty ground refused")
			var visible:Dictionary=w.cart_view();visible.board.clear()
			check(w.cart_view().board.size()==15,"read-only view cannot mutate cached manifest")
			cart_walk(w,Vector2i(3,7));var auto=w.clone();var returned:Dictionary=auto.return_to_camp()
			check(returned.changed or auto.camp_return_view().steps==0,"safe camp return works after cart event")
