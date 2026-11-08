extends SceneTree
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
const Fixture=preload("res://tests/ui_fixture.gd")
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize():
	call_deferred("run_tests")
func run_tests():
	var scene=load("res://main.tscn").instantiate()
	Fixture.attach(scene)
	root.add_child(scene)
	scene.world=World.new(0,1)
	await Fixture.bind(scene,scene.world)
	scene.growth=true
	await process_frame
	check(DisplayServer.get_name()=="headless","audio regression explicitly runs without a display or sound device")
	check(scene.sound_bank.size()==6 and scene.sound_player!=null,"six original audio resources load without hardware playback")
	for sound_id in ["move","pickup","door","impact","victory","water"]:
		check(scene.sound_bank.has(sound_id) and scene.sound_bank[sound_id] is AudioStreamWAV and ResourceLoader.exists("res://assets/audio/%s.wav" % sound_id),"packaged audio exists and loads as WAV: "+sound_id)
	await scene.save_game(false)
	var before: Dictionary=scene.world.save_data().duplicate(true)
	var file_before: Dictionary=Fixture.snapshot(scene)
	var event:=InputEventKey.new()
	event.pressed=true; event.keycode=KEY_M
	var muted_before: bool=scene.muted
	scene._unhandled_input(event)
	check(scene.muted!=muted_before and scene.growth,"M toggles sound even with hero selection open")
	check(scene.world.save_data()==before and Fixture.snapshot(scene)==file_before and scene.sound_event_count==0,"M changes neither game state, save file nor committed sound count")
	scene.muted=true; scene.growth=false
	await scene.move(Vector2i.RIGHT)
	check(scene.sound_event_count==1 and scene.last_sound_event=="move","successful empty-tile step emits one move event")
	check(not scene.sound_player.playing,"muted movement records event without playback")
	await scene.move(Vector2i.RIGHT)
	check(scene.sound_event_count==2 and scene.last_sound_event=="pickup" and scene.world.keys==1,"key pickup emits exactly one pickup event")
	var count_before: int=scene.sound_event_count
	await scene.move(Vector2i.UP)
	check(scene.sound_event_count==count_before,"blocked wall produces no sound event")
	var hover_event:=InputEventMouseMotion.new()
	scene._unhandled_input(hover_event)
	for i in range(4): scene.world.battle_preview("g")
	check(scene.sound_event_count==count_before,"hover and repeated battle preview stay silent")
	await scene.undo(); await scene.load_game()
	check(scene.sound_event_count==count_before,"undo and load do not replay committed audio")
	# A key-spend prompt must not sound like a door opening before confirmation.
	scene.world.pos=Vector2i(5,3); scene.world.keys=1
	await Fixture.sync(scene)
	await scene.move(Vector2i.RIGHT)
	check(scene.interaction and scene.sound_event_count==count_before,"door preview stays silent")
	await scene.perform_action("cancel")
	check(scene.sound_event_count==count_before,"cancelling key expenditure stays silent")
	await scene.move(Vector2i.RIGHT); await scene.perform_action("continue")
	check(scene.sound_event_count==count_before+1 and scene.last_sound_event=="door","confirmed gate emits exactly one door event")
	count_before=scene.sound_event_count
	await scene.undo()
	check(scene.sound_event_count==count_before,"undoing door does not replay its sound")
	# Combat resolution emits once; skipping presentation cannot emit again.
	scene.world=World.new(0,1); scene.history.clear(); scene.world.pos=Vector2i(5,3)
	await Fixture.bind(scene,scene.world)
	scene.muted=false
	await scene.move(Vector2i.LEFT)
	check(scene.sound_event_count==count_before+1 and scene.last_sound_event=="impact","resolved battle emits one impact")
	check(not scene.sound_player.playing,"headless run never starts hardware playback even when unmuted")
	count_before=scene.sound_event_count
	event.keycode=KEY_SPACE; scene._unhandled_input(event)
	check(scene.sound_event_count==count_before and scene.battle_time==0,"skipping battle presentation does not emit another impact")
	await scene.undo(); scene.world.hp=12
	await Fixture.sync(scene)
	await scene.move(Vector2i.LEFT)
	check(scene.sound_event_count==count_before,"rejected lethal battle remains silent")
	# Water choice, actual crossing and bridge each have their own committed event.
	scene.world=World.new(0,1); scene.history.clear(); scene.world.enter_floor(1); scene.world.pos=Vector2i(1,4)
	await Fixture.bind(scene,scene.world)
	await scene.perform_action("spring")
	check(scene.sound_event_count==count_before+1 and scene.last_sound_event=="water","spring choice emits one water event")
	count_before=scene.sound_event_count
	await scene.perform_action("spring")
	check(scene.sound_event_count==count_before,"rejected repeated spring does not replay sound")
	scene.world.enter_floor(2); scene.world.pos=Vector2i(2,7)
	await Fixture.sync(scene)
	await scene.move(Vector2i.DOWN)
	check(scene.sound_event_count==count_before+1 and scene.last_sound_event=="pickup","survey pickup emits one pickup event")
	count_before=scene.sound_event_count
	scene.world.enter_floor(3); scene.world.pos=Vector2i(3,5)
	await Fixture.sync(scene)
	await scene.perform_action("quest_bridge")
	check(scene.sound_event_count==count_before+1 and scene.last_sound_event=="water","bridge completion emits one water event")
	count_before=scene.sound_event_count
	await scene.perform_action("quest_bridge")
	check(scene.sound_event_count==count_before,"duplicate bridge request stays silent")
	scene.world.enter_floor(1); scene.world.pos=Vector2i(8,3)
	await Fixture.sync(scene)
	await scene.move(Vector2i.UP)
	check(scene.sound_event_count==count_before+1 and scene.last_sound_event=="water","actual bridge-water crossing emits once")
	# Controlled endgame fixture isolates final event selection, not balance.
	scene.world=World.new(0,1)
	for floor_id in range(1,5): scene.world.enter_floor(floor_id)
	scene.world.pos=Vector2i(7,3); scene.world.atk=500
	await Fixture.bind(scene,scene.world)
	count_before=scene.sound_event_count
	await scene.move(Vector2i.RIGHT)
	check(scene.world.won and scene.sound_event_count==count_before+1 and scene.last_sound_event=="victory","final boss chooses victory instead of double-counting impact")
	count_before=scene.sound_event_count
	await scene.move(Vector2i.LEFT)
	check(scene.sound_event_count==count_before,"post-victory blocked movement produces no audio")
	scene.toggle_mute()
	check(scene.muted and not scene.sound_player.playing and scene.sound_event_count==count_before,"muting stops playback without emitting game event")
	print("AUDIO: %s (%d checks; headless event routing, no claim of audible QA)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
