extends SceneTree
# All checkpoints below originate in actual World actions. Clones explore
# alternatives; none receives injected stats, equipment, positions or map edits.
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const DIR={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var observations=0
func route(w,f,target,clear_only=false):
 var start=Vector3i(w.pos.x,w.pos.y,w.floor_index);var goal=Vector3i(target.x,target.y,f)
 var queue=[start];var prev={start:null};var arrows={}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p==goal:
   var result=[]
   while p!=start:result.push_front(arrows[p]);p=prev[p]
   return result
  for d in DIR.values():
   var n=Vector2i(p.x,p.y)+d
   if n.x<1 or n.x>9 or n.y<1 or n.y>9:continue
   var t=w.floors[p.z][n.y][n.x]
   if clear_only:
    if t!=".":continue
   else:
    if not t in [".","a","d","h","k","C","I","M","J","F","N","E","O","R","X","U","Y","v","m","<",">"] and not (t=="~" and w.water_choice=="drain") and not (t=="e" and w.winch_choice=="armory") and not (t=="=" and w.expedition_bridge):continue
   var q=Vector3i(n.x,n.y,p.z)
   if t in ["<",">"]:
    var landing=W.Layout.stair_destination(w.floors,w.layout_revision,p.z,n)
    if not landing.ok or not w.floor_seen[landing.floor]:continue
    q=Vector3i(landing.pos.x,landing.pos.y,landing.floor)
   if prev.has(q):continue
   prev[q]=p;arrows[q]=d;queue.append(q)
 return null
func go(w,f,target,clear_only=false):
 var path=route(w,f,target,clear_only)
 assert(path!=null,"no legal route to "+str(target))
 for d in path:assert(w.step(d),w.message)
 return path.size()
func find(w,f,token):
 for y in range(1,10):
  for x in range(1,10):
   if w.floors[f][y][x]==token:return Vector2i(x,y)
 return Vector2i(-1,-1)
func acquire_relic(w):
 var f=w.floor_index;var origin=w.pos
 go(w,1,find(w,1,"O"));assert(w.action("drain"))
 go(w,1,find(w,1,"R"));assert(w.action("relic_buckler"))
 go(w,f,origin);assert(w.action("equip_balanced"))
func _initialize():call_deferred("run")
func run():
 for hero in ["warden","ranger"]:
  var w=W.new(0);assert(w.action("hero_"+hero))
  var relic=false
  for key in G.generate(0,W.MAPS).validation.route:
   if w.floor_index==4 and not relic and route(w,1,find(w,1,"O"))!=null:
    acquire_relic(w);relic=true
   assert(w.step(DIR[key]),w.message)
  assert(relic,"actual relic acquisition missing")
  assert(w.action("expedition"))
  var offers=w.talent_options()
  assert("keen_edge" in offers and w.action("talent_keen_edge"),"actual earned first-tier talent")
  assert("adversity_charge" in w.talent_options() and w.action("talent_adversity_charge"),"actual earned damage-triggered focus recovery")
  print(JSON.stringify({"stage":"equipped_checkpoint","hero":hero,"floor":w.floor_index+1,"hp":w.hp,"inventory":w.inventory,"moves":w.moves}))
  for key in E.generate(0).witness:
   var target=w.pos+DIR[key];var kind=w.tile(target)
   if kind=="H":
    inspect(w,target)
    if w.floor_index==5:inspect_flank_route(w,target)
   assert(w.step(DIR[key]),w.message)
 assert(observations>=32,"insufficient actual alternative fights")
 print("TACTICAL ROUTE AUDIT PASS: "+str(observations)+" actual alternative fights")
 quit()
func inspect(w,target):
 var snapshot=w.save_data().duplicate(true);var previous=w.last_battle.duplicate(true);var message=w.message
 var table=w.tactical_forecast(target)
 assert(table.valid and w.save_data()==snapshot and w.last_battle==previous and w.message==message,"forecast mutated checkpoint")
 for row in table.rows:
  for label in ["unarmed","armed","flank_unarmed","flank_armed"]:
   var branch=row[label]
   if branch.is_empty() or not branch.available:continue
   if not label.begins_with("flank_") and w.pos.distance_to(target)!=1:continue
   var expected=branch.preview
   if not expected.valid or not expected.survivable:continue
   var c=W.from_snapshot(snapshot)
   if c.equipped!=row.id:assert(c.action("equip_"+row.id))
   var armed=label in ["armed","flank_armed"]
   if c.skill_armed!=armed:assert(c.action("arm"))
   var steps=0
   if label.begins_with("flank_"):
    for point in table.flank.path:
     var old=c.pos;var f=c.floor_index
     assert(c.safe_walk_step(point,f,old),"forecast route was not actually safe")
     steps+=1
   assert(c.pos==branch.position,"forecast branch used inaccessible position")
   var actual_preview=c.battle_preview(c.tile(target),"",target)
   assert(actual_preview==expected,"equipping/arming/walking diverges from hypothetical preview")
   var hp=c.hp
   assert(c.step(target-c.pos))
   assert(c.hp==branch.after_hp and c.focus==branch.focus_after,"actual battle differs from trial HP/focus")
   observations+=1
   print(JSON.stringify({"hero":w.hero_id,"floor":w.floor_index+1,"target":str(target),"gear":row.id,"branch":label,"safe_walk_steps":steps,"loss":expected.damage,"after_hp":c.hp,"after_focus":c.focus,"restored_focus":branch.focus_restored,"checkpoint_hp":hp}))

func inspect_flank_route(w,target):
 var c=W.from_snapshot(w.save_data())
 var merchant=find(c,5,"Y")
 assert(route(c,5,merchant)!=null,"roadworks should be reachable before first ferry")
 go(c,5,merchant);assert(c.action("camp_bridge"),"actual gold pays for alternative crossing")
 var side=c.flank_position(target)
 assert(route(c,5,side)!=null,"paid crossing should reach flank without fighting H")
 go(c,5,side)
 for d in DIR.values():
  if c.tile(c.pos+d)=="." and c.pos+d!=target:
   assert(c.safe_walk_step(c.pos+d,c.floor_index,c.pos))
   var table=c.tactical_forecast(target)
   assert(table.flank.reachable and table.flank.steps>0,"real cleared-floor flank reposition not demonstrated")
   inspect(c,target);return
 assert(false,"no cleared retreat to demonstrate flank approach")
