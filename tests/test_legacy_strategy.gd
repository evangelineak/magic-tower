extends SceneTree
const S=preload("res://scripts/legacy_strategy.gd")
const P=preload("res://scripts/legacy_profile.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _init():
 check(S.pool_for_milestones([])==[],"no milestone no pool")
 for tier in range(1,4):check(S.pool_for_milestones([3,5,8].slice(0,tier))==S.IDS.slice(0,tier+3),"canonical milestone pool")
 for bad in [null,true,3,"3",[5],[8],[3,8],[3,3],[3,5,8,8],[3.5]]:check(not S.valid_milestones(bad),"reject malformed milestones")
 check(S.valid_milestones([3.0,5.0,8.0]),"JSON numeric milestones")
 for bad in [null,true,{},["study"],["study","forager","channel","study"],["forager","study","channel","reserve"],["study","forager","channel","fake"]]:
  check(not S.valid_pool(bad) and S.offers(1,bad).is_empty(),"invalid pool rejected")
 for bad in [null,true,"3",-1,1.5,2147483648,INF,NAN]:check(S.offers(bad,S.IDS).is_empty() and not S.valid_offers(bad,S.IDS,[]),"bad seed rejected")
 check(S.offers(42.0,S.IDS)==S.offers(42,S.IDS),"JSON integer seed")
 for count in [4,5,6]:
  var pool=S.IDS.slice(0,count);var combinations={};var original=pool.duplicate()
  for seed_value in range(2048):
   var offered=S.offers(seed_value,pool)
   check(offered.size()==3 and S.valid_offers(seed_value,pool,offered),"deterministic exact offer count")
   check(offered==S.offers(seed_value,pool) and pool==original,"stable and input immutable")
   var sorted=offered.duplicate();sorted.sort();combinations[JSON.stringify(sorted)]=true
   for id in offered:check(id in pool,"no locked option offered")
   var d=S.draft(seed_value,pool)
   check(S.valid_draft(seed_value,d) and d.choice=="","new draft pending")
   d.choice=offered[0];check(S.valid_draft(seed_value,d),"offered choice valid")
   d.choice="none";check(S.valid_draft(seed_value,d),"original always valid")
  check(combinations.size()>=count,"seeds yield genuinely varied combinations")
 seed(321);var first=randi();var second=randi();seed(321)
 check(randi()==first,"RNG reference")
 S.offers(2,S.IDS);S.draft(8,S.IDS)
 check(randi()==second,"no global RNG consumption")
 check(S.valid_draft(0,{"version":0,"pool":[],"offers":[],"choice":"none"}),"legacy remains original")
 check(S.draft(0,[]).choice=="none" and S.valid_draft(0,S.draft(0,[])),"empty auto-lock")
 var d=S.draft(7,S.IDS)
 for bad in [null,{},[],{"version":1,"pool":[],"offers":[],"choice":""}]:check(not S.valid_draft(7,bad),"strict malformed draft")
 var extra=d.duplicate(true);extra.extra=true;check(not S.valid_draft(7,extra),"unknown field rejected")
 var duplicate=d.duplicate(true);duplicate.offers[1]=duplicate.offers[0];check(not S.valid_draft(7,duplicate),"duplicate offers rejected")
 for id in ["", "unknown",true,null]:check(not S.valid_choice(d.offers,id),"choice is known or explicit original")
 var study=S.modifiers("study");check(study.atk==-4 and study.def==-2 and study.levels==4,"study tradeoff")
 check(S.modifiers("reserve",{"skill":false}).def==4 and S.modifiers("reserve",{"skill":true}).def==0,"reserve actual skill condition")
 for suppressed in [true,false]:
  check(S.modifiers("ambush_hunter",{"first_strike":true,"first_strike_suppressed":suppressed}).atk==(-2 if suppressed else 6),"suppressed ambush not rewarded")
 check(S.modifiers("ambush_hunter",{}).atk==-2,"ordinary enemy ambush penalty")
 check(S.modifiers("last_gambit",{"hp":199}).atk==6 and S.modifiers("last_gambit",{"hp":200}).atk==0,"strict HP boundary")
 check(S.modifiers("channel",{"enemy_hp":179}).focus_after==0 and S.modifiers("channel",{"enemy_hp":180}).focus_after==1,"raw enemy HP boundary")
 for id in S.IDS:
  check(S.modifiers(id).size()==6,"fixed modifier shape")
  check(S.kill_rewards(id,300,5,false,0,3)=={"heal":0,"focus":0,"gold":0,"gold_penalty":0},"no death rewards")
 for gold in range(21):
  var rewards=S.kill_rewards("forager",100,gold,true,0,3)
  check(rewards.heal==12 and rewards.gold_penalty==int(ceil(gold/4.0)) and rewards.gold==gold-rewards.gold_penalty,"ceil quarter monster tax")
 check(S.kill_rewards("channel",180,5,true,3,3).focus==0 and S.kill_rewards("channel",180,5,true,2,3).focus==1,"focus cap")
 check(S.kill_rewards("bad",100,3,true,0,3).is_empty() and S.modifiers("bad").is_empty(),"unknown ID not silently original")
 var profile=P.settle(P.fresh(),"strategy_test_00001",{"seed":0,"max_floor":5,"moves":42,"outcome":"withdrawn"}).profile
 check(S.pool_from_profile(profile)==S.IDS.slice(0,5),"real settled milestone pool")
 check(S.pool_from_profile({}).is_empty(),"corrupt profile has no derived options")
 print("LEGACY STRATEGY: %d checks, failures=%d"%[checks,failures])
 quit(1 if failures else 0)
