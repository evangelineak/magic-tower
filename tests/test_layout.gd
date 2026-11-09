extends SceneTree
const Layout=preload("res://scripts/layout.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const W=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String):
	checks+=1
	if not value: failures+=1; push_error(label)
func budget(grid:Array)->Dictionary:
	var result:Dictionary={}
	for row in grid:
		for token in row:
			if token in G.LOOT: result[token]=int(result.get(token,0))+1
	return result
func _init():
	var old:=G.normalize(W.MAPS)
	var prepared:=G.prepare_baseline(W.MAPS,2)
	check(G.prepare_baseline(prepared,2)==prepared,"reservation is idempotent and never duplicates optional loot")
	for f in range(5):
		var expected:=budget(old[f])
		if f in [0,3,4]:
			var added:String="d" if f==3 else "h"
			expected[added]=int(expected.get(added,0))+1
		check(budget(prepared[f])==expected,"original growth budget preserved; optional budget explicit")
		check(prepared[f][3][6]!="D","meaningless bypassable door removed")
		check(budget(prepared[f]).get("k",0)==1,"one mainline key per first-chapter floor unchanged")
		for id in G.SKELETONS:
			var grid:=G.build_skeleton(prepared[f],id)
			check(G.topology([grid],2).valid,"all fifteen floor skeletons retain paid-gate meaning")
			if f in [0,3,4]:
				var isolation:=G.door_isolation(grid,Vector2i(8,2),Vector2i(9,2))
				check(isolation.valid and isolation.exclusive==[Vector2i(9,2)],"single key buys one genuinely exclusive reward cell")
				check(grid[1][9]=="#" and grid[3][9]=="#","one-key room walls reserved before scatter")
			if f in [0,2,3]: check(G.door_isolation(grid,Vector2i(2,9),Vector2i(1,9)).valid,"double-key cage remains exclusive even with other gates open")
	for revision in [1,2]:
		var first:=G.generate(0,W.MAPS,revision)
		var later:=E.generate(0,revision)
		var maps:Array=first.maps.duplicate(true); maps[4][9][9]=">"; maps.append_array(later.maps)
		check(first.validation.solvable and later.solvable,"both layout generations have conservative witnesses")
		check(Layout.orient_maps(Layout.orient_maps(maps,0,revision),0,revision)==maps,"orientation is an involution")
		for f in range(7):
			var up_pos:=Layout.exit_point(f,revision)
			var up:=Layout.stair_destination(maps,revision,f,up_pos)
			check(up.ok and up.floor==f+1 and up.pos==Layout.entry(f+1,revision),"stairs land on actual next-floor entrance")
			if revision==2: check(up.pos==up_pos,"new upward stairs preserve exact coordinate")
			var down:=Layout.stair_destination(maps,revision,f+1,up.pos)
			check(down.ok and down.floor==f and down.pos==up_pos,"descending stairs exactly reverse the boundary")
			if revision==2: check(down.pos==up.pos,"new downward stairs preserve exact coordinate")
		var broken:=maps.duplicate(true); var landing:=Layout.entry(1,revision); broken[1][landing.y][landing.x]="."
		check(not Layout.stair_destination(broken,revision,0,Layout.exit_point(0,revision)).ok,"missing counterpart stair is never a teleport target")
		check(not Layout.stair_destination(maps,99,0,Vector2i(9,9)).ok,"unknown layout fails closed")
		for f in range(8):
			var p:=Vector2i(3,7)
			check(Layout.point(f,Layout.point(f,p,revision),revision)==p,"point roundtrip")
			check(Layout.direction(f,Layout.direction(f,Vector2i.UP,revision),revision)==Vector2i.UP,"direction roundtrip")
			check(Layout.route(f,Layout.route(f,"UDLR",revision),revision)=="UDLR","witness direction roundtrip")
		if revision==1:
			check(first.maps==old,"legacy seed zero retains exact original maps")
			for f in range(5): check(first.maps[f][3][6]=="D","legacy authored doors untouched")
		else:
			for f in [0,3,4]:
				var door:=Layout.point(f,Vector2i(8,2),revision)
				var info:=Layout.door_info(f,door,revision)
				check(info.cost==1 and info.reward_pos==Layout.point(f,Vector2i(9,2),revision),"door tooltip uses physical coordinates and exact cost")
	for f in [0,3,4]:
		for side in [Vector2i(9,1),Vector2i(9,3)]:
			for bypass in [".","D","~"]:
				var broken:=prepared.duplicate(true); broken[f][side.y][side.x]=bypass
				check(not G.validate(Layout.orient_maps(broken,0,2),2).solvable,"room rejects normal, keyed and drainable bypass")
		var missing:=prepared.duplicate(true); missing[f][2][9]="."
		check(not G.validate(Layout.orient_maps(missing,0,2),2).solvable,"empty paid room rejected")
	for variant in range(3):
		var canonical:Array=[E.build(0,variant),E.build(1,variant),E.build(2,variant)]
		var physical:=Layout.orient_maps(canonical,5,2)
		for f in range(3):
			var guard:=Layout.point(f+5,Vector2i(5,[8,7,6][variant]),2)
			var side:=Layout.point(f+5,Vector2i(6,[8,7,6][variant]),2)
			check(E.flanking_position(physical,f,guard,side,2),"flank rotates with the authored shore")
			check(not E.flanking_position(physical,f,guard,guard-(side-guard),2),"front cannot become a flank after rotation")
			var canonical_door:=Vector2i(2,9)
			check(G.door_isolation(canonical[f],canonical_door,Vector2i(1,9)).valid,"all expedition double-lock regions remain exclusive")
	check(Layout.point(5,Vector2i(2,2),2)==Vector2i(8,8),"camp rotates")
	check(Layout.point(7,Vector2i(8,3),2)==Vector2i(2,7),"final boss rotates")
	check(Layout.point(6,Vector2i(9,1),2)==Vector2i(9,1),"Mira/winch floor stays unchanged")
	print("Layout: %d checks, failures=%d"%[checks,failures])
	quit(1 if failures else 0)
