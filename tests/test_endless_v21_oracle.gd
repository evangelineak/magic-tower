extends SceneTree
const Oracle=preload("res://tests/endless_v21_combat_oracle.gd")
class Fixture:
 extends "res://scripts/endless_world_v21.gd"
 var fixture_token:="g"
 var inscription:=""
 var stats={"hp":34,"atk":20,"def":12,"gold":7}
 func tile(_point:Vector2i)->String:return fixture_token
 func base_enemy(_token:String)->Dictionary:return stats.duplicate()
 func _rune_kind()->String:return inscription
var checks:=0
var cases:=0
var failures:Array=[]
var samples:Array=[]
func check(ok:bool,label:String,ctx:Dictionary):
 checks+=1
 if not ok and failures.size()<16:failures.append({"label":label,"context":ctx})
func _initialize():call_deferred("run")
func exercise(p:Dictionary):
 var w=Fixture.new();w.seed=int(p.get("seed",42));w.floor_number=int(p.floor);w.max_floor=int(p.floor);w.fixture_token=p.token;w.inscription=p.rune
 w.legacy_id="none";w.talents.assign(p.get("talents",[]));w.last_kill_kind=p.get("last_kill","")
 w.stats={"hp":p.enemy_hp,"atk":p.enemy_atk,"def":p.enemy_def,"gold":7}
 w.hp=int(p.hp);w.atk=int(p.atk);w.defense=int(p.defense);w.hero_id=p.hero;w.focus=int(p.get("focus",2));w.skill_armed=p.armed
 w.tactic=p.tactic;w.training_level=int(p.level);w.relic_bonus=0;w.gear=p.gear;w.armed_item=p.item;w.items={"ward":1,"pierce":1}
 var expected=Oracle.fight(p);var actual=w.preview(w.pos+Vector2i.RIGHT);cases+=1
 var ctx={"input":p,"expected":expected,"actual":actual}
 for key in ["valid","survivable","damage","heal_after","rounds","first_hit","later_hit"]:check(actual.get(key)==expected[key],key,ctx)
 check(actual.get("hero_reduction",0)==expected.hero_saved,"hero reduction",ctx)
 check(actual.get("opening_damage",0)==expected.opening,"opening",ctx)
 check(actual.get("reflection_damage",0)==expected.thorns,"reflection",ctx)
 check(actual.get("regen_total",0)==expected.regen,"regeneration",ctx)
 var before=w.save_data();var prior=w.hp
 var result=w.step(Vector2i.RIGHT,true)
 if not expected.valid:
  check(not result.get("changed",false) and w.save_data()==before and w.hp==prior and w.focus==p.get("focus",2) and w.skill_armed==p.armed,"invalid refusal atomic",ctx)
 else:
  check(result.get("changed",false),"legal combat executes",ctx)
  check(w.hp==maxi(0,prior-int(expected.damage))+int(expected.heal_after),"actual HP",ctx)
  check(w.ended==not expected.survivable,"actual terminal state",ctx)
  check(w.last_kill_kind==(p.token if expected.survivable else p.get("last_kill","")),"only surviving kill updates tracker",ctx)
  check(w.kills==(1 if expected.survivable else 0) and w.gold==(7 if expected.survivable else 0),"only survival rewards",ctx)
  check(w.focus==int(p.get("focus",2))-(int(expected.cost) if expected.used else 0) and not w.skill_armed,"skill spent once in real combat",ctx)
  check(int(w.items.ward)==(0 if p.item=="ward" else 1) and int(w.items.pierce)==(0 if p.item=="pierce" else 1),"item consumption",ctx)
 if samples.size()<12 and p.token in ["r","t","p"] and p.rune=="shock" and p.hero=="warden" and p.hp==3 and p.atk==13:samples.append({"input":p,"expected":expected})
