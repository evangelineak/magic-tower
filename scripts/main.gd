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
var setup_allocation := {"study":0,"reserve":0}
var walk_generation := 0
var font = ThemeDB.fallback_font
var art: Texture2D
var combat_art: Dictionary = {}
var sound_player: AudioStreamPlayer
var sound_bank: Dictionary = {}
var muted := false
var sound_event_count := 0
var last_sound_event := ""
const ENEMY_ART := {"s":"mossling","g":"sentinel","u":"stalker","b":"briar","w":"juggernaut","V":"colossus","K":"regent","B":"gate_brute","Z":"archivist","H":"ferryman","W":"jailer"}
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
var compare_flank := false
var compare_cache: Dictionary={}
var compare_cache_world=null
var compare_refresh_count:=0
var book := false
var book_page := 0
var journal := false
var journal_page := 0
var journal_details := false
var pinned_target := ""
var growth := true
var growth_tab := 0
var gear_page := 0
var talent_selected := ""
var talent_submitted := false
var talent_target_index := 0
var talent_notice_tier := -1
var talent_notice_time := 0.0
var reset_mode := ""
var battle_details: Dictionary = {}
var battle_receipt: Dictionary = {}
var battle_kind := "s"
var battle_hero := "warden"
var battle_skill := false
var interaction_page := 0
var interaction := false
var interaction_target := "" # Empty means the existing keyboard nearby-actions menu.
var rope_pending: Dictionary={}
var rope_inspecting:=false
var cargo_pending := false
var cargo_inspecting := false
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
var hover_walk_cache: Dictionary = {}
var hover_walk_world = null
var hover_walk_key: Array = []
var hover_walk_refresh_count := 0
var walk_feedback := ""
var walk_feedback_target := Vector2i(-1,-1)
var walk_feedback_time := 0.0
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
	for id in ["warden","ranger","scholar","mossling","sentinel","stalker","briar","juggernaut","colossus","regent","archivist","gate_brute","ferryman","jailer","ilen","mira"]:
		var path := "res://assets/combat/%s.png" % id
		if ResourceLoader.exists(path): combat_art[id]=load(path)
	for id in ["winch","maul"]:
		var path := "res://assets/props/%s.png" % id
		if ResourceLoader.exists(path): combat_art[id]=load(path)
	for id in ["warden","ranger","scholar","mossling","sentinel","stalker","briar","juggernaut","colossus","regent","gate_brute","archivist","ferryman","jailer","ilen","mira"]:
		var path := "res://assets/map_icons/%s.png" % id
		if ResourceLoader.exists(path): map_art[id]=load(path)
	for rope_art in ["rope_ready","rope_spent"]:
		if ResourceLoader.exists("res://assets/rope/%s.png" % rope_art): map_art[rope_art]=load("res://assets/rope/%s.png" % rope_art)
	for cargo_art in ["cargo","cargo_empty"]:
		if ResourceLoader.exists("res://assets/cargo/%s.png" % cargo_art): map_art[cargo_art]=load("res://assets/cargo/%s.png" % cargo_art)
	buttons = [Rect2(768,636,148,40),Rect2(932,636,148,40),Rect2(1096,636,148,40),Rect2(1014,536,230,40),Rect2(768,586,230,40),Rect2(768,536,230,40),Rect2(1014,586,230,40),Rect2(768,686,476,40)]
	await initialize_session()
	queue_redraw()
func _process(delta):
	tick += delta
	walk_feedback_time=maxf(0.0,walk_feedback_time-delta)
	advance_walk(delta)
	battle_time = maxf(0.0, battle_time-delta)
	if battle_time<=0.0 and not modal_open(): talent_notice_time=maxf(0.0,talent_notice_time-delta)
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
			elif world.cargo.version==1 and world.floor_index==0 and Vector2i(x,y)==World.Cargo.source_box() and t=="h":
				draw_cargo_icon(p+Vector2(CELL/2,CELL/2),true)
			else:
				draw_token(p+Vector2(CELL/2,CELL/2),t)
				if crown_cargo_marker(Vector2i(x,y)):
					draw_cargo_icon(p+Vector2(47,47),world.cargo.state=="shipped",26)
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
	draw_hover_walk()
	draw_rope_marker()
	draw_target_marker()
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
	label_at(Vector2(25,795),"WASD / arrows: move, pick up, fight and use stairs.",12,MUTED)
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
	if not modal_open():
		draw_tooltip()
		if talent_notice_time>0.0: draw_talent_notice()
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
	label_at(Vector2(768,326),folio_progress_text(),16,GOLD)
	label_at(Vector2(768,354),"NEW TALENT AVAILABLE  [C]" if not world.talent_options().is_empty() else "C: hero, equipment and skills",15,TEAL)
	draw_wrapped(Vector2(768,388),pinned_target_text(),460,16,GOLD,2)
	draw_wrapped(Vector2(768,441),status_message(),460,15,TEAL,3)
	label_at(Vector2(768,512),"Walking safely... Any key or click stops." if not walk_route.is_empty() else "Click nearby objects to act; clear floor to walk safely.",14,MUTED)
	var titles := ["UNDO  U","SAVE (CLICK)","LOAD  L","GUIDE  H","INTERACT / LEDGER  E","HERO / GROWTH  C","JOURNEY NOTES  J","SAFE TRAVEL  T"]
	for i in buttons.size():
		panel(buttons[i],Color("253748")); label_at(buttons[i].position+Vector2(12,26),titles[i],15)
	panel(Rect2(768,738,476,32),Color("253748"))
	label_at(Vector2(780,760),"X: retire this journey / record milestones",14,GOLD)
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
# Read-only mouse affordances; cache by committed World identity and cursor state.
# Production mutations replace World in apply_session_result and invalidate here.
func invalidate_hover_walk():
	hover_walk_cache.clear(); hover_walk_world=null; hover_walk_key.clear()
func hover_walk_info() -> Dictionary:
	if world==null: return {"state":"outside","route":[],"hint":""}
	var key: Array=[hover,world.floor_index,world.pos,world.moves,world.won,world.generation_valid,world.ended_reason]
	if hover_walk_world==world and key==hover_walk_key and not hover_walk_cache.is_empty(): return hover_walk_cache.duplicate(true)
	hover_walk_world=world; hover_walk_key=key; hover_walk_refresh_count+=1
	var info: Dictionary={"state":"inspect","route":[],"hint":"Mouse only inspects. Use WASD / arrows for manual actions."}
	if hover.x<0 or hover.y<0 or hover.x>=11 or hover.y>=11:
		info={"state":"outside","route":[],"hint":""}
	elif hover==world.pos:
		info.state="current"; info.hint="You are here. Use WASD / arrows to move."
	else:
		var token: String=world.tile(hover)
		if token==".":
			info.route=world.safe_walk_path(hover)
			info.state="ready" if not info.route.is_empty() else "blocked"
			info.hint="Safe route: %d steps. Click to walk; any key or click stops." % info.route.size() if info.state=="ready" else "No safe route. Clear the way manually first."
		elif token=="#": info.state="wall"; info.hint="Wall: no walking route."
		elif World.ENEMIES.has(token): info.hint="Mouse only inspects. Move into this enemy with WASD / arrows to fight."
		elif token in ["D","L"]: info.hint="Mouse only inspects. Move into this door with WASD / arrows to request opening."
		elif token in ["<",">"]: info.hint="Mouse only inspects. Move into these stairs with WASD / arrows."
		elif token in ["k","h","a","d","$","A","P","T","C","I","m"]: info.hint="Mouse only inspects. Move into this item with WASD / arrows to collect."
		elif token in ["M","J","N","E","F","Q","O","X","U","Y","v","t","c","R"]: info.hint="Mouse only inspects. Approach with WASD / arrows, then press E to interact."
		if absi(hover.x-world.pos.x)+absi(hover.y-world.pos.y)==1:
			if World.ENEMIES.has(token): info.hint="Click to fight this adjacent enemy. Dangerous fights still require confirmation."
			elif token in ["k","h","a","d","$","A","P","T","C","I","m"]: info.hint="Click to collect this adjacent item."
			elif token in ["M","J","N","E","F","Q","O","X","U","Y","v","c","R"]: info.hint="Click to open this object's choices. Nothing is spent until you choose."
			elif token=="t": info.hint="Click to rescue Mira."
			elif token in ["D","L"]: info.hint="Click to request opening this door. Key confirmation is unchanged."
			elif token in ["<",">"]: info.hint="Click to use these adjacent stairs."
	hover_walk_cache=info
	return info.duplicate(true)
