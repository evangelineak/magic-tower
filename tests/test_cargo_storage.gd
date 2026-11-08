extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const World=preload("res://scripts/world.gd")
const Clocked=preload("res://tests/clocked_journey_store.gd")
var checks=0
var failures=0
func nonce():return Crypto.new().generate_random_bytes(16).hex_encode()
func check(value,label):
 checks+=1
 if not value:failures+=1;push_error(label)
func need(r,label):
 if r.get("ok",false):return true
 check(false,label+str(r));quit(1);return false
func walk(w,target):
 var queue=[w.pos];var paths={w.pos:[]}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p==target:
   for delta in paths[p]:
    if not w.step(delta):return false
   return true
  for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next=p+delta
   if next.x<1 or next.x>9 or next.y<1 or next.y>9 or paths.has(next):continue
   if not w.floors[w.floor_index][next.y][next.x] in [".","a","d","h","k","s","g"]:continue
   paths[next]=paths[p]+[delta];queue.append(next)
 return false
func _initialize():call_deferred("run")
func run():
 for label in ["active","death","pending","allocated"]:
  var s=Store.new("user://journeys-v1-test-cargo-old-"+nonce());DirAccess.make_dir_recursive_absolute(s.native.root)
  DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tests/fixtures/schema17-"+label+"-store.json"),s.native.root.path_join("store.json"));s.native=Clocked.new(s.path)
  var r=await s.read_active()
  if not need(r,"old17 "+label):return
  check(r.snapshot.version==18 and r.snapshot.cargo=={"version":0,"state":"off","destination":""},"old17 no cargo retrofit "+label)
  var raw=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema17-"+label+".json"))
  for key in raw:
   if key!="version":check(JSON.parse_string(JSON.stringify(r.snapshot[key]))==raw[key],"old17 retains "+label+" "+key)
 for seed_value in [0,1]:
  var s=Store.new("user://journeys-v1-test-cargo-new-"+nonce())
  var born=await s.create_run(seed_value,2,"risk",false,nonce())
  if not need(born,"new cargo"):return
  check(born.snapshot.cargo.destination==("vault" if seed_value==0 else "crown"),"fixed birth destination")
  var w=World.from_snapshot(born.snapshot)
  var key_pos=Vector2i.ZERO
  for y in range(1,10):
   for x in range(1,10):
    if w.floors[0][y][x]=="k":key_pos=Vector2i(x,y)
  check(walk(w,key_pos),"actual pickup funds source door")
  check(walk(w,Vector2i(8,1)),"real safe approach to source")
  var approach=await s.commit_run(born.slot,born.revision,born.run_id,w.save_data(),nonce())
  if not need(approach,"approach commit"):return
  var hp=w.hp;var keys=w.keys
  check(w.action("cargo_ship") and w.hp==hp and w.keys==keys,"real dispatch does not claim HP or spend key")
  var shipped=await s.commit_run(approach.slot,approach.revision,approach.run_id,w.save_data(),nonce())
  if not need(shipped,"shipment commit"):return
  check(shipped.snapshot.cargo.state=="shipped","shipment persisted")
  var readback=await s.read_active();check(readback.ok and readback.snapshot==shipped.snapshot,"read preserves source removal and shipped state")
  var bad=shipped.snapshot.duplicate(true);bad.cargo={"version":0,"state":"off","destination":""}
  if seed_value==0:bad.floors[2][2][9]="#"
  var before=s.native.read().data
  var rejected=await s.commit_run(shipped.slot,shipped.revision,shipped.run_id,bad,nonce())
  check(not rejected.ok and s.native.read().data==before,"ordinary save cannot disable cargo birth rules")
  var undo=await s.commit_run(shipped.slot,shipped.revision,shipped.run_id,approach.snapshot,nonce())
  if not need(undo,"undo shipment"):return
  check(undo.snapshot==approach.snapshot,"Undo restores entire waiting crate and key state")
  w=World.from_snapshot(undo.snapshot)
  check(w.step(Vector2i.DOWN) and w.cargo.state=="opened" and w.keys==keys-1,"opening source permanently closes shipping branch")
  check(w.step(Vector2i.RIGHT) and w.hp==hp+70,"same source crate gives exactly original healing")
  var opened=await s.commit_run(undo.slot,undo.revision,undo.run_id,w.save_data(),nonce())
  if not need(opened,"opened source commit"):return
  check(not w.action("cargo_ship") and not w.action("cargo_claim"),"no second remote reward after source collection")
 print("CARGO STORAGE: ","PASS" if failures==0 else "FAIL"," (",checks," checks)")
 quit(0 if failures==0 else 1)
