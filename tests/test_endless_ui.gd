extends SceneTree
const World=preload("res://scripts/endless_world.gd")
var checks=0
var failures=0
class MemoryStore:
 extends RefCounted
 var snapshot={}
 var revision=0
 var records=[]
 var failing=false
 var writes=0
 func read():return {"ok":true,"status":"empty" if snapshot.is_empty() else "active","snapshot":snapshot.duplicate(true),"revision":revision,"records":records.duplicate(true)}
 func start(s,r):
  if failing or r!=revision:return {"ok":false,"status":"conflict"}
  snapshot=s.duplicate(true);revision+=1;writes+=1;return read()
 func commit(s,r):return start(s,r)
 func finish(s,r):
  if failing:return {"ok":false,"status":"io_error"}
  var w=World.from_data(s)
  if w==null or not w.ended:return {"ok":false,"status":"invalid"}
  if records.is_empty():records.append({"max_floor":w.max_floor,"kills":w.kills});revision+=1
  return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run_tests")
func route(w,target:Vector2i)->Array:
 var q=[w.pos];var parents={w.pos:w.pos};var i=0
 while i<q.size():
  var p:Vector2i=q[i];i+=1
  if p==target:
   var out=[]
   while p!=w.pos:out.push_front(p);p=parents[p]
   return out
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=p+d
   if parents.has(next) or w.tile(next) in ["#","D","V","g","M","S","<",">"]:continue
   parents[next]=p;q.append(next)
 return []
func go_new(w,target:Vector2i):
 var q=[w.pos];var parents={w.pos:w.pos};var i=0
 while i<q.size():
  var p:Vector2i=q[i];i+=1
  if p==target:break
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n=p+d;var t=w.tile(n)
   if parents.has(n) or t in ["#","M","S","D","V","b"] or (t in ["<",">"] and n!=target):continue
   parents[n]=p;q.append(n)
 check(parents.has(target),"v3 UI fixture genuine route exists")
 if not parents.has(target):return
 var path=[];var p=target
 while p!=w.pos:path.push_front(p);p=parents[p]
 for n in path:
  if w.tile(n)=="C":check(w.act("cargo_use").changed,"v3 fixture consumes supply normally")
  check(w.step(n-w.pos).changed and not w.ended,"v3 fixture real surviving action")
func reach_next(w):
 var odd=w.floor_number%2==1
 go_new(w,Vector2i(2 if odd else 12,1 if odd else 13))
 go_new(w,Vector2i(3 if odd else 11,1 if odd else 13))
 go_new(w,Vector2i(13,13) if odd else Vector2i(1,1))
