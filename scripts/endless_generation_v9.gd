class_name TowerEndlessGenerationV9
extends "res://scripts/endless_generation_v8.gd"
const G8=preload("res://scripts/endless_generation_v8.gd")
static func manifest(seed:int,f:int)->Dictionary:
	var route:int=G8.mix(seed,f,907)%2
	var data:Dictionary=G8.routes(seed,f)[route]
	return {"source":f,"route":route,"route_label":data.label,"points":data.points.duplicate(),"reward_count":route+1,"deposit":12,"exchange_price":8}
static func generate(seed:int,f:int)->Dictionary:
	var data:Dictionary=G8.generate(seed,f)
	if data.ok:data.contract=manifest(seed,f);data.revision=9
	return data
static func validate(data:Dictionary)->Dictionary:
	var result:Dictionary=G8.validate(data)
	if result.ok and data.get("contract",{})!=manifest(data.seed,data.floor):return {"ok":false,"errors":["contract manifest"]}
	return result
