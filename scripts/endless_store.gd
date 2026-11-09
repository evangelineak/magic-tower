class_name TowerEndlessStore
extends RefCounted
## Separate device-only save. Never opens the classic journey/profile files.
const World=preload("res://scripts/endless_world.gd")
const MAX_BYTES:=2*1024*1024
const MAX_COUNTER:=10000000
const MILESTONES=[3,8,15,30,50]
const LEGACIES=["kit","coin","mind"]
const LEGACY_COSTS={"kit":1,"coin":2,"mind":2}
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
func initial_start(s:Dictionary)->bool:return int(s.version)<20 and s.actions.is_empty()
func initial_hero(s:Dictionary)->bool:return int(s.version)==20 and s.actions.size()==1 and s.actions[0] in ["hero_warden","hero_ranger","hero_scholar"]
func initial_legacy(s:Dictionary)->bool:return int(s.version)==21 and s.actions.size()==2 and s.actions[0] in ["hero_warden","hero_ranger","hero_scholar"] and s.actions[1] in ["legacy_none","legacy_kit","legacy_coin","legacy_mind"]
func active_initialized(s:Dictionary)->bool:
 if int(s.version)<20:return true
 if s.actions.is_empty() or s.actions[0] not in ["hero_warden","hero_ranger","hero_scholar"]:return false
 for code in s.actions.slice(1):
  if code.begins_with("hero_"):return false
 if int(s.version)==21:
  if s.actions.size()<2 or s.actions[1] not in ["legacy_none","legacy_kit","legacy_coin","legacy_mind"]:return false
  for code in s.actions.slice(2):
   if code.begins_with("legacy_"):return false
 return true
func has_commit_event(s:Dictionary)->bool:return not s.actions.is_empty() and not initial_hero(s) and not initial_legacy(s)
func canonical_snapshot(s:Dictionary)->Dictionary:
 return {"version":int(s.version),"mode":"endless","seed":int(s.seed),"actions":s.actions.duplicate()}
func valid_record(r)->bool:
 if not exact(r,["run_id","seed","max_floor","kills","gold","reason"]) and not exact(r,["run_id","seed","max_floor","kills","gold","reason","rule_version"]):return false
 if not World.supports_version(r.get("rule_version",1)):return false
 return integer(r.run_id,1) and integer(r.seed,0,2147483647) and integer(r.max_floor,1,1000000000) and integer(r.kills,0,1000000000) and integer(r.gold,0,1000000000) and r.reason in ["death","retired","action_limit"]
func fresh_profile()->Dictionary:return {"version":1,"milestones":[],"unlocks":[]}
func profile_points(p:Dictionary)->int:
 var spent:=0
 for id in p.unlocks:spent+=int(LEGACY_COSTS[id])
 return p.milestones.size()-spent
func valid_profile(p)->bool:
 if not exact(p,["version","milestones","unlocks"]) or not integer(p.version,1,1) or not p.milestones is Array or p.milestones.size()>5 or not p.unlocks is Array or p.unlocks.size()>3:return false
 for i in p.milestones.size():
  if not integer(p.milestones[i],0,50) or p.milestones[i]!=MILESTONES[i]:return false
 var last:=-1
 for id in p.unlocks:
  var at:int=LEGACIES.find(id)
  if at<=last:return false
  last=at
 return profile_points(p)>=0
func fresh()->Dictionary:return {"version":2,"revision":0,"run_id":0,"active":null,"finished":false,"records":[],"profile":fresh_profile(),"settlement":{}}
func valid_base(e:Dictionary)->bool:
 if not integer(e.revision) or not integer(e.run_id) or not e.finished is bool or not e.records is Array or e.records.size()>10:return false
 if e.active!=null:
  if not snapshot_shape(e.active) or not active_initialized(e.active):return false
 var seen:Dictionary={}
 for r in e.records:
  if not valid_record(r) or r.run_id>e.run_id or seen.has(r.run_id) or (not e.finished and r.run_id==e.run_id):return false
  seen[r.run_id]=true
 return (e.run_id==0 and e.active==null and not e.finished and e.records.is_empty()) or (e.run_id>0 and e.active!=null)
func valid_settlement(e:Dictionary)->bool:
 var receipt=e.settlement
 if exact(receipt,[]):return not e.finished or int(e.active.version)<21
 if not e.finished or not exact(receipt,["run_id","awarded","balance_after"]) or receipt.run_id!=e.run_id or not receipt.awarded is Array or receipt.awarded.size()>5 or not integer(receipt.balance_after,0,5):return false
 if receipt.balance_after<profile_points(e.profile) or receipt.balance_after>e.profile.milestones.size():return false
 var last:=0
 for value in receipt.awarded:
  if not integer(value,1,50) or value<=last or not e.profile.milestones.any(func(m):return m==value):return false
  last=int(value)
 return int(e.active.version)>=21 or receipt.awarded.is_empty()
