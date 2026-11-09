extends SceneTree
const P=preload("res://scripts/progression.gd")
const T=preload("res://scripts/battle_timeline.gd")
const W=preload("res://scripts/world.gd")
const L=preload("res://scripts/legacy_points.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _init():
 for capacity in range(4):
  for study in range(3):
   for reserve in range(3):
    check(L.valid_allocation(capacity,{"study":study,"reserve":reserve})==(study+reserve<=capacity),"allocation sum respects finite capacity")
 for bad in [{"study":true,"reserve":0},{"study":-1,"reserve":0},{"study":1.5,"reserve":0},{"study":INF,"reserve":0},{"study":2,"reserve":2},{"study":1},{"study":0,"reserve":0,"extra":0}]:
  check(not L.valid_allocation(3,bad),"invalid allocation rejects without coercion")
 var charge:Array=["tactical_review","adversity_charge"]
 var trained:Array=["tactical_review","trained_focus"]
 check(P.skill_level(charge,"focus_deep","study",2)==20 and P.mend_heal(charge,"focus_deep","study",2)==130,"legal adversity+study+gear+two legacy points reaches20 and Mend130")
 check(P.skill_level(charge,"focus_deep","channel",2)==16 and P.mend_heal(charge,"focus_deep","channel",2)==110,"legal channel+adversity variant reaches16 not20")
 var info=P.skill_level_info(trained,"focus_deep","study",2)
 check(info.raw==24 and info.effective==20 and info.overflow==4 and info.legacy==4,"training+gear+study+legacy exposes four wasted levels, not silent power beyond cap")
 var enemy={"hp":20,"atk":20,"def":0,"kind":"s"}
 var b=P.battle(14,3,500,enemy,"scholar",false,"balanced",charge,"none",false,"focus_deep","study","",2)
 check(b.valid and b.survivable and b.damage==40 and b.focus_after==1,"legal scholar adversity gets one finite refund after surviving qualifying damage")
 # A separate exact40 example makes the net-healing economy explicit.
 var net_study=P.mend_heal(charge,"focus_deep","study",2)*int(b.focus_after)-int(b.damage)
 var elite=P.battle(91,3,500,{"hp":180,"atk":40,"def":0,"kind":"H"},"scholar",false,"balanced",charge,"none",false,"focus_deep","channel","",2)
 check(elite.valid and elite.survivable and elite.damage==40 and elite.focus_after==2,"legal elite channel+adversity produces two bounded focus at exact40 damage")
 var net_channel=P.mend_heal(charge,"focus_deep","channel",2)*int(elite.focus_after)-int(elite.damage)
 check(net_study==90 and net_channel==180,"documented possible net healing per qualifying kill, not an infinite loop")
 var cases:=0
 for token in W.ENEMIES:
  enemy=W.ENEMIES[token].duplicate();enemy.kind=token
  for study in range(3):
   for strategy in ["none","study","channel"]:
    for gear in P.GEAR:
     for hero in P.HEROES:
      for armed in [false,true]:
       for hp in [39,199,5000]:
        b=P.battle(73,24,hp,enemy,hero,armed,gear,charge,"none",false,"focus_deep",strategy,token,study)
        var timeline=T.simulate(73,24,hp,enemy,hero,armed,gear,charge,"none",false,"focus_deep",strategy,token,study)
        check(b.valid==timeline.valid,"legacy levels keep forecast/timeline validity identical")
        if b.valid:check(timeline.damage==(b.damage if b.survivable else hp) and timeline.fatal==not b.survivable and timeline.focus_after==(b.focus_after if b.survivable else 0) and timeline.heal_after==(b.heal_after if b.survivable else 0),"legacy level effects apply once to actual damage and surviving rewards")
        cases+=1
 print("LEGACY POINTS BATTLE: %d checks, failures=%d; %d combinations; legal max net40HP kill recovery study=90/channel=180"%[checks,failures,cases])
 quit(1 if failures else 0)
