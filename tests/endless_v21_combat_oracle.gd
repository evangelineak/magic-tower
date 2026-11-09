extends RefCounted
# Independently authored finite-state reference for v21. No production combat calls.
# Inputs may be controlled fixtures; generated offers do not certify earned growth.
static func fight(p:Dictionary)->Dictionary:
 var t:Array=p.get("talents",[])
 var ward:bool=p.item=="ward";var drill:bool=p.item=="pierce"
 var weave:bool=ward and "wardweave" in t
 var deep:bool=drill and "deepdrill" in t
 var over:bool="overload" in t
 var cost:=2 if over else 1
 var active:bool=p.armed and int(p.get("focus",2))>=cost and p.hero in ["warden","ranger"]
 var shield:bool=active and p.hero=="warden"
 var alert:bool="alert" in t and not p.armed and int(p.get("focus",2))>=1
 var armor:int=maxi(0,int(p.enemy_def)-(6 if drill else 0)-(2 if deep else 0))
 armor=maxi(0,armor-(2+int(p.level) if p.tactic=="pierce" else 0))
 armor=maxi(0,armor-((14 if over else 8) if active and p.hero=="ranger" else 0))
 var attack:int=maxi(0,int(p.atk)+(-2 if p.gear=="cloak" else (3 if p.gear=="lens" else 0))-(1 if weave else 0))
 var defense:int=maxi(0,int(p.defense)-(1 if p.gear=="cloak" else (3 if p.gear=="lens" else 0)))
 var hit:int=maxi(0,attack-armor)
 var first_hit:int=hit+(3 if "tracker" in t and p.get("last_kill","")==p.token else 0)
 if "laststand" in t and int(p.hp)<=60:first_hit=int(first_hit*6/5)
 var shock:bool=p.rune=="shock";var silent:bool=p.rune=="silence"
 if shock:first_hit*=2
 var counter:int=maxi(0,int(p.enemy_atk)-defense)+(2 if deep else 0)
 var context={"token":p.token,"shock":shock,"shield":shield,"percent":75 if over else 50,"counter":counter,"brace":3+int(p.level) if p.tactic=="brace" else 0,"cloth":4 if p.gear=="cloak" else 0,"ward":6 if ward else 0,"light":3 if "light" in t and p.gear=="" else 0,"weave":3 if weave else 0,"alert":alert}
 var out={"valid":false,"survivable":false,"damage":0,"heal_after":0,"rounds":0,"regen":0,"thorns":0,"opening":0,"hero_saved":0,"first_hit":first_hit,"later_hit":hit,"cost":cost,"used":active}
 # Potential enemy cycles are checked independent of player HP. First-hit and
 # first/second active-attack phases are included, so temporary modifiers expire.
 var enemy:int=p.enemy_hp;var turn:=0;var attacks:=1 if p.token=="r" else 0;var visited={}
 while enemy>0:
  var key="%d/%s/%d"%[enemy,turn==0,mini(2,attacks)]
  if visited.has(key):return out
  visited[key]=true
  enemy-=first_hit if turn==0 else hit
  if enemy<=0:break
  var event=retaliation(context,turn==0,attacks,false)
  attacks+=1
  if p.token=="p" and not silent and event.hurt>0:enemy=mini(int(p.enemy_hp),enemy+3)
  turn+=1
 out.valid=true;enemy=int(p.enemy_hp);turn=0;attacks=0
 var health:int=p.hp
 if p.token=="r":
  var event=retaliation(context,false,attacks,true)
  out.opening=event.hurt;out.hero_saved+=event.saved;out.damage+=event.hurt;health-=event.hurt;attacks+=1
 while health>0 and enemy>0:
  enemy-=first_hit if turn==0 else hit;out.rounds+=1
  if p.token=="t":
   var harm:int=4 if shock and turn==0 else 2
   health-=harm;out.damage+=harm;out.thorns+=harm
  if health<=0 or enemy<=0:break
  var event=retaliation(context,turn==0,attacks,false)
  attacks+=1;health-=event.hurt;out.damage+=event.hurt;out.hero_saved+=event.saved
  if health<=0:break
  if p.token=="p" and not silent and event.hurt>0:
   var healed:int=mini(3,int(p.enemy_hp)-enemy);enemy+=healed;out.regen+=healed
  turn+=1
 out.survivable=health>0 and enemy<=0
 if out.survivable and p.tactic=="reap" and not silent:out.heal_after=mini(maxi(0,2+int(p.level)-(2 if "mender" in t else 0)),int(out.damage))
 return out
static func retaliation(c:Dictionary,first_counter:bool,number:int,opening:bool)->Dictionary:
 var hurt:int=c.counter
 if opening:
  if c.shock:hurt*=2
 else:
  if first_counter and c.token=="c":hurt*=2
  if first_counter and c.shock and c.token!="r":hurt*=2
  if first_counter:
   for key in ["brace","cloth","ward","light","weave"]:hurt=maxi(0,hurt-int(c[key]))
 if c.alert and number==0:hurt=maxi(0,hurt-2)
 var saved:int=int(hurt*int(c.percent)/100) if c.shield and number<2 else 0
 return {"hurt":hurt-saved,"saved":saved}
