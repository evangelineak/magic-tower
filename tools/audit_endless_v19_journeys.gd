extends "res://tools/audit_endless_v18_budget.gd"
var event_policy:="skip"
var event_reports=[]
var first_sightings=[]
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
   if parents.has(n) or n in blocked or token in ["#","u","v","N","M","S","E","R","O"]:continue
   if token in ["V","B","J","L"] and n!=target:continue
   if token=="D" and not allow_door:continue
   if token in ["<",">"] and n!=target:continue
   parents[n]=p;queue.append(n)
 return []
func station_anchor(w,token:String)->Vector2i:
 var station:Vector2i=find_token(w,token)
 var preferred:Vector2i=station+Vector2i(0,-1 if station.y<7 else 1)
 var candidates=[preferred,station+Vector2i.LEFT,station+Vector2i.RIGHT,station+Vector2i.DOWN,station+Vector2i.UP]
 for p in candidates:
  if w.tile(p) not in [".","a","h","k","C"]:continue
  if p==w.pos or not route(w,p).is_empty():return p
 return Vector2i(-1,-1)
func move_floors(w,destination:int)->bool:
 while w.floor_number!=destination:
  if not go(w,find_token(w,"<" if w.floor_number>destination else ">")):return false
 return true
func solve_cart(w,side:String)->bool:
 var meta:Dictionary=G.cart_manifest(w.seed,w.floor_number)
 var sequence:String=("LLU" if side=="supply" else "LUU") if meta.variant==1 else ("UULL" if side=="supply" else "UUUL")
 for code in sequence:
  var d:Vector2i=w.DIRECTIONS[code];var cart:Vector2i=find_token(w,"O")
  if not go(w,cart-d):return false
  var before:int=w.actions.size();var r:Dictionary=w.step(d)
  check(r.get("changed",false) and not r.get("confirm",false) and w.actions.size()==before+1,"legal cart push records one ordinary direction")
  if not r.get("changed",false):problem="cart push refused "+str(r);return false
 return true
func visit_event(w,side:String)->bool:
 var meta:Dictionary=G.cart_manifest(w.seed,w.floor_number)
 var start_events:int=w.actions.size();var hp:int=w.hp;var items:Dictionary=w.items.duplicate(true);var bonus:int=w.relic_bonus
 if not solve_cart(w,side):return false
 var guard_damage:=0;var hp_after_guard:int=w.hp
 if side=="archive":
  guard_damage=int(w.preview(meta.guardian).damage)
  if not go(w,meta.guardian):return false
  hp_after_guard=w.hp
 if not go(w,meta.rewards[side]):return false
 var chosen:Dictionary=w.carts[w.floor_number]
 check(chosen.claim==side,"one physical reward latches matching gate")
 if not go(w,Vector2i(3,7)):return false
 event_reports.append({"floor":w.floor_number,"variant":meta.variant,"side":side,"physical_events":w.actions.size()-start_events,"hp_before":hp,"hp_after":w.hp,"items_before":items,"items_after":w.items.duplicate(true),"relic_before":bonus,"relic_after":w.relic_bonus,"guard_damage":guard_damage,"hp_after_guard":hp_after_guard})
 return true
func run():
 W=load("res://scripts/endless_world_v19.gd");G=load("res://scripts/endless_generation_v19.gd")
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for policy in ["skip","supply","archive"]:
    lane=route_name;event_policy=policy;active_policy="none";event_reports=[];first_sightings=[];problem="";supply_policy="skip_plus_potion";allow_door=false
    var w=W.new_run(seed);var rows=[]
    for f in range(1,101):
     floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0;floor_income=0;floor_door_income=0;floor_potion_spent=0;floor_potion_heal=0
     var y:int=1 if f%2 else 13
     if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):break
     apply_balanced(w)
     if G.has_cart(seed,f):
      var m:Dictionary=G.cart_manifest(seed,f);var guard:Dictionary=w.preview(m.guardian)
      first_sightings.append({"floor":f,"hp":w.hp,"damage":guard.damage,"survivable":guard.survivable,"actual_growth_packs":w.training_packs})
     var points:Array=G.routes(seed,f)[0 if lane=="primary" else 1].points.duplicate()
     if f%2==0:points.reverse()
     for point in points:
      if not go(w,point):break
     if w.ended or not problem.is_empty():break
     # Real return journey after growth. No teleport, resources or map injection.
     if f==12 and policy!="skip":
      for event_floor in G.cart_floors(seed):
       if not move_floors(w,event_floor) or not visit_event(w,policy):break
      if w.ended or not problem.is_empty() or not move_floors(w,12):break
     if not go(w,G.anchors(f).exit):break
     rows.append({"floor":f,"hp":w.hp,"gold":w.gold,"net_damage":floor_loss,"gross_damage":floor_gross_loss,"healing":floor_healing,"spent":floor_paid,"events":w.actions.size()})
    check(problem.is_empty(),"legal journey fixture "+problem)
    var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
    check(restored!=null and restored.save_data()==w.save_data() and restored.carts==w.carts and restored.items==w.items and restored.deltas==w.deltas and restored.hp==w.hp and restored.gold==w.gold,"full event journey replay resources/maps/cart state")
    reports.append({"seed":seed,"route":lane,"policy":policy,"completed":rows.size(),"ended":w.ended,"problem":problem,"event_rewards":event_reports.duplicate(true),"first_sightings":first_sightings.duplicate(true),"rows":rows,"end_hp":w.hp,"end_gold":w.gold})
    print("CART_JOURNEY_PROGRESS "+str([seed,lane,policy,rows.size(),w.hp,w.gold]))
 print("CART_JOURNEY_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"reports":reports,"note":"No ordinary key vaults/runes/gear; capped training/tactics and potion policy; event policies physically return after floor12 growth; at most two early events, not a deep-loop fix"}))
 quit(0 if failures==0 else 1)
