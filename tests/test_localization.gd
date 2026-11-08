extends SceneTree
const Loc=preload("res://scripts/localization.gd")
const World=preload("res://scripts/world.gd")
const Progression=preload("res://scripts/progression.gd")
var checks:=0
var failures:=0
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func cjk(s: String) -> bool:
	for ch in s:
		if ch.unicode_at(0)>=0x3400 and ch.unicode_at(0)<=0x9fff: return true
	return false
func format_example(template: String, translated: bool=false) -> String:
	var out:=""; var index:=0; var parameter:=0
	while index<template.length():
		if template[index]=="%" and index+1<template.length():
			var spec: String=template[index+1]
			if spec=="%": out+="%"; index+=2; continue
			if spec in ["s","d"]:
				out+=(Loc.text("Warden") if translated else "Warden") if spec=="s" else str(11+parameter)
				parameter+=1; index+=2; continue
		out+=template[index]; index+=1
	return out
func source_strings(source: String) -> Array:
	# Small lexical scanner, not a regex that misreads apostrophes/escaped quotes.
	var result: Array=[]; var i:=0
	while i<source.length():
		if source[i]=="#":
			while i<source.length() and source[i]!="\n": i+=1
			continue
		if source[i] not in ["\"","'"]: i+=1; continue
		var quote: String=source[i]; i+=1
		var text:=""
		while i<source.length():
			if source[i]==quote: i+=1; break
			if source[i]=="\\" and i+1<source.length():
				i+=1
				text+="\n" if source[i]=="n" else source[i]
			else: text+=source[i]
			i+=1
		result.append(text)
	return result
func _initialize():
	call_deferred("run_tests")
