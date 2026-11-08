class_name TowerLegacyStoreNative
extends RefCounted
## Isolated native persistence PROTOTYPE. Never touches the game's save path.
## Snapshot validation below is a six-field bounded stub, NOT World validation.
## Atomic rename protects whole-file publication. Godot flush is not a promise
## of power-loss durability/fsync of the parent directory on every platform.
const Profile=preload("res://scripts/legacy_profile.gd")
const MAX_BYTES=16*1024*1024
const MAX_COUNTER=10000000
var root:String
var safe_path:=false
var test_fail_at:=""
var _lock_token:=""
func _init(path:String="user://legacy-native-prototype-v1"):
	var prefix:="user://legacy-native-prototype-"
	if path.begins_with(prefix):
		var suffix:=path.trim_prefix(prefix)
		safe_path=not suffix.is_empty()
		for c in suffix:
			if not ((c>="a" and c<="z") or (c>="A" and c<="Z") or (c>="0" and c<="9") or c in ["-","_"]): safe_path=false
	root=ProjectSettings.globalize_path(path) if safe_path else ""
func _error(code:String)->Dictionary: return {"ok":false,"code":code}
func _int(value,low:int=0,high:int=MAX_COUNTER)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and floor(float(value))==value
func _keys(value,keys:Array)->bool:
	if not value is Dictionary or value.size()!=keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true
func _now()->int: return int(Time.get_unix_time_from_system()*1000.0)
func _uuid()->String: return Crypto.new().generate_random_bytes(16).hex_encode()
func _snapshot(value)->Dictionary:
	if not _keys(value,["seed_value","floor_seen","floor","hp","moves","won"]): return {}
	if not _int(value.seed_value,0,2147483647) or not _int(value.moves) or not _int(value.hp,1): return {}
	if not value.won is bool or not value.floor_seen is Array or value.floor_seen.size() not in [5,8]: return {}
	if not _int(value.floor,0,value.floor_seen.size()-1): return {}
	var gap:=false
	for seen in value.floor_seen:
		if not seen is bool or (gap and seen): return {}
		if not seen: gap=true
	if not value.floor_seen[0] or not value.floor_seen[int(value.floor)]: return {}
	return {"seed_value":int(value.seed_value),"floor_seen":value.floor_seen.duplicate(),"floor":int(value.floor),"hp":int(value.hp),"moves":int(value.moves),"won":value.won}
func _summary(snapshot,outcome)->Dictionary:
	var s:=_snapshot(snapshot)
	if s.is_empty() or outcome not in ["withdrawn","chapter1","victory"]: return {}
	var peak:=0
	for f in range(s.floor_seen.size()):
		if s.floor_seen[f]: peak=f+1
	if outcome=="chapter1" and (not s.won or s.floor_seen.size()!=5 or peak!=5): return {}
	if outcome=="victory" and (not s.won or s.floor_seen.size()!=8 or peak!=8): return {}
	return {"seed":s.seed_value,"max_floor":peak,"moves":s.moves,"outcome":outcome}
func _fresh()->Dictionary:
	return {"schema":1,"storageRevision":0,"profile":{"id":"local","commitRevision":0,"profile":Profile.fresh()},"runs":{},"slot":{"id":"active","revision":0,"activeRunId":null,"lastFence":0,"writer":null}}
