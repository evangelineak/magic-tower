extends "res://tools/audit_endless_v10_walks.gd"
const Store=preload("res://scripts/endless_store.gd")
var extra_block:Array=[]
func route(w,target:Vector2i)->Array:
 var queue=[w.pos];var parents={w.pos:w.pos};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==target:
   var result=[]
   while p!=w.pos:result.push_front(p);p=parents[p]
   return result
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n=p+direction;var token:String=w.tile(n)
   if parents.has(n) or n in extra_block or token in ["#","u","v","N","M","S","E"]:continue
   if (token=="D" and n!=target) or token=="V":continue
   if token in ["<",">"] and n!=target:continue
   parents[n]=p;queue.append(n)
 return []
func beside(w,token:String)->Vector2i:
 var best=Vector2i(-1,-1);var length=2147483647
 for y in 15:
  for x in 15:
   if w.tile(Vector2i(x,y))!=token:continue
   for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    var p=Vector2i(x,y)+d;var r=route(w,p)
    if (p==w.pos or not r.is_empty()) and r.size()<length:best=p;length=r.size()
 return best
func persist_history(w)->Dictionary:
 var path="/tmp/bridge-store-"+str(Time.get_ticks_usec())+".json"
 var store=Store.new(path);var restored=W.new_run(w.seed);var reply=await store.start(restored.save_data(),0)
 for code in w.actions:
  check(restored.apply_code(code).get("changed",false),"history has only legal canonical events")
  reply=await store.commit(restored.save_data(),reply.revision)
  check(reply.ok,"incremental native write including bridge event succeeds")
 var loaded=await Store.new(path).read()
 var read_world=W.from_data(loaded.snapshot) if loaded.ok else null
 check(read_world!=null and read_world.bridges==w.bridges and read_world.keys==w.keys,"native file reload retains exact chosen bridge/key cost")
 var before=FileAccess.get_file_as_string(path);var bad=w.save_data();bad.bridges={1:"loot"}
 check((await store.commit(bad,reply.revision)).status=="invalid" and FileAccess.get_file_as_string(path)==before,"injected bridge state cannot overwrite native save")
 var changed_choice=w.save_data();changed_choice.actions.append("bridge_loot!" if w.bridges[1]=="short" else "bridge_short!")
 check((await store.commit(changed_choice,reply.revision)).status=="invalid" and FileAccess.get_file_as_string(path)==before,"forged second-choice event cannot overwrite native save")
 DirAccess.remove_absolute(path)
 return reply
