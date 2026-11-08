class_name TowerCargo
extends RefCounted
const Layout=preload("res://scripts/layout.gd")
const VERSION:=1
static func legacy()->Dictionary:
	return {"version":0,"state":"off","destination":""}
static func birth(seed_value:int,layout_revision:int=2)->Dictionary:
	if layout_revision!=2:return legacy()
	return {"version":1,"state":"waiting","destination":"vault" if seed_value%2==0 else "crown"}
static func valid_record(value,seed_value,layout_revision:int)->bool:
	if not value is Dictionary or value.size()!=3:return false
	for key in ["version","state","destination"]:
		if not value.has(key):return false
	if not (value.version is int or value.version is float) or not is_finite(float(value.version)) or (value.version!=0 and value.version!=1):return false
	if not value.state is String or not value.destination is String:return false
	if value.version==0:return value.state=="off" and value.destination==""
	if not (seed_value is int or seed_value is float) or not is_finite(float(seed_value)) or seed_value!=floor(float(seed_value)) or seed_value<0 or seed_value>2147483647:return false
	return layout_revision==2 and value.state in ["waiting","opened","shipped","claimed"] and value.destination==birth(int(seed_value)).destination
static func source_door()->Vector2i:return Vector2i(8,2)
static func source_box()->Vector2i:return Vector2i(9,2)
static func destination_floor(record:Dictionary)->int:return 2 if record.destination=="vault" else 4
static func destination_point(record:Dictionary)->Vector2i:return Vector2i(9,2) if record.destination=="vault" else Vector2i(1,3)
static func install(maps:Array,record:Dictionary)->void:
	# Replace only an existing protected wall, never ordinary loot or a route.
	if record.version==1 and record.destination=="vault":maps[2][2][9]="c"
static func valid_maps(maps:Array,record:Dictionary,expedition:bool)->bool:
	var count:=0
	for grid in maps:
		for row in grid:
			for token in row:
				if token=="c":count+=1
	if record.version==0:return count==0
	if count!=(1 if record.destination=="vault" else 0):return false
	if record.destination=="vault" and Layout.tile(maps,2,Vector2i(9,2))!="c":return false
	var door:=Layout.tile(maps,0,source_door())
	var box:=Layout.tile(maps,0,source_box())
	match record.state:
		"waiting":
			if door!="D" or box!="h":return false
		"opened":
			if door!="." or box not in ["h","."]:return false
		"shipped","claimed":
			if door!="." or box!=".":return false
	if record.state=="claimed":
		if record.destination=="vault" and Layout.tile(maps,2,Vector2i(8,3))=="V":return false
		if record.destination=="crown":
			if not expedition:return false
			for row in maps[4]:
				if "K" in row:return false
	return true