func draw_hover_walk():
	if modal_open() or not can_mutate(): return
	var info:=hover_walk_info()
	if walk_route.is_empty() and info.state=="ready":
		var last: Vector2=ORIGIN+Vector2(world.pos)*CELL+Vector2(CELL/2,CELL/2)
		for point in info.route:
			var center: Vector2=ORIGIN+Vector2(point)*CELL+Vector2(CELL/2,CELL/2)
			draw_line(last,center,Color(0.4,0.85,0.76,0.45),2)
			draw_circle(center,3,TEAL)
			last=center
		draw_circle(last,22,TEAL,false,2)
	elif info.state=="blocked":
		var center: Vector2=ORIGIN+Vector2(hover)*CELL+Vector2(CELL/2,CELL/2)
		draw_line(center-Vector2(8,8),center+Vector2(8,8),RED,2)
		draw_line(center+Vector2(-8,8),center+Vector2(8,-8),RED,2)
	if walk_feedback_time>0.0 and hover==walk_feedback_target:
		draw_rect(Rect2(ORIGIN+Vector2(hover)*CELL+Vector2(4,4),Vector2(CELL-8,CELL-8)),RED if info.state in ["blocked","wall"] else GOLD,false,3)
func tooltip_lines() -> Array[String]:
	var lines: Array[String]=[]
	if hover.x<0 or hover.y<0 or hover.x>=11 or hover.y>=11: return lines
	var data: Dictionary=world.tooltip_data(hover)
	if data.get("title","")!="": lines.append_array(wrapped_lines(str(data.title),298,15))
	var navigation:=hover_walk_info()
	var hint: String=walk_feedback if walk_feedback_time>0.0 and hover==walk_feedback_target else str(navigation.hint)
	if session!=null and session.read_only: hint="Read-only journey. L reloads before you can move."
	if hint!="": lines.append_array(wrapped_lines(hint,298,15))
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
func map_click(target: Vector2i):
	if not can_mutate() or modal_open(): return
	cancel_walk()
	hover=target
	var delta: Vector2i=target-world.pos
	var token: String=world.tile(target)
	if absi(delta.x)+absi(delta.y)==1:
		if token in ["M","J","N","E","F","Q","O","X","U","Y","v","c","R"]:
			open_interaction(token)
			return
		if World.ENEMIES.has(token) or token in ["k","h","a","d","$","A","P","T","C","I","m","t","D","L","<",">"]:
			interaction_target=""
			await move(delta)
			return
	start_walk(target)
func open_interaction(target_token: String=""):
	cancel_walk()
	interaction_target=target_token
	interaction=true; winch_pending=""; cargo_pending=false; cargo_inspecting=false
	rope_pending.clear(); rope_inspecting=false; interaction_page=0
	journal=false; growth=false; book=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
func start_walk(target: Vector2i):
	if not can_mutate(): return
	cancel_walk()
	if modal_open(): return
	hover=target
	var info:=hover_walk_info()
	walk_feedback=str(info.hint); walk_feedback_target=target; walk_feedback_time=1.8
	if info.state!="ready" or world.tile(target)!=".": return
	# Re-prove at click time; the hover cache is for display only.
	walk_route=world.safe_walk_path(target)
	if walk_route.is_empty():
		invalidate_hover_walk(); walk_feedback="No safe route. Clear the way manually first."
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
	close_travel(); comparison=false; journal=false; book=false; growth=false; interaction=false; interaction_target=""
	winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
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
	label_at(Vector2(225,179),skill_sources_text(info),14)
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

func close_comparison():
	comparison=false; compare_cache.clear(); compare_cache_world=null
func open_comparison():
	cancel_walk()
	if comparison: close_comparison(); return
	if battle_time>0.0 or book or journal or growth or interaction or travel_menu: return
	if not World.ENEMIES.has(world.tile(hover)): return
	compare_pos=hover; compare_floor=world.floor_index; compare_page=0; compare_flank=false; comparison=true
	compare_cache.clear(); compare_cache_world=null
	comparison_forecast()
func comparison_forecast() -> Dictionary:
	if world==null or compare_floor!=world.floor_index or not World.ENEMIES.has(world.tile(compare_pos)): return {}
	if compare_cache.is_empty() or compare_cache_world!=world or compare_cache.get("target",Vector2i(-1,-1))!=compare_pos:
		compare_cache=world.tactical_forecast(compare_pos)
		compare_cache_world=world
		compare_refresh_count+=1
	return compare_cache
func comparison_rows() -> Array:
	var rows: Array=[]
	for row in comparison_forecast().get("rows",[]):
		var item: Dictionary=row.duplicate(true)
		item.preview=row.current.preview
		item.after_hp=row.current.after_hp
		rows.append(item)
	return rows
func toggle_compare_position():
	if comparison_forecast().get("flank",{}).get("available",false): compare_flank=not compare_flank
func tactical_result_text(branch: Dictionary) -> String:
	if branch.is_empty(): return "Healing is not an armed combat skill."
	var preview: Dictionary=branch.get("preview",{})
	if not preview.get("valid",false): return "Cannot penetrate defense"
	if not preview.get("survivable",false): return "Full-fight loss %d / LETHAL; no recovery" % int(preview.damage)
	return "Loss %d / after battle %d HP" % [int(preview.damage),int(branch.after_hp)]
func draw_tactical_branch(branch: Dictionary,p:Vector2):
	if branch.is_empty():
		draw_wrapped(p,"Healing is not an armed combat skill.",390,14,MUTED,2)
		return
	var preview: Dictionary=branch.get("preview",{})
	label_at(p,tactical_result_text(branch),14,TEAL if preview.get("survivable",false) else RED)
	label_at(p+Vector2(0,19),"Hero strikes %d / retaliations %d" % [int(preview.get("rounds",0)),int(preview.get("retaliations",0))],12,MUTED)
	if preview.get("survivable",false) and branch.get("focus_after")!=null:
		label_at(p+Vector2(0,36),"Focus: spend %d / restore %d / after %d" % [int(branch.focus_cost),int(branch.focus_restored),int(branch.focus_after)],11,TEAL)
		label_at(p+Vector2(0,52),"Victory: %d gold before debt / +%d HP" % [int(preview.get("gold_after",0)),int(preview.get("heal_after",0))],11,TEAL)
func tactical_map_data() -> Dictionary:
	if not comparison: return {}
	var forecast:=comparison_forecast()
	var flank:Dictionary=forecast.get("flank",{})
	if not forecast.get("valid",false) or not flank.get("available",false): return {}
	var start:Vector2i=compare_pos-Vector2i(2,2)
	var cells:Array=[]
	for y in range(5):
		for x in range(5):
			var point:=start+Vector2i(x,y)
			cells.append({"point":point,"token":world.tile(point)})
	return {"start":start,"cells":cells,"player":world.pos,"enemy":compare_pos,"barrier":flank.position,"player_visible":absi(world.pos.x-compare_pos.x)<=2 and absi(world.pos.y-compare_pos.y)<=2}
