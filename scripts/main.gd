extends Node2D

const World = preload("res://scripts/world.gd")
const CELL := 49.0
const ORIGIN := Vector2(350,142)
const INK := Color("e5ebee")
const MUTED := Color("7e96a4")
const GOLD := Color("e9bd6d")
const TEAL := Color("65dac4")
var world = World.new()
var font = ThemeDB.fallback_font
var art: Texture2D
var history: Array = []
var save_path := "user://journey-v2.json"
var book := false
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
func _ready():
	if ResourceLoader.exists("res://assets/tower.png"): art = load("res://assets/tower.png")
	buttons = [Rect2(350,720,120,38),Rect2(482,720,120,38),Rect2(614,720,120,38),Rect2(746,720,143,38),Rect2(938,745,300,35)]
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
	label_at(Vector2(350,83),"THE KEY OF THE SKY",14,TEAL)
	label_at(Vector2(1040,48),"FLOOR 0%d / 05" % (world.floor_index+1),16,GOLD)
	draw_line(Vector2(36,108),Vector2(1244,108),Color("243342"))
	if art:
		draw_texture_rect(art,Rect2(15,147,300,450),false)
	else:
		for i in range(7):
			panel(Rect2(100+i*4,560-i*49,120-i*8,44),Color(0.1,0.2+i*0.025,0.25+i*0.035))
	label_at(Vector2(36,630),"A tower without time.",20,INK)
	label_at(Vector2(36,659),"Five floors. Choices that echo.",16,MUTED)
	label_at(Vector2(36,701),"Borrow. Explore. Return stronger.",15,TEAL)
	label_at(Vector2(36,747),"BLENDER  +  GODOT",13,MUTED)
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
	draw_colored_polygon(PackedVector2Array([hero+Vector2(0,-17),hero+Vector2(13,13),hero+Vector2(0,9),hero+Vector2(-13,13)]),TEAL)
	draw_circle(hero+Vector2(0,-3),4,INK)
	label_at(Vector2(938,153),["THE ROOTS","THE WARDENS","THE VAULT","THE FORGE","THE CROWN"][world.floor_index],21,GOLD)
	label_at(Vector2(938,179),"FLOOR 0%d" % (world.floor_index+1),13,MUTED)
	var values := [["VITALITY",str(world.hp),Color("ef928f")],["ATTACK",str(world.atk),INK],["DEFENSE",str(world.defense),INK],["GOLD KEYS",str(world.keys),GOLD],["GOLD",str(world.gold),GOLD]]
	for i in values.size():
		panel(Rect2(932,202+i*64,310,54),Color("142130"))
		label_at(Vector2(949,235+i*64),values[i][0],14,MUTED)
		label_at(Vector2(1147,239+i*64),values[i][1],25,values[i][2])
	label_at(Vector2(938,548),"DEBT %d  /  CORE: %s" % [world.debt(), "HELD" if world.core else world.core_use.to_upper()],13,GOLD)
	var target: String = world.tile(hover)
	if World.ENEMIES.has(target):
		var cost: int = world.damage(target)
		label_at(Vector2(938,589),World.ENEMIES[target].name,20)
		label_at(Vector2(938,619),"Predicted loss: %s" % (str(cost)+" HP" if cost>=0 else "IMPOSSIBLE"),16,GOLD)
	else:
		label_at(Vector2(938,589),token_name(target),18,TEAL)
		label_at(Vector2(938,614),"E: interact / inspect ledger",15,MUTED)
	label_at(Vector2(938,674),"Move   WASD / Arrow keys",15)
	label_at(Vector2(938,699),"Click an adjacent tile to move",14,MUTED)
	label_at(Vector2(938,734),"U  undo     L  load     H  guide",14,MUTED)
	label_at(Vector2(350,711),world.message if world.message.length()<=68 else world.message.left(65)+"...",13,TEAL)
	var titles := ["UNDO  U","SAVE  S*","LOAD  L","GUIDE  H","INTERACT / LEDGER  E"]
	for i in buttons.size():
		panel(buttons[i],Color("253748"))
		label_at(buttons[i].position+Vector2(13,25),titles[i],14)
	label_at(Vector2(350,787),"* Click SAVE. S moves down.  |  R twice: restart  |  Autosaves after every move",12,MUTED)
	if battle_time > 0.0: draw_battle()
	if book: draw_book()
	if interaction: draw_interaction()
	if world.won:
		panel(Rect2(380,295,480,230),Color("0c1928"))
		label_at(Vector2(420,350),"THE SKY IS OPEN",30,GOLD)
		label_at(Vector2(420,392),"The final seal has fallen.",20)
		label_at(Vector2(420,426),"%d HP left  /  %d moves  /  %d gold" % [world.hp,world.moves,world.gold],17,TEAL)
		label_at(Vector2(420,475),"Press R twice to begin a new journey.",16,MUTED)
