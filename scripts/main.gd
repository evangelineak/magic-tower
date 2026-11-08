extends Node2D

const World = preload("res://scripts/world.gd")
const Localization = preload("res://scripts/localization.gd")
var language := "zh"
const Attunement = preload("res://scripts/attunement.gd")
const Progression = preload("res://scripts/progression.gd")
const CELL := 64.0
const ORIGIN := Vector2(24,72)
const INK := Color("e5ebee")
const MUTED := Color("7e96a4")
const GOLD := Color("e9bd6d")
const TEAL := Color("65dac4")
const RED := Color("ed827f")
const Session = preload("res://scripts/session.gd")
var session = null # Explicit dependency injection; production uses the durable adapter.
var world = null
var ui_notice := ""
var finish_pending := ""
var strategy_selection := ""
var strategy_submitted := false
var walk_generation := 0
var font = ThemeDB.fallback_font
var art: Texture2D
var combat_art: Dictionary = {}
var sound_player: AudioStreamPlayer
var sound_bank: Dictionary = {}
var muted := false
var sound_event_count := 0
var last_sound_event := ""
const ENEMY_ART := {"s":"mossling","g":"sentinel","u":"stalker","b":"briar","w":"juggernaut","V":"colossus","K":"regent","B":"regent","Z":"archivist","H":"stalker","W":"sentinel"}
var history: Array = []

var travel_menu := false
var travel_page := 0
var travel_rows: Array=[]
var travel_refresh_count := 0
var travel_pending := ""
var attuning := false
var attune_gear := ""
var attune_pending := ""
var comparison := false
var compare_pos := Vector2i(-1,-1)
var compare_floor := -1
var compare_page := 0
var book := false
var book_page := 0
var journal := false
var journal_page := 0
var growth := true
var growth_tab := 0
var gear_page := 0
var reset_mode := ""
var battle_details: Dictionary = {}
var battle_kind := "s"
var battle_hero := "warden"
var battle_skill := false
var interaction_page := 0
var interaction := false
var winch_pending := ""
var battle_time := 0.0
var battle_name := ""
var battle_loss := 0
var action_rows: Array = []
var checkpoint_pending := Vector2i.ZERO
var pending_reason := ""
var reset_armed := false
var selected_run_mode := "safe"
var lethal_delta := Vector2i.ZERO
var lethal_snapshot: Dictionary={}
var lethal_preview: Dictionary={}
var death_report := false
var death_page := 0
var hover := Vector2i(-1,-1)
var tick := 0.0
var buttons: Array = []
var walk_route: Array = []
var walk_floor := -1
var walk_origin := Vector2i(-1,-1)
var walk_timer := 0.0
var map_art: Dictionary = {}
const MAP_ENEMY_ART := {"s":"mossling","g":"sentinel","u":"stalker","b":"briar","w":"juggernaut","V":"colossus","K":"regent","B":"gate_brute","Z":"archivist","H":"ferryman","W":"jailer"}
func initial_seed() -> int:
	var seed_number := randi_range(1,2147483646)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed=") and arg.substr(7).is_valid_int(): seed_number=int(arg.substr(7))
	return seed_number
func play_sound(id: String):
	# Instrument committed events separately from device playback for deterministic QA.
	sound_event_count+=1
	last_sound_event=id
	if muted or not sound_bank.has(id) or DisplayServer.get_name()=="headless": return
	sound_player.stream=sound_bank[id]
	sound_player.play()
func toggle_mute():
	muted=not muted
	if muted and sound_player: sound_player.stop()
	queue_redraw()
func _ready():
	if ResourceLoader.exists("res://assets/fonts/MagicTowerCJK.otf"):
		font=load("res://assets/fonts/MagicTowerCJK.otf")
	sound_player=AudioStreamPlayer.new()
	sound_player.volume_db=-6.0
	add_child(sound_player)
	for id in ["move","pickup","door","impact","victory","water"]:
		var sound_path := "res://assets/audio/%s.wav" % id
		if ResourceLoader.exists(sound_path): sound_bank[id]=load(sound_path)
	if ResourceLoader.exists("res://assets/tower.png"): art = load("res://assets/tower.png")
	for id in ["warden","ranger","scholar","mossling","sentinel","stalker","briar","juggernaut","colossus","regent","archivist","ilen","mira"]:
		var path := "res://assets/combat/%s.png" % id
		if ResourceLoader.exists(path): combat_art[id]=load(path)
	for id in ["winch","maul"]:
		var path := "res://assets/props/%s.png" % id
		if ResourceLoader.exists(path): combat_art[id]=load(path)
	for id in ["warden","ranger","scholar","mossling","sentinel","stalker","briar","juggernaut","colossus","regent","gate_brute","archivist","ferryman","jailer","ilen","mira"]:
		var path := "res://assets/map_icons/%s.png" % id
		if ResourceLoader.exists(path): map_art[id]=load(path)
	buttons = [Rect2(768,636,148,40),Rect2(932,636,148,40),Rect2(1096,636,148,40),Rect2(1014,536,230,40),Rect2(768,586,230,40),Rect2(768,536,230,40),Rect2(1014,586,230,40),Rect2(768,686,476,40)]
	await initialize_session()
	queue_redraw()
func _process(delta):
	tick += delta
	advance_walk(delta)
	battle_time = maxf(0.0, battle_time-delta)
	queue_redraw()
func display(source: String) -> String:
	return Localization.text(source,language)
