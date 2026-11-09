extends SceneTree
# Combat-specific UI fixtures; deterministic core suite proves legal route generation.
const W=preload("res://scripts/endless_world_v12.gd")
const Art=preload("res://scripts/endless_enemy_v12_art.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit(_s,r):
  if r!=revision:return {"ok":false,"status":"conflict"}
  revision+=1;writes+=1;return read()
class ArtCanvas:
 extends Node2D
 var draws=0
 func _draw():
  for size in [16.0,24.0,40.0,64.0,128.0]:
   for token in ["t","p"]:
    assert(Art.draw_enemy(self,Vector2(100,100),token,size));draws+=1
  assert(not Art.draw_enemy(self,Vector2.ZERO,"g"))
  assert(not Art.draw_enemy(self,Vector2.ZERO,"t",NAN))
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func fixture(token:String):
 var w=W.new_run(20);w.pos=Vector2i(2,1)
 var grid:Array=[]
 for y in 15:
  var row:Array=[]
  for x in 15:row.append("#")
  grid.append(row)
 grid[1][2]=".";grid[1][3]=token;w._maps={1:grid}
 return w
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 var art=ArtCanvas.new();root.add_child(art);await process_frame
 check(art.draws>=10,"ten actual new-enemy draw callbacks")
 ui.world=fixture("t");ui.world.atk=100;ui.modal=""
 var thorn=ui.world.preview(Vector2i(3,1))
 check(thorn.reflection_damage==2 and thorn.rounds==1,"kill hit still reflects two")
 check("击杀一击" in ui.battle_mechanism_text(thorn),"result explains killing hit reflection")
 await ui.map_click(Vector2i(3,1))
 check(ui.battle.token=="t" and ui.battle.reflection_damage==2,"adjacent click preserves reflection detail in result")
 ui.queue_redraw();await process_frame
 ui.battle_time=0;ui.world=fixture("t");ui.world.atk=100;ui.world.hp=2
 var fatal=ui.world.preview(Vector2i(3,1))
 check("反伤致死" in ui.battle_mechanism_text(fatal) and "没有胜利奖励" in ui.battle_mechanism_text(fatal),"fatal reflection explicitly denies rewards")
 # A counter death must not be mislabeled as reflection death.
 check("反击致死" in ui.battle_mechanism_text({"token":"t","reflection_damage":2,"termination_reason":"counter_death"}),"distinct counter-death wording")
 ui.world=fixture("p");ui.world.atk=7;ui.world.defense=0;ui.world.armed_item="ward";ui.world.items.ward=1;ui.modal=""
 var stalled=ui.world.preview(Vector2i(3,1));var before=ui.world.save_data();var writes=memory.writes
 check(not stalled.valid and stalled.termination_reason=="regeneration_stall","regeneration fixture cannot advance")
 check("回春循环" in ui.battle_mechanism_text(stalled),"stall explanation differs from armor")
 await ui.map_click(Vector2i(3,1))
 check(memory.writes==writes and ui.world.save_data()==before and ui.world.items.ward==1,"refused looping fight does not save or consume item")
 check(ui.battle_time==0,"refused fight does not start battle animation")
 ui.world.atk=4;var armored=ui.world.preview(Vector2i(3,1))
 check("无法破防" in ui.battle_mechanism_text(armored),"zero hit not falsely labelled regeneration loop")
 ui.world=fixture("p");ui.modal="";var regen=ui.world.preview(Vector2i(3,1))
 check(regen.valid and regen.regen_total>0,"normal priest fight regenerates")
 await ui.map_click(Vector2i(3,1))
 check(ui.battle.token=="p" and "仅实际反击伤害>0" in ui.battle_mechanism_text(ui.battle),"priest result exposes conditional healing")
 ui.queue_redraw();await process_frame
 var layout=ui.tooltip_layout("\n".join(regen.lines),Vector2(1200,750))
 check(layout.end.x<=1260 and layout.end.y<=780,"mechanism preview tooltip stays onscreen")
 ui.world=fixture("p");ui.world.atk=100
 check(ui.world.preview(Vector2i(3,1)).regen_total==0,"dead priest cannot regenerate on killing blow")
 var invalid_route=ui.route_hud_text({"label":"双关：回春祭司 / 棘甲守卫","valid":false,"gold":48})
 check("无法完成战斗" in invalid_route and not "+48" in invalid_route,"route stall not mislabeled armor or promised reward")
 var long_route=ui.route_hud_text({"label":"双关：回春祭司 / 棘甲守卫","valid":true,"survivable":true,"net_damage":999999,"gold":999999})
 check(ui.font.get_string_size(long_route,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x<=468,"long route numbers fit HUD without shrinking text")
 ui.battle={"token":"t"};ui.battle_time=1.0;ui.hover=Vector2i(3,1)
 check(not ui.target_tooltips_visible(),"battle overlay suppresses all target tooltips and status outlines")
 ui.battle_time=0
 check(ui.target_tooltips_visible(),"target tooltip returns after battle overlay closes")
 ui.queue_free();art.queue_free();await process_frame
 print("ENDLESS V12 UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