func draw_token(c: Vector2, t: String):
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
		"s","g","B","V","K":
			var col := Color("8fc57f") if t=="s" else (Color("b5a2e1") if t=="g" else Color("ed987d"))
			draw_circle(c,15 if t in ["s","g"] else 19,col)
			draw_circle(c+Vector2(-5,-2),3,Color("132330")); draw_circle(c+Vector2(5,-2),3,Color("132330"))
			if t in ["B","V","K"]:
				for i in range(3): draw_line(c+Vector2(-10+i*10,-14),c+Vector2(-10+i*10,-22),GOLD,4)
		"M","C","E","F","T","N","Q":
			var color := GOLD if t in ["M","T","C"] else TEAL
			draw_rect(Rect2(c-Vector2(16,16),Vector2(32,32)),color.darkened(0.65))
			draw_rect(Rect2(c-Vector2(16,16),Vector2(32,32)),color,false,2)
			label_at(c+Vector2(-7,7),t,21,color)
		"<",">":
			for i in range(4): draw_line(c+Vector2(-15,12-i*7),c+Vector2(15-i*6,12-i*7),TEAL,3)
			label_at(c+Vector2(8,-8),"+" if t==">" else "-",16,TEAL)
func draw_book():
	panel(Rect2(320,135,610,560),Color("0c1928"))
	label_at(Vector2(350,175),"THE TRAVELER'S FIELD GUIDE",22,GOLD)
	var y := 210
	for kind in World.ENEMIES:
		if kind=="B": continue
		var e: Dictionary = World.ENEMIES[kind]
		draw_token(Vector2(370,y+3),kind)
		label_at(Vector2(405,y+7),"%s  HP %d / ATK %d / DEF %d" % [e.name,e.hp,e.atk,e.def],15)
		y += 40
	for line in ["You strike first. Hover enemies for exact HP loss.","Lethal fights are blocked. Grow stronger, then revisit.","M Merchant / C Core / E Elevator / F Workshop", "N Inscription / Q Secret / T Guarded treasure", "A core has three uses. Choosing one excludes the others.","E opens actions nearby. Borrowing is optional, not free.","Interest follows new chapter milestones, never your steps.","U undoes purchases AND debt. H / Esc / click closes."]:
		label_at(Vector2(350,y+10),line,15,MUTED); y+=25
func token_name(t: String) -> String:
	return {"M":"Merchant: trade & loans","C":"One core. Three choices.","E":"The old elevator","F":"Workshop: a lasting choice","T":"A treasure worth returning for","N":"An inscription. Read carefully.","Q":"A door with a secret","<":"Return to a lower floor",">":"Ascend: check your ledger","a":"Ruby: +5 attack","d":"Sapphire: +4 defense","h":"Spring water: +100 HP","k":"Gold key","D":"A locked shortcut"}.get(t,"SCOUT BEFORE YOU STRIKE")
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
	return rows
