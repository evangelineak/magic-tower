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
 var w=World.new_run(12);var fresh=w.save_data()
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
 w=World.new_run(12);r=await a.start(w.save_data(),r.revision)
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
