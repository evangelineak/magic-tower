extends SceneTree
# Independent legal-behavior audit, pinned to v8. No teleport/stat injection.
var W
var G
var lane:="primary"
var problem:=""
var floor_loss:=0
var declined:=0
var supply_policy:="paid_supply"
var boxes_used:=0
var boxes_left:=0
var floor_paid:=0
var floor_healing:=0
var floor_gross_loss:=0
func _initialize():call_deferred("run")
func route(w,target:Vector2i)->Array:
 var queue=[w.pos];var parents={w.pos:w.pos};var head=0
 var blocked_points:Array=G.routes(w.seed,w.floor_number)[1 if lane=="primary" else 0].points
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==target:
   var result=[]
   while p!=w.pos:result.push_front(p);p=parents[p]
   return result
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+direction;var token:String=w.tile(n)
   if parents.has(n) or token=="#" or (token in w.station_tokens() and token!="C"):continue
   if token=="D" or (token=="V" and n!=target):continue
   if n in blocked_points:continue
   if token in ["<",">"] and n!=target:continue
   parents[n]=p;queue.append(n)
 return []
func action(w,id:String)->Dictionary:
 var gold_before:int=w.gold;var hp_before:int=w.hp
 var result:Dictionary=w.act(id)
 if result.get("changed",false):
  floor_paid+=maxi(0,gold_before-w.gold)
  floor_healing+=maxi(0,w.hp-hp_before)
 return result
func go(w,target:Vector2i)->bool:
 if w.ended or not problem.is_empty():return false
 var steps=route(w,target)
 if steps.is_empty() and w.pos!=target:problem="unreachable fixture target "+str(target);return false
 for point in steps:
  if w.tile(point)=="C":
   var should_use:bool=supply_policy=="paid_supply" or w.growth_view().relief_remaining>0
   var used:bool=should_use and action(w,"cargo_use").get("changed",false)
   if used:boxes_used+=1
   else:
    if not action(w,"cargo_leave").get("changed",false):problem="box could not be used or left";return false
    boxes_left+=1
  var enemy_before:bool=w.tile(point) in w.enemy_tokens();var hp_before:int=w.hp
  var before_preview:Dictionary=w.preview(point) if enemy_before else {}
  var result:Dictionary=w.step(point-w.pos)
  if result.get("confirm",false):result=w.step(point-w.pos,true)
  if not result.get("changed",false):problem="step refused: "+str(result.get("message",""));return false
  if enemy_before:
   floor_loss+=hp_before-w.hp
   floor_gross_loss+=mini(hp_before,int(before_preview.damage))
   if not w.ended:floor_healing+=int(before_preview.get("heal_after",0))
  else:floor_healing+=maxi(0,w.hp-hp_before)
  if w.ended:return false
 return true
func choose(w,id:String):
 if not w.ended and problem.is_empty() and not action(w,id).get("changed",false):declined+=1
func apply_policy(w,policy:String,y:int):
 if policy in ["armor","sword","brace","reap","pierce","balanced"] or (supply_policy=="skip_plus_potion" and w.hp<=130):
  if not go(w,Vector2i(2,y)):return
  if supply_policy=="skip_plus_potion" and w.hp<=130:choose(w,"buy_potion")
  if policy in ["brace","reap","pierce"] and w.tactic!=policy:choose(w,"tactic_"+policy)
  if policy in ["armor","sword"]:choose(w,"buy_"+policy)
  if policy=="balanced":
   # Choose only among real legal camp actions, evaluate route forecasts on clones.
   var best:String=w.tactic;var best_damage:int=2147483647
   for option in ["none","brace","reap","pierce"]:
    var trial=w.clone()
    if trial.tactic!=option and not trial.act("tactic_"+option).changed:continue
    var info:Dictionary=trial.summary().routes[0 if lane=="primary" else 1]
    if info.get("valid",false) and int(info.net_damage)<best_damage:best=option;best_damage=int(info.net_damage)
   if best!=w.tactic:choose(w,"tactic_"+best)
   if w.hp<100:choose(w,"buy_potion")
 if policy in ["guard","power","balanced"]:
  if not go(w,Vector2i(3,y)):return
  if policy=="balanced":
   # Explicit simple policy, not an optimal planner. Try permanent guard, then power, then healing.
   var accepted=false
   for id in ["skill_guard","skill_power","skill_mend"]:
    if action(w,id).get("changed",false):accepted=true;break
   if not accepted:declined+=1
  else:choose(w,"skill_"+policy)
func replay_matches(w)->bool:
 var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
 return restored!=null and restored.save_data()==w.save_data() and restored.summary()==w.summary() and restored.deltas==w.deltas
