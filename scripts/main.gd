extends Node2D

const World = preload("res://scripts/world.gd")
const Progression = preload("res://scripts/progression.gd")
const CELL := 49.0
const ORIGIN := Vector2(350,142)
const INK := Color("e5ebee")
const MUTED := Color("7e96a4")
const GOLD := Color("e9bd6d")
const TEAL := Color("65dac4")
var world = initial_world()
var font = ThemeDB.fallback_font
var art: Texture2D
var combat_art: Dictionary = {}
const ENEMY_ART := {"s":"mossling","g":"sentinel","u":"stalker","b":"briar","V":"colossus","K":"regent","B":"regent"}
var history: Array = []
var save_path := "user://journey-v3.json"
var book := false
var growth := true
var growth_tab := 0
var reset_mode := ""
var battle_details: Dictionary = {}
var battle_kind := "s"
var battle_hero := "warden"
var battle_skill := false
var interaction_page := 0
var interaction := false
var battle_time := 0.0
var battle_name := ""
var battle_loss := 0
var action_rows: Array = []
var checkpoint_pending := Vector2i.ZERO
var reset_armed := false
var hover := Vector2i(-1,-1)
var tick := 0.0
var buttons: Array = []
func initial_world():
	var seed_number := randi_range(1,2147483646)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed=") and arg.substr(7).is_valid_int(): seed_number=int(arg.substr(7))
	return World.new(seed_number)
func _ready():
	if ResourceLoader.exists("res://assets/tower.png"): art = load("res://assets/tower.png")
	for id in ["warden","ranger","scholar","mossling","sentinel","stalker","briar","colossus","regent"]:
		var path := "res://assets/combat/%s.png" % id
		if ResourceLoader.exists(path): combat_art[id]=load(path)
	buttons = [Rect2(350,720,120,38),Rect2(482,720,120,38),Rect2(614,720,120,38),Rect2(746,720,143,38),Rect2(938,745,300,35),Rect2(36,710,272,38)]
	queue_redraw()
func _process(delta):
	tick += delta
	battle_time = maxf(0.0, battle_time-delta)
	queue_redraw()
func label_at(p: Vector2, text: String, size:=18, color:=INK):
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func panel(r: Rect2, color: Color):
	draw_style_box(style(color),r)
func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=10; s.corner_radius_top_right=10; s.corner_radius_bottom_left=10; s.corner_radius_bottom_right=10
	return s
