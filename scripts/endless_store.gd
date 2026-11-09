class_name TowerEndlessStore
extends RefCounted
## Separate device-only save. Never opens the classic journey/profile files.
const World=preload("res://scripts/endless_world.gd")
const MAX_BYTES:=2*1024*1024
const MAX_COUNTER:=10000000
signal web_reply
var path:String
var use_web:=false
var bridge
var callback
var pending:Dictionary={}
var serial:=0
var cache_world=null
var cache_snapshot:Dictionary={}
var test_fail_write:=false
var web_timeout_seconds:=10.0
func _init(test_path:String=""):
 path=ProjectSettings.globalize_path("user://endless-v1.json" if test_path=="" else test_path)
 use_web=OS.has_feature("web") and test_path==""
func fail(status:String)->Dictionary:return {"ok":false,"status":status}
func exact(value,keys:Array)->bool:
 if not value is Dictionary or value.size()!=keys.size():return false
 for key in keys:
  if not value.has(key):return false
 return true
func integer(value,low:int=0,high:int=MAX_COUNTER)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and floor(float(value))==value
func snapshot_shape(s)->bool:
 if not exact(s,["version","mode","seed","actions"]) or not World.supports_version(s.version) or s.mode!="endless" or not integer(s.seed,0,2147483647) or not s.actions is Array or s.actions.size()>100000:return false
 for a in s.actions:
  if not a is String or a.is_empty() or a.length()>40:return false
 return true
func canonical_snapshot(s:Dictionary)->Dictionary:
 return {"version":int(s.version),"mode":"endless","seed":int(s.seed),"actions":s.actions.duplicate()}
func valid_record(r)->bool:
 if not exact(r,["run_id","seed","max_floor","kills","gold","reason"]) and not exact(r,["run_id","seed","max_floor","kills","gold","reason","rule_version"]):return false
 if not World.supports_version(r.get("rule_version",1)):return false
 return integer(r.run_id,1) and integer(r.seed,0,2147483647) and integer(r.max_floor,1,1000000000) and integer(r.kills,0,1000000000) and integer(r.gold,0,1000000000) and r.reason in ["death","retired","action_limit"]
func fresh()->Dictionary:return {"version":1,"revision":0,"run_id":0,"active":null,"finished":false,"records":[]}
func valid_envelope(e)->bool:
 if not exact(e,["version","revision","run_id","active","finished","records"]) or e.version!=1 or not integer(e.revision) or not integer(e.run_id) or not e.finished is bool or not e.records is Array or e.records.size()>10:return false
 if e.active!=null and not snapshot_shape(e.active):return false
 var seen:Dictionary={}
 for r in e.records:
  if not valid_record(r) or r.run_id>e.run_id or seen.has(r.run_id):return false
  seen[r.run_id]=true
 return (e.run_id==0 and e.active==null and not e.finished and e.records.is_empty()) or (e.run_id>0 and e.active!=null)
func result(e:Dictionary)->Dictionary:
 return {"ok":true,"status":"empty" if e.active==null else ("finished" if e.finished else "active"),"snapshot":{} if e.active==null else e.active.duplicate(true),"revision":int(e.revision),"run_id":int(e.run_id),"records":e.records.duplicate(true)}
func validated(s:Dictionary):
 if not snapshot_shape(s):return null
 if cache_world!=null and s==cache_snapshot:return cache_world
 var w=null
 if cache_world!=null and s.version==cache_snapshot.version and s.seed==cache_snapshot.seed and s.actions.size()==cache_snapshot.actions.size()+1 and s.actions.slice(0,-1)==cache_snapshot.actions:
  w=cache_world.clone()
  var action_result:Dictionary=w.apply_code(str(s.actions[-1]))
  if not action_result.get("changed",false) or w.save_data()!=s:w=null
 else:w=World.from_data(s)
 if w!=null:cache_world=w;cache_snapshot=s.duplicate(true)
 return w
