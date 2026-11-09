extends SceneTree
# UI state fixtures supply gold. Core suite proves economy and battle paths.
const W=preload("res://scripts/endless_world_v11.gd")
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
 ui.world=W.new_run(20);ui.world.pos=Vector2i(2,1);ui.world.gold=100;ui.modal=""
 ui.open_supply_panel("items");var previous=ui.world.save_data()
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_TAB
 await ui._unhandled_input(key)
 check(ui.modal=="gear" and ui.choices.size()==2,"I Tab opens gear purchase choices")
 check(ui.world.save_data()==previous and memory.writes==0,"tab preview costs nothing")
 check("40金币" in ui.gear_entry_status(ui.world.gear_view().entries[0]),"unowned card says exact one-time price")
 ui.queue_redraw();await process_frame
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=Vector2(200,120)
 await ui._unhandled_input(click);check(ui.modal=="items","mouse returns to consumables")
 click.position=Vector2(500,120);await ui._unhandled_input(click);check(ui.modal=="gear","mouse opens persistent equipment")
 memory.failing=true;await ui.transact("act","buy_cloak")
 check(ui.world.gold==100 and not ui.world.owned_gear.cloak,"failed save charges no visible gold or ownership")
 memory.failing=false;await ui.transact("act","buy_cloak")
 check(ui.modal=="gear" and ui.world.gold==60 and ui.world.gear=="","purchase does not automatically equip")
 var writes=memory.writes;await ui.transact("act","buy_cloak")
 check(ui.world.gold==60 and memory.writes==writes,"repeat purchase cannot charge again")
 var hp=ui.world.hp;var base_attack=ui.world.atk
 await ui.transact("act","gear_cloak")
 check(ui.world.gear=="cloak" and ui.world.gold==60 and ui.world.hp==hp,"equipping is free and not healing")
 check(ui.world.gear_view().effective_atk==base_attack-2 and ui.world.atk==base_attack,"combat penalty distinct from permanent attack")
 check(ui.world.gear_view().effective_def==maxi(0,ui.world.defense-1),"cloak defense cost appears in real combat display")
 check("防御-1" in str(ui.world.gear_view().entries[0].effects),"cloak card discloses defensive drawback")
 check("已穿戴" in ui.gear_entry_status(ui.world.gear_view().entries[0]),"card marks equipped item")
 ui.queue_redraw();await process_frame
 await ui.transact("act","buy_lens")
 check(ui.world.gear=="cloak" and ui.world.gold==20,"second purchase also does not switch gear")
 await ui.transact("act","gear_lens")
 check(ui.world.gear=="lens" and ui.world.gold==20 and ui.world.gear_view().effective_def==ui.world.defense-3,"one-slot switch is free and shows defense penalty")
 ui.queue_redraw();await process_frame
 await ui.transact("act","gear_none")
 check(ui.world.gear=="" and ui.world.combat_attack()==base_attack,"unarmed option restores combat stats without changing base")
 ui.world.pos=Vector2i(13,13);ui.open_supply_panel("gear")
 check(ui.choices.is_empty() and "查看" in ui.world.gear_view().status,"remote gear preview cannot buy or switch")
 previous=ui.world.save_data();await ui.transact("act","gear_cloak")
 check(ui.world.save_data()==previous,"remote equip command rejected")
 key.keycode=KEY_ESCAPE;await ui._unhandled_input(key);check(ui.modal=="","Escape closes gear without action")
 ui.world=load("res://scripts/endless_world_v10.gd").new_run(20);ui.open_supply_panel("items")
 key.keycode=KEY_TAB;await ui._unhandled_input(key)
 check(ui.modal=="items","legacy I remains consumables-only")
 ui.modal="";ui.open_supply_panel("gear")
 check(ui.modal=="" and "旧规则" in ui.notice,"legacy world does not pretend gear exists")
 ui.queue_free();await process_frame
 print("ENDLESS GEAR UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