func _draw():
	draw_rect(Rect2(0,0,1280,800),Color("080f1b"))
	label_at(Vector2(36,45),"N O C T U R N E   /   G A M E S",14,MUTED)
	label_at(Vector2(350,52),"MAGIC TOWER",32,INK)
	label_at(Vector2(350,83),"SEED %d  /  THE KEY OF THE SKY" % world.seed_value,14,TEAL)
	label_at(Vector2(1040,48),"FLOOR 0%d / 05" % (world.floor_index+1),16,GOLD)
	draw_line(Vector2(36,108),Vector2(1244,108),Color("243342"))
	if art:
		draw_texture_rect(art,Rect2(15,147,300,450),false)
	else:
		for i in range(7):
			panel(Rect2(100+i*4,560-i*49,120-i*8,44),Color(0.1,0.2+i*0.025,0.25+i*0.035))
	label_at(Vector2(36,620),Progression.HEROES[world.hero_id].name.to_upper(),22,INK)
	label_at(Vector2(36,648),"FOCUS %d / %d  |  %s" % [world.focus,world.focus_cap,"SKILL ARMED" if world.skill_armed else ("SKILL READY" if world.focus>0 else "NO FOCUS")],14,TEAL)
	label_at(Vector2(36,674),"Choose your hero with C" if world.moves==0 else "Kills %d  /  Talents %d" % [world.kills,world.talents.size()],16,GOLD)
	if not Progression.talent_options(world.kills,world.talents).is_empty():
		label_at(Vector2(36,698),"NEW TALENT AVAILABLE  [C]",14,GOLD)
	label_at(Vector2(36,775),"R twice: replay  /  N twice: new seed",13,MUTED)
	panel(Rect2(338,130,563,563),Color("121e2c"))
	for y in range(11):
		for x in range(11):
			var p := ORIGIN + Vector2(x,y)*CELL
			var t: String = world.tile(Vector2i(x,y))
			draw_rect(Rect2(p+Vector2(1,1),Vector2(CELL-2,CELL-2)),Color("172535") if (x+y)%2==0 else Color("142130"))
			if t == "#":
				draw_rect(Rect2(p+Vector2(3,3),Vector2(43,43)),Color("283748"))
				draw_line(p+Vector2(5,5),p+Vector2(43,5),Color("3c5061"),2)
			else: draw_token(p+Vector2(24.5,24.5),t)
			if hover == Vector2i(x,y): draw_rect(Rect2(p,Vector2(CELL,CELL)),Color(0.4,0.85,0.76,0.35),false,2)
	var hero := ORIGIN+Vector2(world.pos)*CELL+Vector2(24.5,24.5)
	draw_circle(hero,19+sin(tick*3)*1.5,Color(0.4,0.85,0.76,0.15))
	if combat_art.has(world.hero_id):
		draw_texture_rect(combat_art[world.hero_id],Rect2(hero-Vector2(25,25),Vector2(50,50)),false)
	else:
		draw_colored_polygon(PackedVector2Array([hero+Vector2(0,-17),hero+Vector2(13,13),hero+Vector2(0,9),hero+Vector2(-13,13)]),TEAL)
		draw_circle(hero+Vector2(0,-3),4,INK)
	label_at(Vector2(938,153),["THE ROOTS","THE WARDENS","THE VAULT","THE FORGE","THE CROWN"][world.floor_index],21,GOLD)
	label_at(Vector2(938,179),"FLOOR 0%d" % (world.floor_index+1),13,MUTED)
	var values := [["VITALITY",str(world.hp),Color("ef928f")],["BASE ATTACK",str(world.atk),INK],["BASE DEFENSE",str(world.defense),INK],["GOLD KEYS",str(world.keys),GOLD],["GOLD",str(world.gold),GOLD]]
	for i in values.size():
		panel(Rect2(932,202+i*64,310,54),Color("142130"))
		label_at(Vector2(949,235+i*64),values[i][0],14,MUTED)
		label_at(Vector2(1147,239+i*64),values[i][1],25,values[i][2])
	label_at(Vector2(938,548),"DEBT %d  /  CORE: %s" % [world.debt(), "HELD" if world.core else (world.core_use.to_upper() if world.core_use!="" else "NONE")],13,GOLD)
	var target: String = world.tile(hover)
	if World.ENEMIES.has(target):
		var cost: int = world.damage(target)
		label_at(Vector2(938,589),World.ENEMIES[target].name,20)
		label_at(Vector2(938,619),"Predicted loss: %s" % (str(cost)+" HP" if cost>=0 else "IMPOSSIBLE"),16,GOLD)
		if target=="u": label_at(Vector2(938,637),"AMBUSH: enemy strikes first",12,Color("ef928f"))
		if target=="b": label_at(Vector2(938,637),"THORNS: 2 HP / your attack",12,Color("ef928f"))
	else:
		label_at(Vector2(938,589),token_name(target),18,TEAL)
		label_at(Vector2(938,614),"E: interact / inspect ledger",15,MUTED)
	label_at(Vector2(938,652),quest_hint(),13,GOLD)
	label_at(Vector2(938,674),"Move   WASD / Arrow keys",15)
	label_at(Vector2(938,699),"Click an adjacent tile to move",14,MUTED)
	label_at(Vector2(938,734),"U  undo     L  load     H  guide",14,MUTED)
	label_at(Vector2(350,711),world.message if world.message.length()<=68 else world.message.left(65)+"...",13,TEAL)
	var titles := ["UNDO  U","SAVE  S*","LOAD  L","GUIDE  H","INTERACT / LEDGER  E","HERO / GROWTH  C"]
	for i in buttons.size():
		panel(buttons[i],Color("253748"))
		label_at(buttons[i].position+Vector2(13,25),titles[i],14)
	label_at(Vector2(350,787),"* Click SAVE. S moves down.  |  R twice: restart  |  Autosaves after every move",12,MUTED)
	if battle_time > 0.0: draw_battle()
	if book: draw_book()
	if growth: draw_growth()
	if interaction: draw_interaction()
	if world.won:
		panel(Rect2(380,295,480,230),Color("0c1928"))
		label_at(Vector2(420,350),"THE SKY IS OPEN",30,GOLD)
		label_at(Vector2(420,392),"The final seal has fallen.",20)
		label_at(Vector2(420,426),"%d HP left  /  %d moves  /  %d gold" % [world.hp,world.moves,world.gold],17,TEAL)
		label_at(Vector2(420,475),"Press R twice to begin a new journey.",16,MUTED)
