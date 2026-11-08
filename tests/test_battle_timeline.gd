extends SceneTree
const T=preload("res://scripts/battle_timeline.gd")
const P=preload("res://scripts/progression.gd")
const W=preload("res://scripts/world.gd")
const A=preload("res://scripts/attunement.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func trial(hp:int,enemy:Dictionary,gear:String="balanced",hero:String="warden",skill:bool=false,talents:Array=[],oath:String="none",flank:bool=false)->Dictionary:
 return T.simulate(10,0,hp,enemy,hero,skill,gear,talents,oath,flank)
func prefix(r):
 check(r.valid and r.events.size()<=T.LIMIT,"bounded valid timeline")
 var loss:=0
 for event in r.events:
  loss+=int(event.loss)
  check(int(event.hp)==int(r.start_hp)-loss and event.loss>=0 and event.hp>=0,"actual HP follows cumulative nonnegative prefix")
 check(loss==r.damage,"reported damage equals actual events")
 if r.fatal:
  check(r.remaining_hp==0 and r.fatal_index==r.events.size()-1 and r.damage==r.start_hp and r.enemy_hp>0 and r.heal_after==0,"fatal stops immediately without enemy kill or recovery")
func _init():
 var enemy={"hp":100,"atk":10,"def":0}
 var ambush=enemy.duplicate();ambush.first_strike=true
 var thorn=enemy.duplicate();thorn.thorns=1
 var heavy=enemy.duplicate();heavy.heavy_every=3
 var r=trial(1,ambush);prefix(r);check(r.fatal_round==0 and r.hero_hits==0 and r.events[-1].kind=="first_strike","fatal opening precedes all hero hits")
 r=trial(1,enemy,"duelist");prefix(r);check(r.hero_hits==0 and r.events[-1].kind=="feint","duelist dies to opening feint counter")
 r=trial(1,thorn);prefix(r);check(r.hero_hits==0 and r.enemy_hp==100 and r.events[-1].kind=="thorns","contact thorns kill before hero damage")
 r=trial(20,enemy,"maul");prefix(r);check(r.hero_hits==1 and r.counter_count==2 and r.fatal_round==1,"maul can die to second counter in same round")
 r=trial(35,heavy);prefix(r);check(r.counter_count==3 and r.events[-1].kind=="charged" and r.fatal_round==3,"third retaliation extra damage has actual fatal event")
 r=trial(1,enemy,"buckler");prefix(r);check(r.hero_hits==2 and r.equipment_blocked==4,"shield blocks first retaliation but not second")
 r=trial(1,enemy,"repeater");prefix(r);check(r.hero_hits==3 and r.counter_count==1,"repeater fires three times before first counter")
 r=T.simulate(30,0,1,ambush,"warden",false,"balanced",[],"none",true);prefix(r);check(r.hero_hits==1 and r.first_strike_suppressed,"flank suppresses opening only, not following retaliation")
 r=T.simulate(30,0,1,ambush,"warden",false,"balanced",[],"watch");prefix(r);check(r.hero_hits==1 and r.first_strike_suppressed,"oath suppresses opening")
 # Exact old aggregate equivalence across every current enemy, gear, hero,
 # armed state, oath, flanking and all six attunements, plus original.
 var cases:=0
 var tunings:Array=["none"];tunings.append_array(A.TEMPLATE_IDS)
 for token in W.ENEMIES:
  for gear in P.GEAR:
   for hero in P.HEROES:
    for skill in [false,true]:
     for oath in ["none","watch"]:
      for flank in [false,true]:
       for tuning in tunings:
        var talents:Array=["keen_edge","trained_focus","unbroken"] if cases%2==0 else ["clean_finish","sentinel_lore","battle_medic"]
        var hp:=100000
        var old=P.battle(103,36,hp,W.ENEMIES[token],hero,skill,gear,talents,oath,flank,tuning)
        var actual=T.simulate(103,36,hp,W.ENEMIES[token],hero,skill,gear,talents,oath,flank,tuning)
        check(actual.valid==old.valid,"timeline validity equals preview")
        if old.valid:
         check(actual.survivable and not actual.fatal and actual.damage==old.damage and actual.rounds==old.rounds and actual.retaliations==old.retaliations and actual.heal_after==old.heal_after and actual.skill_consumed==old.skill_consumed,"surviving timeline exactly equals existing total formula")
        cases+=1
 for hp in [1,2,3,17,199,200,399,400,401]:
  for gear in P.GEAR:
   var talents:Array=["iron_skin","last_stand","unbroken"]
   r=T.simulate(73,24,hp,W.ENEMIES.W,"warden",true,gear,talents)
   prefix(r)
   var old=P.battle(73,24,hp,W.ENEMIES.W,"warden",true,gear,talents)
   check(r.fatal==not old.survivable and (r.damage==old.damage if old.survivable else r.damage==hp),"Brace rounding and initial-HP Unbroken preserve fatal/safe boundary")
 r=T.simulate(1,0,10000000,{"hp":10000,"atk":0,"def":0,"thorns":1},"warden",false,"balanced",[])
 check(not r.valid and r.reason=="TIMELINE_LIMIT" and r.events.is_empty(),"overflow does not return a truncated fake death or huge events")
 r=T.simulate(1,0,10000000,{"hp":10000000,"atk":0,"def":0},"warden",false,"balanced",[])
 check(not r.valid and r.reason=="TIMELINE_LIMIT" and r.events.is_empty(),"ten-million-round input is bounded before iteration/allocation")
 check(not trial(10,{"hp":100,"atk":10,"def":50}).valid,"unbreakable armor is not a risk fight")
 check(not trial(10,{"hp":INF,"atk":10,"def":0}).valid,"unbounded numeric enemy rejected")
 print("BATTLE TIMELINE: %d checks, failures=%d; %d complete-equivalence combinations"%[checks,failures,cases])
 quit(1 if failures else 0)
