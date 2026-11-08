extends SceneTree
const Nav=preload("res://scripts/navigation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func anchor(f:int,x:int,y:int,mx:int,my:int,t:String)->Dictionary:
	return {"floor":f,"x":x,"y":y,"marker_x":mx,"marker_y":my,"token":t}
func blank()->Dictionary:
	var maps:Array=[]
	for f in range(5):
		var grid:Array=[]
		for y in range(11):
			var row:Array=[]
			for x in range(11): row.append("#")
			grid.append(row)
		maps.append(grid)
	return {"floors":maps,"floor":0,"x":1,"y":1,"floor_seen":[true,true,true,true,true],"anchors":[],"water_choice":"","bridge_built":false,"expedition_bridge":false,"core_use":"","clue":false,"seal_clues":0}
func corridor()->Dictionary:
	var s:=blank()
	for x in range(1,10): s.floors[0][1][x]="."
	s.floors[0][1][9]="J"
	s.anchors=[anchor(0,8,1,9,1,"J")]
	return s
func proof(s:Dictionary,t:Dictionary)->Dictionary:
	var before:=s.duplicate(true); var target_before:=t.duplicate(true)
	var result:=Nav.route(s,t)
	check(var_to_str(s)==var_to_str(before) and var_to_str(t)==var_to_str(target_before),"navigation never mutates state or destination")
	return result
func _init():
	var s:=corridor(); var t:Dictionary=s.anchors[0]
	var r:=proof(s,t)
	check(r.ok and r.steps==7 and r.path.size()==7,"actual adjacent registered stand coordinate")
	for token in ["s","g","u","b","w","V","K","B","Z","H","W","D","L","a","d","h","k","C","I","T","$","A","P","t","R","?","#"]:
		s=corridor(); s.floors[0][1][4]=token
		check(not proof(s,s.anchors[0]).ok,"no automatic fight/pickup/unlock: "+token)
	for flag in ["drain","bridge","none","spring"]:
		s=corridor(); s.floors[0][1][4]="~"; s.water_choice=flag if flag in ["drain","spring"] else ""; s.bridge_built=flag=="bridge"
		check(proof(s,s.anchors[0]).ok==(flag in ["drain","bridge"]),"water uses real terrain choice")
	for opened in [false,true]:
		s=corridor(); s.floors[0][1][4]="="; s.expedition_bridge=opened
		check(proof(s,s.anchors[0]).ok==opened,"expedition bridge uses paid flag")
	s=corridor(); s.floors[0][1][4]="N"
	check(not proof(s,s.anchors[0]).ok,"unread N is an information pickup")
	s.clue=true
	check(not proof(s,s.anchors[0]).ok,"legacy clue alone does not imply all N effects")
	s.seal_clues=4
	check(proof(s,s.anchors[0]).ok,"already read N has no new side effects")
	s=corridor(); t=s.anchors[0].duplicate(); s.anchors=[]
	check(not proof(s,t).ok,"seen floor is not anchor registration")
	s=corridor(); t=s.anchors[0].duplicate(); t.marker_x=7
	check(not proof(s,t).ok,"forged marker rejected")
	s=corridor(); s.floors[0][1][9]="."
	check(not proof(s,s.anchors[0]).ok,"removed landmark invalidates registration")
	s=corridor(); s.floor_seen[0]=false
	check(not proof(s,s.anchors[0]).ok,"unseen destination rejected")
	s=corridor(); s.floors[0][1][1]="h"
	check(not proof(s,s.anchors[0]).ok,"unsafe origin rejected")
	# Entering stairs changes floor immediately; there is no same-floor edge
	# that silently walks through the stair tile to the corridor behind it.
	s=corridor(); s.floors[0][1][3]=">"
	for x in range(1,10): s.floors[1][1][x]="."
	s.floors[1][1][1]="<"; s.floors[1][1][9]="J"
	check(not proof(s,s.anchors[0]).ok,"cannot walk straight through stairs")
	t=anchor(1,8,1,9,1,"J"); s.anchors.append(t)
	r=proof(s,t)
	check(r.ok and r.steps==9 and r.path[1].floor==1 and r.path[1].x==1,"ascending real landing")
	s.floor_seen[1]=false
	check(not proof(s,t).ok,"no new floor discovery through navigation")
	s.floor_seen[1]=true; s.floors[1][1][1]="h"
	check(not proof(s,t).ok,"stair landing cannot skip a pickup")
	s=blank(); s.floor=1; s.x=2; s.y=1
	s.floors[1][1][2]="."; s.floors[1][1][1]="<"
	s.floors[0][9][9]=">"; s.floors[0][9][8]="."; s.floors[0][9][7]="J"
	t=anchor(0,8,9,7,9,"J"); s.anchors=[t]
	r=proof(s,t)
	check(r.ok and r.steps==2 and r.path[0].x==9 and r.path[0].y==9,"descending real landing")
	# Only the actual repaired E pair provides lift edges, including nearby
	# interaction. This is what preserves an uncleared floor-two bypass value.
	s=blank(); s.x=1; s.y=5
	s.floors[0][5][1]="."; s.floors[0][5][2]="E"
	s.floors[2][1][4]="E"; s.floors[2][1][5]="."
	t=anchor(2,5,1,4,1,"E"); s.anchors=[t]
	for core in ["","forge","sale","lift"]:
		s.core_use=core
		check(not proof(s,t).ok,"unrepaired elevator has no shortcut")
	s.core_use="elevator"; r=proof(s,t)
	check(r.ok and r.steps==2 and r.path[0].kind=="lift","real repaired lift action from adjacent tile")
	s.floor_seen[2]=false
	check(not proof(s,t).ok,"lift cannot grant new-floor focus")
	s.floor_seen[2]=true; s.floors[2][1][4]="h"
	check(not proof(s,t).ok,"lift cannot land on resource or stale marker")
	s=corridor(); t=s.anchors[0].duplicate(); t.x=8.5
	check(not proof(s,t).ok,"fractional coordinate rejected")
	s=corridor(); s.floors[0][1].pop_back()
	check(not proof(s,s.anchors[0]).ok,"malformed row rejected without indexing")
	# Regression: Vector3i narrows to signed 32-bit, so checking bounds only
	# after conversion could turn 2^32+1 into a legitimate coordinate 1.
	for enormous in [4294967296,4294967297,4294967304,1.0e100,-1,-4294967295,INF,NAN]:
		for field in ["floor","x","y","marker_x","marker_y"]:
			s=corridor(); t=s.anchors[0].duplicate(); t[field]=enormous
			var untouched:=t.duplicate(true)
			check(not Nav.anchor_valid(s,t),"raw anchor range rejects "+field)
			# NaN is unequal to itself; serialized snapshots also cover it.
			check(var_to_str(t)==var_to_str(untouched),"raw anchor check never mutates input")
			check(not proof(s,t).ok,"route rejects oversized/negative target "+field)
		for field in ["floor","x","y"]:
			s=corridor(); s[field]=enormous
			check(not proof(s,s.anchors[0]).ok,"raw origin range rejects "+field)
		s=corridor(); s.seal_clues=enormous
		check(not proof(s,s.anchors[0]).ok,"raw clue mask range rejects overflow")
	print("Navigation: %d checks, failures=%d"%[checks,failures])
	quit(1 if failures else 0)