func _valid(data)->bool:
	if not _keys(data,["schema","storageRevision","profile","runs","slot"]) or not _int(data.schema,1,1) or not _int(data.storageRevision): return false
	if not _keys(data.profile,["id","commitRevision","profile"]) or data.profile.id!="local" or not _int(data.profile.commitRevision): return false
	if not Profile.validate(data.profile.profile).ok or data.profile.commitRevision!=data.profile.profile.receipts.size(): return false
	if not data.runs is Dictionary or data.runs.size()>4096: return false
	var slot=data.slot
	if not _keys(slot,["id","revision","activeRunId","lastFence","writer"]) or slot.id!="active" or not _int(slot.revision) or not _int(slot.lastFence): return false
	if slot.writer!=null:
		if not _keys(slot.writer,["owner","fence","leaseUntil"]): return false
		if not slot.writer.owner is String or slot.writer.owner.is_empty() or slot.writer.owner.length()>=200: return false
		if not _int(slot.writer.fence,1) or slot.writer.fence!=slot.lastFence or not _int(slot.writer.leaseUntil,0,9007199254740991): return false
	elif slot.lastFence!=0: return false
	var active_count:=0
	for id in data.runs:
		var run=data.runs[id]
		if not Profile.valid_run_id(id) or not _keys(run,["id","revision","status","snapshot"]) or run.id!=id or not _int(run.revision): return false
		if run.status not in ["active","archived","abandoned"] or _snapshot(run.snapshot).is_empty(): return false
		if run.status=="active":
			active_count+=1
			if slot.activeRunId!=id: return false
		if run.status=="archived":
			if not data.profile.profile.receipts.has(id): return false
			var receipt:Dictionary=data.profile.profile.receipts[id]
			if _summary(run.snapshot,receipt.summary.outcome)!=Profile._summary(receipt.summary): return false
		elif data.profile.profile.receipts.has(id): return false
	for id in data.profile.profile.receipts:
		if not data.runs.has(id): return false
	if slot.activeRunId==null:
		if not data.runs.is_empty() or active_count!=0: return false
	elif not Profile.valid_run_id(slot.activeRunId) or not data.runs.has(slot.activeRunId) or data.runs[slot.activeRunId].status=="abandoned": return false
	return active_count<=1
func _file(name:String)->String: return root.path_join(name)
func _verified(path:String)->Dictionary:
	if not FileAccess.file_exists(path): return _error("MISSING")
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()>MAX_BYTES: return _error("CORRUPT_STORE")
	var text:=f.get_as_text(); f.close()
	var parser:=JSON.new()
	if parser.parse(text)!=OK: return _error("CORRUPT_STORE")
	var outer=parser.data
	if not _keys(outer,["format","payload","sha256"]) or not _int(outer.format,1,1) or not outer.payload is String or not outer.sha256 is String: return _error("CORRUPT_STORE")
	if outer.payload.sha256_text()!=outer.sha256: return _error("CORRUPT_STORE")
	if parser.parse(outer.payload)!=OK: return _error("CORRUPT_STORE")
	var data=parser.data
	if not _valid(data): return _error("CORRUPT_STORE")
	return {"ok":true,"data":data}
func _load()->Dictionary:
	var primary:=_verified(_file("store.json"))
	if primary.ok: return primary
	var backup:=_verified(_file("store.bak"))
	if FileAccess.file_exists(_file("store.json")) or FileAccess.file_exists(_file("store.tmp")) or FileAccess.file_exists(_file("backup.tmp")) or FileAccess.file_exists(_file("store.bak")) or DirAccess.dir_exists_absolute(_file("store.json")):
		return {"ok":false,"code":"CORRUPT_STORE","backup_available":backup.ok}
	return _error("EMPTY_STORE")
func read()->Dictionary:
	if not safe_path: return _error("UNSAFE_PATH")
	if not DirAccess.dir_exists_absolute(root): return _error("EMPTY_STORE")
	if not _lock(): return _error("STORE_LOCKED")
	var result:=_load()
	_unlock()
	return result
func readRun(id:String)->Dictionary:
	var result:=read()
	if not result.ok: return result
	if not result.data.runs.has(id): return _error("RUN_NOT_FOUND")
	return {"ok":true,"run":result.data.runs[id].duplicate(true)}
func readProfile()->Dictionary:
	var result:=read()
	return {"ok":true,"profile":result.data.profile.profile.duplicate(true)} if result.ok else result
func readSlot()->Dictionary:
	var result:=read()
	return {"ok":true,"slot":result.data.slot.duplicate(true)} if result.ok else result
func readReceipt(id:String)->Dictionary:
	var result:=read()
	if not result.ok: return result
	return {"ok":true,"receipt":result.data.profile.profile.receipts.get(id,{}).duplicate(true)}
func _lock()->bool:
	if DirAccess.make_dir_absolute(_file(".writer-lock"))!=OK: return false
	_lock_token=_uuid()
	var f:=FileAccess.open(_file(".writer-lock/owner"),FileAccess.WRITE)
	if f==null: DirAccess.remove_absolute(_file(".writer-lock")); return false
	f.store_string(_lock_token); f.flush(); f.close()
	return true
