extends SceneTree
# Local, synthetic fixtures only. Pin v5: never follow the production default.
const W=preload("res://scripts/endless_world_v6.gd")
const G=preload("res://scripts/endless_generation_v6.gd")
var target_count:=99999
var profile:="primary"
var failure:=""
var floor_damage:=0
func _initialize():call_deferred("run")
func route(w,target:Vector2i)->Array:
 var queue=[w.pos];var parents={w.pos:w.pos};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==target:
   var result=[]
   while p!=w.pos:result.push_front(p);p=parents[p]
   return result
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d;var token:String=w.tile(n)
   if parents.has(n) or (token in ["#","M","S","D","V","E"] and n!=target) or (token=="b" and profile!="alternate") or (token in ["g","w"] and profile=="alternate") or (token in ["<",">"] and n!=target):continue
   parents[n]=p;queue.append(n)
 return []
func go(w,target:Vector2i):
 var steps=route(w,target)
 if steps.is_empty() and w.pos!=target:failure="No legal fixture route";return
 for point in steps:
  if w.actions.size()>=target_count-1:return
  if w.tile(point)=="C":
   if not w.act("cargo_use").changed:failure="Fixture cargo failure";return
   if w.actions.size()>=target_count-1:return
  var enemy_before:bool=w.tile(point) in w.enemy_tokens();var hp_before:int=w.hp
  if not w.step(point-w.pos).changed or w.ended:failure="Fixture route invalid/dead";return
  if enemy_before:floor_damage+=hp_before-w.hp
func run():
 var reports=[]
 for lane in ["primary","alternate"]:
  for policy in ["none","guard","power","armor","sword","brace"]:
   profile=lane;failure=""
   var w=W.new_run(42);var rows=[];var cumulative=0;var first_zero=0;var paid=0;var last_positive=0;var revisit_data={}
   for f in range(1,101):
    floor_damage=0
    var y:int=1 if f%2 else 13
    go(w,Vector2i(2 if f%2 else 12,y))
    go(w,Vector2i(3 if f%2 else 11,y))
    if policy in ["armor","sword","brace"]:go(w,Vector2i(2,y))
    if policy=="brace" and w.tactic!="brace":
     if not w.act("tactic_brace").changed:failure="Tactic setup failed"
    if policy in ["armor","sword"]:
     var before_gold:int=w.gold
     w.act("buy_"+policy)
     paid+=before_gold-w.gold
    if policy in ["guard","power"]:
     go(w,Vector2i(3,y))
     if not w.act("skill_"+policy).changed:failure="Skill setup failed"
    go(w,G.anchors(f).exit)
    var loss:int=floor_damage;cumulative+=loss
    if loss==0 and first_zero==0:first_zero=f
    if loss>0:last_positive=f
    if f==50 and lane=="primary" and policy=="none":
     var revisit=w.clone();var start_actions:int=revisit.actions.size()
     while revisit.floor_number>3:
      var stair:Vector2i=G.anchors(revisit.floor_number).entry
      if revisit.pos==stair:
       var moved=false
       for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
        if revisit.tile(revisit.pos+d)==".":
         moved=revisit.step(d).changed;break
       if not moved:failure="No safe step off stair";break
      go(revisit,stair)
      if not failure.is_empty():break
     if failure.is_empty():
      go(revisit,Vector2i(9,10))
      var preview:Dictionary=revisit.preview(Vector2i(10,10))
      var old_atk:int=revisit.atk;var old_def:int=revisit.defense;var old_hp:int=revisit.hp;var old_gold:int=revisit.gold
      go(revisit,Vector2i(10,10));go(revisit,Vector2i(12,10))
      revisit_data={"from_completed_floor":50,"target_floor":3,"guard_damage":preview.damage,"reward_atk":revisit.atk-old_atk,"reward_def":revisit.defense-old_def,"reward_hp":revisit.hp-old_hp,"reward_gold":revisit.gold-old_gold,"actions_cost":revisit.actions.size()-start_actions,"replay_verified":W.from_data(revisit.save_data())!=null}

    if f<=12 or f in [25,50,100]:rows.append({"floor":f,"damage":loss,"hp":w.hp,"atk":w.atk,"def":w.defense,"gold":w.gold,"keys":w.keys,"kills":w.kills,"spent":paid})
    if not failure.is_empty():push_error(failure);quit(1);return
   var restored=W.from_data(w.save_data())
   if restored==null or restored.summary()!=w.summary():push_error("Audit replay failed");quit(1);return
   reports.append({"route":lane,"policy":policy,"seed":42,"first_zero_loss_floor":first_zero,"sustained_zero_from":last_positive+1 if last_positive<100 else 0,"revisit":revisit_data,"total_damage_100_floors":cumulative,"rows":rows,"replay_verified":true})
 print("BALANCE_RESULT "+JSON.stringify({"rules":6,"note":"Synthetic legal policies, not an optimal solver; no state injection","reports":reports}))
 quit()
