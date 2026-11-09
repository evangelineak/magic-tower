class_name TowerRiddle
extends RefCounted

const VERSION := 1
const SYMBOL_IDS := ["sun", "moon", "tower", "key"]
const SYMBOLS := {"sun":"Sun", "moon":"Moon", "tower":"Tower", "key":"Key"}

# Factoradic enumeration: the seed selects one of all 24 target permutations.
# Separate from map RNG, so reading a clue or generating another room cannot
# reroll the answer. Target positions are D, A, B, C respectively.
static func solution(run_seed: int) -> Array:
	var index := ((run_seed % 24)+24)%24
	var pool := SYMBOL_IDS.duplicate()
	var answer: Array=[]
	for divisor in [6,2,1,1]:
		var choice := floori(float(index)/divisor)
		index=index%divisor
		answer.append(pool.pop_at(choice))
	return answer

static func clues(run_seed: int) -> Array:
	var answer := solution(run_seed)
	return [
		"Contract: %s is neither first nor last." % SYMBOLS[answer[1]],
		"Valve: %s must be immediately before %s." % [SYMBOLS[answer[2]],SYMBOLS[answer[3]]],
		"Inscription: %s is before %s." % [SYMBOLS[answer[0]],SYMBOLS[answer[1]]]
	]

static func valid_input(input: Array, allow_complete:=true) -> bool:
	if input.size()>(4 if allow_complete else 3): return false
	var seen := {}
	for id in input:
		if not id is String or not SYMBOLS.has(id) or seen.has(id): return false
		seen[id]=true
	return true

static func satisfies_clues(run_seed: int, input: Array, clue_mask:=7) -> bool:
	if input.size()!=4 or not valid_input(input): return false
	var answer := solution(run_seed)
	var a := input.find(answer[1])
	var b := input.find(answer[2])
	var c := input.find(answer[3])
	var d := input.find(answer[0])
	if clue_mask & 1 and (a==0 or a==3): return false
	if clue_mask & 2 and c!=b+1: return false
	if clue_mask & 4 and d>=a: return false
	return true
