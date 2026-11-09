extends SceneTree
# Local, synthetic fixtures only. Pin v5: never follow the production default.
const W=preload("res://scripts/endless_world_v5.gd")
const G=preload("res://scripts/endless_generation_v5.gd")
var target_count:=1000
var profile:="primary"
var failure:=""
func _initialize():call_deferred("run")
func route(w,target:Vector2i)->Array:
 var queue=[w.pos];var parents={w.pos:w.pos};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==target:
   var result=[]
   while p!=w.pos:result.push_front(p);p=parents[p]
   return result
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d;var token:String=w.tile(n)
   if parents.has(n) or token in ["#","M","S","D","V"] or (token=="b" and profile!="alternate") or (token in ["g","w"] and profile=="alternate") or (token in ["<",">"] and n!=target):continue
   parents[n]=p;queue.append(n)
 return []
func go(w,target:Vector2i):
 var steps=route(w,target)
 if steps.is_empty() and w.pos!=target:failure="No legal fixture route";return
 for point in steps:
  if w.actions.size()>=target_count-1:return
  if w.tile(point)=="C":
   if not w.act("cargo_use").changed:failure="Fixture cargo failure";return
   if w.actions.size()>=target_count-1:return
  if not w.step(point-w.pos).changed or w.ended:failure="Fixture route invalid/dead";return
func fixture():
 var w=W.new_run(42)
 while w.actions.size()<target_count-1 and failure.is_empty():
  if profile=="corridor":
   var direction:=Vector2i.RIGHT if w.pos.x<3 else Vector2i.LEFT
   if w.tile(w.pos+direction)=="C":
    if not w.act("cargo_use").changed:failure="Fixture corridor cargo failure"
   elif not w.step(direction).changed:failure="Fixture corridor blocked"
  else:
   var floor_before:int=w.floor_number
   var y:int=1 if floor_before%2 else 13
   for point in [Vector2i(2 if floor_before%2 else 12,y),Vector2i(3 if floor_before%2 else 11,y),G.anchors(floor_before).exit]:
    go(w,point)
    if not failure.is_empty() or w.actions.size()>=target_count-1:break
 if failure.is_empty() and not w.act("retire").changed:failure="Fixture retirement failed"
 return w
func run():
 var args=OS.get_cmdline_user_args()
 if args.size()!=2:push_error("Expected -- PROFILE ACTION_COUNT");quit(1);return
 profile=args[0];target_count=int(args[1])
 if profile not in ["corridor","primary","alternate"] or target_count not in [1000,10000]:quit(1);return
 var w=fixture()
 if not failure.is_empty():push_error(failure);quit(1);return
 var expected=w.save_data();var expected_summary=w.summary();var expected_deltas=w.deltas.duplicate(true)
 var json=JSON.stringify(expected);var parse_samples=[];var replay_samples=[];var live_deltas=[]
 # First replay is a warm-up; engine load and fixture generation are excluded.
 var warm=W.from_data(JSON.parse_string(json))
 if warm==null or warm.summary()!=expected_summary:push_error("Warm-up replay mismatch");quit(1);return
 warm=null
 for i in range(5):
  var begin=Time.get_ticks_usec();var decoded=JSON.parse_string(json)
  parse_samples.append(Time.get_ticks_usec()-begin)
  var before=OS.get_static_memory_usage();begin=Time.get_ticks_usec()
  var restored=W.from_data(decoded)
  replay_samples.append(Time.get_ticks_usec()-begin)
  live_deltas.append(OS.get_static_memory_usage()-before)
  if restored==null or restored.save_data()!=expected or restored.summary()!=expected_summary or restored.deltas!=expected_deltas:push_error("Replay mismatch");quit(1);return
  restored=null;decoded=null
 var invalid=expected.duplicate(true);invalid.actions.append("R")
 var begin=Time.get_ticks_usec();var rejected=W.from_data(invalid);var rejection_us=Time.get_ticks_usec()-begin
 if rejected!=null:push_error("Accepted action after retirement");quit(1);return
 var injected=expected.duplicate(true);injected.score=999999
 if W.from_data(injected)!=null:push_error("Accepted forged score field");quit(1);return
 print("BENCH_RESULT "+JSON.stringify({"rules_version":5,"seed":42,"profile":profile,"actions":target_count,"floor":w.max_floor,"kills":w.kills,"json_utf8_bytes":json.to_utf8_buffer().size(),"parse_us":parse_samples,"replay_us":replay_samples,"live_replay_alloc_delta_bytes":live_deltas,"godot_static_peak_bytes":OS.get_static_memory_peak_usage(),"late_invalid_rejection_us":rejection_us,"replay_verified":true,"godot":Engine.get_version_info().string}))
 quit()