func draw_tactical_map():
	var data:=tactical_map_data()
	if data.is_empty(): return
	panel(Rect2(1095,70,170,335),Color("0c1928"))
	label_at(Vector2(1105,94),"LOCAL VIEW / N UP",12,GOLD)
	var origin:=Vector2(1110,110)
	for cell in data.cells:
		var offset:Vector2i=cell.point-data.start
		var rect:=Rect2(origin+Vector2(offset)*28,Vector2(26,26))
		draw_rect(rect,Color("344657") if cell.token=="#" else Color("142838"))
		if cell.token not in ["#","."]: draw_circle(rect.get_center(),3,MUTED)
		var mark:=""
		var color:=INK
		if cell.point==data.barrier: mark="F";color=TEAL
		if cell.point==data.enemy: mark="E";color=RED
		if cell.point==data.player: mark="P";color=GOLD
		if mark!="": label_at(rect.position+Vector2(7,19),mark,16,color)
		if cell.point==data.barrier: draw_rect(rect,TEAL,false,2)
		if cell.point==(data.barrier if compare_flank else data.player): draw_rect(rect.grow(1),GOLD,false,2)
	label_at(Vector2(1105,269),"P: YOU (%d,%d)" % [data.player.x,data.player.y],11,GOLD)
	label_at(Vector2(1105,289),"E: ENEMY (%d,%d)" % [data.enemy.x,data.enemy.y],11,RED)
	label_at(Vector2(1105,309),"F: BARRIER (%d,%d)" % [data.barrier.x,data.barrier.y],11,TEAL)
	label_at(Vector2(1105,331),"Coordinates start at 0.",10,MUTED)
	if not data.player_visible: draw_wrapped(Vector2(1105,350),"You are outside this inset.",150,11,GOLD,2)
	draw_wrapped(Vector2(1105,385),"Location only, not a route.",150,11,MUTED,2)
func draw_comparison():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.72))
	panel(Rect2(195,70,890,670),Color("0c1928"))
	label_at(Vector2(220,105),"TACTICAL WHAT-IF / READ ONLY",24,GOLD)
	var forecast:=comparison_forecast()
	var rows: Array=comparison_rows()
	if rows.is_empty():
		label_at(Vector2(225,155),"This enemy is no longer on the current floor.",18)
		return
	compare_page=clampi(compare_page,0,maxi(0,ceili(rows.size()/3.0)-1))
	label_at(Vector2(220,135),World.ENEMIES[world.tile(compare_pos)].name,19,TEAL)
	label_at(Vector2(220,162),"What-if only. Nothing is equipped, armed, moved or attacked.",14,GOLD)
	label_at(Vector2(220,187),"Actual next-battle skill: armed" if world.skill_armed and world.focus>0 else "Actual next-battle skill: off",14,MUTED)
	label_at(Vector2(610,187),"Watch oath ACTIVE" if world.oath_state=="active" else ("Oath released permanently" if world.oath_state=="spent" else "No watch oath"),14,MUTED)
	var flank: Dictionary=forecast.get("flank",{})
	if flank.get("available",false):
		panel(Rect2(220,201,385,33),Color("253748"))
		label_at(Vector2(230,224),"TAB: BARRIER POSITION" if not compare_flank else "TAB: CURRENT POSITION",14,TEAL)
		label_at(Vector2(620,224),"Safe walking: %d steps" % int(flank.steps) if flank.get("reachable",false) else "No cleared-floor safe route",14,GOLD)
	else: label_at(Vector2(220,224),"Current position only; no flank barrier for this enemy.",14,MUTED)
	label_at(Vector2(220,253),"BARRIER POSITION (THEORETICAL)" if compare_flank else "CURRENT POSITION",14,GOLD)
	label_at(Vector2(235,280),"WITHOUT SKILL",14,INK)
	label_at(Vector2(650,280),"SCHOLAR: OUT-OF-BATTLE HEALING" if not forecast.get("skill_supported",false) else ("1 FOCUS SKILL (THEORETICAL)" if world.focus>0 else "1 FOCUS SKILL / UNAVAILABLE: NO FOCUS"),13,TEAL if world.focus>0 else RED)
	rows=rows.slice(compare_page*3,compare_page*3+3)
	for i in rows.size():
		var row: Dictionary=rows[i]
		var y:=305+i*105
		panel(Rect2(220,y-16,840,101),Color("203343"))
		label_at(Vector2(235,y+3),Progression.GEAR[row.id].name+(" [EQUIPPED]" if world.equipped==row.id else ""),16,GOLD)
		draw_tactical_branch(row.get("flank_unarmed" if compare_flank else "unarmed",{}),Vector2(235,y+24))
		draw_tactical_branch(row.get("flank_armed" if compare_flank else "armed",{}),Vector2(650,y+24))
	label_at(Vector2(225,640),"Current build only; changes on the way to this enemy are not included.",13,MUTED)
	label_at(Vector2(225,662),"No equipment changes here. Compare trade-offs, then choose in C.",13,TEAL)
	panel(Rect2(800,682,110,35),Color("253748")); label_at(Vector2(812,706),"PREV",14)
	panel(Rect2(920,682,110,35),Color("253748")); label_at(Vector2(932,706),"NEXT",14)
	label_at(Vector2(225,706),"V / Esc: close. [ / ]: equipment pages. %d / %d" % [compare_page+1,maxi(1,ceili(comparison_rows().size()/3.0))],14,MUTED)
	draw_tactical_map()
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
func crown_cargo_marker(point: Vector2i) -> bool:
	return world.cargo.version==1 and world.cargo.destination=="crown" and world.floor_index==4 and point==Vector2i(1,3)
func draw_cargo_icon(center: Vector2, full: bool, size:=60.0):
	var icon: String="cargo" if full else "cargo_empty"
	if map_art.has(icon): draw_texture_rect(map_art[icon],Rect2(center-Vector2.ONE*size/2,Vector2.ONE*size),false)
	else:
		draw_rect(Rect2(center-Vector2.ONE*size*0.35,Vector2.ONE*size*0.7),Color("a7793e"),full,-1 if full else 2)
		if full:
			draw_line(center-Vector2(size*0.2,0),center+Vector2(size*0.2,0),TEAL,4)
			draw_line(center-Vector2(0,size*0.2),center+Vector2(0,size*0.2),TEAL,4)
func draw_token(c: Vector2, t: String):
	if t=="c":
		draw_cargo_icon(c,world.cargo.state=="shipped")
		return
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
	if int(enemy.get("thorns",0))>0: traits.append(("Thorns %d" if compact else "Contact %d before each strike (last too).") % int(enemy.thorns))
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
	if interaction and interaction_target!="" and t!=interaction_target: return false
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if world.tile(world.pos+d)==t: return true
	return false
func cargo_actions() -> Array:
	var rows: Array=[]
	for offer in world.cargo_offers():
		rows.append([offer[0],"Ship the original supply free / delay its 70 HP" if offer[0]=="cargo_ship" else offer[1]])
	return rows
func at_rope_anchor() -> bool:
	if interaction and interaction_target!="": return false
	var preview:Dictionary=world.rope_preview()
	return preview.valid and world.pos in [preview.origin,preview.landing]