func route_expect(w,active_rune:bool)->Array:
 var Gen=load("res://scripts/endless_generation_v19.gd")
 var rows:Array=[]
 for route in Gen.routes(w.seed,w.floor_number):
  var points:Array=route.points.duplicate()
  if w.floor_number%2==0:points.reverse()
  var health:int=w.hp;var armed:bool=w.skill_armed;var item:String=w.armed_item;var last_kind:String=w.last_kill_kind;var focus:int=w.focus
  var damage:=0;var healed:=0;var valid:=true;var alive:=true;var remaining:=0
  var kind:String=load("res://scripts/endless_generation_v13.gd").rune_info(w.seed,w.floor_number).kind if active_rune else ""
  for point in points:
   var token:String=w.tile(point)
   if token not in w.enemy_tokens():continue
   remaining+=1
   var foe:Dictionary=w.base_enemy(token)
   var p={"talents":w.talents,"last_kill":last_kind,"focus":focus,"token":token,"rune":kind,"hero":w.hero_id,"armed":armed,"tactic":w.tactic,"gear":w.gear,"item":item,"level":w.effective_level(),"atk":w.atk,"defense":w.defense,"enemy_hp":foe.hp,"enemy_atk":foe.atk,"enemy_def":foe.def,"hp":health}
   var result=Oracle.fight(p);valid=valid and result.valid
   if not alive:continue
   damage+=int(result.damage)
   if not result.survivable:alive=false;continue
   healed+=int(result.heal_after);health=health-int(result.damage)+int(result.heal_after);focus-=int(result.cost) if result.used else 0;armed=false;item="";last_kind=token
  rows.append({"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":remaining})
 return rows
func check_route_rows(actual:Array,expected:Array,label:String):
 check(actual.size()==expected.size(),label+" count",{})
 for i in mini(actual.size(),expected.size()):
  for key in expected[i]:check(actual[i][key]==expected[i][key],label+" "+key,{"actual":actual,"expected":expected})
func route_checks(combinations:Dictionary):
 var World=load("res://scripts/endless_world_v21.gd")
 var Gen=load("res://scripts/endless_generation_v19.gd")
 var serial:=0
 for combo in combinations.values():
  var depth:int=[1,50,100][serial%3];serial+=1
  for hero in ["warden","ranger","scholar"]:
   var w=World.new_run(combo.seed);w.act("hero_"+hero);w.act("legacy_none")
   # Controlled, seeded-obtainable ownership; not a claimed legal journey.
   w.talents.assign(combo.ids);w.floor_number=depth;w.max_floor=depth;w.hp=60 if serial%2==0 else 180;w.atk=20+3*depth;w.defense=10+2*depth;w.skill_armed=hero!="scholar";w.focus=2;w.tactic="reap";w.training_level=3;w.relic_bonus=2;w.gear="" if serial%2==0 else "lens";w.armed_item="ward" if serial%2==0 else "pierce";w.items={"ward":1,"pierce":1}
   w.last_kill_kind=w.tile(Gen.routes(w.seed,depth)[1].points[0])
   var before=w.save_data();var original_hp:int=w.hp;var old_kind:String=w.last_kill_kind
   check_route_rows(w.summary().routes,route_expect(w,false),"talent summary")
   var view:Dictionary=w.rune_view()
   check_route_rows(view.before_routes,route_expect(w,false),"talent rune before")
   check_route_rows(view.after_routes,route_expect(w,true),"talent rune after")
   var copied=w.clone()
   check(copied.talents==w.talents and copied.last_kill_kind==old_kind and copied.legacy_id=="none" and copied.focus==w.focus and copied.skill_armed==w.skill_armed,"clone build fields",{})
   check(w.save_data()==before and w.hp==original_hp and w.focus==2 and w.last_kill_kind==old_kind and w.skill_armed==(hero!="scholar") and w.items.ward==1 and w.items.pierce==1,"talent preview read-only",{})
