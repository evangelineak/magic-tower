extends SceneTree
const W=preload("res://scripts/world.gd")
const Fixture=preload("res://tests/ui_fixture.gd")
var checks=0
var failures=0
func check(v,label):
 checks+=1
 if not v:failures+=1;push_error(label)
func row(rows,id):
 for r in rows:
  if r.id==id:return r
 return {}
func _initialize():call_deferred("run")
func run():
 var w=W.new(1)
 var before=w.save_data().duplicate(true)
 var initial=w.exploration_goals()
 for i in range(5):check(w.exploration_goals()==initial,"stable repeated read")
 check(w.save_data()==before,"reading all goals leaves complete World unchanged")
 check(row(initial,"vault").is_empty() and row(initial,"mira").is_empty() and row(initial,"survey").is_empty(),"unseen unaccepted goals not revealed")
 # Deliberately alter only hidden-map test copies. Outputs must not depend on
 # undiscovered treasure/guard coordinates; these are not player save fixtures.
 var hidden=W.new(1)
 hidden.floors[2][8][2]="T";hidden.floors[2][1][8]="I"
 check(hidden.exploration_goals()==initial,"hidden map details do not affect initial visible goals")
 w.quest_state=1
 var accepted=row(w.exploration_goals(),"survey")
 check(not accepted.is_empty() and accepted.pos==Vector2i(-1,-1),"accepted survey conveys destination but hides unseen location")
 w.rescue_state=1
 var rescue=row(w.exploration_goals(),"mira")
 check(not rescue.is_empty() and rescue.pos==Vector2i(-1,-1),"accepted search conceals unseen Mira coordinate")
 w.won=true
 for r in w.exploration_goals():check(r.status=="First chapter complete; exploration is paused.","won firstchapter goals explicitly paused")
 w.expedition_started=true
 check(w.exploration_goals().is_empty(),"final victory has no active unfinished goals")
 w.won=false;w.expedition_started=false;w.ended_reason="retired"
 check(w.exploration_goals().is_empty(),"archived journey shows no actionable goals")
 var scene=load("res://main.tscn").instantiate();Fixture.attach(scene);root.add_child(scene)
 await process_frame
 await Fixture.bind(scene,W.new(1));scene.growth=false;scene.language="en"
 var saved=Fixture.snapshot(scene);var world_state=scene.world.save_data().duplicate(true);var history=scene.history.duplicate(true);var sound=scene.sound_event_count
 scene.journal=true
 for i in range(3):scene.toggle_target(0);scene.return_target_rows();scene.pinned_target_text()
 scene.session.read_only=true
 scene.toggle_target(0);scene.pinned_target_text()
 check(Fixture.snapshot(scene)==saved and scene.world.save_data()==world_state and scene.history==history and scene.sound_event_count==sound,"pinning and readonly inspection do not write/move/reward/sound")
 # Render-only controlled context, no save or gameplay claim: remove Q exactly
 # as calibration does and verify the independent cargo overlay predicate.
 scene.world.floor_index=4;scene.world.floor_seen=[true,true,true,true,true]
 check(scene.crown_cargo_marker(Vector2i(1,3)),"crown marker before calibration removal")
 scene.world.floors[4][3][1]="."
 check(scene.crown_cargo_marker(Vector2i(1,3)),"crown marker survives Q consumed")
 check(not scene.crown_cargo_marker(Vector2i(2,3)),"cargo overlay fixed to real delivery point")
 scene.queue_free();await process_frame
 print("EXPLORATION INDEPENDENT REVIEW: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