func label_at(p: Vector2, text: String, size:=18, color:=INK):
	draw_string(font,p,display(text),HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func panel(r: Rect2, color: Color):
	draw_style_box(style(color),r)
func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=10; s.corner_radius_top_right=10; s.corner_radius_bottom_left=10; s.corner_radius_bottom_right=10
	return s
func _draw():
	draw_rect(Rect2(0,0,1280,800),Color("080f1b"))
	label_at(Vector2(24,42),"MAGIC TOWER",27,INK)
	if world==null:
		draw_wrapped(Vector2(100,200),ui_notice,1000,22,TEAL)
		label_at(Vector2(100,310),"L: Reload current journey / F5: Retry save",18,GOLD)
		return
	label_at(Vector2(310,42),world.floor_title(),22,GOLD)
	label_at(Vector2(752,30),"FLOOR %d / %d" % [world.floor_index+1,world.floor_count()],18,GOLD)
	label_at(Vector2(930,30),"SEED %d" % world.seed_value,15,TEAL)
	label_at(Vector2(752,54),"F2: 中文 / English",13,MUTED)
	label_at(Vector2(1030,54),"M: SOUND OFF" if muted else "M: SOUND ON (LOW)",13,MUTED)
	panel(Rect2(20,68,712,712),Color("121e2c"))
	for y in range(11):
		for x in range(11):
			var p := ORIGIN + Vector2(x,y)*CELL
			var t: String = world.tile(Vector2i(x,y))
			draw_rect(Rect2(p+Vector2(1,1),Vector2(CELL-2,CELL-2)),Color("172535") if (x+y)%2==0 else Color("142130"))
			if t == "#":
				draw_rect(Rect2(p+Vector2(3,3),Vector2(58,58)),Color("283748"))
				draw_line(p+Vector2(5,5),p+Vector2(58,5),Color("3c5061"),2)
			else: draw_token(p+Vector2(CELL/2,CELL/2),t)
			if hover == Vector2i(x,y): draw_rect(Rect2(p,Vector2(CELL,CELL)),Color(0.4,0.85,0.76,0.35),false,2)
	if world.expedition_revision>=3:
		for y in range(1,10):
			for x in range(1,10):
				var target:=Vector2i(x,y)
				if world.tile(target)!="H": continue
				var side: Vector2i=world.flank_position(target)
				if side.x<0: continue
				var center: Vector2=ORIGIN+Vector2(side)*CELL+Vector2(CELL/2,CELL/2)
				var toward: float=signf(float(target.x-side.x))
				draw_line(center+Vector2(-toward*20,-22),center+Vector2(-toward*20,22),TEAL,4)
				draw_line(center+Vector2(-toward*12,0),center+Vector2(toward*12,0),TEAL,3)
				draw_line(center+Vector2(toward*12,0),center+Vector2(toward*5,-7),TEAL,3)
				draw_line(center+Vector2(toward*12,0),center+Vector2(toward*5,7),TEAL,3)
	var hero := ORIGIN+Vector2(world.pos)*CELL+Vector2(CELL/2,CELL/2)
	draw_circle(hero,19+sin(tick*3)*1.5,Color(0.4,0.85,0.76,0.15))
	if map_art.has(world.hero_id):
		draw_texture_rect(map_art[world.hero_id],Rect2(hero-Vector2(30,30),Vector2(60,60)),false)
		draw_rect(Rect2(hero-Vector2(29,29),Vector2(58,58)),TEAL,false,2)
	elif combat_art.has(world.hero_id):
		draw_texture_rect(combat_art[world.hero_id],Rect2(hero-Vector2(29,29),Vector2(58,58)),false)
	else:
		draw_colored_polygon(PackedVector2Array([hero+Vector2(0,-17),hero+Vector2(13,13),hero+Vector2(0,9),hero+Vector2(-13,13)]),TEAL)
		draw_circle(hero+Vector2(0,-3),4,INK)
	# Keep staircase destinations visible when the hero stands on their landing.
	for y in range(11):
		for x in range(11):
			var t: String=world.tile(Vector2i(x,y))
			if t not in ["<",">"]: continue
			var p:=ORIGIN+Vector2(x,y)*CELL
			draw_rect(Rect2(p+Vector2(3,3),Vector2(58,58)),TEAL,false,2)
			panel(Rect2(p+Vector2(3,3),Vector2(34,20)),Color("083b3b"))
			label_at(p+Vector2(6,18),("F%d" % (world.floor_index+(2 if t==">" else 0))) if (t==">" and world.floor_index+1<world.floor_count()) or (t=="<" and world.floor_index>0) else "--",13,INK)
	for point in walk_route:
		draw_circle(ORIGIN+Vector2(point)*CELL+Vector2(CELL/2,CELL/2),4,TEAL)
	if not walk_route.is_empty():
		draw_circle(ORIGIN+Vector2(walk_route.back())*CELL+Vector2(CELL/2,CELL/2),23,TEAL,false,2)
	draw_sidebar()
	if battle_time > 0.0: draw_battle()
	if book: draw_book()
	if growth: draw_growth()
	if interaction: draw_interaction()
	if world.won and battle_time<=0.0 and not (book or growth or interaction): draw_victory()
	if journal: draw_journal()
	if comparison: draw_comparison()
	if travel_menu: draw_travel()
	if attuning: draw_attunement()
	if not modal_open(): draw_tooltip()
	if finish_pending!="": draw_finish_confirmation()
	if is_terminal(): draw_terminal()
	if strategy_pending(): draw_strategy_draft()
	if reset_armed: draw_new_run_confirmation()
	if not lethal_snapshot.is_empty(): draw_lethal_confirmation()
	if death_report: draw_death_report()
	if session!=null and (session.busy or session.read_only):
		panel(Rect2(210,15,1020,44),Color("182738"))
		label_at(Vector2(225,44),"Saving safely. Please wait." if session.busy else "Read-only: L reloads the current stored journey.",18,GOLD)
func draw_sidebar():
	panel(Rect2(752,72,504,704),Color("101c2a"))
	label_at(Vector2(1100,106),"RISK MODE" if world.mode=="risk" else "SAFE MODE",14,GOLD)
	if combat_art.has(world.hero_id): draw_texture_rect(combat_art[world.hero_id],Rect2(766,82,72,72),false)
	label_at(Vector2(850,106),Progression.HEROES[world.hero_id].name,22,INK)
	label_at(Vector2(850,134),"FOCUS %d / %d  |  %s" % [world.focus,world.focus_cap,"SKILL ARMED" if world.skill_armed else ("SKILL READY" if world.focus>0 else "NO FOCUS")],15,TEAL)
	var values := [["VITALITY",str(world.hp),Color("ef928f")],["BASE ATTACK",str(world.atk),INK],["BASE DEFENSE",str(world.defense),INK],["GOLD KEYS",str(world.keys),GOLD],["GOLD",str(world.gold),GOLD],["DEBT",str(world.debt()),GOLD]]
	for i in values.size():
		var p:=Vector2(768+(i%3)*164,164+(i/3)*70)
		panel(Rect2(p,Vector2(148,60)),Color("203343"))
		label_at(p+Vector2(10,21),values[i][0],13,MUTED)
		label_at(p+Vector2(10,48),values[i][1],23,values[i][2])
	if ui_notice!="": label_at(Vector2(768,422),"F5: retry pending save / L: reload stored journey",13,MUTED)
	label_at(Vector2(768,326),"Kills %d  /  Talents %d" % [world.kills,world.talents.size()],16,GOLD)
	label_at(Vector2(768,354),"NEW TALENT AVAILABLE  [C]" if not Progression.talent_options(world.kills,world.talents).is_empty() else "C: hero, equipment and skills",15,TEAL)
	draw_wrapped(Vector2(768,388),quest_hint(),460,16,GOLD,2)
	draw_wrapped(Vector2(768,441),status_message(),460,15,TEAL,3)
	label_at(Vector2(768,512),"Walking safely... Any key or click stops." if not walk_route.is_empty() else "Click clear floor to walk. Other objects: inspect only.",14,MUTED)
	var titles := ["UNDO  U","SAVE (CLICK)","LOAD  L","GUIDE  H","INTERACT / LEDGER  E","HERO / GROWTH  C","JOURNEY NOTES  J","SAFE TRAVEL  T"]
	for i in buttons.size():
		panel(buttons[i],Color("253748")); label_at(buttons[i].position+Vector2(12,26),titles[i],15)
	panel(Rect2(768,738,476,32),Color("253748"))
	label_at(Vector2(780,760),"X: retire this journey / record milestones",14,GOLD)
	# Manual controls remain available by keyboard.
	# label_at(Vector2(768,750),"WASD / arrows: manual actions. R / N twice: restart.",13,MUTED)
func modal_open() -> bool:
	return strategy_pending() or reset_armed or not lethal_snapshot.is_empty() or death_report or finish_pending!="" or is_terminal() or attuning or book or growth or interaction or journal or comparison or travel_menu or battle_time>0.0 or (world!=null and world.won)
func wrapped_lines(source: String, width: float, size: int) -> Array[String]:
	var result: Array[String]=[]
	var remaining: String=display(source)
	while not remaining.is_empty():
		var count: int=remaining.length()
		while count>1 and font.get_string_size(remaining.left(count),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: count-=1
		if count<remaining.length() and language=="en":
			var space: int=remaining.rfind(" ",count)
			if space>0: count=space
		result.append(remaining.left(count)); remaining=remaining.substr(count).strip_edges()
	return result
func draw_wrapped(p: Vector2, source: String, width: float, size: int, color: Color, limit:=99):
	var lines:=wrapped_lines(source,width,size)
	for i in mini(limit,lines.size()): label_at(p+Vector2(0,i*(size+5)),lines[i],size,color)
func tooltip_lines() -> Array[String]:
	var lines: Array[String]=[]
	if hover.x<0 or hover.y<0 or hover.x>=11 or hover.y>=11: return lines
	var data: Dictionary=world.tooltip_data(hover)
	if data.get("title","")!="": lines.append_array(wrapped_lines(str(data.title),298,15))
	for source in data.get("lines",[]): lines.append_array(wrapped_lines(str(source),298,15))
	if World.ENEMIES.has(world.tile(hover)): lines.append_array(wrapped_lines("V: compare owned equipment",298,15))
	return lines
func tooltip_rect(lines: Array[String]) -> Rect2:
	var target:=Rect2(ORIGIN+Vector2(hover)*CELL,Vector2(CELL,CELL))
	var size:=Vector2(326,24+lines.size()*20)
	var candidates: Array[Vector2]=[target.end+Vector2(8,8),Vector2(target.position.x-size.x-8,target.end.y+8),Vector2(target.end.x+8,target.position.y-size.y-8),target.position-size-Vector2(8,8)]
	for p in candidates:
		var r:=Rect2(p,size)
		if Rect2(8,8,1264,784).encloses(r): return r
	# A horizontal side always avoids the target even near the top/bottom.
	var x: float=target.end.x+8 if target.end.x+8+size.x<=1272 else target.position.x-size.x-8
	return Rect2(Vector2(x,clampf(target.position.y,8,maxf(8,792-size.y))),size)
func draw_tooltip():
	var lines:=tooltip_lines()
	if lines.is_empty(): return
	var rect:=tooltip_rect(lines)
	panel(rect,Color("07111f")); draw_rect(rect,TEAL,false,1.5)
	for i in lines.size(): label_at(rect.position+Vector2(14,22+i*20),lines[i],15,GOLD if i==0 else INK)
func cancel_walk():
	walk_generation+=1
	walk_route.clear(); walk_floor=-1; walk_origin=Vector2i(-1,-1); walk_timer=0.0
func start_walk(target: Vector2i):
	if not can_mutate(): return
	cancel_walk()
	if modal_open() or world.tile(target)!=".": return
	walk_route=world.safe_walk_path(target)
	walk_floor=world.floor_index; walk_origin=world.pos; walk_timer=0.0
func advance_walk(delta: float):
	if walk_route.is_empty() or session==null or session.busy: return
	if modal_open() or world.floor_index!=walk_floor or world.pos!=walk_origin:
		cancel_walk(); return
	walk_timer+=delta
	if walk_timer<0.12: return
	walk_timer=0.0
	var generation := walk_generation
	var result: Dictionary=await session.safe_walk(walk_route[0],walk_floor,walk_origin)
	apply_session_result(result)
	if not result.get("committed",false): cancel_walk(); return
	if generation!=walk_generation: return
	walk_route.pop_front(); walk_origin=world.pos
func close_travel():
	travel_menu=false
	travel_pending=""
	travel_rows.clear()
func refresh_travel():
	travel_rows=world.travel_options()
	travel_refresh_count+=1
func open_travel():
	cancel_walk()
	if travel_menu: close_travel(); return
	if battle_time>0.0 or comparison or book or journal or growth or interaction: return
	travel_menu=true; travel_page=0; travel_pending=""
	refresh_travel()
func visible_travel_options() -> Array:
	var rows: Array=travel_rows
	travel_page=clampi(travel_page,0,maxi(0,ceili(rows.size()/6.0)-1))
	return rows.slice(travel_page*6,travel_page*6+6)
func select_travel(index: int):
	var rows: Array=visible_travel_options()
	if index<0 or index>=rows.size(): return
	var selected: String=rows[index].id
	refresh_travel()
	for row in travel_rows:
		if row.id==selected and row.reachable: travel_pending=selected; return
func confirm_travel():
	# Refresh before confirmation; World also revalidates the route atomically.
	refresh_travel()
	for row in travel_rows:
		if row.id==travel_pending and row.reachable:
			var action_id: String="fast_travel_"+row.id
			var before_moves: int=world.moves
			close_travel()
			await perform_action(action_id)
			if world.moves==before_moves:
				travel_menu=true; refresh_travel()
			return
	travel_pending=""
func draw_travel():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(195,110,890,580),Color("0c1928"))
	label_at(Vector2(225,151),"SAFE TRAVEL / REGISTERED LANDMARKS",24,GOLD)
	label_at(Vector2(225,184),"Free travel follows a currently safe walking route. No rewards are collected.",15,MUTED)
	if not world.travel_available():
		label_at(Vector2(225,240),"Available only during an unfinished expedition.",18,TEAL)
	elif travel_pending!="":
		for row in travel_rows:
			if row.id!=travel_pending: continue
			label_at(Vector2(225,245),"Travel to floor %d: %s?" % [row.floor+1,display(row.name)],22,TEAL)
			label_at(Vector2(225,284),"Safe route: skip %d walking / lift operations" % row.steps,17)
			label_at(Vector2(225,326),"Travel takes one action. NPC choices and oaths remain yours.",16,MUTED)
			panel(Rect2(225,435,390,48),Color("253748"))
			label_at(Vector2(240,466),"Enter: confirm destination",18,GOLD)
			panel(Rect2(635,435,390,48),Color("253748"))
			label_at(Vector2(650,466),"Esc: back to landmarks",18)
	else:
		var rows: Array=visible_travel_options()
		if rows.is_empty(): label_at(Vector2(225,240),"No registered landmarks yet. Visit them on foot first.",18,TEAL)
		for i in rows.size():
			var row: Dictionary=rows[i]
			var r := Rect2(225,220+i*61,830,55)
			panel(r,Color("253748"))
			label_at(r.position+Vector2(12,22),"%d  Floor %d: %s" % [i+1,row.floor+1,display(row.name)],17,TEAL if row.reachable else MUTED)
			label_at(r.position+Vector2(12,44),"Safe route: skip %d walking / lift operations" % row.steps if row.reachable else str(row.get("reason","No safe walking route from here.")),14,MUTED)
		panel(Rect2(815,595,110,38),Color("253748"))
		label_at(Vector2(828,620),"PREV",14)
		panel(Rect2(935,595,110,38),Color("253748"))
		label_at(Vector2(948,620),"NEXT",14)
		label_at(Vector2(225,620),"[ / ]: pages    %d / %d" % [travel_page+1,maxi(1,ceili(travel_rows.size()/6.0))],14,MUTED)
	label_at(Vector2(225,662),"T: close / Esc: back. Viewing and selecting cost nothing.",15,MUTED)

func close_attunement():
	attuning=false; attune_pending=""; attune_gear=""
func open_attunement():
	cancel_walk()
	if attuning: close_attunement(); return
	if battle_time>0.0: return
	close_travel(); comparison=false; journal=false; book=false; growth=false; interaction=false
	winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""
	attune_gear=world.equipped if world.equipped!="balanced" else "buckler"; attune_pending=""; attuning=true
func cycle_attunement(delta: int):
	var ids: Array=["buckler","duelist","repeater","maul"]
	attune_gear=ids[posmod(ids.find(attune_gear)+delta,ids.size())]; attune_pending=""
func attunement_rows() -> Array:
	if not attuning: return []
	return world.attunement_offers(attune_gear)
func attunement_id(action_id: String) -> String:
	return action_id.trim_prefix("attune_"+attune_gear+"_")
func select_attunement(index: int):
	var rows: Array=attunement_rows()
	if index>=0 and index<rows.size(): attune_pending=rows[index][0]
func confirm_attunement():
	if attune_pending=="": return
	var valid := false
	for row in attunement_rows():
		if row[0]==attune_pending: valid=true
	if not valid: attune_pending=""; return
	if not world.attunement_preview(attunement_id(attune_pending),attune_gear).get("can_choose",false): return
	await perform_action(attune_pending)
	attune_pending=""
func attunement_click(mouse: Vector2):
	if not Rect2(195,70,890,660).has_point(mouse): close_attunement(); return
	if Rect2(785,122,120,38).has_point(mouse): cycle_attunement(-1); return
	if Rect2(925,122,120,38).has_point(mouse): cycle_attunement(1); return
	if attune_pending!="":
		if Rect2(225,585,390,48).has_point(mouse): confirm_attunement()
		elif Rect2(635,585,390,48).has_point(mouse): attune_pending=""
		return
	for i in attunement_rows().size():
		if Rect2(225,265+i*91,830,84).has_point(mouse): select_attunement(i); return
func attunement_effect(id: String) -> String:
	var mods: Dictionary=Attunement.modifiers(id)
	return "ATK %s / DEF %s / skill levels +%d" % [("+" if mods.atk>=0 else "")+str(mods.atk),("+" if mods.def>=0 else "")+str(mods.def),mods.levels]
func draw_attunement():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.72))
	panel(Rect2(195,70,890,660),Color("0c1928"))
	label_at(Vector2(225,112),"EQUIPMENT ATTUNEMENT / THIS RUN",24,GOLD)
	label_at(Vector2(225,147),Progression.GEAR[attune_gear].name,21,TEAL)
	panel(Rect2(785,122,120,38),Color("253748")); label_at(Vector2(797,148),"[ PREV",15)
	panel(Rect2(925,122,120,38),Color("253748")); label_at(Vector2(937,148),"NEXT ]",15)
	var current: String=world.gear_attunement(attune_gear)
	var info: Dictionary=world.skill_level_info() if attune_gear=="balanced" else world.attunement_preview(current,attune_gear).skill_level_info
	label_at(Vector2(225,179),"Skill level %d = base %d + training %d + equipment %d + strategy %d" % [info.effective,info.base,info.training,info.gear,info.get("strategy",0)],16)
	label_at(Vector2(225,206),"Only equipped modifiers apply; compare the trade-offs before locking." if attune_gear in world.inventory else "NOT OWNED: preview only. Claim this equipment before confirming.",14,MUTED)
	draw_wrapped(Vector2(225,232),world.skill_description() if attune_gear=="balanced" else world.attunement_preview(current,attune_gear).skill_description,820,15,TEAL,2)
	var rows: Array=attunement_rows()
	if attune_pending!="":
		var id: String=attunement_id(attune_pending)
		label_at(Vector2(225,300),Attunement.TEMPLATES[id].name if id!="none" else "Keep original equipment",23,GOLD)
		label_at(Vector2(225,336),attunement_effect(id),18)
		var candidate: Dictionary=world.attunement_preview(id,attune_gear).skill_level_info
		label_at(Vector2(225,373),"Candidate skill level: %d" % candidate.effective,18,TEAL)
		draw_wrapped(Vector2(225,407),world.attunement_preview(id,attune_gear).skill_description,810,17,TEAL,3)
		draw_wrapped(Vector2(225,493),"Confirm locks this equipment for this run, including keeping the original. U undoes the whole choice; offers never reroll.",810,17,GOLD,3)
		panel(Rect2(225,585,390,48),Color("345c62")); label_at(Vector2(240,616),"ENTER: CONFIRM CHOICE" if attune_gear in world.inventory else "NOT OWNED / READ ONLY",17)
		panel(Rect2(635,585,390,48),Color("253748")); label_at(Vector2(650,616),"ESC: BACK WITHOUT CHANGES",17)
	else:
		for i in rows.size():
			var id: String=attunement_id(rows[i][0])
			var r:=Rect2(225,265+i*91,830,84)
			panel(r,Color("203343"))
			label_at(r.position+Vector2(15,23),"%d  %s" % [i+1,rows[i][1]],18,GOLD)
			label_at(r.position+Vector2(360,23),attunement_effect(id),15,INK)
			var level: int=world.attunement_preview(id,attune_gear).skill_level_info.effective
			label_at(r.position+Vector2(15,46),"Candidate skill level: %d" % level,14,TEAL)
			draw_wrapped(r.position+Vector2(15,66),world.attunement_preview(id,attune_gear).skill_description,800,14,MUTED,1)
		if rows.is_empty():
			label_at(Vector2(225,280),Attunement.TEMPLATES[current].name if current!="none" else "Original equipment",20,GOLD)
			draw_wrapped(Vector2(225,310),"Traveler's kit cannot be attuned." if attune_gear=="balanced" else world.attunement_description(attune_gear),810,19,TEAL,5)
			label_at(Vector2(225,485),"Only owned equipment can be attuned, once per item per run.",17,MUTED)
	label_at(Vector2(225,684),"G / Esc closes. Viewing is free. Only equipped modifiers apply.",15,MUTED)

