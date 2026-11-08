extends SceneTree
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
var checks:=0
var failures:=0
var victory: Dictionary={}
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func from_victory():
	var w=World.new(0,1)
	w.restore(victory)
	return w
func begun():
	var w=from_victory(); w.action("expedition")
	return w
func rejected(w,id: String):
	var before: Dictionary=state(w)
	check(not w.action(id) and state(w)==before,"rejected expedition action leaves entire state unchanged: "+id)
func replay(w,route: String) -> bool:
	for symbol in route:
		var direction: Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[symbol]
		if not w.step(direction): return false
	return true
func write_file(path_name: String, content: String):
	var file:=FileAccess.open(path_name,FileAccess.WRITE); file.store_string(content); file.close()
func _initialize():
	call_deferred("run_tests")
func run_tests():
	check(Expedition.INITIAL.hp==121,"second-chapter proof starts at any surviving 1 HP plus 120, not a sampled minimum")
	for kind in ["Z","H"]:
		for field in ["hp","atk","def","gold"]:
			check(World.ENEMIES[kind][field]==Expedition.ENEMIES[kind][field],"new enemy integration matches expedition definition: "+kind+"."+field)
	var w=World.new(0,1)
	rejected(w,"expedition")
	w.won=true
	rejected(w,"expedition")
	check(w.chapter_offers().is_empty(),"forged won flag cannot continue while first boss remains")
	w=World.new(0,1)
	var first_proof: Dictionary=Generator.validate(w.floors,1)
	check(first_proof.solvable and replay(w,first_proof.route) and w.won and w.floors.size()==5,"actual fresh first chapter wins and stops at five floors")
	victory=state(w)
	check(w.chapter_offers().size()==1 and not w.expedition_started,"victory offers continuation without automatically starting it")
	var old_hp: int=w.hp
	check(w.action("expedition") and w.expedition_started and not w.won and w.floors.size()==8 and w.floor_seen.size()==8 and w.floor_index==5 and w.pos==Vector2i(1,1),"explicit continuation appends three floors and enters floor six")
	check(w.hp==old_hp+120 and w.floors[4][9][9]==">" and w.floor_seen[5] and not w.floor_seen[6] and not w.floor_seen[7],"chapter bonus is exact and connects the old tower without revealing later floors")
	var started: Dictionary=state(w)
	rejected(w,"expedition")
	check(w.restore(victory) and state(w)==victory,"undo chapter start removes appended floors and bonus together")
	w.action("expedition")
	check(state(w)==started,"retry after full rollback reproduces maps and grants bonus only once in state")
	var loaded=World.new(0,1)
	check(loaded.restore(JSON.parse_string(JSON.stringify(started))) and state(loaded)==started,"eight-floor JSON state roundtrip")
	var before_hp: int=w.hp; var before_focus: int=w.focus; var before_interest: int=w.interest
	check(w.step(Vector2i.RIGHT) and w.step(Vector2i.LEFT) and w.floor_index==4,"expedition entrance walks back into original tower")
	check(w.step(Vector2i.LEFT) and w.step(Vector2i.RIGHT) and w.floor_index==5,"old tower exit permits return to expedition")
	check(w.hp==before_hp and w.focus==before_focus and w.interest==before_interest,"revisiting chapter entrance cannot farm bonus, focus or interest")
	w=begun(); w.pos=Vector2i(2,2); w.gold=69
	rejected(w,"camp_medicine")
	w.gold=200; old_hp=w.hp
	check(w.action("camp_medicine") and w.gold==130 and w.hp==old_hp+140 and w.camp_medicine_left==1,"medicine pays seventy and consumes one shared stock")
	check(w.action("camp_medicine") and w.gold==60 and w.hp==old_hp+280 and w.camp_medicine_left==0,"medicine has exactly two charges")
	rejected(w,"camp_medicine")
	check(loaded.restore(JSON.parse_string(JSON.stringify(state(w)))) and loaded.camp_medicine_left==0,"spent camp stock survives save/load")
	w=begun(); w.pos=Vector2i(2,2); w.gold=200; w.focus=w.focus_cap
	rejected(w,"camp_focus")
	w.focus=0; w.gold=54
	rejected(w,"camp_focus")
	w.gold=200
	check(w.action("camp_focus") and w.focus==1 and w.gold==145 and w.camp_focus_left==1,"focus purchase adds one at fifty-five cost")
	check(w.action("camp_focus") and w.focus==2 and w.gold==90 and w.camp_focus_left==0,"focus has exactly two charges")
	rejected(w,"camp_focus")
	w.pos=Vector2i(9,9)
	rejected(w,"camp_medicine"); rejected(w,"camp_bridge")
	w=begun(); w.pos=Vector2i(4,3)
	check(w.tile(Vector2i(5,3))=="=" and not w.step(Vector2i.RIGHT),"unfunded engineering crossing really blocks walking")
	w.pos=Vector2i(2,3); w.gold=79
	rejected(w,"camp_bridge")
	w.gold=80; var before_bridge: Dictionary=state(w)
	check(w.action("camp_bridge") and w.expedition_bridge and w.gold==0,"engineering opens route once for eighty")
	rejected(w,"camp_bridge")
	w.pos=Vector2i(4,3)
	check(w.step(Vector2i.RIGHT) and w.tile(w.pos)=="=","engineering bit makes persistent crossing walkable without replacing its tile")
	check(loaded.restore(JSON.parse_string(JSON.stringify(state(w)))) and loaded.expedition_bridge,"standing on engineered crossing loads correctly")
	check(w.restore(before_bridge) and not w.expedition_bridge and w.gold==80,"engineering undo restores gold and closes all paid crossings")
	# Old successful saves keep the old ending until a fresh explicit choice.
	for version in [4,5]:
		var legacy: Dictionary=victory.duplicate(true); legacy.version=version
		for key in ["expedition_started","expedition_bridge","camp_medicine_left","camp_focus_left"]: legacy.erase(key)
		if version==4:
			for key in ["seal_version","seal_clues","seal_input","seal_solved","seal_reward"]: legacy.erase(key)
		loaded=World.new(0,1)
		check(loaded.restore(JSON.parse_string(JSON.stringify(legacy))) and loaded.won and loaded.floors.size()==5 and not loaded.expedition_started and loaded.hp==int(victory.hp),"legacy successful JSON remains at first ending: "+str(version))
		check(loaded.action("expedition") and loaded.floors.size()==8,"legacy victory can explicitly continue: "+str(version))
	w=begun(); var valid: Dictionary=state(w)
	for fields in [{"expedition_started":false},{"expedition_bridge":"yes"},{"camp_medicine_left":3},{"camp_medicine_left":-1},{"camp_focus_left":1.5},{"camp_focus_left":true},{"version":5}]:
		var bad: Dictionary=valid.duplicate(true); bad.merge(fields,true)
		check(not w.restore(bad) and state(w)==valid,"invalid chapter state rejected atomically")
	var bad: Dictionary=valid.duplicate(true); bad.floor_seen.pop_back()
	check(not w.restore(bad) and state(w)==valid,"floor visibility length must match actual eight maps")
	bad=valid.duplicate(true); bad.floors[4][3][8]="K"
	check(not w.restore(bad) and state(w)==valid,"started chapter cannot restore a live first boss")
	bad=valid.duplicate(true); bad.floors[7][3][8]="."
	check(not w.restore(bad) and state(w)==valid,"unfinished expedition requires one final boss")
	# Real two-chapter run: no shopping, injected stats, skill or engineering.
	w=from_victory(); check(w.action("expedition"),"actual victorious character enters chapter two")
	var second_proof: Dictionary=Expedition.validate(w.floors.slice(5),1)
	var chapter_maps: Array=w.floors.slice(5).duplicate(true)
	var route_points: Array=[]; var crossing_stats: Array=[]
	var actual_ok:=true
	for symbol in second_proof.route:
		var direction: Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[symbol]
		if w.tile(w.pos+direction)=="H": crossing_stats.append([w.atk,w.defense,w.hp,w.damage("H")])
		if not w.step(direction): actual_ok=false; break
		route_points.append([w.floor_index,w.pos])
	check(second_proof.solvable and actual_ok and w.won and w.floor_index==7 and w.tile(Vector2i(8,3))==".","actual inherited character completes the three new floors")
	check(w.hp>0 and w.camp_medicine_left==2 and w.camp_focus_left==2 and not w.expedition_bridge and not w.loan_used and not w.skill_armed,"two-chapter witness wins without optional purchases, loan or skill")
	check(w.checkpoints==2 and w.interest==0,"new chapter never invents additional loan checkpoints")
	check(loaded.restore(JSON.parse_string(JSON.stringify(state(w)))) and loaded.won and loaded.floors.size()==8,"final victory saves and loads without reopening a boss")
	rejected(w,"expedition"); rejected(w,"camp_medicine")
	var final_moves: int=w.moves; var final_hp: int=w.hp
	var combat_result: Dictionary=state(w)
	# Independent arithmetic at the ACTUAL growth timestamps of all crossings.
	# H has first strike, no thorns/heavy; buckler removes its first attack,
	# duelist adds one opening retaliation and penetrates eight enemy DEF.
	var totals: Dictionary={"balanced":0,"buckler":0,"duelist":0}
	check(crossing_stats.size()==3,"real no-engineering route fights all three ferry wardens")
	for sample in crossing_stats:
		for gear in totals:
			var effective_atk: int=sample[0]+(-4 if gear=="buckler" else (6 if gear=="duelist" else 0))
			var effective_def: int=sample[1]+(6 if gear=="buckler" else (-3 if gear=="duelist" else 0))
			var rounds: int=ceili(180.0/(effective_atk-(22 if gear=="duelist" else 30)))
			var attacks: int=rounds+(-1 if gear=="buckler" else (1 if gear=="duelist" else 0))
			var independent_loss: int=maxi(0,62-effective_def)*attacks
			totals[gear]+=independent_loss
			var prediction: Dictionary=World.Progression.battle(sample[0],sample[1],sample[2],World.ENEMIES.H,"warden",false,gear,[])
			check(prediction.damage==independent_loss,"independent first-strike/gear arithmetic at actual crossing")
		check(sample[3]==maxi(0,62-int(sample[1]))*ceili(180.0/(int(sample[0])-30)),"real crossing preview matches independently calculated loss")
	check(totals=={"balanced":334,"buckler":224,"duelist":396},"same growth path changes engineering value by loadout: 334 / 224 / 396 HP")
	var bridge_run=begun()
	check(bridge_run.step(Vector2i.DOWN) and bridge_run.step(Vector2i.RIGHT) and bridge_run.step(Vector2i.DOWN) and bridge_run.action("camp_bridge"),"real inherited gold pays eighty for engineering")
	var bypass_ok:=true
	for point in route_points:
		var target_floor: int=point[0]; var target: Vector2i=point[1]
		if chapter_maps[target_floor-5][target.y][target.x]=="H": continue
		if bridge_run.floor_index<target_floor:
			if not walk_without_extra_loot(bridge_run,Vector2i(9,9)): bypass_ok=false; break
		if bridge_run.floor_index!=target_floor or not walk_without_extra_loot(bridge_run,target): bypass_ok=false; break
	check(bypass_ok and bridge_run.won,"paid route follows same growth/loot sequence while bypassing wardens")
	check(bridge_run.hp==int(combat_result.hp)+int(totals.balanced) and bridge_run.kills==int(combat_result.kills)-3 and bridge_run.gold==int(combat_result.gold)-80-180,"engineering saves 334 HP but costs eighty and forgoes 180 gold plus three kills")
	var medicine_run=begun()
	check(medicine_run.step(Vector2i.DOWN) and medicine_run.step(Vector2i.RIGHT) and medicine_run.action("camp_medicine"),"alternative route buys one seventy-gold medicine from earned gold")
	# Walk out and back via the old tower so replay begins at the same staircase.
	check(medicine_run.step(Vector2i.UP) and medicine_run.step(Vector2i.LEFT) and medicine_run.step(Vector2i.LEFT) and medicine_run.step(Vector2i.RIGHT),"medicine route returns to identical entrance by legal stairs")
	check(replay(medicine_run,second_proof.route) and medicine_run.won and medicine_run.hp==int(combat_result.hp)+140 and medicine_run.gold==int(combat_result.gold)-70 and medicine_run.kills==combat_result.kills,"medicine preserves warden gold/kills but saves only 140 HP for seventy gold")
	print("ROUTE TRADEOFF: bridge 80 gold / 334 HP saved / forgo 180 gold+3 kills; medicine 70 gold / +140 HP; hypothetical same-growth shields/duelist change crossing loss to 224/396.")
	# UI continuation remains explicit, can be undone, and does not consume keys.
	var scene=load("res://main.tscn").instantiate(); root.add_child(scene)
	scene.save_path="user://expedition-integration-test.json"; scene.world=from_victory(); scene.growth=false; scene.battle_time=0.0
	await process_frame
	check(scene.world.won and scene.world.floors.size()==5,"rendering first ending does not auto-start new chapter")
	var event:=InputEventKey.new(); event.pressed=true; event.keycode=KEY_1
	scene._unhandled_input(event)
	check(scene.world.expedition_started and not scene.world.won and scene.world.floors.size()==8,"victory key-one button starts chapter exactly once")
	scene.undo()
	check(state(scene.world)==victory,"controller undo restores five-floor ending and removes recovery bonus")
	scene.perform_action("expedition")
	scene.world.pos=Vector2i(2,2); scene.world.gold=70
	var before_camp: Dictionary=state(scene.world)
	scene.perform_action("camp_medicine")
	check(scene.world.camp_medicine_left==1 and scene.world.gold==0,"controller camp purchase commits stock and cost together")
	scene.undo(); check(state(scene.world)==before_camp,"controller camp undo restores HP gold and shared stock")
	scene.world.hp=1; scene.load_game()
	check(state(scene.world)==before_camp,"controller loads actual schema-six eight-floor autosave")
	# Debt fixture tests UI timing, not claims about a normally paid-off ending.
	scene.world.loan_used=true; scene.world.principal=40; scene.world.fees=2; scene.world.interest=8; scene.world.checkpoints=2; scene.world.overdue=true
	scene.world.pos=Vector2i(8,9); var debt_before: int=scene.world.debt()
	scene.move(Vector2i.RIGHT)
	check(scene.world.floor_index==6 and not scene.interaction and scene.world.debt()==debt_before and scene.world.checkpoints==2,"six-to-seven stairs neither prompt nor charge another loan period")
	var book_state: Dictionary=state(scene.world)
	scene.book=false; scene.interaction=false
	event.keycode=KEY_H; scene._unhandled_input(event)
	event.keycode=KEY_BRACKETRIGHT; scene._unhandled_input(event)
	await process_frame
	check(scene.book and scene.book_page==1,"monster guide reaches page two containing ferry warden")
	event.keycode=KEY_D; scene._unhandled_input(event)
	event.keycode=KEY_F2; scene._unhandled_input(event)
	check(scene.book_page==1 and state(scene.world)==book_state,"guide pagination blocks movement and language switch preserves page")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.book,"Escape closes paginated guide")
	DirAccess.remove_absolute(scene.save_path)
	for version in [4,5]:
		scene.save_path="user://expedition-legacy-v%d-test.json" % version
		var backup_path: String=scene.save_path.get_basename()+(".pre-schema5.json" if version==4 else ".pre-schema6.json")
		if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(backup_path)
		var legacy: Dictionary=victory.duplicate(true); legacy.version=version
		for key in ["expedition_started","expedition_bridge","camp_medicine_left","camp_focus_left"]: legacy.erase(key)
		if version==4:
			for key in ["seal_version","seal_clues","seal_input","seal_solved","seal_reward"]: legacy.erase(key)
		var original: String=JSON.stringify(legacy,"\t")
		write_file(scene.save_path,original); scene.load_game()
		var upgraded=JSON.parse_string(FileAccess.get_file_as_string(scene.save_path))
		check(FileAccess.file_exists(backup_path) and FileAccess.get_file_as_string(backup_path)==original and upgraded.version==12,"legacy JSON upgraded with byte-preserving matching backup: "+str(version))
		check(scene.world.won and scene.world.floors.size()==5 and not scene.world.expedition_started,"UI load preserves legacy first ending until explicit continuation")
		legacy.gold+=1; write_file(scene.save_path,JSON.stringify(legacy)); scene.load_game()
		check(FileAccess.get_file_as_string(backup_path)==original,"legacy backup is never overwritten: "+str(version))
		DirAccess.remove_absolute(scene.save_path); DirAccess.remove_absolute(backup_path)
	print("EXPEDITION: %s (%d checks; actual two-chapter route %d moves, %d HP)" % ["PASS" if failures==0 else "FAIL",checks,final_moves,final_hp])
	quit(0 if failures==0 else 1)

func walk_without_extra_loot(w, goal: Vector2i) -> bool:
	if w.pos==goal: return true
	var queue: Array=[[w.pos,[]]]; var seen: Dictionary={w.pos:true}; var found: Array=[]
	while not queue.is_empty():
		var item: Array=queue.pop_front(); var p: Vector2i=item[0]
		if p==goal: found=item[1]; break
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n: Vector2i=p+d
			if seen.has(n): continue
			var token: String=w.tile(n)
			if token in ["#","H","D","L"]: continue
			if token=="=" and not w.expedition_bridge: continue
			if n!=goal and (token in ["<",">","a","d","h","k"] or World.ENEMIES.has(token)): continue
			seen[n]=true
			var route: Array=item[1].duplicate(); route.append(d); queue.append([n,route])
	if found.is_empty(): return false
	for d in found:
		if not w.step(d): return false
	return true
