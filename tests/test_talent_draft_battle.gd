extends SceneTree
const P=preload("res://scripts/progression.gd")
const T=preload("res://scripts/battle_timeline.gd")
const W=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func battle(raw:int,hp:int=500,armed:bool=false,third:String="",strategy:String="none"):
 var talents:Array=["tactical_review","adversity_charge"]
 if third!="":talents.append(third)
 return P.battle(10,0,hp,{"hp":20,"atk":raw,"def":0,"kind":"s"},"warden",armed,"balanced",talents,"none",false,"none",strategy,"")
func _init():
 var combinations={};var omissions=[{},{}]
 for seed in range(200):
  var draft=P.talent_draft(seed)
  check(P.valid_talent_draft(seed,draft) and P.valid_talent_draft(seed,JSON.parse_string(JSON.stringify(draft))) and draft==P.talent_draft(seed),"fixed independent candidates reproduce")
  check(draft.offers[2]==P.TALENT_TIERS[2].choices,"third tier keeps original pool")
  var first=draft.offers[0].duplicate();first.sort()
  var second=draft.offers[1].duplicate();second.sort()
  combinations[str(first)+str(second)]=true
  for tier in range(2):
   for id in P.TALENT_POOLS[tier]:
    if id not in draft.offers[tier]:omissions[tier][id]=true
 check(omissions[0].size()==4 and omissions[1].size()==4,"all four real omissions appear, not merely order changes")
 check(combinations.size()>=12,"two tiers have genuine changing candidate sets")
 for seed in [0,42,2147483647]:
  check(P.valid_talent_draft(seed,P.talent_draft(seed,0)),"legacy fixed pools independent of seed")
  for bad in [null,true,{}, {"version":true,"offers":[]},{"version":1,"offers":true},{"version":1,"offers":[[],[],[]]}]:
   check(not P.valid_talent_draft(seed,bad),"malformed draft rejects without script exception")
 var enemy=W.ENEMIES.s.duplicate();enemy.kind="s"
 var none=P.battle(18,8,500,enemy,"warden",false,"balanced",["tactical_review"])
 var same=P.battle(18,8,500,enemy,"warden",false,"balanced",["tactical_review"],"none",false,"none","none","s")
 var other=P.battle(18,8,500,enemy,"warden",false,"balanced",["tactical_review"],"none",false,"none","none","g")
 check(not none.review_active and same.review_active and not other.review_active and same.effective_def==none.effective_def+4 and same.damage<none.damage,"review rewards exact prior surviving kind only")
 for raw in [39,40,41]:
  var b=battle(raw)
  check(b.damage==raw and b.focus_after==(1 if raw>=40 else 0),"adversity threshold is actual net HP loss")
 check(battle(40,500,true).damage==26 and battle(40,500,true).focus_after==0,"Brace can reduce damage below refund threshold")
 check(battle(61,500,true).damage==40 and battle(61,500,true).focus_after==1,"Brace floor boundary at exact40 refunds")
 check(battle(59,500,false,"unbroken").damage==39 and battle(59,500,false,"unbroken").focus_after==0,"Unbroken applies before adversity threshold")
 check(battle(60,500,false,"unbroken").damage==40 and battle(60,500,false,"unbroken").focus_after==1,"Unbroken exact40 refunds")
 check(battle(40,40).survivable==false and battle(40,40).focus_after==0,"death never receives would-be refund")
 var stack=P.battle(90,0,500,{"hp":180,"atk":40,"def":0,"kind":"H"},"warden",false,"balanced",["tactical_review","adversity_charge"],"none",false,"none","channel","")
 check(stack.focus_after==2,"channel and adversity can add before World capacity clamp")
 var cases:=0
 for token in W.ENEMIES:
  enemy=W.ENEMIES[token].duplicate();enemy.kind=token
  for prior in ["",token,"not_this_kind"]:
   for gear in P.GEAR:
    for armed in [false,true]:
     for hp in [39,40,41,199,5000]:
      for strategy in ["none","channel","forager","study"]:
       var talents:Array=["tactical_review","adversity_charge","unbroken"]
       var b=P.battle(73,24,hp,enemy,"warden",armed,gear,talents,"none",false,"none",strategy,prior)
       var t=T.simulate(73,24,hp,enemy,"warden",armed,gear,talents,"none",false,"none",strategy,prior)
       check(b.valid==t.valid,"new talent timeline validity equals forecast")
       if b.valid:
        check(t.fatal==not b.survivable and t.damage==(b.damage if b.survivable else hp) and t.focus_after==(b.focus_after if b.survivable else 0) and t.heal_after==(b.heal_after if b.survivable else 0),"new talent prefix damage and conditional rewards agree")
       cases+=1
 print("TALENT DRAFT BATTLE: %d checks, failures=%d; %d combinations"%[checks,failures,cases])
 quit(1 if failures else 0)