func open_comparison():
	cancel_walk()
	if comparison: comparison=false; return
	if battle_time>0.0 or book or journal or growth or interaction or travel_menu: return
	if not World.ENEMIES.has(world.tile(hover)): return
	compare_pos=hover; compare_floor=world.floor_index; compare_page=0; comparison=true
func comparison_rows() -> Array:
	var rows: Array=[]
	if compare_floor!=world.floor_index: return rows
	var kind: String=world.tile(compare_pos)
	if not World.ENEMIES.has(kind): return rows
	for id in world.inventory:
		var preview: Dictionary=world.battle_preview(kind,id,compare_pos)
		var alive: bool=preview.get("valid",false) and preview.get("survivable",false)
		rows.append({"id":id,"preview":preview,"after_hp":world.hp-int(preview.damage)+int(preview.get("heal_after",0)) if alive else -1})
	return rows
func draw_comparison():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.72))
	panel(Rect2(195,110,890,580),Color("0c1928"))
	label_at(Vector2(225,155),"EQUIPMENT FORECAST / READ ONLY",24,GOLD)
	var rows: Array=comparison_rows()
	if rows.is_empty():
		label_at(Vector2(225,210),"This enemy is no longer on the current floor.",18)
		return
	compare_page=clampi(compare_page,0,maxi(0,ceili(rows.size()/4.0)-1))
	if rows.size()>4:
		panel(Rect2(800,170,110,35),Color("253748")); label_at(Vector2(812,194),"PREV",14)
		panel(Rect2(920,170,110,35),Color("253748")); label_at(Vector2(932,194),"NEXT",14)
		label_at(Vector2(650,194),"Page %d   [ / ]" % (compare_page+1),13,GOLD)
	rows=rows.slice(compare_page*4,compare_page*4+4)
	label_at(Vector2(225,193),World.ENEMIES[world.tile(compare_pos)].name,21,TEAL)
	label_at(Vector2(225,225),"Same HP, talents, run strategy, oath and armed skill for every row.",16,MUTED)
	label_at(Vector2(225,252),"Armed skill included" if world.skill_armed and world.focus>0 else "No armed skill included",15,GOLD)
	label_at(Vector2(600,252),"Watch oath ACTIVE" if world.oath_state=="active" else ("Oath released permanently" if world.oath_state=="spent" else "No watch oath"),15,GOLD)
	label_at(Vector2(225,277),"Current position: flank barrier active" if rows[0].preview.get("flank_active",false) else "Current position: no flank barrier",14,TEAL)
	for i in rows.size():
		var row: Dictionary=rows[i]
		var preview: Dictionary=row.preview
		var y: int=316+i*73
		panel(Rect2(220,y-24,840,70),Color("203343"))
		label_at(Vector2(235,y),Progression.GEAR[row.id].name+(" [EQUIPPED]" if world.equipped==row.id else ""),18,GOLD)
		var status: String="Cannot penetrate defense" if not preview.get("valid",false) else ("LETHAL: no after-battle recovery" if row.after_hp<0 else "After battle: %d HP" % row.after_hp)
		label_at(Vector2(600,y),status,16,Color("ef928f") if row.after_hp<0 else TEAL)
		label_at(Vector2(235,y+25),"Loss %s / hero strikes %d / retaliations %d" % [str(int(preview.damage)) if preview.get("valid",false) else "--",int(preview.get("rounds",0)),int(preview.get("retaliations",0))],16,MUTED)
		label_at(Vector2(720,y+25),"Skill %d / %s" % [int(preview.get("skill_level",10)),Attunement.TEMPLATES[preview.attunement].name if preview.get("attunement","none")!="none" else "Original equipment"],13,TEAL)
		if preview.get("valid",false): label_at(Vector2(235,y+42),world.victory_reward_text(preview),12,TEAL)
	label_at(Vector2(225,615),"No equipment changes here. Compare trade-offs, then choose in C.",16,TEAL)
	label_at(Vector2(225,655),"V / Esc / click outside closes. Reading spends nothing.",15,MUTED)
func chapter_button() -> Rect2:
	return Rect2(395,465,490,55)
func draw_victory():
	panel(Rect2(365,245,550,430),Color("0c1928"))
	label_at(Vector2(395,310),"THE SKY IS OPEN" if not world.expedition_started else "THE EXPEDITION IS COMPLETE",25,GOLD)
	label_at(Vector2(395,352),"The final seal has fallen.",18)
	label_at(Vector2(395,389),"%d HP left  /  %d moves  /  %d gold" % [world.hp,world.moves,world.gold],17,TEAL)
	var offers: Array=world.chapter_offers()
	if not offers.is_empty():
		label_at(Vector2(395,432),"Your victory is saved. Continuing is optional.",16,TEAL)
		panel(chapter_button(),Color("253748"))
		label_at(Vector2(408,498),"1  Continue: 3 more floors / +120 HP",18,GOLD)
		label_at(Vector2(395,550),"Keep your hero, gold and old floors. No new loan.",15,MUTED)
	else: label_at(Vector2(395,480),"Both chapters are complete. Your journey is saved.",16,TEAL)
	panel(Rect2(395,575,490,48),Color("253748"))
	label_at(Vector2(408,606),"2  Finish chapter one and record" if not world.expedition_started else "2  Settle final victory",18,GOLD)
	label_at(Vector2(395,650),"Nothing is settled until you explicitly confirm.",15,MUTED)
func draw_token(c: Vector2, t: String):
	if MAP_ENEMY_ART.has(t) and map_art.has(MAP_ENEMY_ART[t]):
		draw_texture_rect(map_art[MAP_ENEMY_ART[t]],Rect2(c-Vector2(30,30),Vector2(60,60)),false)
		draw_rect(Rect2(c-Vector2(29,29),Vector2(58,58)),Color("ce7971"),false,1)
		var enemy: Dictionary=World.ENEMIES[t]
		var markers: String=("!" if enemy.get("first_strike",false) else "")+("*" if enemy.get("thorns",0)>0 else "")+("3" if enemy.get("heavy_every",0)>0 else "")
		if markers!="":
			draw_rect(Rect2(c+Vector2(-29,13),Vector2(10+markers.length()*12,18)),Color("351a25"))
			label_at(c+Vector2(-25,27),markers,14,GOLD)
		return

	var npc_art: String={"J":"ilen","t":"mira"}.get(t,"")
	if map_art.has(npc_art):
		draw_texture_rect(map_art[npc_art],Rect2(c-Vector2(30,30),Vector2(60,60)),false)
		draw_rect(Rect2(c-Vector2(29,29),Vector2(58,58)),TEAL,false,1)
		return
	if combat_art.has(npc_art):
		draw_texture_rect(combat_art[npc_art],Rect2(c-Vector2(28,28),Vector2(56,56)),false)
		return
	if ENEMY_ART.has(t) and combat_art.has(ENEMY_ART[t]):
		draw_texture_rect(combat_art[ENEMY_ART[t]],Rect2(c-Vector2(28,28),Vector2(56,56)),false)
		if t in ["u","b"]:
			label_at(c+Vector2(11,-10),"!" if t=="u" else "*",16,GOLD)
		return
	if t in ["v","m"] and combat_art.has("winch" if t=="v" else "maul"):
		draw_texture_rect(combat_art["winch" if t=="v" else "maul"],Rect2(c-Vector2(28,28),Vector2(56,56)),false)
		return
	match t:
		"n","e":
			var opened: bool=world.winch_choice==("rescue" if t=="n" else "armory")
			var color: Color=TEAL if opened else Color("e59680")
			draw_rect(Rect2(c-Vector2(17,21),Vector2(34,42)),color,false,3)
			if not opened:
				for i in range(3): draw_line(c+Vector2(-10+i*10,-18),c+Vector2(-10+i*10,18),color,3)
			label_at(c+Vector2(-6,6),t,15,color)
		"k":
			draw_circle(c+Vector2(-6,0),6,GOLD,false,3); draw_line(c,c+Vector2(13,0),GOLD,3); draw_line(c+Vector2(10,0),c+Vector2(10,6),GOLD,3)
		"D","L":
			draw_rect(Rect2(c-Vector2(15,19),Vector2(30,38)),Color("725735")); draw_rect(Rect2(c-Vector2(11,15),Vector2(22,30)),GOLD,false,2); draw_circle(c,3,Color("171d27"))
			label_at(c+Vector2(-22,25),"2" if t=="L" else "1",18,GOLD)
			if t=="L":
				draw_circle(c+Vector2(-6,0),3,Color("171d27")); draw_circle(c+Vector2(6,0),3,Color("171d27"))
				label_at(c+Vector2(10,-12),"2",12,GOLD)
		"$","A","P":
			var chest_color: Color={"$":GOLD,"A":Color("f08598"),"P":TEAL}[t]
			draw_rect(Rect2(c-Vector2(17,12),Vector2(34,28)),chest_color.darkened(0.65))
			draw_rect(Rect2(c-Vector2(17,12),Vector2(34,28)),chest_color,false,2)
			draw_line(c+Vector2(-17,-3),c+Vector2(17,-3),chest_color,2)
			label_at(c+Vector2(-6,12),t,17,chest_color)
		"a","d":
			var col := Color("f08598") if t=="a" else Color("80b9f4")
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-14),c+Vector2(10,0),c+Vector2(0,14),c+Vector2(-10,0)]),col)
		"h":
			draw_circle(c+Vector2(0,4),11,Color("7ce0bf")); draw_rect(Rect2(c-Vector2(5,13),Vector2(10,14)),Color("b2ead9")); draw_line(c+Vector2(-4,3),c+Vector2(4,3),Color("e5fff5"),2)
		"s","g","u","b","w","B","V","K","Z","H","W":
			var col: Color = {"s":Color("8fc57f"),"g":Color("b5a2e1"),"u":Color("87b9dc"),"b":Color("9dcc83")}.get(t,Color("ed987d"))
			draw_circle(c,15 if t in ["s","g","u","b"] else 19,col)
			draw_circle(c+Vector2(-5,-2),3,Color("132330")); draw_circle(c+Vector2(5,-2),3,Color("132330"))
			if t in ["u","b"]: label_at(c+Vector2(12,-12),"!" if t=="u" else "*",16,GOLD)
			if t in ["B","V","K","Z"]:
				for i in range(3): draw_line(c+Vector2(-10+i*10,-14),c+Vector2(-10+i*10,-22),GOLD,4)
		"M","C","E","F","T","N","Q","J","I","O","R","X","U","Y","t","v","m":
			var color := GOLD if t in ["M","T","C"] else TEAL
			draw_rect(Rect2(c-Vector2(16,16),Vector2(32,32)),color.darkened(0.65))
			draw_rect(Rect2(c-Vector2(16,16),Vector2(32,32)),color,false,2)
			label_at(c+Vector2(-7,7),t,21,color)
		"=":
			draw_rect(Rect2(c-Vector2(23,23),Vector2(46,46)),Color("0a101c"))
			if world.expedition_bridge:
				for i in range(5): draw_line(c+Vector2(-21,-16+i*8),c+Vector2(21,-16+i*8),GOLD,5)
			else: label_at(c+Vector2(-10,7),"=",23,MUTED)
		"~":
			draw_rect(Rect2(c-Vector2(23,23),Vector2(46,46)),Color("123e62"))
			for i in range(3):
				var shift := sin(tick*2+i)*3
				draw_line(c+Vector2(-17+shift,-12+i*11),c+Vector2(17+shift,-12+i*11),Color("6ac9de"),2)
			if world.bridge_built:
				draw_line(c+Vector2(-18,-20),c+Vector2(-18,20),GOLD,3)
				draw_line(c+Vector2(18,-20),c+Vector2(18,20),GOLD,3)
				for plank in range(5): draw_line(c+Vector2(-18,-16+plank*8),c+Vector2(18,-16+plank*8),Color("ba9563"),5)
		"<",">":
			for i in range(4):
				draw_rect(Rect2(c+Vector2(-23,16-i*9),Vector2(30-i*5,6)),TEAL)
			var d: float=-1.0 if t==">" else 1.0
			draw_line(c+Vector2(17,-d*14),c+Vector2(17,d*17),GOLD,4)
			draw_line(c+Vector2(17,d*17),c+Vector2(9,d*9),GOLD,4)
			draw_line(c+Vector2(17,d*17),c+Vector2(25,d*9),GOLD,4)
