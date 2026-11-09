extends SceneTree
const Gen=preload("res://scripts/endless_generation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _init():
	var layouts:Dictionary={}
	for seed in range(256):
		for floor_number in [1,2,3,8,9,100,1000000,2147483647]:
			var a:=Gen.generate(seed,floor_number)
			check(a.ok,"valid geometry")
			check(a==Gen.generate(seed,floor_number),"reproducible")
			check(a.exit==Gen.anchors(floor_number+1).entry,"stairs same coordinate next floor")
			check(a.entry!=a.exit,"separate stairs")
			check(a.proof.door_is_cut and a.proof.guard_is_optional and not a.combat_budget_verified,"honest proof")
			layouts[str(a.grid)]=true
	check(layouts.size()>200,"geometry varies")
	check(not Gen.generate(-1,1).ok and not Gen.generate(0,0).ok,"invalid inputs")
	check(Gen.generate(2147483647,9223372036854775807).ok,"max int floor no overflow")
	var bad:=Gen.generate(42,1)
	# Drill a passage from the main rail through the reward-room ceiling.
	bad.grid[2][12]="."
	check(not Gen.validate(bad).ok,"door bypass rejected")
	bad=Gen.generate(42,1)
	for x in range(9,13):bad.grid[9][x]="."
	check(not Gen.validate(bad).ok,"guard bypass rejected")
	bad=Gen.generate(42,1);bad.grid[1][1]="."
	check(not Gen.validate(bad).ok,"missing stairs rejected")
	bad=Gen.generate(42,1);bad.grid[3][3]="."
	check(not Gen.validate(bad).ok,"missing key rejected")
	print("ENDLESS GEOMETRY: %s (%d checks, %d unique grids)" % ["PASS" if failures==0 else "FAIL",checks,layouts.size()])
	quit(1 if failures else 0)
