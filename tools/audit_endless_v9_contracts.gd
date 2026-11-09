extends "res://tools/audit_endless_v8_balance.gd"
# CONTRACT-9B only: deposit 12, refund 12, optional exchange 8; no 20-upfront model.
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message);problem=message
func same_snapshot(w,before:Dictionary)->bool:return w.save_data()==before
func equip(w,item:String):
 if not item.is_empty() and int(w.items[item])>0 and w.armed_item!=item:action(w,"arm_"+item)
func finish_job(w,item:String,counters:Dictionary):
 if w.contract_view().phase=="complete":
  var before:int=w.gold
  if action(w,"job_refund").get("changed",false):counters.refunds+=1;counters.refunded_gold+=w.gold-before
 if w.contract_view().phase=="voucher":
  var before:int=w.gold;var inventory:int=w.items[item]
  if action(w,"job_"+item).get("changed",false):counters.exchanges+=1;counters.exchange_spent+=before-w.gold;counters.tools_bought+=int(w.items[item])-inventory
  elif int(w.items[item])+int(w.contract_view().reward_count)>9:
   check(action(w,"job_decline").get("changed",false),"full inventory can freely decline");counters.declined+=1
func run():
 W=load("res://scripts/endless_world_v9.gd");G=load("res://scripts/endless_generation_v9.gd")
 var reports=[];var boundary={}
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for mode in ["none","direct_ward","direct_pierce","job_ward","job_pierce"]:
    lane=route_name;problem="";declined=0;boxes_used=0;boxes_left=0;supply_policy="skip_plus_potion"
    var w=W.new_run(seed);var rows=[];var completed=0
    var counters={"accepted":0,"deposits":0,"refunds":0,"refunded_gold":0,"exchanges":0,"exchange_spent":0,"direct_spent":0,"tools_bought":0,"declined":0}
    var item:String=mode.trim_prefix("direct_").trim_prefix("job_") if mode!="none" else ""
    for f in range(1,51):
     floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0
     var before_hp:int=w.hp;var before_gold:int=w.gold;var before_kills:int=w.kills;var before_actions:int=w.actions.size()
     var y:int=1 if f%2 else 13
     if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)) or not go(w,Vector2i(2,y)):break
     if mode.begins_with("direct_"):
      var money:int=w.gold;var inventory:int=w.items[item]
      if action(w,"job_buy"+item).get("changed",false):counters.direct_spent+=money-w.gold;counters.tools_bought+=int(w.items[item])-inventory
     elif mode.begins_with("job_") and w.contract_view().phase=="offer":
      var offer:Dictionary=G.manifest(seed,f)
      if int(offer.route)==(0 if lane=="primary" else 1) and action(w,"job_accept").get("changed",false):counters.accepted+=1;counters.deposits+=12
     apply_policy(w,"balanced",y)
     var points:Array=G.routes(seed,f)[0 if lane=="primary" else 1].points.duplicate()
     if f%2==0:points.reverse()
     for point in points:
      if not w.ended and problem.is_empty():equip(w,item);go(w,point)
     if mode.begins_with("job_") and w.contract_view().phase in ["complete","voucher"] and not w.ended and problem.is_empty():go(w,Vector2i(2,y))
     if mode.begins_with("job_") and not w.ended and problem.is_empty():finish_job(w,item,counters)
     if not w.ended and problem.is_empty():go(w,G.anchors(f).exit)
     if w.floor_number==f+1:completed=f
     rows.append({"floor":f,"completed":completed==f,"damage":floor_loss,"gross_loss":floor_gross_loss,"healing":floor_healing,"spent_including_deposits":floor_paid,"hp":w.hp,"hp_change":w.hp-before_hp,"gold":w.gold,"net_gold":w.gold-before_gold,"kills":w.kills-before_kills,"actions":w.actions.size()-before_actions,"items":w.items.duplicate(true),"contract_phase":w.contract_view().phase})
     if w.ended or not problem.is_empty():break
    check(replay_matches(w),"economic trajectory replays")
    reports.append({"seed":seed,"route":lane,"mode":mode,"completed":completed,"ended":w.ended,"problem":problem,"counters":counters,"rows":rows,"replay_verified":replay_matches(w)})
    print("CONTRACT_PROGRESS "+str([seed,lane,mode,completed,w.hp,w.gold]))
 print("CONTRACT_RESULT "+JSON.stringify({"design":"CONTRACT-9B","rules":9,"reports":reports,"checks":checks,"failures":failures,"note":"Legal fixed-route comparisons; tools equipped before selected fights; attempts can be rejected for no money/full inventory/previously killed targets"}))
 quit(0 if failures==0 else 1)
