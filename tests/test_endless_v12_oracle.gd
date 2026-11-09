extends SceneTree
const Oracle=preload("res://tests/endless_v12_combat_oracle.gd")
class Fixture:
 extends "res://scripts/endless_world_v12.gd"
 var token:="t"
 var controlled_hit:=1
 var controlled_counter:=0
 func tile(_point:Vector2i)->String:return token
 func base_enemy(_token:String)->Dictionary:return {"hp":32 if token=="t" else 34,"atk":20,"def":0,"gold":22}
 func combat_attack()->int:return controlled_hit
 func combat_defense()->int:return 20-controlled_counter
var checks:=0
var failures=[]
var cases:=0
var samples=[]
func check(ok:bool,label:String,context:Dictionary):
 checks+=1
 if not ok and failures.size()<20:failures.append({"label":label,"context":context})
func _initialize():call_deferred("run")
func run():
 for token in ["t","p"]:
  for hit in range(0,41):
   for hp in [1,2,3,8,180]:
    for counter in [0,1,6]:
     for mode in ["none","brace","reap","cloak","cloakbrace","ward","all"]:
      var w=Fixture.new();w.token=token;w.controlled_hit=hit;w.controlled_counter=counter;w.hp=hp
      w.tactic="brace" if mode in ["brace","cloakbrace","all"] else ("reap" if mode=="reap" else "none")
      w.gear="cloak" if mode in ["cloak","cloakbrace","all"] else ""
      w.armed_item="ward" if mode in ["ward","all"] else "";w.items.ward=1
      var expected=Oracle.fight(token,hp,32 if token=="t" else 34,hit,counter,3+w.effective_level() if w.tactic=="brace" else 0,4 if w.gear=="cloak" else 0,6 if w.armed_item=="ward" else 0,2+w.effective_level() if w.tactic=="reap" else 0)
      var actual=w.preview(Vector2i.ZERO);cases+=1
      var ctx={"token":token,"hit":hit,"hp":hp,"counter":counter,"mode":mode,"expected":expected,"actual":actual}
      if (token=="t" and hit==32 and hp in [2,3] and counter==6 and mode in ["reap","all"]) or (token=="p" and hit in [3,4,34] and hp==180 and counter==1 and mode in ["none","brace"]):samples.append(ctx)
      for field in ["valid","survivable","damage","heal_after","rounds"]:check(actual[field]==expected[field],field,ctx)
      check(actual.reflection_damage==expected.thorns,"reflection actual events",ctx)
      check(actual.regen_total==expected.regen,"healing actual events",ctx)
      var before=w.save_data();var outcome=w.step(Vector2i.RIGHT,true)
      if not expected.valid:
       check(not outcome.get("changed",false) and w.save_data()==before and w.items.ward==1,"unwinnable refusal consumes nothing",ctx)
      else:
       check(outcome.get("changed",false),"valid confirmed combat occurs",ctx)
       check(w.hp==maxi(0,hp-int(expected.damage))+int(expected.heal_after),"actual HP matches event oracle",ctx)
       check(w.ended==not expected.survivable,"actual death matches event oracle",ctx)
       check(w.kills==(1 if expected.survivable else 0) and w.gold==(22 if expected.survivable else 0),"only surviving victory awards kill and gold",ctx)
       check(w.items.ward==(0 if w.armed_item=="ward" or mode in ["ward","all"] else 1),"real fight consumes equipped ward once",ctx)
 print("ORACLE_RESULT "+JSON.stringify({"samples":samples,"cases":cases,"checks":checks,"failures":failures,"controlled_fixture":true,"note":"Independent small-step reference, not legal player progression; production preview only used as actual value"}))
 quit(0 if failures.is_empty() else 1)