func available_actions() -> Array:
	if not interaction: interaction_target=""
	if not rope_pending.is_empty(): return [["rope_confirm","Confirm: spend 1 focus and cross once"],["rope_cancel","Cancel: stay on this bank"]]
	if rope_inspecting or at_rope_anchor(): return world.rope_offers()
	if cargo_pending: return [["cargo_confirm","Confirm shipment to the fixed destination"],["cargo_cancel","Cancel: keep the floor 1 box sealed"]]
	if cargo_inspecting or (interaction_target=="c" and interaction): return cargo_actions()
	if winch_pending!="": return [["winch_confirm","Confirm permanent winch choice"],["winch_cancel","Cancel: leave both options undecided"]]
	var rows: Array = []
	if checkpoint_pending!=Vector2i.ZERO:
		rows.append(["continue","Spend keys and open this door" if pending_reason=="door" else "Continue upstairs: settle interest now"])
		rows.append(["cancel","Cancel: keep all keys" if pending_reason=="door" else "Stay on this floor: no interest charged"])
		if pending_reason=="door": return rows
	if world.debt()>0: rows.append(["repay","Repay using available gold (fees, interest, principal)"])
	for offer in world.camp_offers():
		if interaction_target=="" or (interaction_target=="U" and offer[0] in ["camp_medicine","camp_focus"]) or (interaction_target=="Y" and offer[0]=="camp_bridge"): rows.append(offer)
	for offer in world.npc_offers():
		if interaction_target=="" or (interaction_target=="J" and offer[0] in ["rescue_accept","rescue_repeater"]) or (interaction_target=="U" and offer[0]=="rescue_supplies"): rows.append(offer)
	if nearby("N"): rows.append_array(world.oath_offers())
	if nearby("Y"): rows.append_array(world.audit_offers())
	if nearby("v"): rows.append_array(world.winch_offers())
	if interaction_target=="": rows.append_array(cargo_actions())
	if interaction_target=="" and world.rope_context(): rows.append(["rope_inspect","Inspect the single-use ferry rope / no cost"])
	if world.cargo_context() and nearby("Q"): rows.append(["cargo_inspect","Read the freight label / no resources spent"])
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
	if rope_inspecting or not rope_pending.is_empty() or (pending_reason=="" and at_rope_anchor()):
		draw_rope_confirmation()
		return
	if cargo_pending or cargo_inspecting or (interaction and interaction_target=="c") or (interaction_target=="" and world.cargo_context() and not nearby("Q") and pending_reason==""):
		draw_cargo()
		return
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
func draw_rope_marker():
	var preview:Dictionary=world.rope_preview()
	if not preview.valid:return
	var origin:Vector2=ORIGIN+Vector2(preview.origin)*CELL+Vector2(CELL/2,CELL/2)
	var landing:Vector2=ORIGIN+Vector2(preview.landing)*CELL+Vector2(CELL/2,CELL/2)
	var art:String="rope_spent" if preview.status=="spent" else "rope_ready"
	if map_art.has(art):draw_texture_rect(map_art[art],Rect2(origin-Vector2(27,27),Vector2(54,54)),false)
	else:draw_arc(origin,18,0,TAU,20,GOLD,3)
	label_at(origin+Vector2(-25,-18),"E",13,GOLD)
	if preview.status!="ready":return
	# Offset above the guard so the direction cue never conceals its identity.
	var from:Vector2=origin+Vector2(0,-25)
	var to:Vector2=landing+Vector2(0,-25)
	draw_line(from,to,GOLD,2)
	var direction:float=signf(to.x-from.x)
	draw_line(to,to+Vector2(-direction*8,-6),GOLD,2);draw_line(to,to+Vector2(-direction*8,6),GOLD,2)
	draw_rect(Rect2(landing-Vector2(27,27),Vector2(54,54)),GOLD,false,2)
func draw_rope_confirmation():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	label_at(Vector2(290,158),"ONE-WAY FERRY ROPE",24,GOLD)
	var preview:Dictionary=world.rope_preview()
	if preview.valid:
		label_at(Vector2(290,205),"Takeoff (%d,%d) -> landing (%d,%d) / cost 1 focus" % [preview.origin.x,preview.origin.y,preview.landing.x,preview.landing.y],18,TEAL)
		draw_wrapped(Vector2(290,245),"The rope snaps after crossing. The guardian stays alive. No kill, gold or victory recovery.",700,17,INK,3)
		draw_wrapped(Vector2(290,305),"Return requires another route, the bridge, or fighting the guardian. U can undo the complete crossing.",700,16,INK,3)
		draw_wrapped(Vector2(290,520),"Last focus: your armed skill will be cancelled." if preview.disarm else "Any currently armed skill stays prepared if focus remains.",700,15,GOLD,2)
	draw_wrapped(Vector2(290,570),preview.reason,700,15,TEAL,3)
	action_rows=visible_actions()
	for i in action_rows.size():
		var rect:=Rect2(285,375+i*43,720,37)
		panel(rect,Color("253748"));action_label(rect,"%d  %s" % [i+1,action_rows[i][1]])
	label_at(Vector2(290,672),"Click a choice or press its number. E / Esc closes without choosing.",14,MUTED)
func draw_cargo():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	label_at(Vector2(290,158),"CONFIRM SEALED FREIGHT" if cargo_pending else "SEALED FREIGHT LABEL",24,GOLD)
	draw_wrapped(Vector2(290,202),world.cargo_description(),705,17,INK,7)
	label_at(Vector2(290,354),"Shipping spends no key. The 70 HP is delayed, never duplicated.",15,TEAL)
	action_rows=visible_actions()
	for i in action_rows.size():
		var rect:=Rect2(285,375+i*43,720,37)
		panel(rect,Color("253748"));action_label(rect,"%d  %s" % [i+1,action_rows[i][1]])
	if action_rows.is_empty(): draw_wrapped(Vector2(290,410),"No collection is available here yet. Check the label and guard condition.",700,17,MUTED,2)
	draw_wrapped(Vector2(290,570),"Shipping and collection are manual. U can undo the complete action.",700,15,TEAL,2)
	draw_wrapped(Vector2(290,625),status_message(),700,14,TEAL,2)
	label_at(Vector2(290,672),"Click a choice or press its number. E / Esc closes without choosing.",14,MUTED)
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
	if id=="rope_inspect":rope_inspecting=true;interaction=true;interaction_page=0;return
	if id=="rope_cancel":rope_pending.clear();return
	if id=="rope_confirm":
		if rope_pending.is_empty():return
		var expected:Dictionary=rope_pending.duplicate(true)
		rope_pending.clear()
		if expected!=world.save_data():
			ui_notice="Journey changed. Inspect the rope again before confirming."
			return
		await perform_action("rope_cross",true)
		return
	if id=="rope_cross" and not confirmed:
		if not world.rope_preview().available:return
		rope_pending=world.save_data().duplicate(true);rope_inspecting=true;interaction=true;interaction_page=0
		return
	if id=="cargo_inspect": cargo_inspecting=true; interaction=true; interaction_page=0; return
	if id=="cargo_cancel": cargo_pending=false; return
	if id=="cargo_confirm":
		if not cargo_pending: return
		cargo_pending=false
		await perform_action("cargo_ship",true)
		return
	if id=="cargo_ship" and not confirmed:
		cargo_pending=true; interaction=true; interaction_page=0
		return
	if id=="winch_cancel": winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; return
	if id=="winch_confirm":
		var choice: String=winch_pending
		winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false
		if choice!="": await perform_action(choice,true)
		return
	if id in ["winch_rescue","winch_armory"] and not confirmed:
		winch_pending=id; interaction=true; interaction_page=0
		return
	if id=="cancel":
		checkpoint_pending=Vector2i.ZERO; pending_reason=""; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; return
	if id=="continue":
		var direction := checkpoint_pending
		checkpoint_pending=Vector2i.ZERO; pending_reason=""; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false
		await move(direction,true)
		return
	reset_armed=false
	var result: Dictionary=await session.action(id)
	apply_session_result(result)
