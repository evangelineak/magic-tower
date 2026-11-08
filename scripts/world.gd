class_name TowerWorld
extends RefCounted
const Exploration=preload("res://scripts/exploration.gd")
const Cargo=preload("res://scripts/cargo.gd")
var cargo:Dictionary=Cargo.legacy()
const Layout = preload("res://scripts/layout.gd")
const Generator = preload("res://scripts/generation.gd")
const BattleTimeline = preload("res://scripts/battle_timeline.gd")
const Progression = preload("res://scripts/progression.gd")
const LegacyPoints = preload("res://scripts/legacy_points.gd")
const Strategy = preload("res://scripts/legacy_strategy.gd")
const Attunement = preload("res://scripts/attunement.gd")
const ATTUNABLE_GEAR = ["buckler","duelist","repeater","maul"]
const Expedition = preload("res://scripts/expedition.gd")
const AuditPuzzle = preload("res://scripts/audit_puzzle.gd")
const Navigation = preload("res://scripts/navigation.gd")
const Riddle = preload("res://scripts/riddle.gd")

const MAPS = [
["###########","#@.k..#..a#","#JM#..#...#","#h.#s.D.s.#","#..#..#...#","#..a..#h..#","#.###.###.#","#...s.....#","##d.#..s..#","#$L.#....>#","###########"],
["###########","#<....#.Ra#","#.##s.#~~~#","#k.#..D.b.#","#OC#..#...#","#h.d..#h..#","#.###.###.#","#...g.....#","#a..#..s..#","#...#....>#","###########"],
["###########","#<.hE.#..a#","#..#g.#..##","#k.#..D.VT#","#..#..#..##","#..a..#h..#","#.###.###.#","#...g.....#","##Id#..g..#","#AL.#....>#","###########"],
["###########","#<.a..#..a#","#..#g.#...#","#N.#..D.g.#","#.X#..#...#","#h.F..#h..#","#.###.###.#","#...u...k.#","##a.#..w..#","#PL.#....>#","###########"],
["###########","#<.a..#..a#","#..#g.#...#","#Q.#..D.K.#","#..#..#...#","#h.a..#h..#","#.###.###.#","#...g...k.#","#d..#..g..#","#...#.....#","###########"]]
const ENEMIES = {
"s": {"name":"Mossling", "hp":35, "atk":14, "def":3, "gold":8},
"g": {"name":"Sentinel", "hp":75, "atk":25, "def":10, "gold":18},
"u": {"name":"Veil Stalker", "hp":95, "atk":42, "def":14, "gold":12, "first_strike":true},
"b": {"name":"Briar Sentinel", "hp":90, "atk":35, "def":12, "gold":16, "thorns":2},
"w": {"name":"Brass Juggernaut", "hp":180, "atk":32, "def":20, "gold":24, "heavy_every":3},
"V": {"name":"Vault Colossus", "hp":180, "atk":100, "def":65, "gold":30},
"K": {"name":"Astral Regent", "hp":450, "atk":65, "def":40, "gold":100},
"W": {"name":"Archive Gaoler", "hp":260, "atk":68, "def":48, "gold":40, "thorns":6, "heavy_every":3},
"H": {"name":"Ferry Warden", "hp":180, "atk":62, "def":30, "gold":60, "first_strike":true},
"Z": {"name":"Ashen Castellan", "hp":720, "atk":65, "def":45, "gold":160},
"B": {"name":"Hollow King", "hp":220, "atk":42, "def":20, "gold":100}}
var run_id := ""
var mode := "safe"
var ended_reason := ""
var death_record: Dictionary = {}
var draft: Dictionary = {"version":0,"pool":[],"offers":[],"choice":"none"}
var layout_revision := 2
var seed_value := 0
var generation_attempts := 0
var generation_fallback := false
var generation_valid := true
var hero_id := "warden"
var focus := 2
var focus_cap := 3
var skill_armed := false
var equipped := "balanced"
var inventory: Array = ["balanced"]
var attunement_version := Attunement.REVISION
var gear_offers: Dictionary = {}
var gear_choices: Dictionary = {}
var talents: Array = []
var talent_draft: Dictionary = {}
var last_kill_kind := ""
var legacy_points:Dictionary={"version":0,"capacity":0,"study":0,"reserve":0}
var legacy_reserves:=0
var kills := 0
var floor_seen: Array = [true,false,false,false,false]
var quest_state := 0
var event_done := false
var event_kind := "bargain"
var water_choice := ""
var bridge_built := false
var chest_claimed := false
var last_battle: Dictionary = {}
var core := false
var core_use := ""
var weapon := false
var secret := false
var clue := false
var seal_clues := 0
var seal_input: Array = []
var seal_solved := false
var seal_reward := ""
var principal := 0
var fees := 0
var interest := 0
var loan_used := false
var overdue := false
var checkpoints := 0
var floors: Array = []
var floor_index := 0
var pos := Vector2i(1,1)
var hp := 280
var atk := 18
var defense := 8
var keys := 0
var gold := 0
var audit_puzzle: Dictionary = {}
var audit_read := false
var audit_solved := false
var audit_reward := ""
var travel_anchors: Array = []
var winch_choice := ""
var maul_claimed := false
var oath_state := "fresh"
var expedition_revision := 0
var rescue_state := 0
var rescue_reward := ""
var expedition_started := false
var expedition_bridge := false
var camp_medicine_left := 2
var camp_focus_left := 2
var won := false
var moves := 0
var message := "Find the keys. Read your enemies. Ascend."
func _init(run_seed: int = 0, run_layout: int = 2, session_run_id: String = "", run_mode: String = "safe", restore_only: bool = false, strategy_pool: Array = []):
	if restore_only:
		generation_valid=false
		return
	run_id=session_run_id
	mode=run_mode
	layout_revision=run_layout if Layout.valid_revision(run_layout) else Layout.CURRENT
	seed_value=clampi(run_seed,0,2147483647)
	draft=Strategy.draft(seed_value,strategy_pool)
	legacy_points=LegacyPoints.allocate(LegacyPoints.capacity_for_pool(strategy_pool))
	talent_draft=Progression.talent_draft(seed_value)
	gear_offers=_new_gear_offers(seed_value)
	audit_puzzle=AuditPuzzle.generate(seed_value)
	event_kind=["bargain","smuggler","oath"][seed_value%3]
	var generated: Dictionary = Generator.generate(seed_value, MAPS, layout_revision)
	floors=generated.maps
	cargo=Cargo.birth(seed_value,layout_revision)
	Cargo.install(floors,cargo)
	generation_attempts=generated.attempts
	generation_fallback=generated.fallback
	generation_valid=bool(generated.validation.solvable) and Layout.valid_revision(run_layout) and valid_run_id(run_id) and mode in ["safe","risk"] and Strategy.valid_draft(seed_value,draft)
	if not generation_valid: message="Map validation failed. This run is blocked; choose another seed."
static func from_snapshot(snapshot: Dictionary) -> TowerWorld:
	# No generation, but no usable world until the entire restore validates.
	var instance:=TowerWorld.new(0,2,"","safe",true)
	if not instance.restore(snapshot): return null
	return instance
# Identity is assigned only by the external new-run session. Loading a legacy
# save never borrows this instance's identity. Risk mode does not enable death yet.
static func valid_run_id(value) -> bool:
	if not value is String: return false
	if value=="": return true
	if value.length()<16 or value.length()>64: return false
	for c in value:
		if not c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return false
	return true
func reward_eligible() -> bool:
	return run_id!="" and valid_run_id(run_id)
func highest_seen_floor() -> int:
	if floor_seen.size()!=floors.size() or not floor_seen.size() in [5,8]: return 0
	var peak:=0
	var gap:=false
	for seen in floor_seen:
		if not seen is bool: return 0
		if seen:
			if gap: return 0
			peak+=1
		else: gap=true
	return peak
func _finish_outcome() -> String:
	if ended_reason=="victory": return "victory"
	if ended_reason=="retired": return "chapter1" if won else "withdrawn"
	return ""
func _outcome_legal(outcome: String) -> bool:
	if strategy_pending() or not generation_valid or hp<=0 or highest_seen_floor()==0: return false
	match outcome:
		"withdrawn": return not won
		"chapter1": return won and not expedition_started and floors.size()==5 and highest_seen_floor()==5 and _count_token("K")==0
		"victory": return won and expedition_started and floors.size()==8 and highest_seen_floor()==8 and _count_token("Z")==0
	return false
func finish_run(outcome: String) -> bool:
	# Session calls this on a clone, persists settlement atomically, then publishes.
	if not _outcome_legal(outcome): return false
	if ended_reason!="": return _finish_outcome()==outcome
	ended_reason="victory" if outcome=="victory" else "retired"
	return true
func settlement_summary(outcome: String) -> Dictionary:
	if outcome=="defeat":
		if not reward_eligible(): return {"ok":false,"reason":"INELIGIBLE"}
		if mode!="risk" or ended_reason!="death" or hp!=0 or death_record.is_empty() or highest_seen_floor()==0 or TowerWorld.from_snapshot(save_data())==null: return {"ok":false,"reason":"INVALID_OUTCOME"}
		return {"ok":true,"summary":{"seed":seed_value,"max_floor":highest_seen_floor(),"moves":moves,"outcome":"defeat"}}
	if not reward_eligible(): return {"ok":false,"reason":"INELIGIBLE"}
	if ended_reason=="" or _finish_outcome()!=outcome or not _outcome_legal(outcome):
		return {"ok":false,"reason":"INVALID_OUTCOME"}
	return {"ok":true,"summary":{"seed":seed_value,"max_floor":highest_seen_floor(),"moves":moves,"outcome":outcome}}
func strategy_pending() -> bool:
	return draft.get("choice","")==""
func current_strategy() -> String:
	return "none" if strategy_pending() else str(draft.get("choice","none"))
func choose_strategy(id: String, allocation: Dictionary = {}) -> bool:
	if not generation_valid or ended_reason!="" or won or moves!=0 or not strategy_pending() or not Strategy.valid_choice(draft.offers,id): return false
	var points:=LegacyPoints.allocate(int(legacy_points.capacity),allocation)
	if points.is_empty(): return false
	if int(legacy_points.version)==0: points=LegacyPoints.legacy()
	draft.choice=id;legacy_points=points;legacy_reserves=int(points.reserve)
	return true
func legacy_study() -> int:
	return int(legacy_points.get("study",0))
