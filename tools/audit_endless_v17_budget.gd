extends "res://tools/audit_endless_v10_walks.gd"
var allow_door:=false
var floor_income:=0
var floor_door_income:=0
var floor_potion_spent:=0
var floor_potion_heal:=0
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
   if parents.has(n) or n in blocked or token in ["#","u","v","N","M","S","E","V","B"]:continue
   if token=="D" and not allow_door:continue
   if token in ["<",">"] and n!=target:continue
   parents[n]=p;queue.append(n)
 return []
func find_token(w,token:String)->Vector2i:
 for y in 15:
  for x in 15:
   if w.tile(Vector2i(x,y))==token:return Vector2i(x,y)
 return Vector2i(-1,-1)
func action(w,id:String)->Dictionary:
 var gold:int=w.gold;var hp:int=w.hp
 var r:Dictionary=super.action(w,id)
 if r.get("changed",false) and id=="buy_potion":floor_potion_spent+=gold-w.gold;floor_potion_heal+=w.hp-hp
 return r
func go(w,target:Vector2i)->bool:
 if w.ended or not problem.is_empty():return false
 var steps=route(w,target)
 if steps.is_empty() and w.pos!=target:problem="unreachable fixture "+str(target);return false
 for point in steps:
  if w.tile(point)=="C":
   if not (w.relief_remaining>0 and action(w,"cargo_use").get("changed",false)):
    if not action(w,"cargo_leave").get("changed",false):problem="could not discard box";return false
  var token:String=w.tile(point);var enemy:bool=token in w.enemy_tokens();var hp:int=w.hp;var gold:int=w.gold
  var preview:Dictionary=w.preview(point) if enemy else {}
  var r:Dictionary=w.step(point-w.pos)
  if r.get("confirm",false):r=w.step(point-w.pos,true)
  if not r.get("changed",false):problem="step refused "+str(r);return false
  var earned:int=maxi(0,w.gold-gold);floor_income+=earned
  if token=="$":floor_door_income+=earned
  if enemy:
   check(w.hp==maxi(0,hp-int(preview.damage))+(int(preview.get("heal_after",0)) if preview.survivable else 0),"actual route fight agrees with preview")
   floor_loss+=hp-w.hp;floor_gross_loss+=mini(hp,int(preview.damage))
   if not w.ended:floor_healing+=int(preview.get("heal_after",0))
  else:floor_healing+=maxi(0,w.hp-hp)
  if w.ended:return false
 return true
func run():
 var version:int=16 if "--baseline" in OS.get_cmdline_user_args() else 17
 W=load("res://scripts/endless_world_v%d.gd" % version);G=load("res://scripts/endless_generation_v16.gd")
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for open_boxes in [false,true]:
    for equipment in ["none","cloak"]:
     lane=route_name;problem="";supply_policy="skip_plus_potion";allow_door=false
     var w=W.new_run(seed);var rows=[];var door_count=0
     for f in range(1,101):
      floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0;floor_income=0;floor_door_income=0;floor_potion_spent=0;floor_potion_heal=0
      var y:int=1 if f%2 else 13
      if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):break
      if equipment=="cloak" and not w.owned_gear.cloak and w.gold>=40:
       if not go(w,station_anchor(w,"M")):break
       check(action(w,"buy_cloak").get("changed",false),"legal funded gear purchase")
       check(action(w,"gear_cloak").get("changed",false),"legal camp equip")
      apply_balanced(w)
      var points:Array=G.routes(seed,f)[0 if lane=="primary" else 1].points.duplicate()
      if f%2==0:points.reverse()
      for point in points:
       if not go(w,point):break
      if w.ended or not problem.is_empty():break
      if open_boxes:
       var key=find_token(w,"k")
       if key.x>=0 and not go(w,key):break
       var door=find_token(w,"D");var prize=find_token(w,"$")
       if door.x>=0 and prize.x>=0 and w.keys>0:
        allow_door=true
        if not go(w,prize):break
        allow_door=false;door_count+=1
      if not go(w,G.anchors(f).exit):break
      rows.append({"floor":f,"hp":w.hp,"gold":w.gold,"keys":w.keys,"net_damage":floor_loss,"gross_damage":floor_gross_loss,"healing":floor_healing,"spent":floor_paid,"income":floor_income,"door_income":floor_door_income,"potion_spent":floor_potion_spent,"potion_heal":floor_potion_heal,"events":w.actions.size()})
     check(problem.is_empty(),"fixture unobstructed "+problem)
     var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
     check(restored!=null and restored.hp==w.hp and restored.gold==w.gold and restored.keys==w.keys and restored.save_data()==w.save_data(),"full legal strategy history replays")
     reports.append({"seed":seed,"route":lane,"open_D":open_boxes,"gear":equipment,"completed":rows.size(),"ended":w.ended,"problem":problem,"door_count":door_count,"rows":rows,"end_hp":w.hp,"end_gold":w.gold,"end_floor":w.floor_number})
     print("BUDGET_PROGRESS "+str([seed,lane,open_boxes,equipment,rows.size(),w.hp,w.gold]))
 print("BUDGET_RESULT "+JSON.stringify({"rules":version,"checks":checks,"failures":failures,"reports":reports,"policy":"No runes/bridge/extra reward routes; capped balanced lessons/tactics, potion at HP<=130, free boxes only; D policy explicitly separated, not assumed mandatory"}))
 quit(0 if failures==0 else 1)
