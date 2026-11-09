extends "res://tools/audit_endless_v21_oracle_journeys.gd"
# Legal world action histories, not injected water/HP/guard state. Persistence
# CAS/browser writes are independently verified by the storage worker.
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
   if parents.has(n) or n in blocked or token in ["#","~","F","u","v","N","M","S","E","R","O"]:continue
   if token in ["V","B","J","L"] and n!=target:continue
   if token=="D" and not allow_door:continue
   if token in ["<",">"] and n!=target:continue
   parents[n]=p;queue.append(n)
 return []
func water_checkpoint(w):
 snapshot_check(w)
 var copy=w.clone();var loaded=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
 check(loaded!=null and loaded.water_states==w.water_states and copy.water_states==w.water_states,"canonical water actions replay and clone")
 if loaded!=null:check(loaded.grid()==w.grid() and loaded.pos==w.pos,"water replay exact grid/player")
func turn(w,desired:int,alias:bool=false):
 var before=w.save_data();var old:int=w.water_state();var p:Vector2i=w.pos
 var resources=[w.hp,w.gold,w.keys,w.focus,w.kills,w.items.duplicate(true),w.deltas.duplicate(true)]
 var action:String="water_turn" if alias else ("water_north" if desired==0 else "water_south")
 var result:Dictionary=w.act(action)
 var changes:bool=alias or old!=desired
 check(result.get("changed",false)==changes,"water target/same-state response")
 check(resources==[w.hp,w.gold,w.keys,w.focus,w.kills,w.items,w.deltas] and w.pos==p,"turn preserves player/resources/guard/loot")
 if changes:
  check(w.water_state()==(1-old if alias else desired) and w.actions.size()==before.actions.size()+1,"turn exact target one event")
  check(w.actions[-1] in ["water_north","water_south"],"alias records explicit target")
 else:check(w.save_data()==before,"same target logs nothing")
 water_checkpoint(w)
func run():
 W=load("res://scripts/endless_world_v22.gd");G=load("res://scripts/endless_generation_v22.gd")
 var chosen={};var reports=[]
 for seed_value in range(128):
  for depth in [4,6]:
   if not G.is_water(seed_value,depth):continue
   var m:Dictionary=G.water_manifest(seed_value,depth);var id:String=str(m.variant)+":"+str(m.initial_state)
   if not chosen.has(id):chosen[id]={"seed":seed_value,"floor":depth,"variant":m.variant,"initial":m.initial_state}
 check(chosen.size()==4,"four variant/initial-state classes sampled")
 for sample in chosen.values():
  problem="";lane="primary";active_policy="selective_tools";supply_policy="skip_plus_potion";allow_door=false;hero_spent=0;tools_used=0
  var w=W.new_run(sample.seed);w.act("hero_warden");w.act("legacy_kit")
  for depth in range(1,int(sample.floor)+1):
   var y:int=1 if depth%2 else 13
   if not go(w,Vector2i(2 if depth%2 else 12,y)) or not go(w,Vector2i(3 if depth%2 else 11,y)):break
   apply_balanced(w);draft(w)
   if depth==int(sample.floor):break
   var points:Array=G.routes(w.seed,depth)[0].points.duplicate()
   if depth%2==0:points.reverse()
   for point in points:
    if not go(w,point):break
   if not go(w,G.anchors(depth).exit):break
  check(problem.is_empty() and not w.ended and w.floor_number==sample.floor,"ordinary journey reaches real water room "+problem)
  if not problem.is_empty() or w.ended:continue
  var distant=w.save_data()
  check(not w.act("water_turn").get("changed",false) and w.save_data()==distant,"distant valve command rejected")
  lane="alternate"
  if not go(w,Vector2i(5,12)):check(false,"lower control reachable "+problem);continue
  turn(w,w.water_state());turn(w,1)
  var manifest:Dictionary=w.water_view();var before_kills:int=w.kills
  if not go(w,Vector2i(6,7)):check(false,"south pool/guard reaches island "+problem);continue
  check(w.kills==before_kills+1 and w.tile(manifest.guardians.south)==".","actual south guardian cleared")
  turn(w,0,true) if w.water_state()==1 else turn(w,0)
  var prior=w.save_data();var refused:Dictionary=w.step(Vector2i.DOWN)
  check(not refused.get("changed",false) and w.save_data()==prior and w.tile(Vector2i(6,8))=="~","deep water rejects direct movement")
  check(w.safe_path(Vector2i(6,8)).is_empty(),"safe walker cannot route into deep water")
  check(w.safe_path(Vector2i(12,13)).is_empty(),"new water blocks formerly cleared retreat route")
  var forged=w.save_data();forged.actions.append("water_turn")
  check(W.from_data(forged)==null,"toggle alias forbidden in replay")
  if not go(w,Vector2i(5,2)):check(false,"north pool/guard reaches upper control "+problem);continue
  check(w.tile(manifest.guardians.north)=="." and w.tile(manifest.guardians.south)==".","both water guardians persist dead")
  var water_floor:int=w.floor_number;var saved_water=w.water_states.duplicate(true)
  if not go(w,Vector2i(2,1)):check(false,"upper exit approach "+problem);continue
  check(w.step(Vector2i.LEFT).get("changed",false) and w.floor_number==water_floor+1 and w.pos==Vector2i(1,1),"upper paired stair coordinate")
  var away:=Vector2i.DOWN if w.tile(w.pos+Vector2i.DOWN)=="." else Vector2i.RIGHT
  w.step(away);w.step(-away)
  check(w.floor_number==water_floor and w.pos==Vector2i(1,1) and w.water_states==saved_water,"upper revisit preserves water at exact stair")
  if not go(w,Vector2i(5,2)):check(false,"upper control after revisit "+problem);continue
  turn(w,1);turn(w,0)
  if not go(w,Vector2i(6,7)):check(false,"return to island "+problem);continue
  turn(w,1)
  check(not w.safe_path(Vector2i(12,13)).is_empty(),"restoring water restores safe retreat path")
  if not go(w,Vector2i(12,13)):check(false,"restored retreat reaches original stair approach "+problem);continue
  check(w.tile(manifest.guardians.main) in w.enemy_tokens(),"water route never clears main guardian")
  check(w.tile(manifest.guardians.vault)=="V" and w.tile(manifest.relic)=="T","optional guarded relic remains intact")
  water_checkpoint(w)
  var prior_states=w.water_states.duplicate(true);var target_floor:int=w.floor_number
  # Physically descend to previous floor and re-enter at paired coordinates.
  check(w.step(Vector2i.RIGHT).get("changed",false) and w.floor_number==target_floor-1,"leave floor via entry stair")
  w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT)
  check(w.floor_number==target_floor and w.water_states==prior_states and w.tile(manifest.guardians.south)=="." and w.tile(manifest.guardians.north)==".","floor revisit preserves water and kills")
  water_checkpoint(w)
  reports.append({"seed":sample.seed,"floor":sample.floor,"variant":sample.variant,"initial":sample.initial,"final_water":w.water_state(),"hp":w.hp,"kills":w.kills,"actions":w.actions.size(),"water_actions":w.actions.filter(func(a):return a.begins_with("water_"))})
 print("WATER_INDEPENDENT_WORLD "+JSON.stringify({"checks":checks,"failures":failures,"reports":reports,"note":"Four legal action journeys from new game to actual water room, toggle/guard/retreat/revisit/full replay; no combat or positional injection. Profile unlock eligibility and storage CAS are separate."}))
 quit(0 if failures==0 and reports.size()==4 else 1)
