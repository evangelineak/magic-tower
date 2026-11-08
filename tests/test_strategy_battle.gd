extends SceneTree
const P=preload("res://scripts/progression.gd")
const T=preload("res://scripts/battle_timeline.gd")
const S=preload("res://scripts/legacy_strategy.gd")
const W=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _init():
 var trained:Array=["keen_edge","trained_focus","unbroken"]
 check(P.skill_level(trained,"focus_deep","study")==20 and P.skill_level_info(trained,"focus_deep","study").strategy==4,"20 requires real base+training+equipped tuning+study")
 check(P.skill_level(trained,"focus_deep")==16 and P.skill_level([],"none","study")==14,"none stays16 and study alone is14")
 check(P.brace_percent(trained,"focus_deep","study")==60 and P.mend_heal(trained,"focus_deep","study")==130,"skill effects really reach level20 formulas")
 var good={};var bad={};var combos:=0;var examples={}
 for strategy in S.IDS:
  good[strategy]=false;bad[strategy]=false
  for token in W.ENEMIES:
   for gear in P.GEAR:
    for hero in P.HEROES:
     for armed in [false,true]:
      for hp in [199,100000]:
       for stats in [[18,8],[73,24],[103,36]]:
        var base=P.battle(stats[0],stats[1],hp,W.ENEMIES[token],hero,armed,gear,[],"none",false,"none")
        var none=P.battle(stats[0],stats[1],hp,W.ENEMIES[token],hero,armed,gear,[],"none",false,"none","none")
        check(base==none,"explicit original strategy is identical to omitted default")
        var b=P.battle(stats[0],stats[1],hp,W.ENEMIES[token],hero,armed,gear,[],"none",false,"none",strategy)
        var t=T.simulate(stats[0],stats[1],hp,W.ENEMIES[token],hero,armed,gear,[],"none",false,"none",strategy)
        check(b.valid==t.valid,"strategy timeline validity matches preview")
        if b.valid:
         if b.survivable:
          check(t.survivable and t.damage==b.damage and t.rounds==b.rounds and t.heal_after==b.heal_after and t.focus_after==b.focus_after and t.gold_after==b.gold_after,"strategy victory actual event totals and rewards equal preview")
         else:
          check(t.fatal and t.damage==hp and t.heal_after==0 and t.focus_after==0 and t.gold_after==0,"strategy fatal prefix never receives victory rewards")
        var had_good=good[strategy];var had_bad=bad[strategy]
        if base.valid:
         if not b.valid or b.damage>base.damage:bad[strategy]=true
         if b.valid and b.survivable and b.damage<base.damage:good[strategy]=true
         if b.valid and b.survivable and base.survivable:
          if b.heal_after>base.heal_after or b.focus_after>base.focus_after:good[strategy]=true
          if b.gold_after<base.gold_after:bad[strategy]=true
        if good[strategy]!=had_good or bad[strategy]!=had_bad:
         var example={"enemy":token,"gear":gear,"hero":hero,"armed":armed,"hp":hp,"atk":stats[0],"def":stats[1],"base_loss":base.damage,"strategy_loss":b.damage,"heal":b.get("heal_after",0),"gold":b.get("gold_after",0),"focus":b.get("focus_after",0)}
         if good[strategy]!=had_good:examples[strategy+" better"]=example
         if bad[strategy]!=had_bad:examples[strategy+" worse"]=example
        combos+=1
  check(good[strategy] and bad[strategy],"each strategy has real favorable and costly matchups: "+strategy)
 # Uncancelled first strike is the precise condition, not merely an enemy tag.
 for oath in ["none","watch"]:
  for flank in [false,true]:
   var base=P.battle(73,24,1000,W.ENEMIES.H,"warden",false,"balanced",[],oath,flank)
   var hunter=P.battle(73,24,1000,W.ENEMIES.H,"warden",false,"balanced",[],oath,flank,"none","ambush_hunter")
   check(hunter.effective_atk==base.effective_atk+(6 if oath=="none" and not flank else -2) and hunter.effective_def==base.effective_def-2,"hunter cannot retain buff after flank/oath cancels ambush")
 var low=P.battle(73,24,199,W.ENEMIES.H,"warden",false,"balanced",[],"none",false,"none","last_gambit")
 var high=P.battle(73,24,200,W.ENEMIES.H,"warden",false,"balanced",[],"none",false,"none","last_gambit")
 check(low.effective_atk==79 and high.effective_atk==73,"gambit condition uses starting HP strict below200")
 for gold in [0,1,2,3,4,8,18,60,100,160]:
  var enemy={"hp":1,"atk":0,"def":0,"gold":gold}
  var b=P.battle(18,8,1,enemy,"warden",false,"balanced",[],"none",false,"none","forager")
  check(b.gold_after==gold-ceili(gold*0.25) and b.heal_after==12,"forager tax rounds upward only on monster gold")
 for bad_gold in ["10",true,-1,1.5,INF,NAN,1.0e100]:
  var enemy={"hp":1,"atk":0,"def":0,"gold":bad_gold}
  check(not P.battle(18,8,100,enemy,"warden",false,"balanced",[],"none",false,"none","forager").valid,"invalid monster gold is never silently coerced")
  check(not T.simulate(18,8,100,enemy,"warden",false,"balanced",[],"none",false,"none","forager").valid,"timeline shares gold validation")
 check(P.battle(18,8,100,{"hp":1,"atk":0,"def":0},"warden",false,"balanced",[]).gold_after==0,"missing gold remains valid zero reward")
 print("STRATEGY TRADEOFF EXAMPLES: ",JSON.stringify(examples))
 print("STRATEGY BATTLE: %d checks, failures=%d; %d combinations"%[checks,failures,combos])
 quit(1 if failures else 0)
