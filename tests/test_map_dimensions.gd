extends SceneTree
const World=preload("res://scripts/world.gd")
const Nav=preload("res://scripts/navigation.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String):
	checks+=1
	if not value: failures+=1;push_error(label)
func grid(width:int,height:int)->Array:
	var rows:Array=[]
	for y in height:
		var row:Array=[]
		for x in width: row.append("#" if x==0 or y==0 or x==width-1 or y==height-1 else ".")
		rows.append(row)
	return rows
func _init():
	var w=World.new(42)
	var snapshot:Dictionary=w.save_data().duplicate(true)
	check(w.floor_size()==Vector2i(11,11),"existing floor size")
	check(w.floor_size(4)==Vector2i(11,11),"explicit floor")
	check(w.floor_size(100)==Vector2i.ZERO and w.floor_size(-2)==Vector2i.ZERO,"invalid floors")
	check(w.in_bounds(Vector2i(10,10)) and not w.in_bounds(Vector2i(11,5)),"physical boundaries")
	check(not w.in_bounds(Vector2i(-1,0)),"negative coordinate")
	check(w.save_data()==snapshot,"queries preserve serialized world")
	var big:Array=grid(15,15)
	w.floors=[big];w.floor_index=0
	check(w.floor_size()==Vector2i(15,15),"synthetic large floor")
	check(w.tile(Vector2i(13,13))=="." and w.tile(Vector2i(15,14))=="#","tile actual bounds")
	var route:=Nav.walk_path(big,Vector2i(1,1),Vector2i(13,13))
	check(route.size()==24 and route.back()==Vector2i(13,13),"15 x 15 shortest safe route")
	for p in route: check(big[p.y][p.x]==".","only empty floor")
	# A barrier spanning the interior cannot be bypassed at its outer boundary.
	for token in ["D","L","s","~","M",">","k","="]:
		var blocked:Array=grid(15,15)
		for y in range(1,14): blocked[y][7]=token
		check(Nav.walk_path(blocked,Vector2i(1,1),Vector2i(13,13)).is_empty(),"blocked barrier "+token)
	big[0][1]="."
	check(Nav.walk_path(big,Vector2i(1,1),Vector2i(1,0)).is_empty(),"outer edge remains excluded")
	check(Nav.walk_path(grid(17,9),Vector2i(1,1),Vector2i(15,7)).size()==20,"rectangular dimensions")
	var ragged:Array=grid(15,15);ragged[5].pop_back();w.floors=[ragged]
	check(w.floor_size()==Vector2i.ZERO and w.tile(Vector2i(1,1))=="#","ragged world rejected")
	check(Nav.walk_path(ragged,Vector2i(1,1),Vector2i(13,13)).is_empty(),"ragged navigation rejected")
	for malformed in [[],[[]],[4],[[1,2,3],[1,2,3],[1,2,3]]]:
		check(Nav.walk_path(malformed,Vector2i(1,1),Vector2i(1,2)).is_empty(),"malformed navigation rejected")
	w.floors=[[]]
	check(w.floor_size()==Vector2i.ZERO and not w.in_bounds(Vector2i.ZERO),"empty floor")
	var forged:Dictionary=snapshot.duplicate(true);forged.floors[0]=grid(15,15)
	check(World.from_snapshot(forged)==null,"schema 19 still rejects larger saved map")
	print("MAP DIMENSIONS: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)