func setup_preview(id:String,allocation:Dictionary={}) -> Dictionary:
	if not Strategy.valid_choice(draft.get("offers",[]),id): return {"valid":false}
	var points:=LegacyPoints.allocate(int(legacy_points.get("capacity",0)),allocation)
	if points.is_empty(): return {"valid":false}
	var study:int=points.study
	var hero_descriptions:Dictionary={}
	for hero in ["warden","ranger","scholar"]:
		hero_descriptions[hero]=Progression.skill_description(hero,talents,gear_attunement(),id,study)
	var hero_effects:Dictionary={"warden_block_percent":Progression.brace_percent(talents,gear_attunement(),id,study),"ranger_ignore_def":Progression.skill_level(talents,gear_attunement(),id,study),"scholar_heal":Progression.mend_heal(talents,gear_attunement(),id,study)}
	return {"hero_effects":hero_effects,"hero_skill_descriptions":hero_descriptions,"valid":true,"id":id,"name":"Original strategy" if id=="none" else Strategy.TEMPLATES[id].name,"description":"No strategy bonuses or costs." if id=="none" else Strategy.TEMPLATES[id].description,"capacity":points.capacity,"study":study,"reserve":points.reserve,"remaining":int(points.capacity)-study-int(points.reserve),"reserve_remaining":points.reserve,"skill_level":Progression.skill_level(talents,gear_attunement(),id,study),"skill_level_info":Progression.skill_level_info(talents,gear_attunement(),id,study),"skill_description":Progression.skill_description(hero_id,talents,gear_attunement(),id,study),"mend_heal":Progression.mend_heal(talents,gear_attunement(),id,study),"selected":draft.get("choice")==id,"can_choose":generation_valid and ended_reason=="" and not won and moves==0 and strategy_pending()}
func strategy_preview(id: String) -> Dictionary:
	return setup_preview(id,{"study":legacy_study(),"reserve":int(legacy_points.get("reserve",0))})
func legacy_focus_available() -> bool:
	return generation_valid and not strategy_pending() and ended_reason=="" and not won and hp>0 and legacy_reserves>0 and focus<focus_cap
func legacy_summary() -> String:
	var info:=skill_level_info()
	return "Legacy points: study %d (+%d levels) / reserve %d / capacity %d. Supplies left: %d. Skill level %d (raw %d; overflow %d)." % [legacy_study(),legacy_study()*2,int(legacy_points.reserve),int(legacy_points.capacity),legacy_reserves,int(info.effective),int(info.raw),int(info.overflow)]
func talent_candidates() -> Array:
	if talents.size()>=3 or not talent_draft.has("offers"): return []
	return talent_draft.offers[talents.size()].duplicate()
func talent_options() -> Array:
	if strategy_pending() or ended_reason!="" or not generation_valid or won or talents.size()>=3: return []
	if kills<int(Progression.TALENT_TIERS[talents.size()].kills): return []
	return talent_candidates()
func talent_progress() -> Dictionary:
	return {"available":not talent_options().is_empty(),"next_kills":int(Progression.TALENT_TIERS[talents.size()].kills) if talents.size()<3 else 0,"kills":kills,"tier":talents.size()}
func talent_preview_targets() -> Array:
	var result:Array=[]
	if floors.is_empty(): return result
	for f in range(floors.size()):
		if f!=floor_index and (f!=2 or not floor_seen[2]): continue
		for y in range(1,10):
			for x in range(1,10):
				var kind:String=floors[f][y][x]
				if not ENEMIES.has(kind) or (f!=floor_index and kind!="V"): continue
				result.append({"kind":kind,"floor":f,"pos":Vector2i(x,y),"label":"%s / floor %d" % [ENEMIES[kind].name,f+1]})
	return result
func talent_preview(id:String,kind:String="",target:Vector2i=Vector2i(-1,-1),target_floor:int=-1) -> Dictionary:
	if not id in talent_candidates(): return {"valid":false}
	var result={"valid":true,"id":id,"name":Progression.TALENTS[id].name,"description":Progression.TALENTS[id].description,"can_choose":id in talent_options(),"before":{},"after":{}}
	var f:=floor_index if target_floor==-1 else target_floor
	var allowed:=false
	for entry in talent_preview_targets():
		if entry.floor==f and entry.pos==target and entry.kind==kind: allowed=true;break
	if not allowed: return result
	var next:=talents.duplicate();next.append(id)
	result.before=_battle_preview_with_talents(kind,equipped,target,talents,f)
	result.after=_battle_preview_with_talents(kind,equipped,target,next,f)
	return result
func _new_gear_offers(run_seed:int)->Dictionary:
	var result:Dictionary={}
	for gear in ATTUNABLE_GEAR: result[gear]=Attunement.offers(run_seed,gear)
	return result
func gear_attunement(gear_id:String="")->String:
	var gear:=equipped if gear_id=="" else gear_id
	if not gear in inventory or not gear in ATTUNABLE_GEAR: return "none"
	return str(gear_choices.get(gear,"none"))
func skill_level()->int:
	return Progression.skill_level(talents,gear_attunement(),current_strategy(),legacy_study())
func skill_level_info()->Dictionary:
	return Progression.skill_level_info(talents,gear_attunement(),current_strategy(),legacy_study())
func skill_description()->String:
	return Progression.skill_description(hero_id,talents,gear_attunement(),current_strategy(),legacy_study())
func mend_heal()->int:
	return Progression.mend_heal(talents,gear_attunement(),current_strategy(),legacy_study())
func attunement_offers(gear_id:String="")->Array:
	var gear:=equipped if gear_id=="" else gear_id
	if strategy_pending() or ended_reason!="" or not generation_valid or won or not gear in ATTUNABLE_GEAR or gear_choices.has(gear): return []
	var result:Array=[]
	for id in gear_offers[gear]: result.append(["attune_"+gear+"_"+id,Attunement.TEMPLATES[id].name])
	result.append(["attune_"+gear+"_none","Keep original equipment"])
	return result
func attunement_preview(id:String,gear_id:String="")->Dictionary:
	var gear:=equipped if gear_id=="" else gear_id
	if not gear in ATTUNABLE_GEAR or not Attunement.valid_selection(gear_offers.get(gear,[]),id): return {"valid":false}
	var changes:Dictionary=Attunement.modifiers(id)
	return {"valid":true,"gear":gear,"id":id,"name":"Original equipment" if id=="none" else Attunement.TEMPLATES[id].name,"description":"No attunement bonuses or penalties." if id=="none" else Attunement.TEMPLATES[id].description,"atk":int(changes.atk),"def":int(changes.def),"levels":int(changes.levels),"skill_level":Progression.skill_level(talents,id,current_strategy(),legacy_study()),"skill_level_info":Progression.skill_level_info(talents,id,current_strategy(),legacy_study()),"skill_description":Progression.skill_description(hero_id,talents,id,current_strategy(),legacy_study()),"mend_heal":Progression.mend_heal(talents,id,current_strategy(),legacy_study()),"owned":gear in inventory,"can_choose":not strategy_pending() and generation_valid and not won and gear in inventory and not gear_choices.has(gear),"locked":gear_choices.has(gear),"selected":gear_choices.has(gear) and gear_choices[gear]==id}
func attunement_description(gear_id:String="")->String:
	var gear:=equipped if gear_id=="" else gear_id
	if not gear in ATTUNABLE_GEAR and gear!="balanced": return ""
	if not gear in inventory: return "Not owned yet. These offers are fixed for this run."
	if gear=="balanced": return "Traveler's kit cannot be attuned."
	if not gear_choices.has(gear): return "Unattuned. Choose once, or keep the original equipment."
	var id:String=gear_choices[gear]
	return "Original equipment retained. This choice is locked." if id=="none" else Attunement.TEMPLATES[id].description
func attunement_journal()->Array:
	var result:Array=[]
	for gear in inventory:
		if not gear_choices.has(gear): continue
		var id:String=gear_choices[gear]
		result.append("Equipment attunement: %s / %s" % [Progression.GEAR[gear].name,"Original equipment" if id=="none" else Attunement.TEMPLATES[id].name])
	return result
func floor_count() -> int:
	return floors.size()
func floor_title() -> String:
	return ["THE ROOTS","THE WARDENS","THE VAULT","THE FORGE","THE CROWN","THE ASH CAMP","THE BROKEN ROAD","THE LAST WATCH"][floor_index]
func chapter_offers() -> Array:
	if not strategy_pending() and ended_reason=="" and won and not expedition_started and floors.size()==5 and _count_token("K")==0:
		return [["expedition","Continue expedition: 3 more floors / +120 HP once"]]
	return []
func _navigation_state() -> Dictionary:
	return {"floors":floors,"floor_seen":floor_seen,"anchors":travel_anchors,"floor":floor_index,"x":pos.x,"y":pos.y,"water_choice":water_choice,"bridge_built":bridge_built,"expedition_bridge":expedition_bridge,"core_use":core_use,"clue":clue,"seal_clues":seal_clues,"winch_choice":winch_choice,"expedition_revision":expedition_revision,"layout_revision":layout_revision}
func _anchor_id(anchor: Dictionary) -> String:
	return "%d:%d:%d" % [int(anchor.floor),int(anchor.marker_x),int(anchor.marker_y)]
func _register_anchor(token: String):
	if not token in Navigation.ANCHORS: return
	for direction in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var marker: Vector2i=pos+direction
		if tile(marker)!=token: continue
		var record={"floor":floor_index,"x":pos.x,"y":pos.y,"marker_x":marker.x,"marker_y":marker.y,"token":token}
		for known in travel_anchors:
			if _anchor_id(known)==_anchor_id(record): return
		if travel_anchors.size()<64 and Navigation.anchor_valid(_navigation_state(),record): travel_anchors.append(record)
		return
func travel_available() -> bool:
	return not strategy_pending() and ended_reason=="" and generation_valid and expedition_started and not won
func travel_options() -> Array:
	var options: Array=[]
	if not travel_available(): return options
	var names={"J":"Ilen's workshop","N":"Watch inscription","F":"Old forge","M":"Merchant","U":"Expedition camp","Y":"Roadworks","E":"The old elevator","O":"Waterworks"}
	var state:=_navigation_state()
	for anchor in travel_anchors:
		var proof:=Navigation.route(state,anchor)
		var available: bool=proof.ok and int(proof.steps)>0
		options.append({"id":_anchor_id(anchor),"name":names.get(anchor.token,anchor.token),"floor":int(anchor.floor),"reachable":available,"steps":int(proof.steps),"reason":"Already at this anchor" if proof.ok and int(proof.steps)==0 else str(proof.reason)})
	return options
func winch_offers() -> Array:
	if won or expedition_revision!=3 or not nearby("v") or winch_choice!="": return []
	var offers: Array=[]
	if rescue_state<2 and floors[6][2][9]=="W":
		offers.append(["winch_rescue","Open north gate: rescue Mira without fighting W / siege maul permanently lost"])
	offers.append(["winch_armory","Open armory: claim siege maul / rescue Mira by fighting W later" if floors[6][2][9]=="W" and rescue_state<2 else "Open the siege maul armory."])
	return offers
func winch_journal() -> Array:
	if winch_choice=="rescue": return ["The north gate is open. Mira can leave without fighting W; the siege maul is sealed away forever."]
	if winch_choice=="armory": return ["The armory gate is open. The north shortcut is sealed; defeat W to rescue Mira." if floors[6][2][9]=="W" and rescue_state<2 else "Siege maul armory: open"]
	return []
func audit_lines() -> Array:
	if not audit_read: return []
	var lines:=AuditPuzzle.lines(audit_puzzle)
	if audit_solved: lines.append_array(AuditPuzzle.explanation(audit_puzzle))
	return lines