func draw_token(c: Vector2, t: String):
	if ENEMY_ART.has(t) and combat_art.has(ENEMY_ART[t]):
		draw_texture_rect(combat_art[ENEMY_ART[t]],Rect2(c-Vector2(24,24),Vector2(48,48)),false)
		if t in ["u","b"]:
			label_at(c+Vector2(11,-10),"!" if t=="u" else "*",16,GOLD)
		return
	match t:
		"k":
			draw_circle(c+Vector2(-6,0),6,GOLD,false,3); draw_line(c,c+Vector2(13,0),GOLD,3); draw_line(c+Vector2(10,0),c+Vector2(10,6),GOLD,3)
		"D":
			draw_rect(Rect2(c-Vector2(15,19),Vector2(30,38)),Color("725735")); draw_rect(Rect2(c-Vector2(11,15),Vector2(22,30)),GOLD,false,2); draw_circle(c,3,Color("171d27"))
		"a","d":
			var col := Color("f08598") if t=="a" else Color("80b9f4")
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-14),c+Vector2(10,0),c+Vector2(0,14),c+Vector2(-10,0)]),col)
		"h":
			draw_circle(c+Vector2(0,4),11,Color("7ce0bf")); draw_rect(Rect2(c-Vector2(5,13),Vector2(10,14)),Color("b2ead9")); draw_line(c+Vector2(-4,3),c+Vector2(4,3),Color("e5fff5"),2)
		"s","g","u","b","B","V","K":
			var col: Color = {"s":Color("8fc57f"),"g":Color("b5a2e1"),"u":Color("87b9dc"),"b":Color("9dcc83")}.get(t,Color("ed987d"))
			draw_circle(c,15 if t in ["s","g","u","b"] else 19,col)
			draw_circle(c+Vector2(-5,-2),3,Color("132330")); draw_circle(c+Vector2(5,-2),3,Color("132330"))
			if t in ["u","b"]: label_at(c+Vector2(12,-12),"!" if t=="u" else "*",16,GOLD)
			if t in ["B","V","K"]:
				for i in range(3): draw_line(c+Vector2(-10+i*10,-14),c+Vector2(-10+i*10,-22),GOLD,4)
		"M","C","E","F","T","N","Q","J","I","O","R","X":
			var color := GOLD if t in ["M","T","C"] else TEAL
			draw_rect(Rect2(c-Vector2(16,16),Vector2(32,32)),color.darkened(0.65))
			draw_rect(Rect2(c-Vector2(16,16),Vector2(32,32)),color,false,2)
			label_at(c+Vector2(-7,7),t,21,color)
		"~":
			draw_rect(Rect2(c-Vector2(23,23),Vector2(46,46)),Color("123e62"))
			for i in range(3):
				var shift := sin(tick*2+i)*3
				draw_line(c+Vector2(-17+shift,-12+i*11),c+Vector2(17+shift,-12+i*11),Color("6ac9de"),2)
		"<",">":
			for i in range(4): draw_line(c+Vector2(-15,12-i*7),c+Vector2(15-i*6,12-i*7),TEAL,3)
			label_at(c+Vector2(8,-8),"+" if t==">" else "-",16,TEAL)
