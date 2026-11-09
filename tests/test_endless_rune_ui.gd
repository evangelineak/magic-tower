extends SceneTree
# UI fixtures grant funding; core suite separately tests legal economic paths.
const W=preload("res://scripts/endless_world_v13.gd")
const G=preload("res://scripts/endless_generation_v13.gd")
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
 await process_frame;ui.set_process(false)
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT
 var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_ESCAPE
 for kind in ["shock","silence"]:
  var seed_value=0
  for candidate in 200:
   if G.rune_info(candidate,1).kind==kind:seed_value=candidate;break
  ui.world=W.new_run(seed_value);ui.world.gold=100;ui.modal="";ui.camera=Vector2i.ZERO
  var data=ui.rune_data();var before=ui.world.save_data();var writes=memory.writes
  check(data.kind==kind and data.available,"rune fixture has a meaningful activation")
  check(ui.rune_hit_rect().size==Vector2(28,28),"entry badge visible without occupying a new tile")
  click.position=ui.rune_hit_rect().get_center();await ui._unhandled_input(click)
  check(ui.modal=="rune" and memory.writes==writes and ui.world.save_data()==before,"badge opens read-only comparison, no payment")
  check(data.before_routes.size()==2 and data.after_routes.size()==2,"both route forecasts available")
  check("不能撤销" in ui.rune_tooltip(data) and "%d金币" % data.price in ui.rune_tooltip(data),"tooltip discloses exact price and irreversibility")
  ui.queue_redraw();await process_frame
  await ui._unhandled_input(key)
  check(ui.modal=="" and ui.world.gold==100,"Escape closes without activation")
  ui.open_rune();memory.failing=true;await ui.confirm_modal()
  check(not ui.world.runes.get(1,false) and ui.world.gold==100 and ui.modal=="rune","failed activation persistence leaves original world and preview")
  memory.failing=false;await ui.confirm_modal()
  check(ui.world.runes.get(1,false) and ui.world.gold==100-data.price,"explicit confirmation pays exact once-only cost")
  check(ui.modal=="" and ui.rune_data().active,"saved effect updates badge and closes confirmation")
  writes=memory.writes;ui.open_rune();await ui.confirm_modal()
  check(memory.writes==writes and "本层已生效" in ui.rune_data().reason or (memory.writes==writes and "本层铭文已生效" in ui.rune_data().reason),"active rune cannot charge twice")
  ui.queue_redraw();await process_frame
 ui.world=W.new_run(0);ui.world.gold=100;ui.modal="";ui.open_rune();ui.world.pos+=Vector2i.RIGHT
 var writes=memory.writes;await ui.confirm_modal()
 check(memory.writes==writes and "已变化" in ui.modal_notice,"position changed after preview requires fresh confirmation")
 ui.modal="";ui.world.pos=Vector2i(13,13);ui.open_rune();await ui.confirm_modal()
 check(memory.writes==writes and not ui.rune_data().available,"remote inspection cannot activate at exit")
 ui.modal="";ui.world=W.new_run(0);ui.world.gold=0;ui.open_rune();await ui.confirm_modal()
 check(memory.writes==writes and "金币" in ui.modal_notice,"unfunded preview cannot spend")
 ui.modal="";ui.camera=Vector2i(4,4)
 check(ui.rune_hit_rect().size==Vector2.ZERO,"badge not left floating after entry scrolls out of view")
 ui.world=load("res://scripts/endless_world_v12.gd").new_run(0);ui.camera=Vector2i.ZERO
 check(ui.rune_hit_rect().size==Vector2.ZERO,"old journey does not acquire rune badge")
 var long_text="\n".join(Array(range(16)).map(func(n):return "完整机制说明第%d行" % n))
 var rect=ui.tooltip_layout(long_text,Vector2(1260,790))
 check(rect.end.y<=780 and rect.end.x<=1260 and rect.position.y>=70,"sixteen-line tooltip fits logical viewport")
 ui.queue_free();await process_frame
 print("ENDLESS RUNE UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