func action_effect(id: String):
	if id=="rope_cross": rope_pending.clear(); rope_inspecting=false; interaction=false; interaction_target=""
	if id in ["cargo_ship","cargo_claim"]: cargo_pending=false
	if id=="expedition":
		book=false; journal=false; growth=false; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; battle_time=0.0
		checkpoint_pending=Vector2i.ZERO; pending_reason=""
	if id in ["spring","drain","quest_bridge","camp_bridge"]: play_sound("water")
	elif id in ["cargo_claim","expedition","camp_medicine","camp_focus","rescue_repeater","rescue_supplies","buy","quest_gold","quest_scroll","relic_buckler","relic_duelist","secret","secret_provisions","secret_voucher","audit_medicine"]: play_sound("pickup")
	if id.begins_with("hero_") or id.begins_with("talent_"): growth=false
	if id.begins_with("talent_"): talent_selected=""; talent_submitted=false; talent_notice_time=0.0
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
				rows.append(["legacy_focus","Emergency focus: %d supplies left" % world.legacy_reserves,"Restore 1 focus only when not full. Otherwise no supply is spent."])
		1:
			for id in world.inventory:
				if Progression.GEAR.has(id): rows.append(["equip_"+id,Progression.GEAR[id].name+(" [EQUIPPED]" if world.equipped==id else ""),Progression.GEAR[id].description])
		2:
			for id in world.talent_options(): rows.append(["talent_"+id,Progression.TALENTS[id].name,Progression.TALENTS[id].description])
	return rows
func visible_growth_actions() -> Array:
	var rows: Array=growth_actions()
	if growth_tab!=1: return rows
	gear_page=clampi(gear_page,0,maxi(0,ceili(rows.size()/3.0)-1))
	return rows.slice(gear_page*3,gear_page*3+3)
func open_growth():
	if not talent_submitted: talent_selected=""
	talent_target_index=0
	close_attunement()
	cancel_walk()
	comparison=false
	growth=not growth; journal=false; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; book=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
	if growth: growth_tab=2 if not world.talent_options().is_empty() else 0
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
	if growth_tab==2:
		draw_talent_folio()
		return
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
	elif growth_tab==0: draw_wrapped(Vector2(225,560),world.legacy_summary(),815,14,MUTED,3)
	else: label_at(Vector2(225,610),"Focus is finite. First visits restore it; repeating floors cannot farm it.",15,MUTED)
	label_at(Vector2(225,646),display(status_message()).left(105),14,TEAL)
	label_at(Vector2(225,697),"Choose 1-3. Tab changes section. Esc: keep default Warden." if world.moves==0 else "Click a card / press 1-3. Tab changes section. C / Esc closes.",15,MUTED)
func open_journal():
	close_attunement()
	cancel_walk()
	comparison=false
	journal=not journal
	journal_page=0
	journal_details=false
	book=false; growth=false; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
func floor_has(index: int, token: String) -> bool:
	for row in world.floors[index]:
		if token in row: return true
	return false
func return_target_rows() -> Array:
	return world.exploration_goals() if world!=null else []
func validate_pinned_target():
	if pinned_target=="": return
	for row in return_target_rows():
		if row.id==pinned_target: return
	pinned_target=""
func toggle_target(index: int):
	var rows:=return_target_rows()
	if index<0 or index>=rows.size(): return
	pinned_target="" if pinned_target==rows[index].id else str(rows[index].id)
	queue_redraw()
func pinned_target_text() -> String:
	validate_pinned_target()
	for row in return_target_rows():
		if row.id==pinned_target:
			return target_heading(row)+" / "+display(row.status)
	return "J: return targets" if not return_target_rows().is_empty() else quest_hint()
func target_heading(row: Dictionary) -> String:
	return (display("Floor %d" % (int(row.floor)+1))+" / " if int(row.floor)>=0 else "")+display(row.title)
func return_target_rect(index: int) -> Rect2:
	return Rect2(250,194+index*108,780,100)
func draw_return_targets():
	var rows:=return_target_rows()
	if rows.is_empty(): draw_wrapped(Vector2(260,245),"No unfinished known targets. Explore to discover more.",730,18,MUTED,3)
	for i in rows.size():
		var row: Dictionary=rows[i]
		var r:=return_target_rect(i)
		panel(r,Color("214337") if row.id==pinned_target else Color("172b3c"))
		label_at(r.position+Vector2(12,24),str(i+1)+"  "+target_heading(row),18,GOLD)
		var lines: Array=row.lines
		for j in mini(lines.size(),3):
			var line: String=display(str(lines[j]))
			var size:=14
			while size>11 and font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>748: size-=1
			label_at(r.position+Vector2(12,45+j*19),line,size,INK)
	label_at(Vector2(260,663),"1-4 / click: pin or unpin. Read-only; no movement or collection.",14,TEAL)
	label_at(Vector2(260,688),"J / Esc: close. Tab: detailed notes.",14,MUTED)
func draw_target_marker():
	validate_pinned_target()
	for row in return_target_rows():
		if row.id!=pinned_target or int(row.floor)!=world.floor_index: continue
		var point: Vector2i=row.pos
		if point.x<0 or point.y<0 or not world.floor_seen[world.floor_index]: continue
		var p:=ORIGIN+Vector2(point)*CELL
		draw_rect(Rect2(p+Vector2(3,3),Vector2(58,58)),GOLD,false,3)
		label_at(p+Vector2(4,17),"J",14,GOLD)
func journal_lines() -> Array:
	var entries: Array=[]
	entries.append("Seed %d / %s / floor %d / %d steps" % [world.seed_value,Progression.HEROES[world.hero_id].name,world.floor_index+1,world.moves])
	if world.rescue_state in [1,2]: entries.append_array(world.npc_journal())
	entries.append_array(world.oath_journal())
	entries.append_array(world.audit_journal())
	entries.append_array(world.audit_lines())
	entries.append_array(world.winch_journal())
	entries.append_array(world.cargo_journal())
	entries.append_array(world.attunement_journal())
	entries.append(world.legacy_summary())
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
	label_at(Vector2(260,174),"Read-only snapshot. Close this journal, then press L to reload." if session!=null and session.read_only else "Only what you have discovered. Reading spends nothing.",15,MUTED)
	panel(Rect2(800,121,220,37),Color("253748"))
	label_at(Vector2(812,147),"TAB: TARGETS" if journal_details else "TAB: DETAILS",14,TEAL)
	if not journal_details:
		draw_return_targets()
		return
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
func battle_phase_state(phase: float) -> Dictionary:
	var enemy: Dictionary=World.ENEMIES.get(battle_kind,{})
	var state={"text":"Skill prepared" if battle_skill else "No active skill", "hero_attack":false,"enemy_attack":false,"contact":false,"blocked":false}
	if phase>=0.12 and phase<0.24:
		var suppression: String=str(battle_details.get("first_strike_suppression","none"))
		if enemy.get("first_strike",false):
			if suppression!="none":
				state.text="Flank barrier cancels the first strike" if suppression=="flank" else "Oath cancels the first strike"
				state.blocked=true
			else:
				state.text="AMBUSH: enemy strikes first"
				state.enemy_attack=true
		else: state.text="No opening ambush"
	elif phase>=0.24 and phase<0.30:
		state.enemy_attack=int(battle_details.get("feint_damage",0))>0
		state.text="Opening feint: extra enemy counter" if state.enemy_attack else "Approaching the enemy"
	elif phase>=0.30 and phase<0.40:
		state.contact=int(enemy.get("thorns",0))>0
		state.text="Contact thorns: before every hero strike, including the last" if state.contact else "Approaching the enemy"
	elif phase>=0.40 and phase<0.65:
		state.text="Precision shot" if battle_hero=="ranger" and battle_skill else "Hero attacks"
		state.hero_attack=true
	elif phase>=0.65 and phase<0.80:
		state.text="Retaliation resolved"
		state.enemy_attack=int(battle_details.get("retaliations",0))>0
	elif phase>=0.80: state.text="Victory saved: actual gains below"
	return state
func battle_gain_lines() -> Array[String]:
	if battle_receipt.is_empty(): return []
	return [
		"HP %d -> %d / loss %d / recovered +%d" % [battle_receipt.hp_before,battle_receipt.hp_after,battle_receipt.hp_lost,battle_receipt.hp_restored],
		"Focus %d -> %d / skill spent %d / actually restored +%d" % [battle_receipt.focus_before,battle_receipt.focus_after,battle_receipt.focus_spent,battle_receipt.focus_restored],
		"Gold loot %d / debt paid %d / pocket +%d (%d -> %d)" % [battle_receipt.gold_reward,battle_receipt.debt_paid,int(battle_receipt.gold_after)-int(battle_receipt.gold_before),battle_receipt.gold_before,battle_receipt.gold_after]
	]