func draw_book():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(235,105,810,610),Color("0c1928"))
	label_at(Vector2(265,145),"THE TRAVELER'S FIELD GUIDE",24,GOLD)
	var kinds: Array=[]
	for kind in World.ENEMIES:
		if kind!="B": kinds.append(kind)
	for i in kinds.size():
		var kind: String=kinds[i]
		var e: Dictionary=World.ENEMIES[kind]
		var p := Vector2(275+(i%2)*380,195+floori(i/2.0)*92)
		draw_token(p+Vector2(15,10),kind)
		label_at(p+Vector2(48,0),e.name,18,GOLD)
		label_at(p+Vector2(48,24),"HP %d / ATK %d / DEF %d" % [e.hp,e.atk,e.def],14,INK)
		var mechanic_text: String="Normal retaliation after your attacks."
		if kind=="u": mechanic_text="Strikes first, even if you one-shot it."
		if kind=="b": mechanic_text="2 thorns / your hit, including final hit."
		label_at(p+Vector2(48,47),mechanic_text,12,TEAL)
	var lines := ["Exact forecasts include ambush, thorns, gear, skills and talents.","Thorns ignores DEF. Brace and total-loss reduction still apply.","C: hero / gear / talents. E: local choices, quests and ledger.","J: researcher / I: sample / O: valve / R: relic / X: encounter.","Interest: first entry to floors 4 and 5 only, never steps or waiting.","Grow stronger and revisit. U reverses the entire previous action.","H / Esc / click closes. Battles are cosmetic replays; any key skips."]
	for i in lines.size(): label_at(Vector2(265,505+i*27),lines[i],15,MUTED)
func token_name(t: String) -> String:
	if t=="~" and world.water_choice=="drain": return "Drained passage to the relic vault"
	if t=="X": return world.event_title()
	return {"M":"Merchant: trade & loans","C":"One core. Three choices.","E":"The old elevator","F":"Workshop: a lasting choice","T":"A treasure worth returning for","N":"An inscription. Read carefully.","Q":"A door with a secret","<":"Return to a lower floor",">":"Ascend: check your ledger","a":"Ruby: +5 attack","d":"Sapphire: +4 defense","h":"Spring water: +100 HP","k":"Gold key","D":"A locked shortcut","J":"A traveler with a request","I":"An unusual research sample","O":"Drain the route or keep the spring?","~":"Deep water blocks this route","R":"A choice of equipment","X":"A costly opportunity"}.get(t,"SCOUT BEFORE YOU STRIKE")
func nearby(t: String) -> bool:
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if world.tile(world.pos+d)==t: return true
	return false
func available_actions() -> Array:
	var rows: Array = []
	if checkpoint_pending!=Vector2i.ZERO:
		rows.append(["continue","Continue upstairs: settle interest now"])
		rows.append(["cancel","Stay on this floor: no interest charged"])
	if world.debt()>0: rows.append(["repay","Repay using available gold (fees, interest, principal)"])
	if nearby("M"):
		rows.append(["buy","Buy armor-breaker: 60 gold / +12 ATK (once)"])
		rows.append(["borrow","Borrow 40 gold: 2 fee / 10% per new milestone"])
		rows.append(["sell_core","Sell core: +35 gold / lose its other uses"])
	if nearby("E"):
		rows.append(["elevator","Use core: repair elevator / excludes forge & sale"])
		rows.append(["travel","Ride repaired elevator: floors 1 <-> 3"])
	if nearby("F"): rows.append(["forge","Use core: permanent +8 DEF / excludes lift & sale"])
	if nearby("Q"): rows.append(["secret","Inspect the mechanism using the inscription's clue"])
	if nearby("J"):
		if world.quest_state==0: rows.append(["quest_accept","Accept: retrieve the sample and return here"])
		if world.quest_state==2:
			rows.append(["quest_gold","Turn in sample: +45 gold / give up focus training"])
			rows.append(["quest_scroll","Turn in sample: focus cap 4 + full refill / give up gold"])
	if nearby("O") and world.water_choice=="":
		rows.append(["drain","Drain the water: open a route / give up the spring"])
		rows.append(["spring","Keep the spring: +120 HP / relic route stays flooded"])
	if nearby("R") and not world.chest_claimed:
		rows.append(["relic_buckler","Choose heavy buckler: +6 DEF / -4 ATK"])
		rows.append(["relic_duelist","Choose duelist rig: +6 ATK / -3 DEF"])
	if nearby("X") and not world.event_done:
		rows.append_array(world.event_offers())
	return rows