func enemy_traits(enemy: Dictionary, compact:=false) -> Array:
	var traits: Array=[]
	if enemy.get("first_strike",false): traits.append("First strike" if compact else "Strikes first, even if you one-shot it.")
	if int(enemy.get("thorns",0))>0: traits.append(("Thorns %d" if compact else "%d thorns per hit, including the final hit.") % int(enemy.thorns))
	if int(enemy.get("heavy_every",0))>0: traits.append("Charge / 3" if compact else "Every 3rd retaliation doubles; feint counts.")
	if traits.is_empty() and not compact: traits.append("Normal retaliation after your attacks.")
	return traits
func draw_book():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(235,105,810,610),Color("0c1928"))
	label_at(Vector2(265,145),"THE TRAVELER'S FIELD GUIDE",24,GOLD)
	var kinds: Array=[]
	for kind in World.ENEMIES:
		if kind!="B": kinds.append(kind)
	book_page=clampi(book_page,0,maxi(0,ceili(kinds.size()/6.0)-1))
	var visible_kinds: Array=kinds.slice(book_page*6,book_page*6+6)
	if kinds.size()>6:
		panel(Rect2(760,115,120,40),Color("253748")); label_at(Vector2(772,141),"PREV",14)
		panel(Rect2(885,115,140,40),Color("253748")); label_at(Vector2(898,141),"NEXT",14)
		label_at(Vector2(665,145),"Page %d   [ / ]" % (book_page+1),12,TEAL)
	for i in visible_kinds.size():
		var kind: String=visible_kinds[i]
		var e: Dictionary=World.ENEMIES[kind]
		var p := Vector2(265+(i%2)*390,185+floori(i/2.0)*97)
		draw_token(p+Vector2(15,10),kind)
		label_at(p+Vector2(48,0),e.name,18,GOLD)
		label_at(p+Vector2(48,24),"HP %d / ATK %d / DEF %d" % [e.hp,e.atk,e.def],14,INK)
		var traits: Array=enemy_traits(e)
		for t in traits.size(): label_at(p+Vector2(48,44+t*14),traits[t],12,TEAL)

	var lines := ["Exact forecasts include ambush, thorns, gear, skills and talents.","Thorns ignores DEF. Brace and total-loss reduction still apply.","C: hero / gear / talents. E: local choices, quests and ledger.","J: researcher / I: sample / O: valve / R: relic / X: encounter.","Interest: first entry to floors 4 and 5 only, never steps or waiting.","Grow stronger and revisit. U reverses the entire previous action.","L: 2-key lock / $: +60 gold / A: +5 ATK / P: +140 HP, +1 focus.","H / Esc / click closes. Battles are cosmetic replays; any key skips."]
	for i in lines.size(): label_at(Vector2(265,505+i*27),lines[i],15,MUTED)
func token_name(t: String) -> String:
	if t=="v": return "Winch: rescue shortcut OR siege maul armory"
	if t=="m": return "Siege maul: double hits, double counters; -4 DEF"
	if t=="n": return "North rescue gate: open" if world.winch_choice=="rescue" else "North rescue gate: sealed"
	if t=="e": return "Siege maul armory: open" if world.winch_choice=="armory" else "Siege maul armory: sealed"
	if t=="~" and world.bridge_built: return "Survey bridge: cross safely above the water"
	if t=="~" and world.water_choice=="drain": return "Drained passage to the relic vault"
	if t=="X": return world.event_title()
	if t=="=": return "Expedition bridge: open" if world.expedition_bridge else "Broken bridge: engineering unlocks a shortcut"
	return {"t":"Mira: the missing apprentice","U":"Expedition camp: finite tactical supplies","Y":"Engineering station: inspect local options","M":"Merchant: calibration needs a powered lift","C":"Core: lift powers calibration; forge/sale forfeits it","E":"The old elevator","F":"Workshop: a lasting choice","T":"A treasure worth returning for","N":"An inscription. Read carefully.","Q":"A door with a secret","<":"Return to a lower floor",">":"Ascend: check your ledger","a":"Ruby: +5 attack","d":"Sapphire: +4 defense","h":"Spring water: +70 HP","k":"Gold key","D":"Gold door: costs 1 key","L":"Double lock: costs 2 keys","$":"Gold cache: +60 gold","A":"Blade relic: +5 attack","P":"Supplies: +140 HP / +1 focus","J":"Ilen: cartographer and mentor","I":"An unusual research sample","O":"Drain the route or keep the spring?","~":"Deep water blocks this route","R":"A choice of equipment","X":"A costly opportunity"}.get(t,"SCOUT BEFORE YOU STRIKE")
func nearby(t: String) -> bool:
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if world.tile(world.pos+d)==t: return true
	return false
func available_actions() -> Array:
	if winch_pending!="": return [["winch_confirm","Confirm permanent winch choice"],["winch_cancel","Cancel: leave both options undecided"]]
	var rows: Array = []
	if checkpoint_pending!=Vector2i.ZERO:
		rows.append(["continue","Spend keys and open this door" if pending_reason=="door" else "Continue upstairs: settle interest now"])
		rows.append(["cancel","Cancel: keep all keys" if pending_reason=="door" else "Stay on this floor: no interest charged"])
		if pending_reason=="door": return rows
	if world.debt()>0: rows.append(["repay","Repay using available gold (fees, interest, principal)"])
	rows.append_array(world.camp_offers())
	rows.append_array(world.npc_offers())
	rows.append_array(world.oath_offers())
	rows.append_array(world.audit_offers())
	rows.append_array(world.winch_offers())
	if nearby("M"):
		if (world.seal_clues & 1)==0: rows.append(["seal_contract","Read the old contract: calibration clue / lift power required"])
		rows.append(["buy","Buy armor-breaker: 60 gold / +12 ATK (once)"])
		rows.append(["borrow","Borrow 40 gold: 2 fee / 10% per new milestone"])
		rows.append(["sell_core","Sell core: +35 gold / PERMANENTLY forfeit lift and calibration"])
	if nearby("E"):
		rows.append(["elevator","Use core: repair elevator / excludes forge & sale"])
		rows.append(["travel","Ride repaired elevator: floors 1 <-> 3"])
	if nearby("F"):
		rows.append(["forge","Forge core: +8 DEF / PERMANENTLY forfeit lift and calibration"])
		if not world.bridge_built:
			rows.append(["quest_bridge","Spend survey (I): bridge on floor 2 / no J reward; no core"])
	if nearby("O") and (world.seal_clues & 2)==0: rows.append(["seal_water","Read the valve plate: calibration clue / no water spent"])
	if nearby("N") and (world.seal_clues & 4)==0: rows.append(["seal_inscription","Read the inscription: calibration clue"])
	if nearby("Q"):
		if world.seal_solved and world.seal_reward=="":
			rows.append(["secret_provisions","Choose provisions: +80 HP and 1 key / forgo voucher"])
			rows.append(["secret_voucher","Choose 50 voucher: repay %d / receive %d gold" % [mini(50,world.debt()),maxi(0,50-world.debt())]])
		elif world.riddle_ready():
			rows.append_array(world.riddle_options())
			if not world.seal_input.is_empty():
				rows.append(["secret_backspace","Erase the last symbol"])
				rows.append(["secret_reset","Clear all four slots"])

	if nearby("J"):
		if world.quest_state==0: rows.append(["quest_accept","Accept: find survey / choose J rewards or F flood bridge"])
		if world.quest_state==2:
			rows.append(["quest_gold","Spend survey: +45 gold / give up focus training AND bridge"])
			rows.append(["quest_scroll","Spend survey: focus cap 4 + refill / give up gold AND bridge"])
	if nearby("O") and world.water_choice=="":
		if not world.bridge_built: rows.append(["drain","Drain the water: open a route / give up the spring"])
		rows.append(["spring","Use spring: +120 HP / bridge remains open" if world.bridge_built else ("Use spring: +120 HP / survey spent; route stays flooded" if world.quest_state==3 else "Use spring: +120 HP / survey bridge can still open route")])
	if nearby("R") and not world.chest_claimed:
		rows.append(["relic_buckler","Buckler: +6 DEF / -4 ATK; blocks first enemy hit"])
		rows.append(["relic_duelist","Duelist: +6 ATK / -3 DEF / pierce 8; EXTRA opening retaliation"])
	if nearby("X") and not world.event_done:
		rows.append_array(world.event_offers())
	return rows
func visible_actions() -> Array:
	var rows := available_actions()
	interaction_page=clampi(interaction_page,0,maxi(0,ceili(rows.size()/6.0)-1))
	return rows.slice(interaction_page*6,interaction_page*6+6)
