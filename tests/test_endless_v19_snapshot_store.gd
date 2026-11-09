extends SceneTree
const Store=preload("res://scripts/endless_store.gd")
const World=preload("res://scripts/endless_world.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:push_error("Expected independent audit JSON path");quit(1);return
 var data=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if not data is Dictionary or not data.get("legal_histories") is Array:quit(1);return
 var index:=0
 for snapshot in data.legal_histories:
  var w=World.new_run(int(snapshot.seed),19)
  var path="/tmp/endless-v19-snapshot-%d-%d.json" % [Time.get_ticks_usec(),index];index+=1
  var store=Store.new(path);var result:Dictionary=await store.start(w.save_data(),0)
  check(result.ok,"new native proof save")
  for code in snapshot.actions:
   check(w.apply_code(code).get("changed",false),"canonical legal event")
   result=await store.commit(w.save_data(),int(result.revision))
   check(result.ok,"native CAS commit of actual event")
   if not result.ok:quit(1);return
  var fresh=Store.new(path);result=await fresh.read()
  var loaded=World.from_data(result.snapshot) if result.ok else null
  check(loaded!=null and loaded.save_data()==w.save_data() and loaded.save_data().actions==snapshot.actions and loaded.seed==int(snapshot.seed) and loaded.carts==w.carts and loaded.items==w.items and loaded.hp==w.hp and loaded.deltas==w.deltas,"fresh-file restore preserves exact shared choice/reward and world")
 print("CART_NATIVE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"histories":index}))
 quit(0 if failures==0 else 1)