func run_tests():
	check(Loc.text("Warden")=="护卫" and Loc.text("Warden","en")=="Warden","Chinese default and untouched English mode")
	check(Loc.text("warden") == "warden" and Loc.text("")=="","technical IDs and empty text unchanged")
	var font_text:="%+-/" # Actual display symbols; all CJK characters are collected from catalogs below.
	for catalog_path in ["res://scripts/localization_ui.gd","res://scripts/localization_world.gd","res://scripts/localization_progression.gd"]:
		check(ResourceLoader.exists(catalog_path),"display catalog packaged: "+catalog_path)
		if not ResourceLoader.exists(catalog_path): continue
		var catalog=load(catalog_path)
		var exact_ok:=true; var template_ok:=true
		for source in catalog.EXACT:
			var translated: String=Loc.text(source)
			if translated!=catalog.EXACT[source]: exact_ok=false; push_error("Catalog mismatch: "+source+" => "+translated)
			font_text+=str(catalog.EXACT[source])
		for pair in catalog.TEMPLATES:
			var sample:=format_example(pair[0])
			var expected:=format_example(pair[1],true)
			if Loc.text(sample)!=expected:
				template_ok=false; push_error("Template mismatch: "+sample+" => "+Loc.text(sample)+" expected "+expected)
			font_text+=str(pair[1])
		check(exact_ok,"catalog exact rules match their declared translation: "+catalog_path)
		check(template_ok,"template captures preserve values, order, punctuation and percent: "+catalog_path)
	for dictionary in [Progression.HEROES,Progression.GEAR,Progression.TALENTS,World.ENEMIES]:
		var complete:=true
		for id in dictionary:
			for field in ["name","skill","description"]:
				if dictionary[id].has(field) and not cjk(Loc.text(dictionary[id][field])):
					complete=false; push_error("Untranslated visible field: "+id+"."+field)
		check(complete,"all displayed model names and descriptions translate")
	for example in ["Mossling defeated. -12 HP","Warden chosen. Every hero can clear the main route.","Gold 37 / debt 42 = principal 40 + fee 2 + interest 0","Raw: normal 96 + ambush 0 + thorns 0","EXTRA opening hit 25 + charge bonus 25 / 5 retaliations","Final loss 112 / recovery +0 / no active skill"]:
		check(cjk(Loc.text(example)) and Loc.text(example)!=example,"real dynamic display translates: "+example)
	check(not "Mossling" in Loc.text("Mossling defeated. -12 HP") and "12" in Loc.text("Mossling defeated. -12 HP"),"dynamic monster names translate recursively without losing damage")
	check("35%" in Loc.text(Progression.skill_description("warden",[])) and "45%" in Loc.text(Progression.skill_description("warden",["iron_skin","trained_focus"])) and not "%%" in Loc.text(Progression.skill_description("warden",[])),"percent values survive exact and dynamic skill translation")
	check(not Loc.text("Double lock: costs 2 gold keys").ends_with("s") and "2" in Loc.text("Double lock: costs 2 gold keys"),"English plural key suffix does not leak into Chinese")
	var learned: String=Loc.text("Learned: Iron skin, Trained focus")
	check(learned=="已学："+Loc.text("Iron skin")+"、"+Loc.text("Trained focus"),"nested learned talent list translates every dynamic name")
	var equipped: String=Loc.text("Equipped: Heavy buckler. "+str(Progression.GEAR.buckler.description))
	check(cjk(equipped) and not "Equipped" in equipped and not "Heavy buckler" in equipped and not "Block the" in equipped and "+6" in equipped and "-4" in equipped,"equipment prefix, dynamic name and full description all translate")
	for id in World.Riddle.SYMBOLS:
		check(cjk(Loc.text(World.Riddle.SYMBOLS[id])),"riddle symbol name translates: "+id)
	for seed_number in [0,23]:
		for clue_line in World.Riddle.clues(seed_number):
			var translated: String=Loc.text(clue_line)
			check(cjk(translated) and not "Sun" in translated and not "Moon" in translated and not "Tower" in translated and not "Key" in translated,"seed-specific relation clue fully translates: "+clue_line)
	# Audit only UI-like string literals, excluding fragments that are always
	# joined to a complete translated string and technical engine labels.
	var allow := [" (cancel armed skill)"," / 1 focus"," [EQUIPPED]","BLENDER  +  GODOT"]
	var words:=RegEx.new(); words.compile("[A-Za-z]{3,}")
	for path in ["res://scripts/main.gd","res://scripts/world.gd","res://scripts/progression.gd","res://scripts/riddle.gd"]:
		var missing: Array=[]
		for source in source_strings(FileAccess.get_file_as_string(path)):
			if not " " in source or source in allow or source.begins_with("res://") or words.search(source)==null: continue
			var sample:=format_example(source)
			if not cjk(Loc.text(sample)) and not sample in missing: missing.append(sample)
		check(missing.is_empty(),"visible source audit "+path+": "+str(missing))
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene); scene.save_path="user://localization-integration-test.json"; scene.world=World.new(0)
	await process_frame
	check(scene.language=="zh" and scene.display("Warden")=="护卫","main starts in Chinese and display uses translator")
	var font_path:="res://assets/fonts/MagicTowerCJK.otf"
	check(ResourceLoader.exists(font_path) and scene.font is FontFile and scene.font.resource_path==font_path,"packaged CJK font actually loads and is selected")
	var missing_chars:=""
	if scene.font is FontFile:
		for ch in font_text:
			if (ch.unicode_at(0)>=0x3000 or ch in "%+-/") and not scene.font.has_char(ch.unicode_at(0)) and not ch in missing_chars: missing_chars+=ch
	check(missing_chars.is_empty(),"font cmap covers catalog Chinese/punctuation and numeric symbols: "+missing_chars)
	scene.save_game(false)
	var before: Dictionary=scene.world.save_data().duplicate(true)
	var file_before: String=FileAccess.get_file_as_string(scene.save_path)
	var event:=InputEventKey.new(); event.pressed=true; event.keycode=KEY_F2
	for mode in ["growth","book","journal","interaction","battle"]:
		scene.growth=mode=="growth"; scene.book=mode=="book"; scene.journal=mode=="journal"; scene.interaction=mode=="interaction"; scene.battle_time=2.0 if mode=="battle" else 0.0
		scene.checkpoint_pending=Vector2i.RIGHT if mode=="interaction" else Vector2i.ZERO
		scene.pending_reason="interest" if mode=="interaction" else ""
		var modal_before: Array=[scene.growth,scene.book,scene.journal,scene.interaction,scene.battle_time,scene.checkpoint_pending,scene.pending_reason]
		var sound_before: int=scene.sound_event_count
		scene._unhandled_input(event)
		check(scene.language=="en" and scene.display("Warden")=="Warden","F2 switches to English inside "+mode)
		scene._unhandled_input(event)
		check(scene.language=="zh" and [scene.growth,scene.book,scene.journal,scene.interaction,scene.battle_time,scene.checkpoint_pending,scene.pending_reason]==modal_before,"F2 returns Chinese without dismissing or acting on "+mode)
		check(scene.world.save_data()==before and scene.history.is_empty() and scene.sound_event_count==sound_before and FileAccess.get_file_as_string(scene.save_path)==file_before,"F2 is state, history, audio and save neutral in "+mode)
	event.echo=true
	scene._unhandled_input(event)
	check(scene.language=="zh","held F2 auto-repeat does not flicker language")
	DirAccess.remove_absolute(scene.save_path)
	print("LOCALIZATION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