func draw_battle():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.58))
	panel(Rect2(245,125,790,590),Color("0c1928"))
	label_at(Vector2(280,163),"BATTLE REPLAY",23,GOLD)
	var phase := clampf(1.0-battle_time/2.4,0.0,1.0)
	var state:=battle_phase_state(phase)
	var hero_pos := Vector2(450,300)
	var enemy_pos := Vector2(825,300)
	if state.enemy_attack:
		var t: float=(phase-0.12)/0.12 if phase<0.24 else ((phase-0.24)/0.06 if phase<0.30 else (phase-0.65)/0.15)
		enemy_pos.x-=sin(t*PI)*45
		# Suppressed ambushes never enter this branch or flash a damage ring.
		draw_circle(hero_pos,47,Color(0.9,0.35,0.3,0.3))
	if state.blocked: draw_circle(hero_pos,51,Color(0.3,0.8,0.75,0.8),false,3)
	if state.contact:
		draw_circle(enemy_pos,52,Color(0.85,0.65,0.3,0.8),false,3)
		draw_line(hero_pos+Vector2(53,0),enemy_pos-Vector2(53,0),Color("ba8759"),2)
	if state.hero_attack:
		var t: float=(phase-0.40)/0.25
		if battle_hero=="warden": hero_pos.x+=sin(t*PI)*65
		var projectile:=hero_pos.lerp(enemy_pos,t)
		if battle_hero=="scholar": draw_circle(projectile,8,Color("c5a3ed"))
		else: draw_line(projectile-Vector2(17,8),projectile+Vector2(17,-8),GOLD,3)
	draw_wrapped(Vector2(280,195),state.text,720,15,TEAL,2)
	draw_ellipse_shadow(hero_pos); draw_ellipse_shadow(enemy_pos)
	battle_figure(battle_hero,hero_pos,true); battle_figure(ENEMY_ART.get(battle_kind,""),enemy_pos,false)
	label_at(Vector2(365,375),Progression.HEROES[battle_hero].name,19,TEAL)
	label_at(Vector2(730,375),battle_name,19,GOLD)
	label_at(Vector2(280,411),"%d hero strikes  /  %d damage per hit  /  %d HP lost" % [int(battle_details.get("rounds",0)),int(battle_details.get("hit",0)),battle_loss],18)
	var detail_lines:=battle_breakdown(battle_details)
	for i in detail_lines.size(): label_at(Vector2(280,439+i*22),detail_lines[i],14,MUTED)
	var gain_lines:=battle_gain_lines()
	for i in gain_lines.size(): label_at(Vector2(280,543+i*25),gain_lines[i],16,TEAL)
	draw_wrapped(Vector2(280,637),"Order illustration, not every strike. Damage saved once; any key / click skips.",720,14,GOLD,2)

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
				KEY_ESCAPE: strategy_selection=""; setup_allocation={"study":0,"reserve":0}
				KEY_0: strategy_selection="none"
				KEY_Q: adjust_setup("study",1)
				KEY_A: adjust_setup("study",-1)
				KEY_W: adjust_setup("reserve",1)
				KEY_S: adjust_setup("reserve",-1)
				KEY_1,KEY_2,KEY_3:
					var index: int=event.keycode-KEY_1
					if index<world.draft.offers.size(): strategy_selection=world.draft.offers[index]
				KEY_ENTER: confirm_strategy()
				KEY_N: request_restart("new")
				KEY_R: request_restart("replay")
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var mouse: Vector2=get_global_mouse_position()
			for i in world.draft.offers.size():
				if Rect2(220,200+i*95,500,88).has_point(mouse): strategy_selection=world.draft.offers[i]
			if Rect2(220,490,500,46).has_point(mouse): strategy_selection="none"
			for j in 2:
				var node: String=["study","reserve"][j]
				if Rect2(745,282+j*145,70,34).has_point(mouse): adjust_setup(node,-1)
				if Rect2(975,282+j*145,70,34).has_point(mouse): adjust_setup(node,1)
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
			if Rect2(220,201,385,33).has_point(get_global_mouse_position()): toggle_compare_position(); return
			if comparison_rows().size()>3:
				if Rect2(800,682,110,35).has_point(get_global_mouse_position()): compare_page=maxi(0,compare_page-1); return
				if Rect2(920,682,110,35).has_point(get_global_mouse_position()): compare_page+=1; return
			if not Rect2(195,70,890,670).has_point(get_global_mouse_position()): close_comparison()
			return
		if book:
			if Rect2(760,115,120,40).has_point(get_global_mouse_position()): book_page=maxi(0,book_page-1)
			elif Rect2(880,115,150,40).has_point(get_global_mouse_position()): book_page+=1
			else: book=false
			return
		if journal:
			if Rect2(800,121,220,37).has_point(get_global_mouse_position()): journal_details=not journal_details
			elif not journal_details:
				for i in return_target_rows().size():
					if return_target_rect(i).has_point(get_global_mouse_position()): toggle_target(i); return
				if not Rect2(230,100,820,610).has_point(get_global_mouse_position()): journal=false
			elif Rect2(830,651,80,37).has_point(get_global_mouse_position()): journal_page=maxi(0,journal_page-1)
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
			if growth_tab==2: talent_folio_click(get_global_mouse_position()); return
			var choices := visible_growth_actions()
			for i in choices.size():
				if Rect2(225,270+i*87,830,76).has_point(get_global_mouse_position()): perform_action(choices[i][0]); return
			if not Rect2(195,80,890,650).has_point(get_global_mouse_position()): growth=false
			return
		if interaction:
			var rows := visible_actions()
			for i in rows.size():
				if Rect2(285,375+i*43,720,37).has_point(get_global_mouse_position()): perform_action(rows[i][0]); return
			if not Rect2(260,120,770,570).has_point(get_global_mouse_position()): interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
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
					4: open_interaction()
					5: open_growth()
					6: open_journal()
					7: open_travel()
				return
		hover=Vector2i(((get_global_mouse_position()-ORIGIN)/CELL).floor())
		await map_click(hover)
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
			if event.keycode==KEY_ESCAPE: close_comparison()
			elif event.keycode==KEY_TAB: toggle_compare_position()
			elif event.keycode==KEY_BRACKETLEFT: compare_page=maxi(0,compare_page-1)
			elif event.keycode==KEY_BRACKETRIGHT: compare_page+=1
			return
		if event.keycode==KEY_J: open_journal(); return
		if event.keycode==KEY_C: open_growth(); return
		if event.keycode==KEY_H: book=not book; journal=false; growth=false; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""; return
		if event.keycode==KEY_E:
			if interaction:
				interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false
				rope_pending.clear(); rope_inspecting=false; interaction_page=0
				journal=false; growth=false; book=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
			else: open_interaction()
			return
		if event.keycode==KEY_ESCAPE: book=false; journal=false; growth=false; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""; return
		if journal:
			if event.keycode==KEY_TAB: journal_details=not journal_details; return
			if not journal_details:
				if event.keycode>=KEY_1 and event.keycode<=KEY_4: toggle_target(event.keycode-KEY_1)
				return
			if event.keycode==KEY_BRACKETLEFT: journal_page=maxi(0,journal_page-1)
			if event.keycode==KEY_BRACKETRIGHT: journal_page+=1
			return
		if growth:
			if event.keycode==KEY_TAB: growth_tab=(growth_tab+1)%3; return
			if growth_tab==2:
				if event.keycode==KEY_BRACKETLEFT: cycle_talent_target(-1)
				elif event.keycode==KEY_BRACKETRIGHT: cycle_talent_target(1)
				elif event.keycode==KEY_ENTER: confirm_talent()
				elif event.keycode>=KEY_1 and event.keycode<=KEY_3: select_talent(event.keycode-KEY_1)
				return
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
		history.clear(); journal=false; journal_page=0; reset_armed=false; battle_time=0.0; growth=true; growth_tab=0; gear_page=0; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""
	else:
		reset_armed=true; reset_mode=mode; selected_run_mode="safe"
		ui_notice="Press %s again: %s. Autosave will be replaced." % ["R" if mode=="replay" else "N","replay this seed" if mode=="replay" else "start a new seed"]
