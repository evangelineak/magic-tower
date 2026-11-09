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
func need(r,label):
 if r.get("ok",false):return true
 check(false,label+str(r));quit(1);return false
func prepared(label):
 var store=Store.new("user://journeys-v1-test-points-"+nonce())
 DirAccess.make_dir_recursive_absolute(store.native.root)
 DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/schema16-"+label+"-store.json"),store.native.root.path_join("store.json"))
 store.native=Clocked.new(store.path)
 return store
func _initialize():call_deferred("run")
func run():
 for label in ["active","death"]:
  var s=prepared(label);var r=await s.read_active()
  if not need(r,"real16 migration "+label):return
  check(r.snapshot.version==19 and r.snapshot.legacy_points=={"version":0,"capacity":0,"study":0,"reserve":0} and r.snapshot.legacy_reserves==0,"old16 no midrun point grants")
  var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16-"+label+".json"))
  for key in old:
   if key!="version":check(JSON.parse_string(JSON.stringify(r.snapshot[key]))==old[key],"old16 keeps "+label+" "+key)
 var legacy=prepared("pending");var pending=await legacy.read_active()
 if not need(pending,"old pending"):return
 var old_request=nonce()
 var legacy_chosen=await legacy.choose_strategy(pending.slot,pending.revision,pending.run_id,"none",old_request,{})
 if not need(legacy_chosen,"oldpending zero choice"):return
 var retry=await legacy.choose_strategy(pending.slot,pending.revision,pending.run_id,"none",old_request,{"study":0,"reserve":0})
 check(retry.ok and retry.revision==legacy_chosen.revision and retry.snapshot.legacy_points.version==0,"oldpending accepts zero and empty allocation equals explicit zero retry")
 var s=prepared("death");var old=await s.read_active()
 if not need(old,"ledger"):return
 var born=await s.create_run(0,2,"risk",true,nonce())
 if not need(born,"new born"):return
 check(born.snapshot.legacy_points=={"version":1,"capacity":2,"study":0,"reserve":0} and born.snapshot.legacy_reserves==0,"capacity uses actual birth pool tier5")
 var original=s.native.read().data
 for allocation in [{"study":2,"reserve":1},{"study":-1,"reserve":0},{"study":true,"reserve":0},{"study":0.5,"reserve":0},{"study":1,"reserve":0,"extra":0}]:
  var bad=await s.choose_strategy(born.slot,born.revision,born.run_id,"none",nonce(),allocation)
  check(not bad.ok and s.native.read().data==original,"invalid allocation atomic "+str(allocation))
 var alloc={"study":1,"reserve":1};var request=nonce()
 s.native.test_fail_at="after_choice"
 var failed=await s.choose_strategy(born.slot,born.revision,born.run_id,"none",request,alloc)
 check(not failed.ok and s.native.read().data==original,"allocation and strategy abort together")
 s.native.test_fail_at="";s.test_drop_next_ack=true
 var lost=await s.choose_strategy(born.slot,born.revision,born.run_id,"none",request,alloc)
 check(not lost.ok and lost.retryable,"lost acknowledgement retryable")
 var chosen=await s.choose_strategy(born.slot,born.revision,born.run_id,"none",request,alloc)
 if not need(chosen,"retry selection"):return
 check(chosen.revision==born.revision+1 and chosen.slot==born.slot and chosen.profile==born.profile and chosen.snapshot.legacy_points.study==1 and chosen.snapshot.legacy_reserves==1,"one atomic allocation including none without consuming profile")
 var current=s.native.read().data
 var bad=await s.choose_strategy(born.slot,born.revision,born.run_id,"none",request,{"study":2,"reserve":0})
 check(not bad.ok and s.native.read().data==current,"same nonce cannot swap allocation")
 var forged=chosen.snapshot.duplicate(true);forged.legacy_points.study=0
 bad=await s.commit_run(chosen.slot,chosen.revision,chosen.run_id,forged,nonce())
 check(not bad.ok and s.native.read().data==current,"ordinary save cannot reallocate points")
 var w=World.from_snapshot(chosen.snapshot)
 check(w.focus<w.focus_cap,"new hero has room for one reserve focus")
 var focus=w.focus
 check(w.action("legacy_focus") and w.focus==focus+1 and w.legacy_reserves==0,"actual reserve consumption restores focus")
 var saved=await s.commit_run(chosen.slot,chosen.revision,chosen.run_id,w.save_data(),nonce())
 if not need(saved,"commit actual reserve use"):return
 check(saved.snapshot.legacy_points==chosen.snapshot.legacy_points and saved.snapshot.legacy_reserves==0,"remaining dynamic, birth allocation immutable")
 var undone=await s.commit_run(saved.slot,saved.revision,saved.run_id,chosen.snapshot,nonce())
 if not need(undone,"undo reserve"):return
 check(undone.snapshot==chosen.snapshot,"real undo restores remaining without reallocating")
 var restarted=await s.read_active()
 check(restarted.ok and restarted.snapshot==chosen.snapshot,"restart reads complete allocation and remaining")
 w=World.from_snapshot(undone.snapshot)
 var directions={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
 for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":check(w.step(directions[c]),"real risk route with reserved supply "+c)
 var approached=await s.commit_run(undone.slot,undone.revision,undone.run_id,w.save_data(),nonce())
 if not need(approached,"risk approach"):return
 var dead=await s.settle_death(approached.slot,approached.revision,approached.run_id,Vector2i.LEFT,nonce())
 if not need(dead,"death with unused supply"):return
 check(dead.snapshot.legacy_reserves==1 and dead.snapshot.legacy_points==chosen.snapshot.legacy_points,"atomic death retains unused reserve and allocated study")
 var read_dead=await s.read_active()
 check(read_dead.ok and read_dead.snapshot==dead.snapshot,"full death replay retains paid allocation without consuming reserve")
 print("LEGACY POINTS STORAGE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
