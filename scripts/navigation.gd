class_name TowerNavigation
extends RefCounted
const Layout = preload("res://scripts/layout.gd")
# Pure current-state route proof. No World actions, pickup, combat or mutation.
const ANCHORS = ["J","N","F","M","U","Y","E"]
const SAFE = [".","J","F","M","U","Y","E","O","Q","X","v","<",">"]
const DIRS = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
static func integer(v) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v))
static func bounded_integer(v, minimum:int, maximum:int)->bool:
	# Compare raw numeric values BEFORE narrowing to int/Vector3i. JSON can
	# carry finite integral doubles far outside either integer storage range.
	return integer(v) and v>=minimum and v<=maximum
static func coordinates_valid(a:Dictionary,floor_count:int)->bool:
	return bounded_integer(a.get("floor"),0,floor_count-1) and bounded_integer(a.get("x"),1,9) and bounded_integer(a.get("y"),1,9)
static func fail(reason:String)->Dictionary:
	return {"ok":false,"steps":0,"path":[],"reason":reason}
static func point(a:Dictionary)->Vector3i:
	return Vector3i(int(a.x),int(a.y),int(a.floor))
static func anchor_valid(state:Dictionary,a)->bool:
	if not valid_maps(state): return false
	return _anchor_valid_checked(state,a)
# Internal only: route has already validated the complete immutable state.
static func _anchor_valid_checked(state:Dictionary,a)->bool:
	if not a is Dictionary: return false
	if not coordinates_valid(a,state.floors.size()): return false
	if not bounded_integer(a.get("marker_x"),1,9) or not bounded_integer(a.get("marker_y"),1,9): return false
	var p:=point(a)
	if p.z<0 or p.z>=state.floors.size() or p.x<1 or p.x>9 or p.y<1 or p.y>9 or not state.floor_seen[p.z]: return false
	var mx:=int(a.marker_x); var my:=int(a.marker_y)
	return mx>=1 and mx<=9 and my>=1 and my<=9 and absi(p.x-mx)+absi(p.y-my)<=1 and a.get("token","") in ANCHORS and state.floors[p.z][my][mx]==a.token and safe(p,state)
static func registered(a:Dictionary,state:Dictionary)->bool:
	if not valid_maps(state) or not _anchor_valid_checked(state,a): return false
	return _registered_checked(a,state)
static func _registered_checked(a:Dictionary,state:Dictionary)->bool:
	for record in state.anchors:
		if _anchor_valid_checked(state,record) and point(record)==point(a) and record.token==a.token and record.marker_x==a.marker_x and record.marker_y==a.marker_y: return true
	return false
static func safe(p:Vector3i,state:Dictionary)->bool:
	if p.z<0 or p.z>=state.floors.size() or p.x<1 or p.x>9 or p.y<1 or p.y>9 or not state.floor_seen[p.z]: return false
	var t:String=state.floors[p.z][p.y][p.x]
	if t in SAFE: return true
	if t=="N": return state.get("clue",false)==true and (int(state.get("seal_clues",0))&4)==4
	if t=="~": return state.get("water_choice","")=="drain" or state.get("bridge_built",false)==true
	if t in ["n","e"]:
		return state.get("expedition_revision",0)==3 and state.get("winch_choice","")==("rescue" if t=="n" else "armory")
	if t=="=": return state.get("expedition_bridge",false)==true
	return false
static func valid_maps(state:Dictionary)->bool:
	var revision=state.get("layout_revision",1)
	if not integer(revision) or (revision!=1 and revision!=2): return false
	if not state.get("floors") is Array or state.floors.size() not in [5,8]: return false
	if not state.get("floor_seen") is Array or state.floor_seen.size()!=state.floors.size() or not state.get("anchors") is Array: return false
	for seen in state.floor_seen:
		if not seen is bool: return false
	for grid in state.floors:
		if not grid is Array or grid.size()!=11: return false
		for row in grid:
			if not row is Array or row.size()!=11: return false
			for t in row:
				if not t is String or t.length()!=1: return false
	if not bounded_integer(state.get("expedition_revision",0),0,3) or state.get("winch_choice","") not in ["","rescue","armory"]: return false
	if state.anchors.size()>64: return false
	for key in ["clue","bridge_built","expedition_bridge"]:
		if not state.get(key,false) is bool: return false
	if not bounded_integer(state.get("seal_clues",0),0,7): return false
	return true
