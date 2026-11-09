extends RefCounted
# Independent event-state reference. Does not call any production rule/simulator.
# Controlled fixtures, not evidence of reachable player growth or balance.
static func fight(p:Dictionary)->Dictionary:
 var out={"valid":false,"survivable":false,"damage":0,"heal_after":0,"rounds":0,"regen":0,"thorns":0,"opening":0,"hero_saved":0}
 var armor:int=maxi(0,int(p.enemy_def)-(6 if p.item=="pierce" else 0))
 armor=maxi(0,armor-(2+int(p.level) if p.tactic=="pierce" else 0))
 armor=maxi(0,armor-(8 if p.hero=="ranger" and p.armed else 0))
 var attack:int=maxi(0,int(p.atk)+(-2 if p.gear=="cloak" else (3 if p.gear=="lens" else 0)))
 var defense:int=maxi(0,int(p.defense)-(1 if p.gear=="cloak" else (3 if p.gear=="lens" else 0)))
 var hit:int=maxi(0,attack-armor);var counter:int=maxi(0,int(p.enemy_atk)-defense)
 if hit==0:return out
 var shock:bool=p.rune=="shock";var silent:bool=p.rune=="silence"
 var shield:bool=p.hero=="warden" and p.armed
 # Prove termination separately: reject cycles, not a guessed hit threshold.
 var enemy:int=p.enemy_hp;var turn:=0;var attacks:=1 if p.token=="r" else 0;var visited={}
 while enemy>0:
  var key="%d/%s/%d"%[enemy,turn==0,mini(2,attacks)]
  if visited.has(key):return out
  visited[key]=true
  enemy-=hit*(2 if shock and turn==0 else 1)
  if enemy<=0:break
  var raw=counter*(2 if turn==0 and p.token=="c" else 1)*(2 if shock and turn==0 and p.token!="r" else 1)
  var hurt:int=raw
  if turn==0:
   hurt=maxi(0,hurt-(3+int(p.level) if p.tactic=="brace" else 0))
   hurt=maxi(0,hurt-(4 if p.gear=="cloak" else 0))
   hurt=maxi(0,hurt-(6 if p.item=="ward" else 0))
  if shield and attacks<2:hurt-=int(hurt/2)
  attacks+=1
  if p.token=="p" and not silent and hurt>0:enemy=mini(int(p.enemy_hp),enemy+3)
  turn+=1
 out.valid=true;enemy=int(p.enemy_hp);turn=0;attacks=0
 var health:int=p.hp
 if p.token=="r":
  var raw:int=counter*(2 if shock else 1);var saving:int=int(raw/2) if shield else 0
  out.opening=raw-saving;out.hero_saved+=saving;out.damage+=out.opening;health-=out.opening;attacks=1
 while health>0 and enemy>0:
  enemy-=hit*(2 if shock and turn==0 else 1);out.rounds+=1
  if p.token=="t":
   var harm:int=4 if shock and turn==0 else 2
   health-=harm;out.damage+=harm;out.thorns+=harm
  if health<=0 or enemy<=0:break
  var harm:int=counter*(2 if turn==0 and p.token=="c" else 1)*(2 if shock and turn==0 and p.token!="r" else 1)
  if turn==0:
   harm=maxi(0,harm-(3+int(p.level) if p.tactic=="brace" else 0))
   harm=maxi(0,harm-(4 if p.gear=="cloak" else 0))
   harm=maxi(0,harm-(6 if p.item=="ward" else 0))
  var saving:int=int(harm/2) if shield and attacks<2 else 0
  harm-=saving;out.hero_saved+=saving;attacks+=1;health-=harm;out.damage+=harm
  if health<=0:break
  if p.token=="p" and not silent and harm>0:
   var healed:int=mini(3,int(p.enemy_hp)-enemy);enemy+=healed;out.regen+=healed
  turn+=1
 out.survivable=health>0 and enemy<=0
 if out.survivable and p.tactic=="reap" and not silent:out.heal_after=mini(2+int(p.level),int(out.damage))
 return out
