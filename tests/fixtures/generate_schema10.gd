extends SceneTree
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func state(w)->Dictionary: return w.save_data().duplicate(true)
func reject(w,id:String):
 var before=state(w)
 check(not w.action(id) and state(w)==before,"rejected without mutation: "+id)
func restore_check(w):
 var copy=World.new(0)
 check(copy.restore(JSON.parse_string(JSON.stringify(state(w)))) and state(copy)==state(w),"legal rescue state JSON roundtrip")
func replay(w,route:String)->bool:
 for c in route:
  if not w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]): return false
 return true
func walk(w,goal:Vector2i)->bool:
 if w.pos==goal: return true
 var queue:Array=[[w.pos,[]]]; var seen:Dictionary={w.pos:true}
 while not queue.is_empty():
  var row:Array=queue.pop_front(); var p:Vector2i=row[0]
  if p==goal:
   for d in row[1]:
    if not w.step(d): return false
   return true
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d
   if seen.has(n): continue
   var token:String=w.tile(n)
   if token in ["#","L","D"]: continue
   if token=="n" and w.winch_choice!="rescue": continue
   if token=="e" and w.winch_choice!="armory": continue
   if token=="m" and n!=goal: continue
   if token=="=" and not w.expedition_bridge: continue
   if token=="~" and not w.bridge_built and w.water_choice!="drain": continue
   if token in ["<",">","W","Z","K","V","t"] and n!=goal: continue
   if World.ENEMIES.has(token) and (w.damage(token)<0 or w.damage(token)>=w.hp): continue
   seen[n]=true; var path:Array=row[1].duplicate(); path.append(d); queue.append([n,path])
 return false
func travel(w,floor_id:int)->bool:
 for i in range(12):
  if w.floor_index==floor_id: return true
  var stair=Vector2i(1,1) if w.floor_index>floor_id else Vector2i(9,9)
  if w.pos==stair:
   if not w.step(Vector2i.RIGHT if stair.x==1 else Vector2i.LEFT): return false
  if not walk(w,stair): return false
 return false
func key(scene,code):
 var event=InputEventKey.new(); event.pressed=true; event.keycode=code; scene._unhandled_input(event)
func _initialize():
 var w=World.new(0)
 assert(replay(w,Generator.validate(w.floors).route) and w.action("expedition"))
 for c in Expedition.validate(w.floors.slice(5)).route:
  var d:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]
  if w.tile(w.pos+d)=="Z": break
  assert(w.step(d))
 assert(travel(w,6) and walk(w,Vector2i(7,4)))
 var branchpoint=w.save_data().duplicate(true)
 for branch in ["rescue","armory"]:
  assert(w.restore(branchpoint) and w.action("winch_"+branch))
  if branch=="rescue":
   assert(walk(w,Vector2i(9,1)) and w.tile(Vector2i(9,2))=="W" and not w.maul_claimed)
  else:
   assert(walk(w,Vector2i(9,4)) and w.maul_claimed)
   assert(w.action("equip_balanced") and walk(w,Vector2i(9,2)) and walk(w,Vector2i(9,1)))
  assert(w.rescue_state==2 and w.rescue_reward=="")
  assert(travel(w,0) and walk(w,Vector2i(1,2)))
  assert(w.npc_offers().any(func(row):return row[0]=="rescue_repeater"))
  var data=w.save_data()
  assert(data.version==10)
  var file=FileAccess.open("/tmp/tower-v17-legacy/schema10-"+branch+".json",FileAccess.WRITE)
  file.store_string(JSON.stringify(data)); file.close()
  print(branch,": moves=",w.moves," HP=",w.hp," maul=",w.maul_claimed," rescue=",w.rescue_state)
 quit()
