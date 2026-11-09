class_name TowerEndlessGenerationV6
extends "res://scripts/endless_generation_v5.gd"
# The v5 map contracts are frozen; v6 adds optional camp encounters only.
static func encounter_kind(seed:int,f:int)->String:
	var state:int=(seed%2147483646+(f%2147483646)*97+1)%2147483647
	state=(state*48271)%2147483647
	state=(state*48271)%2147483647
	return ["quartermaster","medicine","altar"][state%3]