func revisit_sample(original)->Dictionary:
 var w=original.clone();var before_actions:int=w.actions.size();var start_hp:int=w.hp
 while w.floor_number>3:
  var stair:Vector2i=G.anchors(w.floor_number).entry
  if w.pos==stair:
   var moved=false
   for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    if w.tile(w.pos+direction)==".":moved=w.step(direction).get("changed",false);break
   if not moved:return {"ok":false,"reason":"cannot step off paired stair"}
  if not go(w,stair):return {"ok":false,"reason":problem,"ended":w.ended}
 if not go(w,Vector2i(9,10)):return {"ok":false,"reason":problem}
 var p:Dictionary=w.preview(Vector2i(10,10));var old_atk:int=w.atk;var old_def:int=w.defense;var old_hp:int=w.hp;var old_gold:int=w.gold
 if not go(w,Vector2i(10,10)) or not go(w,Vector2i(12,10)):return {"ok":false,"reason":problem,"ended":w.ended,"preview_damage":p.damage,"replay_verified":replay_matches(w)}
 return {"ok":true,"guard_damage":p.damage,"reward_atk":w.atk-old_atk,"reward_def":w.defense-old_def,"reward_hp":w.hp-old_hp,"reward_gold":w.gold-old_gold,"total_hp_change":w.hp-start_hp,"actions_cost":w.actions.size()-before_actions,"replay_verified":replay_matches(w)}
func run():
 W=load("res://scripts/endless_world_v8.gd");G=load("res://scripts/endless_generation_v8.gd")
 if W==null or G==null:push_error("v8 core not ready");quit(1);return
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for policy in ["none","guard","power","armor","sword","brace","reap","pierce","balanced"]:
    for box_policy in ["paid_supply","skip_plus_potion"]:
     lane=route_name;problem="";declined=0;supply_policy=box_policy;boxes_used=0;boxes_left=0
     var w=W.new_run(seed);var rows=[];var damage=0;var streak=0;var longest=0;var last_positive=0;var completed=0;var revisit={}
     for f in range(1,101):
      floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0
      var hp_entry:int=w.hp;var gold_entry:int=w.gold;var kills_entry:int=w.kills
      var y:int=1 if f%2 else 13
      if go(w,Vector2i(2 if f%2 else 12,y)) and go(w,Vector2i(3 if f%2 else 11,y)):
       apply_policy(w,policy,y)
       go(w,G.anchors(f).exit)
      damage+=floor_loss
      if w.floor_number==f+1:completed=f
      if floor_loss==0 and completed==f:streak+=1;longest=maxi(longest,streak)
      else:streak=0;last_positive=f
      rows.append({"floor":f,"completed":completed==f,"damage":floor_loss,"gross_loss":floor_gross_loss,"healing":floor_healing,"spent":floor_paid,"hp_entry":hp_entry,"hp":w.hp,"net_hp":w.hp-hp_entry,"atk":w.atk,"def":w.defense,"gold":w.gold,"gold_change":w.gold-gold_entry,"keys":w.keys,"kills":w.kills,"floor_kills":w.kills-kills_entry,"items":w.items.duplicate(true)})
      if w.ended or not problem.is_empty():break
      if f==50 and lane=="primary" and policy in ["none","balanced"]:
       var saved_loss=floor_loss;var saved_problem=problem;var saved_used=boxes_used;var saved_left=boxes_left;var saved_paid=floor_paid;var saved_healing=floor_healing;var saved_gross=floor_gross_loss
       revisit=revisit_sample(w);problem=saved_problem;floor_loss=saved_loss;boxes_used=saved_used;boxes_left=saved_left;floor_paid=saved_paid;floor_healing=saved_healing;floor_gross_loss=saved_gross
     if not replay_matches(w):push_error("replay mismatch "+str([seed,lane,policy]));quit(1);return
     reports.append({"seed":seed,"route":lane,"policy":policy,"supply_policy":supply_policy,"boxes_used":boxes_used,"boxes_left":boxes_left,"growth":w.growth_view(),"completed_floors":completed,"ended":w.ended,"ended_reason":w.ended_reason,"fixture_problem":problem,"declined_optional_actions":declined,"total_damage":damage,"longest_zero_streak":longest,"sustained_zero_from":last_positive+1 if completed==100 and last_positive<100 else 0,"revisit_50_to_3":revisit,"rows":rows,"replay_verified":true})
     print("AUDIT_PROGRESS "+str([seed,lane,policy,supply_policy,completed,w.hp]))
 print("BALANCE_RESULT "+JSON.stringify({"rules":8,"profiles":72,"note":"Legal synthetic policies, not an optimal solver; no attribute edits or teleport; failed strategies retained","reports":reports}))
 quit()
