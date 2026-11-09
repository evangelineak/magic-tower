extends SceneTree
const W=preload("res://scripts/endless_world_v21.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var failing=false
 var profile={"version":1,"milestones":[3,8,15],"unlocks":[]}
 var points=3
 var settlement={}
 var snapshot={}
 func read():return {"ok":true,"revision":revision,"snapshot":snapshot,"records":[],"profile":profile.duplicate(true),"points":points,"settlement":settlement.duplicate(true)}
 func unlock_legacy(id,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  if id not in profile.unlocks:profile.unlocks.append(id);points-=1 if id=="kit" else 2;revision+=1;writes+=1
  return read()
 func start_legacy(data,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  snapshot=data.duplicate(true);settlement={};revision+=1;writes+=1;return read()
 func commit(data,r):return await start_legacy(data,r)
 func finish(data,r):
  if failing:return {"ok":false,"status":"io_error"}
  snapshot=data.duplicate(true);revision+=1;writes+=1;settlement={"run_id":"receipt","awarded":[30],"balance_after":points+1};points+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 ui.world=load("res://scripts/endless_world_v20.gd").new_run(5);ui.world.act("hero_warden");ui.modal=""
 var old=ui.world.save_data();await ui.start_run(42,21);ui.hero_setup_selection="scholar";await ui.confirm_hero_setup()
 check(ui.modal=="legacy_setup" and ui.legacy_selection=="none" and ui.hero_setup_seed==42 and ui.world.save_data()==old,"hero step opens default-none legacy page without replacing old run")
 check(ui.legacy_points==3 and ui.legacy_rows().size()==4,"actual profile balance and four actual catalog cards")
 var writes=memory.writes;ui.legacy_selection="kit";await ui.start_legacy_setup()
 check(memory.writes==writes and ui.world.save_data()==old,"selecting locked card cannot start or deduct")
 memory.failing=true;await ui.unlock_setup_legacy("kit")
 check(ui.legacy_points==3 and not ui.owns_legacy("kit") and ui.world.save_data()==old,"failed unlock never grants visual ownership or replaces world")
 memory.failing=false;await ui.unlock_setup_legacy("kit")
 check(ui.legacy_points==2 and ui.owns_legacy("kit") and ui.world.save_data()==old,"confirmed unlock spends real returned points independently of start")
 writes=memory.writes;await ui.unlock_setup_legacy("kit")
 check(memory.writes==writes and ui.legacy_points==2,"repeated owned unlock cannot double-charge")
 memory.failing=true;await ui.start_legacy_setup()
 check(ui.world.save_data()==old and ui.modal=="legacy_setup","failed new run leaves old journey and unlocked selection")
 memory.failing=false;await ui.start_legacy_setup()
 check(ui.world.actions==["hero_scholar","legacy_kit"] and ui.modal=="","final confirmed run has exactly two setup events")
 check(not ui.talent_ready(),"offers shown for preview do not falsely mark talent ready before milestone")
 ui.world.kills=3;check(ui.talent_ready(),"earned tier shows static ready indicator")
 ui.build_tab="talent";ui.open_build();var offers=ui.world.talent_view().offers
 check(offers.size()==3 and ui.build_tabs().size()==3,"real milestone opens three fixed offers and three B tabs")
 var ids=[]
 for row in offers:ids.append(row.id)
 ui.open_build();var repeat=[]
 for row in ui.choices:repeat.append(row.id)
 check(ids==repeat,"closing/reopening cannot reroll seeded offer")
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(800,280);writes=memory.writes
 await ui._unhandled_input(click)
 check(ui.talent_selection==str(offers[0].id) and memory.writes==writes,"clicking talent card only highlights without writing")
 ui.talent_selection=str(offers[0].id);writes=memory.writes
 check(memory.writes==writes and ui.world.talent_view().chosen.is_empty(),"highlight alone never commits talent")
 memory.failing=true;await ui.confirm_talent()
 check(ui.world.talent_view().chosen.is_empty(),"failed talent persistence leaves actual choice pending")
 memory.failing=false;await ui.confirm_talent()
 check(ui.world.talent_view().chosen.size()==1,"explicit confirmation chooses one talent")
 writes=memory.writes;await ui.confirm_talent();check(memory.writes==writes,"repeat confirm cannot choose second talent same tier")
 ui.queue_redraw();await process_frame
 var armed=W.new_run(6);armed.act("hero_ranger");armed.act("legacy_none");armed.kills=3;armed.act("skill_use");ui.world=armed;ui.open_build();ui.talent_selection=str(ui.choices[0].id)
 writes=memory.writes;await ui.confirm_talent()
 check(memory.writes==writes and ui.world.talent_view().chosen.is_empty() and not ui.modal_notice.is_empty(),"prepared skill blocks talent with actual reason")
 ui.world.ended=true;memory.failing=true;await ui.settle_run()
 check(ui.modal=="finish_retry" and ui.settlement.is_empty(),"failed settlement displays no unconfirmed points")
 memory.failing=false;await ui.settle_run()
 check(ui.modal=="ended" and "新增 1 点" in ui.settlement_text() and ui.legacy_points==3,"only confirmed finish receipt displays actual award and current balance")
 ui.ingest_profile({"ok":true,"points":1,"settlement":ui.settlement,"profile":ui.profile})
 check("结算时余额 3" in ui.settlement_text() and "当前可用 1" in ui.settlement_text(),"receipt balance and current spendable points are separate")
 ui.world=load("res://scripts/endless_world_v20.gd").new_run(5)
 check("旧规则旅程不发轮回点" in ui.settlement_text(),"old version cannot imply it earns new points")
 await ui.start_run(99,21);ui.hero_setup_selection="ranger";await ui.confirm_hero_setup();ui.queue_redraw();await process_frame
 click.position=Vector2(300,220);writes=memory.writes;await ui._unhandled_input(click)
 check(ui.legacy_selection=="none" and memory.writes==writes,"legacy card selection never silently pays points")
 var back=InputEventKey.new();back.pressed=true;back.keycode=KEY_ESCAPE;await ui._unhandled_input(back)
 check(ui.modal=="hero_setup" and ui.hero_setup_seed==99,"back to heroes preserves seed and does not reroll draft")
 ui.queue_free();await process_frame
 print("PROGRESS UI: %s (%d checks; fixtures, not real store or balance proof)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
