extends "res://tools/audit_endless_v17_budget.gd"
func route(w,target:Vector2i)->Array:
 var queue=[w.pos];var parents={w.pos:w.pos};var head=0
 var blocked:Array=G.routes(w.seed,w.floor_number)[1 if lane=="primary" else 0].points
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==target:
   var result=[]
   while p!=w.pos:result.push_front(p);p=parents[p]
   return result
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n=p+direction;var token:String=w.tile(n)
   if parents.has(n) or n in blocked or token in ["#","u","v","N","M","S","E","B"]:continue
   if token=="V" and n!=target:continue
   if token=="D" and not allow_door:continue
   if token in ["<",">"] and n!=target:continue
   parents[n]=p;queue.append(n)
 return []
func travel(w,destination:int)->bool:
 while w.floor_number!=destination:
  var target:Vector2i=G.anchors(w.floor_number).exit if w.floor_number<destination else G.anchors(w.floor_number).entry
  if w.pos==target:
   var offset=Vector2i.RIGHT if target.x==1 else Vector2i.LEFT
   if not go(w,target+offset):return false
  if not go(w,target):return false
 return true
func run():
 W=load("res://scripts/endless_world_v17.gd");G=load("res://scripts/endless_generation_v16.gd")
 lane="primary";supply_policy="skip_plus_potion";problem="";var w=W.new_run(0)
 for f in range(1,13):
  var y:int=1 if f%2 else 13
  check(go(w,Vector2i(2 if f%2 else 12,y)) and go(w,Vector2i(3 if f%2 else 11,y)),"legal growth supplies")
  apply_balanced(w)
  var points:Array=G.routes(0,f)[0].points.duplicate()
  if f%2==0:points.reverse()
  for p in points:check(go(w,p),"real mandatory guard")
  check(go(w,G.anchors(f).exit),"real upstairs traversal")
 check(travel(w,3),"actual descent to old floor3 vault")
 for f in [3,4]:
  check(travel(w,f),"real traversal between old vaults")
  check(go(w,Vector2i(10,10)) and go(w,Vector2i(12,10)),"defeat old vault guard and take first two relics")
 check(w.bonus_atk==6 and w.bonus_def==4 and w.relic_bonus==2,"real relics fill finite budgets")
 check(travel(w,5) and go(w,Vector2i(10,10)),"approach third old relic through actual guard")
 if w.hp<180:
  check(go(w,station_anchor(w,"M")),"camp refill before full-health boundary")
  check(action(w,"buy_potion").get("changed",false),"pay real money to refill")
 check(go(w,Vector2i(11,10)) and w.hp==180,"actually capped player stands beside unclaimed third relic")
 var before=w.save_data()
 check(not w.relic_quote().allowed and not w.step(Vector2i.RIGHT).get("changed",false) and w.save_data()==before and w.tile(Vector2i(12,10))=="T","zero-yield relic truly preserved in legal history")
 var medicine_floor=0;var G6=load("res://scripts/endless_generation_v6.gd")
 for f in range(1,13):
  if G6.encounter_kind(0,f)=="medicine":medicine_floor=f;break
 check(medicine_floor>0 and travel(w,medicine_floor) and go(w,station_anchor(w,"M")),"real travel to unspent medicine encounter")
 var hp:int=w.hp;check(action(w,"enc_blood_key").get("changed",false) and w.hp==hp-30,"legitimately exchange 30 HP for a key, no HP injection")
 check(travel(w,5) and go(w,Vector2i(11,10)),"actual return to preserved third relic")
 var quote:Dictionary=w.relic_quote();var old_hp:int=w.hp
 check(quote.allowed and quote.atk_gain==0 and quote.def_gain==0 and quote.relic_gain==0 and quote.heal_actual>0,"preserved relic now has exact healing-only use")
 check(w.step(Vector2i.RIGHT).get("changed",false) and w.hp==old_hp+int(quote.heal_actual) and w.tile(Vector2i(12,10))==".","real healing-only collection, consumed once")
 var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
 check(restored!=null and restored.save_data()==w.save_data() and restored.hp==w.hp and restored.relic_bonus==w.relic_bonus and restored.deltas==w.deltas,"full real growth and return history replays")
 check(problem.is_empty(),"no fixture obstruction "+problem)
 print("REVISIT_RESULT "+JSON.stringify({"rules":17,"checks":checks,"failures":failures,"events":w.actions.size(),"floor":w.floor_number,"hp":w.hp,"gold":w.gold,"healing_quote":quote,"medicine_floor":medicine_floor,"note":"All training, three old vault guards, resource payment and stair journeys were real actions; no stat, position or inventory injection"}))
 quit(0 if failures==0 else 1)
