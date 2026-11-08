class_name TowerProgression
extends RefCounted

# All archetypes start from the same baseline. Tactical abilities and mutually
# exclusive loadouts change decisions without weakening the generation witness.
const FOCUS_START := 2
const FOCUS_MAX := 3
const HEROES := {
	"warden": {"name":"Warden", "skill":"Brace", "description":"Spend 1 focus: reduce the next battle's total loss by 30."},
	"ranger": {"name":"Ranger", "skill":"Precision", "description":"Spend 1 focus: ignore 10 enemy DEF for the next battle."},
	"scholar": {"name":"Scholar", "skill":"Mend", "description":"Spend 1 focus outside battle: recover 80 HP."}
}
const GEAR := {
	"balanced": {"name":"Traveler's kit", "atk":0, "def":0, "description":"No bonuses or penalties. The safe baseline."},
	"buckler": {"name":"Heavy buckler", "atk":-4, "def":6, "description":"+6 DEF / -4 ATK. May fail to break heavy armor."},
	"duelist": {"name":"Duelist's rig", "atk":6, "def":-3, "description":"+6 ATK / -3 DEF. Fewer rounds, harder retaliation."}
}
const TALENT_TIERS := [
	{"kills":3, "choices":["iron_skin","keen_edge","clean_finish"]},
	{"kills":7, "choices":["last_stand","sentinel_lore","trained_focus"]},
	{"kills":12, "choices":["giant_slayer","battle_medic","unbroken"]}
]
const TALENTS := {
	"iron_skin": {"name":"Iron skin", "tier":0, "description":"+2 effective DEF in every battle."},
	"keen_edge": {"name":"Keen edge", "tier":0, "description":"+3 effective ATK in every battle."},
	"clean_finish": {"name":"Clean finish", "tier":0, "description":"After a zero-loss victory, recover 15 HP."},
	"last_stand": {"name":"Last stand", "tier":1, "description":"Below 200 HP before battle: +20% damage per hit (floor)."},
	"sentinel_lore": {"name":"Sentinel lore", "tier":1, "description":"+4 effective DEF against Sentinels only."},
	"trained_focus": {"name":"Trained focus", "tier":1, "description":"Brace blocks 40; Precision ignores 14 DEF; Mend heals 100."},
	"giant_slayer": {"name":"Giant slayer", "tier":2, "description":"Against enemies with at least 180 HP: +10% hit damage (floor)."},
	"battle_medic": {"name":"Battle medic", "tier":2, "description":"Recover 10 HP after a surviving victory."},
	"unbroken": {"name":"Unbroken", "tier":2, "description":"At 400+ HP before battle: reduce total loss by 20."}
}

static func valid_talents(chosen: Array) -> bool:
	if chosen.size()>TALENT_TIERS.size(): return false
	for i in chosen.size():
		if not chosen[i] is String or not chosen[i] in TALENT_TIERS[i].choices: return false
	return true

static func talent_options(kills: int, chosen: Array) -> Array:
	if not valid_talents(chosen) or chosen.size()>=TALENT_TIERS.size(): return []
	var tier: Dictionary = TALENT_TIERS[chosen.size()]
	if kills<int(tier.kills): return []
	return tier.choices.duplicate()

static func mend_heal(chosen: Array) -> int:
	return 100 if "trained_focus" in chosen else 80

static func battle(attack: int, defense: int, hp: int, enemy: Dictionary, hero: String, skill: bool, equipment: String, talents: Array) -> Dictionary:
	var result := {"valid":false, "survivable":false, "damage":-1, "hit":0, "rounds":0, "heal_after":0, "skill_consumed":false, "effective_atk":0, "effective_def":0, "enemy_def":0, "normal_damage":0, "first_strike_damage":0, "thorns_damage":0, "blocked_damage":0, "reason":"Invalid battle input."}
	if not HEROES.has(hero) or not GEAR.has(equipment) or not valid_talents(talents): return result
	if attack<=0 or defense<0 or hp<=0: return result
	for key in ["hp","atk","def"]:
		if not enemy.has(key) or not (enemy[key] is int or enemy[key] is float): return result
		if not is_finite(float(enemy[key])) or float(enemy[key])!=floor(float(enemy[key])) or enemy[key]<0: return result
	if enemy.hp<=0: return result
	if not enemy.get("first_strike",false) is bool: return result
	var thorns_value = enemy.get("thorns",0)
	if not (thorns_value is int or thorns_value is float): return result
	if not is_finite(float(thorns_value)) or float(thorns_value)!=floor(float(thorns_value)) or thorns_value<0: return result
	var gear: Dictionary = GEAR[equipment]
	var effective_atk := maxi(0, attack+int(gear.atk)+(3 if "keen_edge" in talents else 0))
	var effective_def := maxi(0, defense+int(gear.def)+(2 if "iron_skin" in talents else 0))
	if "sentinel_lore" in talents and (enemy.get("name","")=="Sentinel" or enemy.get("kind","")=="g"):
		effective_def+=4
	var enemy_def := int(enemy.def)
	if skill and hero=="ranger": enemy_def=maxi(0,enemy_def-(14 if "trained_focus" in talents else 10))
	result.effective_atk=effective_atk
	result.effective_def=effective_def
	result.enemy_def=enemy_def
	var hit := effective_atk-enemy_def
	if hit<=0:
		result.reason="Cannot break armor. Change equipment, use Precision, or return later."
		return result
	# Percentage bonuses apply to post-armor damage, add together, and round down
	# once. Flat ATK/DEF and armor penetration are already resolved above.
	var percent := 100
	if "last_stand" in talents and hp<200: percent+=20
	if "giant_slayer" in talents and enemy.hp>=180: percent+=10
	hit=int(floor(float(hit*percent)/100.0))
	var rounds := ceili(float(enemy.hp)/hit)
	var incoming_hit := maxi(0,int(enemy.atk)-effective_def)
	# Components are BEFORE total-loss mitigation. First strike attacks once even
	# if the hero would one-shot. Thorns ignores DEF and includes the killing hit.
	var normal_damage := maxi(0,rounds-1)*incoming_hit
	var first_strike_damage := incoming_hit if enemy.get("first_strike",false) else 0
	var thorns_damage := rounds*int(thorns_value)
	var raw_loss := normal_damage+first_strike_damage+thorns_damage
	var loss := raw_loss
	if skill and hero=="warden": loss=maxi(0,loss-(40 if "trained_focus" in talents else 30))
	if "unbroken" in talents and hp>=400: loss=maxi(0,loss-20)
	result.valid=true
	result.hit=hit
	result.rounds=rounds
	result.damage=loss
	result.normal_damage=normal_damage
	result.first_strike_damage=first_strike_damage
	result.thorns_damage=thorns_damage
	result.blocked_damage=raw_loss-loss
	result.survivable=loss<hp
	result.skill_consumed=skill and hero in ["warden","ranger"] and result.survivable
	if result.survivable:
		if "clean_finish" in talents and loss==0: result.heal_after+=15
		if "battle_medic" in talents: result.heal_after+=10
	result.reason="Victory possible." if result.survivable else "Lethal. Post-battle recovery cannot save you."
	return result
