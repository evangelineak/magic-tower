extends SceneTree
const W=preload("res://scripts/endless_world_v17.gd")
const G6=preload("res://scripts/endless_generation_v6.gd")
var checks:=0
var failures=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():call_deferred("run")
func run():
 var rows=[];var medicine_seed=0
 for seed in range(64):
  if G6.encounter_kind(seed,1)=="medicine":medicine_seed=seed;break
 for id in ["buy_potion","enc_medicine","skill_mend","cargo_use","cargo_open","case_take"]:
  for hp in [50,100,130,150,179,180]:
   var w=W.new_run(medicine_seed if id=="enc_medicine" else 0);w.hp=hp;w.gold=100;w.pos=Vector2i(2,1)
   if id=="skill_mend":w.pos=Vector2i(3,1)
   if id=="cargo_use":w.relief_remaining=0
   if id=="cargo_open":w.cargo={"state":"carried","source":1,"target":3,"reward":""}
   if id=="case_take":w.floor_number=4;w.pos=Vector2i(12,13);w.messenger={"state":"found","found":"A","advanced":false,"attempts":[]}
   var before=w.save_data();var q:Dictionary=w.action_quote(id);var result:Dictionary=w.act(id)
   check(q.allowed==result.get("changed",false),id+" quote eligibility matches actual controlled execution")
   if q.allowed:
    check(w.hp==q.hp_after and w.hp-hp==q.heal_actual,id+" displayed heal equals actual capped HP")
    check(100-w.gold==q.cost_gold,id+" displayed price equals actual debit")
   else:check(w.hp==hp and w.gold==100 and w.save_data()==before,id+" refusal leaves funds/HP/history untouched")
   rows.append({"action":id,"hp_before":hp,"quote":q,"hp_after":w.hp,"paid":100-w.gold,"changed":result.get("changed",false)})
 var quarter_seed=0
 for seed in range(64):
  if G6.encounter_kind(seed,1)=="quartermaster":quarter_seed=seed;break
 for id in ["job_buyward","job_buypierce","enc_ward","enc_pierce"]:
  var w=W.new_run(quarter_seed if id.begins_with("enc_") else 0);w.pos=Vector2i(2,1);w.gold=100
  var item="ward" if "ward" in id else "pierce";var expected=4 if item=="ward" else 8
  var offered=w.encounter_options() if id.begins_with("enc_") else w.contract_options();var label=""
  for row in offered:
   if row.id==id:label=row.label
  check((str(expected)+"金币") in label,"tool offer label has finalB price "+id)
  check(w.act(id).get("changed",false) and w.gold==100-expected and w.items[item]==1,"direct tool actual debit/quantity "+id)
 for count in [1,2]:
  for item in ["ward","pierce"]:
   var seed=0
   for candidate in range(64):
    var probe=W.new_run(candidate)
    if probe._job_manifest().reward_count==count:seed=candidate;break
   var w=W.new_run(seed);w.pos=Vector2i(2,1);w.gold=100;w.contract={"source":1,"phase":"voucher"}
   var expected=2 if count==1 else 4
   check(w.contract_view().exchange_price==expected,"voucher view price matches finalB quantity")
   check(w.act("job_"+item).get("changed",false) and w.gold==100-expected and w.items[item]==count and w.contract.is_empty(),"voucher actual price/full quantity and one-time settlement")
 var t=W.new_run(0);t.pos=Vector2i(11,10);t.hp=180;t.bonus_atk=6;t.bonus_def=4;t.atk=26;t.defense=14;t.relic_bonus=2
 var data=t.save_data();var q=t.relic_quote()
 check(not q.allowed and not t.step(Vector2i.RIGHT).get("changed",false) and t.save_data()==data and t.tile(Vector2i(12,10))=="T","all-zero relic retained with no movement/event")
 t.hp=151;q=t.relic_quote()
 check(q.allowed and q.heal_actual==29 and q.atk_gain==0 and q.def_gain==0 and q.relic_gain==0,"injured capped build quoted precise healing-only relic")
 check(t.step(Vector2i.RIGHT).get("changed",false) and t.hp==180 and t.tile(Vector2i(12,10))==".","healing-only relic settles and consumes once")
 var msg=W.new_run(0);msg.floor_number=4;msg.pos=Vector2i(12,13);msg.bonus_def=4;msg.defense=14;msg.messenger={"state":"found","found":"A","advanced":false,"attempts":[]}
 var help_label=""
 for row in msg.case_options():
  if row.id=="case_help":help_label=row.label
 check("8金币" in help_label and "最多" in help_label,"help choice discloses capped conversion before commitment")
 print("QUOTE_RESULT "+JSON.stringify({"rules":17,"checks":checks,"failures":failures,"controlled_fixtures":true,"rows":rows,"note":"Controlled transaction eligibility/price/heal boundaries, not claimed as legal earned resources or replay histories"}))
 quit(0 if failures.is_empty() else 1)