func action_label(rect: Rect2, source: String):
	var text: String=display(source)
	var limit: float=rect.size.x-24
	if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x<=limit:
		label_at(rect.position+Vector2(12,24),text,16)
		return
	var cut: int=text.length()-1
	while cut>1 and font.get_string_size(text.left(cut),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>limit: cut-=1
	if language=="en":
		var space: int=text.rfind(" ",cut)
		if space>0: cut=space
	label_at(rect.position+Vector2(12,15),text.left(cut),14)
	label_at(rect.position+Vector2(12,31),text.substr(cut).strip_edges(),14)
func draw_interaction():
	if winch_pending!="":
		draw_winch_confirmation()
		return
	if nearby("Q") and pending_reason=="":
		draw_calibration()
		return
	if pending_reason=="door":
		draw_key_confirmation()
		return
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	var audit_context: bool=nearby("Y") and pending_reason=="" and checkpoint_pending==Vector2i.ZERO
	var inscription_context: bool=nearby("N") and pending_reason=="" and checkpoint_pending==Vector2i.ZERO
	label_at(Vector2(290,158),"INSCRIPTION & OATH" if inscription_context else ("ENGINEER & SUPPLY LABELS" if audit_context else world.event_title().to_upper() if nearby("X") and not world.event_done else "CHOICES & THE LEDGER"),25,GOLD)
	label_at(Vector2(290,190),"Gold %d   |   Debt %d   |   Core: %s" % [world.gold,world.debt(),"held" if world.core else (world.core_use if world.core_use!="" else "none")],18,TEAL)
	label_at(Vector2(290,218),("Watch oath ACTIVE" if world.oath_state=="active" else ("Oath released permanently" if world.oath_state=="spent" else "No watch oath")) if inscription_context else "J: review discovered labels and the explanation." if audit_context else "Principal %d  +  fees %d  +  interest %d" % [world.principal,world.fees,world.interest],16)
	var terms := ["Borrow once, before floor 4. Receive 40; owe 42. Max total 50.","First entry to floors 4 and 5: ceil(remaining principal x 10%).", "No compound interest. Walking, waiting & backtracking cost nothing.", "After maturity: debt freezes; future gold repays it. No new loans.", "Repay early to reduce interest. No real money. Debt ends with this run."]
	if inscription_context:
		terms=["Clues and oaths are independent. Reading costs no resources."]
	elif audit_context and world.audit_read:
		terms=world.audit_lines().slice(4) if world.audit_solved else world.audit_lines()
	elif nearby("U") or nearby("Y"):
		terms=["Camp stock is finite and shared across all three new floors.","Medicine is used immediately. Focus purchases require missing focus.","Roadworks open all expedition bridges once; old water is unchanged.","Bridges bypass guards, but also their gold and kill rewards.","You may return for supplies or fight bypassed guards later."]
	for i in terms.size(): label_at(Vector2(290,248+i*23),terms[i],15,MUTED)
	if checkpoint_pending!=Vector2i.ZERO:
		label_at(Vector2(290,369),"ASCENDING NOW: +%d interest. Choose below." % ceili(world.principal*0.1),16,GOLD)
	action_rows=visible_actions()
	if action_rows.is_empty():
		label_at(Vector2(290,405),"Stand beside a marked object or NPC to interact.",18,TEAL)
	for i in action_rows.size():
		var r := Rect2(285,375+i*43,720,37)
		panel(r,Color("253748"))
		action_label(r,"%d  %s" % [i+1,action_rows[i][1]])
	label_at(Vector2(290,640),display(status_message()).left(100),14,TEAL)
	if available_actions().size()>6:
		label_at(Vector2(815,218),"Page %d   [ / ]" % (interaction_page+1),13,GOLD)
	label_at(Vector2(290,672),"Click a choice or press its number. E / Esc closes without choosing.",14,MUTED)
func draw_calibration():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	label_at(Vector2(290,158),"OLD TOWER CALIBRATION",25,GOLD)
	label_at(Vector2(290,190),"Read M / O / N clues; power the lift with the core.",16,TEAL)
	var hint := "Four unique symbols. The fourth entry checks the order; mistakes cost nothing."
	if world.core_use in ["forge","sold"]: hint="Calibration forfeited: the core was forged or sold this run."
	elif world.seal_solved: hint="Calibration solved. Choose ONE reward; the other is forgone."
	elif not world.riddle_ready(): hint="Not ready: read all three clues and repair the old lift."
	label_at(Vector2(290,218),hint,15,GOLD)
	label_at(Vector2(290,248),"J: review only your discovered clues. E / Esc: leave without changing the input.",14,MUTED)
	for i in range(4):
		var slot := Rect2(290+i*175,275,160,63)
		panel(slot,Color("253748"))
		var symbol: String=World.Riddle.SYMBOLS.get(world.seal_input[i],"?") if i<world.seal_input.size() else "---"
		label_at(slot.position+Vector2(12,38),"%d  %s" % [i+1,symbol],20,TEAL)
	label_at(Vector2(290,361),"Repeated symbols are unavailable. Backspace and clear are safe.",14,MUTED)
	action_rows=visible_actions()
	for i in action_rows.size():
		var r := Rect2(285,375+i*43,720,37)
		panel(r,Color("253748"))
		action_label(r,"%d  %s" % [i+1,action_rows[i][1]])
	label_at(Vector2(290,640),display(status_message()).left(100),14,TEAL)
	label_at(Vector2(290,672),"Click a choice or press its number. E / Esc closes without choosing.",14,MUTED)
func draw_key_confirmation():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	var cost := 2 if world.tile(world.pos+checkpoint_pending)=="L" else 1
	label_at(Vector2(290,158),"SPEND KEYS?",25,GOLD)
	label_at(Vector2(290,205),"%s: costs %d gold keys" % ["Double lock" if cost==2 else "Gold door",cost],22,INK)
	label_at(Vector2(290,248),"Held: %d   /   Remaining after opening: %d" % [world.keys,world.keys-cost],20,TEAL)
	label_at(Vector2(290,292),"Keys are limited. Double-lock rooms need TWO keys.",17,GOLD)
	label_at(Vector2(290,325),"A shortcut now can cost a treasure later. You can cancel or return.",16,MUTED)
	var rows := available_actions()
	for i in rows.size():
		var r := Rect2(285,375+i*43,720,37)
		panel(r,Color("253748"))
		label_at(r.position+Vector2(12,24),"%d  %s" % [i+1,rows[i][1]],16)
	label_at(Vector2(290,580),"U restores the opened door, your keys and your position together.",15,MUTED)
	label_at(Vector2(290,640),"Nothing is spent until you confirm.",16,TEAL)
	label_at(Vector2(290,672),"Click a choice / press 1-2. E / Esc cancels.",14,MUTED)
func draw_winch_confirmation():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	label_at(Vector2(290,158),"ONE WINCH / ONE PERMANENT CHOICE",24,GOLD)
	var lines: Array=["Open the north rescue gate.","Reach Mira without fighting the Archive Gaoler.","The siege maul armory stays sealed for this run."] if winch_pending=="winch_rescue" else ["Open the siege maul armory.","The north rescue shortcut stays sealed for this run.","Mira can still be rescued by defeating the Archive Gaoler."]
	if winch_pending=="winch_armory" and world.winch_offers().size()==1:
		lines=["Open the siege maul armory."]
	for i in lines.size(): label_at(Vector2(290,220+i*38),lines[i],18,TEAL if i==0 else INK)
	label_at(Vector2(290,345),"No cost until confirmed. U can undo the complete action.",15,MUTED)
	action_rows=visible_actions()
	for i in action_rows.size():
		var rect := Rect2(285,375+i*43,720,37)
		panel(rect,Color("253748")); action_label(rect,"%d  %s" % [i+1,action_rows[i][1]])
	label_at(Vector2(290,672),"Click a choice / press 1-2. E / Esc cancels.",14,MUTED)
func perform_action(id: String, confirmed:=false):
	if not can_mutate(): return
	cancel_walk()
	if id=="winch_cancel": winch_pending=""; return
	if id=="winch_confirm":
		var choice: String=winch_pending
		winch_pending=""
		if choice!="": await perform_action(choice,true)
		return
	if id in ["winch_rescue","winch_armory"] and not confirmed:
		winch_pending=id; interaction=true; interaction_page=0
		return
	if id=="cancel":
		checkpoint_pending=Vector2i.ZERO; pending_reason=""; interaction=false; winch_pending=""; return
	if id=="continue":
		var direction := checkpoint_pending
		checkpoint_pending=Vector2i.ZERO; pending_reason=""; interaction=false; winch_pending=""
		await move(direction,true)
		return
	reset_armed=false
	var result: Dictionary=await session.action(id)
	apply_session_result(result)
func action_effect(id: String):
	if id=="expedition":
		book=false; journal=false; growth=false; interaction=false; winch_pending=""; battle_time=0.0
		checkpoint_pending=Vector2i.ZERO; pending_reason=""
	if id in ["spring","drain","quest_bridge","camp_bridge"]: play_sound("water")
	elif id in ["expedition","camp_medicine","camp_focus","rescue_repeater","rescue_supplies","buy","quest_gold","quest_scroll","relic_buckler","relic_duelist","secret","secret_provisions","secret_voucher","audit_medicine"]: play_sound("pickup")
	if id.begins_with("hero_") or id.begins_with("talent_"): growth=false
func quest_hint() -> String:
	return ["J: find the researcher's request","QUEST: seek the sample (I)","SURVEY: J reward or F bridge","SURVEY: delivered to J","SURVEY: flood bridge built"][clampi(world.quest_state,0,4)]
func skill_description() -> String:
	return world.skill_description()
func growth_actions() -> Array:
	var rows: Array=[]
	match growth_tab:
		0:
			if world.moves==0:
				for id in Progression.HEROES:
					rows.append(["hero_"+id,Progression.HEROES[id].name,Progression.HEROES[id].description])
			else:
				rows.append(["mend" if world.hero_id=="scholar" else "arm",Progression.HEROES[world.hero_id].skill+(" (cancel armed skill)" if world.skill_armed else " / 1 focus"),skill_description()])
		1:
			for id in world.inventory:
				if Progression.GEAR.has(id): rows.append(["equip_"+id,Progression.GEAR[id].name+(" [EQUIPPED]" if world.equipped==id else ""),Progression.GEAR[id].description])
		2:
			for id in Progression.talent_options(world.kills,world.talents): rows.append(["talent_"+id,Progression.TALENTS[id].name,Progression.TALENTS[id].description])
	return rows
func visible_growth_actions() -> Array:
	var rows: Array=growth_actions()
	if growth_tab!=1: return rows
	gear_page=clampi(gear_page,0,maxi(0,ceili(rows.size()/3.0)-1))
	return rows.slice(gear_page*3,gear_page*3+3)
func open_growth():
	close_attunement()
	cancel_walk()
	comparison=false
	growth=not growth; journal=false; interaction=false; winch_pending=""; book=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
	if growth: growth_tab=2 if not Progression.talent_options(world.kills,world.talents).is_empty() else 0
func draw_growth():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.72))
	panel(Rect2(195,80,890,650),Color("0c1928"))
	label_at(Vector2(225,120),"THE HERO'S PATH",26,GOLD)
	label_at(Vector2(225,150),"%s  /  Focus %d  /  Kills %d  /  Seed %d" % [Progression.HEROES[world.hero_id].name,world.focus,world.kills,world.seed_value],17,TEAL)
	for i in 3:
		var r := Rect2(225+i*270,175,250,40)
		panel(r,Color("345c62") if growth_tab==i else Color("253748"))
		label_at(r.position+Vector2(15,26),["HERO & SKILL","EQUIPMENT","TALENTS"][i],17)
	var subtitle: String = ["Choose before your first action. Later: use your hero's skill.","Switch owned gear freely. Check the battle forecast after switching.","One choice at 3 / 7 / 12 kills. Each tier's choices are exclusive."][growth_tab]
	label_at(Vector2(225,245),subtitle,16,MUTED)
	var rows := visible_growth_actions()
	for i in rows.size():
		var r := Rect2(225,270+i*87,830,76)
		panel(r,Color("203343"))
		label_at(r.position+Vector2(15,27),"%d  %s" % [i+1,rows[i][1]],19,GOLD)
		var description: String=display(rows[i][2])
		var description_width := 725.0 if growth_tab==0 else 790.0
		if font.get_string_size(description,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>description_width:
			var split_at := description.length()-1
			while split_at>1 and font.get_string_size(description.left(split_at),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>description_width: split_at-=1
			if language=="en":
				var space_at := description.rfind(" ",split_at)
				if space_at>0: split_at=space_at
			label_at(r.position+Vector2(15,47),description.left(split_at),14,INK)
			label_at(r.position+Vector2(15,66),description.substr(split_at).strip_edges(),14,INK)
		else: label_at(r.position+Vector2(15,56),description,15,INK)
		if growth_tab==0:
			var portrait: String=rows[i][0].trim_prefix("hero_") if rows[i][0].begins_with("hero_") else world.hero_id
			if combat_art.has(portrait): draw_texture_rect(combat_art[portrait],Rect2(r.position+Vector2(750,3),Vector2(70,70)),false)
	if growth_tab==2:
		var learned: Array=[]
		for id in world.talents: learned.append(Progression.TALENTS[id].name)
		label_at(Vector2(225,565),"Learned: "+(", ".join(learned) if not learned.is_empty() else "none yet"),15,TEAL)
		if rows.is_empty(): label_at(Vector2(225,300),"No new choice yet. Defeat foes and return.",18,INK)
	if growth_tab==1:
		panel(Rect2(225,548,285,38),Color("345c62")); label_at(Vector2(240,574),"G: ATTUNE / PREVIEW GEAR",15,GOLD)
		if growth_actions().size()>3:
			panel(Rect2(780,548,120,38),Color("253748")); label_at(Vector2(792,574),"PREV",14)
			panel(Rect2(915,548,120,38),Color("253748")); label_at(Vector2(927,574),"NEXT",14)
			label_at(Vector2(530,574),"Page %d   [ / ]" % (gear_page+1),14,TEAL)
		if world.equipped=="duelist": label_at(Vector2(225,610),"DUELIST COST: one EXTRA opening retaliation, even on a one-shot kill.",15,Color("ef928f"))
	else: label_at(Vector2(225,610),"Focus is finite. First visits restore it; repeating floors cannot farm it.",15,MUTED)
	label_at(Vector2(225,646),display(status_message()).left(105),14,TEAL)
	label_at(Vector2(225,697),"Choose 1-3. Tab changes section. Esc: keep default Warden." if world.moves==0 else "Click a card / press 1-3. Tab changes section. C / Esc closes.",15,MUTED)
func open_journal():
	close_attunement()
	cancel_walk()
	comparison=false
	journal=not journal
	journal_page=0
	book=false; growth=false; interaction=false; winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""
func floor_has(index: int, token: String) -> bool:
	for row in world.floors[index]:
		if token in row: return true
	return false
func journal_lines() -> Array:
	var entries: Array=[]
	entries.append("Seed %d / %s / floor %d / %d steps" % [world.seed_value,Progression.HEROES[world.hero_id].name,world.floor_index+1,world.moves])
	if world.rescue_state in [1,2]: entries.append_array(world.npc_journal())
	entries.append_array(world.oath_journal())
	entries.append_array(world.audit_journal())
	entries.append_array(world.audit_lines())
	entries.append_array(world.winch_journal())
	entries.append_array(world.attunement_journal())
	if not strategy_pending():
		var strategy: Dictionary=world.strategy_preview(world.current_strategy())
		if strategy.get("valid",false): entries.append("Run strategy: %s. %s" % [strategy.name,strategy.description])
	if world.expedition_started:
		entries.append("Chapter II: supplies are finite; old floors remain available.")
		entries.append("Camp stock: medicine %d / focus %d. Bridges: %s." % [world.camp_medicine_left,world.camp_focus_left,"open" if world.expedition_bridge else "closed"])
	entries.append("Gold %d / debt %d = principal %d + fee %d + interest %d" % [world.gold,world.debt(),world.principal,world.fees,world.interest])
	if world.debt()==0:
		entries.append("No outstanding debt. Walking and waiting never incur interest.")
	elif world.checkpoints<2:
		entries.append("Next interest: first entry to floor %d, +%d at current principal." % [4+world.checkpoints,ceili(world.principal*0.1)])
	else:
		entries.append("Debt is frozen. Future gold repays it until the balance is clear.")
	if world.core:
		entries.append("Core held: lift powers calibration; forge or sale permanently forfeits it.")
	elif world.core_use!="":
		entries.append({"elevator":"Core used for lift. Forge and sale are forgone.","forge":"Core forged: +8 DEF. Lift and sale are forgone.","sold":"Core sold: +35 gold. Lift and forge are forgone."}[world.core_use])
	else: entries.append("No mechanism core in your pack.")
	if world.floor_seen[1]:
		entries.append({"":"Floor 2: spring still available." if world.bridge_built else "Floor 2: the water decision is still open.","drain":"Floor 2 drained: relic route opened; spring healing forgone.","spring":"Floor 2 spring used: +120 HP; bridge open." if world.bridge_built else ("Floor 2 spring used: survey spent at J; relic route stays flooded." if world.quest_state==3 else "Floor 2 spring used: +120 HP; a survey bridge can still open the route.")}[world.water_choice])
	if world.bridge_built: entries.append("Survey bridge built: floor 2 water is walkable; core unchanged.")
	entries.append(["No research task accepted.","Find the survey (I): J rewards or F flood bridge, choose once.","Survey held: J = gold / focus; F = bridge preserving spring (no core).","Survey spent at J: alternative reward and flood bridge forgone.","Survey spent at F: bridge built; both researcher rewards forgone."][world.quest_state])
	if world.floor_seen[2]:
		if floor_has(2,"V"): entries.append("Floor 3: a powerful guardian still watches the star vault.")
		elif floor_has(2,"T"): entries.append("Floor 3: the guardian is defeated; its treasure is unclaimed.")
		else: entries.append("Floor 3: the star vault treasure has been claimed.")
	if world.floor_seen[3]:
		entries.append("Floor 4: %s / %s" % [world.event_title(),"resolved" if world.event_done else "decision still open"])
	for floor_index in [0,2,3]:
		if not world.floor_seen[floor_index]: continue
		var token: String={0:"$",2:"A",3:"P"}[floor_index]
		if floor_has(floor_index,token):
			var reward: String={"$":"60 gold","A":"+5 ATK","P":"+140 HP and +1 focus"}[token]
			entries.append("Floor %d cache: %s / %s." % [floor_index+1,reward,"double lock needs 2 keys" if floor_has(floor_index,"L") else "unclaimed, lock already opened"])
	for clue_line in world.riddle_clues(): entries.append(clue_line)
	if world.seal_solved: entries.append("Old tower calibration solved.")
	if world.seal_reward!="": entries.append("Calibration reward: %s" % world.seal_reward)
	if world.core_use in ["forge","sold"]: entries.append("Calibration forfeited: the core was forged or sold this run.")
	if world.secret: entries.append("The bell's secret has been found.")
	var names: Array=[]
	for id in world.talents: names.append(Progression.TALENTS[id].name)
	if world.rescue_state not in [1,2]: entries.append_array(world.npc_journal())
	entries.append("Talents: "+(", ".join(names) if not names.is_empty() else "none chosen"))
	entries.append("Equipped: "+Progression.GEAR[world.equipped].name+". "+Progression.GEAR[world.equipped].description)
	entries.append("Focus %d/%d: +1 on first entry to a floor; revisits give none." % [world.focus,world.focus_cap])
	var lines: Array=[]
	for entry in entries:
		var remaining: String=display(entry)
		while font.get_string_size(remaining,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>740:
			var split_at := mini(86,remaining.length()-1)
			while split_at>1 and font.get_string_size(remaining.left(split_at),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>730: split_at-=1
			if language=="en":
				var space_at := remaining.rfind(" ",split_at)
				if space_at>0: split_at=space_at
			lines.append(remaining.substr(0,split_at))
			remaining=remaining.substr(split_at).strip_edges()
		lines.append(remaining)
	return lines
func draw_journal():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.72))
	panel(Rect2(230,100,820,610),Color("0c1928"))
	label_at(Vector2(260,144),"JOURNEY NOTES",26,GOLD)
	label_at(Vector2(260,174),"Only what you have discovered. Reading spends nothing.",15,MUTED)
	var lines := journal_lines()
	var pages := maxi(1,ceili(lines.size()/12.0))
	journal_page=clampi(journal_page,0,pages-1)
	var visible := lines.slice(journal_page*12,journal_page*12+12)
	for i in visible.size():
		label_at(Vector2(260,213+i*34),visible[i],15,INK if i%2==0 else TEAL)
	label_at(Vector2(260,680),"J / Esc: close    [ / ]: pages    %d / %d" % [journal_page+1,pages],14,MUTED)
	if pages>1:
		panel(Rect2(830,651,80,37),Color("253748")); label_at(Vector2(846,676),"PREV",14)
		panel(Rect2(925,651,90,37),Color("253748")); label_at(Vector2(942,676),"NEXT",14)
func battle_figure(id: String, center: Vector2, hero: bool):
	if combat_art.has(id):
		draw_texture_rect(combat_art[id],Rect2(center-Vector2(78,95),Vector2(156,156)),false)
	elif hero:
		draw_circle(center,28,TEAL.darkened(0.4))
		label_at(center+Vector2(-8,8),"H",24,TEAL)
	else: draw_token(center,battle_kind)
func draw_battle():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.58))
	panel(Rect2(285,170,710,465),Color("0c1928"))
	label_at(Vector2(320,210),"BATTLE REPLAY",23,GOLD)
	var phase := clampf(1.0-battle_time/2.4,0.0,1.0)
	var hero_pos := Vector2(450,345)
	var enemy_pos := Vector2(825,345)
	var is_ambush: bool=World.ENEMIES.get(battle_kind,{}).get("first_strike",false)
	var phase_text := "Readying the strike"
	if phase>=0.15 and phase<0.30 and is_ambush:
		phase_text={"oath":"Oath cancels the first strike","flank":"Flank barrier cancels the first strike"}.get(battle_details.get("first_strike_suppression","none"),"AMBUSH: enemy strikes first")
		enemy_pos.x-=sin((phase-0.15)/0.15*PI)*55
		draw_circle(hero_pos,47,Color(0.9,0.35,0.3,0.3))
	elif phase>=0.30 and phase<0.60:
		phase_text="Precision shot" if battle_hero=="ranger" else "Hero attacks"
		var action_phase := (phase-0.30)/0.30
		if battle_hero=="warden": hero_pos.x+=sin(action_phase*PI)*65
		var projectile := hero_pos.lerp(enemy_pos,action_phase)
		if battle_hero=="scholar": draw_circle(projectile,8,Color("c5a3ed"))
		else: draw_line(projectile-Vector2(17,8),projectile+Vector2(17,-8),GOLD,3)
	elif phase>=0.60 and phase<0.80:
		phase_text="Thorns reflect damage" if int(World.ENEMIES.get(battle_kind,{}).get("thorns",0))>0 else "Retaliation resolved"
		if int(battle_details.get("normal_damage",0))>0: enemy_pos.x-=sin((phase-0.60)/0.20*PI)*45
		draw_circle(enemy_pos,50,Color(0.85,0.75,0.4,0.25),false,3)
	else:
		if phase>=0.80: phase_text="Victory: the forecast holds"
	label_at(Vector2(320,240),phase_text,15,TEAL)
	draw_ellipse_shadow(hero_pos)
	draw_ellipse_shadow(enemy_pos)
	battle_figure(battle_hero,hero_pos,true)
	battle_figure(ENEMY_ART.get(battle_kind,""),enemy_pos,false)
	label_at(Vector2(365,420),Progression.HEROES[battle_hero].name,19,TEAL)
	label_at(Vector2(730,420),battle_name,19,GOLD)
	label_at(Vector2(320,463),"%d hero strikes  /  %d damage per hit  /  %d HP lost" % [int(battle_details.get("rounds",0)),int(battle_details.get("hit",0)),battle_loss],19)
	var detail_lines := battle_breakdown(battle_details)
	for i in detail_lines.size(): label_at(Vector2(320,489+i*22),detail_lines[i],14,MUTED if i<2 else TEAL)
	label_at(Vector2(320,582),"Cosmetic replay. Damage resolves once; any key / click skips.",14,GOLD)
