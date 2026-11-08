extends SceneTree
const Layout=preload("res://scripts/layout.gd")
const Expedition=preload("res://scripts/expedition.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const DIRECTIONS={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var checks:=0
var failures:=0
func check(value:bool,label:String):
	checks+=1
	if not value: failures+=1; push_error(label)
func replay(world,route:String):
	for c in route:
		var direction:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
		check(world.step(direction),"real World witness step")
func _init():
	check_rescue_return()
	check(Expedition.damage("H",{"hp":1000,"atk":78,"def":28})==136,"first crossing loss")
	check(Expedition.damage("H",{"hp":1000,"atk":88,"def":32})==120,"second crossing loss")
	check(Expedition.damage("H",{"hp":1000,"atk":98,"def":36})==78,"third crossing loss")
	check(3*Expedition.ENEMIES.H.gold==180,"bridge skips 180 potential guard gold")
	for token in Expedition.ENEMIES:
		check(World.ENEMIES.has(token),"World defines expedition enemy "+token)
		if not World.ENEMIES.has(token): continue
		for field in ["hp","atk","def","gold","first_strike","thorns","heavy_every"]:
			check(Expedition.ENEMIES[token].get(field,false)==World.ENEMIES[token].get(field,false),"chapter enemy contract")
	var geometries:Dictionary={}; var min_hp:=1000000; var max_hp:=0
	for seed_value in range(200):
		var run:=Expedition.generate(seed_value)
		check(run.content_revision==3 and run.quest_supported,"new expedition content revision")
		check(Expedition.rescue_topology(run.maps).valid,"rescue single guard topology")
		check(run.solvable,"seed %d solvable"%seed_value)
		check(run.maps==Expedition.generate(seed_value).maps,"deterministic")
		geometries[str(run.maps)]=true
		if not run.solvable: return
		min_hp=mini(min_hp,run.validation.hp); max_hp=maxi(max_hp,run.validation.hp)
		var first:=Generator.generate(seed_value,World.MAPS)
		check(first.validation.solvable and first.validation.atk>=73 and first.validation.def>=24,"chapter one witness growth floor")
		var world=World.new(0)
		world.seed_value=seed_value; world.floors=first.maps.duplicate(true)
		replay(world,first.validation.route)
		check(world.won,"chapter one actually won")
		check(world.action("expedition"),"explicit continuation")
		var start_hp:int=world.hp
		replay(world,run.witness)
		check(world.floors[6][1][9]=="t" and world.floors[6][2][9]=="W","mainline does not use rescue reward")
		check(world.won and world.floor_index==7,"chapter two actually won")
		check(world.hp==start_hp+run.validation.hp-121,"real HP matches witness delta")
		check(not world.expedition_bridge and not world.loan_used and world.camp_medicine_left==2,"no purchases or loan proof")
		var canonical:=Layout.orient_maps(run.maps,5,2)
		for f in range(3):
			var grid:Array=canonical[f]
			check(grid[1][1]=="<","entry")
			check(grid[9][1]==["$","A","P"][f] and grid[9][2]=="L" and grid[8][1]=="#","cage gate")
			var closed:=Generator.reachable(grid,["#","=","L","Z"])
			check(not closed.has(Vector2i(1,9)),"no cage bypass")
			var no_guard:=Generator.reachable(grid,["#","=","L","Z","H"])
			check(not no_guard.has(Vector2i(8,2)),"free route requires ferry guard")
			var bridge:=Generator.reachable(grid,["#","L","Z","H"])
			check(bridge.has(Vector2i(8,2)),"bridge avoids ferry guard")
			check(Expedition.damage("H",{"hp":121,"atk":73,"def":24})>0,"bridge saves actual HP")
			check(grid[3][8]=="Z" if f==2 else grid[9][9]==">","goal")
			for i in range(11): check(grid[0][i]=="#" and grid[10][i]=="#" and grid[i][0]=="#" and grid[i][10]=="#","boundary")
	check(geometries.size()>=24,"chapter geometry diversity")
	var invalid:Array=Expedition.generate(0).maps.duplicate(true); invalid[2][7][2]="."
	check(not Expedition.validate(invalid).solvable,"missing boss rejected")
	for variant in range(3):
		var fixture:Array=[Expedition.build(0,variant),Expedition.build(1,variant),Expedition.build(2,variant)]
		var guard:=Vector2i(5,[8,7,6][variant])
		check(Expedition.flanking_position(fixture,1,guard,guard+Vector2i.RIGHT),"H east-adjacent flank exists")
		for offset in [Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN,Vector2i(2,0),Vector2i.ZERO]:
			check(not Expedition.flanking_position(fixture,1,guard,guard+offset),"no remote or wrong-side flank")
		fixture[1][guard.y][guard.x]="."
		check(not Expedition.flanking_position(fixture,1,guard,guard+Vector2i.RIGHT),"defeated guard cannot be flanked")
	for variant in range(3):
		var maps:Array=[Expedition.build(0,variant),Expedition.build(1,variant),Expedition.build(2,variant)]
		for bypass in [".","D","="]:
			var broken:=maps.duplicate(true); broken[1][1][8]=bypass
			check(not Expedition.rescue_topology(broken).valid,"rescue rejects wall, door and bridge bypass")
			check(not Expedition.validate(Layout.orient_maps(broken,5,2)).solvable,"proof rejects rescue bypass")
		for hole in [Vector2i(9,3),Vector2i(9,5)]:
			for bypass in [".","D","="]:
				var broken:=maps.duplicate(true); broken[1][hole.y][hole.x]=bypass
				check(not Expedition.validate(Layout.orient_maps(broken,5,2)).solvable,"armory wall/door/bridge bypass rejected")
		var removed:=maps.duplicate(true); removed[1][2][9]="."
		check(not Expedition.validate(Layout.orient_maps(removed,5,2)).solvable,"missing optional guardian rejected")
		var missing:=maps.duplicate(true); missing[1][1][9]="."
		check(not Expedition.validate(Layout.orient_maps(missing,5,2)).solvable,"missing apprentice rejected")
		var sealed:=maps.duplicate(true); sealed[1][2][8]="#"; sealed[1][3][9]="#"
		check(not Expedition.validate(Layout.orient_maps(sealed,5,2)).solvable,"sealed rescue rejected")
	print("Expedition generation: %d checks; 200 seeds; %d geometries; HP %d..%d"%[checks,geometries.size(),min_hp,max_hp])
	quit(1 if failures else 0)

func req(value:bool):
	check(value,"actual seven-to-eight-to-seven rescue path")
func travel(w,p:Vector2i):
	var path:=Expedition.path_to(w.floors[w.floor_index],w.pos,p,{"hp":w.hp,"atk":w.atk,"def":w.defense})
	req(not path.is_empty() or w.pos==p)
	for d in path: req(w.step(d))
func check_rescue_return():
	var w=World.new(0)
	for c in Generator.validate(w.floors).route: req(w.step(DIRECTIONS[c]))
	req(w.action("expedition"))
	var route:String=Expedition.generate(0).witness; var index:=0
	while w.floor_index<6:
		req(w.step(DIRECTIONS[route[index]])); index+=1
	travel(w,Vector2i(8,2))
	print("Early guard: HP ",w.hp," ATK ",w.atk," DEF ",w.defense," cost ",w.damage("W"))
	req(w.damage("W")>=w.hp and not w.step(Vector2i.RIGHT))
	travel(w,Vector2i(1,1))
	req(w.floor_index==5)
	req(w.step(Vector2i.RIGHT)); req(w.step(Vector2i.LEFT)); req(w.floor_index==6)
	while index<route.length():
		var d:Vector2i=DIRECTIONS[route[index]]
		if w.tile(w.pos+d)=="Z": break
		req(w.step(d)); index+=1
	req(w.floor_index==7)
	travel(w,Layout.entry(w.floor_index,w.layout_revision)); req(w.floor_index==6)
	travel(w,Vector2i(8,2))
	print("Return guard: HP ",w.hp," ATK ",w.atk," DEF ",w.defense," cost ",w.damage("W"))
	req(w.damage("W")<w.hp)
	req(w.step(Vector2i.RIGHT)); req(w.step(Vector2i.UP))
	req(w.rescue_state==2)
	print("Real walk rescue return PASS HP ",w.hp)
