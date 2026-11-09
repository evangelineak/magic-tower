extends "res://tools/audit_endless_v19_journeys.gd"
var skill_policy:="never"
var focus_spent:=0
var focus_earned:=0
var focus_overflow:=0
var skills_armed:=0
var skill_healing:=0
func action(w,id:String)->Dictionary:
 var before:int=w.focus;var hp:int=w.hp
 var result:Dictionary=super.action(w,id)
 if result.get("changed",false):
  focus_spent+=maxi(0,before-w.focus)
  if id=="skill_use":
   if w.hero_id=="scholar":skill_healing+=w.hp-hp
   else:skills_armed+=1
 return result
func prepare_tool(w,point:Vector2i):
 if skill_policy=="never" or w.focus<=0 or w.skill_armed or w.tile(point) not in w.enemy_tokens():return
 if w.hero_id=="scholar":
  if w.hp<=156:action(w,"skill_use")
  return
 # Greedy player policy can inspect the same forecast the UI exposes.
 # This is not an independent combat oracle or proof of optimal allocation.
 var plain:Dictionary=w.preview(point);var trial=w.clone()
 if not trial.act("skill_use").get("changed",false):return
 var boosted:Dictionary=trial.preview(point)
 if boosted.valid and int(boosted.damage)-int(boosted.get("heal_after",0))<int(plain.damage)-int(plain.get("heal_after",0)):
  action(w,"skill_use")
func go(w,target:Vector2i)->bool:
 if w.ended or not problem.is_empty():return false
 var steps=route(w,target)
 if steps.is_empty() and w.pos!=target:problem="unreachable fixture "+str(target);return false
 for point in steps:
  if w.tile(point)=="C":
   if not (w.relief_remaining>0 and action(w,"cargo_use").get("changed",false)):
    if not action(w,"cargo_leave").get("changed",false):problem="could not discard box";return false
  prepare_tool(w,point)
  var token:String=w.tile(point);var enemy:bool=token in w.enemy_tokens();var hp:int=w.hp;var gold:int=w.gold;var focus_before:int=w.focus;var highest:int=w.max_floor
  var result:Dictionary=w.step(point-w.pos)
  if result.get("confirm",false):result=w.step(point-w.pos,true)
  if not result.get("changed",false):problem="step refused "+str(result);return false
  # Observe committed resource changes, rather than summing forecast damage.
  if enemy:
   var battle:Dictionary=result.get("battle",{})
   var healed:int=int(battle.get("heal_after",0)) if not w.ended else 0
   floor_loss+=hp-w.hp;floor_gross_loss+=hp-w.hp+healed;floor_healing+=healed
   focus_spent+=maxi(0,focus_before-w.focus)
  else:floor_healing+=maxi(0,w.hp-hp)
  if w.max_floor>highest:
   var potential:int=int(w.max_floor/4)-int(highest/4)
   var actual:int=maxi(0,w.focus-focus_before)
   focus_earned+=actual;focus_overflow+=potential-actual
  check(w.focus>=0 and w.focus<=3 and w.focus==2+focus_earned-focus_spent,"actual focus conservation/cap")
  floor_income+=maxi(0,w.gold-gold)
  if w.ended:return false
 return true
func run():
 W=load("res://scripts/endless_world_v20.gd");G=load("res://scripts/endless_generation_v19.gd")
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for hero in ["warden","ranger","scholar"]:
    for policy in ["never","greedy"]:
     lane=route_name;skill_policy=policy;problem="";supply_policy="skip_plus_potion";allow_door=false
     focus_spent=0;focus_earned=0;focus_overflow=0;skills_armed=0;skill_healing=0
     var w=W.new_run(seed);check(w.act("hero_"+hero).get("changed",false),"real initial hero event")
     var rows=[]
     for f in range(1,101):
      floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0;floor_income=0;floor_door_income=0;floor_potion_spent=0;floor_potion_heal=0
      var y:int=1 if f%2 else 13
      if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):break
      apply_balanced(w)
      var points:Array=G.routes(seed,f)[0 if lane=="primary" else 1].points.duplicate()
      if f%2==0:points.reverse()
      for point in points:
       if not go(w,point):break
      if w.ended or not problem.is_empty():break
      if not go(w,G.anchors(f).exit):break
      rows.append({"floor":f,"hp":w.hp,"gold":w.gold,"focus":w.focus,"focus_spent_total":focus_spent,"focus_earned_total":focus_earned,"focus_overflow_total":focus_overflow,"skill_healing_total":skill_healing,"net_damage":floor_loss,"gross_damage":floor_gross_loss,"healing":floor_healing,"spent":floor_paid,"potion_spent":floor_potion_spent,"potion_heal":floor_potion_heal,"events":w.actions.size()})
     check(problem.is_empty(),"legal hero route fixture "+problem)
     var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
     check(restored!=null and restored.save_data()==w.save_data() and restored.hero_id==w.hero_id and restored.focus==w.focus and restored.skill_armed==w.skill_armed and restored.hp==w.hp and restored.gold==w.gold and restored.items==w.items and restored.deltas==w.deltas,"actual full hero journey replay")
     reports.append({"seed":seed,"route":lane,"hero":hero,"policy":policy,"completed":rows.size(),"ended":w.ended,"problem":problem,"end_hp":w.hp,"end_gold":w.gold,"focus":w.focus,"focus_spent":focus_spent,"focus_earned":focus_earned,"focus_overflow":focus_overflow,"skills_armed":skills_armed,"skill_healing":skill_healing,"rows":rows})
     print("HERO_JOURNEY_PROGRESS "+str([seed,lane,hero,policy,rows.size(),w.hp,w.gold,focus_spent]))
 print("HERO_JOURNEY_RESULT "+JSON.stringify({"rules":20,"checks":checks,"failures":failures,"reports":reports,"policy":"No key vaults/cart claims/runes/gear/items; finite balanced lessons+tactics; potion at camp HP<=130. Never vs greedy immediate forecast net-loss reduction for warden/ranger, full24 scholar before a battle. Actual committed resource deltas are measured; not an independent combat oracle, optimal policy or universal balance proof."}))
 quit(0 if failures==0 else 1)
