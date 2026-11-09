class_name TowerEndlessGenerationV13
extends "res://scripts/endless_generation_v12.gd"
const G12=preload("res://scripts/endless_generation_v12.gd")
static func rune_info(seed:int,f:int)->Dictionary:
	var quiet:bool="p" in G12.roster12(seed,f) and G12.mix(seed,f,1907)%2==0
	return {"kind":"silence" if quiet else "shock","price":10 if quiet else 18,"title":"寂静铭文" if quiet else "震击铭文","entry":G12.anchors(f).entry}
static func generate(seed:int,f:int)->Dictionary:
	var data:Dictionary=G12.generate(seed,f)
	if data.ok:data.rune=rune_info(seed,f);data.revision=13
	return data
static func validate(data:Dictionary)->Dictionary:
	var result:Dictionary=G12.validate(data)
	if result.ok and data.get("rune",{})!=rune_info(data.seed,data.floor):return {"ok":false,"errors":["rune identity"]}
	return result
