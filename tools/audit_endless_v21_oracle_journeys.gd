extends "res://tools/audit_endless_v19_journeys.gd"
# World-log journeys only: legacy entitlement transactions are separately tested
# by the store suite. No enemy, stats, kills, maps or action history injection.
var hero_spent:=0
var draft_index:=0
func prepare_tool(w,point:Vector2i):
 if w.tile(point) not in w.enemy_tokens():return
 if w.hero_id=="scholar":
  if w.hp<=140 and w.focus>=w.skill_cost():
   if w.act("skill_use").get("changed",false):hero_spent+=w.skill_cost()
 elif not w.skill_armed and w.focus>=w.skill_cost():
  var before:Dictionary=w.preview(point);var probe=w.clone()
  if probe.act("skill_use").get("changed",false):
   var after:Dictionary=probe.preview(point)
   if after.valid and (not before.valid or int(after.net_damage)<int(before.net_damage)):
    if w.act("skill_use").get("changed",false):hero_spent+=w.skill_cost()
 super.prepare_tool(w,point)
func draft(w):
 if w.skill_armed:w.act("skill_cancel")
 while w.talent_view().available:
  var view:Dictionary=w.talent_view();var before:Array=w.talent_draft();var offer:Dictionary=view.offers[draft_index%3]
  check(w.act(offer.action).get("changed",false),"earned talent selected")
  check(w.talent_draft()==before,"actual earned choice preserves later offers")
func snapshot_check(w):
 var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
 check(restored!=null,"legal build history replays")
 if restored==null:return
 for key in ["hp","atk","defense","gold","kills","pos","floor_number","max_floor","focus","skill_armed","hero_id","legacy_id","legacy_coin_used","talents","last_kill_kind","items","deltas"]:
  check(restored.get(key)==w.get(key),"legal replay "+key)
func run():
 W=load("res://scripts/endless_world_v21.gd");G=load("res://scripts/endless_generation_v19.gd")
 var reports=[]
 for seed_value in [0,42]:
  for hero in ["warden","ranger","scholar"]:
   for legacy in ["none","kit","coin","mind"]:
    lane="primary";active_policy="selective_tools";supply_policy="skip_plus_potion";allow_door=false;problem="";hero_spent=0;tools_used=0;draft_index=(seed_value+legacy.length())%3
    var w=W.new_run(seed_value);w.act("hero_"+hero);w.act("legacy_"+legacy);var rows=[]
    for depth in range(1,17):
     floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0;floor_income=0;floor_door_income=0;floor_potion_spent=0;floor_potion_heal=0
     var y:int=1 if depth%2 else 13
     if not go(w,Vector2i(2 if depth%2 else 12,y)) or not go(w,Vector2i(3 if depth%2 else 11,y)):break
     apply_balanced(w)
     var points:Array=G.routes(seed_value,depth)[0].points.duplicate()
     if depth%2==0:points.reverse()
     for point in points:
      if not go(w,point):break
     if w.ended or not problem.is_empty():break
     draft(w);snapshot_check(w)
     if not go(w,G.anchors(depth).exit):break
     rows.append({"floor":depth,"hp":w.hp,"gold":w.gold,"focus":w.focus,"last_kill_kind":w.last_kill_kind,"talents":w.talents.duplicate(),"actions":w.actions.size()})
    check(problem.is_empty() and rows.size()==16 and not w.ended,"legal16-floor sample "+str([seed_value,hero,legacy])+" "+problem)
    check(w.talents.size()==3,"all three tiers earned through real kills")
    snapshot_check(w)
    reports.append({"seed":seed_value,"hero":hero,"legacy":legacy,"draft_index":draft_index,"completed":rows.size(),"ended":w.ended,"problem":problem,"skill_focus_spent":hero_spent,"tools_used":tools_used,"rows":rows})
 print("V21_ORACLE_JOURNEYS "+JSON.stringify({"checks":checks,"failures":failures,"reports":reports,"controlled_stats":false,"note":"24 legal16-floor world-action journeys; profile unlock eligibility and persistent transactions are separately verified. Not general solvability or 100-floor balance proof."}))
 quit(0 if failures==0 else 1)
