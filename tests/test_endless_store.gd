extends SceneTree
const Store=preload("res://scripts/endless_store.gd")
const World=preload("res://scripts/endless_world.gd")
var count:=0
var failures:=0
func check(value:bool,label:String):
 count+=1
 if not value:failures+=1;push_error(label)
func _initialize():call_deferred("run_tests")
func route(w,target:Vector2i)->Array:
 var queue=[w.pos];var parents={w.pos:w.pos};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==target:
   var steps=[]
   while p!=w.pos:steps.push_front(p);p=parents[p]
   return steps
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var q:Vector2i=p+d
   if parents.has(q) or w.tile(q) in ["#","D","V","<",">","M","S"]:continue
   parents[q]=p;queue.append(q)
 return []
func run_tests():
 var path="/tmp/tower-endless-store-"+str(Time.get_ticks_usec())+"/endless.json"
 var a=Store.new(path);var b=Store.new(path)
 var r=await a.read();check(r.ok and r.status=="empty","independent empty slot")
 var w=World.new_run(12,1);var fresh=w.save_data()
 r=await a.start(fresh,0);check(r.ok and r.revision==1,"start persisted")
 check((await a.start(fresh,0)).revision==1,"start ack retry idempotent")
 var p=w.pos;var moved=w.step(Vector2i.RIGHT)
 check(moved.changed,"real world step")
 var s=w.save_data();r=await a.commit(s,1)
 check(r.ok and r.revision==2,"one real move persisted")
 check((await a.commit(s,1)).revision==2,"commit ack retry idempotent")
 var back=w.clone();back.step(Vector2i.RIGHT)
 check((await b.commit(back.save_data(),1)).status=="conflict","second writer stale revision rejected")
 a.test_fail_write=true
 var before=FileAccess.get_file_as_string(path)
 check((await a.commit(back.save_data(),2)).status=="io_error","failed write reported")
 check(FileAccess.get_file_as_string(path)==before,"failed write keeps previous bytes")
 a.test_fail_write=false
 check((await a.commit(back.save_data(),2)).ok,"retry previously failed action")
 var reload=await b.read()
 check(reload.ok and World.from_data(reload.snapshot).pos==p+Vector2i(2,0),"separate instance restores exact position")
 check((await a.finish(reload.snapshot,reload.revision)).status=="invalid","active run cannot score")
 w=World.from_data(reload.snapshot);w.act("retire")
 r=await a.commit(w.save_data(),reload.revision)
 check(r.ok,"retirement persisted first")
 var ended_revision=r.revision
 r=await a.finish(w.save_data(),ended_revision)
 check(r.ok and r.status=="finished" and r.records.size()==1,"retirement and local leaderboard")
 check((await a.finish(w.save_data(),ended_revision)).records.size()==1,"finish acknowledgement retry no duplicate")
 check((await b.read()).status=="finished","finished state readable")
 var forged=fresh.duplicate(true);forged.atk=99999
 check((await a.start(forged,r.revision)).status=="invalid","unknown snapshot field rejected")
 forged=fresh.duplicate(true);forged.actions=["invalid"]
 check((await a.commit(forged,r.revision)).status=="invalid","unknown action rejected by replay")
 w=World.new_run(12,1);r=await a.start(w.save_data(),r.revision)
 w.step(Vector2i.RIGHT);r=await a.commit(w.save_data(),r.revision)
 var steps=route(w,Vector2i(9,10))
 check(not steps.is_empty(),"real route reaches optional guard")
 for target in steps:
  var action=w.step(target-w.pos)
  check(action.changed,"real route action accepted")
  r=await a.commit(w.save_data(),r.revision)
  check(r.ok,"real route action persisted")
 check(not w.preview(Vector2i(10,10)).survivable,"early vault guard fatal")
 w.step(Vector2i.RIGHT,true)
 r=await a.commit(w.save_data(),r.revision)
 check(r.ok and w.ended and w.ended_reason=="death","actual confirmed death persisted")
 r=await a.finish(w.save_data(),r.revision)
 check(r.ok and r.records.size()==2,"actual death records once alongside retirement")
 # Versioned replay must not reinterpret old runs or cross rules on one run.
 var legacy_record={"run_id":1,"seed":12,"max_floor":1,"kills":0,"gold":0,"reason":"retired"}
 check(a.valid_record(legacy_record),"unversioned old records remain readable as v1")
 for bad_version in [0,7,1.5,"1",true,null]:
  var bad_record=legacy_record.duplicate();bad_record.rule_version=bad_version
  check(not a.valid_record(bad_record),"record rejects invalid rule version")
 var version_path=path+".versions"
 var versions=Store.new(version_path)
 var old=World.new_run(12,1);var modern=World.new_run(12,2)
 check(old.save_data().version==1 and modern.save_data().version==2,"explicit v1 and v2 factories")
 var vr=await versions.start(old.save_data(),0)
 check(vr.ok,"version one start")
 check((await versions.start(modern.save_data(),0)).status=="conflict","different-version start is not ack retry")
 modern.act("retire")
 check((await versions.commit(modern.save_data(),1)).status=="invalid","cannot upgrade active run via commit")
 old.act("retire")
 check((await versions.commit(old.save_data(),1)).ok,"old rules still replay and commit")
 vr=await versions.finish(old.save_data(),2)
 check(vr.ok and vr.records[0].rule_version==1,"old rules settle and label")
 modern=World.new_run(12,2)
 vr=await versions.start(modern.save_data(),3)
 check(vr.ok and vr.snapshot.version==2,"explicit new run changes version")
 check((await Store.new(version_path).read()).snapshot.version==2,"v2 disk roundtrip preserves version")
 modern.act("retire")
 vr=await versions.commit(modern.save_data(),4)
 check(vr.ok,"v2 action commits")
 var switched=modern.save_data();switched.version=1
 check((await versions.finish(switched,5)).status=="invalid","finish cannot change rules")
 vr=await versions.finish(modern.save_data(),5)
 check(vr.ok and vr.records[1].rule_version==2,"v2 finish and label")
 check((await versions.finish(switched,5)).status=="conflict","finish retry checks version")
 for bad_version in [0,7,1.5,"1",true,null,{},[]]:
  var bad=modern.save_data();bad.version=bad_version
  check(World.from_data(bad)==null,"facade rejects invalid version")
  check((await versions.start(bad,6)).status=="invalid","storage rejects invalid version")
 var roundtrip=JSON.parse_string(JSON.stringify(old.save_data()))
 check(World.from_data(roundtrip).save_data()==old.save_data(),"JSON number version accepted without migration")
 check(World.new_run(12).save_data().version==6,"new factory defaults to v6")
 # Every ordered pair rejects cross-rule commits, while explicit starts work.
 for source in [1,2,3,4,5,6]:
  vr=await versions.read()
  var source_world=World.new_run(12,source)
  vr=await versions.start(source_world.save_data(),vr.revision)
  check(vr.ok and vr.snapshot.version==source,"explicit version start")
  for target_version in [1,2,3,4,5,6]:
   if target_version==source:continue
   var target_world=World.new_run(12,target_version);target_world.act("retire")
   var bytes=FileAccess.get_file_as_string(version_path)
   check((await versions.commit(target_world.save_data(),vr.revision)).status=="invalid","cross-version commit rejected")
   check(FileAccess.get_file_as_string(version_path)==bytes,"cross-version rejection preserves bytes")
  source_world.act("retire")
  vr=await versions.commit(source_world.save_data(),vr.revision)
  check(vr.ok,"matching version retirement persisted")
  vr=await versions.finish(source_world.save_data(),vr.revision)
  check(vr.ok,"matching version finished")
  var found=false
  for item in vr.records:
   if item.run_id==vr.run_id:found=item.rule_version==source
  check(found,"rank labels exact rules")
  var reopened=await Store.new(version_path).read()
  check(reopened.ok and reopened.snapshot.version==source,"disk reload preserves every version")
 DirAccess.remove_absolute(version_path)
 var lock=path+".lock"
 DirAccess.make_dir_absolute(lock)
 var owner=FileAccess.open(lock+"/owner.json",FileAccess.WRITE);owner.store_string(JSON.stringify({"pid":OS.get_process_id()}));owner.close()
 check((await a.start(fresh,r.revision)).status=="locked","live process lock is never stolen")
 owner=FileAccess.open(lock+"/owner.json",FileAccess.WRITE);owner.store_string(JSON.stringify({"pid":2147483647}));owner.close()
 if a.owner_proved_dead(2147483647):check((await a.start(fresh,r.revision)).ok,"proved dead process lock recovers")
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("not json");file.close()
 check((await b.read()).status=="corrupt","corrupt file not reset")
 check((await a.start(fresh,r.revision)).status=="corrupt","new run cannot silently overwrite corrupt save")
 check(FileAccess.get_file_as_string(path)=="not json","corruption retained for recovery")
 DirAccess.remove_absolute(path);DirAccess.remove_absolute(path.get_base_dir())
 print("ENDLESS NATIVE STORE: %s (%d checks)"%["PASS" if failures==0 else "FAIL",count])
 quit(0 if failures==0 else 1)
