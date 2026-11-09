extends SceneTree
# Independent acceptance: earned movement histories are distinct from corruption
# and ranking-retention fixtures below. Production world computes game actions;
# this test independently asserts persistence, balances and transaction effects.
const Store=preload("res://scripts/endless_store.gd")
var W
var G=preload("res://scripts/endless_generation_v19.gd")
var checks:=0
var failures:=[]
var evidence=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func write_json(path:String,value):
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
func bytes(path:String)->String:return FileAccess.get_file_as_string(path)
func path_to(w,target:Vector2i)->Array:
 var q=[w.pos];var seen={w.pos:w.pos};var i:=0
 while i<q.size():
  var p:Vector2i=q[i];i+=1
  if p==target:
   var out=[]
   while p!=w.pos:out.push_front(p);p=seen[p]
   return out
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n=p+d;var t:String=w.tile(n)
   if seen.has(n) or t in ["#","D","u","v","N","M","S","E","R","O","J","L","B","T"]:continue
   if (t in w.enemy_tokens() or t in ["<",">"]) and n!=target:continue
   seen[n]=p;q.append(n)
 return []
func go(w,target:Vector2i)->bool:
 var route:=path_to(w,target)
 if route.is_empty() and w.pos!=target:check(false,"legal route unreachable "+str(target));return false
 for p in route:
  if w.tile(p)=="C":
   var use:Dictionary=w.act("cargo_use")
   if not use.get("changed",false):check(w.act("cargo_leave").get("changed",false),"discard unopened full-health crate legally")
  var r:Dictionary=w.step(p-w.pos)
  if not r.get("changed",false) or w.ended:check(false,"legal route action failed "+str(r));return false
 return true
func journey(depth:int,seed:int=42,legacy:String="none"):
 var w=W.new_run(seed)
 check(w.act("hero_scholar").get("changed",false),"canonical hero selected")
 check(w.act("legacy_"+legacy).get("changed",false),"canonical legacy selected")
 while w.floor_number<depth:
  var f:int=w.floor_number;var y:=1 if f%2 else 13
  if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):return null
  var points:Array=G.routes(seed,f)[0].points.duplicate()
  if f%2==0:points.reverse()
  for p in points:
   if not go(w,p):return null
  if not go(w,G.anchors(f).exit):return null
 return w
func death_journey():
 var w=journey(3)
 if w==null:return null
 # Keep walking the ordinary main route without training or taking rescue crates.
 # All danger actions are explicitly confirmed, never HP/position injection.
 for f in range(3,10):
  var points=G.routes(w.seed,f)[0].points.duplicate()
  if f%2==0:points.reverse()
  points.append(G.anchors(f).exit)
  for p in points:
   var route=path_to(w,p)
   if route.is_empty() and w.pos!=p:check(false,"death route reachable");return null
   for q in route:
    if w.tile(q)=="C":check(w.act("cargo_leave").get("changed",false),"death route legally declines rescue")
    var result=w.step(q-w.pos,true)
    if not result.get("changed",false):check(false,"death route legal action");return null
    if w.ended:return w
 check(false,"unupgraded ordinary route eventually dies")
 return null
func persist_earned(store,w,revision:int)->Dictionary:
 var initial=W.new_run(w.seed);initial.act(w.actions[0]);initial.act(w.actions[1])
 var r:Dictionary=await store.start_legacy(initial.save_data(),revision)
 check(r.get("ok",false),"earned run initial atomic start")
 if not r.get("ok",false):return r
 for code in w.actions.slice(2):
  var change:Dictionary=initial.apply_code(code)
  check(change.get("changed",false),"earned history every event legal")
  r=await store.commit(initial.save_data(),int(r.revision))
  if not r.get("ok",false):check(false,"earned history commit "+str(r));return r
 check(initial.save_data()==w.save_data(),"actual persisted replay reaches earned snapshot")
 return r
