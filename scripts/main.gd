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
var save_path := "user://journey.json"
var book := false
var reset_armed := false
var hover := Vector2i(-1,-1)
var tick := 0.0
var buttons: Array = []
func _ready():
	if ResourceLoader.exists("res://assets/tower.png"): art = load("res://assets/tower.png")
	buttons = [Rect2(350,720,120,38),Rect2(482,720,120,38),Rect2(614,720,120,38),Rect2(746,720,143,38)]
	queue_redraw()
func _process(delta):
	tick += delta
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
	label_at(Vector2(1040,48),"CHAPTER 0%d / 03" % (world.floor_index+1),16,GOLD)
	draw_line(Vector2(36,108),Vector2(1244,108),Color("243342"))
	if art:
		draw_texture_rect(art,Rect2(15,147,300,450),false)
	else:
		for i in range(7):
			panel(Rect2(100+i*4,560-i*49,120-i*8,44),Color(0.1,0.2+i*0.025,0.25+i*0.035))
	label_at(Vector2(36,630),"A tower without time.",20,INK)
	label_at(Vector2(36,659),"Three floors. One last seal.",16,MUTED)
	label_at(Vector2(36,701),"No luck. Only your choices.",15,TEAL)
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
	label_at(Vector2(938,153),["THE ROOTS","THE WARDENS","THE CROWN"][world.floor_index],21,GOLD)
	label_at(Vector2(938,179),"FLOOR 0%d" % (world.floor_index+1),13,MUTED)
	var values := [["VITALITY",str(world.hp),Color("ef928f")],["ATTACK",str(world.atk),INK],["DEFENSE",str(world.defense),INK],["GOLD KEYS",str(world.keys),GOLD],["TREASURE",str(world.gold),GOLD]]
	for i in values.size():
		panel(Rect2(932,202+i*64,310,54),Color("142130"))
		label_at(Vector2(949,235+i*64),values[i][0],14,MUTED)
		label_at(Vector2(1147,239+i*64),values[i][1],25,values[i][2])
	label_at(Vector2(938,558),"SCOUT BEFORE YOU STRIKE",13,TEAL)
	var target: String = world.tile(hover)
	if World.ENEMIES.has(target):
		var cost: int = world.damage(target)
		label_at(Vector2(938,589),World.ENEMIES[target].name,20)
		label_at(Vector2(938,619),"Predicted loss: %s" % (str(cost)+" HP" if cost>=0 else "IMPOSSIBLE"),16,GOLD)
	else:
		label_at(Vector2(938,589),"Hover an enemy to see",16,MUTED)
		label_at(Vector2(938,614),"the exact battle cost.",16,MUTED)
	label_at(Vector2(938,674),"Move   WASD / Arrow keys",15)
	label_at(Vector2(938,699),"Click an adjacent tile to move",14,MUTED)
	label_at(Vector2(938,734),"U  undo     L  load     H  guide",14,MUTED)
	label_at(Vector2(350,711),world.message,14,TEAL)
	var titles := ["UNDO  U","SAVE  S*","LOAD  L","GUIDE  H"]
	for i in buttons.size():
		panel(buttons[i],Color("253748"))
		label_at(buttons[i].position+Vector2(13,25),titles[i],14)
	label_at(Vector2(350,787),"* Click SAVE. S moves down.  |  R twice: restart  |  Autosaves after every move",12,MUTED)
	if book: draw_book()
	if world.won:
		panel(Rect2(380,295,480,230),Color("0c1928"))
		label_at(Vector2(420,350),"THE SKY IS OPEN",30,GOLD)
		label_at(Vector2(420,392),"The Hollow King has fallen.",20)
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
		"s","g","B":
			var col := Color("8fc57f") if t=="s" else (Color("b5a2e1") if t=="g" else Color("ed987d"))
			draw_circle(c,15 if t!="B" else 19,col)
			draw_circle(c+Vector2(-5,-2),3,Color("132330")); draw_circle(c+Vector2(5,-2),3,Color("132330"))
			if t=="B":
				for i in range(3): draw_line(c+Vector2(-10+i*10,-14),c+Vector2(-10+i*10,-22),GOLD,4)
		"<",">":
			for i in range(4): draw_line(c+Vector2(-15,12-i*7),c+Vector2(15-i*6,12-i*7),TEAL,3)
			label_at(c+Vector2(8,-8),"+" if t==">" else "-",16,TEAL)
func draw_book():
	panel(Rect2(350,150,540,535),Color("0c1928"))
	label_at(Vector2(380,193),"THE TRAVELER'S FIELD GUIDE",22,GOLD)
	var y := 238
	for kind in ["s","g","B"]:
		var e: Dictionary = World.ENEMIES[kind]
		draw_token(Vector2(400,y+10),kind)
		label_at(Vector2(435,y),e.name,19)
		label_at(Vector2(435,y+27),"HP %d   ATK %d   DEF %d" % [e.hp,e.atk,e.def],16,MUTED)
		y += 80
	for line in ["You strike first. Damage is deterministic.","Lethal fights are blocked; upgrade and return.","Ruby +5 ATK / Sapphire +4 DEF / Potion +100 HP","Gold is your score. Keys open gold doors.","Stairs allow backtracking. Undo restores a move.","Click or press H to close this guide."]:
		label_at(Vector2(380,y),line,15,TEAL if y>620 else MUTED); y+=29
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		hover = Vector2i((get_global_mouse_position()-ORIGIN)/CELL)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if book: book=false; return
		for i in buttons.size():
			if buttons[i].has_point(get_global_mouse_position()):
				match i:
					0: undo()
					1: save_game()
					2: load_game()
					3: book=true
				return
		var diff: Vector2i = hover-world.pos
		if absi(diff.x)+absi(diff.y)==1: move(diff)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_H: book=not book; return
		if event.keycode==KEY_ESCAPE: book=false; return
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
					world=World.new(); history.clear(); reset_armed=false; save_game(false)
				else: reset_armed=true; world.message="Press R again to restart. Your autosave will be replaced."
func move(direction: Vector2i):
	reset_armed=false
	var before: Dictionary = world.save_data().duplicate(true)
	if world.step(direction):
		history.append(before)
		if history.size()>100: history.pop_front()
		save_game(false)
func undo():
	if history.is_empty(): world.message="No move to undo in this session."; return
	world.restore(history.pop_back())
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
