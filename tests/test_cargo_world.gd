extends SceneTree
const W=preload("res://scripts/world.gd")
const C=preload("res://scripts/cargo.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const L=preload("res://scripts/layout.gd")
const DIRS=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func snap(w)->Dictionary:return w.save_data().duplicate(true)
func walk(w,goal:Vector2i)->bool:
 var queue:Array=[w.pos];var parents:Dictionary={w.pos:Vector2i(-1,-1)};var head:=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==goal:break
  for d in DIRS:
   var n:Vector2i=p+d
   if n.x<1 or n.y<1 or n.x>9 or n.y>9 or parents.has(n):continue
   var t:String=w.floors[w.floor_index][n.y][n.x]
   if t in ["#","c","D","L","~","=","n","e","m","T","R","t"]:continue
   if t in ["<",">"] and n!=goal:continue
   if t in W.ENEMIES and not w.battle_preview(t,"",n).survivable:continue
   parents[n]=p;queue.append(n)
 if not parents.has(goal):return false
 var path:Array=[];var p:=goal
 while p!=w.pos:
  var prev:Vector2i=parents[p];path.push_front(p-prev);p=prev
 for d in path:
  if not w.step(d):return false
 return true
func to_floor(w,target:int)->bool:
 while w.floor_index!=target:
  var p:Vector2i=L.entry(w.floor_index,w.layout_revision) if target<w.floor_index else L.exit_point(w.floor_index,w.layout_revision)
  if w.pos==p:
   var moved:=false
   for d in DIRS:
    if w.tile(w.pos+d)==".":moved=w.step(d);break
   if not moved:return false
  if not walk(w,p):return false
 return true
func route(w,text:String)->bool:
 for c in text:
  if not w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]):return false
 return true
func _init():
 for seed_value in range(20):
  var w=W.new(seed_value)
  check(C.valid_record(w.cargo,seed_value,2),"birth cargo seed determines exact destination")
  check(C.valid_maps(w.floors,w.cargo,false),"birth source and chute occupy only reserved locations")
  check(G.topology(w.floors).valid,"cargo marker never opens guarded vault or key-room bypass")
  check(W.from_snapshot(JSON.parse_string(JSON.stringify(snap(w))))!=null,"cargo JSON canonical restore")
  check(G.validate(w.floors).solvable,"real cargo maps retain no-cargo conservative proof")
 var w=W.new(0);var before=snap(w)
 check(not w.action("cargo_ship") and snap(w)==before,"remote dispatch refuses atomically")
 check(walk(w,Vector2i(8,1)),"real first-floor route reaches source seal")
 before=snap(w);var keys:int=w.keys;var hp:int=w.hp
 check(w.action("cargo_ship") and w.keys==keys and w.hp==hp and w.moves==before.moves+1,"shipping spends neither key nor HP and gives no premature reward")
 check(w.floors[0][2][8]=="." and w.floors[0][2][9]==".","source empty door removed, no empty key trap")
 check(w.safe_walk_path(Vector2i(9,2)).size()>0,"cleared source safe click remains possible")
 var shipped=snap(w)
 check(not w.action("cargo_ship") and snap(w)==shipped,"cannot dispatch twice")
 check(w.restore(before) and w.cargo.state=="waiting" and w.floors[0][2][8]=="D","whole-state undo restores locked source and supply")
 check(w.step(Vector2i.DOWN) and w.cargo.state=="opened" and w.keys==keys-1,"local opening pays real key and commits no shipment")
 check(w.tooltip_data(Vector2i(9,2)).title=="Sealed medical supply","source reward is clearly a medical crate, not spring water")
 before=snap(w);check(not w.action("cargo_ship") and snap(w)==before,"opened source cannot dispatch even before pickup")
 hp=w.hp;check(w.step(Vector2i.RIGHT) and w.hp==hp+70,"local original supply remains exactly70")
 check(W.from_snapshot(snap(w))!=null,"local collected state reloads")
 # Controlled location only for seal-negative tests: no fake enemy kill or reward.
 w=W.from_snapshot(shipped);w.floor_seen[1]=true;w.floor_seen[2]=true;w.floor_index=2;w.pos=Vector2i(8,2)
 before=snap(w)
 check(not w.action("cargo_claim") and not w.step(Vector2i.RIGHT) and snap(w)==before,"living V blocks collection and chute traversal from its outside flank")
 check(w.safe_walk_path(Vector2i(9,2)).is_empty(),"safe click cannot cross chute")
 for patch in [{"version":true},{"version":2},{"state":"claimed"},{"destination":"crown"},{"extra":1}]:
  var bad=shipped.duplicate(true);bad.cargo.merge(patch,true)
  check(W.from_snapshot(bad)==null,"forged cargo record/early claimed rejected")
 for token in ["h","D"]:
  var bad=shipped.duplicate(true);bad.floors[0][2][9 if token=="h" else 8]=token
  check(W.from_snapshot(bad)==null,"shipped cargo cannot coexist with original supply or lock")
 for name in ["schema17-active.json","schema17-death.json","schema17-allocated.json","schema17-pending.json"]:
  var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name));var restored=W.from_snapshot(old)
  check(restored!=null and restored.cargo==C.legacy(),"true old17 remains cargo off without map refresh")
  if restored!=null:
   var actual:Dictionary=JSON.parse_string(JSON.stringify(snap(restored)))
   for key in old:
    if key!="version":check(actual[key]==old[key],"old state unchanged: "+key)
 check(W.new(0,1).cargo==C.legacy(),"legacy layout birth cannot invent new source room")
 # Real routes: ship, replay conservative chapter, then collect at each genuine destination.
 for seed_value in [0,1]:
  w=W.new(seed_value);check(walk(w,Vector2i(8,1)),"real dispatch approach")
  check(w.action("cargo_ship") and walk(w,Vector2i(1,1)),"real dispatch and return to route start")
  var proof=G.generate(seed_value,W.MAPS).validation
  check(route(w,proof.route) and w.won,"baseline route still wins after optional dispatch excursion")
  check(w.cargo.state=="shipped" and not w.action("cargo_claim"),"K victory alone never claims deferred supply")
  if seed_value==1:check(not w.cargo_ready(),"crown seal requires explicit continuation even after real K defeat")
  check(w.action("expedition"),"explicit continuation required for crown seal")
  if seed_value==0:
   var second=E.generate(seed_value)
   for c in second.witness:
    var d:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
    if w.tile(w.pos+d)=="Z":break
    check(w.step(d),"real expedition growth before vault revisit")
   check(to_floor(w,2) and walk(w,Vector2i(8,2)),"genuine cross-chapter return to V")
   check(w.step(Vector2i.DOWN),"grown hero actually defeats V, not a forged seal flag")
   check(w.step(Vector2i.UP),"return adjacent to freight chute for manual collection")
  else:check(to_floor(w,4) and walk(w,Vector2i(1,3)),"return to calibration stand after explicit expedition")
  hp=w.hp;keys=w.keys
  check(w.cargo_ready() and not w.cargo_offers().is_empty(),"real route unlocks exact deferred destination")
  check(w.action("cargo_claim") and w.hp==hp+70 and w.keys==keys,"manual delivery equals original70 and costs no hidden key")
  before=snap(w);check(not w.action("cargo_claim") and snap(w)==before,"destination cannot duplicate reward")
  check(W.from_snapshot(JSON.parse_string(JSON.stringify(before)))!=null,"collected genuine route remains reloadable")
 print("CARGO WORLD: %d checks, failures=%d"%[checks,failures]);quit(1 if failures else 0)