func visible_actions() -> Array:
	var rows := available_actions()
	interaction_page=clampi(interaction_page,0,maxi(0,ceili(rows.size()/6.0)-1))
	return rows.slice(interaction_page*6,interaction_page*6+6)
func draw_interaction():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	label_at(Vector2(290,158),world.event_title().to_upper() if nearby("X") and not world.event_done else "CHOICES & THE LEDGER",25,GOLD)
	label_at(Vector2(290,190),"Gold %d   |   Debt %d   |   Core: %s" % [world.gold,world.debt(),"held" if world.core else (world.core_use if world.core_use!="" else "none")],18,TEAL)
	label_at(Vector2(290,218),"Principal %d  +  fees %d  +  interest %d" % [world.principal,world.fees,world.interest],16)
	var terms := ["Borrow once, before floor 4. Receive 40; owe 42. Max total 50.","First entry to floors 4 and 5: ceil(remaining principal x 10%).", "No compound interest. Walking, waiting & backtracking cost nothing.", "After maturity: debt freezes; future gold repays it. No new loans.", "Repay early to reduce interest. No real money. Debt ends with this run."]
	for i in terms.size(): label_at(Vector2(290,248+i*23),terms[i],15,MUTED)
	if checkpoint_pending!=Vector2i.ZERO:
		label_at(Vector2(290,369),"ASCENDING NOW: +%d interest. Choose below." % ceili(world.principal*0.1),16,GOLD)
	action_rows=visible_actions()
	if action_rows.is_empty():
		label_at(Vector2(290,405),"Stand beside a marked object or NPC to interact.",18,TEAL)
	for i in action_rows.size():
		var r := Rect2(285,375+i*43,720,37)
		panel(r,Color("253748"))
		label_at(r.position+Vector2(12,24),"%d  %s" % [i+1,action_rows[i][1]],16)
	label_at(Vector2(290,640),world.message.left(100),14,TEAL)
	if available_actions().size()>6:
		label_at(Vector2(815,218),"Page %d   [ / ]" % (interaction_page+1),13,GOLD)
	label_at(Vector2(290,672),"Click a choice or press its number. E / Esc closes without choosing.",14,MUTED)
func perform_action(id: String):
	if id=="cancel":
		checkpoint_pending=Vector2i.ZERO; interaction=false; return
	if id=="continue":
		var direction := checkpoint_pending
		checkpoint_pending=Vector2i.ZERO; interaction=false
		move(direction,true)
		return
	reset_armed=false
	var before: Dictionary=world.save_data().duplicate(true)
	if world.action(id):
		if id.begins_with("hero_") or id.begins_with("talent_"): growth=false
		history.append(before)
		if history.size()>100: history.pop_front()
		save_game(false)
	else:
		world.message={"borrow":"Loan unavailable: once per run, before floor 4.","buy":"Need 60 gold; this weapon can only be purchased once.","repay":"No gold available or no outstanding debt.","elevator":"A held core is required. Its other uses will be lost.","forge":"A held core is required. Its other uses will be lost.","sell_core":"No core held. A used or sold core cannot be reclaimed.","travel":"Repair this elevator with the core first.","secret":"The bell is silent. Find the inscription and restore its mechanism."}.get(id,"This choice is unavailable. Check its cost and requirements.")
func quest_hint() -> String:
	return ["J: find the researcher's request","QUEST: seek the sample (I)","QUEST: return sample to J","QUEST COMPLETE"][clampi(world.quest_state,0,3)]
