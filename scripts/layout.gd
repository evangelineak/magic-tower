class_name TowerLayout
extends RefCounted
const CURRENT := 2
static func valid_revision(revision:int)->bool:
	return revision in [1,2]
static func rotated(global_floor:int,revision:int)->bool:
	return revision==2 and global_floor%2==1
static func point(global_floor:int,p:Vector2i,revision:int)->Vector2i:
	return Vector2i(10-p.x,10-p.y) if rotated(global_floor,revision) else p
static func direction(global_floor:int,d:Vector2i,revision:int)->Vector2i:
	return -d if rotated(global_floor,revision) else d
static func entry(global_floor:int,revision:int)->Vector2i:
	return point(global_floor,Vector2i(1,1),revision)
static func exit_point(global_floor:int,revision:int)->Vector2i:
	return point(global_floor,Vector2i(9,9),revision)
# A half turn is its own inverse: converts authored maps to physical maps and
# physical maps back to authored coordinates without mutating the argument.
static func orient_maps(maps:Array,first_floor:int,revision:int)->Array:
	var result:=maps.duplicate(true)
	for f in range(result.size()):
		if not rotated(first_floor+f,revision): continue
		result[f].reverse()
		for row in result[f]: row.reverse()
	return result
static func route(global_floor:int,steps:String,revision:int)->String:
	if not rotated(global_floor,revision): return steps
	var result:=""
	for c in steps: result+={"U":"D","D":"U","L":"R","R":"L"}.get(c,c)
	return result
static func tile(maps:Array,f:int,p:Vector2i)->String:
	if f<0 or f>=maps.size() or p.x<0 or p.x>=11 or p.y<0 or p.y>=11: return "#"
	if not maps[f] is Array or maps[f].size()!=11 or not maps[f][p.y] is Array or maps[f][p.y].size()!=11: return "#"
	var value=maps[f][p.y][p.x]
	return value if value is String else "#"
static func stair_destination(maps:Array,revision:int,f:int,stair_pos:Vector2i)->Dictionary:
	if not valid_revision(revision): return {"ok":false}
	var token:=tile(maps,f,stair_pos)
	if token not in ["<",">"]: return {"ok":false}
	var next_floor:int=f+(1 if token==">" else -1)
	var landing:=stair_pos if revision==2 else (Vector2i(1,1) if token==">" else Vector2i(9,9))
	if tile(maps,next_floor,landing)!=("<" if token==">" else ">"): return {"ok":false}
	return {"ok":true,"floor":next_floor,"pos":landing}
static func door_info(global_floor:int,door_pos:Vector2i,revision:int)->Dictionary:
	if not valid_revision(revision) or global_floor<0 or global_floor>=8: return {}
	var p:=point(global_floor,door_pos,revision)
	if p==Vector2i(2,9) and global_floor in [0,2,3,5,6,7]:
		var reward:String={0:"$",2:"A",3:"P",5:"$",6:"A",7:"P"}[global_floor]
		return {"cost":2,"reward_token":reward,"reward_pos":point(global_floor,Vector2i(1,9),revision),"label":{ "$":"60 gold", "A":"5 ATK", "P":"140 HP and 1 focus"}[reward]}
	if revision==2 and global_floor in [0,3,4] and p==Vector2i(8,2):
		return {"cost":1,"reward_token":"d" if global_floor==3 else "h","reward_pos":point(global_floor,Vector2i(9,2),revision),"label":"4 DEF" if global_floor==3 else "70 HP"}
	return {}