func battle_breakdown(details: Dictionary) -> Array[String]:
	return [
		"Raw: normal %d + ambush %d + thorns %d" % [int(details.get("normal_damage",0)),int(details.get("first_strike_damage",0)),int(details.get("thorns_damage",0))],
		"EXTRA opening hit %d + charge bonus %d / %d retaliations" % [int(details.get("feint_damage",0)),int(details.get("charged_damage",0)),int(details.get("retaliations",0))],
		"Shield %d / oath %d / flank %d / total reduction %d" % [int(details.get("equipment_blocked",0)),int(details.get("oath_blocked",0)),int(details.get("flank_blocked",0)),int(details.get("blocked_damage",0))],
		"Final loss %d / recovery +%d / %s" % [int(details.get("damage",0)),int(details.get("heal_after",0)),"skill used" if details.get("skill_consumed",false) else "no active skill"]
	]

func draw_ellipse_shadow(center: Vector2):
	draw_set_transform(center+Vector2(0,57),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,49,Color(0,0,0,0.35))
	draw_set_transform(Vector2.ZERO)
func _unhandled_input(event):
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed): cancel_walk()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2:
		language="en" if language=="zh" else "zh"
		queue_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_M:
		toggle_mute()
		return
	if session!=null and session.busy: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F5: retry_save(); return
		if event.keycode==KEY_L and (world==null or session.read_only or is_terminal() or strategy_pending() or not modal_open()): load_game(); return
	if world==null: return
	if death_report:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_BRACKETLEFT: death_page=maxi(0,death_page-1)
			elif event.keycode==KEY_BRACKETRIGHT: death_page=mini(death_page_count()-1,death_page+1)
			else: death_report=false
		elif event is InputEventMouseButton and event.pressed: death_report=false
		return
	if reset_armed:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_ESCAPE: reset_armed=false
				KEY_S: selected_run_mode="safe"
				KEY_D: selected_run_mode="risk"
				KEY_ENTER: request_restart(reset_mode)
				KEY_N: request_restart("new")
				KEY_R: request_restart("replay")
		return
	if strategy_pending():
		if strategy_submitted: return
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_ESCAPE: strategy_selection=""
				KEY_0: strategy_selection="none"
				KEY_1,KEY_2,KEY_3:
					var index: int=event.keycode-KEY_1
					if index<world.draft.offers.size(): strategy_selection=world.draft.offers[index]
				KEY_ENTER: confirm_strategy()
				KEY_N: request_restart("new")
				KEY_R: request_restart("replay")
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var mouse: Vector2=get_global_mouse_position()
			for i in world.draft.offers.size():
				if Rect2(220,200+i*95,840,88).has_point(mouse): strategy_selection=world.draft.offers[i]
			if Rect2(220,490,840,46).has_point(mouse): strategy_selection="none"
			if Rect2(220,650,840,45).has_point(mouse): confirm_strategy()
		return
	if not lethal_snapshot.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE: clear_lethal()
			elif event.keycode==KEY_ENTER: confirm_lethal()
		return
	if is_terminal():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_N: request_restart("new")
			elif event.keycode==KEY_R: request_restart("replay")
			elif event.keycode==KEY_B and world.ended_reason=="death": death_report=true;death_page=0
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			if Rect2(250,595,350,48).has_point(get_global_mouse_position()): request_restart("new")
		return
	if finish_pending!="":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE: finish_pending=""
			elif event.keycode==KEY_ENTER: confirm_finish()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			if Rect2(250,525,350,48).has_point(get_global_mouse_position()): confirm_finish()
			elif Rect2(650,525,350,48).has_point(get_global_mouse_position()): finish_pending=""
		return
	if event is InputEventMouseMotion:
		hover = Vector2i(((get_global_mouse_position()-ORIGIN)/CELL).floor())
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if battle_time>0.0: battle_time=0.0; return
		if attuning:
			attunement_click(get_global_mouse_position()); return
		if travel_menu:
			var mouse: Vector2=get_global_mouse_position()
			if not Rect2(195,110,890,580).has_point(mouse): close_travel(); return
			if travel_pending!="":
				if Rect2(225,435,390,48).has_point(mouse): confirm_travel()
				elif Rect2(635,435,390,48).has_point(mouse): travel_pending=""
			else:
				if Rect2(815,595,110,38).has_point(mouse): travel_page=maxi(0,travel_page-1); return
				if Rect2(935,595,110,38).has_point(mouse): travel_page+=1; return
				for i in visible_travel_options().size():
					if Rect2(225,220+i*61,830,55).has_point(mouse): select_travel(i); return
			return
		if comparison:
			if comparison_rows().size()>4:
				if Rect2(800,170,110,35).has_point(get_global_mouse_position()): compare_page=maxi(0,compare_page-1); return
				if Rect2(920,170,110,35).has_point(get_global_mouse_position()): compare_page+=1; return
			if not Rect2(195,110,890,580).has_point(get_global_mouse_position()): comparison=false
			return
		if book:
			if Rect2(760,115,120,40).has_point(get_global_mouse_position()): book_page=maxi(0,book_page-1)
			elif Rect2(880,115,150,40).has_point(get_global_mouse_position()): book_page+=1
			else: book=false
			return
		if journal:
			if Rect2(830,651,80,37).has_point(get_global_mouse_position()): journal_page=maxi(0,journal_page-1)
			elif Rect2(925,651,90,37).has_point(get_global_mouse_position()): journal_page+=1
			elif not Rect2(230,100,820,610).has_point(get_global_mouse_position()): journal=false
			return
		if growth:
			if growth_tab==1 and Rect2(225,548,285,38).has_point(get_global_mouse_position()): open_attunement(); return
			if growth_tab==1 and growth_actions().size()>3:
				if Rect2(780,548,120,38).has_point(get_global_mouse_position()): gear_page=maxi(0,gear_page-1); return
				if Rect2(915,548,120,38).has_point(get_global_mouse_position()): gear_page+=1; return
			for i in 3:
				if Rect2(225+i*270,175,250,40).has_point(get_global_mouse_position()): growth_tab=i; return
			var choices := visible_growth_actions()
			for i in choices.size():
				if Rect2(225,270+i*87,830,76).has_point(get_global_mouse_position()): perform_action(choices[i][0]); return
			if not Rect2(195,80,890,650).has_point(get_global_mouse_position()): growth=false
			return
		if interaction:
			var rows := visible_actions()
			for i in rows.size():
				if Rect2(285,375+i*43,720,37).has_point(get_global_mouse_position()): perform_action(rows[i][0]); return
			if not Rect2(260,120,770,570).has_point(get_global_mouse_position()): interaction=false; winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""
			return
		if world.won and Rect2(395,575,490,48).has_point(get_global_mouse_position()): request_finish(); return
		if Rect2(768,738,476,32).has_point(get_global_mouse_position()): request_finish(); return
		if world.won and chapter_button().has_point(get_global_mouse_position()) and not world.chapter_offers().is_empty():
			perform_action(world.chapter_offers()[0][0]); return
		for i in buttons.size():
			if buttons[i].has_point(get_global_mouse_position()):
				match i:
					0: undo()
					1: save_game()
					2: load_game()
					3: book=true
					4: interaction=true; interaction_page=0
					5: open_growth()
					6: open_journal()
					7: open_travel()
				return
		hover=Vector2i(((get_global_mouse_position()-ORIGIN)/CELL).floor())
		start_walk(hover)
	if event is InputEventKey and event.pressed and not event.echo:
		if battle_time>0.0: battle_time=0.0; return
		if event.keycode==KEY_G: open_attunement(); return
		if attuning:
			if event.keycode==KEY_ESCAPE:
				if attune_pending!="": attune_pending=""
				else: close_attunement()
			elif event.keycode==KEY_BRACKETLEFT: cycle_attunement(-1)
			elif event.keycode==KEY_BRACKETRIGHT: cycle_attunement(1)
			elif attune_pending!="":
				if event.keycode==KEY_ENTER: confirm_attunement()
			elif event.keycode>=KEY_1 and event.keycode<=KEY_4: select_attunement(event.keycode-KEY_1)
			return
		if event.keycode==KEY_T: open_travel(); return
		if travel_menu:
			if event.keycode==KEY_ESCAPE:
				if travel_pending!="": travel_pending=""
				else: close_travel()
			elif travel_pending!="":
				if event.keycode==KEY_ENTER: confirm_travel()
			else:
				if event.keycode==KEY_BRACKETLEFT: travel_page=maxi(0,travel_page-1)
				elif event.keycode==KEY_BRACKETRIGHT: travel_page+=1
				else: select_travel(event.keycode-KEY_1)
			return
		if event.keycode==KEY_V: open_comparison(); return
		if comparison:
			if event.keycode==KEY_ESCAPE: comparison=false
			elif event.keycode==KEY_BRACKETLEFT: compare_page=maxi(0,compare_page-1)
			elif event.keycode==KEY_BRACKETRIGHT: compare_page+=1
			return
		if event.keycode==KEY_J: open_journal(); return
		if event.keycode==KEY_C: open_growth(); return
		if event.keycode==KEY_H: book=not book; journal=false; growth=false; interaction=false; winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""; return
		if event.keycode==KEY_E: interaction=not interaction; winch_pending=""; interaction_page=0; journal=false; growth=false; book=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""; return
		if event.keycode==KEY_ESCAPE: book=false; journal=false; growth=false; interaction=false; winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""; return
		if journal:
			if event.keycode==KEY_BRACKETLEFT: journal_page=maxi(0,journal_page-1)
			if event.keycode==KEY_BRACKETRIGHT: journal_page+=1
			return
		if growth:
			if event.keycode==KEY_TAB: growth_tab=(growth_tab+1)%3; return
			if growth_tab==1 and event.keycode==KEY_BRACKETLEFT: gear_page=maxi(0,gear_page-1); return
			if growth_tab==1 and event.keycode==KEY_BRACKETRIGHT: gear_page+=1; return
			var index: int=event.keycode-KEY_1
			var choices := visible_growth_actions()
			if index>=0 and index<choices.size(): perform_action(choices[index][0])
			return
		if interaction:
			if event.keycode==KEY_BRACKETLEFT: interaction_page=maxi(0,interaction_page-1); return
			if event.keycode==KEY_BRACKETRIGHT: interaction_page+=1; return
			var index: int = event.keycode-KEY_1
			var rows := visible_actions()
			if index>=0 and index<rows.size(): perform_action(rows[index][0])
			return
		if book:
			if event.keycode==KEY_BRACKETLEFT: book_page=maxi(0,book_page-1)
			if event.keycode==KEY_BRACKETRIGHT: book_page+=1
			return
		if world.won and event.keycode==KEY_1 and not world.chapter_offers().is_empty():
			perform_action(world.chapter_offers()[0][0]); return
		if event.keycode==KEY_X or (world.won and event.keycode==KEY_2): request_finish(); return
		match event.keycode:
			KEY_W,KEY_UP: move(Vector2i.UP)
			KEY_S,KEY_DOWN: move(Vector2i.DOWN)
			KEY_A,KEY_LEFT: move(Vector2i.LEFT)
			KEY_D,KEY_RIGHT: move(Vector2i.RIGHT)
			KEY_U: undo()
			KEY_L: load_game()
			KEY_R: request_restart("replay")
			KEY_N: request_restart("new")