func audit_offers() -> Array:
	if won or not expedition_started or not nearby("Y") or audit_reward!="": return []
	if not audit_read: return [["audit_read","Inspect Ilen's three supply labels: a deduction, not a gamble"]]
	if not audit_solved:
		return [["audit_guess_0","Choose box A"],["audit_guess_1","Choose box B"],["audit_guess_2","Choose box C"]]
	return [["audit_retrain","Retrain chosen talents once: clear choices, keep kills; no HP or focus refunded"],["audit_medicine","Take ready medicine: +140 HP now; retraining forgone"]]
func audit_journal() -> Array:
	if audit_reward=="retrain": return ["The genuine certificate funded one talent retraining. Choose again at C; medicine is forgone."]
	if audit_reward=="medicine": return ["The genuine certificate bought ready medicine. Talent retraining is forgone."]
	if audit_solved: return ["Supply labels solved. Return to Y for one retraining or +140 HP. Claim before defeating Z."]
	if audit_read: return ["Ilen's supply labels await a solution at Y. Wrong guesses cost no resources."]
	return []
func oath_offers() -> Array:
	if won or not nearby("N"): return []
	if oath_state=="fresh": return [["oath_accept","Watch oath: -10 ATK / cancel ambush / halve each thorn hit. Return here to release; never bind again."]]
	if oath_state=="active": return [["oath_renounce","Release the oath here for free. Its protection and attack penalty end; NEVER bind again."]]
	return []
func oath_journal() -> Array:
	if oath_state=="active": return ["Watch oath active: -10 ATK, no ambush loss, each thorn hit halved down. Return to N to release once, forever."]
	if oath_state=="spent": return ["Watch oath released. No penalty or protection remains. You cannot bind again this run."]
	return []
func npc_offers() -> Array:
	if won or expedition_revision==1: return []
	var offers: Array=[]
	if nearby("J"):
		if rescue_state==0: offers.append(["rescue_accept","Ilen: look for apprentice Mira beyond the old tower"])
		elif rescue_state==2: offers.append(["rescue_repeater","Bring Mira home: receive the repeating crossbow / camp help forgone"])
	if nearby("U") and rescue_state==2:
		offers.append(["rescue_supplies","Let Mira help the camp: +40 gold / +1 medicine stock / +1 focus stock"])
	return offers
func npc_journal() -> Array:
	if expedition_revision==1: return []
	match rescue_state:
		1: return ["Ilen seeks Mira. Search the seventh floor; a dangerous gaoler guards her."]
		2: return ["Mira is safe. Before defeating Z, return to Ilen at J for a repeating crossbow, or U for camp supplies. Choose once."]
		3: return ["Mira returned home to Ilen. The repeating crossbow is yours; camp help is forgone." if rescue_reward=="repeater" else "Mira helps the camp. Extra stock still costs gold; the repeating crossbow is forgone."]
	return []
func camp_offers() -> Array:
	var offers: Array=[]
	if not expedition_started or won: return offers
	if nearby("U"):
		offers.append(["camp_medicine","Medicine: 70 gold / +140 HP now / %d left" % camp_medicine_left])
		offers.append(["camp_focus","Focus: 55 gold / +1 now / %d left" % camp_focus_left])
	if nearby("Y"):
		offers.append(["camp_bridge","Roadworks: 80 gold / open expedition bridges once" if not expedition_bridge else "Expedition bridges are already open"])
	return offers
func _count_token(token: String) -> int:
	var total := 0
	for grid in floors:
		for row in grid:
			for value in row:
				if value==token: total+=1
	return total
