extends SceneTree
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const L=preload("res://scripts/layout.gd")
const R=preload("res://scripts/rope.gd")
const DIRS=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func snap(w)->Dictionary:return w.save_data().duplicate(true)
func find(w,token:String)->Vector2i:
 for y in range(1,10):
  for x in range(1,10):
   if w.tile(Vector2i(x,y))==token:return Vector2i(x,y)
 return Vector2i(-1,-1)
func path(w,goal:Vector2i)->Array:
 var queue:Array=[w.pos];var parents:Dictionary={w.pos:Vector2i(-1,-1)};var head:=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==goal:break
  for d in DIRS:
   var n:Vector2i=p+d
   if n.x<1 or n.x>9 or n.y<1 or n.y>9 or parents.has(n):continue
   var t:String=w.tile(n)
   if t in W.ENEMIES or t in ["#","D","L","~","c","n","e","m","t","R","T","<",">"]:continue
   if t=="=" and not w.expedition_bridge:continue
   parents[n]=p;queue.append(n)
 if not parents.has(goal):return []
 var p:=goal;var result:Array=[]
 while p!=w.pos:
  var prev:Vector2i=parents[p];result.push_front(p-prev);p=prev
 return result
func walk(w,goal:Vector2i)->bool:
 if w.pos==goal:return true
 var route=path(w,goal)
 if route.is_empty():return false
 for d in route:
  if not w.step(d):return false
 return true
func checkpoint(seed_value:int=0,armed_policy:bool=false):
 var w=W.new(seed_value,2,"rope_world_test_0001")
 for c in G.generate(seed_value,W.MAPS).validation.route:
  var d:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
  if armed_policy and w.tile(w.pos+d) in W.ENEMIES and w.focus>0 and not w.skill_armed:check(w.action("arm"),"actual combat focus spent along chapter")
  check(w.step(d),"actual conservative chapter route")
 check(w.won and w.action("expedition"),"actual expedition continuation")
 var target:=find(w,"H");var origin:Vector2i=target-L.direction(5,Vector2i.RIGHT,w.layout_revision)
 check(walk(w,origin),"walk normally to mapped takeoff point")
 check(W.from_snapshot(snap(w))!=null,"real checkpoint validates before rope use")
 return w
func reject(w,label:String):
 var before=snap(w);var last:Dictionary=w.last_battle.duplicate(true)
 check(not w.action("rope_cross") and snap(w)==before and w.last_battle==last,"atomic rejection: "+label)
