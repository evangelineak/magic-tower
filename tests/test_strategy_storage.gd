extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const World=preload("res://scripts/world.gd")
const Strategy=preload("res://scripts/legacy_strategy.gd")
const Clocked=preload("res://tests/clocked_journey_store.gd")
var checks:=0
var failures:=0
# JSON parsing turns integer-valued receipt numbers into floats. Compare every
# receipt field after the same wire normalization; never omit fields.
func same_json(a,b)->bool:return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func nonce()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
func check(value:bool,label:String):
 checks+=1
 if not value:failures+=1;push_error(label)
func need(r:Dictionary,label:String)->bool:
 if r.get("ok",false):return true
 check(false,label+str(r));quit(1);return false
func _initialize():call_deferred("run")
func prepared(label:String="death"):
 var s=Store.new("user://journeys-v1-test-strategy-"+nonce())
 DirAccess.make_dir_recursive_absolute(s.native.root)
 var copied=DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/schema14-"+label+"-store.json"),s.native.root.path_join("store.json"))
 if copied!=OK:return null
 s.native=Clocked.new(s.path)
 return s
func run():
 for label in ["active","death"]:
  var s=prepared(label);var old=await s.read_active()
  if not need(old,"old14 migration "+label):return
  check(old.snapshot.version==18 and old.snapshot.draft=={"version":0,"pool":[],"offers":[],"choice":"none"},"old14 gets no retroactive draw "+label)
  var prior=s.native.read().data
  var denied=await s.choose_strategy(old.slot,old.revision,old.run_id,"study",nonce())
  check(not denied.ok and s.native.read().data==prior,"old14 cannot claim new choice "+label)
 var s=prepared();var old=await s.read_active()
 if not need(old,"ledger setup"):return
 var profile=old.profile.duplicate(true);var pool=Strategy.pool_from_profile(profile)
 check(pool.size()==5,"actual old7F defeat ledger grants tier5 birth pool")
 var created=await s.create_run(51,2,"safe",true,nonce())
 if not need(created,"entitled create"):return
 check(created.snapshot.draft==Strategy.draft(51,pool) and created.snapshot.draft.choice=="","create derives exact pool/offers from actual ledger")
 check(created.profile==profile and created.snapshot.moves==0,"birth does not grant points or consume a move")
 var current=s.native.read().data
 var forged=World.new(52,2,nonce(),"safe").save_data()
 var wrong=s.native.create_journey(s.auth,forged,true,forged.run_id)
 check(not wrong.ok and s.native.read().data==current,"caller cannot understate or substitute entitled birth pool")
 var unauthorized=current.duplicate(true)
 unauthorized.runs[created.run_id].snapshot=World.new(51,2,created.run_id,"safe",false,Strategy.IDS).save_data()
 check(not s.native._valid(unauthorized),"read rejects birth pool exceeding current genuine ledger")
 var impostor=s.auth.duplicate(true);impostor.owner="another-tab"
 wrong=s.native.choose_strategy(created.run_id,impostor,created.revision,created.snapshot.draft.offers[0],nonce())
 check(not wrong.ok and s.native.read().data==current,"wrong writer cannot choose pending strategy")
 var candidate=created.snapshot.duplicate(true);candidate.gold+=10
 wrong=await s.commit_run(created.slot,created.revision,created.run_id,candidate,nonce())
 check(not wrong.ok and s.native.read().data==current,"pending cannot change resource fields even without moves")
 wrong=await s.settle_run(created.slot,created.revision,created.run_id,"withdrawn",nonce())
 check(not wrong.ok and s.native.read().data==current,"pending cannot finish early")
 var chosen_id=created.snapshot.draft.offers[0]
 var selected=World.from_snapshot(created.snapshot);check(selected.choose_strategy(chosen_id),"model prepares actual offered choice")
 wrong=await s.commit_run(created.slot,created.revision,created.run_id,selected.save_data(),nonce())
 check(not wrong.ok and s.native.read().data==current,"ordinary save cannot perform the choice")
 var noop=await s.commit_run(created.slot,created.revision,created.run_id,created.snapshot,nonce())
 if not need(noop,"genuinely unchanged pending save"):return
 check(noop.snapshot==created.snapshot and noop.revision==created.revision+1,"unchanged pending save allowed without auto-choice")
 current=s.native.read().data
 for invalid in ["last_gambit","unknown",""]:
  wrong=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,invalid,nonce())
  check(not wrong.ok and s.native.read().data==current,"cannot choose absent/unentitled option "+invalid)
 for fault in ["after_choice","before_rename"]:
  s.native.test_fail_at=fault
  wrong=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,chosen_id,nonce())
  s.native.test_fail_at=""
  check(not wrong.ok and s.native.read().data==current,"failed choice rolls back all state "+fault)
 var request=nonce();s.test_drop_next_ack=true
 var lost=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,chosen_id,request)
 check(not lost.ok and lost.retryable,"choice response loss remains retryable")
 var picked=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,chosen_id,request)
 if not need(picked,"choice acknowledgement retry"):return
 check(picked.snapshot==selected.save_data() and picked.slot==noop.slot and picked.revision==noop.revision+1 and picked.profile==profile,"choice commits once with exact world and unchanged ledger/slot")
 var duplicate=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,chosen_id,request)
 check(duplicate==picked,"same choice nonce does not lock or count twice")
 var reopened=Store.new(s.path);reopened.native=Clocked.new(s.path);reopened.owner=s.owner
 var read=await reopened.read_active()
 check(read.ok and read.snapshot==picked.snapshot,"chosen state survives reopening")
 current=s.native.read().data
 wrong=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,"none",request)
 check(not wrong.ok and s.native.read().data==current,"same nonce cannot change choice")
 wrong=await s.commit_run(picked.slot,picked.revision,picked.run_id,created.snapshot,nonce())
 check(not wrong.ok and s.native.read().data==current,"undo/save cannot reopen the pending draft")
 var moved=World.from_snapshot(picked.snapshot);check(moved.step(Vector2i.RIGHT),"locked choice permits real movement")
 var saved=await s.commit_run(picked.slot,picked.revision,picked.run_id,moved.save_data(),nonce())
 check(saved.ok and saved.snapshot.draft==picked.snapshot.draft,"ordinary gameplay preserves entire birth/choice snapshot")
 var replaced=await s.create_run(51,2,"risk",true,nonce())
 if not need(replaced,"explicit next risk run"):return
 check(replaced.snapshot.draft.offers==created.snapshot.draft.offers and replaced.profile==profile,"same seed and ledger do not reroll on explicit next run")
 wrong=await s.choose_strategy(noop.slot,noop.revision,noop.run_id,chosen_id,request)
 check(not wrong.ok and wrong.reason=="SUPERSEDED_OPERATION","old choice cannot reactivate abandoned run")
 var none_nonce=nonce()
 var none=await s.choose_strategy(replaced.slot,replaced.revision,replaced.run_id,"none",none_nonce)
 check(none.ok and none.snapshot.draft.choice=="none" and none.snapshot.moves==0,"explicit original build is a locked choice too")
 var next=await s.create_run(52,2,"safe",true,nonce())
 if not need(next,"replace immediately after choice"):return
 var old_none=await s.choose_strategy(replaced.slot,replaced.revision,replaced.run_id,"none",none_nonce)
 check(not old_none.ok and old_none.reason=="SUPERSEDED_OPERATION","tombstoned chosen payload cannot crash or reactivate on retry")
 # The chosen strategy is part of the full replay-verified death, not an adapter-only flag.
 var risk_store=prepared();var legacy=await risk_store.read_active()
 if not need(legacy,"chosen-death ledger setup"):return
 var risk_birth=await risk_store.create_run(0,2,"risk",true,nonce())
 if not need(risk_birth,"chosen-death birth"):return
 var studied=await risk_store.choose_strategy(risk_birth.slot,risk_birth.revision,risk_birth.run_id,"study",nonce())
 if not need(studied,"actual offered study"):return
 var risk_world=World.from_snapshot(studied.snapshot)
 for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":
  if not risk_world.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]):
   check(false,"real selected-strategy route");quit(1);return
 var risk_live=await risk_store.commit_run(studied.slot,studied.revision,studied.run_id,risk_world.save_data(),nonce())
 if not need(risk_live,"chosen-death actual route save"):return
 var expected_death=World.from_snapshot(risk_world.save_data());check(expected_death.lethal_fight(Vector2i.LEFT),"real selected study build can enter fatal fight")
 var died=await risk_store.settle_death(risk_live.slot,risk_live.revision,risk_live.run_id,Vector2i.LEFT,nonce())
 if not need(died,"chosen death settlement"):return
 check(died.snapshot==expected_death.save_data() and died.snapshot.draft.choice=="study","death snapshot and replay retain exact selected strategy")
 var read_death=await risk_store.read_active()
 check(read_death.ok and read_death.snapshot==died.snapshot and same_json(read_death.receipt,died.receipt),"chosen strategy death and receipt survive validated read")
 print("STRATEGY STORAGE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