func tile(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= 11 or p.y >= 11: return "#"
	return floors[floor_index][p.y][p.x]
func safe_walk_path(target: Vector2i) -> Array[Vector2i]:
	if strategy_pending() or ended_reason!="" or not generation_valid or won: return []
	return Navigation.walk_path(floors[floor_index],pos,target)
func safe_walk_step(next: Vector2i, expected_floor: int, expected_pos: Vector2i) -> bool:
	if strategy_pending() or ended_reason!="" or not generation_valid or won or floor_index!=expected_floor or pos!=expected_pos: return false
	if absi(next.x-pos.x)+absi(next.y-pos.y)!=1 or tile(next)!=".": return false
	pos=next; moves+=1
	message="Safe step. No interaction or resources changed."
	return true
func tooltip_data(point: Vector2i) -> Dictionary:
	var underfoot:=_tile_tooltip_data(point)
	if point!=pos: return underfoot
	var lines:Array[String]=[
		"HP %d / base ATK %d / base DEF %d" % [hp,atk,defense],
		"Equipment: %s" % str(Progression.GEAR[equipped].name),
		str(Progression.GEAR[equipped].description),
		"Focus: %d / %d" % [focus,focus_cap],
		skill_description()
	]
	var tuning:=gear_attunement()
	var level_info:=skill_level_info()
	lines.append("Attunement: %s" % ("Original equipment" if tuning=="none" else str(Attunement.TEMPLATES[tuning].name)))
	if tuning!="none": lines.append(str(Attunement.TEMPLATES[tuning].description))
	lines.append("Skill level %d = base %d + training %d + equipment %d + strategy %d + legacy %d (raw %d; overflow %d)" % [level_info.effective,level_info.base,level_info.training,level_info.gear,level_info.strategy,level_info.legacy,level_info.raw,level_info.overflow])
	if current_strategy()!="none":
		lines.append("Run strategy: %s" % str(Strategy.TEMPLATES[current_strategy()].name))
		lines.append(str(Strategy.TEMPLATES[current_strategy()].description))
	if hero_id!="scholar": lines.append("Next-battle skill: armed" if skill_armed else "Next-battle skill: off")
	lines.append("Standing on: %s" % str(underfoot.title))
	for fact in underfoot.lines: lines.append(str(fact))
	return {"title":str(Progression.HEROES[hero_id].name),"lines":lines}
func _tile_tooltip_data(point: Vector2i) -> Dictionary:
	if point.x<0 or point.x>=11 or point.y<0 or point.y>=11: return {"title":"Outside the tower","lines":[]}
	var token:=tile(point)
	var lines:Array[String]=[]
	if ENEMIES.has(token):
		var enemy:Dictionary=ENEMIES[token]
		lines.append("HP %d / ATK %d / DEF %d / Gold %d" % [enemy.hp,enemy.atk,enemy.def,enemy.gold])
		var forecast:=battle_preview(token,"",point)
		if forecast.valid and not forecast.survivable:
			lines.append("Damage required to defeat this enemy: %d HP; current HP: %d. This fight cannot be survived." % [int(forecast.damage),hp])
		else:
			lines.append("Predicted loss: %d HP" % int(forecast.damage) if forecast.valid else str(forecast.reason))
		if forecast.valid:
			lines.append(victory_reward_text(forecast))
		if forecast.valid and not forecast.survivable: lines.append("Lethal battle is blocked. Grow stronger and return." if mode=="safe" else "Risk mode: ordinary movement refuses this lethal battle. A separate confirmed attempt can end this run in death.")
		if enemy.get("first_strike",false): lines.append("First strike: one opening attack, even against a killing hit.")
		if int(enemy.get("thorns",0))>0:
			lines.append("Thorns: %d damage per real hit, including the final hit." % int(enemy.thorns))
			if mode=="risk": lines.append("Risk combat: contact thorns resolve before your hit. A fatal contact stops that attack.")
		if int(enemy.get("heavy_every",0))>0: lines.append("Every third retaliation adds one extra hit.")
		if forecast.get("first_strike_suppression","")=="flank": lines.append("Current position cancels this enemy's first strike.")
		elif forecast.get("first_strike_suppression","")=="oath": lines.append("The active Watch oath cancels this enemy's first strike.")
		lines.append("Fight only by a deliberate adjacent move. Click walking never fights.")
		return {"title":str(enemy.name),"lines":lines}
	var titles={"c":"Freight chute","#":"Wall",".":"Cleared floor","k":"Gold key","h":"Spring water","a":"Ruby of resolve","d":"Sapphire ward","D":"Locked door","L":"Double lock","$":"Sealed treasury","A":"Sealed edge","P":"Sealed provisions","T":"Star vault","C":"Ancient core","M":"Merchant","J":"Ilen's workshop","N":"Watch inscription","E":"The old elevator","F":"Old forge","Q":"Old-tower calibration","I":"Survey sample","O":"Waterworks","R":"Flooded relic chest","X":event_title(),"U":"Expedition camp","Y":"Roadworks","v":"One-use winch","n":"North rescue gate","e":"Armory gate","m":"Siege maul","t":"Mira","~":"Flooded ground","=":"Expedition bridge","<":"Downstairs",">":"Upstairs"}
	if cargo.version==1 and ((floor_index==0 and point in [Cargo.source_door(),Cargo.source_box()]) or (floor_index==Cargo.destination_floor(cargo) and point==Cargo.destination_point(cargo))):
		lines.append(cargo_description())
	match token:
		".": lines.append("Click to walk through cleared floor only. Nothing is picked up or activated.")
		"#": lines.append("Impassable wall.")
		"k": lines.append("Pick up 1 gold key by a deliberate adjacent move.")
		"h": lines.append("Recover 70 HP when picked up.")
		"a": lines.append("Gain 5 ATK when picked up.")
		"d": lines.append("Gain 4 DEF when picked up.")
		"D": lines.append("Costs 1 gold key. Open manually; click walking never spends keys.")
		"L": lines.append("Costs 2 gold keys. Other reward cages compete for the same keys.")
		"$": lines.append("Reward: 60 gold. Overdue debt is paid before spare gold remains.")
		"A": lines.append("Reward: 5 ATK.")
		"P": lines.append("Reward: 140 HP and 1 focus, up to capacity.")
		"T": lines.append("Reward: 10 ATK and 45 gold. Guarded treasure can be revisited.")
		"C": lines.append("One core: repair the lift and power calibration, forge +8 DEF, or sell for 35 gold.")
		"M": lines.append("Piercer costs 60 gold for +12 ATK. Borrowing is a separate explicit choice.")
		"J": lines.append("Ilen handles the survey and Mira's return. Talk manually; no automatic hand-in.")
		"N": lines.append("Read a calibration clue here. The optional Watch oath is a separate choice.")
		"E": lines.append("The lift works only after repairing it with the core. It connects floors 1 and 3.")
		"F": lines.append("Forge the core for +8 DEF, or use the survey to build the old flood bridge.")
		"Q": lines.append("Calibration requires three read clues and the repaired lift. Inspect to reason from your clues.")
		"I": lines.append("Bring the sample to J for gold or focus training, or to F for a flood bridge.")
		"O": lines.append("Drain the water to reach the relic, or take +120 HP. A survey bridge can preserve both routes.")
		"R": lines.append("Choose one relic: heavy buckler or duelist gear. The other choice is lost.")
		"X":
			for offer in event_offers(): lines.append(str(offer[1]))
		"U":
			lines.append("Medicine: 70 gold for +140 HP / %d left." % camp_medicine_left)
			lines.append("Focus: 55 gold for +1 / %d left. Full focus never consumes stock." % camp_focus_left)
		"Y": lines.append("80 gold opens expedition bridges once. Supply-label deduction is a separate optional task.")
		"v":
			if winch_choice!="":
				for fact in winch_journal():lines.append(str(fact))
			elif rescue_state>=2 or floors[6][2][9]!="W":
				lines.append("The rescue no longer needs a shortcut. The unused winch can still open the siege maul armory.")
			else:lines.append("The unused winch can open either the rescue shortcut or the siege maul armory, not both. Inspect the routes before choosing.")
		"n": lines.append("Open" if winch_choice=="rescue" else "Closed")
		"e": lines.append("Open" if winch_choice=="armory" else "Closed")
		"m": lines.append(Progression.GEAR.maul.description)
		"t": lines.append("Step onto Mira to rescue her. Choose her future at J or U before defeating Z.")
		"~": lines.append("Passable only after draining at O or building the survey bridge at F. Click walking does not cross water.")
		"=": lines.append("Passable after paying for roadworks at Y. Click walking does not cross bridges.")
		"<",">":
			lines.append("Use a deliberate adjacent move to change floors. Click walking never uses stairs.")
			var landing:=Layout.stair_destination(floors,layout_revision,floor_index,point)
			if landing.ok: lines.append("Destination: floor %d, tile (%d,%d)." % [int(landing.floor)+1,landing.pos.x,landing.pos.y])
			else: lines.append("No valid stair connection.")
	if token in ["D","L"]:
		var room:=Layout.door_info(floor_index,point,layout_revision)
		if not room.is_empty():
			var contents:=tile(room.reward_pos)
			if contents==room.reward_token: lines.append("Sealed room reward: %s." % str(room.label))
			elif contents==".": lines.append("The room's reward has already been collected.")
			else: lines.append("The room's contents have changed. Inspect before opening.")
		elif token=="D" and layout_revision==1:
			lines.append("Legacy shortcut: this old layout may have another way around.")
	var title:=str(titles.get(token,"Unknown tile"))
	if token=="h" and cargo.version==1 and floor_index==0 and point==Cargo.source_box():title="Sealed medical supply"
	return {"title":title,"lines":lines}
func flank_position(target: Vector2i) -> Vector2i:
	if expedition_revision!=3 or floor_index<5 or floor_index>7 or tile(target)!="H": return Vector2i(-1,-1)
	var candidate:=target+Layout.direction(floor_index,Vector2i.RIGHT,layout_revision)
	return candidate if Expedition.flanking_position(floors.slice(5),floor_index-5,target,candidate,layout_revision) else Vector2i(-1,-1)
func battle_preview(kind: String, equipment_override: String = "", target: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	var gear := equipped if equipment_override=="" else equipment_override
	return _battle_preview_with_talents(kind,gear,target,talents,floor_index)
func _battle_preview_with_talents(kind:String,gear:String,target:Vector2i,chosen:Array,target_floor:int) -> Dictionary:
	if not gear in inventory: gear="invalid_unowned"
	var flank:=target_floor==floor_index and expedition_revision==3 and floor_index>=5 and floor_index<=7 and kind=="H" and flank_position(target)==pos
	var enemy:Dictionary=ENEMIES.get(kind,{}).duplicate();enemy.kind=kind
	return Progression.battle(atk,defense,hp,enemy,hero_id,skill_armed and focus>0,gear,chosen,"watch" if oath_state=="active" else "none",flank,gear_attunement(gear),current_strategy(),last_kill_kind,legacy_study())
func battle_timeline(target: Vector2i) -> Dictionary:
	var kind:=tile(target)
	if not ENEMIES.has(kind): return {"valid":false,"reason":"Not an enemy.","events":[]}
	var flank:=expedition_revision==3 and floor_index>=5 and floor_index<=7 and kind=="H" and flank_position(target)==pos
	var enemy:Dictionary=ENEMIES[kind].duplicate();enemy.kind=kind
	return BattleTimeline.simulate(atk,defense,hp,enemy,hero_id,skill_armed and focus>0,equipped,talents,"watch" if oath_state=="active" else "none",flank,gear_attunement(),current_strategy(),last_kill_kind,legacy_study())
func lethal_fight(delta: Vector2i) -> bool:
	# Explicit Session confirmation is separate from ordinary movement.
	if strategy_pending() or mode!="risk" or ended_reason!="" or not generation_valid or won or hp<=0 or moves>=1000000 or absi(delta.x)+absi(delta.y)!=1: return false
	var target:=pos+delta
	var kind:=tile(target)
	if not ENEMIES.has(kind): return false
	var preview:=battle_preview(kind,"",target)
	if not preview.valid or preview.survivable: return false
	var timeline:=battle_timeline(target)
	if not timeline.get("valid",false) or not timeline.get("fatal",false): return false
	death_record={"floor":floor_index,"x":target.x,"y":target.y,"enemy":kind,"start_hp":hp,"skill_armed":skill_armed}
	last_battle=timeline.duplicate(true);last_battle.enemy=kind
	if timeline.skill_consumed:
		focus-=1
		skill_armed=false
	hp=0;ended_reason="death";moves+=1
	message="Defeated. No kill reward or recovery was granted."
	return true
func victory_reward_text(preview: Dictionary) -> String:
	if not preview.get("valid",false) or not preview.get("survivable",false):
		return "No victory rewards: this forecast is lethal or unavailable."
	var available:=maxi(0,focus_cap-focus+(1 if preview.get("skill_consumed",false) else 0))
	var recovered:=mini(available,maxi(0,int(preview.get("focus_after",0))))
	return "Victory loot (after strategy tax, before debt): %d gold / +%d HP / +%d focus" % [int(preview.get("gold_after",0)),int(preview.get("heal_after",0)),recovered]
func damage(kind: String, target: Vector2i = Vector2i(-1,-1)) -> int:
	var preview := battle_preview(kind,"",target)
	return int(preview.damage) if preview.valid else -1
func enter_floor(number: int):
	floor_index=number
	if not floor_seen[number]:
		floor_seen[number]=true
		focus=mini(focus_cap,focus+1)
func step(direction: Vector2i) -> bool:
	if strategy_pending() or ended_reason!="" or not generation_valid or won or absi(direction.x)+absi(direction.y)!=1: return false
	var target := pos + direction
	var t := tile(target)
	if t == "c":
		message=cargo_description()
		return false
	if t == "#": return false
	if t in ["n","e"] and (expedition_revision!=3 or winch_choice!=("rescue" if t=="n" else "armory")):
		message="This winch gate is locked. One mechanism can open only one route."
		return false
	if t == "=" and not expedition_bridge:
		message="Bridge closed. Pay for roadworks at Y, or take the guarded road."
		return false
	if t == "~" and water_choice!="drain" and not bridge_built:
		message="Flooded. Drain at O, or bring the survey to F to preserve the spring."
		return false
	var stair_landing: Dictionary={}
	if t in ["<",">"]:
		stair_landing=Layout.stair_destination(floors,layout_revision,floor_index,target)
		if not stair_landing.ok: return false
	if t in ["D","L"] and keys < (2 if t=="L" else 1):
		message = "Double lock: 2 gold keys required. Reward cages compete for keys." if t=="L" else "Locked. A gold key is needed."
		return false
	if ENEMIES.has(t):
		var forecast := battle_preview(t,"",target)
		var cost := int(forecast.damage)
		if not forecast.valid or cost < 0 or cost >= hp:
			message = "Too dangerous. Find more crystals first."
			return false
		last_battle=forecast.duplicate(true)
		last_battle["enemy"]=t
		hp -= cost
		hp += int(last_battle.heal_after)
		if last_battle.skill_consumed:
			focus-=1
			skill_armed=false
		kills+=1
		gain_gold(int(last_battle.gold_after))
		focus=mini(focus_cap,focus+int(last_battle.focus_after))
		last_kill_kind=t
		message = "%s defeated. -%d HP" % [ENEMIES[t].name, cost]
		if t in ["K","Z"]: won = true
	elif t == "m":
		if expedition_revision!=3 or winch_choice!="armory" or maul_claimed: return false
		maul_claimed=true; inventory.append("maul"); equipped="maul"
		message="Siege maul recovered. Double strikes, double counters, -4 DEF. Compare before fighting."
	elif t == "t":
		if expedition_revision<2 or rescue_state>=2: return false
		rescue_state=2
		message="Mira rescued. Before defeating Z, return to Ilen at J or take her to U. Choose her future once."
	elif t == "$":
		gain_gold(60)
		message="Sealed treasury: +60 gold. Two keys spent, other cages remain."
	elif t == "A":
		atk+=5
		message="Sealed edge: +5 ATK. A key investment in your next battle."
	elif t == "P":
		hp+=140; focus=mini(focus_cap,focus+1)
		message="Sealed provisions: +140 HP / +1 focus up to capacity."
	elif t == "I":
		if quest_state>=2: return false
		quest_state=2
		message="Survey: J offers gold or focus; F can build a bridge preserving the spring."
	elif t == "C":
		core = true
		message = "Core: lift powers calibration; forge +8 DEF or sell 35 forfeits that quest."
	elif t == "T":
		atk += 10
		gain_gold(45)
		message = "Star vault: +10 ATK and 45 gold. Worth returning for!"
	elif t == "N":
		clue = true
		seal_clues |= 4
		message = Riddle.clues(seed_value)[2]
	elif t in ["M","E","F","Q","J","O","R","X","U","Y","v","n","e"]:
		message = "Press E to inspect choices. Nothing is spent until you choose."
	elif t == "k":
		keys += 1
		message = "A gold key. Every door is a decision."
	elif t in ["D","L"]:
		if cargo.version==1 and cargo.state=="waiting" and floor_index==0 and target==Cargo.source_door():cargo.state="opened"
		keys -= 2 if t=="L" else 1
		message = "The seal breaks."
	elif t == "h":
		hp += 70
		message = "Medical supply collected: +70 HP." if cargo.version==1 and floor_index==0 and target==Cargo.source_box() else "Spring water: +70 HP"
	elif t == "a":
		atk += 5
		message = "Ruby of resolve: +5 ATK"
	elif t == "d":
		defense += 4
		message = "Sapphire ward: +4 DEF"
	pos = target
	moves += 1
	if t == ">":
		enter_floor(int(stair_landing.floor))
		if floor_index in [3,4]: settle_checkpoint(floor_index - 2)
		pos = stair_landing.pos
		message = "Floor %d. Debt %d. Interest settles only on first entry to floors 4 / 5." % [floor_index + 1, debt()]
	elif t == "<":
		floor_index = int(stair_landing.floor)
		pos = stair_landing.pos
		message = "Backtracking is wisdom, not defeat."
	elif not t in [".","M","E","F","N","Q","J","O","R","X","U","Y","~","=","v","n","e"]: floors[floor_index][target.y][target.x] = "."
	_register_anchor(t)
	return true
func debt() -> int:
	return principal + fees + interest
func nearby(token: String) -> bool:
	for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if tile(pos+d)==token: return true
	return false
func consume_nearby(token: String):
	for direction in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var target: Vector2i=pos+direction
		if tile(target)==token:
			floors[floor_index][target.y][target.x]="."
			return
func pay(amount: int):
	if amount<=0: return
	var paid := mini(mini(amount, debt()),gold)
	gold -= paid
	var part := mini(paid, fees)
	fees -= part; paid -= part
	part = mini(paid, interest)
	interest -= part; paid -= part
	principal -= paid
	if debt()==0: overdue=false
func gain_gold(amount: int):
	if amount<=0: return
	gold += amount
	if overdue: pay(amount)
func settle_checkpoint(number: int):
	number=clampi(number,0,2)
	if number <= checkpoints: return
	for n in range(checkpoints+1, number+1):
		if principal>0: interest += ceili(principal*0.1)
	checkpoints=number
	if checkpoints>=2 and debt()>0: overdue=true
func riddle_clues() -> Array:
	var all_clues := Riddle.clues(seed_value)
	var read: Array=[]
	for i in range(3):
		if seal_clues & (1<<i): read.append(all_clues[i])
	return read
func riddle_ready() -> bool:
	return seal_clues==7 and core_use=="elevator" and not secret
func riddle_options() -> Array:
	var options: Array=[]
	if not nearby("Q") or not riddle_ready() or seal_solved: return options
	for id in Riddle.SYMBOL_IDS:
		if not id in seal_input: options.append(["secret_ring_"+id,Riddle.SYMBOLS[id]])
	return options
func riddle_input_text() -> String:
	var names: PackedStringArray=[]
	for id in seal_input: names.append(Riddle.SYMBOLS[id])
	return " > ".join(names)
func _read_seal(bit: int):
	seal_clues |= bit
	if bit==4: clue=true
	var index := 0 if bit==1 else (1 if bit==2 else 2)
	message=Riddle.clues(seed_value)[index]

func exploration_goals()->Array:
	return Exploration.goals(self)
func cargo_status()->String:
	if cargo.version==0:return ""
	match cargo.state:
		"waiting":return "Freight status: sealed on floor 1; dispatch is still available."
		"opened":return "Freight status: source opened; the 70 HP supply is still inside." if floors[0][2][9]=="h" else "Freight status: the source supply was collected locally."
		"shipped":return "Freight status: ready for manual collection." if cargo_ready() else "Freight status: dispatched; destination seal is still locked."
	return "Freight status: collected at destination; no further reward."
func cargo_description()->String:
	if cargo.version==0:return ""
	var destination:="Floor 3 freight chute: the Vault Colossus must be defeated." if cargo.destination=="vault" else "Floor 5 cargo beside the calibration stand: defeat the Regent AND continue the expedition before collection."
	return cargo_status()+" "+("Sealed freight: the SAME 70 HP supply, not an extra reward. Open the floor 1 door with 1 key now, or ship it free and collect later. " if cargo.state=="waiting" else "Freight contains only the original 70 HP supply; it is not an extra reward. ")+destination+" Shipping removes the empty source lock. Destination is fixed; this supply can only be collected once. Normal Undo remains available."
func cargo_journal()->Array:
	if cargo.version==0:return []
	return [cargo_status(),"Destination: floor 3 freight chute, after defeating the Vault Colossus." if cargo.destination=="vault" else "Destination: cargo beside the floor 5 calibration stand, after the Regent and expedition continuation."]
func _cargo_near(f:int,p:Vector2i)->bool:
	return floor_index==f and absi(pos.x-p.x)+absi(pos.y-p.y)<=1
func cargo_ready()->bool:
	if cargo.version!=1 or cargo.state!="shipped":return false
	if cargo.destination=="vault":return floors[2][3][8]!="V"
	if not expedition_started:return false
	for row in floors[4]:
		if "K" in row:return false
	return true
func cargo_context()->bool:
	return cargo.version==1 and (_cargo_near(0,Cargo.source_door()) or _cargo_near(Cargo.destination_floor(cargo),Cargo.destination_point(cargo)))
func cargo_offers()->Array:
	if cargo.version!=1 or strategy_pending() or ended_reason!="" or won or not generation_valid:return []
	if cargo.state=="waiting" and _cargo_near(0,Cargo.source_door()):return [["cargo_ship",cargo_description()]]
	if cargo_ready() and _cargo_near(Cargo.destination_floor(cargo),Cargo.destination_point(cargo)):return [["cargo_claim","Collect the shipped supply: +70 HP once. This is the original floor 1 box."]]
	return []
func event_title() -> String:
	return {"bargain":"The tower keeper", "smuggler":"The locked-road smuggler", "oath":"The well of resolve"}[event_kind]
func event_offers() -> Array:
	match event_kind:
		"smuggler": return [["smuggler_sell","Trade 1 gold key for 45 gold / one offer only"],["smuggler_buy","Pay 30 gold for 2 keys / one offer only"],["bargain_leave","Decline this encounter permanently"]]
		"oath": return [["oath_power","Surrender ALL focus (at least 2) for +7 ATK"],["oath_renew","Pay 60 HP to restore 2 focus (up to capacity)"],["bargain_leave","Decline this encounter permanently"]]
	return [["bargain_blood","Blood bargain: pay 80 HP / gain +6 ATK"],["bargain_gold","Ward bargain: pay 25 gold / gain +5 DEF"],["bargain_leave","Decline this encounter permanently"]]
func action(id: String) -> bool:
	if strategy_pending() or ended_reason!="": return false
	if id in ["cargo_ship","cargo_claim"]:
		var allowed:=false
		for offer in cargo_offers():
			if offer[0]==id:allowed=true
		if not allowed:return false
		if id=="cargo_ship":
			cargo.state="shipped";floors[0][2][8]=".";floors[0][2][9]="."
			message="Freight dispatched. The empty source door is removed; the original 70 HP supply awaits its stated destination."
		else:
			cargo.state="claimed";hp+=70
			message="Freight collected: +70 HP. The original supply cannot be collected again."
		moves+=1
		return true
	if id=="legacy_focus":
		if not legacy_focus_available(): return false
		legacy_reserves-=1;focus+=1;moves+=1
		message="Emergency reserve used: +1 focus. One supply consumed."
		return true
	if id.begins_with("fast_travel_"):
		if not travel_available(): return false
		var requested:=id.trim_prefix("fast_travel_")
		for anchor in travel_anchors:
			if _anchor_id(anchor)!=requested: continue
			var proof:=Navigation.route(_navigation_state(),anchor)
			if not proof.ok or int(proof.steps)<=0: return false
			floor_index=int(anchor.floor); pos=Vector2i(int(anchor.x),int(anchor.y)); moves+=1
			message="Safe return: skipped %d cleared steps. No supplies, clues or focus changed." % int(proof.steps)
			return true
		return false
	if id=="expedition":
		if not generation_valid or chapter_offers().is_empty(): return false
		var generated: Dictionary=Expedition.generate(seed_value,layout_revision)
		if not generated.get("solvable",false) or generated.get("maps",[]).size()!=3:
			message="Expedition validation failed. Your first-chapter victory is preserved."
			return false
		floors.append_array(generated.maps.duplicate(true))
		floor_seen.append_array([false,false,false])
		var chapter_exit:=Layout.exit_point(4,layout_revision)
		floors[4][chapter_exit.y][chapter_exit.x]=">"
		expedition_started=true
		expedition_revision=int(generated.get("content_revision",1))
		won=false
		hp+=120
		enter_floor(5)
		pos=Layout.entry(5,layout_revision)
		moves+=1
		message="Expedition begun: +120 HP once. Old floors and all earlier choices remain."
		return true
	if strategy_pending() or ended_reason!="" or not generation_valid or won: return false
	if id.begins_with("attune_"):
		for gear in ATTUNABLE_GEAR:
			var prefix:String="attune_"+gear+"_"
			if not id.begins_with(prefix): continue
			var selected:=id.trim_prefix(prefix)
			if not gear in inventory or gear_choices.has(gear) or not Attunement.valid_selection(gear_offers[gear],selected): return false
			gear_choices[gear]=selected
			moves+=1
			message="Equipment choice locked. Only the worn item's attunement applies. Full-state undo can reverse this choice."
			return true
		return false
	if id.begins_with("audit_guess_"):
		if not expedition_started or not nearby("Y") or not audit_read or audit_solved: return false
		if not id in ["audit_guess_0","audit_guess_1","audit_guess_2"]: return false
		var chosen:=int(id.trim_prefix("audit_guess_"))
		if chosen==int(audit_puzzle.solution):
			audit_solved=true
			message="Certificate found by deduction. Inspect the label explanations, then choose one reward before Z."
		else:
			message="That box does not fit the stated truth count. Reread the labels; no resources were spent."
		_register_anchor("Y")
		moves+=1
		return true
	if id.begins_with("secret_ring_"):
		var symbol := id.trim_prefix("secret_ring_")
		if not nearby("Q") or not riddle_ready() or seal_solved:
			message="Calibration needs all three clues and the repaired lift."
			return false
		if not Riddle.SYMBOLS.has(symbol) or symbol in seal_input:
			message="Use each symbol once. Backspace or clear to change the sequence."
			return false
		seal_input.append(symbol)
		if seal_input.size()==4:
			if Riddle.satisfies_clues(seed_value,seal_input):
				seal_solved=true
				message="Calibration solved. Choose provisions or a fixed 50-gold voucher."
			else:
				seal_input.clear()
				message="The order does not fit the clues. Reset freely; nothing was spent."
		else:
			message="Symbol recorded. No HP, gold, focus or interest was spent."
		moves+=1
		return true
	if id.begins_with("hero_"):
		var choice:=id.trim_prefix("hero_")
		if moves!=0 or not Progression.HEROES.has(choice): return false
		hero_id=choice
		message="%s chosen. Every hero can clear the main route." % Progression.HEROES[choice].name
		moves+=1
		return true
	if id.begins_with("equip_"):
		var choice:=id.trim_prefix("equip_")
		if not choice in inventory or choice==equipped: return false
		equipped=choice
		message="Equipment changed. Scout the new battle forecast."
		moves+=1
		return true
	if id.begins_with("talent_"):
		var choice:=id.trim_prefix("talent_")
		if not choice in talent_options(): return false
		talents.append(choice)
		message="Talent learned: %s" % Progression.TALENTS[choice].name
		moves+=1
		return true
	match id:
		"winch_rescue","winch_armory":
			if expedition_revision!=3 or not nearby("v") or winch_choice!="": return false
			if id=="winch_rescue" and (rescue_state>=2 or floors[6][2][9]!="W"): return false
			winch_choice="rescue" if id=="winch_rescue" else "armory"
			message="North gate opened. Mira can be rescued without W; the siege maul is permanently forgone." if winch_choice=="rescue" else "Armory opened. Claim the siege maul; defeating W remains the way to rescue Mira."
			if winch_choice=="armory" and (rescue_state>=2 or floors[6][2][9]!="W"): message="Siege maul armory: open"
		"audit_read":
			if not expedition_started or not nearby("Y") or audit_read: return false
			audit_read=true
			message="Read all three labels and the truth-count rule. You may reconsider without paying."
		"audit_retrain","audit_medicine":
			if not expedition_started or not nearby("Y") or not audit_solved or audit_reward!="": return false
			if id=="audit_retrain":
				if talents.is_empty():
					message="No chosen talents to retrain. Choose talents at C first, or leave this reward unclaimed."
					return false
				talents.clear(); audit_reward="retrain"
				message="Talents cleared once. Kills remain; no HP, focus or earlier rewards are refunded. Choose again at C."
			else:
				hp+=140; audit_reward="medicine"
				message="Ready medicine: +140 HP. Talent retraining is permanently forgone."
		"oath_accept":
			if not nearby("N") or oath_state!="fresh": return false
			oath_state="active"
			message="Watch oath bound. Some fights become harder. Release only at N; after release, no second oath."
		"oath_renounce":
			if not nearby("N") or oath_state!="active": return false
			oath_state="spent"
			message="Watch oath released for free. No focus restored. You can never bind it again this run."
		"rescue_accept":
			if not nearby("J") or rescue_state!=0 or expedition_revision==1: return false
			rescue_state=1
			message="Ilen asks you to find Mira on the seventh floor. The survey remains a separate choice."
		"rescue_repeater","rescue_supplies":
			if rescue_state!=2 or expedition_revision<2: return false
			if id=="rescue_repeater":
				if not nearby("J"): return false
				rescue_reward="repeater"; inventory.append("repeater"); equipped="repeater"
				message="Mira returns home. Repeating crossbow received; camp help is forgone."
			else:
				if not nearby("U"): return false
				rescue_reward="supplies"; camp_medicine_left+=1; camp_focus_left+=1
				gain_gold(40)
				message="Mira joins the camp: +40 gold, +1 medicine stock and +1 focus stock. Purchases still cost gold."
			rescue_state=3
		"camp_medicine":
			if not expedition_started or not nearby("U") or camp_medicine_left<=0 or gold<70: return false
			gold-=70; hp+=140; camp_medicine_left-=1
			message="Medicine consumed: +140 HP. Stock is shared across the expedition."
		"camp_focus":
			if not expedition_started or not nearby("U") or camp_focus_left<=0 or gold<55 or focus>=focus_cap: return false
			gold-=55; focus+=1; camp_focus_left-=1
			message="Focus restored: +1. Full focus never consumes gold or stock."
		"camp_bridge":
			if not expedition_started or not nearby("Y") or expedition_bridge or gold<80: return false
			gold-=80; expedition_bridge=true
			message="Roadworks complete. Expedition bridges open; guarded roads remain optional."
		"seal_contract":
			if not nearby("M"): return false
			_read_seal(1)
		"seal_water":
			if not nearby("O"): return false
			_read_seal(2)
		"seal_inscription":
			if not nearby("N"): return false
			_read_seal(4)
		"secret_backspace","secret_reset":
			if not nearby("Q") or not riddle_ready() or seal_solved or seal_input.is_empty(): return false
			if id=="secret_backspace": seal_input.pop_back()
			else: seal_input.clear()
			message="Sequence edited. No resources or interest spent."
		"arm":
			if hero_id=="scholar" or focus<=0: return false
			skill_armed=not skill_armed
			message="Next battle skill %s. Preview includes its effect." % ("armed" if skill_armed else "off")
		"mend":
			if hero_id!="scholar" or focus<=0: return false
			focus-=1; hp+=mend_heal()
			message="Focus spent to mend. Charges return only on new floors."
		"quest_accept":
			if not nearby("J") or quest_state!=0: return false
			quest_state=1
			message="Find the floor 3 survey. J: gold or focus. F: bridge, keeping the spring."
		"quest_gold","quest_scroll":
			if not nearby("J") or quest_state!=2: return false
			quest_state=3
			if id=="quest_gold":
				gain_gold(45)
				message="Survey delivered: 45 gold. Focus training and survey bridge forgone."
			else:
				focus_cap=4; focus=4
				message="Survey delivered: focus capacity 4 and refill. Gold and bridge forgone."
		"quest_bridge":
			if not nearby("F") or quest_state!=2 or bridge_built or water_choice=="drain": return false
			quest_state=4; bridge_built=true
			message="Survey spent: flood bridge built on floor 2. Spring preserved; J rewards forgone."
		"drain","spring":
			if not nearby("O") or water_choice!="" or (id=="drain" and bridge_built): return false
			water_choice=id
			if id=="spring": hp+=120
			message="Water drained: north relic vault accessible; healing forgone." if id=="drain" else ("Spring consumed: +120 HP. The bridge keeps the relic route open." if bridge_built else ("Spring consumed: +120 HP. Survey spent at J: no bridge remains." if quest_state==3 else "Spring consumed: +120 HP. A survey bridge can still open the route."))
		"relic_buckler","relic_duelist":
			if not nearby("R") or chest_claimed: return false
			var choice:=id.trim_prefix("relic_")
			chest_claimed=true; inventory.append(choice); equipped=choice
			consume_nearby("R")
			message="Relic chosen: %s. The other relic is sealed away." % Progression.GEAR[choice].name
		"smuggler_sell","smuggler_buy":
			if not nearby("X") or event_done or event_kind!="smuggler": return false
			if id=="smuggler_sell":
				if keys<1: return false
				keys-=1; gain_gold(45)
			else:
				if gold<30: return false
				gold-=30; keys+=2
			event_done=true
			message="The smuggler departs. The other offer is gone."
		"oath_power","oath_renew":
			if not nearby("X") or event_done or event_kind!="oath": return false
			if id=="oath_power":
				if focus<2: return false
				focus=0; skill_armed=false; atk+=7
			else:
				if hp<=60 or focus>=focus_cap: return false
				hp-=60; focus=mini(focus_cap,focus+2)
			event_done=true
			message="The well falls silent. Your exchange cannot be repeated."
		"bargain_blood","bargain_gold","bargain_leave":
			if not nearby("X") or event_done: return false
			if id!="bargain_leave" and event_kind!="bargain": return false
			if id=="bargain_blood":
				if hp<=80: return false
				hp-=80; atk+=6
			elif id=="bargain_gold":
				if gold<25: return false
				gold-=25; defense+=5
			event_done=true
			message="The keeper accepts your choice. This offer will not return."
		"borrow":
			if not nearby("M") or loan_used or checkpoints>0: return false
			principal=40; fees=2; loan_used=true; gold+=40
			message="Borrowed 40. Fee 2; max 50 due at floor 5. No real money."
		"repay":
			if gold<=0 or debt()==0: return false
			pay(gold)
			message="Payment applied: fee, interest, then principal. Debt %d." % debt()
		"buy":
			if not nearby("M") or weapon or gold<60: return false
			gold-=60; atk+=12; weapon=true
			message="Piercer purchased: +12 ATK. No resale."
		"sell_core":
			if not nearby("M") or not core: return false
			core=false; core_use="sold"; gain_gold(35)
			message="Core sold. Lift, forge and old-tower calibration are forgone."
		"elevator":
			if not nearby("E") or not core: return false
			core=false; core_use="elevator"
			message="Lift repaired. Calibration is powered; forge and sale forgone."
		"forge":
			if not nearby("F") or not core: return false
			core=false; core_use="forge"; defense+=8
			message="Core forged: +8 DEF. Lift, sale and old-tower calibration are forgone."
		"travel":
			if not nearby("E") or core_use!="elevator": return false
			_register_anchor("E")
			enter_floor(2 if floor_index==0 else 0)
			pos=Vector2i(4,1) if floor_index==2 else Vector2i(2,5)
			message="The old lift remembers. No interest on revisits."
		"secret","secret_provisions","secret_voucher":
			if not nearby("Q") or not riddle_ready() or not seal_solved: return false
			secret=true
			seal_reward="voucher" if id=="secret_voucher" else "provisions"
			if seal_reward=="provisions":
				hp+=80; keys+=1
				message="Calibration provisions: +80 HP / +1 key. Voucher forgone."
			else:
				var cleared := mini(50,debt())
				# Credit is consumed by debt before its remainder becomes cash.
				# pay() keeps the normal fee/interest/principal order; no existing
				# player gold is spent, and loan/checkpoint history is preserved.
				gold+=cleared
				pay(cleared)
				gain_gold(50-cleared)
				message="Calibration voucher: %d debt cleared / %d gold received." % [cleared,50-cleared]
			consume_nearby("Q")
		_: return false
	var interaction_anchor={"audit_read":"Y","audit_retrain":"Y","audit_medicine":"Y","borrow":"M","buy":"M","sell_core":"M","seal_contract":"M","quest_accept":"J","quest_gold":"J","quest_scroll":"J","rescue_accept":"J","rescue_repeater":"J","forge":"F","quest_bridge":"F","seal_inscription":"N","oath_accept":"N","oath_renounce":"N","elevator":"E","travel":"E","camp_medicine":"U","camp_focus":"U","rescue_supplies":"U","camp_bridge":"Y"}
	if interaction_anchor.has(id): _register_anchor(interaction_anchor[id])
	moves+=1
	return true
func save_data() -> Dictionary:
	return {"version":18,"cargo":cargo.duplicate(true),"legacy_points":legacy_points.duplicate(true),"legacy_reserves":legacy_reserves,"talent_draft":talent_draft.duplicate(true),"last_kill_kind":last_kill_kind,"draft":draft.duplicate(true),"death_record":death_record.duplicate(true),"run_id":run_id,"mode":mode,"ended_reason":ended_reason,"attunement_version":attunement_version,"gear_offers":gear_offers.duplicate(true),"gear_choices":gear_choices.duplicate(true),"layout_revision":layout_revision,"winch_choice":winch_choice,"maul_claimed":maul_claimed,"audit_puzzle":audit_puzzle,"audit_read":audit_read,"audit_solved":audit_solved,"audit_reward":audit_reward,"travel_anchors":travel_anchors,"oath_state":oath_state,"expedition_revision":expedition_revision,"rescue_state":rescue_state,"rescue_reward":rescue_reward,"expedition_started":expedition_started,"expedition_bridge":expedition_bridge,"camp_medicine_left":camp_medicine_left,"camp_focus_left":camp_focus_left,"seal_version":Riddle.VERSION,"seal_clues":seal_clues,"seal_input":seal_input,"seal_solved":seal_solved,"seal_reward":seal_reward,"floors":floors,"floor":floor_index,"x":pos.x,"y":pos.y,"hp":hp,"atk":atk,"def":defense,"keys":keys,"gold":gold,"won":won,"moves":moves,
	"seed_value":seed_value,"generation_attempts":generation_attempts,"generation_fallback":generation_fallback,
	"hero_id":hero_id,"focus":focus,"focus_cap":focus_cap,"skill_armed":skill_armed,"equipped":equipped,"inventory":inventory,"talents":talents,"kills":kills,"floor_seen":floor_seen,
	"quest_state":quest_state,"bridge_built":bridge_built,"event_done":event_done,"event_kind":event_kind,"water_choice":water_choice,"chest_claimed":chest_claimed,
	"core":core,"core_use":core_use,"weapon":weapon,"secret":secret,"clue":clue,"principal":principal,"fees":fees,"interest":interest,"loan_used":loan_used,"overdue":overdue,"checkpoints":checkpoints}
func restore(d: Dictionary) -> bool:
	var save_version = d.get("version")
	if not (save_version is int or save_version is float): return false
	if not is_finite(float(save_version)) or (save_version!=4 and save_version!=5 and save_version!=6 and save_version!=7 and save_version!=8 and save_version!=9 and save_version!=10 and save_version!=11 and save_version!=12 and save_version!=13 and save_version!=14 and save_version!=15 and save_version!=16 and save_version!=17 and save_version!=18): return false
	if save_version>=14:
		if not d.get("death_record") is Dictionary or not d.get("ended_reason") is String: return false
		if d.get("ended_reason")=="death": return _restore_death(d)
		if not d.death_record.is_empty(): return false
	var saved_draft:Dictionary={"version":0,"pool":[],"offers":[],"choice":"none"}
	if save_version>=15:
		if not Strategy.valid_draft(d.get("seed_value"),d.get("draft")): return false
		saved_draft=d.draft.duplicate(true)
		saved_draft.version=int(saved_draft.version)
		if saved_draft.choice=="":
			if not (d.get("moves") is int or d.get("moves") is float) or not d.get("won") is bool: return false
			if d.moves!=0 or d.ended_reason!="" or d.won: return false
	var saved_talent_draft:Dictionary=Progression.talent_draft(0,0)
	var saved_last_kill:=""
	if save_version>=16:
		if not Progression.valid_talent_draft(d.get("seed_value"),d.get("talent_draft")): return false
		if not d.get("last_kill_kind") is String or (d.last_kill_kind!="" and not ENEMIES.has(d.last_kill_kind)): return false
		saved_talent_draft=d.talent_draft.duplicate(true);saved_talent_draft.version=int(saved_talent_draft.version)
		saved_last_kill=d.last_kill_kind
	var saved_points:Dictionary=LegacyPoints.legacy()
	var saved_reserves:=0
	if save_version>=17:
		if not LegacyPoints.valid_record(d.get("legacy_points"),d.get("legacy_reserves"),saved_draft.pool,saved_draft.choice==""): return false
		saved_points={}
		for key in ["version","capacity","study","reserve"]: saved_points[key]=int(d.legacy_points[key])
		saved_reserves=int(d.legacy_reserves)
	var saved_run_id := ""
	var saved_mode := "safe"
	var saved_end := ""
	if save_version>=13:
		if not valid_run_id(d.get("run_id")) or not d.get("mode") in ["safe","risk"] or not d.get("ended_reason") in ["","retired","victory"]: return false
		saved_run_id=d.run_id; saved_mode=d.mode; saved_end=d.ended_reason
	var saved_layout := 1
	if save_version>=11:
		var revision=d.get("layout_revision")
		if not (revision is int or revision is float) or not is_finite(float(revision)) or (revision!=1 and revision!=2): return false
		saved_layout=int(revision)
	var saved_cargo:Dictionary=Cargo.legacy()
	if save_version>=18:
		if not Cargo.valid_record(d.get("cargo"),d.get("seed_value"),saved_layout):return false
		saved_cargo=d.cargo.duplicate(true);saved_cargo.version=int(saved_cargo.version)
	var old_seal: bool = save_version==4
	var saved_winch := ""
	var saved_maul := false
	if save_version>=10:
		if not d.get("winch_choice") in ["","rescue","armory"] or not d.get("maul_claimed") is bool: return false
		saved_winch=d.winch_choice; saved_maul=d.maul_claimed
		if saved_maul and saved_winch!="armory": return false
	var saved_oath := "fresh"
	if save_version>=8:
		if not d.get("oath_state") in ["fresh","active","spent"]: return false
		saved_oath=d.oath_state
	var saved_expedition := false
	var saved_bridge := false
	var saved_medicine := 2
	var saved_focus_stock := 2
	if save_version>=6:
		if not d.get("expedition_started") is bool or not d.get("expedition_bridge") is bool: return false
		saved_expedition=d.expedition_started; saved_bridge=d.expedition_bridge
		for key in ["camp_medicine_left","camp_focus_left"]:
			if not (d.get(key) is int or d.get(key) is float): return false
			if not is_finite(float(d[key])) or d[key]!=floor(d[key]) or d[key]<0 or d[key]>(3 if save_version>=7 and d.get("rescue_reward")=="supplies" else 2): return false
		saved_medicine=int(d.camp_medicine_left); saved_focus_stock=int(d.camp_focus_left)
		if not saved_expedition and (saved_bridge or saved_medicine!=2 or saved_focus_stock!=2): return false
	var saved_revision := 1 if saved_expedition else 0
	var saved_rescue := 0
	var saved_reward := ""
	if save_version>=7:
		for key in ["expedition_revision","rescue_state"]:
			if not (d.get(key) is int or d.get(key) is float): return false
			if not is_finite(float(d[key])) or d[key]!=floor(d[key]): return false
		saved_revision=int(d.expedition_revision); saved_rescue=int(d.rescue_state)
		if saved_revision<0 or saved_revision>(3 if save_version>=10 else 2) or saved_rescue<0 or saved_rescue>3: return false
		if not d.get("rescue_reward") in ["","repeater","supplies"]: return false
		saved_reward=d.rescue_reward
		if saved_expedition!=(saved_revision>0): return false
		if saved_revision==1 and saved_rescue!=0: return false
		if saved_rescue>=2 and saved_revision<2: return false
		if (saved_rescue==3)!=(saved_reward!=""): return false
	if saved_revision!=3 and (saved_winch!="" or saved_maul): return false
	var expected_floors := 8 if saved_expedition else 5
	if not d.get("bridge_built",false) is bool: return false
	if d.get("bridge_built",false)!=(d.get("quest_state")==4): return false
	if d.get("bridge_built",false) and d.get("water_choice")=="drain": return false
	for key in ["floor","x","y","hp","atk","def","keys","gold","moves","principal","fees","interest","checkpoints","generation_attempts","focus","focus_cap","kills","quest_state"]:
		if not d.has(key) or not (d[key] is float or d[key] is int): return false
		if not is_finite(float(d[key])) or float(d[key])!=floor(float(d[key])) or d[key]<0 or d[key]>1000000: return false
	for key in ["core","weapon","secret","clue","loan_used","overdue","won","generation_fallback","skill_armed","event_done","chest_claimed"]:
		if not d.get(key) is bool: return false
	if not (d.get("seed_value") is int or d.get("seed_value") is float): return false
	if not is_finite(float(d.seed_value)) or d.seed_value<0 or d.seed_value>2147483647 or d.seed_value!=floor(d.seed_value): return false
	if d.get("event_kind") != ["bargain","smuggler","oath"][int(d.seed_value)%3]: return false
	if not d.get("hero_id") is String or not Progression.HEROES.has(d.hero_id): return false
	if not d.get("equipped") is String or not Progression.GEAR.has(d.equipped): return false
	if not d.get("inventory") is Array or d.inventory.size()<1 or d.inventory.size()>4: return false
	var unique_gear: Dictionary={}
	for gear in d.inventory:
		if not gear is String or not Progression.GEAR.has(gear) or unique_gear.has(gear): return false
		unique_gear[gear]=true
	if not "balanced" in d.inventory or not d.equipped in d.inventory: return false
	var relic_count := int("buckler" in d.inventory)+int("duelist" in d.inventory)
	if relic_count>1 or d.chest_claimed!=(relic_count==1): return false
	if ("repeater" in d.inventory)!=(saved_reward=="repeater"): return false
	if ("maul" in d.inventory)!=saved_maul: return false
	var saved_gear_offers:Dictionary={}
	var saved_gear_choices:Dictionary={}
	if save_version>=12:
		if not (d.get("attunement_version") is int or d.get("attunement_version") is float) or d.attunement_version!=Attunement.REVISION: return false
		if not d.get("gear_offers") is Dictionary or d.gear_offers.size()!=ATTUNABLE_GEAR.size(): return false
		for gear in ATTUNABLE_GEAR:
			if not Attunement.valid_offers(d.gear_offers.get(gear)): return false
			# Keep the actual persisted selection/order, not a seed regeneration.
			saved_gear_offers[gear]=d.gear_offers[gear].duplicate()
		if not d.get("gear_choices") is Dictionary or d.gear_choices.size()>ATTUNABLE_GEAR.size(): return false
		for gear in d.gear_choices:
			if not gear is String or not gear in ATTUNABLE_GEAR or not gear in d.inventory: return false
			if not Attunement.valid_selection(saved_gear_offers[gear],d.gear_choices[gear]): return false
			saved_gear_choices[gear]=d.gear_choices[gear]
	else:
		saved_gear_offers=_new_gear_offers(int(d.seed_value))
	if not d.get("talents") is Array or not Progression.valid_talents(d.talents): return false
	for tier in range(d.talents.size()):
		if not d.talents[tier] in saved_talent_draft.offers[tier]: return false
	if d.kills==0 and saved_last_kill!="": return false
	if d.talents.size()>0 and d.kills<3: return false
	if d.talents.size()>1 and d.kills<7: return false
	if d.talents.size()>2 and d.kills<12: return false
	if not d.get("floor_seen") is Array or d.floor_seen.size()!=expected_floors: return false
	for seen in d.floor_seen:
		if not seen is bool: return false
	if not d.floor_seen[0]: return false
	if save_version>=13:
		var unseen:=false
		for seen in d.floor_seen:
			if seen and unseen: return false
			if not seen: unseen=true

	if not d.get("water_choice") in ["","drain","spring"]: return false
	if int(d.focus_cap) not in [3,4] or d.focus>d.focus_cap or d.quest_state>4: return false
	if d.hero_id=="scholar" and d.skill_armed: return false
	if d.generation_attempts>16: return false
	if not d.get("core_use") in ["","sold","forge","elevator"]: return false
	if d.core and d.core_use!="": return false
	if d.principal>40 or d.fees>2 or d.interest>8 or d.checkpoints>2: return false
	var balance: int = int(d.principal+d.fees+d.interest)
	if not d.loan_used and balance>0: return false
	if d.overdue != (d.checkpoints==2 and balance>0): return false
	if d.secret and (not d.clue or d.core_use!="elevator"): return false
	var saved_seal_clues := 7 if old_seal and d.secret else 0
	var saved_seal_input: Array = Riddle.solution(int(d.seed_value)) if old_seal and d.secret else []
	var saved_seal_solved: bool = old_seal and d.secret
	var saved_seal_reward := "legacy" if old_seal and d.secret else ""
	if not old_seal:
		if not (d.get("seal_version") is int or d.get("seal_version") is float) or d.seal_version!=Riddle.VERSION: return false
		if not (d.get("seal_clues") is int or d.get("seal_clues") is float): return false
		if not is_finite(float(d.seal_clues)) or d.seal_clues!=floor(d.seal_clues) or d.seal_clues<0 or d.seal_clues>7: return false
		if not d.get("seal_input") is Array or not Riddle.valid_input(d.seal_input): return false
		if not d.get("seal_solved") is bool or not d.get("seal_reward") in ["","provisions","voucher","legacy"]: return false
		saved_seal_clues=int(d.seal_clues); saved_seal_input=d.seal_input.duplicate()
		saved_seal_solved=d.seal_solved; saved_seal_reward=d.seal_reward
		if d.secret!=(saved_seal_reward!=""): return false
		if saved_seal_reward=="voucher" and balance!=0: return false
		if saved_seal_clues & 4 and not d.clue: return false
		if saved_seal_solved:
			if saved_seal_clues!=7 or d.core_use!="elevator" or saved_seal_input!=Riddle.solution(int(d.seed_value)): return false
		elif saved_seal_input.size()>3 or d.secret: return false
		if not saved_seal_input.is_empty() and (saved_seal_clues!=7 or d.core_use!="elevator"): return false
	if not d.get("floors") is Array or d.floors.size()!=expected_floors: return false
	var cores_remaining := 0
	var seals_remaining := 0
	var first_boss_remaining := 0
	var last_boss_remaining := 0
	var apprentices := 0
	var gaolers := 0
	var machinery: Dictionary={"v":0,"n":0,"e":0,"m":0}
	for grid in d.floors:
		if not grid is Array or grid.size()!=11: return false
		for row in grid:
			if not row is Array or row.size()!=11: return false
			for c in row:
				if c=="C": cores_remaining+=1
				if c=="Q": seals_remaining+=1
				if c=="K": first_boss_remaining+=1
				if c=="Z": last_boss_remaining+=1
				if c=="t": apprentices+=1
				if c=="W": gaolers+=1
				if c in machinery:
					if saved_revision!=3: return false
					machinery[c]+=1
				if not saved_expedition and c in ["U","Y","=","Z","H","t","W","v","n","e","m"]: return false
				if not c is String or not c in ["#",".","k","D","L","$","A","P","h","a","d","s","g","u","b","w","B","K","V","T","M","C","E","F","N","Q","J","I","O","R","X","~","<",">","U","Y","=","Z","H","t","W","v","n","e","m","c"]: return false
	if not Cargo.valid_maps(d.floors,saved_cargo,saved_expedition):return false
	if cores_remaining>1 or (cores_remaining>0 and (d.core or d.core_use!="")): return false
	if old_seal and d.secret:
		if seals_remaining>1: return false
	elif seals_remaining!=(0 if d.secret else 1): return false
	if saved_revision>=2:
		if apprentices!=(1 if saved_rescue<2 else 0) or gaolers>1: return false
		if saved_rescue>=2 and gaolers!=0 and not (saved_revision==3 and saved_winch=="rescue"): return false
		if d.floors[6][1][8]!=("n" if saved_revision==3 else "#") or d.floors[6][1][9]!=("t" if saved_rescue<2 else "."): return false
		if not d.floors[6][2][9] in ["W","."]: return false
	elif apprentices!=0 or gaolers!=0: return false
	if saved_revision==3:
		if machinery.v!=1 or machinery.n!=1 or machinery.e!=1 or machinery.m!=(0 if saved_maul else 1): return false
		if d.floors[6][4][7]!="v" or d.floors[6][4][8]!="e" or d.floors[6][4][9]!=("." if saved_maul else "m"): return false
		if d.floors[6][3][9]!="#" or d.floors[6][5][9]!="#" or d.floors[6][6][8]!=".": return false
	if saved_expedition:
		if first_boss_remaining!=0 or last_boss_remaining!=(0 if d.won else 1): return false
		if not d.floor_seen[5] or Layout.tile(d.floors,4,Layout.exit_point(4,saved_layout))!=">": return false
		if Layout.tile(d.floors,5,Layout.point(5,Vector2i(2,2),saved_layout))!="U" or Layout.tile(d.floors,5,Layout.point(5,Vector2i(2,3),saved_layout))!="Y": return false
		if Layout.tile(d.floors,7,Layout.point(7,Vector2i(8,3),saved_layout))!=("." if d.won else "Z"): return false
		for f in range(5,8):
			if Layout.tile(d.floors,f,Layout.entry(f,saved_layout))!="<" or Layout.tile(d.floors,f,Layout.point(f,Vector2i(5,3),saved_layout))!="=": return false
			if f<7 and Layout.tile(d.floors,f,Layout.exit_point(f,saved_layout))!=">": return false
	elif last_boss_remaining!=0: return false
	if saved_layout==2:
		for f in range(d.floors.size()):
			for y in range(11):
				for x in range(11):
					if d.floors[f][y][x] in ["<",">"] and not Layout.stair_destination(d.floors,saved_layout,f,Vector2i(x,y)).ok: return false
	var saved_puzzle: Dictionary=AuditPuzzle.generate(int(d.seed_value))
	var saved_audit_read := false
	var saved_audit_solved := false
	var saved_audit_reward := ""
	if save_version>=9:
		if not AuditPuzzle.valid(d.get("audit_puzzle")): return false
		if not d.get("audit_read") is bool or not d.get("audit_solved") is bool: return false
		if not d.get("audit_reward") in ["","retrain","medicine"]: return false
		saved_puzzle=AuditPuzzle.canonical(d.audit_puzzle)
		saved_audit_read=d.audit_read; saved_audit_solved=d.audit_solved; saved_audit_reward=d.audit_reward
		if saved_audit_read and not saved_expedition: return false
		if saved_audit_solved and not saved_audit_read: return false
		if saved_audit_reward!="" and not saved_audit_solved: return false
		if saved_audit_reward=="retrain" and d.kills<3: return false
	var saved_anchors: Array=[]
	if save_version>=9:
		if not d.get("travel_anchors") is Array or d.travel_anchors.size()>64: return false
		var navigation_state:=d.duplicate()
		navigation_state["anchors"]=d.travel_anchors
		var anchor_ids: Dictionary={}
		for anchor in d.travel_anchors:
			if not anchor is Dictionary or anchor.size()!=6 or not Navigation.anchor_valid(navigation_state,anchor): return false
			var stable_id:=_anchor_id(anchor)
			if anchor_ids.has(stable_id): return false
			anchor_ids[stable_id]=true
			saved_anchors.append({"floor":int(anchor.floor),"x":int(anchor.x),"y":int(anchor.y),"marker_x":int(anchor.marker_x),"marker_y":int(anchor.marker_y),"token":anchor.token})
	if d.floor >= expected_floors or d.x < 1 or d.x > 9 or d.y < 1 or d.y > 9 or d.hp <= 0 or d.atk <= 0: return false
	var position_token: String=d.floors[int(d.floor)][int(d.y)][int(d.x)]
	if position_token=="#" or position_token=="m": return false
	if position_token=="n" and saved_winch!="rescue": return false
	if position_token=="e" and saved_winch!="armory": return false
	if not d.floor_seen[int(d.floor)]: return false
	if saved_end=="victory" and (not d.won or not saved_expedition or not d.floor_seen[7]): return false
	if saved_end=="retired" and d.won and (saved_expedition or not d.floor_seen[4] or first_boss_remaining!=0): return false
	legacy_points=saved_points;legacy_reserves=saved_reserves
	talent_draft=saved_talent_draft;last_kill_kind=saved_last_kill
	draft=saved_draft
	death_record={}
	run_id=saved_run_id; mode=saved_mode; ended_reason=saved_end
	layout_revision=saved_layout
	attunement_version=Attunement.REVISION; gear_offers=saved_gear_offers; gear_choices=saved_gear_choices
	seed_value=int(d.seed_value); generation_attempts=int(d.generation_attempts); generation_fallback=d.generation_fallback
	hero_id=d.hero_id; focus=int(d.focus); focus_cap=int(d.focus_cap); skill_armed=d.skill_armed
	equipped=d.equipped; inventory=d.inventory.duplicate(); talents=d.talents.duplicate(); kills=int(d.kills); floor_seen=d.floor_seen.duplicate()
	quest_state=int(d.quest_state); bridge_built=d.get("bridge_built",false); event_done=d.event_done; event_kind=d.event_kind; water_choice=d.water_choice; chest_claimed=d.chest_claimed
	last_battle={}
	floors = d.floors.duplicate(true)
	if old_seal and d.secret:
		# Some historical saves retained the bell tile after claiming its old
		# reward. Remove it without granting the new reward or changing stats.
		for grid in floors:
			for row in grid:
				for x in row.size():
					if row[x]=="Q": row[x]="."
	seal_clues=saved_seal_clues; seal_input=saved_seal_input; seal_solved=saved_seal_solved; seal_reward=saved_seal_reward
	floor_index = int(d.floor)
	pos = Vector2i(int(d.x),int(d.y))
	hp=int(d.hp); atk=int(d.atk); defense=int(d.def); keys=int(d.keys); gold=int(d.gold); moves=int(d.moves)
	core=d.core; core_use=d.core_use; weapon=d.weapon; secret=d.secret; clue=d.clue
	principal=int(d.principal); fees=int(d.fees); interest=int(d.interest); loan_used=d.loan_used; overdue=d.overdue; checkpoints=int(d.checkpoints)
	winch_choice=saved_winch; maul_claimed=saved_maul
	audit_puzzle=saved_puzzle; audit_read=saved_audit_read; audit_solved=saved_audit_solved; audit_reward=saved_audit_reward
	travel_anchors=saved_anchors
	oath_state=saved_oath
	expedition_revision=saved_revision; rescue_state=saved_rescue; rescue_reward=saved_reward
	expedition_started=saved_expedition; expedition_bridge=saved_bridge
	camp_medicine_left=saved_medicine; camp_focus_left=saved_focus_stock
	won = d.won
	cargo=saved_cargo
	generation_valid=true
	message = "Your journey resumes."
	return true

func _restore_death(d: Dictionary) -> bool:
	# Reconstruct and validate the full living pre-state, then execute the same
	# bounded timeline. No serialized round count or client summary is trusted.
	var record:Dictionary=d.death_record
	if record.size()!=6: return false
	for key in ["floor","x","y","start_hp"]:
		var value=record.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floor(float(value)): return false
	if record.floor<0 or record.floor>7 or record.x<1 or record.x>9 or record.y<1 or record.y>9 or record.start_hp<1 or record.start_hp>1000000: return false
	if not record.get("enemy") is String or not ENEMIES.has(record.enemy) or not record.get("skill_armed") is bool: return false
	if not d.get("mode") is String or not d.get("won") is bool or not d.get("skill_armed") is bool or not d.get("hero_id") is String: return false
	if d.mode!="risk" or d.won: return false
	for key in ["hp","moves","focus","floor","x","y"]:
		var value=d.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floor(float(value)) or value<0 or value>1000000: return false
	if d.hp!=0 or d.moves<1 or d.floor!=record.floor or absi(int(d.x)-int(record.x))+absi(int(d.y)-int(record.y))!=1: return false
	var before:=d.duplicate(true)
	before.ended_reason="";before.death_record={};before.hp=record.start_hp;before.moves=int(d.moves)-1
	before.skill_armed=record.skill_armed
	if record.skill_armed and d.get("skill_armed")==false and d.get("hero_id") in ["warden","ranger"]: before.focus=int(d.focus)+1
	var probe:=TowerWorld.from_snapshot(before)
	if probe==null or probe.tile(Vector2i(int(record.x),int(record.y)))!=record.enemy: return false
	var delta:=Vector2i(int(record.x),int(record.y))-probe.pos
	if not probe.lethal_fight(delta): return false
	var expected:=d.duplicate(true)
	expected.version=18
	if int(d.version)<18:expected.cargo=Cargo.legacy()
	if int(d.version)<17:
		expected.legacy_points=LegacyPoints.legacy()
		expected.legacy_reserves=0
	if int(d.version)<16:
		expected.talent_draft=Progression.talent_draft(0,0)
		expected.last_kill_kind=""
	if int(d.version)<15:
		expected.draft={"version":0,"pool":[],"offers":[],"choice":"none"}
	if JSON.parse_string(JSON.stringify(probe.save_data()))!=JSON.parse_string(JSON.stringify(expected)): return false
	if not restore(before): return false
	return lethal_fight(delta)
