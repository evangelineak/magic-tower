extends "res://tools/audit_endless_v12_roster.gd"
# Each policy uses legal actions only. No equipment bought, to isolate inscriptions.
func run():
 W=load("res://scripts/endless_world_v13.gd");G=load("res://scripts/endless_generation_v13.gd")
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for policy in ["none","always","forecast"]:
    lane=route_name;problem="";supply_policy="skip_plus_potion"
    var w=W.new_run(seed);var rows=[];var paid=0;var activated=0;var unavailable=0
    for f in range(1,101):
     floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0
     var y:int=1 if f%2 else 13
     if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):break
     apply_balanced(w)
     var view:Dictionary=w.rune_view();var index:int=0 if lane=="primary" else 1
     var want:bool=policy=="always"
     if policy=="forecast":
      var b:Dictionary=view.before_routes[index];var a:Dictionary=view.after_routes[index]
      want=bool(a.valid) and ((a.survivable and not b.survivable) or int(a.net_damage)<int(b.net_damage))
     var used=false
     if want:
      # Never step onto the stair and accidentally change floors.
      if not go(w,Vector2i(2 if f%2 else 12,y)):break
      view=w.rune_view()
      if view.available:
       var before=w.save_data();var gold:int=w.gold
       var confirmation:Dictionary=w.act("rune_on")
       check(confirmation.get("confirm",false) and w.save_data()==before and w.gold==gold,"confirmation does not pay or append event")
       var result:Dictionary=w.act("rune_on!")
       check(result.get("changed",false),"legal confirmed rune activation")
       check(w.gold==gold-int(view.price),"rune pays disclosed price once")
       paid+=gold-w.gold;activated+=1;used=true
       var after=w.save_data()
       check(not w.act("rune_on!").get("changed",false) and w.save_data()==after,"duplicate activation atomic no-op")
      else:unavailable+=1
     # Re-optimize only tactics, not permanent training, after rule change.
     if used:
      if not go(w,station_anchor(w,"M")):break
      var best:String=w.tactic;var loss:=2147483647
      for id in ["none","brace","reap","pierce"]:
       var trial=w.clone()
       if trial.tactic!=id and not trial.act("tactic_"+id).get("changed",false):continue
       var info:Dictionary=trial.summary().routes[index]
       if info.valid and int(info.net_damage)<loss:best=id;loss=int(info.net_damage)
      if best!=w.tactic:choose(w,"tactic_"+best)
     var points:Array=G.routes(seed,f)[index].points.duplicate()
     if f%2==0:points.reverse()
     var predicted:Dictionary=w.summary().routes[index];var before_loss=floor_loss
     for point in points:
      if not go(w,point):break
     if w.ended or not problem.is_empty():break
     check(floor_loss-before_loss==int(predicted.net_damage),"actual chosen route loss matches active rune forecast")
     if not go(w,G.anchors(f).exit):break
     rows.append({"floor":f,"hp":w.hp,"gold":w.gold,"net_damage":floor_loss,"rune":view.kind,"activated":used,"paid_total":paid,"count_total":activated,"events":w.actions.size()})
    var replay=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
    check(replay!=null and replay.save_data()==w.save_data() and replay.runes==w.runes and replay.hp==w.hp and replay.gold==w.gold,"full legal history replays per-floor inscriptions")
    check(problem.is_empty(),"legal fixture unobstructed "+problem)
    reports.append({"seed":seed,"route":lane,"policy":policy,"completed":rows.size(),"ended":w.ended,"problem":problem,"paid":paid,"activated":activated,"unavailable":unavailable,"rows":rows})
    print("RUNE_PROGRESS "+str([seed,lane,policy,rows.size(),paid,activated,w.hp,w.gold]))
 print("RUNE_RESULT "+JSON.stringify({"rules":13,"checks":checks,"failures":failures,"monster_counts":monster_counts,"reports":reports,"forecast_policy":"health-greedy strict lower predicted net loss, not optimal economic valuation"}))
 quit(0 if failures==0 else 1)
