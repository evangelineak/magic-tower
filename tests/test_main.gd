extends SceneTree
const Fixture=preload("res://tests/ui_fixture.gd")
# Legacy-layout regression: authored fixed coordinates and old stair routes are intentional.
# New layout-2 behavior is covered by test_usability and both generator suites.
class ControlledStore extends Fixture.MemoryAdapter:
	var delayed := false
	var fail := false
	var conflict := false
	var lose_ack := false
	func commit_run(slot,revision,run_id,data,request):
		if delayed: await Engine.get_main_loop().process_frame
		if conflict: return {"ok":false,"status":"conflict","reason":"conflict","retryable":false}
		if fail: return {"ok":false,"status":"io_error","reason":"io_error","retryable":true}
		var result=await super.commit_run(slot,revision,run_id,data,request)
		if lose_ack:
			lose_ack=false
			return {"ok":false,"status":"ack_lost","reason":"ack_lost","retryable":true}
		return result
var failures := 0
var checks := 0
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize():
	call_deferred("run_tests")
func run_tests():
	var scene = load("res://main.tscn").instantiate()
	Fixture.attach(scene)
	root.add_child(scene)
	scene.language="en" # Preserve English-contract UI assertions; default Chinese has its own suite.
	await Fixture.bind(scene,load("res://scripts/world.gd").new(0,1))
	scene.growth=true; scene.growth_tab=0
	var event := InputEventKey.new()
	event.pressed=true
	await process_frame
	check(scene.growth and scene.growth_tab==0 and scene.growth_actions().size()==3,"startup automatically presents hero choices")
	event.keycode=KEY_D; scene._unhandled_input(event)
	check(scene.world.moves==0 and scene.world.pos==Vector2i(1,1),"startup hero modal blocks movement")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.growth and scene.world.hero_id=="warden","Escape accepts default Warden without spending move")
	check(scene.world.pos==Vector2i(1,1),"initial position")
	await scene.move(Vector2i.RIGHT)
	await scene.move(Vector2i.RIGHT)
	check(scene.world.keys==1,"input controller collects key")
	check(scene.history.size()==2,"controller keeps undo snapshots")
	await scene.undo()
	check(scene.world.keys==0 and scene.world.pos==Vector2i(2,1),"undo restores inventory and position")
	scene.world.hp=1
	await scene.load_game()
	check(scene.world.hp==280 and scene.history.is_empty(),"load restores persisted state and clears undo")
	event.keycode=KEY_H
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
	check(scene.growth and scene.growth_tab==0,"replay automatically reopens hero selection")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	scene.world.pos=Vector2i(2,1)
	await Fixture.sync(scene)
	await scene.perform_action("borrow")
	check(scene.world.debt()==42 and scene.world.gold==40,"UI borrowing updates ledger")
	await scene.undo()
	check(scene.world.debt()==0 and scene.world.gold==0 and not scene.world.loan_used,"UI undo reverses full loan")
	await scene.perform_action("borrow")
	scene.world.gold=60
	await Fixture.sync(scene)
	await scene.perform_action("buy")
	check(scene.world.weapon and scene.world.gold==0,"UI purchase")
	await scene.undo()
	check(not scene.world.weapon and scene.world.atk==18 and scene.world.gold==60 and scene.world.debt()==42,"UI purchase undo keeps matching gold and debt")
	scene.world.enter_floor(1); scene.world.enter_floor(2); scene.world.pos=Vector2i(8,9); scene.world.gold=22
	await Fixture.sync(scene)
	var steps_before: int=scene.world.moves
	await scene.move(Vector2i.RIGHT)
	check(scene.interaction and scene.pending_reason=="interest" and scene.checkpoint_pending==Vector2i.RIGHT and scene.world.floor_index==2 and scene.world.debt()==42,"interest transition asks before changing state")
	event.keycode=KEY_D; scene._unhandled_input(event)
	check(scene.world.moves==steps_before,"modal prevents movement")
	await scene.perform_action("cancel")
	check(not scene.interaction and scene.checkpoint_pending==Vector2i.ZERO and scene.world.debt()==42 and scene.world.floor_index==2,"cancel leaves interest uncharged")
	await scene.move(Vector2i.RIGHT)
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.interaction and scene.checkpoint_pending==Vector2i.ZERO and scene.world.floor_index==2,"escape cancels pending ascent")
	await scene.move(Vector2i.RIGHT)
	await scene.perform_action("repay")
	check(scene.world.debt()==20 and scene.world.gold==0 and scene.checkpoint_pending==Vector2i.RIGHT,"repay while pending reduces remaining principal")
	await scene.perform_action("continue")
	check(scene.world.floor_index==3 and scene.world.debt()==22 and scene.world.interest==2 and not scene.interaction,"confirmed ascent uses current principal")
	await scene.undo()
	check(scene.world.floor_index==2 and scene.world.debt()==20 and scene.world.checkpoints==0,"undo crossing restores interest node and debt together")
	await scene.move(Vector2i.RIGHT); await scene.perform_action("continue")
	# Restart uses the new layout; fourth-floor stairs now stay at (9,9).
	await scene.move(Vector2i.LEFT); await scene.move(Vector2i.RIGHT)
	check(scene.world.floor_index==2 and scene.world.checkpoints==1,"descend retains settled milestone")
	await scene.move(Vector2i.LEFT); await scene.move(Vector2i.RIGHT)
	check(scene.world.floor_index==3 and not scene.interaction and scene.world.interest==2,"revisit ascent does not charge or prompt twice")
	await scene.load_game()
	check(scene.world.floor_index==3 and scene.world.debt()==22 and scene.history.is_empty(),"UI autosave preserves ledger and milestones")
	await Fixture.bind(scene,load("res://scripts/world.gd").new(0,1)); scene.history.clear()
	event.keycode=KEY_C; scene._unhandled_input(event)
	check(scene.growth and scene.growth_actions().size()==3,"C offers three heroes before first move")
	event.keycode=KEY_D; scene._unhandled_input(event)
	check(scene.world.moves==0 and scene.world.pos==Vector2i(1,1),"hero panel blocks exploration input")
	event.keycode=KEY_2; scene._unhandled_input(event)
	check(scene.world.hero_id=="ranger" and not scene.growth,"number selects ranger and closes panel")
	event.keycode=KEY_C; scene._unhandled_input(event)
	check(scene.growth and scene.growth_actions()[0][0]=="arm","hero panel becomes skill panel after selection")
	event.keycode=KEY_1; scene._unhandled_input(event)
	check(scene.world.skill_armed,"number prepares hero skill")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.growth,"escape closes skill panel")
	scene.world.pos=Vector2i(5,3)
	await Fixture.sync(scene)
	var before_combat: Dictionary=scene.world.save_data().duplicate(true)
	var predicted_loss: int=scene.world.damage("s")
	await scene.move(Vector2i.LEFT)
	check(scene.battle_time>0 and scene.battle_loss==predicted_loss and scene.world.kills==1,"battle presentation matches committed combat")
	var after_combat: Dictionary=scene.world.save_data().duplicate(true)
	event.keycode=KEY_D; scene._unhandled_input(event)
	check(scene.battle_time==0 and scene.world.save_data()==after_combat,"skip animation does not repeat combat or move")
	await scene.undo()
	check(scene.world.save_data()==before_combat and scene.battle_time==0,"combat undo restores enemy, focus, hero and stats together")
	scene.world.kills=3
	await Fixture.sync(scene)
	event.keycode=KEY_C; scene._unhandled_input(event)
	check(scene.growth_tab==2 and scene.growth_actions().size()==3,"unlocked talent tier opens three mutually exclusive choices")
	event.keycode=KEY_1; scene._unhandled_input(event)
	check(scene.world.talents.is_empty() and scene.talent_selected!="" and scene.growth,"talent key previews without committing")
	await scene.confirm_talent()
	check(scene.world.talents.size()==1 and not scene.growth,"Enter confirms the preselected talent")
	await scene.undo()
	check(scene.world.talents.is_empty(),"talent selection reversible via whole-state undo")
	var folio_snapshot=scene.world.save_data().duplicate(true)
	scene.growth=true;scene.growth_tab=2;scene.select_talent(0)
	var folio_selected=scene.talent_selected
	var folio_forecast=scene.talent_card_preview(folio_selected)
	check(folio_forecast.valid and not folio_forecast.before.is_empty(),"folio preview uses a real known enemy")
	check(scene.world.save_data()==folio_snapshot,"talent preview neither learns nor changes current build")
	check(scene.talent_targets().all(func(t):return t.floor==scene.world.floor_index),"unseen third-floor vault is not disclosed")
	scene.world.floor_seen[1]=true;scene.world.floor_seen[2]=true
	await Fixture.sync(scene)
	check(scene.talent_targets().any(func(t):return t.floor==2 and t.kind=="V"),"seen surviving vault becomes a remote comparison target")
	var folio_targets=scene.talent_targets()
	for i in folio_targets.size():
		if folio_targets[i].floor==2:scene.talent_target_index=i;break
	var vault_comparison=scene.talent_card_preview(folio_selected)
	check(not vault_comparison.after.get("flank_active",false),"remote vault forecast cannot gain current-position flank")
	scene.session.adapter.lost_ack=true
	await scene.confirm_talent()
	check(scene.world.talents.is_empty() and scene.talent_submitted,"talent lost ACK keeps the old live build")
	scene.select_talent(1)
	check(scene.talent_selected==folio_selected,"pending talent choice cannot silently change retry target")
	await scene.retry_save()
	check(scene.world.talents==[folio_selected] and not scene.talent_submitted,"F5 publishes exactly the confirmed talent")
	await scene.undo()
	check(scene.world.talent_draft==folio_snapshot.talent_draft,"talent Undo restores the same fixed booklet")
	# Cosmetic folio toast is generated only by a committed milestone kill.
	scene.growth=false;scene.world.kills=3
	scene.step_effect("s","warden")
	check(scene.battle_time>0 and scene.talent_notice_tier==0 and scene.talent_notice_time>0,"third kill queues a noticeable folio notice behind battle replay")
	var notice_before=scene.talent_notice_time
	scene._process(0.1)
	check(scene.talent_notice_time==notice_before,"folio notice does not expire underneath the battle replay")
	scene.battle_time=0
	scene._process(0.5)
	check(scene.talent_notice_time<notice_before,"folio notice countdown begins only after combat feedback")
	await scene.load_game()
	check(scene.talent_notice_time==0,"load does not replay folio acquisition feedback")

	var seed_before: int=scene.world.seed_value
	event.keycode=KEY_R; scene._unhandled_input(event); scene._unhandled_input(event)
	check(scene.world.seed_value==seed_before and scene.world.moves==0,"replay retains same seed")
	check(scene.growth and scene.growth_tab==0,"later replay resets growth tab to hero selection")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	event.keycode=KEY_N; scene._unhandled_input(event)
	check(scene.world.seed_value==seed_before,"one N does not overwrite journey")
	event.keycode=KEY_D; scene._unhandled_input(event)
	check(scene.selected_run_mode=="risk" and scene.world.mode=="safe" and scene.world.seed_value==seed_before,"new-run risk selection does not convert current safe journey")
	event.keycode=KEY_LEFT; scene._unhandled_input(event)
	check(scene.world.moves==0 and scene.reset_armed,"mode confirmation blocks movement")
	event.keycode=KEY_N; scene._unhandled_input(event)
	check(scene.growth and scene.world.mode=="risk" and scene.world.moves==0,"confirmed risk new seed presents hero choices")
	await Fixture.bind(scene,load("res://scripts/world.gd").new(0,1)); scene.history.clear()
	scene.growth=true; scene.growth_tab=0
	await scene.save_game(false)
	var readonly_before: Dictionary=scene.world.save_data().duplicate(true)
	var file_before: Dictionary=Fixture.snapshot(scene)
	event.keycode=KEY_J; scene._unhandled_input(event)
	check(scene.journal and not scene.growth and not scene.book and not scene.interaction,"J opens exclusive read-only journal")
	var initial_notes: String="\n".join(scene.journal_lines())
	check(not "Floor 2" in initial_notes and not "Floor 3" in initial_notes and not "Floor 4" in initial_notes and not "Inscription:" in initial_notes,"journal hides unvisited water, vault, event and unlearned clue")
	for key in [KEY_D,KEY_1,KEY_U,KEY_R,KEY_L]:
		event.keycode=key; scene._unhandled_input(event)
	check(scene.world.save_data()==readonly_before and scene.history.is_empty() and Fixture.snapshot(scene)==file_before,"journal blocks movement, choices, undo, restart and loading without changing save")
	event.keycode=KEY_BRACKETRIGHT; scene._unhandled_input(event)
	await process_frame
	check(scene.world.save_data()==readonly_before,"journal pagination spends no resources or moves")
	event.keycode=KEY_J; scene._unhandled_input(event)
	check(not scene.journal and scene.world.save_data()==readonly_before,"J closes journal without mutation")
	for key in [KEY_C,KEY_E,KEY_H]:
		event.keycode=KEY_J; scene._unhandled_input(event)
		event.keycode=key; scene._unhandled_input(event)
		check(not scene.journal,"switching to C E H closes journal")
		event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(scene.world.save_data()==readonly_before,"switching journal panels remains read-only")
	scene.world.enter_floor(1)
	await Fixture.sync(scene)
	var notes: String="\n".join(scene.journal_lines())
	check("Floor 2" in notes and not "Floor 3" in notes and not "Floor 4" in notes,"visited floor unlocks only its own notes")
	scene.world.enter_floor(2)
	await Fixture.sync(scene)
	notes="\n".join(scene.journal_lines())
	check("powerful guardian" in notes,"journal records unresolved visited vault")
	scene.world.floors[2][3][8]="."
	await Fixture.sync(scene)
	notes="\n".join(scene.journal_lines())
	check("treasure is unclaimed" in notes,"journal distinguishes defeated guard from claimed treasure")
	scene.world.floors[2][3][9]="."
	await Fixture.sync(scene)
	notes="\n".join(scene.journal_lines())
	check("treasure has been claimed" in notes,"journal records claimed vault")
	scene.world.enter_floor(3); scene.world.pos=Vector2i(1,2); scene.world.step(Vector2i.DOWN)
	await Fixture.sync(scene)
	check("Inscription:" in "\n".join(scene.journal_lines()),"journal retains learned clue")
	await scene.save_game(false)
	event.keycode=KEY_J; scene._unhandled_input(event)
	await scene.load_game()
	check(not scene.journal and scene.journal_page==0,"successful load closes journal and resets page")
	event.keycode=KEY_J; scene._unhandled_input(event)
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.journal,"Escape dismisses journal")
	event.keycode=KEY_R; scene._unhandled_input(event); scene._unhandled_input(event)
	check(not scene.journal and scene.growth and scene.journal_page==0,"replay leaves journal closed and opens hero selection")
	await Fixture.bind(scene,load("res://scripts/world.gd").new(0,1)); scene.history.clear(); scene.growth=false
	scene.world.pos=Vector2i(3,9); scene.world.keys=2
	await Fixture.sync(scene)
	var gate_before: Dictionary=scene.world.save_data().duplicate(true)
	check("2 keys" in scene.token_name("L") and "70" in scene.token_name("h") and "140" in scene.token_name("P"),"updated gate and recovery hover descriptions")
	check("Floor 1 cache:" in "\n".join(scene.journal_lines()) and not "Floor 3 cache:" in "\n".join(scene.journal_lines()),"journal lists visited reward cage but hides unvisited cage")
	await scene.move(Vector2i.LEFT)
	check(scene.interaction and scene.pending_reason=="door" and scene.world.save_data()==gate_before,"attempting double lock asks before spending keys")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(not scene.interaction and scene.checkpoint_pending==Vector2i.ZERO and scene.world.save_data()==gate_before,"Escape cancels key spending without moving")
	await scene.move(Vector2i.LEFT); await scene.perform_action("continue")
	check(scene.world.keys==0 and scene.world.tile(Vector2i(2,9))=="." and not scene.interaction,"confirmed double lock spends exactly two keys")
	check("unclaimed, lock already opened" in "\n".join(scene.journal_lines()),"journal distinguishes opened cage from claimed reward")
	await scene.move(Vector2i.LEFT)
	check(scene.world.gold==60 and not "Floor 1 cache:" in "\n".join(scene.journal_lines()),"claiming cache updates reward and journal")
	await scene.undo(); await scene.undo()
	check(scene.world.save_data()==gate_before,"UI undo restores reward gate keys and whole state together")
	scene.world.keys=1
	await Fixture.sync(scene)
	await scene.move(Vector2i.LEFT)
	check(not scene.interaction and scene.world.keys==1 and scene.world.pos==Vector2i(3,9),"insufficient keys blocks double lock without confirmation")
	scene.world.pos=Vector2i(5,3)
	await Fixture.sync(scene)
	await scene.move(Vector2i.RIGHT)
	check(scene.interaction and scene.pending_reason=="door" and scene.available_actions().size()==2,"ordinary door offers only confirm/cancel, not interest actions")
	await scene.perform_action("cancel")
	check(scene.world.keys==1 and scene.world.pos==Vector2i(5,3) and scene.pending_reason=="","ordinary door cancellation clears reason without charge")
	await scene.move(Vector2i.RIGHT); await scene.perform_action("continue")
	check(scene.world.keys==0 and scene.world.tile(Vector2i(6,3))==".","ordinary door spends exactly one key")
	await scene.move(Vector2i.LEFT); await scene.move(Vector2i.RIGHT)
	check(scene.world.keys==0 and not scene.interaction and scene.world.pos==Vector2i(6,3),"already opened door never reconfirms or charges twice")
	# Attunement is a read-only modal until a separate explicit confirmation.
	await Fixture.bind(scene,load("res://scripts/world.gd").new(0,2)); scene.history.clear(); scene.growth=false
	await scene.save_game(false)
	var pristine: Dictionary=scene.world.save_data().duplicate(true)
	var attune_file_before: Dictionary=Fixture.snapshot(scene)
	var attune_audio_before: int=scene.sound_event_count
	scene.start_walk(Vector2i(1,2))
	event.keycode=KEY_G; scene._unhandled_input(event)
	check(scene.attuning and scene.walk_route.is_empty() and scene.attune_gear=="buckler","G cancels walking and previews non-traveler gear")
	check(scene.attunement_rows().size()==4,"unowned equipment exposes three fixed offers and original")
	scene.select_attunement(0)
	var pending: String=scene.attune_pending
	event.keycode=KEY_F2; scene._unhandled_input(event)
	check(scene.attune_pending==pending,"F2 retains candidate without applying it")
	event.keycode=KEY_ENTER; scene._unhandled_input(event)
	event.keycode=KEY_RIGHT; scene._unhandled_input(event)
	check(scene.world.save_data()==pristine and scene.history.is_empty(),"unowned confirmation and movement are blocked")
	check(Fixture.snapshot(scene)==attune_file_before and scene.sound_event_count==attune_audio_before,"preview never saves or plays action sounds")
	event.keycode=KEY_ESCAPE; scene._unhandled_input(event)
	check(scene.attuning and scene.attune_pending=="","Escape first backs out of confirmation")
	scene.cycle_attunement(1)
	check(scene.attune_gear=="duelist" and scene.attunement_rows().size()==4,"all non-traveler gear can be previewed before acquisition")
	scene.close_attunement(); scene.world.inventory.append("buckler"); scene.world.equipped="buckler"; scene.world.chest_claimed=true
	await Fixture.sync(scene)
	var owned_before: Dictionary=scene.world.save_data().duplicate(true)
	scene.open_attunement(); scene.select_attunement(0)
	check(scene.world.save_data()==owned_before,"owned selection still requires separate confirmation")
	await scene.confirm_attunement()
	check(scene.world.gear_choices.has("buckler") and scene.attunement_rows().is_empty() and scene.history.size()==1,"confirmed selection locks only this gear with one undo snapshot")
	var locked: Dictionary=scene.world.save_data().duplicate(true)
	await scene.confirm_attunement()
	check(scene.world.save_data()==locked,"repeat confirmation cannot apply twice")
	await scene.undo()
	check(not scene.attuning and scene.world.save_data()==owned_before,"undo closes modal and restores actual offers and choices")
	scene.open_attunement(); scene.select_attunement(3); await scene.confirm_attunement()
	check(scene.world.gear_choices.get("buckler")=="none" and scene.attunement_rows().is_empty(),"keeping original is an explicit locked choice")
	await scene.load_game()
	check(not scene.attuning,"load closes attunement modal")
	# Legacy file is not a second writer path: L only reads the new active slot.
	var legacy_path="user://journey-v4.json"
	var existed=FileAccess.file_exists(legacy_path)
	var prior_bytes=FileAccess.get_file_as_bytes(legacy_path) if existed else PackedByteArray()
	var original_bytes="legacy fixture must remain untouched"
	var old_file=FileAccess.open(legacy_path,FileAccess.WRITE); old_file.store_string(original_bytes); old_file.close()
	var active_id: String=scene.world.run_id
	await scene.load_game()
	check(FileAccess.get_file_as_string(legacy_path)==original_bytes,"L leaves legacy bytes untouched")
	check(scene.world.run_id==active_id and scene.world.reward_eligible(),"L reads only the eligible active slot, never grafts legacy")
	if existed:
		old_file=FileAccess.open(legacy_path,FileAccess.WRITE);old_file.store_buffer(prior_bytes);old_file.close()
	else: DirAccess.remove_absolute(legacy_path)
	# Delayed durable commits never publish speculative world/history/effects.
	var slow=ControlledStore.new()
	scene.session=load("res://scripts/session.gd").new(slow)
	await scene.initialize_session()
	scene.apply_session_result(await scene.session.new_run(0,1,true))
	scene.growth=false
	var before_delayed=scene.world.save_data().duplicate(true)
	var sounds_before=scene.sound_event_count
	slow.delayed=true
	scene.move(Vector2i.RIGHT)
	check(scene.session.busy and scene.world.save_data()==before_delayed and scene.history.is_empty(),"inflight step does not publish candidate or undo history")
	check(scene.sound_event_count==sounds_before,"inflight step has no speculative audio")
	await scene.move(Vector2i.RIGHT)
	await process_frame; await process_frame
	check(scene.world.moves==1 and slow.writes==3,"busy repeated input commits only once")
	slow.delayed=false; slow.fail=true
	var stable=scene.world.save_data().duplicate(true)
	var history_before=scene.history.duplicate(true)
	await scene.move(Vector2i.RIGHT)
	check(scene.world.save_data()==stable and scene.history==history_before,"IO failure preserves live world and history")
	check(scene.ui_notice=="io_error","storage failure uses UI-local notice")
	await scene.perform_action("arm")
	check(scene.world.save_data()==stable,"pending save prevents a different action from replacing candidate")
	slow.fail=false
	await scene.retry_save()
	check(scene.world.moves==2 and scene.world.keys==1,"retry commits the same held candidate")
	slow.conflict=true
	stable=scene.world.save_data().duplicate(true)
	await scene.move(Vector2i.LEFT)
	check(scene.session.read_only and scene.world.save_data()==stable,"fence conflict enters readonly without speculative movement")
	await scene.move(Vector2i.LEFT)
	check(scene.world.save_data()==stable,"readonly cannot overwrite current slot")
	slow.conflict=false
	await scene.load_game()
	check(not scene.session.read_only and scene.history.is_empty(),"explicit reload reacquires and discards stale history")
	scene.growth=false; slow.delayed=true
	scene.start_walk(Vector2i(1,1))
	scene.advance_walk(0.2)
	scene.cancel_walk()
	await process_frame; await process_frame
	check(scene.walk_route.is_empty(),"manual cancellation during await cannot resume automatic route")
	# Lost acknowledgements commit on disk once, but effects wait for successful retry.
	slow.delayed=false
	scene.world.pos=Vector2i(5,3)
	await Fixture.sync(scene)
	scene.battle_time=0.0
	var battle_before=scene.world.save_data().duplicate(true)
	var effect_before=scene.sound_event_count
	var writes_before=slow.writes
	slow.lose_ack=true
	await scene.move(Vector2i.LEFT)
	check(scene.world.save_data()==battle_before and scene.sound_event_count==effect_before and scene.battle_time==0.0,"lost combat acknowledgement has no speculative effects")
	await scene.retry_save()
	check(scene.world.kills==1 and scene.battle_time>0 and scene.sound_event_count==effect_before+1,"retried combat publishes exactly one battle and impact")
	check(slow.writes==writes_before+1,"retry never executes combat or storage mutation twice")
	var final_battle=scene.world.save_data().duplicate(true)
	await scene.retry_save()
	check(scene.world.save_data()==final_battle and scene.sound_event_count==effect_before+1,"extra F5 cannot replay successful effects")
	# Settlement intent is a read-only confirmation until explicit Enter.
	await Fixture.bind(scene,load("res://scripts/world.gd").new(0,2))
	scene.growth=false
	var unfinished=scene.world.save_data().duplicate(true)
	var ledger_before=Fixture.snapshot(scene)
	scene.request_finish()
	check(scene.finish_pending=="withdrawn" and scene.modal_open(),"X opens explicit withdrawal confirmation")
	event.keycode=KEY_D;scene._unhandled_input(event)
	check(scene.world.save_data()==unfinished and Fixture.snapshot(scene)==ledger_before,"withdrawal prompt blocks moves and never settles implicitly")
	var old_language=scene.language
	event.keycode=KEY_F2;scene._unhandled_input(event)
	check(scene.finish_pending=="withdrawn" and scene.language!=old_language,"F2 preserves withdrawal confirmation without committing")
	event.keycode=KEY_ESCAPE;scene._unhandled_input(event)
	check(scene.finish_pending=="" and scene.world.save_data()==unfinished,"Escape cancels withdrawal without changing active run")
	# Settlement is transactional and terminal only after durable acknowledgement.
	scene.world.enter_floor(1);scene.world.enter_floor(2)
	await Fixture.sync(scene)
	unfinished=scene.world.save_data().duplicate(true)
	scene.request_finish()
	var pre_finish_audio=scene.sound_event_count
	scene.session.adapter.lost_ack=true
	await scene.confirm_finish()
	check(not scene.is_terminal() and scene.world.save_data()==unfinished,"lost settlement acknowledgement never publishes terminal state")
	check(scene.sound_event_count==pre_finish_audio and scene.finish_pending=="withdrawn","pending settlement has no reward effects and keeps retry context")
	await scene.retry_save()
	check(scene.is_terminal() and scene.finish_pending=="" and scene.history.is_empty(),"successful retry shows terminal page and clears undo")
	check(scene.session.receipt.milestones==[3] and scene.sound_event_count==pre_finish_audio+1,"first reached milestone and effect published once")
	var settled_snapshot=scene.world.save_data().duplicate(true)
	var settled_record=Fixture.snapshot(scene)
	event.keycode=KEY_D;scene._unhandled_input(event)
	event.keycode=KEY_U;scene._unhandled_input(event)
	check(scene.world.save_data()==settled_snapshot and Fixture.snapshot(scene)==settled_record,"terminal directions and Undo are read-only")
	await scene.retry_save()
	check(scene.sound_event_count==pre_finish_audio+1,"duplicate terminal retry does not replay reward effect")
	await scene.load_game()
	check(scene.is_terminal() and scene.world.save_data()==settled_snapshot and scene.sound_event_count==pre_finish_audio+1,"L restores settled record without replaying effects")
	check("capacity for each new run" in "\n".join(scene.terminal_lines()) and "repeated records grant nothing" in "\n".join(scene.terminal_lines()),"archive labels explain per-run capacity and no repeated-record farming")
	check(scene.settlement_notice()=="","archive does not show restored exploration message")
	check(scene.milestone_text([3.0,5.0])=="[3, 5]","JSON milestone numbers display as floor integers")
	var terminal_id=scene.world.run_id
	await scene.request_restart("new")
	check(scene.is_terminal() and scene.world.run_id==terminal_id,"terminal new game still needs explicit second confirmation")
	await scene.request_restart("new")
	check(not scene.is_terminal() and scene.world.run_id!=terminal_id and scene.strategy_pending(),"confirmed new game gets new identity and requires unlocked strategy selection")
	check(scene.session.adapter.profile.milestones==[3],"new game preserves stored history milestones")
	var draft_before=scene.world.save_data().duplicate(true)
	var draft_record=Fixture.snapshot(scene)
	var draft_sounds=scene.sound_event_count
	event.keycode=KEY_1;scene._unhandled_input(event)
	var selected_strategy: String=scene.strategy_selection
	var expected_setup_level: int=12+(4 if selected_strategy=="study" else 0)
	var earned_setup_profile: Dictionary=scene.session.adapter.profile.duplicate(true)
	event.keycode=KEY_Q;scene._unhandled_input(event)
	check(scene.setup_allocation=={"study":1,"reserve":0} and scene.setup_preview().skill_level==expected_setup_level,"study previews actual +2 levels without spending capacity")
	event.keycode=KEY_W;scene._unhandled_input(event)
	check(scene.setup_allocation=={"study":1,"reserve":0},"cannot allocate beyond earned first milestone capacity")
	event.keycode=KEY_F2;scene._unhandled_input(event)
	check(scene.strategy_selection==selected_strategy and scene.world.save_data()==draft_before,"strategy preview/F2 change no World state")
	event.keycode=KEY_D;scene._unhandled_input(event)
	event.keycode=KEY_U;scene._unhandled_input(event)
	check(Fixture.snapshot(scene)==draft_record and scene.sound_event_count==draft_sounds,"mandatory strategy modal blocks movement/Undo and writes no preview")
	event.keycode=KEY_ESCAPE;scene._unhandled_input(event)
	check(scene.setup_allocation=={"study":0,"reserve":0},"Escape clears only local allocation")
	check(scene.strategy_selection=="" and scene.strategy_pending(),"Escape clears preview but cannot skip mandatory choice")
	await scene.load_game()
	check(scene.world.draft==draft_before.draft and scene.strategy_selection=="","L restores exact offers without rerolling")
	event.keycode=KEY_1;scene._unhandled_input(event)
	scene.adjust_setup("study",1)
	scene.session.adapter.fail_before=true
	await scene.confirm_strategy()
	check(scene.strategy_pending() and scene.world.save_data()==draft_before,"strategy IO failure does not lock live draft")
	event.keycode=KEY_0;scene._unhandled_input(event)
	scene.adjust_setup("study",-1)
	check(scene.setup_allocation.study==1,"failed whole-plan commit freezes original allocation for F5")
	check(scene.strategy_selection==selected_strategy,"pending strategy retry keeps the originally submitted preview, not a different card")
	await scene.retry_save()
	check(not scene.strategy_pending() and scene.world.current_strategy()==selected_strategy and scene.world.moves==0 and scene.history.is_empty(),"strategy retry locks exactly once without a move and clears Undo")
	check(scene.world.legacy_points.study==1 and scene.world.skill_level()==expected_setup_level,"retry atomically locks study with selected strategy")
	var locked_strategy=scene.world.save_data().duplicate(true)
	await scene.undo()
	await scene.load_game()
	check(scene.world.save_data()==locked_strategy and scene.sound_event_count==draft_sounds,"locked strategy survives Undo/L with no reward sound")

	await scene.request_restart("replay")
	await scene.request_restart("replay")
	check(scene.strategy_pending(),"same-seed new journey offers a fresh explicit strategy choice")
	var same_seed_offers=scene.world.draft.offers.duplicate()
	event.keycode=KEY_0;scene._unhandled_input(event)
	scene.adjust_setup("reserve",1)
	scene.session.adapter.lost_ack=true
	await scene.confirm_strategy()
	check(scene.strategy_pending() and scene.strategy_selection=="none","lost acknowledgement leaves old live draft and original-rules preview")
	var strategy_writes=scene.session.adapter.writes
	await scene.retry_save()
	check(not scene.strategy_pending() and scene.world.current_strategy()=="none" and scene.session.adapter.writes==strategy_writes,"ack retry publishes original rules once without another write")
	check(scene.world.legacy_reserves==1 and scene.world.legacy_points.reserve==1,"original strategy can lock one reserve with one ACK retry")
	await scene.retry_save()
	await scene.load_game()
	check(scene.world.draft.offers==same_seed_offers and scene.world.draft.choice=="none","repeat retry and load retain deterministic offers and locked original rules")
	await scene.perform_action("hero_warden")
	scene.growth_tab=0
	check(scene.growth_actions().size()==2 and scene.growth_actions()[1][0]=="legacy_focus","hero page exposes separate emergency supply action after hero choice")
	var reserve_before=scene.world.save_data().duplicate(true)
	await scene.perform_action("legacy_focus")
	check(scene.world.focus==3 and scene.world.legacy_reserves==0,"emergency supply adds one focus and spends exactly one owned charge")
	var full_before=Fixture.snapshot(scene)
	await scene.perform_action("legacy_focus")
	check(Fixture.snapshot(scene)==full_before,"full focus or exhausted supply cannot spend resources")
	await scene.undo()
	check(scene.world.save_data()==reserve_before,"Undo restores supply and focus together without changing locked allocation")
	await scene.load_game()
	check(scene.world.save_data()==reserve_before,"reload keeps restored supply and chosen setup")
	# Actual first-chapter proof supplies a legitimate K-victory UI fixture.
	var first_win=load("res://scripts/world.gd").new(0,1)
	var route=load("res://scripts/generation.gd").validate(first_win.floors,1).route
	for direction in route:
		first_win.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[direction])
	await Fixture.bind(scene,first_win)
	check(scene.world.won and not scene.is_terminal() and scene.world.chapter_offers().size()==1,"K victory remains active with optional continuation")
	scene.request_finish()
	check(scene.finish_pending=="chapter1","K finish chooses chapter-one receipt, not full victory")
	await scene.confirm_finish()
	check(scene.is_terminal() and scene.session.receipt.summary.outcome=="chapter1","explicit K settlement archives chapter one")
	first_win.action("expedition")
	first_win.enter_floor(6);first_win.enter_floor(7)
	first_win.floors[7][3][8]=".";first_win.pos=Vector2i(8,3);first_win.won=true
	await Fixture.bind(scene,first_win)
	check(scene.settlement_outcome()=="victory" and not scene.is_terminal(),"Z victory still awaits explicit settlement")
	scene.request_finish();await scene.confirm_finish()
	check(scene.is_terminal() and scene.session.receipt.summary.outcome=="victory","Z confirmation records final victory")
	# Synthetic risk fixture is test-only; production must use explicit new-run selection.
	var risk_world=load("res://scripts/world.gd").new(0,1,"","risk")
	risk_world.hp=1; risk_world.defense=0; risk_world.pos=Vector2i(3,4)
	# Locate a real enemy with an ordinary adjacent floor without altering map contents.
	var lethal_direction:=Vector2i.ZERO
	for yy in range(11):
		for xx in range(11):
			if risk_world.tile(Vector2i(xx,yy))!="s": continue
			for dd in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
				if risk_world.tile(Vector2i(xx,yy)-dd)==".": risk_world.pos=Vector2i(xx,yy)-dd; lethal_direction=dd
	await Fixture.bind(scene,risk_world)
	scene.growth=false;scene.reset_armed=false;scene.finish_pending=""
	var alive=scene.world.save_data().duplicate(true)
	var sound_before=scene.sound_event_count
	await scene.move(lethal_direction)
	check(not scene.lethal_snapshot.is_empty() and scene.world.save_data()==alive,"risk move previews lethal fight without mutating live world")
	event.keycode=KEY_F2;scene._unhandled_input(event)
	check(scene.lethal_snapshot==alive,"language switch preserves original confirmation snapshot")
	event.keycode=KEY_UP;scene._unhandled_input(event)
	check(scene.world.save_data()==alive,"lethal confirmation blocks movement")
	event.keycode=KEY_ESCAPE;scene._unhandled_input(event)
	check(scene.lethal_snapshot.is_empty() and scene.world.save_data()==alive,"cancel preserves the living run")
	await scene.move(lethal_direction)
	await scene.session.action("arm")
	scene.world=scene.session.world
	var changed_before=scene.world.save_data().duplicate(true)
	await scene.confirm_lethal()
	check(not scene.is_terminal() and scene.world.save_data()==changed_before and not scene.lethal_snapshot.is_empty(),"changed current state refuses frozen lethal confirmation instead of silently refreshing it")
	scene.clear_lethal()
	await Fixture.bind(scene,risk_world);scene.growth=false
	alive=scene.world.save_data().duplicate(true);sound_before=scene.sound_event_count
	await scene.move(lethal_direction)
	scene.session.adapter.lost_ack=true
	await scene.confirm_lethal()
	check(not scene.is_terminal() and scene.world.save_data()==alive and scene.sound_event_count==sound_before,"lost death acknowledgement leaves live display and audio unchanged")
	await scene.retry_save()
	check(scene.is_terminal() and scene.world.hp==0 and scene.death_report and scene.battle_time==0,"retry publishes durable death report, never full victory replay")
	check(scene.world.gold==alive.gold and scene.world.kills==alive.kills and scene.world.pos==Vector2i(alive.x,alive.y),"death does not grant kill gold, kills or advance into enemy")
	check(scene.world.last_battle.fatal and scene.death_event_lines().size()==scene.world.last_battle.events.size(),"report uses actual fatal event prefix")
	check(scene.sound_event_count==sound_before+1,"durable death has one impact sound")
	await scene.retry_save()
	check(scene.sound_event_count==sound_before+1,"duplicate retry cannot replay death effects")
	await scene.load_game()
	check(scene.is_terminal() and not scene.death_report and scene.session.receipt.summary.outcome=="defeat","reload restores defeat receipt without replay")
	var archived_before=Fixture.snapshot(scene)
	var archived_sound=scene.sound_event_count
	event.keycode=KEY_B;scene._unhandled_input(event)
	check(scene.death_report and not scene.death_event_lines().is_empty(),"B reopens reconstructed actual death events after L")
	check(Fixture.snapshot(scene)==archived_before and scene.sound_event_count==archived_sound,"read-only death review neither writes nor replays sound")
	for armed_hero in ["warden","ranger"]:
		var armed_world=load("res://scripts/world.gd").new(0,1,"","risk")
		armed_world.pos=risk_world.pos;armed_world.hp=1;armed_world.defense=0
		armed_world.hero_id=armed_hero;armed_world.skill_armed=true;armed_world.focus=2
		await Fixture.bind(scene,armed_world);scene.death_report=false;scene.growth=false
		await scene.move(lethal_direction)
		check(scene.lethal_preview.get("skill_consumed",false),"lethal confirmation uses actual armed "+armed_hero+" consumption, not survivor forecast flag")
		await scene.confirm_lethal()
		check(scene.is_terminal() and scene.world.focus==1 and not scene.world.skill_armed,"armed "+armed_hero+" death consumes exactly one focus")
	var learned_world=load("res://scripts/world.gd").new(0,2)
	learned_world.kills=7;learned_world.talents=["tactical_review","adversity_charge"]
	await Fixture.bind(scene,learned_world)
	scene.language="zh"
	check(scene.talent_loss_text({"valid":false})=="无法破防","folio combined forecast translates impossible damage before joining")
	var learned_before=Fixture.snapshot(scene)
	var learned_cards=scene.learned_talent_cards()
	check(learned_cards.size()==2 and learned_cards[0].id=="tactical_review" and learned_cards[1].id=="adversity_charge","learned folio preserves both names after choices exhaust")
	check(learned_cards[0].description!="" and learned_cards[1].description!="","learned folio retains actual ability descriptions")
	check(Fixture.snapshot(scene)==learned_before and scene.world.talent_options().is_empty(),"learned card review is read-only and not selectable")
	scene.growth=true;scene.growth_tab=2;scene.talent_selected=""
	event.keycode=KEY_1;scene._unhandled_input(event)
	await scene.confirm_talent()
	check(Fixture.snapshot(scene)==learned_before,"learned card number and confirmation cannot learn twice or spend resources")
	# Explicit deterministic coverage: study strategy adds +4 on top of the
	# same +2 legacy allocation; non-study retains level 12. No random-card assumption.
	var SetupWorld=load("res://scripts/world.gd")
	var setup_pool=SetupWorld.Strategy.pool_from_profile(earned_setup_profile)
	for chosen in ["study","reserve"]:
		var fixture_world
		for fixture_seed in range(32):
			fixture_world=SetupWorld.new(fixture_seed,2,"", "safe",false,setup_pool)
			if chosen in fixture_world.draft.offers: break
		check(chosen in fixture_world.draft.offers,"deterministic setup fixture offers "+chosen)
		await Fixture.bind(scene,fixture_world,earned_setup_profile)
		scene.strategy_selection=chosen;scene.setup_allocation={"study":0,"reserve":0};scene.strategy_submitted=false
		var base_level=int(scene.setup_preview().skill_level)
		scene.adjust_setup("study",1)
		var expected_level=12+(4 if chosen=="study" else 0)
		check(scene.setup_preview().skill_level==expected_level and scene.setup_preview().skill_level==base_level+2,"allocation preview adds exactly two for "+chosen)
		await scene.confirm_strategy()
		check(scene.world.skill_level()==expected_level and scene.world.legacy_points.study==1,"atomic setup stores additive skill level for "+chosen)
	var effects_preview=scene.world.setup_preview("none",{})
	check(scene.setup_hero_effects_text(effects_preview).contains("Scholar: heal"),"preparation exposes all three model-backed hero effects")
	print("UI integration: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
