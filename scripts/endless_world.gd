class_name TowerEndlessWorld
extends RefCounted
## Rules router. Saved action logs always replay with their original rules.
const MAX_ACTIONS:=100000
const CURRENT_VERSION:=22
const SUPPORTED_VERSIONS=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22]
const RULE_SCRIPTS={
 1:"res://scripts/endless_world_v1.gd",
 2:"res://scripts/endless_world_v2.gd",
 3:"res://scripts/endless_world_v3.gd",
 4:"res://scripts/endless_world_v4.gd",
 5:"res://scripts/endless_world_v5.gd",
 6:"res://scripts/endless_world_v6.gd",
 7:"res://scripts/endless_world_v7.gd",
 8:"res://scripts/endless_world_v8.gd",
 9:"res://scripts/endless_world_v9.gd",
 10:"res://scripts/endless_world_v10.gd",
 11:"res://scripts/endless_world_v11.gd",
 12:"res://scripts/endless_world_v12.gd",
 13:"res://scripts/endless_world_v13.gd",
 14:"res://scripts/endless_world_v14.gd",
 15:"res://scripts/endless_world_v15.gd",
 16:"res://scripts/endless_world_v16.gd",
 17:"res://scripts/endless_world_v17.gd",
 18:"res://scripts/endless_world_v18.gd",
 19:"res://scripts/endless_world_v19.gd",
 20:"res://scripts/endless_world_v20.gd",
 21:"res://scripts/endless_world_v21.gd",
 22:"res://scripts/endless_world_v22.gd",
}
static func supports_version(version)->bool:
 # JSON numeric values are floats. Never coerce strings, booleans or fractions.
 if not (version is int or version is float):return false
 return is_finite(float(version)) and version==floor(float(version)) and int(version) in SUPPORTED_VERSIONS
static func new_run(run_seed:int,rule_version:int=CURRENT_VERSION):
 if not supports_version(rule_version):return null
 return load(RULE_SCRIPTS[rule_version]).new_run(run_seed)
static func new_v1_run(run_seed:int):
 return new_run(run_seed,1)
static func from_data(data:Dictionary):
 var version=data.get("version")
 if not supports_version(version):return null
 return load(RULE_SCRIPTS[int(version)]).from_data(data)
