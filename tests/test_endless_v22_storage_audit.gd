extends "res://tests/test_endless_v21_storage_audit.gd"
# Independent cross-rule persistence: all milestone records below come from
# actual world action replay, not manually injected floor/kill values.
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
   if seen.has(n) or t in ["~","F","#","D","u","v","N","M","S","E","R","O","J","L","B","T"]:continue
   if (t in w.enemy_tokens() or t in ["<",">"]) and n!=target:continue
   seen[n]=p;q.append(n)
 return []
func go(w,target:Vector2i)->bool:
 var route:=path_to(w,target)
 if route.is_empty() and w.pos!=target:check(false,"v22 legal route unreachable "+str(target));return false
 for p in route:
  if w.tile(p)=="C":
   if not w.act("cargo_use").get("changed",false):check(w.act("cargo_leave").get("changed",false),"legally decline unavailable rescue")
  if w.tile(p) in w.enemy_tokens() and w.focus>=w.skill_cost() and w.hp<=180-w.skill_heal():
   check(w.act("skill_use").get("changed",false),"legal scholar preparation")
  var result:Dictionary=w.step(p-w.pos)
  if not result.get("changed",false) or w.ended:check(false,"v22 legal route failed "+str(result));return false
 return true
func conclude(store,w,revision:int)->Dictionary:
 check(w.act("retire").get("changed",false),"actual voluntary retirement")
 var r:Dictionary=await store.commit(w.save_data(),revision)
 check(r.ok,"retirement committed")
 if not r.ok:return r
 return await store.finish(w.save_data(),int(r.revision))
func run():
 if not FileAccess.file_exists("res://scripts/endless_world_v22.gd"):
  push_error("v22 implementation not ready; audit must not claim pass");quit(2);return
 var root="/tmp/tower-v22-cross-version-"+str(Time.get_ticks_usec())
 var p=root+"/cross.json";var a=Store.new(p);var b=Store.new(p)
 W=load("res://scripts/endless_world_v21.gd")
 var old=journey(3)
 if old==null:quit(1);return
 var r:Dictionary=await persist_earned(a,old,0)
 r=await conclude(a,old,int(r.revision))
 check(r.ok and r.points==1 and r.profile.milestones==[3],"real v21 third-floor result earns initial shared point")
 var first_record:Dictionary=r.records[0].duplicate(true)
 r=await a.unlock_legacy("kit",int(r.revision))
 check(r.ok and r.points==0 and r.profile.unlocks==["kit"],"v21 earned point purchases shared kit")
 var old_receipt:Dictionary=r.settlement.duplicate(true)
 W=load("res://scripts/endless_world_v22.gd")
 G=load("res://scripts/endless_generation_v22.gd")
 var next=W.new_run(42);next.act("hero_scholar");next.act("legacy_kit")
 var before=bytes(p);var stale:int=r.revision
 var locked=W.new_run(42);locked.act("hero_scholar");locked.act("legacy_mind")
 var rejected:Dictionary=await b.start_legacy(locked.save_data(),stale)
 check(not rejected.ok and bytes(p)==before,"v22 cannot select unowned legacy inherited from prior version")
 r=await a.start_legacy(next.save_data(),stale)
 check(r.ok and r.points==0 and r.profile.milestones==[3] and r.profile.unlocks==["kit"] and r.settlement.is_empty(),"v22 start preserves v21 profile and clears only receipt")
 before=bytes(p)
 var retry:Dictionary=await b.start_legacy(next.save_data(),stale)
 check(retry.ok and retry.revision==r.revision and bytes(p)==before,"v22 start lost acknowledgement is read-only")
 var other=W.new_run(43);other.act("hero_scholar");other.act("legacy_kit")
 rejected=await b.start_legacy(other.save_data(),stale)
 check(not rejected.ok and bytes(p)==before,"different v22 seed cannot reuse stale start revision")
 var same_depth=journey(3,42,"kit")
 if same_depth==null:quit(1);return
 # Alive new start is intentionally legal and carries no award.
 r=await persist_earned(a,same_depth,int(r.revision))
 r=await conclude(a,same_depth,int(r.revision))
 check(r.ok and r.points==0 and r.profile.milestones==[3] and r.settlement.awarded.is_empty(),"v22 same floor does not pay v21 milestone twice")
 var same_record:Dictionary={}
 for record in r.records:
  if record.run_id==r.run_id:same_record=record.duplicate(true)
 var deep=journey(8,42,"kit")
 if deep==null:quit(1);return
 r=await persist_earned(a,deep,int(r.revision))
 r=await conclude(a,deep,int(r.revision))
 check(r.ok and r.points==1 and r.profile.milestones==[3,8] and r.settlement.awarded==[8],"v22 actual eighth floor earns only new shared milestone")
 var deep_record:Dictionary={}
 for record in r.records:
  if record.run_id==r.run_id:deep_record=record.duplicate(true)
 before=bytes(p)
 var future=deep.save_data().duplicate(true);future.version=23
 rejected=await b.start_legacy(future,int(r.revision))
 check(not rejected.ok and bytes(p)==before,"future rules23 rejected without disturbing profile")
 # Shape/ownership corruption fixtures are separate from the genuine journeys.
 for version in [21,22]:
  var corrupt:Dictionary=JSON.parse_string(before)
  corrupt.active={"version":version,"mode":"endless","seed":42,"actions":["hero_scholar","legacy_mind"]}
  corrupt.finished=false;corrupt.settlement={};corrupt.records=[]
  var bad_path=root+"/unowned-"+str(version)+".json";write_json(bad_path,corrupt)
  var original=bytes(bad_path);var refusal:Dictionary=await Store.new(bad_path).read()
  check(not refusal.ok and bytes(bad_path)==original,"active ownership enforced for rules"+str(version))
 var final:Dictionary=await Store.new(p).read()
 check(final.ok and final.points==1 and final.profile.milestones==[3,8] and final.profile.unlocks==["kit"],"restart retains single shared cross-rule ledger")
 var trace_path=root+"/earned-trace.json"
 write_json(trace_path,{"old_snapshot":old.save_data(),"old_record":first_record,"same_snapshot":same_depth.save_data(),"same_record":same_record,"deep_snapshot":deep.save_data(),"deep_record":deep_record})
 var node_output=[]
 var node_exit=OS.execute("node",[ProjectSettings.globalize_path("res://tests/test_endless_v22_storage_audit.js"),trace_path],node_output,true)
 for output in node_output:print(output)
 check(node_exit==0,"production JS cross-rule parity on actual native traces")
 print("V22_STORAGE_INDEPENDENT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"evidence_root":root,"old_actions":old.actions.size(),"same_actions":same_depth.actions.size(),"deep_actions":deep.actions.size(),"profile":final.get("profile",{}),"boundary":"Genuine native earned journeys; malformed ownership fixtures explicitly separate. Not WebGL gameplay or anti-cheat."}))
 quit(0 if failures.is_empty() else 1)