func run():
 W=load("res://scripts/endless_world_v21.gd")
 if W==null:check(false,"v21 world exists");quit(1);return
 var root="/tmp/tower-v21-independent-"+str(Time.get_ticks_usec())
 var p=root+"/earned.json";var a=Store.new(p);var b=Store.new(p)
 var r:Dictionary=await a.read()
 check(r.ok and not FileAccess.file_exists(p),"empty read never writes migration")
 var w=journey(3)
 if w==null:quit(1);return
 r=await persist_earned(a,w,int(r.revision))
 if not r.get("ok",false):quit(1);return
 check(w.max_floor==3 and w.kills>=2,"earned actual third floor without injected growth")
 var before=bytes(p);var revoked=w.clone();check(revoked.act("retire").get("changed",false),"actual voluntary retirement")
 a.test_fail_write=true
 var rejected:Dictionary=await a.commit(revoked.save_data(),int(r.revision))
 check(not rejected.ok and bytes(p)==before,"failed terminal commit retains exact previous bytes")
 a.test_fail_write=false
 r=await a.commit(revoked.save_data(),int(r.revision));check(r.ok,"terminal event durably committed")
 var starter=W.new_run(7);starter.act("hero_warden");starter.act("legacy_none")
 before=bytes(p)
 rejected=await b.start_legacy(starter.save_data(),int(r.revision))
 check(not rejected.ok and bytes(p)==before,"ended pending settlement cannot be overwritten")
 var terminal_revision:int=r.revision
 a.test_fail_write=true
 rejected=await a.finish(revoked.save_data(),terminal_revision)
 check(not rejected.ok and bytes(p)==before,"failed finish neither pays nor marks finished")
 a.test_fail_write=false
 r=await b.finish(revoked.save_data(),terminal_revision)
 check(r.ok and r.points==1 and r.profile.milestones==[3] and r.settlement.awarded==[3] and r.settlement.balance_after==1,"third-floor retirement grants exactly first milestone atomically")
 var trace_path=root+"/earned-trace.json"
 var old_trace=load("res://scripts/endless_world_v20.gd").new_run(42);old_trace.act("hero_warden")
 write_json(trace_path,{"snapshot":revoked.save_data(),"record":r.records[0],"settlement":r.settlement,"old_snapshot":old_trace.save_data()})
 var acknowledged=bytes(p)
 var again:Dictionary=await a.finish(revoked.save_data(),terminal_revision)
 check(again.ok and bytes(p)==acknowledged and again.revision==r.revision,"lost finish acknowledgement no second write/reward")
 var restart=Store.new(p);var loaded:Dictionary=await restart.read()
 check(loaded.ok and loaded.points==1 and loaded.settlement==r.settlement,"restart preserves confirmed settlement receipt")
 var receipt:Dictionary=loaded.settlement.duplicate(true)
 before=bytes(p)
 rejected=await restart.unlock_legacy("coin",int(loaded.revision))
 check(not rejected.ok and bytes(p)==before,"two-point option cannot spend one point")
 a.test_fail_write=true
 rejected=await a.unlock_legacy("kit",int(loaded.revision))
 check(not rejected.ok and bytes(p)==before,"failed unlock retains earned point and ownership bytes")
 a.test_fail_write=false
 var stale:int=loaded.revision
 r=await a.unlock_legacy("kit",stale)
 check(r.ok and r.points==0 and r.profile.unlocks==["kit"] and r.settlement==receipt,"unlock deducts fixed cost but keeps settlement receipt")
 acknowledged=bytes(p)
 var delayed:Dictionary=await b.finish(revoked.save_data(),terminal_revision)
 check(delayed.ok and delayed.settlement==receipt and bytes(p)==acknowledged,"lost finish reply after concurrent unlock still returns original receipt without write")
 again=await b.unlock_legacy("kit",stale)
 check(again.ok and again.points==0 and bytes(p)==acknowledged,"same unlock stale retry never double charges")
 rejected=await b.unlock_legacy("mind",stale)
 check(not rejected.ok and bytes(p)==acknowledged,"competing different unlock cannot spend stale balance")
 var owned=W.new_run(42);owned.act("hero_ranger");owned.act("legacy_kit")
 r=await b.start_legacy(owned.save_data(),int(r.revision))
 check(r.ok and r.points==0 and r.settlement.is_empty(),"owned loadout new run clears only current receipt")
 check(owned.items.ward==1 and owned.items.pierce==1 and owned.focus==1,"owned loadout is replayed as finite initial resources")
 check(not (await a.finish(revoked.save_data(),terminal_revision)).ok,"old run cannot pay after a new run begins")
 # Repeat the exact same earned progress in a new run: no second milestone.
 var duplicate=journey(3)
 r=await persist_earned(a,duplicate,int(r.revision));duplicate.act("retire")
 r=await a.commit(duplicate.save_data(),int(r.revision));r=await a.finish(duplicate.save_data(),int(r.revision))
 check(r.ok and r.points==0 and r.profile.milestones==[3] and r.settlement.awarded.is_empty(),"same seed/depth new death-or-retirement does not farm points")
 evidence.append({"earned_floor":3,"actions":w.actions.size(),"first_award":[3],"spent_unlock":"kit","repeat_award":r.settlement.awarded})
 # Controlled ranking-retention fixture, not forged earned growth: remove the
 # convenience ranking from an otherwise already verified settled envelope.
 var envelope:Dictionary=JSON.parse_string(bytes(p));envelope.records=[];write_json(p,envelope)
 loaded=await Store.new(p).read()
 check(loaded.ok and loaded.points==0 and loaded.profile.milestones==[3],"discarded top10 history cannot erase milestone ledger")
 # A separate genuinely played death crosses floor 3 then falls on floor 7.
 var dead=death_journey()
 if dead==null:quit(1);return
 check(dead.ended and dead.ended_reason=="death" and dead.max_floor==7,"actual confirmed fatal battle on seventh floor")
 var death_store=Store.new(root+"/death.json")
 var death_saved:Dictionary=await persist_earned(death_store,dead,0)
 check(death_saved.ok,"fatal battle persisted through every legal event")
 var death_result:Dictionary=await death_store.finish(dead.save_data(),int(death_saved.revision))
 check(death_result.ok and death_result.points==1 and death_result.settlement.awarded==[3] and death_result.records[0].reason=="death","actual death and retirement share earned milestone rule")
 evidence.append({"death_floor":dead.max_floor,"death_actions":dead.actions.size(),"death_award":death_result.settlement.awarded})
 # Independent v1 migration: exact genuine old snapshot, no retroactive grant.
 var old_path=root+"/old.json";var old=load("res://scripts/endless_world_v20.gd").new_run(42);old.act("hero_warden")
 var original={"version":1,"revision":7,"run_id":4,"active":old.save_data(),"finished":false,"records":[]}
 write_json(old_path,original);var legacy=Store.new(old_path);var original_bytes=bytes(old_path)
 loaded=await legacy.read();check(loaded.ok and bytes(old_path)==original_bytes and loaded.points==0,"v1 read only does not mutate old bytes")
 old.act("retire")
 # Real filesystem failure, distinct from the deterministic test_fail_write hook:
 # make the atomic pending-file name an empty directory, so FileAccess.open fails.
 check(DirAccess.make_dir_absolute(old_path+".pending")==OK,"create actual pending-file collision fixture")
 rejected=await legacy.commit(old.save_data(),7)
 check(not rejected.ok and bytes(old_path)==original_bytes,"real native pending-file open failure keeps v1 bytes")
 check(DirAccess.remove_absolute(old_path+".pending")==OK,"remove only own empty collision fixture")
 legacy.test_fail_write=true
 rejected=await legacy.commit(old.save_data(),7)
 check(not rejected.ok and bytes(old_path)==original_bytes,"failed first migration leaves old v1 bytes exactly")
 legacy.test_fail_write=false;r=await legacy.commit(old.save_data(),7)
 check(r.ok and JSON.parse_string(bytes(old_path)).version==2,"first successful transaction atomically upgrades envelope")
 r=await legacy.finish(old.save_data(),int(r.revision))
 check(r.ok and r.points==0 and r.profile.milestones.is_empty() and r.settlement.awarded.is_empty(),"old v20 settlement never retroactively earns meta")
 # Explicit controlled corruption fixtures fail closed without rewriting.
 var bad_path=root+"/future.json";var corrupt=JSON.parse_string(bytes(p));corrupt.version=99;write_json(bad_path,corrupt);before=bytes(bad_path)
 rejected=await Store.new(bad_path).read();check(not rejected.ok and bytes(bad_path)==before,"future schema rejected without deleting or migration")
 var balance_path=root+"/negative.json";corrupt=JSON.parse_string(bytes(p));corrupt.profile.unlocks=["kit","coin","mind"];write_json(balance_path,corrupt);before=bytes(balance_path)
 rejected=await Store.new(balance_path).read();check(not rejected.ok and bytes(balance_path)==before,"negative computed balance invalid and bytes preserved")
 var node_output=[]
 var node_exit=OS.execute("node",[ProjectSettings.globalize_path("res://tests/test_endless_v21_storage_audit.js"),trace_path],node_output,true)
 for output in node_output:print(output)
 check(node_exit==0,"production JS parity on native earned trace")
 print("V21_STORAGE_INDEPENDENT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"earned":evidence,"evidence_root":root,"boundary":"Native real files/CAS and genuinely walked third-floor runs; ranking removal and malformed envelopes are explicitly controlled fixtures. No Godot Web gameplay or malicious-client trust claim."}))
 quit(0 if failures.is_empty() else 1)
