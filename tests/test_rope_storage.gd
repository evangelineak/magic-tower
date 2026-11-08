extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const Clocked=preload("res://tests/clocked_journey_store.gd")
const Session=preload("res://scripts/session.gd")
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const DIR={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;push_error(label)
func nonce():return Crypto.new().generate_random_bytes(16).hex_encode()
func _init():call_deferred("run")
func run():
 for label in ["active","death","pending","allocated"]:
  var old_store=Store.new("user://journeys-v1-test-rope-old-"+nonce())
  DirAccess.make_dir_recursive_absolute(old_store.native.root)
  DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/rope_schema18-"+label+"-store.json"),old_store.native.root.path_join("store.json"))
  old_store.native=Clocked.new(old_store.path)
  var loaded=await old_store.read_active()
  check(loaded.ok,"genuine schema18 "+label+" reads")
  if not loaded.ok:quit(1);return
  check(loaded.snapshot.version==19 and loaded.snapshot.rope=={"version":0,"state":"off"},"old18 never receives rope "+label)
  if label=="active":
   var previous=old_store.native.read().data.runs[loaded.run_id].last_op
   var retry=await old_store.commit_run(int(previous.expected_slot),int(previous.expected_revision),loaded.run_id,loaded.snapshot,previous.request_id)
   check(retry.ok and retry.revision==loaded.revision and retry.snapshot==loaded.snapshot,"old18 ACK retry accepts exact canonical19 payload without advancing")
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rope_schema18-"+label+".json"))
  for field in old:
   if field!="version":check(JSON.parse_string(JSON.stringify(loaded.snapshot[field]))==old[field],"old18 preserves "+label+" "+field)
 var store=Store.new("user://journeys-v1-test-rope-"+nonce())
 var session=Session.new(store)
 var result=await session.new_run(1)
 check(result.ok,"production native new run")
 if not result.ok:quit(1);return
 check(session.world.rope=={"version":1,"state":"ready"},"layout2 birth ready")
 var w=W.from_snapshot(session.world.save_data())
 for key in G.generate(1,W.MAPS).validation.route:check(w.step(DIR[key]),"legal first chapter step")
 check(w.action("expedition"),"legitimate continuation")
 for key in E.generate(1).witness:
  if w.rope_preview().available:break
  check(w.step(DIR[key]),"legal approach to rope")
 check(w.rope_preview().available,"real route reaches usable rope before H")
 result=await store.commit_run(session.slot,session.revision,w.run_id,w.save_data(),nonce())
 check(result.ok and (await session.open_current()).ok,"persist actual ready crossing position")
 var before=session.world.save_data().duplicate(true);var original_store=store.native.read().data
 for rope in [{"version":true,"state":"ready"},{"version":1.5,"state":"ready"},{"version":1,"state":"off"},{"version":1,"state":"ready","bonus":1},{"version":0,"state":"ready"}]:
  var bad=before.duplicate(true);bad.rope=rope
  check(not (await store.commit_run(session.slot,session.revision,w.run_id,bad,nonce())).ok and store.native.read().data==original_store,"malformed rope atomic refusal")
 var graft=before.duplicate(true);graft.rope={"version":0,"state":"off"}
 check(W.from_snapshot(graft)!=null,"off is a valid old birth but not this run")
 check(not (await store.commit_run(session.slot,session.revision,w.run_id,graft,nonce())).ok and store.native.read().data==original_store,"native rejects birth disabling")
 session.history.append(graft)
 check(not (await session.undo()).ok and session.world.save_data()==before,"Session history cannot change rope birth")
 session.history.clear()
 store.test_drop_next_ack=true
 result=await session.action("rope_cross")
 check(not result.ok and not result.has("effect") and session.world.save_data()==before,"lost ACK preserves visible pre-crossing state")
 var durable=store.native.read().data
 result=await session.retry_pending()
 check(result.ok and result.effect.input=="rope_cross" and store.native.read().data==durable,"retry acknowledges same durable crossing without second consumption")
 var spent=session.world.save_data().duplicate(true)
 check(spent.rope.state=="spent" and spent.focus==before.focus-1 and spent.moves==before.moves+1,"one focus and one movement spent")
 for key in before:
  if key not in ["x","y","focus","moves","rope","skill_armed"]:check(before[key]==spent[key],"crossing leaves unrelated field unchanged: "+key)
 check(not (await session.action("rope_cross")).ok,"spent rope cannot repeat")
 check(not (await session.retry_pending()).has("effect"),"retry cannot replay effect after success")
 check((await session.undo()).ok and session.world.save_data()==before,"Undo restores ready rope focus and position as new CAS revision")
 check((await session.open_current()).ok and session.world.save_data()==before,"reload restores exact Undo state")
 var new_store=Store.new("user://journeys-v1-test-rope-layout1-"+nonce())
 result=await new_store.create_run(1,1,"safe",false,nonce())
 check(result.ok and result.snapshot.rope=={"version":0,"state":"off"},"new legacy layout has no rope")
 print("ROPE STORAGE: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
