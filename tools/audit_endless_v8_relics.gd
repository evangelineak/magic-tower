extends "res://tools/audit_endless_v8_balance.gd"
# Separate legal detour: finish 12 floors, revisit vaults on 3/4, then resume at 13.
func travel_floor(w,target_floor:int)->bool:
 while w.floor_number!=target_floor:
  var descending:bool=w.floor_number>target_floor
  var stair:Vector2i=G.anchors(w.floor_number).entry if descending else G.anchors(w.floor_number).exit
  if w.pos==stair:
   var moved=false
   for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    if w.tile(w.pos+d)==".":moved=w.step(d).get("changed",false);break
   if not moved:problem="cannot step off stair";return false
  if not go(w,stair):return false
 return true
func collect_two(w)->Dictionary:
 var before:Dictionary={"hp":w.hp,"atk":w.atk,"def":w.defense,"gold":w.gold,"actions":w.actions.size(),"relic_bonus":w.relic_bonus}
 var guards=[]
 for old_floor in [3,4]:
  if not travel_floor(w,old_floor) or not go(w,Vector2i(9,10)):return {"ok":false,"problem":problem,"ended":w.ended}
  guards.append(w.preview(Vector2i(10,10)).damage)
  if not go(w,Vector2i(10,10)) or not go(w,Vector2i(12,10)):return {"ok":false,"problem":problem,"ended":w.ended}
 if not travel_floor(w,13):return {"ok":false,"problem":problem,"ended":w.ended}
 return {"ok":true,"guard_damages":guards,"hp_change":w.hp-before.hp,"atk_change":w.atk-before.atk,"def_change":w.defense-before.def,"gold_change":w.gold-before.gold,"actions":w.actions.size()-before.actions,"relic_bonus":w.relic_bonus,"effective_level":w.effective_level(),"growth":w.growth_view(),"replay_verified":replay_matches(w)}
func run():
 W=load("res://scripts/endless_world_v8.gd");G=load("res://scripts/endless_generation_v8.gd")
 var reports=[]
 for seed in [0,42]:
  for route_name in ["primary","alternate"]:
   for box_policy in ["paid_supply","skip_plus_potion"]:
    lane=route_name;problem="";declined=0;boxes_used=0;boxes_left=0;supply_policy=box_policy
    var w=W.new_run(seed);var rows=[];var detour={};var completed=0;var streak=0;var longest=0
    for f in range(1,101):
     floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0
     var before_hp:int=w.hp;var before_gold:int=w.gold
     var y:int=1 if f%2 else 13
     if go(w,Vector2i(2 if f%2 else 12,y)) and go(w,Vector2i(3 if f%2 else 11,y)):
      apply_policy(w,"balanced",y)
      go(w,G.anchors(f).exit)
     if w.floor_number==f+1:completed=f
     if floor_loss==0 and completed==f:streak+=1;longest=maxi(longest,streak)
     else:streak=0
     rows.append({"floor":f,"completed":completed==f,"damage":floor_loss,"gross_loss":floor_gross_loss,"healing":floor_healing,"spent":floor_paid,"hp":w.hp,"net_hp":w.hp-before_hp,"gold":w.gold,"gold_change":w.gold-before_gold,"atk":w.atk,"def":w.defense})
     if w.ended or not problem.is_empty():break
     if f==12:
      detour=collect_two(w)
      if not detour.ok:break
    if not replay_matches(w):push_error("Relic replay mismatch");quit(1);return
    reports.append({"seed":seed,"route":lane,"supply_policy":supply_policy,"completed_floors":completed,"ended":w.ended,"fixture_problem":problem,"detour":detour,"rows":rows,"longest_zero_streak":longest,"replay_verified":true})
    print("RELIC_PROGRESS "+str([seed,lane,supply_policy,completed,w.hp]))
 print("RELIC_RESULT "+JSON.stringify({"rules":8,"reports":reports,"note":"Legal two-vault revisit, no injected relics or stats"}))
 quit()