func valid_envelope(e)->bool:
 if not e is Dictionary or not integer(e.get("version"),1,2):return false
 if e.get("version")==1:
  if not exact(e,["version","revision","run_id","active","finished","records"]) or not valid_base(e):return false
  if e.active!=null and int(e.active.version)>=21:return false
  for r in e.records:
   if int(r.get("rule_version",1))>=21:return false
  return true
 if e.get("version")!=2 or not exact(e,["version","revision","run_id","active","finished","records","profile","settlement"]) or not valid_base(e) or not valid_profile(e.profile) or not valid_settlement(e):return false
 if e.active!=null and int(e.active.version)==21:
  var id:String=str(e.active.actions[1]).trim_prefix("legacy_")
  if id!="none" and id not in e.profile.unlocks:return false
 return true
func normalize(e:Dictionary)->Dictionary:
 var n=e.duplicate(true)
 if int(n.version)==1:n.version=2;n.profile=fresh_profile();n.settlement={}
 n.profile.version=1;n.profile.milestones=n.profile.milestones.map(func(m):return int(m))
 if not n.settlement.is_empty():
  n.settlement.run_id=int(n.settlement.run_id);n.settlement.balance_after=int(n.settlement.balance_after);n.settlement.awarded=n.settlement.awarded.map(func(m):return int(m))
 return n