func draw_interaction():
	draw_rect(Rect2(0,0,1280,800),Color(0,0,0,0.65))
	panel(Rect2(260,120,770,570),Color("0c1928"))
	label_at(Vector2(290,158),"CHOICES & THE LEDGER",25,GOLD)
	label_at(Vector2(290,190),"Gold %d   |   Debt %d   |   Core: %s" % [world.gold,world.debt(),"held" if world.core else world.core_use],18,TEAL)
	label_at(Vector2(290,218),"Principal %d  +  fees %d  +  interest %d" % [world.principal,world.fees,world.interest],16)
	var terms := ["Borrow once, before floor 4. Receive 40; owe 42. Max total 50.","First entry to floors 4 and 5: ceil(remaining principal x 10%).", "No compound interest. Walking, waiting & backtracking cost nothing.", "After maturity: debt freezes; future gold repays it. No new loans.", "Repay early to reduce interest. No real money. Debt ends with this run."]
	for i in terms.size(): label_at(Vector2(290,248+i*23),terms[i],15,MUTED)
	if checkpoint_pending!=Vector2i.ZERO:
		label_at(Vector2(290,369),"ASCENDING NOW: +%d interest. Choose below." % ceili(world.principal*0.1),16,GOLD)
	action_rows=available_actions()
	if action_rows.is_empty():
		label_at(Vector2(290,405),"Stand next to M, E, F or Q to make a choice.",18,TEAL)
	for i in action_rows.size():
		var r := Rect2(285,375+i*43,720,37)
		panel(r,Color("253748"))
		label_at(r.position+Vector2(12,24),"%d  %s" % [i+1,action_rows[i][1]],16)
	label_at(Vector2(290,640),world.message.left(100),14,TEAL)
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
		history.append(before)
		if history.size()>100: history.pop_front()
		save_game(false)
	else:
		world.message={"borrow":"Loan unavailable: once per run, before floor 4.","buy":"Need 60 gold; this weapon can only be purchased once.","repay":"No gold available or no outstanding debt.","elevator":"A held core is required. Its other uses will be lost.","forge":"A held core is required. Its other uses will be lost.","sell_core":"No core held. A used or sold core cannot be reclaimed.","travel":"Repair this elevator with the core first.","secret":"The bell is silent. Find the inscription and restore its mechanism."}.get(id,"This choice is unavailable.")
func draw_battle():
	var p := ORIGIN+Vector2(world.pos)*CELL+Vector2(CELL/2,CELL/2)
	var f := battle_time/0.65
	draw_circle(p,24+(1-f)*30,Color(1,0.72,0.38,f*0.45),false,3)
	draw_line(p+Vector2(-22,-22),p+Vector2(22,22),Color(1,0.9,0.7,f),5)
	panel(Rect2(360,118,520,37),Color("3d2430"))
	label_at(Vector2(374,143),"%s defeated  /  -%d HP" % [battle_name,battle_loss],17,GOLD)
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		hover = Vector2i((get_global_mouse_position()-ORIGIN)/CELL)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if book: book=false; return
		if interaction:
			var rows := available_actions()
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
					4: interaction=true
				return
		var diff: Vector2i = hover-world.pos
		if absi(diff.x)+absi(diff.y)==1: move(diff)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_H: book=not book; interaction=false; checkpoint_pending=Vector2i.ZERO; return
		if event.keycode==KEY_E: interaction=not interaction; book=false; checkpoint_pending=Vector2i.ZERO; return
		if event.keycode==KEY_ESCAPE: book=false; interaction=false; checkpoint_pending=Vector2i.ZERO; return
		if interaction:
			var index: int = event.keycode-KEY_1
			var rows := available_actions()
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
			KEY_R:
				if reset_armed:
					world=World.new(); history.clear(); reset_armed=false; battle_time=0.0; save_game(false)
				else: reset_armed=true; world.message="Press R again to restart. Your autosave will be replaced."
func move(direction: Vector2i, confirmed:=false):
	reset_armed=false
	if not confirmed and world.tile(world.pos+direction)==">" and world.floor_index>=2 and world.checkpoints<world.floor_index-1 and world.debt()>0:
		checkpoint_pending=direction
		interaction=true
		world.message="A new milestone settles interest. Repay first, continue, or cancel."
		return
	var before: Dictionary = world.save_data().duplicate(true)
	var enemy: String = world.tile(world.pos+direction)
	var old_hp: int = world.hp
	if world.step(direction):
		if World.ENEMIES.has(enemy):
			battle_time=0.65; battle_name=World.ENEMIES[enemy].name; battle_loss=old_hp-world.hp
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
