extends SceneTree
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures+=1; push_error(message)
func _initialize():
	call_deferred("run_tests")
func run_tests():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.save_path="user://integration-test.json"
	await process_frame
	check(scene.world.pos==Vector2i(1,1),"initial position")
	scene.move(Vector2i.RIGHT)
	scene.move(Vector2i.RIGHT)
	check(scene.world.keys==1,"input controller collects key")
	check(scene.history.size()==2,"controller keeps undo snapshots")
	scene.undo()
	check(scene.world.keys==0 and scene.world.pos==Vector2i(2,1),"undo restores inventory and position")
	scene.world.hp=1
	scene.load_game()
	check(scene.world.hp==360 and scene.history.is_empty(),"load restores persisted state and clears undo")
	var event := InputEventKey.new()
	event.pressed=true;event.keycode=KEY_H
	scene._unhandled_input(event)
	check(scene.book,"H opens guide")
	event.keycode=KEY_D
	scene._unhandled_input(event)
	check(scene.world.pos==Vector2i(2,1),"guide prevents movement")
	event.keycode=KEY_ESCAPE
	scene._unhandled_input(event)
	check(not scene.book,"escape closes guide")
	event.keycode=KEY_R
	scene._unhandled_input(event)
	check(scene.world.pos==Vector2i(2,1),"one R does not restart")
	scene._unhandled_input(event)
	check(scene.world.pos==Vector2i(1,1),"two R restart")
	# Only remove the test-specific file generated above, never a player's journey.
	DirAccess.remove_absolute(scene.save_path)
	print("UI integration: %s (10 checks)" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