func run_tests():
 var ui=load("res://endless.tscn").instantiate();var memory=MemoryStore.new();ui.store=memory;root.add_child(ui)
 await process_frame
 check(ui.modal=="start" and ui.world==null,"fresh mode offers new independent journey")
 await ui.start_run(1,1)
 check(ui.world!=null and memory.writes==1,"new journey saved before showing")
 var old=ui.world.save_data().duplicate(true)
 memory.failing=true
 await ui.map_click(Vector2i(2,1))
 check(ui.world.save_data()==old and ui.world.atk==20,"failed save rolls back visible pickup")
 check("保存未确认" in ui.notice,"failed save is visible")
 memory.failing=false
 await ui.map_click(Vector2i(2,1))
 check(ui.world.pos==Vector2i(2,1) and ui.world.atk==23,"adjacent item click succeeds")
 await ui.map_click(Vector2i(2,2))
 check(ui.modal=="choices","adjacent merchant opens")
 await ui.transact("act","buy_sword")
 check("金币不足" in ui.modal_notice and ui.modal=="choices","failed purchase visible inside modal")
 ui.modal=""
 await ui.map_click(Vector2i(3,1))
 check(ui.world.hp==170,"adjacent potion click restores HP")
 var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_E
 await ui._unhandled_input(event)
 check(ui.modal=="choices" and ui.choices.size()==3,"nearby skill opens three choices")
 await ui.transact("act","skill_power")
 check(ui.world.atk==25 and ui.modal=="","choice committed once")
 await ui.map_click(Vector2i(5,1))
 check(ui.walk.size()==2,"safe empty target queues route")
 await ui._process(0.2)
 check(ui.world.pos==Vector2i(4,1),"safe queued step executed")
 old=ui.world.save_data().duplicate(true)
 await ui.map_click(Vector2i(12,10))
 check(ui.world.save_data()==old and ui.walk.is_empty(),"distant guarded treasure does not trigger")
 ui.modal="new"
 await ui.map_click(Vector2i(5,1))
 check(ui.world.save_data()==old,"modal blocks world click")
 ui.modal=""
 # A fully valid replay state near a door, built with actual rule steps.
 var w=World.new_run(7,1)
 for target in [Vector2i(3,3),Vector2i(9,3)]:
  var path=route(w,target);check(not path.is_empty(),"door setup real route exists")
  for p in path:check(w.step(p-w.pos).changed,"setup uses real model step")
 memory.snapshot=w.save_data();memory.revision+=1;await ui.reload_run()
 old=ui.world.save_data().duplicate(true)
 await ui.map_click(Vector2i(10,3))
 check(ui.modal=="confirm" and ui.world.save_data()==old,"door preview spends nothing")
 await ui.reload_run()
 check(ui.modal=="" and ui.pending_revision==-1 and ui.choices.is_empty(),"reload clears stale confirmation and choices")
 await ui.map_click(Vector2i(10,3))
 ui.revision+=1
 await ui.confirm_modal()
 check(ui.world.save_data()==old and ui.modal=="","changed revision rejects old confirmation")
 await ui.reload_run();await ui.map_click(Vector2i(10,3));await ui.confirm_modal()
 check(ui.world.keys==0 and ui.world.tile(Vector2i(10,3))==".","door confirmed through normal transaction")
 await ui.transact("act","retire")
 check(ui.world.ended and ui.modal=="ended" and memory.records.size()==1,"retire records local result")
 await ui.settle_run()
 check(memory.records.size()==1,"settlement retry is not duplicate")
 check(ui.screen_tile(Vector2(0,0))==Vector2i(-1,-1),"outside viewport rejects tile")
 ui.world=World.new_run(9,1);ui.world.pos=Vector2i(13,13);ui.center_camera()
 check(ui.camera==Vector2i(4,4),"camera follows into larger map edge")
 check(ui.screen_tile(ui.ORIGIN+Vector2(32,32))==Vector2i(4,4),"mouse maps viewport to world coordinate")
 # New UI defaults to v2; old v1 fixture above remains replay-compatible.
 await ui.start_run(1,2)
 check(ui.world.rule_version()==2 and memory.snapshot.version==2,"new mode uses v2 explicitly")
 check(ui.world.summary().routes.size()==2,"two route budgets exposed")
 await ui.map_click(Vector2i(2,1))
 await ui.map_click(Vector2i(3,1))
 check(ui.modal=="choices" and ui.choices[1].id=="cargo_accept","adjacent sealed supply offers real choice")
 check(ui.world.hp==150,"opening choices does not auto consume supply")
 await ui.transact("act","cargo_accept")
 check(ui.world.hp==150 and ui.world.cargo.target==3 and ui.world.tile(Vector2i(3,1))==".","transport trades immediate healing for later modification")
 await ui.reload_run()
 check(ui.world.rule_version()==2 and ui.world.cargo.state=="carried","v2 task restores by replay")
 await ui.map_click(Vector2i(2,2))
 check(ui.modal=="choices" and ui.choices.back().id=="cargo_open","merchant permits reversible cargo decision")
 await ui.transact("act","cargo_open")
 check(ui.world.hp==170 and ui.world.cargo.state=="opened","opening cargo heals once and forfeits reward")
 var after_open=ui.world.save_data()
 await ui.transact("act","cargo_open")
 check(ui.world.save_data()==after_open,"duplicate opening cannot farm health")
 ui.queue_redraw();await process_frame
 var v3=World.new_run(42)
 for floor_index in 3:reach_next(v3)
 go_new(v3,Vector2i(1,12))
 memory.snapshot=v3.save_data();memory.revision+=1;await ui.reload_run()
 await ui.transact("act","case_read")
 check(ui.modal=="case" and ui.world.case_view().visible,"reading opens historical inset")
 check(ui.choices.size()==3,"history has three real candidate actions")
 await ui.transact("act","case_b")
 check(ui.modal=="case" and "没有扣除资源" in ui.modal_notice,"wrong deduction retains explanatory feedback over history map")
 await ui.transact("act","case_a")
 check(ui.world.messenger.state=="found" and ui.choices.size()==2,"correct deduction reveals mutually exclusive choices")
 await ui.transact("act","case_help")
 check(ui.world.messenger.state=="helped" and ui.choices.is_empty(),"delayed reward not available before advancing")
 await ui.reload_run();ui.open_case()
 check(ui.world.messenger.state=="helped" and ui.modal=="case","historical clue state survives reload")
 var snapshot_before=ui.world.save_data()
 await ui.transact("act","case_reward")
 check(ui.world.save_data()==snapshot_before,"early UI reward attempt rejected")
 ui.queue_redraw();await process_frame
 ui.queue_free();await process_frame
 print("ENDLESS UI: %s (%d checks)"%["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
