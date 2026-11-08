extends "res://tools/audit_cargo_routes.gd"
# Legal-route audit; no injected resources, map edits, or quest flags.
const Expedition=preload("res://scripts/expedition.gd")
var observations=0
func observe(w,label):
 var saved=w.save_data().duplicate(true);var message=w.message;var battle=w.last_battle.duplicate(true)
 var goals=w.call("exploration_goals")
 assert(w.save_data()==saved and w.message==message and w.last_battle==battle,"goal lookup mutated the journey")
 assert(goals==w.call("exploration_goals"),"same world produced unstable goals")
 var ids=[]
 for entry in goals:
  ids.append(entry.id)
  assert(entry.pos==entry.position,"position aliases disagree")
  var known=entry.floor>=0 and entry.floor<w.floor_seen.size() and w.floor_seen[entry.floor]
  if not known:assert(entry.position==Vector2i(-1,-1),"unknown floor coordinate leaked")
 if not w.floor_seen[2]:assert(not "vault" in ids,"unseen vault leaked")
 if label=="fresh":assert(not "mira" in ids and not "survey" in ids,"unaccepted unseen quest leaked")
 if label in ["sample_delivered_J"]:assert(not "survey" in ids,"resolved sample goal remained")
 if label=="vault_claimed":assert(not "vault" in ids,"collected treasure goal remained")
 if label=="cargo_claimed":assert(not "cargo" in ids,"claimed cargo remained")
 if label=="mira_delivered_camp":assert(not "mira" in ids,"resolved Mira goal remained")
 if label=="mira_rescued":assert("mira" in ids,"undecided Mira reward disappeared")
 observations+=1
 print(JSON.stringify({"stage":label,"floor":w.floor_index+1,"goals":goals,"hp":w.hp,"quest":w.quest_state,"rescue":w.rescue_state,"cargo":w.cargo}))
 return goals
func upkeep(w):
 while w.focus>0 and not w.won:assert(w.action("mend"))
func _init():
 var w=W.new(1)
 assert(w.action("hero_scholar"))
 observe(w,"fresh")
 assert(w.action("quest_accept"));assert(w.action("rescue_accept"))
 observe(w,"commissions_accepted_unseen_destinations")
 var shipped=false;var sample=false;var sample_paid=false;var seen={}
 for key in G.generate(1,W.MAPS).validation.route:
  upkeep(w)
  if not seen.has(w.floor_index):seen[w.floor_index]=true;observe(w,"first_visit_"+str(w.floor_index+1))
  if w.floor_index==0 and w.tile(w.pos+DIR[key])==">" and not shipped:
   var origin=w.pos;go(w,0,Vector2i(8,3));assert(w.action("cargo_ship"));observe(w,"shipped_destination_unseen");go(w,0,origin);shipped=true
  if w.floor_index==2 and not sample and route(w,2,Vector2i(2,8))!=null:
   var origin=w.pos;go(w,2,Vector2i(2,8));sample=true
   observe(w,"sample_held_vault_seen")
   var clone=W.from_snapshot(w.save_data())
   if route(clone,0,Vector2i(1,2))!=null:
    go(clone,0,Vector2i(1,2));assert(clone.action("quest_gold"));observe(clone,"sample_delivered_J");sample_paid=true
   go(w,2,origin)
  if sample and not sample_paid and route(w,0,Vector2i(1,2))!=null:
   var delivered=W.from_snapshot(w.save_data());go(delivered,0,Vector2i(1,2));assert(delivered.action("quest_gold"));observe(delivered,"sample_delivered_J");sample_paid=true
  assert(w.step(DIR[key]),w.message)
 observe(w,"chapter1_won_cargo_not_ready")
 assert(w.action("expedition"));observe(w,"continued_cargo_ready")
 var claim=W.from_snapshot(w.save_data());go(claim,4,Vector2i(1,3));assert(claim.action("cargo_claim"));observe(claim,"cargo_claimed")
 var rescued=false;var vault_claimed=false
 for key in Expedition.generate(1).witness:
  upkeep(w)
  if not seen.has(w.floor_index):seen[w.floor_index]=true;observe(w,"first_visit_"+str(w.floor_index+1))
  if w.floor_index==6 and not rescued and route(w,6,Vector2i(8,2))!=null:
   var clone=W.from_snapshot(w.save_data());go(clone,6,Vector2i(8,2));upkeep(clone)
   observe(clone,"gaoler_before_fight")
   if clone.step(Vector2i.RIGHT):
    observe(clone,"gaoler_defeated_apprentice_unrescued")
    assert(clone.step(Vector2i.UP));observe(clone,"mira_rescued")
    go(clone,5,Vector2i(8,8));assert(clone.action("rescue_supplies"));observe(clone,"mira_delivered_camp");rescued=true
    go(clone,2,Vector2i(7,3));upkeep(clone)
    assert(clone.step(Vector2i.RIGHT));observe(clone,"vault_guard_defeated")
    assert(clone.step(Vector2i.RIGHT));observe(clone,"vault_claimed");vault_claimed=true
  assert(w.step(DIR[key]),w.message)
 assert(shipped and sample and sample_paid and rescued and vault_claimed,"route did not exercise all required goal changes")
 observe(w,"victory")
 print("EXPLORATION AUDIT PASS: "+str(observations)+" pure goal observations")
 quit()

func route(w,f,target):
 var start=Vector3i(w.pos.x,w.pos.y,w.floor_index);var end=Vector3i(target.x,target.y,f)
 var queue=[start];var prev={start:null};var arrows={}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p==end:
   var result=""
   while p!=start:result=arrows[p]+result;p=prev[p]
   return result
  for key in DIR:
   var n=Vector2i(p.x,p.y)+DIR[key]
   if n.x<1 or n.x>9 or n.y<1 or n.y>9:continue
   var token=w.floors[p.z][n.y][n.x]
   if not token in [".","k","h","a","d","C","I","M","J","O","F","N","E","Q","X","U","Y","v","<",">"]:continue
   var q=Vector3i(n.x,n.y,p.z)
   if token in ["<",">"]:
    var dest=W.Layout.stair_destination(w.floors,w.layout_revision,p.z,n)
    if not dest.ok or not w.floor_seen[dest.floor]:continue
    q=Vector3i(dest.pos.x,dest.pos.y,dest.floor)
   if prev.has(q):continue
   prev[q]=p;arrows[q]=key;queue.append(q)
 return null
