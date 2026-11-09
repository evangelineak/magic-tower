class_name TowerEndlessWorld
extends RefCounted
## Rules router. Saved action logs always replay with their original rules.
const MAX_ACTIONS:=100000
static func new_run(run_seed:int,rule_version:int=2):
 if rule_version==1:return load("res://scripts/endless_world_v1.gd").new_run(run_seed)
 if rule_version==2:return load("res://scripts/endless_world_v2.gd").new_run(run_seed)
 return null
static func new_v1_run(run_seed:int):
 return new_run(run_seed,1)
static func from_data(data:Dictionary):
 var version=data.get("version")
 # JSON numeric values are floats. Reject booleans, strings and fractions.
 if not (version is int or version is float):return null
 if version==1:return load("res://scripts/endless_world_v1.gd").from_data(data)
 if version==2:return load("res://scripts/endless_world_v2.gd").from_data(data)
 return null
