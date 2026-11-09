extends SceneTree
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
var failure := ""
var visited_states := 0
func verify(w, context: String) -> bool:
	visited_states+=1
	var expected: Dictionary=w.save_data().duplicate(true)
	# Constructing a fresh world for every step reruns generation unnecessarily;
	# exercise the same atomic restore used by undo/load on the current object.
	var encoded: Dictionary=JSON.parse_string(JSON.stringify(expected))
	if not w.restore(encoded) or w.save_data()!=expected:
		failure="Legal state failed roundtrip: "+context
		return false
	return true
func act(w, id: String, context: String) -> bool:
	var before: Dictionary=w.save_data().duplicate(true)
	var changed: bool=w.action(id)
	if not changed and w.save_data()!=before:
		failure="Rejected action mutated state: %s / %s" % [id,context]
		return false
	return verify(w,context+" action "+id)
func _init():
	var runs:=0
	for seed_value in [0,42,834]:
		for hero in ["warden","ranger","scholar"]:
			var w=World.new(seed_value)
			var route: String=Generator.validate(w.floors).route
			if not act(w,"hero_"+hero,"start"): break
			var index:=0
			for command in route:
				var context: String="seed %d hero %s step %d" % [seed_value,hero,index]
				# Legitimate bonuses only; the conservative witness does not need them.
				if w.nearby("J") and w.quest_state==0:
					if not act(w,"quest_accept",context): break
				if w.nearby("M") and not w.loan_used and w.checkpoints==0:
					if not act(w,"borrow",context): break
				if w.nearby("M") and not w.weapon and w.gold>=60:
					if not act(w,"buy",context): break
				if w.nearby("O") and w.water_choice=="":
					if not act(w,"spring",context): break
				if w.nearby("X") and not w.event_done:
					if not act(w,"bargain_leave",context): break
				var choices: Array=w.Progression.talent_options(w.kills,w.talents)
				if not choices.is_empty():
					if not act(w,"talent_"+choices[0],context): break
				var direction: Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[command]
				if w.ENEMIES.has(w.tile(w.pos+direction)) and w.focus>0:
					if not act(w,"mend" if hero=="scholar" else "arm",context): break
				var predicted: Dictionary=w.battle_preview(w.tile(w.pos+direction)) if w.ENEMIES.has(w.tile(w.pos+direction)) else {}
				var hp_before: int=w.hp
				if not w.step(direction):
					failure="Legal bonus-only witness blocked: "+context
					break
				if not predicted.is_empty() and w.hp!=hp_before-int(predicted.damage)+int(predicted.heal_after):
					failure="Preview diverged from resolution: "+context
					break
				if not verify(w,context): break
				index+=1
			if not failure.is_empty(): break
			if not w.won: failure="Witness ended without victory"; break
			runs+=1
		if not failure.is_empty(): break
	if not failure.is_empty(): push_error(failure)
	print("ADVERSARIAL: %s (%d full runs, %d legal save/restore states)" % ["PASS" if failure.is_empty() else "FAIL",runs,visited_states])
	quit(0 if failure.is_empty() else 1)