func native_read()->Dictionary:
 if not FileAccess.file_exists(path):return {"ok":true,"envelope":fresh()}
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return fail("io_error")
 if file.get_length()>MAX_BYTES:return fail("corrupt")
 var json=JSON.new()
 if json.parse(file.get_as_text())!=OK:return fail("corrupt")
 var e=json.data
 if not valid_envelope(e):return fail("corrupt")
 if e.active!=null:e.active=canonical_snapshot(e.active)
 return {"ok":true,"envelope":e}
func _on_reply(args:Array):
 if args.size()!=1:return
 var p=JSON.parse_string(str(args[0]))
 if p is Dictionary and pending.has(int(p.get("request",-1))):pending[int(p.request)]=p.get("result",fail("io_error"));web_reply.emit()
func web(operation:String,args:Dictionary)->Dictionary:
 if bridge==null:
  var source=FileAccess.get_file_as_string("res://scripts/endless_storage_web.js")
  if source.is_empty():return fail("unavailable")
  JavaScriptBridge.eval(source,true);bridge=JavaScriptBridge.get_interface("MagicTowerEndless")
  if bridge==null:return fail("unavailable")
  callback=JavaScriptBridge.create_callback(_on_reply)
 serial+=1;var id=serial;pending[id]={"waiting":true}
 var timer=Engine.get_main_loop().create_timer(web_timeout_seconds)
 timer.timeout.connect(func():
  if pending.has(id) and pending[id].get("waiting",false):pending[id]=fail("timeout");web_reply.emit()
 ,CONNECT_ONE_SHOT)
 bridge.request(JSON.stringify({"request":id,"operation":operation,"args":args}),callback)
 while pending.has(id) and pending[id].get("waiting",false):await web_reply
 var r:Dictionary=pending.get(id,fail("io_error"));pending.erase(id);return r
func read()->Dictionary:
 var r:Dictionary
 if use_web:r=await web("read",{})
 else:
  var loaded=native_read()
  r=result(loaded.envelope) if loaded.ok else loaded
 if not r.get("ok",false):return r
 if r.status!="empty":
  if not snapshot_shape(r.snapshot):return fail("corrupt")
  r.snapshot=canonical_snapshot(r.snapshot)
  var w=validated(r.snapshot)
  if w==null:return fail("corrupt")
  if r.status=="finished" and not w.ended:return fail("corrupt")
 return r