func _init():
 var fresh=W.new(0)
 check(fresh.rope==R.birth(2) and fresh.save_data().version==19,"new layout2 gets ready rope, not an action before expedition")
 reject(fresh,"outside expedition")
 check(W.new(0,1).rope==R.legacy(),"legacy layout birth has no retrofitted crossing")
 for patch in [{"version":true},{"version":2},{"state":true},{"state":"spent"},{"extra":1}]:
  var bad=snap(fresh);bad.rope.merge(patch,true)
  check(W.from_snapshot(bad)==null,"invalid rope field/source rejected")
 for seed_value in [0,1,2]:
  var w=checkpoint(seed_value);var before=snap(w);var message:String=w.message;var battle:Dictionary=w.last_battle.duplicate(true)
  var offer=w.rope_preview();var target:Vector2i=offer.target
  check(offer.available and offer.valid and offer.cost==1 and not offer.disarm,"live mapped origin with focus offers one crossing")
  check(offer.origin==w.pos and offer.landing==w.flank_position(target),"coordinates share actual Layout-mapped flank definition")
  check(" ".join(w.tooltip_data(offer.origin).lines).contains("Single-use rope: 1 focus") and " ".join(w.tooltip_data(offer.landing).lines).contains("one-way"),"map markers expose accurate origin and landing tooltip semantics")
  check(snap(w)==before and w.message==message and w.last_battle==battle,"preview does not alter any gameplay or message state")
  check(w.action("rope_cross"),"real World action crosses without hypothetical position injection")
  var after=snap(w)
  check(w.pos==offer.landing and w.focus==before.focus-1 and w.moves==before.moves+1 and w.rope.state=="spent","one exact spatial/focus/move transaction")
  for key in before:
   if key not in ["x","y","focus","moves","rope"]:check(after[key]==before[key],"crossing preserves non-crossing field "+key)
  check(w.tile(target)=="H" and w.last_battle==battle,"guardian alive and no fabricated battle animation")
  check(path(w,offer.origin).is_empty(),"spent rope does not create a free reverse route")
  check(W.from_snapshot(JSON.parse_string(JSON.stringify(after))).save_data()==after,"spent state canonical JSON roundtrip")
  reject(w,"cannot repeat or reverse")
  check(w.restore(before) and snap(w)==before,"ordinary whole-step Undo restores focus/position/ready together")
  # Exact stance/landing and route controls, controlled negative fixtures.
  w.pos+=Vector2i.DOWN;reject(w,"not exactly at origin");w.restore(before)
  for token in ["#","h","s","~","=","M","D","L",">"]:
   w.floors[5][offer.landing.y][offer.landing.x]=token;reject(w,"landing not cleared: "+token);w.restore(before)
  w.expedition_bridge=true;reject(w,"bridge already open");w.restore(before)
  w.floors[5][target.y][target.x]=".";reject(w,"guardian defeated");w.restore(before)
  w.focus=0;reject(w,"zero focus");w.restore(before)
  w.won=true;reject(w,"chapter paused");w.restore(before)
  w.ended_reason="retired";reject(w,"terminal run");w.restore(before)
  w.expedition_revision=2;reject(w,"old chapter content");w.restore(before)
  check(w.action("arm") and w.rope_preview().available,"armed with spare focus is a valid crossing")
  check(w.action("rope_cross") and w.skill_armed and w.focus==before.focus-1,"spare focus preserves planned combat skill")
 # Real prior fights consume focus; chapter entry leaves one charge.
 var last=checkpoint(0,true)
 check(last.focus==1 and last.action("arm"),"actual legal route prepares final-focus armed case")
 var last_before=snap(last);var last_offer=last.rope_preview()
 check(last_offer.disarm and last_offer.reason.contains("cancel"),"preview explicitly explains final-focus skill cancellation")
 check(last.action("rope_cross") and last.focus==0 and not last.skill_armed,"final focus spent cancels armed flag, without combat")
 check(last.restore(last_before) and last.skill_armed and last.focus==1 and last.rope.state=="ready","Undo also restores armed planning state")
 # Real archived source versions remain untouched and gain no new crossing.
 for label in ["active","death","pending","allocated"]:
  var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rope_schema18-"+label+".json"))
  var loaded=W.from_snapshot(old)
  check(loaded!=null and loaded.rope==R.legacy(),"genuine18 migration keeps rope off: "+label)
  if loaded!=null:
   var upgraded:Dictionary=JSON.parse_string(JSON.stringify(snap(loaded)))
   for key in old:
    if key!="version":check(upgraded[key]==old[key],"genuine18 prior state conserved: "+key)
 # Controlled HP-only boundary after a real used crossing: lethal battle replay
 # must conserve the spent flag rather than resurrecting a one-use route.
 var spent=checkpoint();spent.mode="risk";check(spent.action("rope_cross"),"real crossing before controlled lethal HP boundary")
 var victim:=find(spent,"H");spent.hp=1
 check(W.from_snapshot(snap(spent))!=null and spent.lethal_fight(victim-spent.pos),"adjacent real H fatal attempt from spent landing")
 check(spent.rope.state=="spent" and W.from_snapshot(JSON.parse_string(JSON.stringify(snap(spent))))!=null,"death replay conserves spent rope and no crossing rewards")
 # Existing real early risk death replay also preserves unspent rope.
 var risk=W.new(0,2,"rope_risk_world_0001","risk")
 for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":check(risk.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"actual early risk route")
 check(risk.lethal_fight(Vector2i.LEFT) and W.from_snapshot(snap(risk))!=null and risk.rope.state=="ready","death does not consume or fabricate a future rope use")
 print("ROPE WORLD: %d checks, failures=%d"%[checks,failures]);quit(1 if failures else 0)