func move(direction: Vector2i, confirmed:=false):
	if not can_mutate(): return
	interaction_target=""
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
func step_effect(enemy: String, hero_before: String, combat: Dictionary={}):
	if World.ENEMIES.has(enemy) and not world.won:
		for i in Progression.TALENT_TIERS.size():
			if world.kills==Progression.TALENT_TIERS[i].kills:
				talent_notice_tier=i; talent_notice_time=6.0
	if World.ENEMIES.has(enemy): play_sound("victory" if world.won else "impact")
	elif enemy in ["D","L"]: play_sound("door")
	elif enemy in ["k","h","a","d","C","I","T","$","A","P","m"]: play_sound("pickup")
	elif enemy=="~": play_sound("water")
	else: play_sound("move")
	if World.ENEMIES.has(enemy):
		var resolved: Dictionary=world.last_battle.duplicate(true)
		battle_time=2.4; battle_name=World.ENEMIES[enemy].name; battle_loss=int(resolved.get("damage",0))
		battle_receipt=combat.duplicate(true)
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
	strategy_selection=""; strategy_submitted=false; setup_allocation={"study":0,"reserve":0}
	talent_selected=""; talent_submitted=false; talent_notice_time=0.0
	close_attunement(); cancel_walk(); close_travel(); finish_pending=""; clear_lethal(); death_report=false; reset_armed=false
	var result: Dictionary=await session.reacquire_and_reload()
	if result.get("status")=="empty" and world==null:
		result=await session.new_run(initial_seed())
	apply_session_result(result)
	if not result.get("ok",false): return
	journal=false; journal_page=0; interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; growth=result.get("committed",false) and result.get("effect",{}).get("operation","")=="create"; gear_page=0; book=false; comparison=false
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
	invalidate_hover_walk()
	walk_feedback_time=0.0
	if result.get("ok",false):
		world=session.world; history=session.history; ui_notice=""
		compare_cache.clear(); compare_cache_world=null
		if result.get("status","")=="loaded" or result.get("effect",{}).get("operation","")=="create": pinned_target=""; interaction_target=""
		validate_pinned_target()
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
		"step": step_effect(str(effect.get("token",".")),str(effect.get("hero",world.hero_id)),effect.get("combat",{}))
		"action": action_effect(str(effect.get("input","")))
		"walk": play_sound("move")
		"undo": battle_time=0.0; talent_selected=""; talent_submitted=false; talent_notice_time=0.0
		"death":
			clear_lethal(); cancel_walk(); battle_time=0.0; death_report=true; death_page=0; play_sound("impact")
		"settle":
			finish_pending=""; cancel_walk(); battle_time=0.0; play_sound("victory")
		"strategy":
			strategy_selection=""; strategy_submitted=false; setup_allocation={"study":0,"reserve":0}; cancel_walk(); growth=true; growth_tab=0
		"create":
			talent_selected=""; talent_submitted=false; talent_notice_time=0.0
			strategy_selection=""; strategy_submitted=false; setup_allocation={"study":0,"reserve":0}
			clear_lethal(); death_report=false
			finish_pending=""
			close_attunement(); close_travel(); comparison=false; journal=false; book=false
			reset_armed=false; battle_time=0.0; growth=true; growth_tab=0; gear_page=0
			interaction=false; interaction_target=""; winch_pending=""; cargo_pending=false; cargo_inspecting=false; rope_pending.clear(); rope_inspecting=false; checkpoint_pending=Vector2i.ZERO; pending_reason=""

func is_terminal() -> bool:
	return session!=null and session.get("terminal")==true
func settlement_outcome() -> String:
	if world.won: return "victory" if world.expedition_started else "chapter1"
	return "withdrawn"
func request_finish():
	if not can_mutate(): return
	cancel_walk(); close_attunement(); close_travel()
	book=false; growth=false; interaction=false; interaction_target=""; journal=false; comparison=false; battle_time=0.0
	finish_pending=settlement_outcome(); reset_armed=false
func confirm_finish():
	if finish_pending=="" or not can_mutate(): return
	apply_session_result(await session.finish(finish_pending))
func draw_finish_confirmation():
	panel(Rect2(210,180,860,440),Color("101c2a"))
	label_at(Vector2(245,225),"END THIS JOURNEY?",26,GOLD)
	draw_wrapped(Vector2(245,270),"This permanently ends this run. Undo will no longer be available. Your current items do not carry into a new run.",770,19,INK,3)
	draw_wrapped(Vector2(245,355),"First records of floors 3 / 5 / 8 each grant one point of per-run capacity. Retirement and defeat grant the same first-record reward; repeats grant nothing.",770,18,TEAL,3)
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
		"Legacy points gained: %d / capacity for each new run: %d" % [receipt.get("milestones",[]).size(),profile.get("milestones",[]).size()],
		"Reassign only in a new run. Unused points are allowed; repeated records grant nothing."]
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
	if not setup_preview().get("can_choose",false): return
	strategy_submitted=true
	apply_session_result(await session.choose_strategy(strategy_selection,setup_allocation.duplicate(true)))
func skill_sources_text(info: Dictionary) -> String:
	return "Skill %d = base %d + training %d + gear %d + strategy %d + legacy %d (overflow %d)" % [info.effective,info.base,info.training,info.gear,info.get("strategy",0),info.get("legacy",0),info.get("overflow",0)]
func setup_hero_effects_text(preview: Dictionary) -> String:
	var effects: Dictionary=preview.hero_effects
	return "Warden: %d%% block / Ranger: ignore %d DEF / Scholar: heal %d HP" % [effects.warden_block_percent,effects.ranger_ignore_def,effects.scholar_heal]
func setup_preview() -> Dictionary:
	return world.setup_preview(strategy_selection if strategy_selection!="" else "none",setup_allocation)
func adjust_setup(node: String,change: int):
	if strategy_submitted or not strategy_pending() or node not in ["study","reserve"]: return
	var candidate: Dictionary=setup_allocation.duplicate(true)
	candidate[node]=int(candidate[node])+change
	var preview: Dictionary=world.setup_preview(strategy_selection if strategy_selection!="" else "none",candidate)
	if preview.get("valid",false): setup_allocation=candidate
