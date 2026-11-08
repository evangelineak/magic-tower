extends SceneTree
const World=preload("res://scripts/world.gd")
func _initialize():
 var first=World.new(0,2,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","safe")
 var second=World.new(42,2,"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","safe")
 var before=first.save_data().duplicate(true)
 assert(first.step(Vector2i.RIGHT))
 var payload={"source":"Actual schema13 World constructors and one legal step; synthetic test only","first":before,"first_after_step":first.save_data(),"second":second.save_data()}
 var file=FileAccess.open("res://tools/session_bridge_fixtures.json",FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close();quit()