func _unlock():
	if FileAccess.get_file_as_string(_file(".writer-lock/owner"))!=_lock_token: return
	DirAccess.remove_absolute(_file(".writer-lock/owner")); DirAccess.remove_absolute(_file(".writer-lock")); _lock_token=""
func _commit(data:Dictionary)->Dictionary:
	data.storageRevision=int(data.storageRevision)+1
	if not _valid(data): return _error("INVALID_COMMIT")
	if test_fail_at=="before_temp": return _error("INJECTED_BEFORE_TEMP")
	var payload:=JSON.stringify(data)
	if payload.length()>MAX_BYTES-1024: return _error("STORE_FULL")
	var f:=FileAccess.open(_file("store.tmp"),FileAccess.WRITE)
	if f==null: return _error("WRITE_FAILED")
	f.store_string(JSON.stringify({"format":1,"payload":payload,"sha256":payload.sha256_text()})); f.flush()
	var write_error:=f.get_error(); f.close()
	if write_error!=OK or not _verified(_file("store.tmp")).ok: return _error("WRITE_FAILED")
	if test_fail_at=="after_temp": return _error("INJECTED_AFTER_TEMP")
	if FileAccess.file_exists(_file("store.json")):
		if not _verified(_file("store.json")).ok: return _error("CORRUPT_STORE")
		if DirAccess.copy_absolute(_file("store.json"),_file("backup.tmp"))!=OK or not _verified(_file("backup.tmp")).ok: return _error("BACKUP_FAILED")
		if DirAccess.rename_absolute(_file("backup.tmp"),_file("store.bak"))!=OK: return _error("BACKUP_FAILED")
	if test_fail_at in ["after_backup","before_rename"]: return _error("INJECTED_BEFORE_RENAME")
	if DirAccess.rename_absolute(_file("store.tmp"),_file("store.json"))!=OK: return _error("RENAME_FAILED")
	if test_fail_at=="after_rename": return _error("AMBIGUOUS_COMMIT")
	return {"ok":true}
func initialize()->Dictionary:
	if not safe_path: return _error("UNSAFE_PATH")
	if DirAccess.make_dir_recursive_absolute(root)!=OK: return _error("WRITE_FAILED")
	if not _lock(): return _error("STORE_LOCKED")
	var loaded:=_load(); var result:Dictionary
	if loaded.ok: result={"ok":true,"status":"existing"}
	elif loaded.code!="EMPTY_STORE": result=loaded
	else:
		var directory:=DirAccess.open(root); var unknown:=false
		for name in directory.get_files(): unknown=true
		for name in directory.get_directories():
			if name!=".writer-lock": unknown=true
		result=_error("HISTORY_WITHOUT_PRIMARY") if unknown else _commit(_fresh())
	_unlock(); return result
func _auth(slot:Dictionary,auth,active_id=null)->String:
	if not auth is Dictionary or not auth.get("owner") is String or not _int(auth.get("fence"),1) or not _int(auth.get("expectedSlotRevision")): return "STALE_WRITER"
	if slot.writer==null or slot.writer.owner!=auth.owner or slot.writer.fence!=auth.fence or slot.writer.leaseUntil<=_now(): return "STALE_WRITER"
	if slot.revision!=auth.expectedSlotRevision: return "STALE_SLOT_REVISION"
	if active_id!=null and slot.activeRunId!=active_id: return "NOT_ACTIVE_RUN"
	return ""
