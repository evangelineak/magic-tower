extends SceneTree
const Oracle=preload("res://tests/endless_v20_combat_oracle.gd")
class Fixture:
 extends "res://scripts/endless_world_v20.gd"
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
 var w=Fixture.new();w.seed=42;w.floor_number=int(p.floor);w.max_floor=int(p.floor);w.fixture_token=p.token;w.inscription=p.rune
 w.stats={"hp":p.enemy_hp,"atk":p.enemy_atk,"def":p.enemy_def,"gold":7}
 w.hp=int(p.hp);w.atk=int(p.atk);w.defense=int(p.defense);w.hero_id=p.hero;w.focus=2;w.skill_armed=p.armed
 w.tactic=p.tactic;w.training_level=int(p.level);w.relic_bonus=0;w.gear=p.gear;w.armed_item=p.item;w.items={"ward":1,"pierce":1}
 var expected=Oracle.fight(p);var actual=w.preview(w.pos+Vector2i.RIGHT);cases+=1
 var ctx={"input":p,"expected":expected,"actual":actual}
 for key in ["valid","survivable","damage","heal_after","rounds"]:check(actual.get(key)==expected[key],key,ctx)
 check(actual.get("opening_damage",0)==expected.opening,"opening",ctx)
 check(actual.get("reflection_damage",0)==expected.thorns,"reflection",ctx)
 check(actual.get("regen_total",0)==expected.regen,"regeneration",ctx)
 var before=w.save_data();var prior=w.hp
 var result=w.step(Vector2i.RIGHT,true)
 if not expected.valid:
  check(not result.get("changed",false) and w.save_data()==before and w.hp==prior and w.focus==2 and w.skill_armed==p.armed,"invalid refusal atomic",ctx)
 else:
  check(result.get("changed",false),"legal combat executes",ctx)
  check(w.hp==maxi(0,prior-int(expected.damage))+int(expected.heal_after),"actual HP",ctx)
  check(w.ended==not expected.survivable,"actual terminal state",ctx)
  check(w.kills==(1 if expected.survivable else 0) and w.gold==(7 if expected.survivable else 0),"only survival rewards",ctx)
  check(w.focus==(1 if p.armed else 2) and not w.skill_armed,"skill spent once in real combat",ctx)
  check(int(w.items.ward)==(0 if p.item=="ward" else 1) and int(w.items.pierce)==(0 if p.item=="pierce" else 1),"item consumption",ctx)
 if samples.size()<12 and p.token in ["r","t","p"] and p.rune=="shock" and p.hero=="warden" and p.hp==3 and p.atk==13:samples.append({"input":p,"expected":expected})
func route_expect(w,active_rune:bool)->Array:
 var Gen=load("res://scripts/endless_generation_v19.gd")
 var rows:Array=[]
 for route in Gen.routes(w.seed,w.floor_number):
  var points:Array=route.points.duplicate()
  if w.floor_number%2==0:points.reverse()
  var health:int=w.hp;var armed:bool=w.skill_armed;var item:String=w.armed_item
  var damage:=0;var healed:=0;var valid:=true;var alive:=true;var remaining:=0
  var kind:String=load("res://scripts/endless_generation_v13.gd").rune_info(w.seed,w.floor_number).kind if active_rune else ""
  for point in points:
   var token:String=w.tile(point)
   if token not in w.enemy_tokens():continue
   remaining+=1
   var foe:Dictionary=w.base_enemy(token)
   var p={"token":token,"rune":kind,"hero":w.hero_id,"armed":armed,"tactic":w.tactic,"gear":w.gear,"item":item,"level":w.effective_level(),"atk":w.atk,"defense":w.defense,"enemy_hp":foe.hp,"enemy_atk":foe.atk,"enemy_def":foe.def,"hp":health}
   var result=Oracle.fight(p);valid=valid and result.valid
   if not alive:continue
   damage+=int(result.damage)
   if not result.survivable:alive=false;continue
   healed+=int(result.heal_after);health=health-int(result.damage)+int(result.heal_after);armed=false;item=""
  rows.append({"damage":damage,"net_damage":damage-healed,"heal_after":healed,"valid":valid,"survivable":alive,"remaining":remaining})
 return rows
func check_route_rows(actual:Array,expected:Array,label:String):
 check(actual.size()==expected.size(),label+" count",{})
 for i in mini(actual.size(),expected.size()):
  for key in expected[i]:check(actual[i][key]==expected[i][key],label+" "+key,{"actual":actual,"expected":expected})
func route_checks():
 var World=load("res://scripts/endless_world_v20.gd")
 for seed_value in [0,1,42,117]:
  for depth in [1,3,4,9,12,50,100]:
   for hero in ["warden","ranger","scholar"]:
    var w=World.new_run(seed_value);w.act("hero_"+hero)
    # Controlled progression state: explicitly not a legal history.
    w.floor_number=depth;w.max_floor=depth;w.hp=180;w.atk=20+3*depth;w.defense=10+2*depth;w.skill_armed=hero!="scholar";w.focus=2;w.tactic="brace";w.training_level=3;w.relic_bonus=2;w.gear="lens";w.armed_item="ward";w.items.ward=1
    var before=w.save_data();var original_hp:int=w.hp
    check_route_rows(w.summary().routes,route_expect(w,false),"unactivated summary")
    var view:Dictionary=w.rune_view()
    check_route_rows(view.before_routes,route_expect(w,false),"rune before")
    check_route_rows(view.after_routes,route_expect(w,true),"rune after")
    var copy=w.clone()
    check(copy.hero_id==w.hero_id and copy.focus==w.focus and copy.skill_armed==w.skill_armed,"clone hero state",{})
    check(w.save_data()==before and w.hp==original_hp and w.focus==2 and w.skill_armed==(hero!="scholar") and w.items.ward==1,"read-only preview keeps resources",{})
