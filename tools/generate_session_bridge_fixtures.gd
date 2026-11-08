extends SceneTree
const World=preload("res://scripts/world.gd")
func _initialize():
 var first=World.new(0,2,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","safe")
 var second=World.new(42,2,"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","safe")
 var before=first.save_data().duplicate(true)
 assert(first.step(Vector2i.RIGHT))
 var payload={"source":"Actual current World constructors and one legal step; synthetic test only","first":before,"first_after_step":first.save_data().duplicate(true),"second":second.save_data().duplicate(true)}
 var second_ended=World.from_snapshot(second.save_data().duplicate(true));assert(second_ended.finish_run("withdrawn"));payload.second_ended=second_ended.save_data().duplicate(true)
 var withdrawn=World.from_snapshot(first.save_data().duplicate(true));assert(withdrawn.finish_run("withdrawn"));payload.withdrawn=withdrawn.save_data().duplicate(true)
 var winner=World.new(0,2,"dddddddddddddddddddddddddddddddd","safe")
 var route=load("res://scripts/generation.gd").generate(0,World.MAPS).validation.route
 for c in route:assert(winner.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]))
 payload.winner_fresh=World.new(0,2,winner.run_id,"safe").save_data().duplicate(true);payload.chapter1_base=winner.save_data().duplicate(true)
 var ended=World.from_snapshot(winner.save_data().duplicate(true));assert(ended.finish_run("chapter1"));payload.chapter1_ended=ended.save_data().duplicate(true)
 assert(winner.action("expedition"))
 for c in load("res://scripts/expedition.gd").generate(0).validation.route:assert(winner.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]))
 payload.victory_base=winner.save_data().duplicate(true);assert(winner.finish_run("victory"));payload.victory_ended=winner.save_data().duplicate(true)
 var risk=World.new(0,2,"rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr","risk")
 payload.next_fresh=World.new(17,2,"tttttttttttttttttttttttttttttttt","safe").save_data().duplicate(true)
 payload.risk_fresh=risk.save_data().duplicate(true)
 for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":assert(risk.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]))
 payload.risk_base=risk.save_data().duplicate(true);payload.risk_delta=[-1,0]
 assert(risk.lethal_fight(Vector2i.LEFT));payload.risk_dead=risk.save_data().duplicate(true)
 payload.schema13_active=JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema13-active-store.json")).payload)
 payload.schema13_archived=JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema13-archived-store.json")).payload)
 var file=FileAccess.open("res://tools/session_bridge_fixtures.json",FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close();quit()
