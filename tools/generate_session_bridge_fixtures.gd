extends SceneTree
const Strategy=preload("res://scripts/legacy_strategy.gd")
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
 var next_run=World.from_snapshot(payload.next_fresh)
 for c in load("res://scripts/generation.gd").validate(next_run.floors).route:assert(next_run.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]))
 payload.next_chapter_base=next_run.save_data().duplicate(true);assert(next_run.finish_run("chapter1"));payload.next_chapter_ended=next_run.save_data().duplicate(true)
 var draft_run=World.new(51,2,"uuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuu","safe",false,Strategy.pool_for_milestones([3,5]))
 payload.draft_fresh=draft_run.save_data().duplicate(true)
 assert(draft_run.choose_strategy(draft_run.draft.offers[0]));payload.draft_selected=draft_run.save_data().duplicate(true)
 assert(draft_run.step(Vector2i.RIGHT));payload.draft_moved=draft_run.save_data().duplicate(true)
 payload.draft_next=World.new(51,2,"vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv","risk",false,Strategy.pool_for_milestones([3,5])).save_data().duplicate(true)
 var cargo_run=World.new(0,2,"cccccccccccccccccccccccccccccccc","risk",false,Strategy.pool_for_milestones([3,5]))
 payload.cargo_fresh=cargo_run.save_data().duplicate(true)
 assert(cargo_run.choose_strategy("none"))
 assert(_walk(cargo_run,Vector2i(8,1)));payload.cargo_approach=cargo_run.save_data().duplicate(true)
 assert(cargo_run.action("cargo_ship"));payload.cargo_shipped=cargo_run.save_data().duplicate(true)
 var file=FileAccess.open("res://tools/session_bridge_fixtures.json",FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close();quit()

func _walk(w,target):
 var queue=[w.pos];var paths={w.pos:[]}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p==target:
   for delta in paths[p]:
    if not w.step(delta):return false
   return true
  for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=p+delta
   if next.x<1 or next.x>9 or next.y<1 or next.y>9 or paths.has(next):continue
   if not w.floors[w.floor_index][next.y][next.x] in [".","a","d","h","k","s","g"]:continue
   paths[next]=paths[p]+[delta];queue.append(next)
 return false
