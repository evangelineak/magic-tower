extends "res://tools/audit_endless_v10_walks.gd"
# Independent legal histories only: no stat grants, position injection or invented gear.
var preview_checks:=0
var monster_counts:={"t":0,"p":0}
var persistence_checked:=false
func check_storage(w):
 var Store=load("res://scripts/endless_store.gd")
 var path="/tmp/v12-gear-store-"+str(Time.get_ticks_usec())+".json"
 var store=Store.new(path);var replay=W.new_run(w.seed)
 var saved=await store.start(replay.save_data(),0)
 for code in w.actions:
  check(replay.apply_code(code).get("changed",false),"gear history reconstructs legal action")
  saved=await store.commit(replay.save_data(),saved.revision)
  check(saved.ok,"incremental verified cache persists gear action")
 var loaded=await Store.new(path).read()
 var restored=W.from_data(loaded.snapshot) if loaded.ok else null
 check(restored!=null and restored.gear==w.gear and restored.owned_gear==w.owned_gear and restored.gold==w.gold,"native file restores purchased and equipped gear")
 var before=FileAccess.get_file_as_string(path);var forged=w.save_data();forged.gear="lens"
 check((await store.commit(forged,saved.revision)).status=="invalid" and FileAccess.get_file_as_string(path)==before,"forged gear field cannot overwrite native file")
 DirAccess.remove_absolute(path)
func go(w,target:Vector2i)->bool:
 if w.ended or not problem.is_empty():return false
 var path=route(w,target)
 if path.is_empty() and w.pos!=target:problem="unreachable fixture "+str(target);return false
 for point in path:
  if w.tile(point)=="C":
   if not (w.growth_view().relief_remaining>0 and action(w,"cargo_use").get("changed",false)):
    if not action(w,"cargo_leave").get("changed",false):problem="box refused";return false
  var token:String=w.tile(point)
  if token in monster_counts:monster_counts[token]+=1
  var enemy:bool=token in w.enemy_tokens()
  var before:int=w.hp;var p:Dictionary=w.preview(point) if enemy else {}
  var result:Dictionary=w.step(point-w.pos)
  if result.get("confirm",false):result=w.step(point-w.pos,true)
  if not result.get("changed",false):problem="step refused";return false
  if enemy:
   preview_checks+=1
   check(w.hp==maxi(0,before-int(p.damage))+ (int(p.heal_after) if p.survivable else 0),"actual combat agrees with preview")
   floor_loss+=before-w.hp
  if w.ended:return false
 return true
func run():
 W=load("res://scripts/endless_world_v12.gd");G=load("res://scripts/endless_generation_v12.gd")
 var reports=[]
 for seed in [0,42]:
  for chosen in ["none","cloak","lens"]:
   for route_name in ["primary","alternate"]:
    lane=route_name;problem="";supply_policy="skip_plus_potion"
    var w=W.new_run(seed);var rows=[];var bought_at=0
    for f in range(1,101):
     floor_loss=0;floor_paid=0;floor_healing=0;floor_gross_loss=0
     var y:int=1 if f%2 else 13
     if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):break
     if not go(w,station_anchor(w,"M")):break
     if chosen!="none" and not w.owned_gear[chosen] and w.gold>=40:
      var before=w.save_data();var base_atk:int=w.atk;var base_def:int=w.defense;var gold:int=w.gold
      check(w.act("buy_"+chosen).get("changed",false),"legally funded purchase")
      check(w.gold==gold-40 and w.gear=="" and w.atk==base_atk and w.defense==base_def,"purchase costs 40 without auto-equip or base growth")
      check(w.act("gear_"+chosen).get("changed",false),"camp equip")
      check(w.atk==base_atk and w.defense==base_def,"equip preserves growth")
      var after=w.save_data();check(not w.act("buy_"+chosen).get("changed",false) and w.save_data()==after,"duplicate purchase atomic rejection")
      bought_at=f
      if not persistence_checked:
       await check_storage(w)
       persistence_checked=true
     apply_balanced(w)
     var points:Array=G.routes(w.seed,f)[0 if lane=="primary" else 1].points.duplicate()
     if f%2==0:points.reverse()
     var forecast:Dictionary=w.summary().routes[0 if lane=="primary" else 1]
     var loss_before=floor_loss
     for point in points:
      if not go(w,point):break
     if w.ended or not problem.is_empty():break
     check(floor_loss-loss_before==int(forecast.net_damage),"route summary includes equipped gear and actual ordered combat")
     var frozen=w.save_data();var invalid=w.act("gear_none")
     check(not invalid.get("changed",false) and w.save_data()==frozen,"away from camp equip cannot mutate history")
     var cloned=w.clone();check(cloned.gear==w.gear and cloned.owned_gear==w.owned_gear,"clone retains gear")
     cloned.owned_gear.cloak=not cloned.owned_gear.cloak
     check(cloned.owned_gear!=w.owned_gear,"clone owns independent gear dictionary")
     if not go(w,G.anchors(f).exit):break
     rows.append({"floor":f,"hp":w.hp,"gold":w.gold,"net_damage":floor_loss,"gear":w.gear,"base_atk":w.atk,"base_def":w.defense,"events":w.actions.size()})
    check(problem.is_empty(),"journey fixture valid "+problem)
    var replay=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
    check(replay!=null and replay.save_data()==w.save_data() and replay.gear==w.gear and replay.owned_gear==w.owned_gear and replay.hp==w.hp and replay.gold==w.gold,"full legal history replays gear and resources")
    var forged=w.save_data();forged.gear="lens";check(W.from_data(forged)==null,"DTO refuses forged gear field")
    reports.append({"seed":seed,"policy":chosen,"route":lane,"completed":rows.size(),"ended":w.ended,"bought_at":bought_at,"problem":problem,"rows":rows})
    print("ROSTER_PROGRESS "+str([chosen,lane,rows.size(),w.hp,w.gold]))
 print("ROSTER_RESULT "+JSON.stringify({"rules":12,"checks":checks,"monster_counts":monster_counts,"preview_checks":preview_checks,"failures":failures,"reports":reports}))
 quit(0 if failures==0 else 1)
