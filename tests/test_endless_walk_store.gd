extends SceneTree
const Store=preload("res://scripts/endless_store.gd")
const World=preload("res://scripts/endless_world.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 for version in [10,11,12,13,14,15]:await run_version(version)
 print("ENDLESS WALK STORE: %s (%d checks)"%["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
func run_version(version:int):
 var path="/tmp/tower-walk-store-"+str(Time.get_ticks_usec())+".json"
 var store=Store.new(path);var w=World.new_run(0,version)
 var r=await store.start(w.save_data(),0)
 for code in ["R","cargo_use","R","R","R"]:
  check(w.apply_code(code).changed,"legal setup "+code)
  r=await store.commit(w.save_data(),r.revision)
  check(r.ok,"persist legal setup")
 var original=w.save_data();var original_bytes=FileAccess.get_file_as_string(path)
 var candidate=w.clone();var view=candidate.camp_return_view();var moved=candidate.return_to_camp()
 check(view.available and moved.changed and moved.steps==3,"real three-step safe return")
 var target=candidate.save_data()
 check((await store.commit(target,r.revision)).status=="invalid","ordinary commit is still single event")
 check((await store.commit_walk(original,r.revision)).status=="invalid","zero step batch rejected")
 var forged=w.clone();forged.apply_code("L");forged.apply_code("R")
 check((await store.commit_walk(forged.save_data(),r.revision)).status=="invalid","legal arbitrary walk is not camp return")
 var extra=candidate.clone();extra.apply_code("R")
 check((await store.commit_walk(extra.save_data(),r.revision)).status=="invalid","camp return plus extra move rejected")
 var old=target.duplicate(true);old.version=9
 check((await store.commit_walk(old,r.revision)).status=="invalid","v9 cannot use batch API")
 for target_version in [10,11,12,13,14,15]:
  if target_version==version:continue
  var switched=target.duplicate(true);switched.version=target_version
  check((await store.commit_walk(switched,r.revision)).status=="invalid","walk cannot switch supported rules in same run")
 var malformed=original.duplicate(true);malformed.actions.append("cargo_use")
 check((await store.commit_walk(malformed,r.revision)).status=="invalid","non-direction suffix rejected")
 check(FileAccess.get_file_as_string(path)==original_bytes,"all rejected batches preserve bytes")
 store.test_fail_write=true
 check((await store.commit_walk(target,r.revision)).status=="io_error","atomic write failure surfaced")
 check(FileAccess.get_file_as_string(path)==original_bytes,"failed safe batch leaves old bytes")
 store.test_fail_write=false
 var old_revision:int=r.revision
 r=await store.commit_walk(target,old_revision)
 check(r.ok and r.revision==old_revision+1 and r.snapshot==target,"safe three-step batch commits exactly one revision")
 check((await Store.new(path).commit_walk(target,old_revision)).revision==r.revision,"lost acknowledgment retry is idempotent across instances")
 check((await Store.new(path).commit_walk(forged.save_data(),old_revision)).status=="conflict","competing stale batch conflicts")
 var reread=await Store.new(path).read()
 check(reread.ok and World.from_data(reread.snapshot).pos==candidate.pos,"real native file restores exact camp location")
 check(reread.snapshot.actions.slice(original.actions.size())==["L","L","L"],"save contains expanded directions, no macro")
 var huge=target.duplicate(true)
 for i in 225:huge.actions.append("R")
 check((await store.commit_walk(huge,r.revision)).status=="invalid","225-step suffix rejected")
 check((await store.commit_walk(target,r.revision)).status=="invalid","already-at-camp request is not a new write")
 DirAccess.remove_absolute(path)
