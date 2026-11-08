extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const World=preload("res://scripts/world.gd")
const Clocked=preload("res://tests/clocked_journey_store.gd")
var checks=0
var failures=0
func nonce():return Crypto.new().generate_random_bytes(16).hex_encode()
func check(value,label):
 checks+=1
 if not value:failures+=1;push_error(label)
func need(result,label):
 if result.get("ok",false):return true
 check(false,label+str(result));quit(1);return false
func _initialize():call_deferred("run")
func run():
 for label in ["active","death"]:
  var store=Store.new("user://journeys-v1-test-talent-old-"+nonce())
  DirAccess.make_dir_recursive_absolute(store.native.root)
  check(DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/schema15-"+label+"-store.json"),store.native.root.path_join("store.json"))==OK,"copy real15 "+label)
  store.native=Clocked.new(store.path)
  var loaded=await store.read_active()
  if not need(loaded,"read actual15 "+label):return
  var raw=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema15-"+label+".json"))
  check(loaded.snapshot.version==18 and loaded.snapshot.talent_draft.version==0 and loaded.snapshot.last_kill_kind=="","old15 retains legacy offer policy, no invented kill history")
  for key in raw:
   if key!="version":check(JSON.parse_string(JSON.stringify(loaded.snapshot[key]))==JSON.parse_string(JSON.stringify(raw[key])),"old15 preserved "+label+" "+key)
 var store=Store.new("user://journeys-v1-test-talent-"+nonce())
 var created=await store.create_run(0,2,"risk",false,nonce())
 if not need(created,"new schema16"):return
 check(created.snapshot.version==18 and created.snapshot.talent_draft.version==1 and created.snapshot.last_kill_kind=="","new birth draft and empty history")
 var before=store.native.read().data
 var forged=created.snapshot.duplicate(true)
 forged.talent_draft={"version":0,"offers":[["iron_skin","keen_edge","clean_finish"],["last_stand","sentinel_lore","trained_focus"],["giant_slayer","battle_medic","unbroken"]]}
 var rejected=await store.commit_run(created.slot,created.revision,created.run_id,forged,nonce())
 check(not rejected.ok and store.native.read().data==before,"ordinary commit cannot downgrade talent birth policy")
 var invalid=created.snapshot.duplicate(true)
 invalid.talent_draft.offers[0][1]=invalid.talent_draft.offers[0][0]
 rejected=await store.commit_run(created.slot,created.revision,created.run_id,invalid,nonce())
 check(not rejected.ok and store.native.read().data==before,"duplicate birth candidates rejected atomically")
 var false_birth=forged.duplicate(true)
 false_birth.run_id=nonce()
 rejected=store.native.create_journey(store.auth,false_birth,true,false_birth.run_id)
 check(not rejected.ok and store.native.read().data==before,"create cannot supply legacy candidate policy as new run")
 var world=World.from_snapshot(created.snapshot)
 var directions={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
 for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":check(world.step(directions[c]),"actual risk approach "+c)
 check(world.last_kill_kind!="","actual surviving kill records kind")
 var saved=await store.commit_run(created.slot,created.revision,created.run_id,world.save_data(),nonce())
 if not need(saved,"save actual kill history"):return
 check(saved.snapshot.talent_draft==created.snapshot.talent_draft and saved.snapshot.last_kill_kind==world.last_kill_kind,"dynamic last kill commits without redrawing birth offers")
 var dead=await store.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.LEFT,nonce())
 if not need(dead,"atomic defeat"):return
 check(dead.snapshot.last_kill_kind==saved.snapshot.last_kill_kind and dead.snapshot.talent_draft==saved.snapshot.talent_draft,"lethal attempt neither records a kill nor redraws offers")
 var readback=await store.read_active()
 if not need(readback,"death read"):return
 check(readback.snapshot==dead.snapshot,"full replay-validated terminal retains talent draft and kill history")
 print("TALENT STORAGE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
