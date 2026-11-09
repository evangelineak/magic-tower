extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
const Clocked=preload("res://tests/clocked_journey_store.gd")
const DIRS={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func nonce()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
func fresh():return Store.new("user://journeys-v1-test-death-"+nonce())
func need(r:Dictionary,label:String)->bool:
 if r.get("ok",false):return true
 check(false,label+str(r));quit(1);return false
func _initialize():call_deferred("run")
func real_risk(id:String,mode:String="risk"):
 var w=World.new(0,2,id,mode)
 for c in Generator.validate(w.floors).route:
  if not w.step(DIRS[c]):return null
 if not w.action("expedition"):return null
 var route:String=Expedition.generate(0).witness;var i=0
 while w.floor_index<6:
  if not w.step(DIRS[route[i]]):return null
  i+=1
 var path=Expedition.path_to(w.floors[w.floor_index],w.pos,Vector2i(8,2),{"hp":w.hp,"atk":w.atk,"def":w.defense})
 for d in path:
  if not w.step(d):return null
 return w if w.pos==Vector2i(8,2) else null
func run():
 for armed in [false,true]:
  var s=fresh();var created=await s.create_run(0,2,"risk",false,nonce())
  if not need(created,"risk create"):return
  var w=real_risk(created.run_id)
  check(w!=null,"real safe route reaches early W without resource injection")
  if w==null:quit(1);return
  if armed:check(w.action("arm"),"arm through real action")
  var alive=w.save_data();var expected=World.from_snapshot(alive)
  check(expected.lethal_fight(Vector2i.RIGHT),"real optional guardian fatal in current build")
  if expected.ended_reason!="death":quit(1);return
  print("REAL DEATH ROUTE armed=",armed," hp=",w.hp," moves=",w.moves," damage=",w.damage("W"))
  var saved=await s.commit_run(created.slot,created.revision,created.run_id,alive,nonce())
  if not need(saved,"risk live save"):return
  var unchanged=s.native.read().data
  var direct=await s.commit_run(saved.slot,saved.revision,saved.run_id,expected.save_data(),nonce())
  check(not direct.ok and s.native.read().data==unchanged,"ordinary save cannot bypass atomic death settlement")
  direct=await s.settle_run(saved.slot,saved.revision,saved.run_id,"defeat",nonce())
  check(not direct.ok,"generic finish cannot invent defeat")
  for delta in [Vector2i.ZERO,Vector2i(2,0),Vector2i.LEFT]:
   direct=await s.settle_death(saved.slot,saved.revision,saved.run_id,delta,nonce())
   check(not direct.ok and s.native.read().data==unchanged,"wrong target/delta leaves all state unchanged")
  for point in ["after_profile","after_archive","after_slot","before_rename"]:
   s.native.test_fail_at=point
   direct=await s.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.RIGHT,nonce())
   s.native.test_fail_at=""
   check(not direct.ok and s.native.read().data==unchanged,"death transaction rollback "+point)
  var request=nonce()
  if armed:s.native.test_fail_at="after_rename"
  else:s.test_drop_next_ack=true
  var lost=await s.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.RIGHT,request)
  s.native.test_fail_at=""
  check(not lost.ok and lost.retryable,"death ack loss retryable, including actual post-rename failure")
  var dead=await s.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.RIGHT,request)
  if not need(dead,"death retry"):return
  check(dead.status=="archived" and dead.eligible and dead.snapshot==expected.save_data(),"committed exact replay-verified death candidate")
  check(dead.receipt.summary.outcome=="defeat" and dead.receipt.summary.max_floor==7 and dead.profile.milestones.size()==2 and dead.profile.milestones[0]==3 and dead.profile.milestones[1]==5,"defeat earns only actually seen milestones")
  check(dead.slot==saved.slot+1 and dead.revision==saved.revision+1,"single slot/run increment")
  var duplicate=await s.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.RIGHT,request)
  check(duplicate==dead,"duplicate death no second grant or state change")
  direct=await s.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.DOWN,request)
  check(not direct.ok,"same nonce different lethal direction conflicts")
  var restarted=Store.new(s.path);restarted.owner=s.owner
  var restored=await restarted.read_active()
  if not need(restored,"death restart"):return
  check(restored.snapshot==dead.snapshot and restored.receipt==dead.receipt and restored.profile==dead.profile,"restart retains archive and same ledger")
  var data=s.native.read().data
  for field in ["enemy","start_hp","x","skill_armed"]:
   var bad=data.duplicate(true);bad.runs[saved.run_id].snapshot.death_record[field]=null
   check(not s.native._valid(bad),"bad death record rejected "+field)
  var next=await s.create_run(1,2,"safe",true,nonce())
  if not need(next,"next safe run"):return
  check(next.profile==dead.profile,"new safe run retains defeat ledger")
  direct=await s.settle_death(saved.slot,saved.revision,saved.run_id,Vector2i.RIGHT,request)
  check(not direct.ok and direct.reason=="SUPERSEDED_OPERATION","old death cannot restore superseded slot")
 var safe=fresh();var safe_new=await safe.create_run(0,2,"safe",false,nonce())
 if not need(safe_new,"safe mode setup"):return
 var safe_world=real_risk(safe_new.run_id,"safe")
 var safe_live=await safe.commit_run(safe_new.slot,safe_new.revision,safe_new.run_id,safe_world.save_data(),nonce())
 if not need(safe_live,"safe real W position"):return
 var before_safe=safe.native.read().data
 var cannot_die=await safe.settle_death(safe_live.slot,safe_live.revision,safe_live.run_id,Vector2i.RIGHT,nonce())
 check(not cannot_die.ok and safe.native.read().data==before_safe,"safe mode cannot opt into same real lethal encounter")
 var cannot_switch=safe_world.save_data();cannot_switch.mode="risk"
 var switch_mode=await safe.commit_run(safe_live.slot,safe_live.revision,safe_live.run_id,cannot_switch,nonce())
 check(not switch_mode.ok and safe.native.read().data==before_safe,"run mode immutable through ordinary save")
 var survivor=World.new(0,2,nonce(),"risk")
 for outcome in ["withdrawn","chapter1","victory"]:
  if outcome=="chapter1":
   for c in Generator.validate(survivor.floors).route:assert(survivor.step(DIRS[c]))
  elif outcome=="victory":
   assert(survivor.action("expedition"))
   for c in Expedition.generate(0).witness:assert(survivor.step(DIRS[c]))
  var branch=fresh();var initial=await branch.create_run(0,2,"risk",false,survivor.run_id)
  if not need(initial,"surviving risk create"):return
  var saved=await branch.commit_run(initial.slot,initial.revision,initial.run_id,survivor.save_data(),nonce())
  if not need(saved,"surviving risk witness"):return
  var ended=await branch.settle_run(saved.slot,saved.revision,saved.run_id,outcome,nonce())
  check(ended.ok and ended.status=="archived" and ended.snapshot.mode=="risk" and ended.receipt.summary.outcome==outcome,"surviving risk retains ordinary settlement "+outcome)
 # Genuine schema13 containers generated by the old committed code, no version edits.
 for label in ["active","archived"]:
  var source="res://tests/fixtures/schema13-"+label+"-store.json"
  var envelope=JSON.parse_string(FileAccess.get_file_as_string(source));var old=JSON.parse_string(envelope.payload)
  var s=fresh();DirAccess.make_dir_recursive_absolute(s.native.root)
  check(DirAccess.copy_absolute(ProjectSettings.globalize_path(source),s.native.root.path_join("store.json"))==OK,"copy authentic old container")
  var clocked=Clocked.new(s.path);clocked.now_ms=int(old.slot.writer.leaseUntil)+1;s.native=clocked
  var migrated=await s.read_active()
  if not need(migrated,"real13 migration"):return
  check(migrated.status==label and migrated.snapshot.version==19 and migrated.run_id==old.slot.activeRunId,"old identity and active/archive status preserved")
  check(migrated.snapshot.death_record.is_empty() and migrated.profile==old.profile.profile,"upgrade adds no death or reward")
  if label=="active":
   var w=World.from_snapshot(migrated.snapshot);check(w.step(Vector2i.LEFT),"old active continues legally")
   var saved=await s.commit_run(migrated.slot,migrated.revision,migrated.run_id,w.save_data(),nonce())
   check(saved.ok and saved.snapshot.version==19,"next normal commit upgrades old container payload")
  else:check(migrated.receipt==old.profile.profile.receipts[migrated.run_id],"old terminal receipt remains exact")
 print("DEATH STORAGE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
