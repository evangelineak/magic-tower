extends "res://tools/audit_endless_v8_balance.gd"
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func station_anchor(w,token:String)->Vector2i:
 for y in range(15):
  for x in range(15):
   if w.tile(Vector2i(x,y))==token:return Vector2i(x,y-1 if y<7 else y+1)
 return Vector2i(-1,-1)
func apply_balanced(w):
 if not go(w,station_anchor(w,"M")):return
 if w.hp<=130:choose(w,"buy_potion")
 var best:String=w.tactic;var loss:=2147483647
 for id in ["none","brace","reap","pierce"]:
  var trial=w.clone()
  if trial.tactic!=id and not trial.act("tactic_"+id).changed:continue
  var info:Dictionary=trial.summary().routes[0 if lane=="primary" else 1]
  if info.valid and int(info.net_damage)<loss:best=id;loss=int(info.net_damage)
 if best!=w.tactic:choose(w,"tactic_"+best)
 if not go(w,station_anchor(w,"S")):return
 for id in ["skill_guard","skill_power","skill_mend"]:
  if action(w,id).get("changed",false):break
func independent_safe_steps(w)->int:
 if w.ended:return -1
 var queue=[w.pos];var dist={w.pos:0};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   if w.tile(p+d)=="M":return int(dist[p])
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var q:Vector2i=p+d
   if not dist.has(q) and w.tile(q)==".":dist[q]=int(dist[p])+1;queue.append(q)
 return -1
func resource_fingerprint(w)->Dictionary:
 return {"floor":w.floor_number,"hp":w.hp,"atk":w.atk,"def":w.defense,"gold":w.gold,"keys":w.keys,"kills":w.kills,"items":w.items.duplicate(true),"deltas":w.deltas.duplicate(true),"cargo":w.cargo.duplicate(true),"messenger":w.messenger.duplicate(true),"contract":w.contract.duplicate(true)}
func run():
 W=load("res://scripts/endless_world_v10.gd");G=load("res://scripts/endless_generation_v10.gd")
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   lane=route_name;problem="";supply_policy="skip_plus_potion";boxes_used=0;boxes_left=0;declined=0
   var w=W.new_run(seed);var rows=[];var macro_count=0;var macro_steps=0;var saved_inputs=0;var channels=0
   for f in range(1,101):
    floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0
    if G.is_channel(seed,f):channels+=1
    var y:int=1 if f%2 else 13
    if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):break
    apply_balanced(w)
    var points:Array=G.routes(seed,f)[0 if lane=="primary" else 1].points.duplicate()
    if f%2==0:points.reverse()
    for point in points:
     if not go(w,point):break
    if w.ended or not problem.is_empty():break
    var independent:int=independent_safe_steps(w);var view:Dictionary=w.camp_return_view();var before=w.save_data();var resources=resource_fingerprint(w)
    var macro=w.clone();var returned:Dictionary=macro.return_to_camp()
    if view.available:
     check(independent>0 and independent==view.steps,"safe return has independent shortest distance")
     var manual=w.clone()
     for point in view.path:
      check(manual.tile(point)==".","every path cell was already empty")
      check(manual.step(point-manual.pos).changed,"manual twin uses legal one-cell movement")
     check(returned.changed and macro.save_data()==manual.save_data(),"macro exactly equals manual expanded directions")
     check(macro.actions.size()-w.actions.size()==view.steps,"real recorded steps are not skipped")
     check(resource_fingerprint(macro)==resources,"macro touches no resources, battles, doors or stairs")
     macro_count+=1;macro_steps+=int(view.steps);saved_inputs+=int(view.steps)-1;w=macro
    else:
     check(not returned.get("changed",false) and macro.save_data()==before,"unavailable macro atomic no-op")
     check(independent<=0,"unavailable agrees with independent empty-cell reachability")
     go(w,station_anchor(w,"M"))
    if not go(w,G.anchors(f).exit):break
    rows.append({"floor":f,"hp":w.hp,"gold":w.gold,"net_damage":floor_loss,"spent":floor_paid,"recorded_actions":w.actions.size(),"macro_calls_total":macro_count,"macro_real_steps_total":macro_steps,"manual_inputs_saved_total":saved_inputs,"layout":G.layout_name(seed,f),"macro_available":view.available,"macro_steps":view.steps})
   check(problem.is_empty(),"legal journey has no fixture obstruction "+problem)
   check(rows.size()==100 and not w.ended,"balanced real 100 floors survives")
   check(replay_matches(w),"expanded full 100-floor history replays")
   reports.append({"seed":seed,"route":lane,"completed":rows.size(),"ended":w.ended,"problem":problem,"channel_floors":channels,"macro_calls":macro_count,"macro_real_steps":macro_steps,"manual_inputs_saved":saved_inputs,"actual_recorded_events":w.actions.size(),"estimated_inputs_with_shortcut":w.actions.size()-saved_inputs,"rows":rows,"replay_verified":replay_matches(w)})
   print("WALK_PROGRESS "+str([seed,lane,rows.size(),macro_count,macro_steps,w.actions.size()]))
 print("WALK_RESULT "+JSON.stringify({"rules":10,"checks":checks,"failures":failures,"reports":reports,"note":"Input savings are relative to manually following the exact same safe path; real UDLR movement/events remain"}))
 quit(0 if failures==0 else 1)