func skill_description() -> String:
	if "trained_focus" in world.talents:
		return {"warden":"Spend 1 focus: reduce next battle total loss by 40.","ranger":"Spend 1 focus: ignore 14 enemy DEF for next battle.","scholar":"Spend 1 focus outside battle: recover 100 HP."}[world.hero_id]
	return Progression.HEROES[world.hero_id].description
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
func open_growth():
	growth=not growth; interaction=false; book=false; checkpoint_pending=Vector2i.ZERO
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
	var rows := growth_actions()
	for i in rows.size():
		var r := Rect2(225,270+i*87,830,76)
		panel(r,Color("203343"))
		label_at(r.position+Vector2(15,27),"%d  %s" % [i+1,rows[i][1]],19,GOLD)
		label_at(r.position+Vector2(15,56),rows[i][2],15,INK)
		if growth_tab==0:
			var portrait: String=rows[i][0].trim_prefix("hero_") if rows[i][0].begins_with("hero_") else world.hero_id
			if combat_art.has(portrait): draw_texture_rect(combat_art[portrait],Rect2(r.position+Vector2(750,3),Vector2(70,70)),false)
	if growth_tab==2:
		var learned: Array=[]
		for id in world.talents: learned.append(Progression.TALENTS[id].name)
		label_at(Vector2(225,565),"Learned: "+(", ".join(learned) if not learned.is_empty() else "none yet"),15,TEAL)
		if rows.is_empty(): label_at(Vector2(225,300),"No new choice yet. Defeat foes and return.",18,INK)
	label_at(Vector2(225,610),"Focus is finite. First visits restore it; repeating floors cannot farm it.",15,MUTED)
	label_at(Vector2(225,646),world.message.left(105),14,TEAL)
	label_at(Vector2(225,697),"Choose 1-3. Tab changes section. Esc: keep default Warden." if world.moves==0 else "Click a card / press 1-3. Tab changes section. C / Esc closes.",15,MUTED)
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
	var is_ambush := battle_kind=="u"
	var phase_text := "Readying the strike"
	if phase>=0.15 and phase<0.30 and is_ambush:
		phase_text="AMBUSH: enemy strikes first"
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
		phase_text="Thorns reflect damage" if battle_kind=="b" else "Retaliation resolved"
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
	label_at(Vector2(320,463),"%d rounds  /  %d damage per hit  /  %d HP lost" % [int(battle_details.get("rounds",0)),int(battle_details.get("hit",0)),battle_loss],19)
	label_at(Vector2(320,494),"Before mitigation: retaliation %d + ambush %d + thorns %d" % [int(battle_details.get("normal_damage",0)),int(battle_details.get("first_strike_damage",0)),int(battle_details.get("thorns_damage",0))],15,MUTED)
	label_at(Vector2(320,521),"Blocked %d  /  Recovery +%d HP  /  %s" % [int(battle_details.get("blocked_damage",0)),int(battle_details.get("heal_after",0)),"skill used" if battle_skill else "no active skill"],16,TEAL)
	label_at(Vector2(320,565),"All rounds are already resolved once. Animation never changes damage.",14,MUTED)
	label_at(Vector2(320,603),"Press any key / click to skip.",15,GOLD)
