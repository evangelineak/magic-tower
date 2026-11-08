extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String):
	checks+=1
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
	scene.world.pos=Vector2i(2,1)
	scene.perform_action("borrow")
	check(scene.world.debt()==42 and scene.world.gold==40,"UI borrowing updates ledger")
	scene.undo()
	check(scene.world.debt()==0 and scene.world.gold==0 and not scene.world.loan_used,"UI undo reverses full loan")
	scene.perform_action("borrow")
	scene.world.gold=60
	scene.perform_action("buy")
	check(scene.world.weapon and scene.world.gold==0,"UI purchase")
	scene.undo()
	check(not scene.world.weapon and scene.world.atk==18 and scene.world.gold==60 and scene.world.debt()==42,"UI purchase undo keeps matching gold and debt")
	scene.world.floor_index=2; scene.world.pos=Vector2i(8,9); scene.world.gold=22
	var steps_before: int=scene.world.moves
	scene.move(Vector2i.RIGHT)
	check(scene.interaction and scene.checkpoint_pending==Vector2i.RIGHT and scene.world.floor_index==2 and scene.world.debt()==42,"interest transition asks before changing state")
	event.keycode=KEY_D; scene._unhandled_input(event)
	check(scene.world.moves==steps_before,"modal prevents movement")
	scene.perform_action("cancel")
	check(not scene.interaction and scene.checkpoint_pending==Vector2i.ZERO and scene.world.debt()==42 and scene.world.floor_index==2,"cancel leaves interest uncharged")
	scene.move(Vector2i.RIGHT)
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.interaction and scene.checkpoint_pending==Vector2i.ZERO and scene.world.floor_index==2,"escape cancels pending ascent")
	scene.move(Vector2i.RIGHT)
	scene.perform_action("repay")
	check(scene.world.debt()==20 and scene.world.gold==0 and scene.checkpoint_pending==Vector2i.RIGHT,"repay while pending reduces remaining principal")
	scene.perform_action("continue")
	check(scene.world.floor_index==3 and scene.world.debt()==22 and scene.world.interest==2 and not scene.interaction,"confirmed ascent uses current principal")
	scene.undo()
	check(scene.world.floor_index==2 and scene.world.debt()==20 and scene.world.checkpoints==0,"undo crossing restores interest node and debt together")
	scene.move(Vector2i.RIGHT); scene.perform_action("continue")
	scene.move(Vector2i.RIGHT); scene.move(Vector2i.LEFT)
	check(scene.world.floor_index==2 and scene.world.checkpoints==1,"descend retains settled milestone")
	scene.move(Vector2i.LEFT); scene.move(Vector2i.RIGHT)
	check(scene.world.floor_index==3 and not scene.interaction and scene.world.interest==2,"revisit ascent does not charge or prompt twice")
	scene.load_game()
	check(scene.world.floor_index==3 and scene.world.debt()==22 and scene.history.is_empty(),"UI autosave preserves ledger and milestones")
	# Only remove the test-specific file generated above, never a player's journey.
	DirAccess.remove_absolute(scene.save_path)
	print("UI integration: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