func run():
 W=load("res://scripts/endless_world_v16.gd");G=load("res://scripts/endless_generation_v16.gd")
 var seed=-1
 for candidate in range(64):
  var grid:Array=G.generate(candidate,1).grid
  for row in grid:
   if "N" in row:seed=candidate;break
  if seed>=0:break
 check(seed>=0,"legal first-floor bridge seed exists")
 var reports=[]
 for choice in ["short","loot"]:
  extra_block=[];problem="";lane="alternate";supply_policy="skip_plus_potion"
  var w=W.new_run(seed)
  check(go(w,Vector2i(2,1)) and go(w,Vector2i(3,1)),"real entrance supplies")
  var before=w.save_data()
  check(not w.act("bridge_"+choice+"!").get("changed",false) and w.save_data()==before,"remote bridge request refused atomically")
  extra_block=[Vector2i(3,3)]
  check(go(w,beside(w,"N")),"reach real winch without collecting key")
  before=w.save_data()
  check(not w.act("bridge_"+choice+"!").get("changed",false) and w.save_data()==before,"no-key request refused atomically")
  extra_block=[]
  check(go(w,Vector2i(3,3)),"collect actual key")
  check(go(w,beside(w,"N")),"return to actual winch")
  before=w.save_data();var keys:int=w.keys
  check(w.act("bridge_"+choice).get("confirm",false) and w.save_data()==before and w.keys==keys,"confirmation alone neither consumes key nor records action")
  if choice=="short":
   var stale=w.clone()
   check(go(stale,Vector2i(10,3)) and stale.keys==0,"spend real key on original value door after requesting bridge confirmation")
   check(go(stale,beside(stale,"N")),"return to winch after spending key")
   var denied=stale.save_data()
   check(not stale.act("bridge_short!").get("changed",false) and stale.save_data()==denied,"stale confirmation rechecks key instead of granting free bridge")
   check(W.from_data(JSON.parse_string(JSON.stringify(stale.save_data())))!=null,"legal stale-confirmation trajectory replays")
  check(w.act("bridge_"+choice+"!").get("changed",false),"confirmed branch chosen")
  check(w.keys==keys-1 and w.bridges[1]==choice,"one key pays for exact branch")
  before=w.save_data()
  for duplicate in ["short","loot"]:check(not w.act("bridge_"+duplicate+"!").get("changed",false) and w.save_data()==before,"choice immutable, no duplicate or opposite charge")
  var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
  check(restored!=null and restored.bridges==w.bridges and restored.keys==w.keys,"full legal action replay derives bridge")
  await persist_history(w)
  var clone=w.clone();clone.bridges[1]="loot" if choice=="short" else "short"
  check(clone.bridges!=w.bridges,"clone bridge map independent")
  var closed_side=Vector2i(6,5) if choice=="short" else Vector2i(7,8)
  var approach=Vector2i(6,6) if choice=="short" else Vector2i(7,7)
  check(go(w,approach),"approach explicitly locked other arm")
  before=w.save_data()
  check(not w.step(closed_side-w.pos).get("changed",false) and w.save_data()==before,"unselected bridge cannot be stepped through or recorded")
  if choice=="short":
   # Controlled rune boundary only: not a claimed legal cleared-floor history.
   var sealed=w.clone();sealed.pos=Vector2i(2,1);sealed.gold=100
   for yy in 15:
    for xx in 15:
     var point=Vector2i(xx,yy)
     if point!=Vector2i(6,4) and sealed.tile(point) in sealed.enemy_tokens():sealed._consume(point)
   var sealed_before=sealed.save_data()
   check(not sealed.rune_view().available and not sealed.act("rune_on!").get("changed",false) and sealed.gold==100 and sealed.save_data()==sealed_before,"controlled sealed-island guardian alone cannot justify rune charge")
   extra_block=[Vector2i(3,8),Vector2i(8,8)]
   check(go(w,Vector2i(8,9)),"short branch legally reaches/fights second guard while first forbidden")
   check(w.tile(Vector2i(8,8)) in w.enemy_tokens(),"first skipped guard remains alive")
  else:
   check(go(w,Vector2i(6,4)),"loot branch legally fights additional guard")
   # Explicit controlled inventory boundaries, not claimed as a legally earned full inventory.
   for inventory in [{"ward":9,"pierce":0},{"ward":0,"pierce":9},{"ward":9,"pierce":9}]:
    var full=w.clone();full.items=inventory.duplicate();var saved=full.save_data();var location=full.pos;var funds=full.gold
    check(not full.step(Vector2i.UP).get("changed",false) and full.save_data()==saved and full.pos==location and full.items==inventory and full.gold==funds and full.tile(Vector2i(6,3))=="B","controlled full inventory refuses whole box without partial reward or movement")
   var room=w.clone();room.items={"ward":8,"pierce":8}
   check(room.step(Vector2i.UP).get("changed",false) and room.items=={"ward":9,"pierce":9},"controlled one free slot in each inventory accepts whole box")
   var ward:int=w.items.ward;var pierce:int=w.items.pierce;var gold:int=w.gold
   check(go(w,Vector2i(6,3)),"actual chest pickup")
   check(w.items.ward==ward+1 and w.items.pierce==pierce+1 and w.gold==gold and w.tile(Vector2i(6,3))==".","chest gives exactly two tools, no gold")
   check(go(w,Vector2i(6,4)) and go(w,Vector2i(6,3)),"revisit empty chest cell")
   check(w.items.ward==ward+1 and w.items.pierce==pierce+1 and w.gold==gold,"chest not duplicated on revisit")
  check(go(w,G.anchors(1).exit),"legally leave chosen bridge floor")
  check(go(w,Vector2i(12,13)) and go(w,Vector2i(13,13)),"legally descend paired stairs back to bridge floor")
  check(w.floor_number==1 and w.bridges[1]==choice,"cross-floor revisit retains irreversible choice")
  await persist_history(w)
  check(problem.is_empty(),"legal fixture has no obstruction "+problem)
  reports.append({"seed":seed,"choice":choice,"events":w.actions.size(),"keys":w.keys,"hp":w.hp,"bridges":w.bridges})
 print("BRIDGE_ACTION_RESULT "+JSON.stringify({"rules":16,"checks":checks,"failures":failures,"reports":reports,"inventory_boundaries":"four explicit inventory clones and one cleared-floor rune clone, not legal acquisition histories"}))
 quit(0 if failures==0 else 1)