func draw_ellipse_shadow(center: Vector2):
	draw_set_transform(center+Vector2(0,57),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,49,Color(0,0,0,0.35))
	draw_set_transform(Vector2.ZERO)
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		hover = Vector2i((get_global_mouse_position()-ORIGIN)/CELL)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if battle_time>0.0: battle_time=0.0; return
		if book: book=false; return
		if growth:
			for i in 3:
				if Rect2(225+i*270,175,250,40).has_point(get_global_mouse_position()): growth_tab=i; return
			var choices := growth_actions()
			for i in choices.size():
				if Rect2(225,270+i*87,830,76).has_point(get_global_mouse_position()): perform_action(choices[i][0]); return
			if not Rect2(195,80,890,650).has_point(get_global_mouse_position()): growth=false
			return
		if interaction:
			var rows := visible_actions()
			for i in rows.size():
				if Rect2(285,375+i*43,720,37).has_point(get_global_mouse_position()): perform_action(rows[i][0]); return
			if not Rect2(260,120,770,570).has_point(get_global_mouse_position()): interaction=false; checkpoint_pending=Vector2i.ZERO
			return
		for i in buttons.size():
			if buttons[i].has_point(get_global_mouse_position()):
				match i:
					0: undo()
					1: save_game()
					2: load_game()
					3: book=true
					4: interaction=true; interaction_page=0
					5: open_growth()
				return
		var diff: Vector2i = hover-world.pos
		if absi(diff.x)+absi(diff.y)==1: move(diff)
	if event is InputEventKey and event.pressed and not event.echo:
		if battle_time>0.0: battle_time=0.0; return
		if event.keycode==KEY_C: open_growth(); return
		if event.keycode==KEY_H: book=not book; growth=false; interaction=false; checkpoint_pending=Vector2i.ZERO; return
		if event.keycode==KEY_E: interaction=not interaction; interaction_page=0; growth=false; book=false; checkpoint_pending=Vector2i.ZERO; return
		if event.keycode==KEY_ESCAPE: book=false; growth=false; interaction=false; checkpoint_pending=Vector2i.ZERO; return
		if growth:
			if event.keycode==KEY_TAB: growth_tab=(growth_tab+1)%3; return
			var index: int=event.keycode-KEY_1
			var choices := growth_actions()
			if index>=0 and index<choices.size(): perform_action(choices[index][0])
			return
		if interaction:
			if event.keycode==KEY_BRACKETLEFT: interaction_page=maxi(0,interaction_page-1); return
			if event.keycode==KEY_BRACKETRIGHT: interaction_page+=1; return
			var index: int = event.keycode-KEY_1
			var rows := visible_actions()
			if index>=0 and index<rows.size(): perform_action(rows[index][0])
			return
		if book: return
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
	if reset_armed and reset_mode==mode:
		world=World.new(world.seed_value if mode=="replay" else randi_range(1,2147483646))
		history.clear(); reset_armed=false; battle_time=0.0; growth=true; growth_tab=0; interaction=false; checkpoint_pending=Vector2i.ZERO
		save_game(false)
	else:
		reset_armed=true; reset_mode=mode
		world.message="Press %s again: %s. Autosave will be replaced." % ["R" if mode=="replay" else "N","replay this seed" if mode=="replay" else "start a new seed"]
func move(direction: Vector2i, confirmed:=false):
	reset_armed=false
	if not confirmed and world.tile(world.pos+direction)==">" and world.floor_index>=2 and world.checkpoints<world.floor_index-1 and world.debt()>0:
		checkpoint_pending=direction
		interaction_page=0
		interaction=true
		world.message="A new milestone settles interest. Repay first, continue, or cancel."
		return
	var before: Dictionary = world.save_data().duplicate(true)
	var enemy: String = world.tile(world.pos+direction)
	var preview: Dictionary = world.battle_preview(enemy) if World.ENEMIES.has(enemy) else {}
	var used_skill: bool = preview.get("skill_consumed",false)
	var hero_before: String = world.hero_id
	if world.step(direction):
		if World.ENEMIES.has(enemy):
			battle_time=2.4; battle_name=World.ENEMIES[enemy].name; battle_loss=int(preview.get("damage",0))
			battle_details=preview; battle_kind=enemy; battle_hero=hero_before; battle_skill=used_skill
		history.append(before)
		if history.size()>100: history.pop_front()
		save_game(false)
func undo():
	if history.is_empty(): world.message="No move to undo in this session."; return
	world.restore(history.pop_back())
	battle_time=0.0
	world.message="One step back. A different possibility."
	save_game(false)
func save_game(announce:=true):
	var f := FileAccess.open(save_path,FileAccess.WRITE)
	if f == null: world.message="Could not save. Check storage permissions."; return
	f.store_string(JSON.stringify(world.save_data()))
	if announce: world.message="Journey saved locally."
func load_game():
	if not FileAccess.file_exists(save_path): world.message="No saved journey yet."; return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or not world.restore(parsed): world.message="Save is invalid. Current journey is unchanged."; return
	history.clear()
	battle_time=0.0
