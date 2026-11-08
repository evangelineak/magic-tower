extends SceneTree
const World=preload("res://scripts/world.gd")
const A=preload("res://scripts/attunement.gd")
const P=preload("res://scripts/progression.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func snapshot(w)->Dictionary: return w.save_data().duplicate(true)
func json_copy(value): return JSON.parse_string(JSON.stringify(value))
func fixture(name:String):
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name+".json"))
	var w=World.new(0)
	check(w.restore(data),"historical fixture loads: "+name)
	return w
func rejects(w,id:String):
	var before:=snapshot(w)
	check(not w.action(id) and snapshot(w)==before,"invalid action is atomic: "+id)
func invalid_save(w,data:Dictionary,label:String):
	var before:=snapshot(w)
	check(not w.restore(data) and snapshot(w)==before,"invalid save is atomic: "+label)
func offer(w,gear:String,id:String):
	# Controlled catalog selection for a focused rules test; persisted catalog
	# validity is deliberately independent of the current generator's seed.
	var ids:Array=[id]
	for candidate in A.TEMPLATE_IDS:
		if candidate!=id and ids.size()<3: ids.append(candidate)
	w.gear_offers[gear]=ids
func _init():
	var w=World.new(42)
	check(w.save_data().version==15 and w.attunement_version==1 and w.gear_choices.is_empty(),"new schema starts unselected and original")
	check(w.gear_offers.size()==4 and not w.gear_offers.has("balanced"),"only four nonbaseline gear catalogs")
	check(w.gear_offers==World.new(42).gear_offers,"catalog is deterministic")
	for gear in World.ATTUNABLE_GEAR:
		check(A.valid_offers(w.gear_offers[gear]),"three unique legal candidates: "+gear)
		var before:=snapshot(w)
		var options:Array=w.attunement_offers(gear)
		check(options.size()==4,"unowned gear candidates visible before acquisition")
		for id in w.gear_offers[gear]:
			var preview:Dictionary=w.attunement_preview(id,gear)
			check(preview.valid and not preview.owned and not preview.can_choose,"unowned preview read-only")
			check(preview.skill_level==P.skill_level(w.talents,id) and preview.mend_heal==P.mend_heal(w.talents,id),"candidate preview uses pure rule values")
		check(snapshot(w)==before,"preview and candidate query do not mutate run")
		rejects(w,"attune_"+gear+"_"+str(w.gear_offers[gear][0]))
		rejects(w,"attune_"+gear+"_none")
	rejects(w,"attune_balanced_none"); rejects(w,"attune_missing_focus_light"); rejects(w,"attune_repeater_")
	check(w.attunement_offers("balanced").is_empty() and not w.attunement_preview("none","balanced").valid,"baseline cannot be tuned")
	# Genuine schema-11 fixtures were generated with the old source, not by
	# taking a new save and merely changing its version number.
	for name in ["schema11-layout2","schema11-layout1"]:
		var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name+".json"))
		w=fixture(name)
		check(w.gear_choices.is_empty() and w.attunement_version==1,"migration grants no attunement or locked choice")
		check(w.run_id=="" and w.mode=="safe" and w.ended_reason=="" and not w.reward_eligible(),"legacy gains no session identity or terminal state")
		var migrated:=snapshot(w)
		for field in old:
			if field=="version": continue
			check(json_copy(migrated[field])==old[field],"migration preserves historical field "+field)
		for gear in World.ATTUNABLE_GEAR: check(w.gear_offers[gear]==A.offers(int(old.seed_value),gear),"old save gets deterministic actual catalog")
		check(w.restore(json_copy(migrated)) and snapshot(w)==migrated,"migrated JSON roundtrip does not reroll")
	w=fixture("schema11-layout1")
	check("maul" in w.inventory and "repeater" in w.inventory,"real old reward path supplies comparison gear")
	check(w.action("equip_balanced"),"comparison starts in untuned baseline")
	offer(w,"repeater","focus_deep"); offer(w,"maul","guard_deep")
	var before_choice:=snapshot(w)
	check(w.action("attune_repeater_focus_deep"),"full underscore ID parses and commits once")
	check(w.gear_choices.repeater=="focus_deep" and w.gear_attunement()=="none","unworn gear has no global effect")
	check(w.action("equip_repeater") and w.skill_level()==12,"only worn focus tuning changes skill level")
	check(w.skill_level_info().gear==2 and w.skill_level_info().effective==12,"UI level breakdown matches current gear")
	var tip:Dictionary=w.tooltip_data(w.pos)
	check(A.TEMPLATES.focus_deep.description in tip.lines and w.skill_description() in tip.lines and "Attunement: Deep focus" in tip.lines and "Skill level 12 = base 10 + training 0 + equipment 2 + strategy 0" in tip.lines,"hero tooltip uses the current worn tuning and skill effect")
	check(w.action("attune_maul_guard_deep"),"second item has independent choice")
	var repeat_preview:Dictionary=w.battle_preview("W","repeater")
	var maul_preview:Dictionary=w.battle_preview("W","maul")
	check(repeat_preview.attunement=="focus_deep" and maul_preview.attunement=="guard_deep","V comparison selects each override gear's own tuning")
	check(w.skill_level()==12 and w.action("equip_maul") and w.skill_level()==10,"switching gear removes unworn level bonus")
	check(not w.battle_preview("W","duelist").valid,"future catalog never grants unowned battle equipment")
	for id in ["focus_deep","none","guard_light"]: rejects(w,"attune_repeater_"+id)
	var saved:=snapshot(w); var copy=World.new(7)
	check(copy.restore(json_copy(saved)) and snapshot(copy)==saved,"all offers and independent locks survive JSON load")
	check(copy.restore(before_choice) and copy.gear_choices.is_empty() and copy.gear_offers==before_choice.gear_offers,"full-state undo reverses decision without rerolling")
	check(copy.action("attune_repeater_none") and copy.gear_choices.repeater=="none","explicit original is a locked choice")
	rejects(copy,"attune_repeater_focus_deep")
	check(copy.attunement_offers("repeater").is_empty(),"locked original has no repeat offers")
	# All IDs, not just the first catalog entry, work through World action.
	for gear in World.ATTUNABLE_GEAR:
		for id in A.TEMPLATE_IDS:
			w=fixture("schema11-layout1")
			if gear in ["buckler","duelist"]:
				# Unit fixture owns one relic, never both mutually exclusive relics.
				w.inventory.append(gear); w.chest_claimed=true
			offer(w,gear,id)
			check(w.action("attune_"+gear+"_"+id),"every gear/template action preserves ID")
			w.equipped=gear; w.hero_id="ranger"; w.skill_armed=true; w.focus=2
			var expected:=P.battle(w.atk,w.defense,w.hp,World.ENEMIES.W,"ranger",true,gear,w.talents,"watch" if w.oath_state=="active" else "none",false,id)
			check(w.battle_preview("W")==expected,"World armed preview equals pure tuned rules")
			w.hero_id="scholar"; w.skill_armed=false
			var hp_before:int=w.hp; var focus_before:int=w.focus
			var healing:int=w.mend_heal()
			check(w.action("mend") and w.hp==hp_before+healing and w.focus==focus_before-1,"scholar applies current item's exact mend amount")
	# Actual combat consumes the same preview and focus, not a stale skill level.
	w=fixture("schema11-layout1"); offer(w,"repeater","focus_deep")
	check(w.action("attune_repeater_focus_deep"),"combat fixture attunes")
	w.equipped="repeater"; w.hero_id="ranger"; w.skill_armed=true; w.focus=2
	w.floor_index=0; w.pos=Vector2i(1,1); w.floors[0][1][2]="b"
	var expected:Dictionary=w.battle_preview("b","",Vector2i(2,1)); var start_hp:int=w.hp
	check(w.step(Vector2i.RIGHT) and w.last_battle==expected.merged({"enemy":"b"}),"actual combat reuses exact tuned forecast")
	check(w.hp==start_hp-expected.damage+expected.heal_after and w.focus==1 and not w.skill_armed,"actual combat loss/heal/focus agrees with forecast")
	w=fixture("schema11-layout1"); offer(w,"maul","focus_light")
	check(w.action("attune_maul_focus_light"),"save rejection fixture attunes")
	var good:=snapshot(w)
	for bad_version in [true,0,2,1.5,4294967297,1.0e100]:
		var bad:=good.duplicate(true); bad.attunement_version=bad_version; invalid_save(w,bad,"bad tuning version")
	for bad_offers in [[],{}, {"balanced":["edge_light","guard_light","focus_light"]}]:
		var bad:=good.duplicate(true); bad.gear_offers=bad_offers; invalid_save(w,bad,"bad catalog structure")
	for bad_list in [["none","edge_light","guard_light"],["focus_light","focus_light","edge_light"],["focus_light","edge_light"],["bad","edge_light","guard_light"]]:
		var bad:=good.duplicate(true); bad.gear_offers.maul=bad_list; invalid_save(w,bad,"bad catalog contents")
	for bad_choices in [{"balanced":"none"},{"duelist":"none"},{"maul":"unknown"},{"maul":false},{"unknown":"none"}]:
		var bad:=good.duplicate(true); bad.gear_choices=bad_choices; invalid_save(w,bad,"unowned or invalid selected gear")
	var bad:=good.duplicate(true); bad.gear_offers.extra=["focus_light","edge_light","guard_light"]; invalid_save(w,bad,"extra catalog key")
	bad=good.duplicate(true); bad.gear_offers.maul=["edge_light","guard_light","edge_deep"]; invalid_save(w,bad,"selection missing from actual persisted offers")
	# Legal actual stored lists are authoritative, even when order/subset differs
	# from today's seed generator. This prevents migration from silently rerolling.
	var alternate:=good.duplicate(true); alternate.gear_offers.maul=["focus_light","guard_deep","edge_deep"]
	check(w.restore(json_copy(alternate)) and w.gear_offers.maul==alternate.gear_offers.maul,"actual valid saved catalog beats seed regeneration")
	w.won=true; rejects(w,"attune_repeater_none")
	print("ATTUNEMENT WORLD: %d checks, failures=%d"%[checks,failures])
	quit(1 if failures else 0)