func start(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("start",snapshot,expected_revision)
func commit(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("commit",snapshot,expected_revision)
func finish(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("finish",snapshot,expected_revision)
func write(operation:String,s:Dictionary,expected:int)->Dictionary:
 if not snapshot_shape(s) or JSON.stringify(s).length()>MAX_BYTES:return fail("invalid")
 s=canonical_snapshot(s)
 var current=await read()
 if not current.get("ok",false):return current
 # Validate before writes; clone/apply-one never trusts a new history prefix.
 var w=validated(s)
 if w==null:return fail("invalid")
 var r:Dictionary={}
 if operation=="finish":
  if not w.ended:return fail("invalid")
  r={"run_id":current.run_id,"seed":w.seed,"max_floor":w.max_floor,"kills":w.kills,"gold":w.gold,"reason":w.ended_reason,"rule_version":int(s.version)}
  if not valid_record(r):return fail("invalid")
 var args={"snapshot":s,"expected_revision":expected,"record":r}
 if use_web:return await web(operation,args)
 var directory=path.get_base_dir()
 if DirAccess.make_dir_recursive_absolute(directory)!=OK and not DirAccess.dir_exists_absolute(directory):return fail("io_error")
 var lock_path=path+".lock"
 if not acquire_native_lock(lock_path):return fail("locked")
 var outcome=native_write_locked(operation,args)
 DirAccess.remove_absolute(lock_path+"/owner.json")
 DirAccess.remove_absolute(lock_path)
 return outcome
func acquire_native_lock(lock_path:String)->bool:
 if DirAccess.make_dir_absolute(lock_path)==OK:return write_lock_owner(lock_path)
 # Recover only a proved-dead process, serialized by a separate recovery guard.
 # Missing/malformed metadata or a reused live PID stays locked, never guessed stale.
 var recovery=lock_path+".recovery"
 if DirAccess.make_dir_absolute(recovery)!=OK:return false
 var owner_path=lock_path+"/owner.json"
 var parser=JSON.new();var safe=false
 if FileAccess.file_exists(owner_path) and parser.parse(FileAccess.get_file_as_string(owner_path))==OK:
  var owner=parser.data
  safe=exact(owner,["pid"]) and integer(owner.pid,1,2147483647) and owner_proved_dead(int(owner.pid))
 if safe:
  if DirAccess.remove_absolute(owner_path)==OK:DirAccess.remove_absolute(lock_path)
 DirAccess.remove_absolute(recovery)
 if not safe or DirAccess.make_dir_absolute(lock_path)!=OK:return false
 return write_lock_owner(lock_path)
func owner_proved_dead(pid:int)->bool:
 # Godot is_process_running is not reliable for arbitrary Unix PIDs.
 if pid==OS.get_process_id():return false
 return OS.get_name()=="Linux" and DirAccess.dir_exists_absolute("/proc/self") and not DirAccess.dir_exists_absolute("/proc/"+str(pid))
func write_lock_owner(lock_path:String)->bool:
 var file=FileAccess.open(lock_path+"/owner.json",FileAccess.WRITE)
 if file==null:
  DirAccess.remove_absolute(lock_path);return false
 file.store_string(JSON.stringify({"pid":OS.get_process_id()}));file.flush()
 var ok=file.get_error()==OK;file.close()
 if not ok:
  DirAccess.remove_absolute(lock_path+"/owner.json");DirAccess.remove_absolute(lock_path)
 return ok
func native_write_locked(operation:String,a:Dictionary)->Dictionary:
 var loaded=native_read()
 if not loaded.ok:return loaded
 var e:Dictionary=loaded.envelope;var s:Dictionary=a.snapshot;var expected:int=a.expected_revision
 if operation=="finish" and e.finished and e.active==s and expected==int(e.revision)-1:return result(e)
 if not e.finished and e.active==s and expected==int(e.revision)-1 and ((operation=="start" and s.actions.is_empty()) or (operation=="commit" and not s.actions.is_empty())):return result(e)
 if expected!=int(e.revision):return fail("conflict")
 if e.revision>=MAX_COUNTER:return fail("limit")
 var n=e.duplicate(true);n.revision=int(n.revision)+1
 if operation=="start":
  if not s.actions.is_empty() or e.run_id>=MAX_COUNTER:return fail("invalid")
  n.run_id=int(n.run_id)+1;n.active=s.duplicate(true);n.finished=false
 elif operation=="commit":
  if e.active==null or e.finished or s.version!=e.active.version or s.seed!=e.active.seed or s.actions.size()!=e.active.actions.size()+1 or s.actions.slice(0,-1)!=e.active.actions:return fail("invalid")
  n.active=s.duplicate(true)
 elif operation=="finish":
  if e.active==null or e.finished or e.active!=s or not valid_record(a.record) or a.record.run_id!=e.run_id or a.record.get("rule_version",1)!=s.version:return fail("invalid")
  n.finished=true;n.records.append(a.record.duplicate(true))
  n.records.sort_custom(func(x,y):return x.max_floor>y.max_floor if x.max_floor!=y.max_floor else (x.kills>y.kills if x.kills!=y.kills else (x.gold>y.gold if x.gold!=y.gold else x.run_id<y.run_id)))
  n.records=n.records.slice(0,10)
 else:return fail("invalid")
 var text=JSON.stringify(n)
 if text.length()>MAX_BYTES:return fail("limit")
 if test_fail_write:return fail("io_error")
 var temporary=path+".pending"
 var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return fail("io_error")
 file.store_string(text);file.flush()
 var err=file.get_error();file.close()
 if err!=OK:return fail("io_error")
 if DirAccess.rename_absolute(temporary,path)!=OK:return fail("io_error")
 return result(n)
