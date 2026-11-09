extends SceneTree
const Store=preload("res://scripts/legacy_store_native.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func snapshot(peak:int=1,won:bool=false,seed:int=42)->Dictionary:
	var seen:Array=[]
	for f in range(8 if peak>5 else 5): seen.append(f<peak)
	return {"seed_value":seed,"floor_seen":seen,"floor":peak-1,"hp":100,"moves":peak*10,"won":won}
func new_store():
	var store=Store.new("user://legacy-native-prototype-test-"+Crypto.new().generate_random_bytes(8).hex_encode())
	check(store.read().code=="EMPTY_STORE","absent path is explicitly empty, not silently a profile")
	check(store.initialize().ok,"explicit isolated initialize")
	return store
func auth_for(store,owner:String="window_A")->Dictionary:
	var claimed:Dictionary=store.claimWriter(owner)
	check(claimed.ok,"claim writer")
	return claimed.auth
func bytes(store)->String: return FileAccess.get_file_as_string(store.root.path_join("store.json"))
func put_payload(store,payload:Dictionary):
	var text:=JSON.stringify(payload)
	var file:=FileAccess.open(store.root.path_join("store.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":1,"payload":text,"sha256":text.sha256_text()})); file.flush(); file.close()
func race_worker(args:PackedStringArray):
	var store=Store.new(args[1])
	var control:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(store.root.path_join("race-control.json")))
	var ready:=FileAccess.open(store.root.path_join("ready-"+args[2]),FileAccess.WRITE)
	ready.store_string("ready"); ready.close()
	var deadline:=Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(store.root.path_join("race-go")) and Time.get_ticks_msec()<deadline:
		OS.delay_msec(2)
	var result:Dictionary=store.saveRun(control.id,control.auth,0,control.snapshot)
	var output:=FileAccess.open(store.root.path_join("result-"+args[2]+".json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(result)); output.flush(); output.close()
	quit()
func process_race():
	var store=new_store(); var auth:=auth_for(store)
	var run:Dictionary=store.createRun(auth,snapshot()); auth.expectedSlotRevision=run.slotRevision
	var control:=FileAccess.open(store.root.path_join("race-control.json"),FileAccess.WRITE)
	control.store_string(JSON.stringify({"id":run.run.id,"auth":auth,"snapshot":snapshot(3)})); control.close()
	var prefix:String="user://"+store.root.get_file()
	var pids:Array=[]
	for label in ["a","b"]:
		pids.append(OS.create_process(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_legacy_store_native.gd","--","native-race",prefix,label]))
	check(pids[0]>0 and pids[1]>0 and pids[0]!=pids[1],"two real Godot worker processes launched")
	var deadline:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and not (FileAccess.file_exists(store.root.path_join("ready-a")) and FileAccess.file_exists(store.root.path_join("ready-b"))):
		OS.delay_msec(5)
	check(FileAccess.file_exists(store.root.path_join("ready-a")) and FileAccess.file_exists(store.root.path_join("ready-b")),"both processes reached shared start barrier")
	var go:=FileAccess.open(store.root.path_join("race-go"),FileAccess.WRITE); go.store_string("go"); go.close()
	deadline=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and not (FileAccess.file_exists(store.root.path_join("result-a.json")) and FileAccess.file_exists(store.root.path_join("result-b.json"))):
		OS.delay_msec(5)
	var results:Array=[]
	for label in ["a","b"]:
		var path:String=store.root.path_join("result-"+label+".json")
		if FileAccess.file_exists(path): results.append(JSON.parse_string(FileAccess.get_file_as_string(path)))
	check(results.size()==2,"both real processes returned race results")
	if results.size()==2:
		var winners:=0
		for result in results:
			if result.get("ok",false): winners+=1
			else: check(result.get("code") in ["STORE_LOCKED","STALE_REVISION"],"losing process is rejected by lock or CAS")
		check(winners==1,"exactly one process publishes the shared expected revision")
		var loaded:Dictionary=store.readRun(run.run.id)
		check(loaded.ok and loaded.run.revision==1 and loaded.run.snapshot.floor==2,"race leaves one complete valid authoritative snapshot")
	print("NATIVE REAL PROCESS RACE: pids=%s results=%s evidence=%s"%[pids,results,store.root])
func _init():
	var args:=OS.get_cmdline_user_args()
	if args.size()==3 and args[0]=="native-race":
		race_worker(args)
		return
	var unsafe=Store.new("user://journey-v4.json")
	check(not unsafe.initialize().ok and unsafe.read().code=="UNSAFE_PATH","prototype cannot touch production save path")
	check(not Store.new("user://legacy-native-prototype-../journey").safe_path,"path traversal rejected")
	var s=new_store(); var auth:=auth_for(s)
	var run:=s.createRun(auth,snapshot(3))
	check(run.ok and run.run.revision==0 and run.run.id.length()==32,"new run gets a genuine native-generated identifier")
	var id:String=run.run.id; auth.expectedSlotRevision=run.slotRevision
	var other=Store.new("user://legacy-native-prototype-"+s.root.get_file().trim_prefix("legacy-native-prototype-"))
	check(other.read().ok,"second adapter reads the same isolated container")
	check(other.claimWriter("window_B").code=="WRITER_BUSY","unexpired writer cannot be stolen")
	var before:=bytes(s)
	check(s.saveRun(id,auth,7,snapshot(4)).code=="STALE_REVISION" and bytes(s)==before,"stale run CAS never publishes")
	var saved:=s.saveRun(id,auth,0,snapshot(5,true))
	check(saved.ok and saved.run.revision==1,"save increments only run revision")
	check(s.readSlot().slot.revision==auth.expectedSlotRevision,"save does not switch global active pointer")
	var settled:=s.settleRun(id,auth,1,"chapter1")
	check(settled.ok and settled.status=="applied" and settled.new_unlocks==["legacy_scout","legacy_tactician"],"summary is derived from stored peak and one receipt awards milestones")
	before=bytes(s)
	var duplicate:=s.settleRun(id,{},0,"chapter1")
	check(duplicate.ok and duplicate.status=="duplicate" and duplicate.new_unlocks.is_empty() and bytes(s)==before,"read-only retry returns same receipt without committing again")
	check(s.settleRun(id,{},0,"withdrawn").status=="conflict" and bytes(s)==before,"a different requested outcome cannot replace receipt")
	check(s.createRun(auth,snapshot()).code=="STALE_SLOT_REVISION","settlement invalidates old slot revision")
	auth.expectedSlotRevision=settled.slotRevision
	var second:=s.createRun(auth,snapshot()); auth.expectedSlotRevision=second.slotRevision
	check(second.ok and second.run.id!=id,"same seed replay is a different run identity")
	check(s.saveRun(id,auth,2,snapshot()).code=="NOT_ACTIVE_RUN","closed historical run cannot overwrite current active slot")
	before=bytes(s)
	check(s.createRun(auth,snapshot()).code=="ACTIVE_RUN_EXISTS" and bytes(s)==before,"replacement requires explicit intent")
	var old_auth:=auth.duplicate(); var third:=s.createRun(auth,snapshot(),true)
	check(third.ok and s.readRun(second.run.id).run.status=="abandoned","explicit replacement archives old active as abandoned")
	auth.expectedSlotRevision=third.slotRevision
	check(s.saveRun(second.run.id,old_auth,0,snapshot(5,true)).code=="STALE_SLOT_REVISION","old window revision cannot save old run after a new run exists")
	check(s.saveRun(second.run.id,auth,0,snapshot(5,true)).code=="NOT_ACTIVE_RUN","even refreshed slot revision cannot target previous run")
	check(s.readReceipt(id).receipt==s.readProfile().profile.receipts[id],"receipt and profile share one source of truth")
	var malformed:=snapshot(3); malformed.floor_seen=[true,false,true,false,false]
	check(s.saveRun(third.run.id,auth,0,malformed).code=="INVALID_SNAPSHOT","highest seen floor cannot be forged through holes in stub")
	malformed=snapshot(); malformed.max_floor=8
	check(s.saveRun(third.run.id,auth,0,malformed).code=="INVALID_SNAPSHOT","caller cannot supply settlement summary fields")
	check(s.settleRun(third.run.id,auth,0,"victory").code=="INVALID_OUTCOME","not-won stub cannot request victory")
	check(s.settleRun(third.run.id,auth,0,"defeat").code=="INVALID_OUTCOME","death deliberately not implemented in this positive-HP stub")
	# Real elapsed lease expiry: a new fence defeats the old writer globally.
	var lease_store=new_store(); var short:Dictionary=lease_store.claimWriter("old",50).auth
	OS.delay_msec(80)
	var takeover:Dictionary=lease_store.claimWriter("new").auth
	check(takeover.fence>short.fence,"lease takeover increments the global fence")
	check(lease_store.createRun(short,snapshot()).code=="STALE_WRITER","expired writer cannot create a new run over the current writer")
	check(lease_store.renewWriter(short).code=="STALE_WRITER","expired fence cannot renew itself")
	# Every injected pre-publication failure leaves the complete authoritative
	# primary unchanged, including profile, run, receipt and active pointer.
	for failure in ["before_temp","after_temp","after_backup","before_rename"]:
		var f=new_store(); var a:=auth_for(f); var r:=f.createRun(a,snapshot(5,true)); a.expectedSlotRevision=r.slotRevision
		var untouched:=bytes(f); f.test_fail_at=failure
		var result:Dictionary=f.settleRun(r.run.id,a,0,"chapter1")
		check(not result.ok and bytes(f)==untouched,"pre-rename injected failure never half-commits: "+failure)
		check(f.readProfile().profile.receipts.is_empty() and f.readRun(r.run.id).run.status=="active","failed commit never issues a receipt or archives run")
		f.test_fail_at=""
		check(f.settleRun(r.run.id,a,0,"chapter1").ok,"retry after failed write commits once")
	var lost=new_store(); var lost_auth:=auth_for(lost); var lost_run:=lost.createRun(lost_auth,snapshot(8,true)); lost_auth.expectedSlotRevision=lost_run.slotRevision
	lost.test_fail_at="after_rename"
	check(lost.settleRun(lost_run.run.id,lost_auth,0,"victory").code=="AMBIGUOUS_COMMIT","lost response after publication is explicitly ambiguous")
	lost.test_fail_at=""
	var retry:Dictionary=lost.settleRun(lost_run.run.id,lost_auth,0,"victory")
	check(retry.ok and retry.status=="duplicate" and retry.new_unlocks.is_empty(),"published but unacknowledged settlement safely retries")
	# Busy short filesystem lock is never stolen, even if it looks old.
	var lock_path:String=s.root.path_join(".writer-lock")
	check(DirAccess.make_dir_absolute(lock_path)==OK,"test acquires isolated filesystem lock")
	before=bytes(s)
	check(s.read().code=="STORE_LOCKED","reader cannot confuse in-progress initialization with corruption")
	check(s.saveRun(third.run.id,auth,0,snapshot(2)).code=="STORE_LOCKED" and bytes(s)==before,"occupied directory lock blocks writers")
	DirAccess.remove_absolute(lock_path)
	# An ordinary write failure can be induced portably without chmod tricks.
	check(DirAccess.make_dir_absolute(s.root.path_join("store.tmp"))==OK,"test blocks temporary-file creation")
	before=bytes(s)
	check(s.saveRun(third.run.id,auth,0,snapshot(2)).code=="WRITE_FAILED" and bytes(s)==before,"unwritable temporary target leaves primary untouched")
	DirAccess.remove_absolute(s.root.path_join("store.tmp"))
	# A valid backup is evidence for explicit recovery, NOT permission to
	# silently lose the latest receipt by falling back and awarding again.
	var corrupt=new_store(); var ca:=auth_for(corrupt); var cr:=corrupt.createRun(ca,snapshot(5,true)); ca.expectedSlotRevision=cr.slotRevision
	check(corrupt.settleRun(cr.run.id,ca,0,"chapter1").ok,"corrupt-store fixture settled first")
	var file:=FileAccess.open(corrupt.root.path_join("store.json"),FileAccess.WRITE); file.store_string("{broken"); file.close()
	var broken:Dictionary=corrupt.read()
	check(not broken.ok and broken.code=="CORRUPT_STORE" and broken.backup_available,"bad primary reports verified backup without accepting its older state")
	check(not corrupt.initialize().ok and not corrupt.claimWriter("new").ok,"corruption cannot silently reinitialize or issue awards")
	var semantic=new_store(); var payload:Dictionary=semantic.read().data
	payload.profile.profile.unlocked=["legacy_veteran"]
	put_payload(semantic,payload)
	check(semantic.read().code=="CORRUPT_STORE","valid hash cannot conceal invalid profile semantics")
	var orphan=Store.new("user://legacy-native-prototype-orphan-"+Crypto.new().generate_random_bytes(8).hex_encode())
	DirAccess.make_dir_recursive_absolute(orphan.root)
	file=FileAccess.open(orphan.root.path_join("store.tmp"),FileAccess.WRITE); file.store_string("partial"); file.close()
	check(not orphan.initialize().ok,"orphaned temporary history never becomes fresh automatically")
	# Bounded ledger never deletes old or abandoned runs to make room.
	var full=new_store(); var fa:=auth_for(full); payload=full.read().data
	for i in range(4096):
		var key:="filled_run_%020d"%i
		payload.runs[key]={"id":key,"revision":0,"status":"abandoned" if i<4095 else "active","snapshot":snapshot()}
		if i==4095: payload.slot.activeRunId=key
	put_payload(full,payload); before=bytes(full)
	check(full.read().ok and full.createRun(fa,snapshot(),true).code=="RUNS_FULL" and bytes(full)==before,"4096-run cap refuses rather than evicts history")
	process_race()
	print("NATIVE LEGACY STORE: %d checks, failures=%d; isolated prototype only"%[checks,failures])
	quit(1 if failures else 0)
