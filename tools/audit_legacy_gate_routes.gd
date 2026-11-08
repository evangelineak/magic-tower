extends "res://tools/audit_legacy_points_routes.gd"
var rows=[]
func _init():
 var earn=W.new(1,2,"gate_earning_0123456789")
 assert(earn.action("hero_scholar"));var st=stats()
 follow(earn,G.generate(1,W.MAPS).validation.route,st);assert(earn.action("expedition"));follow(earn,E.generate(1).witness,st)
 assert(earn.finish_run("victory"));profile=P.settle(P.fresh(),earn.run_id,earn.settlement_summary("victory").summary).profile
 for strategy in ["none","channel"]:
  for tier in ["trained_focus","adversity_charge"]:
   for allocation in [{"study":0,"reserve":0},{"study":2,"reserve":1}]:
    gate_run(strategy,tier,allocation)
 quit()
func path_to(w,target):
 var queue=[w.pos];var prev={w.pos:Vector2i(-1,-1)}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p.distance_to(target)==1:
   var result=[]
   while p!=w.pos:result.push_front(p);p=prev[p]
   return result
  for d in DIR.values():
   var n=p+d
   if prev.has(n):continue
   if not w.tile(n) in [".","a","d","h","k","C","I","M","J","F","N","E","O","X","U","Y","v"]:continue
   prev[n]=p;queue.append(n)
 return null
func inspect(w,st,kind,index):
 var target=Vector2i(8,3) if kind=="V" else Vector2i(9,2)
 var path=path_to(w,target)
 if path==null:return {}
 var c=W.from_snapshot(w.save_data());var cs=st.duplicate(true)
 for p in path:
  upkeep(c,cs);assert(c.step(p-c.pos))
 upkeep(c,cs)
 var b=c.battle_preview(kind,"",target)
 var row={"kind":kind,"index":index,"floor":w.floor_index+1,"origin":str(w.pos),"detour_steps":path.size(),"hp":c.hp,"atk":c.atk,"def":c.defense,"kills":c.kills,"talents":c.talents.duplicate(),"damage":b.damage,"valid":b.valid,"focus":c.focus}
 var ok=c.step(target-c.pos);row.win=ok
 if ok:
  row.after_hp=c.hp;row.after_focus=c.focus
  if kind=="V":assert(c.step(Vector2i.RIGHT));row.reward_atk=c.atk
  else:assert(c.step(Vector2i.UP));row.rescued=c.rescue_state
 return row
func revisit(w,st,index):
 var start=Vector3i(w.pos.x,w.pos.y,w.floor_index)
 var queue=[start];var prev={start:null};var arrows={}
 var end=null
 while not queue.is_empty():
  var p=queue.pop_front()
  if p.z==2 and Vector2i(p.x,p.y).distance_to(Vector2i(8,3))==1:end=p;break
  for key in DIR:
   var n=Vector2i(p.x,p.y)+DIR[key]
   if n.x<1 or n.x>9 or n.y<1 or n.y>9:continue
   var token=w.floors[p.z][n.y][n.x]
   if not token in [".","a","d","h","k","C","I","M","J","F","N","E","O","X","U","Y","v","<",">"]:continue
   var q=Vector3i(n.x,n.y,p.z)
   if token in ["<",">"]:
    var dest=W.Layout.stair_destination(w.floors,w.layout_revision,p.z,n)
    if not dest.ok or not w.floor_seen[dest.floor]:continue
    q=Vector3i(dest.pos.x,dest.pos.y,dest.floor)
   if prev.has(q):continue
   prev[q]=p;arrows[q]=key;queue.append(q)
 if end==null:return {}
 var route=""
 while end!=start:route=arrows[end]+route;end=prev[end]
 var c=W.from_snapshot(w.save_data());var cs=st.duplicate(true)
 for key in route:
  upkeep(c,cs)
  if not c.step(DIR[key]):return {}
 var row=inspect(c,cs,"V",index)
 row.return_steps=route.length();row.return_extra_kills=c.kills-w.kills;row.departure_floor=w.floor_index+1;row.departure_pos=str(w.pos)
 return row
func gate_run(strategy,tier,allocation):
 var w=W.new(23,2,"gate_probe_0123456789","safe",false,S.pool_from_profile(profile))
 assert(w.choose_strategy(strategy,allocation));assert(w.action("hero_scholar"))
 var st=stats(tier);var findings={};var idx=0
 for chapter in [0,1]:
  if chapter==1:assert(w.action("expedition"))
  var route=G.generate(23,W.MAPS).validation.route if chapter==0 else E.generate(23).witness
  for key in route:
   upkeep(w,st)
   if w.floor_index in [2,6]:
    var kind="V" if w.floor_index==2 else "W"
    var result=inspect(w,st,kind,idx)
    if not result.is_empty():
     if not findings.has(kind+"_first"):findings[kind+"_first"]=result
     findings[kind+"_last"]=result
     if result.win and not findings.has(kind+"_win"):findings[kind+"_win"]=result
   if w.floor_index==4 and not findings.has("V_return_win"):
    var r=revisit(w,st,idx)
    if not r.is_empty():
     findings["V_return_last"]=r
     if r.win:findings["V_return_win"]=r
   assert(w.step(DIR[key]),w.message);idx+=1
 print(JSON.stringify({"strategy":strategy,"tier":tier,"allocation":allocation,"findings":findings}))