func result(e:Dictionary)->Dictionary:
 return {"ok":true,"status":"empty" if e.active==null else ("finished" if e.finished else "active"),"snapshot":{} if e.active==null else e.active.duplicate(true),"revision":int(e.revision),"run_id":int(e.run_id),"records":e.records.duplicate(true),"profile":e.profile.duplicate(true),"points":profile_points(e.profile),"settlement":e.settlement.duplicate(true)}
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
func validated_walk(base:Dictionary,s:Dictionary):
 if not snapshot_shape(base) or not snapshot_shape(s) or not int(base.version) in [10,11,12,13,14,15,16,17,18,19,20,21] or s.version!=base.version or base.seed!=s.seed:return null
 var count:int=s.actions.size()-base.actions.size()
 if count<1 or count>224 or s.actions.slice(0,base.actions.size())!=base.actions:return null
 for code in s.actions.slice(base.actions.size()):
  if code not in ["U","D","L","R"]:return null
 var original=validated(base)
 if original==null or original.ended:return null
 var candidate=original.clone()
 var moved:Dictionary=candidate.return_to_camp()
 if not moved.get("changed",false) or candidate.save_data()!=s:return null
 return candidate
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
 return {"ok":true,"envelope":normalize(e)}
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
func start_hero(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("start_hero",snapshot,expected_revision)
func start_legacy(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("start_legacy",snapshot,expected_revision)
func unlock_legacy(id:String,expected_revision:int)->Dictionary:
 if id not in LEGACIES or not integer(expected_revision):return fail("invalid")
 var current=await read()
 if not current.get("ok",false):return current
 var args={"legacy_id":id,"expected_revision":expected_revision}
 if use_web:return await web("unlock_legacy",args)
 return native_transaction("unlock_legacy",args)
func commit(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("commit",snapshot,expected_revision)
func commit_walk(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("commit_walk",snapshot,expected_revision)
func finish(snapshot:Dictionary,expected_revision:int)->Dictionary:return await write("finish",snapshot,expected_revision)
func write(operation:String,s:Dictionary,expected:int)->Dictionary:
 if not snapshot_shape(s) or JSON.stringify(s).length()>MAX_BYTES:return fail("invalid")
 s=canonical_snapshot(s)
 if operation=="start" and not initial_start(s):return fail("invalid")
 if operation=="start_hero" and not initial_hero(s):return fail("invalid")
 if operation=="start_legacy" and not initial_legacy(s):return fail("invalid")
 var current=await read()
 if not current.get("ok",false):return current
 var previous_ended:bool=current.status!="empty" and validated(current.snapshot).ended
 if operation=="finish" and not previous_ended:return fail("invalid")
 # Validate before writes; clone/apply-one never trusts a new history prefix.
 var w=null
 if operation=="commit_walk":
  if not int(s.version) in [10,11,12,13,14,15,16,17,18,19,20,21]:return fail("invalid")
  var acknowledged:bool=current.status=="active" and current.snapshot==s and expected==current.revision-1
  if acknowledged:w=validated(s)
  else:
   if expected!=current.revision:return fail("conflict")
   if current.status!="active":return fail("invalid")
   w=validated_walk(current.snapshot,s)
 else:w=validated(s)
 if w==null:return fail("invalid")
 var r:Dictionary={}
 if operation=="finish":
  if not w.ended:return fail("invalid")
  r={"run_id":current.run_id,"seed":w.seed,"max_floor":w.max_floor,"kills":w.kills,"gold":w.gold,"reason":w.ended_reason,"rule_version":int(s.version)}
  if not valid_record(r):return fail("invalid")
 var args={"snapshot":s,"expected_revision":expected,"record":r,"previous_ended":previous_ended}
 if use_web:
  var reply:Dictionary=await web(operation,args)
  if reply.get("ok",false) and operation=="commit_walk":cache_world=w;cache_snapshot=s.duplicate(true)
  return reply
 var outcome=native_transaction(operation,args)
 if outcome.get("ok",false) and operation=="commit_walk":cache_world=w;cache_snapshot=s.duplicate(true)
 return outcome
func native_transaction(operation:String,args:Dictionary)->Dictionary:
 var directory=path.get_base_dir()
 if DirAccess.make_dir_recursive_absolute(directory)!=OK and not DirAccess.dir_exists_absolute(directory):return fail("io_error")
 var lock_path=path+".lock"
 if not acquire_native_lock(lock_path):return fail("locked")
 var outcome=native_write_locked(operation,args)
 DirAccess.remove_absolute(lock_path+"/owner.json");DirAccess.remove_absolute(lock_path)
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
 var e:Dictionary=loaded.envelope;var expected:int=a.expected_revision
 if operation=="unlock_legacy":
  if a.legacy_id in e.profile.unlocks:return result(e)
  if expected!=int(e.revision):return fail("conflict")
  if e.revision>=MAX_COUNTER:return fail("limit")
  if profile_points(e.profile)<int(LEGACY_COSTS[a.legacy_id]):return fail("insufficient_points")
  var unlocked=e.duplicate(true);unlocked.revision=int(e.revision)+1
  unlocked.profile.unlocks=LEGACIES.filter(func(id):return id==a.legacy_id or id in e.profile.unlocks)
  return save_native_envelope(unlocked)
 var s:Dictionary=a.snapshot
 if operation=="finish" and e.finished and e.active==s and expected<=int(e.revision):return result(e)
 if not e.finished and e.active==s and expected==int(e.revision)-1 and ((operation=="start" and initial_start(s)) or (operation=="start_hero" and initial_hero(s)) or (operation=="start_legacy" and initial_legacy(s)) or (operation=="commit" and has_commit_event(s)) or (operation=="commit_walk" and int(s.version) in [10,11,12,13,14,15,16,17,18,19,20,21] and has_commit_event(s))):return result(e)
 if expected!=int(e.revision):return fail("conflict")
 if e.revision>=MAX_COUNTER:return fail("limit")
 var n=e.duplicate(true);n.revision=int(n.revision)+1
 if operation in ["start","start_hero","start_legacy"]:
  if operation=="start" and not initial_start(s):return fail("invalid")
  if operation=="start_hero" and not initial_hero(s):return fail("invalid")
  if operation=="start_legacy" and not initial_legacy(s):return fail("invalid")
  if e.run_id>=MAX_COUNTER:return fail("limit")
  if e.active!=null and not e.finished:
   var previous=validated(e.active)
   if previous==null:return fail("corrupt")
   if previous.ended:return fail("pending_settlement")
  if operation=="start_legacy":
   var id:String=str(s.actions[1]).trim_prefix("legacy_")
   if id!="none" and id not in e.profile.unlocks:return fail("locked_legacy")
  n.run_id=int(n.run_id)+1;n.active=s.duplicate(true);n.finished=false;n.settlement={}
 elif operation=="commit":
  if e.active==null or e.finished or s.version!=e.active.version or s.seed!=e.active.seed or s.actions.size()!=e.active.actions.size()+1 or s.actions.slice(0,-1)!=e.active.actions:return fail("invalid")
  n.active=s.duplicate(true)
 elif operation=="commit_walk":
  if e.active==null or e.finished or validated_walk(e.active,s)==null:return fail("invalid")
  n.active=s.duplicate(true)
 elif operation=="finish":
  if e.active==null or e.finished or e.active!=s or not valid_record(a.record) or a.record.run_id!=e.run_id or a.record.get("rule_version",1)!=s.version:return fail("invalid")
  var awarded:Array=[]
  if int(s.version)==21:
   for milestone in MILESTONES:
    if milestone<=int(a.record.max_floor) and milestone not in e.profile.milestones:awarded.append(milestone)
  n.profile.milestones.append_array(awarded);n.finished=true
  n.settlement={"run_id":int(e.run_id),"awarded":awarded,"balance_after":profile_points(n.profile)}
  n.records.append(a.record.duplicate(true))
  n.records.sort_custom(func(x,y):return x.max_floor>y.max_floor if x.max_floor!=y.max_floor else (x.kills>y.kills if x.kills!=y.kills else (x.gold>y.gold if x.gold!=y.gold else x.run_id<y.run_id)))
  n.records=n.records.slice(0,10)
 else:return fail("invalid")
 return save_native_envelope(n)
func save_native_envelope(n:Dictionary)->Dictionary:
 if not valid_envelope(n):return fail("invalid")
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
