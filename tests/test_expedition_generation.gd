extends SceneTree
const Expedition=preload("res://scripts/expedition.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
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
	check(Expedition.damage("H",{"hp":1000,"atk":78,"def":28})==136,"first crossing loss")
	check(Expedition.damage("H",{"hp":1000,"atk":88,"def":32})==120,"second crossing loss")
	check(Expedition.damage("H",{"hp":1000,"atk":98,"def":36})==78,"third crossing loss")
	check(3*Expedition.ENEMIES.H.gold==180,"bridge skips 180 potential guard gold")
	for token in Expedition.ENEMIES:
		for field in ["hp","atk","def","gold","first_strike"]:
			check(Expedition.ENEMIES[token].get(field,false)==World.ENEMIES[token].get(field,false),"chapter enemy contract")
	var geometries:Dictionary={}; var min_hp:=1000000; var max_hp:=0
	for seed_value in range(200):
		var run:=Expedition.generate(seed_value)
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
		check(world.won and world.floor_index==7,"chapter two actually won")
		check(world.hp==start_hp+run.validation.hp-121,"real HP matches witness delta")
		check(not world.expedition_bridge and not world.loan_used and world.camp_medicine_left==2,"no purchases or loan proof")
		for f in range(3):
			var grid:Array=run.maps[f]
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
	var invalid:Array=Expedition.generate(0).maps.duplicate(true); invalid[2][3][8]="."
	check(not Expedition.validate(invalid).solvable,"missing boss rejected")
	print("Expedition generation: %d checks; 200 seeds; %d geometries; HP %d..%d"%[checks,geometries.size(),min_hp,max_hp])
	quit(1 if failures else 0)
