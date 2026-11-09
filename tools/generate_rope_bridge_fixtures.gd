extends SceneTree
const W=preload("res://scripts/world.gd")
const S=preload("res://scripts/legacy_strategy.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const DIR={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
func _init():
 # The browser's preceding real chapter settlement earns this exact pool.
 var w=W.new(1,2,"rope_browser_fixture_0001","safe",false,S.pool_for_milestones([3,5]))
 var result={"fresh":w.save_data().duplicate(true)}
 assert(w.choose_strategy("none"))
 for key in G.generate(1,W.MAPS).validation.route:assert(w.step(DIR[key]))
 assert(w.action("expedition"))
 for key in E.generate(1).witness:
  if w.rope_preview().available:break
  assert(w.step(DIR[key]))
 assert(w.rope_preview().available)
 result.before=w.save_data().duplicate(true)
 assert(w.action("rope_cross"));result.after=w.save_data().duplicate(true)
 var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rope_schema18-active.json"))
 var upgraded=W.from_snapshot(old);assert(upgraded!=null)
 result.old_upgraded=upgraded.save_data().duplicate(true)
 var out=FileAccess.open("res://tools/rope_bridge_fixtures.json",FileAccess.WRITE)
 out.store_string(JSON.stringify(result));out.close()
 print("ROPE BRIDGE VECTORS: actual legal route + genuine18 canonical migration")
 quit()
