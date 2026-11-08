class_name TowerProgression
extends RefCounted
const Attunement = preload("res://scripts/attunement.gd")

# All archetypes start from the same baseline. Tactical abilities and mutually
# exclusive loadouts change decisions without weakening the generation witness.
const BASE_SKILL_LEVEL := 10
const SKILL_LEVEL_CAP := 20
const ATTAINABLE_SKILL_LEVEL := 16
const FOCUS_START := 2
const FOCUS_MAX := 3
const HEROES := {
	"warden": {"name":"Warden", "skill":"Brace", "description":"Spend 1 focus: block 35% of total battle loss (rounded down)."},
	"ranger": {"name":"Ranger", "skill":"Precision", "description":"Spend 1 focus: ignore 10 enemy DEF for the next battle."},
	"scholar": {"name":"Scholar", "skill":"Mend", "description":"Spend 1 focus outside battle: recover 80 HP."}
}
const GEAR := {
	"balanced": {"name":"Traveler's kit", "atk":0, "def":0, "description":"No bonuses or penalties. The safe baseline."},
	"buckler": {"name":"Heavy buckler", "atk":-4, "def":6, "description":"+6 DEF / -4 ATK. Block the first enemy attack, not thorns."},
	"maul": {"name":"Siege maul", "atk":0, "def":-4, "description":"-4 DEF. Double damage per strike; each nonlethal strike draws two counters. Ambush and thorns still apply."},
	"repeater": {"name":"Repeating crossbow", "atk":-3, "def":-6, "description":"-3 ATK / -6 DEF. Fire up to three hits before counters begin. First strike and thorns still apply."},
	"duelist": {"name":"Duelist's rig", "atk":6, "def":-3, "description":"WARNING: take an EXTRA opening counter, even on a one-shot. Enemy DEF -8; +6 ATK / -3 DEF."}
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
	"trained_focus": {"name":"Trained focus", "tier":1, "description":"Brace blocks 45% (floor); Precision ignores 14 DEF; Mend heals 100."},
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

static func skill_level(chosen: Array, attunement: String = "none") -> int:
	if not Attunement.valid_id(attunement): return -1
	return clampi(BASE_SKILL_LEVEL+(4 if "trained_focus" in chosen else 0)+int(Attunement.modifiers(attunement).levels),1,SKILL_LEVEL_CAP)

static func skill_level_info(chosen: Array, attunement: String = "none") -> Dictionary:
	if not Attunement.valid_id(attunement): return {}
	return {"base":BASE_SKILL_LEVEL,"training":4 if "trained_focus" in chosen else 0,"gear":int(Attunement.modifiers(attunement).levels),"effective":skill_level(chosen,attunement),"cap":SKILL_LEVEL_CAP,"attainable_max":ATTAINABLE_SKILL_LEVEL}

static func mend_heal(chosen: Array, attunement: String = "none") -> int:
	var level:=skill_level(chosen,attunement)
	return 30+5*level if level>=1 else 0

static func brace_percent(chosen: Array, attunement: String = "none") -> int:
	var level:=skill_level(chosen,attunement)
	return floori(10.0+2.5*level) if level>=1 else 0

static func skill_description(hero: String, chosen: Array, attunement: String = "none") -> String:
	match hero:
		"warden": return "Spend 1 focus: block %d%% of total battle loss (rounded down)." % brace_percent(chosen,attunement)
		"ranger": return "Spend 1 focus: ignore %d enemy DEF for the next battle." % skill_level(chosen,attunement)
		"scholar": return "Spend 1 focus outside battle: recover %d HP." % mend_heal(chosen,attunement)
	return "Unknown hero."

static func battle(attack: int, defense: int, hp: int, enemy: Dictionary, hero: String, skill: bool, equipment: String, talents: Array, oath: String = "none", flank: bool = false, attunement: String = "none") -> Dictionary:
	var result := {"valid":false, "survivable":false, "damage":-1, "hit":0, "rounds":0, "heal_after":0, "skill_consumed":false, "effective_atk":0, "effective_def":0, "enemy_def":0, "normal_damage":0, "first_strike_damage":0, "thorns_damage":0, "blocked_damage":0, "feint_damage":0, "charged_damage":0, "equipment_blocked":0, "oath_blocked":0, "oath_active":oath=="watch", "first_strike_suppressed":false, "first_strike_suppression":"none", "flank_blocked":0, "flank_active":flank, "attack_multiplier":1, "retaliations_per_hit":1, "retaliations":0, "skill_level":0, "attunement":attunement, "reason":"Invalid battle input."}
	if not HEROES.has(hero) or not GEAR.has(equipment) or not valid_talents(talents) or not oath in ["none","watch"] or not Attunement.valid_id(attunement): return result
	if attack<=0 or defense<0 or hp<=0: return result
	for key in ["hp","atk","def"]:
		if not enemy.has(key) or not (enemy[key] is int or enemy[key] is float): return result
		if not is_finite(float(enemy[key])) or float(enemy[key])!=floor(float(enemy[key])) or enemy[key]<0: return result
	if enemy.hp<=0: return result
	if not enemy.get("first_strike",false) is bool: return result
	result.first_strike_suppressed=(flank or oath=="watch") and enemy.get("first_strike",false)
	if result.first_strike_suppressed:
		result.first_strike_suppression="flank" if flank else "oath"
	var thorns_value = enemy.get("thorns",0)
	if not (thorns_value is int or thorns_value is float): return result
	if not is_finite(float(thorns_value)) or float(thorns_value)!=floor(float(thorns_value)) or thorns_value<0: return result
	var heavy_every := 0
	if enemy.has("heavy_every"):
		var period = enemy.heavy_every
		if not (period is int or period is float): return result
		# This version implements one explicit mechanic, not arbitrary modulo
		# values. Accept 3.0 for JSON roundtrips, but reject booleans and strings.
		if not is_finite(float(period)) or float(period)!=3.0: return result
		heavy_every=3
	var gear: Dictionary = GEAR[equipment]
	var tuning: Dictionary = Attunement.modifiers(attunement)
	result.skill_level=skill_level(talents,attunement)
	var effective_atk := maxi(0, attack+int(gear.atk)+int(tuning.atk)+(3 if "keen_edge" in talents else 0)-(10 if oath=="watch" else 0))
	var effective_def := maxi(0, defense+int(gear.def)+int(tuning.def)+(2 if "iron_skin" in talents else 0))
	if "sentinel_lore" in talents and (enemy.get("name","")=="Sentinel" or enemy.get("kind","")=="g"):
		effective_def+=4
	var enemy_def := int(enemy.def)
	if skill and hero=="ranger": enemy_def=maxi(0,enemy_def-int(result.skill_level))
	if equipment=="duelist": enemy_def=maxi(0,enemy_def-8)
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
	result.attack_multiplier=2 if equipment=="maul" else 1
	result.retaliations_per_hit=2 if equipment=="maul" else 1
	# Maul multiplies the already rounded per-hit damage, not each modifier.
	hit*=int(result.attack_multiplier)
	var rounds := ceili(float(enemy.hp)/hit)
	var incoming_hit := maxi(0,int(enemy.atk)-effective_def)
	# Components are BEFORE total-loss mitigation. First strike attacks once even
	# if the hero would one-shot. Thorns ignores DEF and includes the killing hit.
	var normal_retaliations := maxi(0,rounds-(3 if equipment=="repeater" else 1))*int(result.retaliations_per_hit)
	var feint_counter := 1 if equipment=="duelist" else 0
	var retaliations := normal_retaliations+feint_counter
	var normal_damage := normal_retaliations*incoming_hit
	var feint_damage := feint_counter*incoming_hit
	# The non-contact feint causes a real counter, even before a killing hit.
	# It advances the heavy-strike counter, but never triggers thorns itself.
	# First strike is a separate opening attack, not a retaliation.
	var charged_damage := floori(float(retaliations)/heavy_every)*incoming_hit if heavy_every>0 else 0
	var first_strike_damage := incoming_hit if enemy.get("first_strike",false) else 0
	var thorns_damage := rounds*int(thorns_value)
	var raw_loss := normal_damage+feint_damage+charged_damage+first_strike_damage+thorns_damage
	# Watch suppresses the ambush itself, then halves EACH thorn trigger.
	# Raw components remain visible; its reduction is separately reported.
	var flank_blocked := first_strike_damage if flank else 0
	# Flank gets attribution first; an active oath cannot cancel the same ambush twice.
	var oath_blocked := (0 if flank else first_strike_damage)+rounds*(int(thorns_value)-floori(float(thorns_value)/2.0)) if oath=="watch" else 0
	# The shield intercepts exactly the first enemy attack: first strike if
	# present, otherwise retaliation #1. The blocked swing still advances the
	# enemy counter, and thorns can never be intercepted by this equipment.
	var equipment_blocked := incoming_hit if equipment=="buckler" and ((enemy.get("first_strike",false) and not result.first_strike_suppressed) or retaliations>0) else 0
	var loss := raw_loss-flank_blocked-oath_blocked-equipment_blocked
	# Order: equipment, then floor(remaining loss * Brace rate), then Unbroken.
	# No minimum block: a one-damage battle still costs one HP without a shield.
	if skill and hero=="warden": loss-=int(floor(float(loss*brace_percent(talents,attunement))/100.0))
	if "unbroken" in talents and hp>=400: loss=maxi(0,loss-20)
	result.valid=true
	result.hit=hit
	result.rounds=rounds
	result.damage=loss
	result.normal_damage=normal_damage
	result.feint_damage=feint_damage
	result.charged_damage=charged_damage
	result.equipment_blocked=equipment_blocked
	result.oath_blocked=oath_blocked
	result.flank_blocked=flank_blocked
	result.retaliations=retaliations
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