func draw_strategy_draft():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.8))
	panel(Rect2(190,80,900,650),Color("101c2a"))
	label_at(Vector2(220,122),"PREPARE THIS RUN / STRATEGY + LEGACY POINTS",23,GOLD)
	draw_wrapped(Vector2(220,155),"One confirmation locks both choices. You may leave points unused. No modifier means original strategy and zero points.",840,15,INK,2)
	var preview:=setup_preview()
	label_at(Vector2(740,190),"Capacity %d / unassigned %d" % [int(preview.get("capacity",0)),int(preview.get("remaining",0))],16,TEAL)
	for i in world.draft.offers.size():
		var id: String=world.draft.offers[i]
		var card: Dictionary=world.strategy_preview(id)
		var r:=Rect2(220,200+i*95,500,88)
		panel(r,Color("345c62") if strategy_selection==id else Color("203343"))
		label_at(r.position+Vector2(12,23),"%d  %s" % [i+1,display(card.name)],18,GOLD)
		draw_wrapped(r.position+Vector2(12,44),card.description,476,14,INK,3)
	panel(Rect2(220,490,500,46),Color("345c62") if strategy_selection=="none" else Color("203343"))
	label_at(Vector2(232,519),"0  Original strategy / points still optional",17,TEAL)
	for j in 2:
		var node: String=["study","reserve"][j]
		var y: float=200+j*145
		panel(Rect2(735,y,325,135),Color("203343"))
		label_at(Vector2(747,y+24),"Study: %d / 2" % setup_allocation.study if j==0 else "Emergency focus: %d / 2" % setup_allocation.reserve,18,GOLD)
		draw_wrapped(Vector2(747,y+46),"Each point: +2 skill levels, capped at 20." if j==0 else "Each point: one +1 focus supply this run. Use in C when not full.",298,14,INK,2)
		panel(Rect2(745,y+82,70,34),Color("253748")); panel(Rect2(975,y+82,70,34),Color("345c62"))
		label_at(Vector2(755,y+106),"A: -" if j==0 else "S: -",16)
		label_at(Vector2(985,y+106),"Q: +" if j==0 else "W: +",16)
	label_at(Vector2(740,510),"New run: reassign, never farm deaths.",13,MUTED)
	if preview.get("valid",false):
		var info: Dictionary=preview.skill_level_info
		label_at(Vector2(220,562),skill_sources_text(info),15,TEAL)
		draw_wrapped(Vector2(220,589),setup_hero_effects_text(preview),840,15,INK,2)
	label_at(Vector2(220,632),"Locked for this run. Undo and reload cannot reassign. Zero points are allowed.",15,GOLD)
	panel(Rect2(220,650,840,45),Color("345c62") if strategy_selection!="" else Color("203343"))
	label_at(Vector2(235,679),"ENTER: LOCK WHOLE PLAN / Esc: clear preview",18)
	draw_wrapped(Vector2(220,715),ui_notice if ui_notice!="" else "N: new seed / R: same seed new run / L: reload / F2: language",840,13,GOLD if ui_notice!="" else MUTED,1)

func folio_progress_text() -> String:
	var progress: Dictionary=world.talent_progress()
	if progress.available: return "TALENT FOLIO READY / %d kills / C" % world.kills
	if int(progress.next_kills)>0: return "Next folio: %d / %d kills" % [world.kills,progress.next_kills]
	return "All talent folios chosen / %d kills" % world.kills
func draw_talent_notice():
	panel(Rect2(40,650,670,100),Color("173d48"))
	label_at(Vector2(58,678),"TALENT FOLIO %d UNLOCKED" % (talent_notice_tier+1),22,GOLD)
	draw_wrapped(Vector2(58,711),"C: inspect three fixed choices. You can keep exploring and choose later.",630,17,INK,2)
func talent_targets() -> Array:
	return world.talent_preview_targets()
func cycle_talent_target(direction: int):
	var targets:=talent_targets()
	if not targets.is_empty(): talent_target_index=posmod(talent_target_index+direction,targets.size())
func talent_card_preview(id: String) -> Dictionary:
	var targets:=talent_targets()
	if targets.is_empty(): return world.talent_preview(id)
	talent_target_index=clampi(talent_target_index,0,targets.size()-1)
	var target: Dictionary=targets[talent_target_index]
	return world.talent_preview(id,target.kind,target.pos,target.floor)
func select_talent(index: int):
	if talent_submitted: return
	var options: Array=world.talent_options()
	if index>=0 and index<options.size(): talent_selected=options[index]
func confirm_talent():
	if talent_selected=="" or talent_submitted or not can_mutate(): return
	if not world.talent_preview(talent_selected).get("can_choose",false): return
	talent_submitted=true
	await perform_action("talent_"+talent_selected)
func talent_folio_click(mouse: Vector2):
	if Rect2(815,225,105,38).has_point(mouse): cycle_talent_target(-1); return
	if Rect2(935,225,105,38).has_point(mouse): cycle_talent_target(1); return
	for i in world.talent_options().size():
		if Rect2(225,290+i*103,830,96).has_point(mouse): select_talent(i); return
	if Rect2(225,640,830,40).has_point(mouse): confirm_talent(); return
	if not Rect2(195,80,890,650).has_point(mouse): growth=false
func talent_loss_text(preview: Dictionary) -> String:
	if not preview.get("valid",false): return display("Cannot penetrate defense")
	return str(int(preview.damage))+display(" HP loss")+(" / "+display("LETHAL") if not preview.get("survivable",false) else "")
func learned_talent_cards() -> Array:
	var cards: Array=[]
	for id in world.talents:
		cards.append({"id":id,"name":Progression.TALENTS[id].name,"description":Progression.TALENTS[id].description})
	return cards
func draw_talent_folio():
	var learned:=learned_talent_cards()
	if world.talent_options().is_empty():
		label_at(Vector2(225,248),folio_progress_text(),19,TEAL)
		label_at(Vector2(225,278),"Learned talents (read-only)",17,GOLD)
		for i in learned.size():
			var r:=Rect2(225,295+i*100,830,90)
			panel(r,Color("203343"))
			label_at(r.position+Vector2(12,26),learned[i].name,20,GOLD)
			draw_wrapped(r.position+Vector2(12,52),learned[i].description,805,16,INK,2)
		label_at(Vector2(225,620),"Run talents are separate from legacy strategy and equipment attunement.",15,MUTED)
		label_at(Vector2(225,666),"Esc: return to the map. Learned talents remain active.",16,TEAL)
		return
	var targets:=talent_targets()
	if not targets.is_empty():
		talent_target_index=clampi(talent_target_index,0,targets.size()-1)
		var target: Dictionary=targets[talent_target_index]
		label_at(Vector2(225,248),"%s / F%d (%d,%d)" % [display(World.ENEMIES[target.kind].name),target.floor+1,target.pos.x,target.pos.y],17,TEAL)
		panel(Rect2(815,225,105,38),Color("253748"));label_at(Vector2(825,250),"[ PREV TARGET",12)
		panel(Rect2(935,225,105,38),Color("253748"));label_at(Vector2(945,250),"NEXT TARGET ]",12)
	else: label_at(Vector2(225,248),"No known living target. Descriptions remain available.",16,TEAL)
	label_at(Vector2(225,277),"Same current build; remote previews grant no flank barrier.",14,MUTED)
	var options: Array=world.talent_options()
	for i in options.size():
		var preview:=talent_card_preview(options[i])
		var r:=Rect2(225,290+i*103,830,96)
		panel(r,Color("345c62") if talent_selected==options[i] else Color("203343"))
		label_at(r.position+Vector2(12,23),"%d  %s" % [i+1,display(preview.name)],19,GOLD)
		draw_wrapped(r.position+Vector2(12,44),preview.description,805,14,INK,2)
		if preview.get("before",{}).has("damage"):
			label_at(r.position+Vector2(12,74),"%s  ->  %s" % [talent_loss_text(preview.before),talent_loss_text(preview.after)],14,TEAL)
			label_at(r.position+Vector2(12,91),world.victory_reward_text(preview.after),12,MUTED)
	if options.is_empty(): draw_wrapped(Vector2(225,330),folio_progress_text(),800,21,GOLD,2)
	var learned_names: Array[String]=[]
	for card in learned: learned_names.append(display(card.name))
	label_at(Vector2(225,620),"Learned: %s" % (", ".join(learned_names) if not learned_names.is_empty() else display("None")),15,MUTED)
	panel(Rect2(225,640,830,40),Color("345c62") if talent_selected!="" else Color("203343"))
	label_at(Vector2(240,666),"1-3: preview / Enter: learn selected talent / Esc: decide later",16,TEAL)
	draw_wrapped(Vector2(225,704),ui_notice if ui_notice!="" else "Fixed offers. Viewing does not spend resources or reroll choices.",830,14,GOLD if ui_notice!="" else MUTED,1)
