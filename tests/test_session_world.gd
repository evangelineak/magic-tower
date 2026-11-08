extends SceneTree
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
const ID="session_test_run_000001"
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func canonical(w)->String: return JSON.stringify(w.save_data())
func replay(w,route:String):
	for c in route:
		check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"actual witness")
func terminal(w):
	var before:=canonical(w)
	check(not w.step(Vector2i.RIGHT),"terminal rejects step")
	check(not w.action("expedition") and not w.action("arm") and not w.action("fast_travel_0:1:2"),"terminal rejects all actions")
	check(w.safe_walk_path(w.pos+Vector2i.RIGHT).is_empty(),"terminal rejects walking path")
	check(not w.safe_walk_step(w.pos+Vector2i.RIGHT,w.floor_index,w.pos),"terminal rejects walking step")
	check(not w.travel_available() and w.chapter_offers().is_empty(),"terminal has no continuation")
	check(canonical(w)==before,"terminal attempts change no saved data")
func _init():
	var w=World.new(0,2,ID,"risk")
	check(w.generation_valid and w.reward_eligible() and w.mode=="risk" and w.ended_reason=="","new session identity accepted")
	check(w.save_data().version==13,"schema13")
	var fast=World.from_snapshot(w.save_data())
	check(fast!=null and fast.generation_valid and canonical(fast)==canonical(w),"validated no-generation snapshot constructor")
	check(World.from_snapshot({})==null,"bad fast restore never exposes usable instance")
	var blank=World.new(0,2,"","safe",true)
	check(not blank.generation_valid and not blank.step(Vector2i.RIGHT) and not blank.action("arm"),"restore-only constructor fails closed")
	check(not w.settlement_summary("withdrawn").ok,"active state cannot settle")
	var before:=canonical(w)
	for outcome in ["chapter1","victory","defeat","garbage"]:
		check(not w.finish_run(outcome) and canonical(w)==before,"illegal finish atomic")
	check(w.finish_run("withdrawn"),"explicit retirement")
	check(w.ended_reason=="retired" and w.settlement_summary("withdrawn").summary=={"seed":0,"max_floor":1,"moves":0,"outcome":"withdrawn"},"summary derives actual run")
	before=canonical(w)
	check(w.finish_run("withdrawn") and canonical(w)==before,"same finish idempotent")
	check(not w.finish_run("chapter1") and not w.settlement_summary("victory").ok,"terminal outcome cannot change")
	terminal(w)
	var clone=World.new()
	check(clone.restore(w.save_data()) and clone.run_id==ID and clone.mode=="risk" and clone.ended_reason=="retired","terminal roundtrip retains identity/mode")
	terminal(clone)
	for field in ["run_id","mode","ended_reason"]:
		for bad in [null,true,123,[],{},"invalid value"]:
			var data:Dictionary=w.save_data().duplicate(true); data[field]=bad
			before=canonical(clone)
			check(not clone.restore(data) and canonical(clone)==before,"invalid session field rejected atomically")
	for bad_id in ["short","x".repeat(65),"身份不是合法标识123456789", "123456789012345/"]:
		check(not World.new(0,2,bad_id).generation_valid,"invalid constructor ID fails closed")
	check(not World.new(0,2,ID,"cheat").generation_valid,"invalid constructor mode fails closed")
	var data:Dictionary=w.save_data().duplicate(true); data.ended_reason="death"; data.hp=0
	check(not clone.restore(data),"death unsupported this batch")
	data=w.save_data().duplicate(true); data.ended_reason="victory"
	check(not clone.restore(data),"forged victory rejected")
	data=w.save_data().duplicate(true); data.floor_seen=[true,false,true,false,false]
	check(not clone.restore(data),"noncontiguous exploration rejected")
	var pure=World.new()
	check(not pure.reward_eligible() and pure.finish_run("withdrawn") and not pure.settlement_summary("withdrawn").ok,"pure identity empty never eligible")
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema11-layout2.json"))
	check(clone.restore(legacy) and clone.run_id=="" and clone.mode=="safe" and clone.ended_reason=="","legacy restore never inherits eligible ID")
	check(not clone.reward_eligible(),"old save ineligible")
	for fixture in ["schema12-layout1.json","schema12-layout2.json"]:
		var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+fixture))
		var target=World.new(0,2,ID,"risk")
		check(target.restore(old),"real schema12 migrates: "+fixture)
		check(target.run_id=="" and target.mode=="safe" and target.ended_reason=="" and not target.reward_eligible(),"legacy never grafts identity")
		var migrated:Dictionary=JSON.parse_string(JSON.stringify(target.save_data()))
		for key in old:
			if key=="version": continue
			check(migrated[key]==old[key],"legacy preserves field "+key)
	w=World.new(0,2,ID)
	replay(w,Generator.generate(0,World.MAPS).validation.route)
	check(w.won and w.ended_reason=="" and not w.chapter_offers().is_empty(),"K victory remains resumable and not settled")
	var chapter=World.new()
	check(chapter.restore(w.save_data()) and chapter.finish_run("chapter1"),"explicit chapter1 retirement")
	check(chapter.settlement_summary("chapter1").summary.max_floor==5,"chapter1 peak exact")
	terminal(chapter)
	check(w.action("expedition"),"unfinished K continues")
	replay(w,Expedition.generate(0).witness)
	check(w.won and w.ended_reason=="","Z requires explicit terminal confirmation")
	check(not w.finish_run("chapter1") and not w.finish_run("withdrawn"),"won final cannot mislabel result")
	check(w.finish_run("victory") and w.settlement_summary("victory").summary.max_floor==8,"final victory summary")
	check(clone.restore(w.save_data()) and clone.run_id==ID and clone.ended_reason=="victory","final victory roundtrip")
	terminal(w)
	print("SESSION WORLD: %d checks, failures=%d"%[checks,failures])
	quit(1 if failures else 0)