func noncombat_checks():
 var World=load("res://scripts/endless_world_v21.gd")
 for legacy in ["none","kit","coin","mind"]:
  for hero in ["warden","ranger","scholar"]:
   var w=World.new_run(42);var absent=w.step(Vector2i.RIGHT)
   check(not absent.get("changed",false),"unselected cannot move",{})
   w.act("hero_"+hero)
   check(not w.step(Vector2i.RIGHT).get("changed",false),"hero alone cannot move",{})
   w.act("legacy_"+legacy)
   check(w.hp==(120 if legacy=="mind" else 150) and w.focus==({"none":2,"kit":1,"coin":1,"mind":3}[legacy]),"legacy actual initial tradeoff",{})
   check(w.items.ward==(1 if legacy=="kit" else 0) and w.items.pierce==(1 if legacy=="kit" else 0),"kit atomic tools",{})
   var restored=World.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
   check(restored!=null and restored.hero_id==hero and restored.legacy_id==legacy and restored.hp==w.hp and restored.focus==w.focus and restored.items==w.items,"two-prefix replay",{})
   var prior=w.save_data();check(not w.act("legacy_none").get("changed",false) and w.save_data()==prior,"legacy cannot change",{})
 for cards in [[],["mender"],["overload"],["mender","overload"],["reserve","mender","overload"]]:
  for health in [1,120,179,180]:
   for focus_value in [0,1,2,3,4]:
    var w=World.new_run(42);w.act("hero_scholar");w.act("legacy_none");w.talents.assign(cards);w.hp=health;w.focus=focus_value
    var cost:int=2 if "overload" in cards else 1;var heal:int=(42 if "overload" in cards else 24)+(4 if "mender" in cards else 0);var before=w.save_data();var allowed:bool=health<180 and focus_value>=cost
    check(w.hero_view().heal_actual==mini(heal,180-health),"scholar UI actual heal",{})
    var result:Dictionary=w.act("skill_use")
    check(result.get("changed",false)==allowed and w.hp==(mini(180,health+heal) if allowed else health) and w.focus==(focus_value-cost if allowed else focus_value),"scholar exact heal/cost",{"cards":cards,"hp":health,"focus":focus_value})
    if not allowed:check(w.save_data()==before,"rejected heal leaves history",{})
 # Controlled merchant adjacency, noncombat physiology only.
 for health in [1,128,129,179,180]:
  var w=World.new_run(42);w.act("hero_scholar");w.act("legacy_none");w.talents.assign(["mender"]);w.hp=health;w.gold=100;w.pos=Vector2i(2,1)
  var q:Dictionary=w.action_quote("buy_potion");var before=w.save_data();var r:Dictionary=w.act("buy_potion")
  check(q.heal_actual==mini(54,180-health) and w.hp==mini(180,health+54) and w.gold==(85 if health<180 else 100),"mender merchant exact54cap",{})
  if health==180:check(not r.get("changed",false) and w.save_data()==before,"full-health potion no purchase",{})
 # Controlled milestone positioning verifies cap4 correction over frozen v20 cap3.
 for focus_value in [2,3,4]:
  var w=World.new_run(42);w.act("hero_warden");w.act("legacy_none");w.talents.assign(["reserve"]);w.floor_number=3;w.max_floor=3;w.pos=Vector2i(12,13);w.focus=focus_value
  check(w.step(Vector2i.RIGHT).get("changed",false) and w.floor_number==4 and w.focus==mini(4,focus_value+1),"reserve cap4 milestone actual",{})
  var gained:int=w.focus
  w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT);w.step(Vector2i.LEFT);w.step(Vector2i.RIGHT)
  check(w.floor_number==4 and w.focus==gained,"milestone revisit no focus farming",{})
 # Controlled vault adjacency isolates one-use coin inheritance; this is not a
 # claim that the fixture paid the door key or earned its position.
 for initial_gold in [0,9999996]:
  var w=World.new_run(42);w.act("hero_ranger");w.act("legacy_coin");w.gold=initial_gold
  var gold_floors=[]
  for depth in range(1,13):
   w.floor_number=depth
   if w.vault_kind()=="gold":gold_floors.append(depth)
  w.floor_number=gold_floors[0];w.pos=Vector2i(11,3)
  var q:Dictionary=w.vault_quote();var old_gold:int=w.gold
  check(q.nominal==52 and q.actual==mini(52,w.MAX_STAT-old_gold),"first coin vault quote52",{})
  check(w.step(Vector2i.RIGHT).get("changed",false) and w.gold==old_gold+int(q.actual) and w.legacy_coin_used,"first coin vault claim marks use",{})
  w.floor_number=gold_floors[1];w.pos=Vector2i(11,3)
  check(w.vault_quote().nominal==40,"next coin vault baseline40",{})
 # Cached offers are copied, stable across unrelated state and delayed choices.
 for seed_value in range(128):
  var w=World.new_run(seed_value);w.act("hero_warden");w.act("legacy_none");var offers:Array=w.talent_draft();var flatten=[]
  for group in offers:check(group.size()==3,"draft three entries",{});flatten.append_array(group)
  var unique={};for id in flatten:unique[id]=true
  check(unique.size()==9,"draft nine unique",{})
  var alien=w.talent_draft();alien[0][0]="injected"
  check(w.talent_draft()==offers,"draft view cannot mutate internal cache",{})
  w.kills=15;w.hp=60;w.gold=99
  check(w.talent_draft()==offers,"delay does not reroll",{})
  w.act("skill_use");var before=w.save_data()
  check(not w.act("tal_"+offers[0][0]).get("changed",false) and w.save_data()==before,"armed must cancel before draft",{})
  w.act("skill_cancel")
  for tier in range(3):
   var old_focus:int=w.focus
   check(w.act("tal_"+offers[tier][0]).get("changed",false),"delayed tiers selectable sequentially",{})
   check(w.talents.size()==tier+1 and w.focus==old_focus and w.talent_draft()==offers,"selection no refill/reroll",{})
  before=w.save_data()
  check(not w.act("tal_"+offers[0][0]).get("changed",false) and w.save_data()==before,"cannot take fourth",{})
