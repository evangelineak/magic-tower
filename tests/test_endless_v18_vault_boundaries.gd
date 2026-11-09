extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var W=load("res://scripts/endless_world_v18.gd")
 var kinds={}
 for seed in range(32):
  var w=W.new_run(seed)
  for block in range(8):
   var seen={}
   for f in range(block*4+1,block*4+5):
    var kind:String=w.vault_kind(f);seen[kind]=true
    if not kinds.has(kind):kinds[kind]={"seed":seed,"floor":f}
   check(seen.size()==4 and seen.has("gold") and seen.has("medicine") and seen.has("ward") and seen.has("pierce"),"each four-floor block has exact reward roster")
 for kind in kinds:
  var sample:Dictionary=kinds[kind]
  for n in [0,1,3,4,6,7,8,9]:
   var w=W.new_run(sample.seed)
   # Explicit controlled capacity fixtures, not earned resource histories.
   w.floor_number=sample.floor;w.pos=Vector2i(11,3);w.hp=180 if n%2==0 else 130
   w.items.ward=n;w.items.pierce=n
   var q:Dictionary=w.vault_quote();var before=w.save_data();var hp:int=w.hp;var gold:int=w.gold;var items:Dictionary=w.items.duplicate(true)
   check(w.tile(Vector2i(12,3))=="$","fixture targets original reward cell")
   var r:Dictionary=w.step(Vector2i.RIGHT)
   check(bool(r.get("changed",false))==bool(q.allowed),"capacity preview equals step")
   if q.allowed:
    check(w.gold-gold==int(q.gold) and w.hp-hp==int(q.heal),"cash and healing exact quoted delta")
    check(w.items.ward-items.ward==int(q.ward) and w.items.pierce-items.pierce==int(q.pierce),"whole tool batch exact delta")
    check(w.tile(Vector2i(12,3))==".","successful collection consumes once")
   else:
    check(w.hp==hp and w.gold==gold and w.items==items and w.pos==Vector2i(11,3) and w.save_data()==before,"refusal atomic no movement/event/resources")
    check(w.tile(Vector2i(12,3))=="$","refused chest remains")
 print("VAULT_BOUNDARY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"controlled_fixtures":true,"note":"capacity fixture state is deliberately injected, not claimed as a legal route"}))
 quit(0 if failures==0 else 1)