func request_restart(mode: String):
	if session==null or world==null or session.busy or session.read_only: return
	close_attunement()
	cancel_walk()
	close_travel()
	comparison=false
	if reset_armed and reset_mode==mode:
		var result: Dictionary=await session.new_run(world.seed_value if mode=="replay" else randi_range(1,2147483646),2,true,selected_run_mode)
		apply_session_result(result)
		if not result.get("committed",false): return
		history.clear(); journal=false; journal_page=0; reset_armed=false; battle_time=0.0; growth=true; growth_tab=0; gear_page=0; interaction=false; winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""
	else:
		reset_armed=true; reset_mode=mode; selected_run_mode="safe"
		ui_notice="Press %s again: %s. Autosave will be replaced." % ["R" if mode=="replay" else "N","replay this seed" if mode=="replay" else "start a new seed"]
func move(direction: Vector2i, confirmed:=false):
	if not can_mutate(): return
	cancel_walk()
	reset_armed=false
	var target_token: String=world.tile(world.pos+direction)
	if world.mode=="risk" and World.ENEMIES.has(target_token):
		var preview: Dictionary=world.battle_preview(target_token,"",world.pos+direction)
		if preview.get("valid",false) and not preview.get("survivable",false):
			var timeline: Dictionary=world.battle_timeline(world.pos+direction)
			if not timeline.get("valid",false) or not timeline.get("fatal",false): return
			preview.skill_consumed=timeline.get("skill_consumed",false)
			lethal_delta=direction; lethal_snapshot=world.save_data().duplicate(true); lethal_preview=preview.duplicate(true)
			return
	var key_cost := 2 if target_token=="L" else 1
	if not confirmed and target_token in ["D","L"] and world.keys>=key_cost and not world.won:
		checkpoint_pending=direction; pending_reason="door"
		interaction_page=0; interaction=true
		ui_notice="Opening this door costs %d keys. Confirm or keep them for later." % key_cost
		return
	if not confirmed and world.tile(world.pos+direction)==">" and world.floor_index in [2,3] and world.checkpoints<world.floor_index-1 and world.debt()>0:
		checkpoint_pending=direction; pending_reason="interest"
		interaction_page=0
		interaction=true
		ui_notice="A new milestone settles interest. Repay first, continue, or cancel."
		return
	apply_session_result(await session.step(direction))
func step_effect(enemy: String, hero_before: String):
	if World.ENEMIES.has(enemy): play_sound("victory" if world.won else "impact")
	elif enemy in ["D","L"]: play_sound("door")
	elif enemy in ["k","h","a","d","C","I","T","$","A","P","m"]: play_sound("pickup")
	elif enemy=="~": play_sound("water")
	else: play_sound("move")
	if World.ENEMIES.has(enemy):
		var resolved: Dictionary=world.last_battle.duplicate(true)
		battle_time=2.4; battle_name=World.ENEMIES[enemy].name; battle_loss=int(resolved.get("damage",0))
		battle_details=resolved; battle_kind=enemy; battle_hero=hero_before; battle_skill=resolved.get("skill_consumed",false)
func undo():
	if not can_mutate(): return
	close_attunement(); cancel_walk(); close_travel()
	var result: Dictionary=await session.undo()
	apply_session_result(result)
	if result.get("committed",false): battle_time=0.0
func save_game(_announce:=true):
	if not can_mutate(): return
	cancel_walk()
	apply_session_result(await session.save())
func load_game():
	if session==null or session.busy: return
	strategy_selection=""; strategy_submitted=false
	close_attunement(); cancel_walk(); close_travel(); finish_pending=""; clear_lethal(); death_report=false; reset_armed=false
	var result: Dictionary=await session.reacquire_and_reload()
	if result.get("status")=="empty" and world==null:
		result=await session.new_run(initial_seed())
	apply_session_result(result)
	if not result.get("ok",false): return
	journal=false; journal_page=0; interaction=false; winch_pending=""; growth=result.get("committed",false) and result.get("effect",{}).get("operation","")=="create"; gear_page=0; book=false; comparison=false
	checkpoint_pending=Vector2i.ZERO; pending_reason=""; battle_time=0.0
