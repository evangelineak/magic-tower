extends SceneTree
const P = preload("res://scripts/legacy_profile.gd")
var checks = 0
var failures = 0
func check(ok:bool,label:String):
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func summary(f:int=3,outcome:String="withdrawn") -> Dictionary:
 return {"seed":42,"max_floor":f,"moves":123,"outcome":outcome}
func run_id(i:int) -> String: return "run_%016d" % i
func bad(profile,label:String):
 var before = var_to_bytes(profile)
 check(not P.validate(profile).ok,label)
 var result = P.settle(profile,run_id(99),summary())
 check(not result.ok and result.status == "invalid",label + " settlement rejected")
 check(var_to_bytes(profile)==before,label + " input preserved")
func _init():
 var empty = P.fresh()
 check(P.validate(empty).ok,"fresh valid")
 var result = P.settle(empty,run_id(1),summary())
 check(result.ok and result.status=="applied" and result.new_unlocks==["legacy_scout"],"floor3 unlock")
 check(empty==P.fresh(),"settle does not mutate profile")
 var profile = result.profile.duplicate(true)
 check(P.validate(profile).ok,"first receipt valid")
 result.receipt.milestones.clear()
 result.new_unlocks.clear()
 check(profile.receipts[run_id(1)].milestones==[3],"return dictionaries independent")
 var duplicate = P.settle(profile,run_id(1),summary())
 check(duplicate.ok and duplicate.status=="duplicate" and duplicate.new_unlocks==[] and duplicate.profile==profile,"same request idempotent")
 var conflict = P.settle(profile,run_id(1),summary(8,"victory"))
 check(not conflict.ok and conflict.status=="conflict" and conflict.profile==profile and conflict.receipt==profile.receipts[run_id(1)],"old run cannot upgrade receipt")
 for field in ["seed","moves","outcome"]:
  var changed = summary()
  changed[field] = "defeat" if field=="outcome" else 124
  check(P.settle(profile,run_id(1),changed).status=="conflict","all summary fields immutable")
 result=P.settle(profile,run_id(2),summary(5,"chapter1"))
 check(result.new_unlocks==["legacy_tactician"] and result.receipt.milestones==[5],"only newly reached milestone awarded")
 profile=result.profile
 result=P.settle(profile,run_id(3),summary(8,"victory"))
 check(result.new_unlocks==["legacy_veteran"] and result.profile.unlocked==P.UNLOCKS,"final milestone unlocked")
 profile=result.profile
 result=P.settle(profile,run_id(4),summary(8,"defeat"))
 check(result.ok and result.new_unlocks==[] and result.receipt.milestones==[],"subsequent run gives no repeat reward")
 check(P.validate(result.profile).ok,"empty award receipt valid")
 var jump=P.settle(P.fresh(),run_id(5),summary(8,"victory"))
 check(jump.receipt.milestones==[3,5,8] and jump.new_unlocks==P.UNLOCKS,"first floor8 settlement grants all milestones")
 var low=P.settle(P.fresh(),run_id(6),summary(1))
 check(low.ok and low.new_unlocks==[] and P.validate(low.profile).ok,"floor1 still records final receipt")
 var json=JSON.parse_string(JSON.stringify(profile))
 check(P.validate(json).ok,"JSON float integer profile accepted")
 check(P.settle(json,run_id(3),JSON.parse_string(JSON.stringify(summary(8,"victory")))).status=="duplicate","JSON summary equal to integer summary")
 check(P.settle(json,run_id(7),summary(8)).new_unlocks==[],"JSON does not repeat milestone via type mismatch")
 for outcome in P.OUTCOMES:
  check(P.settle(P.fresh(),run_id(1),summary(8,outcome)).ok,"supported outcome")
 for id in [null,true,1,"short","a".repeat(65),"x".repeat(15)+"!","x".repeat(15)+"中","x".repeat(15)+"\n",[],{}]:
  check(not P.settle(P.fresh(),id,summary()).ok,"invalid run id")
 for id in ["a".repeat(16),"Z9_-".repeat(16)]: check(P.valid_run_id(id),"valid boundary run ID")
 for field in ["seed","max_floor","moves"]:
  for value in [null,true,false,"3",[],{},NAN,INF,-INF,1e100,4294967296,-1,1.5]:
   var s=summary(); s[field]=value
   check(not P.settle(P.fresh(),run_id(1),s).ok,"numeric type/range rejected "+field)
 for s in [{},{"seed":1},null,[],true]: check(not P.settle(P.fresh(),run_id(1),s).ok,"malformed summary")
 for outcome in ["death","won","",null,true,1]:
  var s=summary(); s.outcome=outcome
  check(not P.settle(P.fresh(),run_id(1),s).ok,"unknown outcome")
 check(not P.settle(P.fresh(),run_id(1),summary(4,"chapter1")).ok,"chapter1 floor minimum")
 check(not P.settle(P.fresh(),run_id(1),summary(7,"victory")).ok,"victory floor requirement")
 var s=summary(); s.seed=2147483647;s.moves=10000000
 check(P.settle(P.fresh(),run_id(1),s).ok,"numeric upper bounds")
 for field in ["seed","moves","max_floor"]:
  s=summary();s[field] = {"seed":2147483648,"moves":10000001,"max_floor":9}[field]
  check(not P.settle(P.fresh(),run_id(1),s).ok,"above maximum")
 s=summary();s.extra=1
 check(not P.settle(P.fresh(),run_id(1),s).ok,"unknown summary fields")
 for value in [null,[],true,"",{}, {"revision":1}]: bad(value,"malformed profile")
 for revision in [0,2,true,1.5,INF,"1"]:
  var p=P.fresh();p.revision=revision;bad(p,"invalid revision")
 var p=profile.duplicate(true);p.extra=1;bad(p,"unknown profile key")
 p=profile.duplicate(true);p.receipts[run_id(1)].extra=1;bad(p,"unknown receipt key")
 p=profile.duplicate(true);p.receipts[run_id(1)].run_id=run_id(2);bad(p,"receipt identity mismatch")
 p=profile.duplicate(true);p.receipts[run_id(1)].summary.max_floor=2;bad(p,"unearned milestone")
 p=profile.duplicate(true);p.receipts[run_id(2)].milestones=[3,5];p.receipts[run_id(2)].unlocked=["legacy_scout","legacy_tactician"];bad(p,"duplicate milestone source")
 p=profile.duplicate(true);p.receipts.erase(run_id(2));bad(p,"profile lacks receipt")
 p=profile.duplicate(true);p.milestones=[3,5];p.unlocked=["legacy_scout","legacy_tactician"];bad(p,"receipt lacks profile award")
 p=jump.profile.duplicate(true);p.milestones=[];p.unlocked=[];p.receipts[run_id(5)].milestones=[];p.receipts[run_id(5)].unlocked=[];bad(p,"reached but deliberately omitted awards")
 for value in [[5,3,8],[3,3,8],[3,4,8],[true,5,8],[3.1,5,8],[3,5,8,8],null,"3"]:
  p=profile.duplicate(true);p.milestones=value;bad(p,"invalid award sequence")
 p=profile.duplicate(true);p.unlocked[0]="unknown";bad(p,"unknown unlock")
 p=profile.duplicate(true);p.receipts=[];bad(p,"receipt type")
 # No pruning at capacity: duplicate/conflict stay available, only new IDs fail.
 p=P.fresh()
 for i in P.MAX_RECEIPTS:
  var id=run_id(i)
  p.receipts[id]={"run_id":id,"summary":summary(1),"milestones":[],"unlocked":[]}
 check(P.validate(p).ok,"full ledger valid")
 var full=P.settle(p,run_id(P.MAX_RECEIPTS),summary(8))
 check(not full.ok and full.status=="full" and full.profile==p,"full rejects without removing receipts")
 check(P.settle(p,run_id(0),summary(1)).status=="duplicate","duplicate available at capacity")
 check(P.settle(p,run_id(0),summary(8)).status=="conflict","conflict available at capacity")
 p.receipts[run_id(P.MAX_RECEIPTS)]={"run_id":run_id(P.MAX_RECEIPTS),"summary":summary(1),"milestones":[],"unlocked":[]}
 bad(p,"overfull ledger")
 print("LEGACY PROFILE: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