func _operation(data:Dictionary,op:String,args:Dictionary)->Dictionary:
	var slot:Dictionary=data.slot
	if op in ["claim","renew"]:
		var ms=args.ms
		if not _int(ms,50,60000): return _error("INVALID_LEASE")
		if op=="claim":
			if not args.owner is String or args.owner.is_empty() or args.owner.length()>=200: return _error("INVALID_LEASE")
			if slot.writer!=null and slot.writer.leaseUntil>_now():
				if slot.writer.owner!=args.owner: return _error("WRITER_BUSY")
			else:
				slot.lastFence=int(slot.lastFence)+1
				slot.writer={"owner":args.owner,"fence":slot.lastFence,"leaseUntil":0}
		else:
			var error:=_auth(slot,args.auth)
			if error!="": return _error(error)
		slot.writer.leaseUntil=_now()+int(ms)
		var auth:Dictionary=slot.writer.duplicate(); auth.expectedSlotRevision=slot.revision
		return {"ok":true,"auth":auth,"changed":true}
	if op=="settle":
		if not data.runs.has(args.id): return _error("RUN_NOT_FOUND")
		var summary:=_summary(data.runs[args.id].snapshot,args.outcome)
		if summary.is_empty(): return _error("INVALID_OUTCOME")
		if data.profile.profile.receipts.has(args.id):
			var duplicate:=Profile.settle(data.profile.profile,args.id,summary)
			duplicate.erase("profile"); duplicate.changed=false
			return duplicate
	var error:=_auth(slot,args.auth,args.get("id"))
	if error!="": return _error(error)
	if op=="create":
		var copied:=_snapshot(args.snapshot)
		if copied.is_empty(): return _error("INVALID_SNAPSHOT")
		if data.runs.size()>=4096: return _error("RUNS_FULL")
		if slot.activeRunId!=null and data.runs[slot.activeRunId].status=="active":
			if args.replace!=true: return _error("ACTIVE_RUN_EXISTS")
			data.runs[slot.activeRunId].status="abandoned"; data.runs[slot.activeRunId].revision=int(data.runs[slot.activeRunId].revision)+1
		var id:=_uuid()
		if data.runs.has(id) or data.profile.profile.receipts.has(id): return _error("ID_COLLISION")
		var run:Dictionary={"id":id,"revision":0,"status":"active","snapshot":copied}
		data.runs[id]=run; slot.activeRunId=id; slot.revision=int(slot.revision)+1
		return {"ok":true,"run":run.duplicate(true),"slotRevision":slot.revision,"changed":true}
	if not data.runs.has(args.id) or data.runs[args.id].status!="active": return _error("RUN_NOT_ACTIVE")
	var run:Dictionary=data.runs[args.id]
	if not _int(args.expected) or run.revision!=args.expected: return _error("STALE_REVISION")
	if op=="save":
		var copied:=_snapshot(args.snapshot)
		if copied.is_empty(): return _error("INVALID_SNAPSHOT")
		run.snapshot=copied; run.revision=int(run.revision)+1
		return {"ok":true,"run":run.duplicate(true),"changed":true}
	if op=="settle":
		var settled:=Profile.settle(data.profile.profile,args.id,_summary(run.snapshot,args.outcome))
		if not settled.ok: return settled
		data.profile.profile=settled.profile; data.profile.commitRevision=int(data.profile.commitRevision)+1
		run.status="archived"; run.revision=int(run.revision)+1; slot.revision=int(slot.revision)+1
		settled.erase("profile"); settled.slotRevision=slot.revision; settled.changed=true
		return settled
	return _error("UNKNOWN_OPERATION")
func _mutate(op:String,args:Dictionary)->Dictionary:
	if not safe_path: return _error("UNSAFE_PATH")
	if not DirAccess.dir_exists_absolute(root): return _error("EMPTY_STORE")
	if not _lock(): return _error("STORE_LOCKED")
	var loaded:=_load(); var result:=loaded
	if loaded.ok:
		var data:Dictionary=loaded.data.duplicate(true)
		result=_operation(data,op,args)
		if result.ok and result.get("changed",false):
			var commit:=_commit(data)
			if not commit.ok: result=commit
		result.erase("changed")
	_unlock(); return result
func claimWriter(owner,lease_ms=15000)->Dictionary: return _mutate("claim",{"owner":owner,"ms":lease_ms})
func renewWriter(auth,lease_ms=15000)->Dictionary: return _mutate("renew",{"auth":auth,"ms":lease_ms})
func createRun(auth,snapshot,replace_active:bool=false)->Dictionary: return _mutate("create",{"auth":auth,"snapshot":snapshot,"replace":replace_active})
func saveRun(id:String,auth,expected_revision,snapshot)->Dictionary: return _mutate("save",{"id":id,"auth":auth,"expected":expected_revision,"snapshot":snapshot})
func settleRun(id:String,auth,expected_revision,outcome:String)->Dictionary: return _mutate("settle",{"id":id,"auth":auth,"expected":expected_revision,"outcome":outcome})