func retry_save():
	if session==null or session.busy: return
	cancel_walk()
	apply_session_result(await session.retry_pending())
func status_message() -> String:
	if session!=null and session.busy: return "Saving safely. Please wait."
	return ui_notice if ui_notice!="" else (world.message if world!=null else "Opening journey storage...")
func can_mutate() -> bool:
	return session!=null and world!=null and not session.busy and not session.read_only and not is_terminal()
func apply_session_result(result: Dictionary):
	if result.get("ok",false):
		world=session.world; history=session.history; ui_notice=""
		if strategy_pending(): cancel_walk()
		if result.get("committed",false): dispatch_committed_effect(result.get("effect",{}))
	else:
		ui_notice=str(result.get("reason",result.get("status","Storage unavailable.")))
	queue_redraw()
func initialize_session():
	if session==null:
		# Adapter factory is supplied by the storage layer; no legacy FileAccess path.
		var factory=load("res://scripts/session_storage.gd")
		if factory==null: ui_notice="Storage unavailable. No journey was changed."; return
		session=Session.new(factory.new())
	var result: Dictionary=await session.open_current()
	apply_session_result(result)
	if result.get("status")=="empty":
		apply_session_result(await session.new_run(initial_seed()))
		if world!=null: ui_notice="New save system: old journey files are kept untouched."
	else: growth=false

func dispatch_committed_effect(effect: Dictionary):
	match effect.get("operation",""):
		"step": step_effect(str(effect.get("token",".")),str(effect.get("hero",world.hero_id)))
		"action": action_effect(str(effect.get("input","")))
		"walk": play_sound("move")
		"undo": battle_time=0.0
		"death":
			clear_lethal(); cancel_walk(); battle_time=0.0; death_report=true; death_page=0; play_sound("impact")
		"settle":
			finish_pending=""; cancel_walk(); battle_time=0.0; play_sound("victory")
		"strategy":
			strategy_selection=""; strategy_submitted=false; cancel_walk(); growth=true; growth_tab=0
		"create":
			strategy_selection=""; strategy_submitted=false
			clear_lethal(); death_report=false
			finish_pending=""
			close_attunement(); close_travel(); comparison=false; journal=false; book=false
			reset_armed=false; battle_time=0.0; growth=true; growth_tab=0; gear_page=0
			interaction=false; winch_pending=""; checkpoint_pending=Vector2i.ZERO; pending_reason=""

func is_terminal() -> bool:
	return session!=null and session.get("terminal")==true
func settlement_outcome() -> String:
	if world.won: return "victory" if world.expedition_started else "chapter1"
	return "withdrawn"
func request_finish():
	if not can_mutate(): return
	cancel_walk(); close_attunement(); close_travel()
	book=false; growth=false; interaction=false; journal=false; comparison=false; battle_time=0.0
	finish_pending=settlement_outcome(); reset_armed=false
func confirm_finish():
	if finish_pending=="" or not can_mutate(): return
	apply_session_result(await session.finish(finish_pending))
func draw_finish_confirmation():
	panel(Rect2(210,180,860,440),Color("101c2a"))
	label_at(Vector2(245,225),"END THIS JOURNEY?",26,GOLD)
	draw_wrapped(Vector2(245,270),"This permanently ends this run. Undo will no longer be available. Your current items do not carry into a new run.",770,19,INK,3)
	draw_wrapped(Vector2(245,355),"Only newly reached floor milestones 3 / 5 / 8 are recorded. Records alone grant no stats. Only a strategy explicitly chosen for a new run applies.",770,18,TEAL,3)
	label_at(Vector2(245,440),"Pending first records: %s (only after saving)" % str(pending_milestones()),17,GOLD)
	draw_wrapped(Vector2(245,475),settlement_notice(),770,15,MUTED,2)
	panel(Rect2(250,525,350,48),Color("34463d"));panel(Rect2(650,525,350,48),Color("253748"))
	label_at(Vector2(265,555),"ENTER: end and record",19,GOLD)
	label_at(Vector2(665,555),"ESC: keep exploring",19,INK)
func pending_milestones() -> Array:
	var pending: Array=[]
	for floor_number in [3,5,8]:
		if world.floor_seen.size()>=floor_number and world.floor_seen[floor_number-1]:
			var found:=false
			for recorded in session.profile.get("milestones",[]):
				if recorded==floor_number: found=true
			if not found: pending.append(floor_number)
	return pending
func terminal_lines() -> Array[String]:
	var receipt: Dictionary=session.receipt
	var profile: Dictionary=session.profile
	return [display({"defeat":"Journey ended in battle","withdrawn":"Exploration retired","chapter1":"Chapter one complete","victory":"Final victory recorded"}.get(receipt.get("summary",{}).get("outcome",""),"JOURNEY RECORDED")),"This journey is archived and read-only. Undo and further moves are unavailable.",
		"New milestones: %s" % milestone_text(receipt.get("milestones",[])),
		"Recorded milestones: %s" % milestone_text(profile.get("milestones",[])),
		"Records alone grant no stats. Only a strategy explicitly chosen for a new run applies."]
func draw_terminal():
	panel(Rect2(210,150,860,530),Color("101c2a"))
	label_at(Vector2(245,200),"JOURNEY RECORDED",28,GOLD)
	label_at(Vector2(245,242),"%d HP left  /  %d moves  /  %d gold" % [world.hp,world.moves,world.gold],18,TEAL)
	var y:=285.0
	for line in terminal_lines():
		var wrapped=wrapped_lines(line,770,18)
		for text_line in wrapped: label_at(Vector2(245,y),text_line,18,INK);y+=26
		y+=12
	draw_wrapped(Vector2(245,530),settlement_notice(),770,15,MUTED,2)
	panel(Rect2(250,595,350,48),Color("253748"))
	label_at(Vector2(265,625),"N twice: new journey",19,GOLD)
	label_at(Vector2(650,625),"L: reload record / F2: language",16,MUTED)
	if world.ended_reason=="death": label_at(Vector2(245,565),"B: review the fatal events (read-only)",18,TEAL)

func settlement_notice() -> String:
	if session!=null and session.busy: return "Saving safely. Please wait."
	return ui_notice
func milestone_text(values: Array) -> String:
	var floors: Array[int]=[]
	for value in values: floors.append(int(value))
	return str(floors)

func clear_lethal():
	lethal_delta=Vector2i.ZERO; lethal_snapshot={}; lethal_preview={}
func confirm_lethal():
	if lethal_snapshot.is_empty() or not can_mutate(): return
	apply_session_result(await session.confirm_lethal(lethal_delta,lethal_snapshot.duplicate(true)))
func draw_new_run_confirmation():
	panel(Rect2(210,150,860,530),Color("101c2a"))
	label_at(Vector2(245,200),"CHOOSE A NEW JOURNEY",26,GOLD)
	draw_wrapped(Vector2(245,255),"S: Safe mode. Lethal battles are refused.",770,20,TEAL,2)
	draw_wrapped(Vector2(245,325),"D: Risk mode. Confirmed lethal combat ends and records this run. No Undo after death.",770,20,GOLD,3)
	label_at(Vector2(245,440),"RISK MODE" if selected_run_mode=="risk" else "SAFE MODE",24,GOLD)
	draw_wrapped(Vector2(245,485),"This choice applies only to the new run. The current run is not converted. Replacing it abandons its unfinished progress.",770,18,INK,3)
	label_at(Vector2(245,610),"ENTER: create chosen mode / ESC: cancel",20,TEAL)
func draw_lethal_confirmation():
	panel(Rect2(210,130,860,550),Color("101c2a"))
	label_at(Vector2(245,180),"LETHAL BATTLE: CONFIRM DEATH?",25,RED)
	label_at(Vector2(245,225),"Current HP %d / full fight forecast %d damage" % [world.hp,int(lethal_preview.get("damage",0))],19,GOLD)
	draw_wrapped(Vector2(245,275),"Death ends and records this journey. It cannot be undone. No kill gold or after-battle healing is awarded.",770,19,INK,3)
	draw_wrapped(Vector2(245,375),"An armed skill consumes focus. Thorns deal contact damage before your strike; lethal contact prevents that strike.",770,19,INK,3)
	label_at(Vector2(245,485),"Focus %d / armed skill will consume: %s" % [world.focus,"yes" if lethal_preview.get("skill_consumed",false) else "no"],18,TEAL)
	draw_wrapped(Vector2(245,525),settlement_notice(),770,16,RED,2)
	label_at(Vector2(245,610),"ENTER: fight to the fatal event / ESC: cancel",20,GOLD)
func draw_death_report():
	panel(Rect2(210,130,860,550),Color("101c2a"))
	label_at(Vector2(245,185),"Journey ended in battle",27,RED)
	draw_wrapped(Vector2(245,235),"Only actual events up to death are shown. No victory or kill reward occurred.",770,19,INK,3)
	var details: Dictionary=world.last_battle
	label_at(Vector2(245,305),"Actual hero strikes %d / counters %d / HP lost %d" % [int(details.get("hero_hits",0)),int(details.get("counter_count",0)),int(details.get("damage",0))],18,GOLD)
	var rows:=death_event_lines()
	for i in range(death_page*6,mini(rows.size(),death_page*6+6)):
		label_at(Vector2(245,350+(i-death_page*6)*37),rows[i],16,INK)
	label_at(Vector2(245,595),"[ / ]: events page %d / %d" % [death_page+1,death_page_count()],17,GOLD)
	label_at(Vector2(245,640),"Any other key: view the saved record",18,TEAL)
func death_page_count() -> int:
	return maxi(1,ceili(world.last_battle.get("events",[]).size()/6.0))
func death_event_lines() -> Array[String]:
	var lines: Array[String]=[]
	var names={"hero_hit":"Hero strike","counter":"Enemy counter","first_strike":"Enemy first strike","feint":"Duelist opening counter","thorns":"Contact thorns","charged":"Heavy strike bonus"}
	for item in world.last_battle.get("events",[]):
		lines.append("%s: damage %d / HP %d / enemy HP %d" % [display(names.get(item.kind,item.kind)),int(item.damage),int(item.hp),int(item.enemy_hp)])
	return lines

func strategy_pending() -> bool:
	return world!=null and world.strategy_pending()
func confirm_strategy():
	if not strategy_pending() or strategy_selection=="" or strategy_submitted or not can_mutate(): return
	strategy_submitted=true
	apply_session_result(await session.choose_strategy(strategy_selection))
func draw_strategy_draft():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.8))
	panel(Rect2(190,80,900,650),Color("101c2a"))
	label_at(Vector2(220,122),"LEGACY STRATEGY / ONE CHOICE THIS RUN",24,GOLD)
	draw_wrapped(Vector2(220,155),"Choose a trade-off before the first step. Original rules remain viable. This is separate from hero, equipment and kill talents.",840,16,INK,2)
	for i in world.draft.offers.size():
		var id: String=world.draft.offers[i]
		var preview: Dictionary=world.strategy_preview(id)
		var r:=Rect2(220,200+i*95,840,88)
		panel(r,Color("345c62") if strategy_selection==id else Color("203343"))
		label_at(r.position+Vector2(15,25),"%d  %s" % [i+1,display(preview.name)],20,GOLD)
		draw_wrapped(r.position+Vector2(15,51),preview.description,810,16,INK,2)
	panel(Rect2(220,490,840,46),Color("345c62") if strategy_selection=="none" else Color("203343"))
	label_at(Vector2(235,520),"0  Original rules / no strategy modifier",19,TEAL)
	if strategy_selection!="":
		var preview: Dictionary=world.strategy_preview(strategy_selection)
		var info: Dictionary=preview.skill_level_info
		label_at(Vector2(220,565),"Skill level %d = base %d + training %d + equipment %d + strategy %d" % [info.effective,info.base,info.training,info.gear,info.strategy],16,TEAL)
		draw_wrapped(Vector2(220,593),preview.skill_description,840,16,INK,2)
	else: label_at(Vector2(220,565),"Select a card to preview. Nothing is locked until Enter.",17,TEAL)
	label_at(Vector2(220,632),"Locked for this run. Undo and reload do not reroll or undo this choice.",16,GOLD)
	panel(Rect2(220,650,840,45),Color("345c62") if strategy_selection!="" else Color("203343"))
	label_at(Vector2(235,679),"ENTER: LOCK STRATEGY / Esc: clear selection",18)
	draw_wrapped(Vector2(220,715),ui_notice if ui_notice!="" else "N: new seed / R: same seed new run / L: reload / F2: language",840,13,GOLD if ui_notice!="" else MUTED,1)
