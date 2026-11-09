extends SceneTree
# UI state fixtures deliberately supply funds/stages; core tests cover legal full routes.
const V9=preload("res://scripts/endless_world_v9.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var failing=false
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit(_s,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  writes+=1;revision+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame
 ui.world=V9.new_run(20);ui.world.pos=Vector2i(2,1);ui.world.gold=40;ui.modal=""
 ui.open_supply_panel("encounter");var previous=ui.world.save_data()
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_TAB
 await ui._unhandled_input(key)
 check(ui.modal=="contract" and ui.choices.size()==3,"Tab opens order alternatives without replacing encounter")
 check(ui.contract_heading(ui.world.contract_view()).contains("尚未接单"),"offer clearly not accepted")
 check("12金" in ui.contract_body(ui.world.contract_view()) and "8金币" in ui.contract_body(ui.world.contract_view()),"body discloses refundable deposit and later optional price")
 check(memory.writes==0 and ui.world.save_data()==previous,"tab preview cannot accept or charge")
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(200,120)
 await ui._unhandled_input(click);check(ui.modal=="encounter","mouse encounter tab works")
 click.position=Vector2(500,120);await ui._unhandled_input(click)
 check(ui.modal=="contract" and memory.writes==0,"mouse contract tab is read-only")
 ui.queue_redraw();await process_frame
 await ui.transact("act","job_accept")
 check(ui.modal=="contract" and ui.world.gold==28,"accept deducts only twelve and keeps order panel")
 check(ui.contract_heading(ui.world.contract_view()).contains("已接"),"active label distinguishes accepted state")
 var accepted=ui.world.save_data();var writes=memory.writes
 await ui.transact("act","job_cancel")
 check(ui.modal=="confirm_job" and memory.writes==writes and ui.world.save_data()==accepted,"cancel opens second confirmation without writes")
 key.keycode=KEY_ESCAPE;await ui._unhandled_input(key)
 check(ui.world.contract_view().phase=="active" and ui.world.gold==28,"Escape preserves active order and deposit")
 ui.open_supply_panel("contract");await ui.transact("act","job_cancel")
 memory.failing=true;await ui.confirm_modal()
 check(ui.world.contract_view().phase=="active" and ui.world.gold==28,"failed confirmed cancellation save does not alter shown contract")
 memory.failing=false;ui.open_supply_panel("contract");await ui.transact("act","job_cancel");await ui.confirm_modal()
 check(ui.world.contract_view().phase=="closed" and ui.world.gold==28,"confirmed cancellation loses deposited amount only once")
 # New fixture: source-floor completion, including full inventory before refund.
 ui.world=V9.new_run(20);ui.world.pos=Vector2i(2,1);ui.world.gold=40;ui.modal=""
 await ui.transact("act","job_accept")
 for point in ui.world.contract_view().target_points:ui.world._consume(point)
 ui.world.items.ward=9;ui.world.items.pierce=9;ui.open_supply_panel("contract")
 check(ui.choices.size()==1 and ui.choices[0].id=="job_refund","completion offers refund despite full inventory")
 await ui.transact("act","job_refund")
 check(ui.world.gold==40 and ui.world.contract_view().phase=="voucher","refund is returned deposit, not extra gold")
 check(ui.contract_heading(ui.world.contract_view()).contains("押金已退"),"voucher stage clearly says already refunded")
 var voucher=ui.world.save_data();writes=memory.writes
 await ui.transact("act","job_ward")
 check(ui.world.gold==40 and ui.world.save_data()==voucher and memory.writes==writes,"full inventory exchange keeps money and voucher")
 ui.world.floor_number=2;ui.world.pos=Vector2i(12,13);ui.open_supply_panel("contract")
 check(ui.choices.is_empty() and ui.world.contract_view().source==1,"different floor shows source but offers no redemption")
 ui.queue_redraw();await process_frame
 ui.world.floor_number=1;ui.world.pos=Vector2i(2,1);ui.open_supply_panel("contract")
 await ui.transact("act","job_decline")
 check(ui.world.gold==40 and ui.world.contract_view().phase=="closed","decline voucher is free after refund")
 ui.world=load("res://scripts/endless_world_v8.gd").new_run(20);ui.modal="";ui.open_supply_panel("contract")
 check(ui.modal=="" and "旧规则" in ui.notice,"old journey never pretends contracts exist")
 ui.queue_free();await process_frame
 print("ENDLESS CONTRACT UI: %s (%d checks; UI stage fixtures, not legal route proof)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