static func route(state:Dictionary,target:Dictionary)->Dictionary:
	if not valid_maps(state): return fail("Invalid navigation state")
	if not coordinates_valid(state,state.floors.size()): return fail("Invalid origin")
	if not integer(state.get("seal_clues",0)): return fail("Invalid clue state")
	if not _anchor_valid_checked(state,target) or not _registered_checked(target,state): return fail("Destination is not a registered anchor")
	var start:=point(state); var goal:=point(target)
	if not safe(start,state) or not safe(goal,state): return fail("Anchor is not currently safe")
	var queue:Array=[start]; var parents:Dictionary={start:start}; var kinds:Dictionary={}; var head:=0
	while head<queue.size():
		var p:Vector3i=queue[head]; head+=1
		if p==goal:
			var path:Array=[]
			while p!=start:
				path.push_front({"kind":kinds[p],"floor":p.z,"x":p.x,"y":p.y}); p=parents[p]
			return {"ok":true,"steps":path.size(),"path":path,"reason":""}
		var edges:Array=[]
		for d in DIRS:
			var n:=Vector3i(p.x+d.x,p.y+d.y,p.z)
			if not safe(n,state): continue
			var t:String=state.floors[n.z][n.y][n.x]
			if t in ["<",">"]:
				var landing:=Layout.stair_destination(state.floors,int(state.get("layout_revision",1)),n.z,Vector2i(n.x,n.y))
				if not landing.ok: continue
				n=Vector3i(landing.pos.x,landing.pos.y,int(landing.floor))
			if safe(n,state): edges.append({"point":n,"kind":"step"})
		if state.get("core_use","")=="elevator" and p.z in [0,2]:
			var lift_here:=Vector3i(2,5,0) if p.z==0 else Vector3i(4,1,2)
			var lift_there:=Vector3i(4,1,2) if p.z==0 else Vector3i(2,5,0)
			if absi(p.x-lift_here.x)+absi(p.y-lift_here.y)<=1 and state.floors[lift_here.z][lift_here.y][lift_here.x]=="E" and state.floors[lift_there.z][lift_there.y][lift_there.x]=="E" and safe(lift_there,state): edges.append({"point":lift_there,"kind":"lift"})
		for edge in edges:
			var n:Vector3i=edge.point
			if parents.has(n): continue
			parents[n]=p; kinds[n]=edge.kind; queue.append(n)
	return fail("No cleared, cost-free route connects these anchors")

# Same-floor click walking is deliberately narrower than landmark fast travel.
# Only already empty '.' cells may be traversed; no stairs, NPCs or open bridges.
static func walk_path(grid:Array,start:Vector2i,target:Vector2i)->Array[Vector2i]:
	var empty:Array[Vector2i]=[]
	if grid.size()!=11: return empty
	for row in grid:
		if not row is Array or row.size()!=11: return empty
		for token in row:
			if not token is String or token.length()!=1: return empty
	if start.x<1 or start.x>9 or start.y<1 or start.y>9 or target.x<1 or target.x>9 or target.y<1 or target.y>9: return empty
	if start==target or grid[start.y][start.x]=="#" or grid[target.y][target.x]!=".": return empty
	var queue:Array[Vector2i]=[start]
	var parents:Dictionary={start:start}
	var head:=0
	while head<queue.size():
		var p:Vector2i=queue[head]; head+=1
		if p==target:
			var path:Array[Vector2i]=[]
			while p!=start:
				path.push_front(p); p=parents[p]
			return path
		for direction in DIRS:
			var next:Vector2i=p+direction
			if next.x<1 or next.x>9 or next.y<1 or next.y>9 or parents.has(next) or grid[next.y][next.x]!=".": continue
			parents[next]=p; queue.append(next)
	return empty