func legal_replay_checks():
 var World=load("res://scripts/endless_world_v20.gd")
 var Router=load("res://scripts/endless_world.gd")
 var Gen=load("res://scripts/endless_generation_v19.gd")
 for seed_value in [0,42,117]:
  for hero in ["warden","ranger","scholar"]:
   var w=World.new_run(seed_value)
   var result:Dictionary=w.act("hero_"+hero)
   check(result.get("changed",false),"legal hero selected",{})
   if hero!="scholar":
    w.act("skill_use");w.act("skill_cancel");w.act("skill_use")
   else:w.act("skill_use")
   w.step(Vector2i.RIGHT);w.act("cargo_use")
   var goal:Vector2i=Gen.routes(seed_value,1)[0].points[0]
   var queue=[w.pos];var parents={w.pos:w.pos};var head:=0
   while head<queue.size() and not parents.has(goal):
    var at:Vector2i=queue[head];head+=1
    for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     var next:Vector2i=at+direction;var token:String=w.tile(next)
     if parents.has(next) or (next!=goal and token not in [".","k","h","a"]):continue
     parents[next]=at;queue.append(next)
   check(parents.has(goal),"legal route to first mandatory guard",{"seed":seed_value,"hero":hero})
   if not parents.has(goal):continue
   var path:Array=[];var cursor:Vector2i=goal
   while cursor!=w.pos:path.push_front(cursor);cursor=parents[cursor]
   for point in path:
    var moved:Dictionary=w.step(point-w.pos)
    check(moved.get("changed",false) and not moved.get("confirm",false),"real first-floor step",{"seed":seed_value,"hero":hero})
    var saved=w.save_data();var restored=Router.from_data(JSON.parse_string(JSON.stringify(saved)));var copied=w.clone()
    check(restored!=null,"legal prefix replay",{})
    if restored==null:continue
    for key in ["hp","atk","defense","focus","hero_id","skill_armed","kills","gold","pos","floor_number","items","deltas"]:
     check(restored.get(key)==w.get(key) and copied.get(key)==w.get(key),"legal replay/clone "+key,{"seed":seed_value,"hero":hero})
   check(w.kills==1 and not w.ended,"earned first guard victory",{"seed":seed_value,"hero":hero})
 # Frozen old rules must stay old even after the current router changes.
 for version in range(1,20):
  var old=Router.new_run(42,version);old.step(Vector2i.RIGHT)
  var saved:Dictionary=old.save_data();var restored=Router.from_data(JSON.parse_string(JSON.stringify(saved)))
  check(restored!=null and restored.rule_version()==version and restored.save_data()==saved,"frozen old version replay",{"version":version})
func run():
 var loadouts=[["",""],["cloak","ward"],["lens","pierce"],["cloak","pierce"],["lens","ward"],["","ward"]]
 for token in ["g","b","w","V","r","c","t","p"]:
  for rune in ["","shock","silence"]:
   for hero in ["warden","ranger","scholar"]:
    for tactic in ["brace","pierce","reap"]:
     for loadout in loadouts:
      for attack in [0,12,13,15,46]:
       for health in [1,3,180]:
        for counter in [0,1,7]:
         exercise({"token":token,"rune":rune,"hero":hero,"armed":hero!="scholar","tactic":tactic,"gear":loadout[0],"item":loadout[1],"level":2,"atk":attack,"defense":20-counter,"enemy_hp":34,"enemy_atk":20,"enemy_def":12,"hp":health,"floor":50})
 # Explicit fixed-scale high-floor fixtures: not purported legal journeys.
 for depth in [1,50,100]:
  for hero in ["warden","ranger","scholar"]:
   for armed in [false,true]:
    if hero=="scholar" and armed:continue
    for token in ["r","c","t","p"]:
     for rune in ["","shock","silence"]:
      for health in [1,2,4,8,32,180]:
       exercise({"token":token,"rune":rune,"hero":hero,"armed":armed,"tactic":"brace","gear":"cloak","item":"ward","level":5,"atk":20+3*depth,"defense":10+2*depth,"enemy_hp":34,"enemy_atk":24+2*depth,"enemy_def":12+3*depth,"hp":health,"floor":depth})
 route_checks()
 legal_replay_checks()
 print("V20_ORACLE_RESULT "+JSON.stringify({"cases":cases,"checks":checks,"failures":failures,"samples":samples,"controlled_battle_fixture":true,"route_fixture_worlds":84,"legal_first_floor_runs":9,"frozen_version_replays":19,"note":"59400 independent state-cycle/event combat fixtures plus 84 controlled route states, not legal growth/balance evidence; separately 9 legal first-floor journeys and 19 frozen-version replays. Production preview is actual only."}))
 quit(0 if failures.is_empty() else 1)