func run():
 var World=load("res://scripts/endless_world_v21.gd")
 var combinations:Dictionary={}
 for seed_value in range(128):
  var w=World.new_run(seed_value);var offers:Array=w.talent_draft()
  for a in offers[0]:
   for b in offers[1]:
    for c in offers[2]:
     var ids:Array=[a,b,c];var sorted_ids=ids.duplicate();sorted_ids.sort();var key=",".join(sorted_ids)
     if not combinations.has(key):combinations[key]={"seed":seed_value,"ids":ids}
 var loadouts=[["",""],["cloak","ward"],["lens","pierce"],["cloak","pierce"],["lens","ward"],["","ward"],["","pierce"],["cloak",""]]
 for combo in combinations.values():
  for token in ["g","b","w","V","r","c","t","p"]:
   for rune in ["","shock","silence"]:
    for hero in ["warden","ranger","scholar"]:
     for phase in range(8):
      var loadout:Array=loadouts[phase]
      exercise({"seed":combo.seed,"talents":combo.ids,"last_kill":token if phase%2==0 else ("b" if token=="g" else "g"),"token":token,"rune":rune,"hero":hero,"armed":hero!="scholar" and phase%3!=0,"focus":2 if phase%2==0 else 3,"tactic":["brace","pierce","reap"][phase%3],"gear":loadout[0],"item":loadout[1],"level":phase%6,"atk":[12,13,15,46,20,25,11,35][phase],"defense":20-[0,1,7,12][phase%4],"enemy_hp":6 if phase==0 else 34,"enemy_atk":20,"enemy_def":12,"hp":[1,3,59,60,61,180,24,8][phase],"floor":50})
 # Single/zero-card states also occur before the third draft, including first-hit-only kills.
 for talents in [[],["tracker"],["laststand"],["alert"],["light"],["wardweave"],["deepdrill"],["mender"],["overload"],["reserve"]]:
  for hero in ["warden","ranger","scholar"]:
   for token in ["r","c","t","p","g"]:
    for rune in ["","shock","silence"]:
     for attack in [0,12,13,46]:
      for health in [1,2,60,61,180]:
       exercise({"seed":42,"talents":talents,"last_kill":token,"token":token,"rune":rune,"hero":hero,"armed":hero!="scholar","focus":2,"tactic":"reap","gear":"","item":"pierce" if token=="r" else "ward","level":0,"atk":attack,"defense":19,"enemy_hp":3 if attack==12 else 34,"enemy_atk":20,"enemy_def":12,"hp":health,"floor":100})
 route_checks(combinations)
 noncombat_checks()
 print("V21_ORACLE_RESULT "+JSON.stringify({"cases":cases,"checks":checks,"failures":failures,"samples":samples,"valid_draft_triples":combinations.size(),"controlled_battle_fixture":true,"note":"Independent event reference; full triples are obtainable from real seed offers but combat stats/ownership are controlled, not earned growth or balance evidence."}))
 quit(0 if failures.is_empty() else 1)
