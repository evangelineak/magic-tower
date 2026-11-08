extends SceneTree
# Run with Godot --headless --path . --script tools/generate_legacy_vectors.gd.
# Expected results are computed by the tested GDScript implementation, never
# hand-written copies of a second implementation's behavior.
const P = preload("res://scripts/legacy_profile.gd")
const OUTPUT = "res://tests/fixtures/legacy-profile-vectors.json"
var cases:Array = []
func summary(f:int=3,outcome:String="withdrawn") -> Dictionary:
 return {"seed":42,"max_floor":f,"moves":123,"outcome":outcome}
func id(n:int) -> String: return "run_%016d" % n
func add_case(label:String,profile,run_id,run_summary) -> Dictionary:
 var result = P.settle(profile,run_id,run_summary)
 cases.append({"id":label,"profile":profile.duplicate(true) if profile is Dictionary else profile,"run_id":run_id,"summary":run_summary,"expected_validation":P.validate(profile),"expected_settlement":result})
 return result
func _init():
 var empty=P.fresh()
 add_case("fresh-low-floor",empty,id(0),summary(1))
 var stage3=add_case("first-floor-three",empty,id(1),summary()).profile
 var stage5=add_case("second-run-floor-five",stage3,id(2),summary(5,"chapter1")).profile
 var stage8=add_case("third-run-floor-eight",stage5,id(3),summary(8,"victory")).profile
 add_case("same-summary-duplicate",stage3,id(1),summary())
 add_case("old-run-new-floor-conflict",stage3,id(1),summary(8,"victory"))
 add_case("same-run-outcome-conflict",stage3,id(1),summary(3,"defeat"))
 var changed=summary();changed.moves=124
 add_case("same-run-moves-conflict",stage3,id(1),changed)
 changed=summary();changed.seed=43
 add_case("same-run-seed-conflict",stage3,id(1),changed)
 add_case("other-run-same-milestone-no-repeat",stage3,id(4),summary())
 add_case("other-run-all-milestones-no-repeat",stage8,id(4),summary(8,"defeat"))
 add_case("first-run-jumps-to-eight",empty,id(5),summary(8,"victory"))
 add_case("json-float-profile-and-summary",JSON.parse_string(JSON.stringify(stage3)),id(1),{"seed":42.0,"max_floor":3.0,"moves":123.0,"outcome":"withdrawn"})
 add_case("json-float-profile-next-milestone",JSON.parse_string(JSON.stringify(stage3)),id(6),{"seed":42.0,"max_floor":5.0,"moves":123.0,"outcome":"chapter1"})
 var low=add_case("settled-before-first-milestone",empty,id(7),summary(2)).profile
 add_case("low-run-reload-cannot-upgrade",low,id(7),summary(3))
 changed=summary();changed.seed=2147483647;changed.moves=10000000
 add_case("summary-upper-bounds",empty,"Z9_-".repeat(16),changed)
 add_case("bad-id",empty,"short",summary())
 add_case("bad-summary-outcome",empty,id(1),summary(3,"death"))
 add_case("bad-premature-chapter",empty,id(1),summary(4,"chapter1"))
 add_case("bad-premature-victory",empty,id(1),summary(7,"victory"))
 changed=summary();changed.moves=true
 add_case("bad-boolean-number",empty,id(1),changed)
 changed=summary();changed.max_floor=3.5
 add_case("bad-fractional-number",empty,id(1),changed)
 changed=summary();changed.seed=4294967296
 add_case("bad-overflow-seed",empty,id(1),changed)
 changed=summary();changed.extra=1
 add_case("bad-summary-extra-field",empty,id(1),changed)
 var bad=stage3.duplicate(true);bad.revision=2
 add_case("corrupt-profile-revision",bad,id(2),summary())
 bad=stage3.duplicate(true);bad.extra=1
 add_case("corrupt-profile-extra-field",bad,id(2),summary())
 bad=stage3.duplicate(true);bad.receipts={}
 add_case("corrupt-orphaned-unlock",bad,id(2),summary())
 bad=stage3.duplicate(true);bad.unlocked=["unknown"]
 add_case("corrupt-unknown-unlock",bad,id(2),summary())
 bad=stage5.duplicate(true);bad.milestones=[5,3];bad.unlocked=["legacy_tactician","legacy_scout"]
 add_case("corrupt-unordered-milestones",bad,id(4),summary())
 bad=stage3.duplicate(true);bad.receipts[id(1)].summary.max_floor=2
 add_case("corrupt-unearned-award",bad,id(2),summary())
 bad=stage3.duplicate(true);bad.receipts[id(2)]=bad.receipts[id(1)].duplicate(true);bad.receipts[id(2)].run_id=id(2)
 add_case("corrupt-duplicate-award-sources",bad,id(3),summary())
 bad=stage3.duplicate(true);bad.milestones=[];bad.unlocked=[];bad.receipts[id(1)].milestones=[];bad.receipts[id(1)].unlocked=[]
 add_case("corrupt-reached-milestone-omitted",bad,id(2),summary())
 bad=stage3.duplicate(true);bad.receipts[id(1)].run_id=id(2)
 add_case("corrupt-receipt-identity",bad,id(2),summary())
 bad=stage3.duplicate(true);bad.receipts[id(1)].extra=0
 add_case("corrupt-receipt-extra-field",bad,id(2),summary())
 add_case("corrupt-null-profile",null,id(1),summary())
 add_case("corrupt-empty-object-profile",{},id(1),summary())
 var document={"fixture_revision":1,"profile_revision":P.REVISION,"producer":"tools/generate_legacy_vectors.gd via scripts/legacy_profile.gd","comparison":"Compare validation ok and settlement ok/status/profile/receipt/new_unlocks; reason strings are diagnostic, not protocol enums.","fresh":P.fresh(),"cases":cases}
 var file=FileAccess.open(OUTPUT,FileAccess.WRITE)
 if file==null:
  push_error("Cannot write fixture: " + str(FileAccess.get_open_error()))
  quit(1)
  return
 file.store_string(JSON.stringify(document,"  ",true)+"\n")
 file.close()
 print("Generated %d legacy-profile protocol vectors: %s" % [cases.size(),OUTPUT])
 quit(0)
