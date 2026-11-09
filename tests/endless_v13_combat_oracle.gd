extends RefCounted
# Independent finite-state / small-step reference for v13. Never calls production preview.
static func fight(token:String,player_hp:int,enemy_hp:int,hit:int,counter:int,brace:int,cloak:int,ward:int,reap:int,inscription:String)->Dictionary:
 var r={"valid":false,"survivable":false,"damage":0,"heal_after":0,"rounds":0,"regen":0,"thorns":0,"opening":0,"events":[]}
 if hit<=0:return r
 var shock:bool=inscription=="shock";var silence:bool=inscription=="silence"
 var eh=enemy_hp;var first=true;var seen={}
 # Refuse truly unfinishable priest loops independently of the player's finite HP.
 while eh>0:
  var key=str(eh)+":"+str(first)
  if seen.has(key):r.events.append("repeat_enemy_state");return r
  seen[key]=true;eh-=hit*(2 if first and shock else 1)
  if eh<=0:break
  var harm=counter*(2 if first and token=="c" else 1)*(2 if first and shock and token!="r" else 1)
  if first:harm=maxi(0,harm-brace-cloak-ward)
  if token=="p" and not silence and harm>0:eh=mini(enemy_hp,eh+3)
  first=false
 r.valid=true;eh=enemy_hp;first=true;var hp=player_hp
 if token=="r":
  var opening=counter*(2 if shock else 1);hp-=opening;r.damage+=opening;r.opening=opening;r.events.append(["opening",opening,maxi(0,hp)])
 while hp>0 and eh>0:
  var dealt_hit=hit*(2 if first and shock else 1)
  r.rounds+=1;eh-=dealt_hit;r.events.append(["hit",dealt_hit,maxi(0,eh)])
  if token=="t":
   var reflect=4 if first and shock else 2
   hp-=reflect;r.damage+=reflect;r.thorns+=reflect;r.events.append(["thorns",reflect,maxi(0,hp)])
  if hp<=0 or eh<=0:break
  var harm=counter*(2 if first and token=="c" else 1)*(2 if first and shock and token!="r" else 1)
  if first:harm=maxi(0,harm-brace-cloak-ward)
  first=false;hp-=harm;r.damage+=harm;r.events.append(["counter",harm,maxi(0,hp)])
  if hp<=0:break
  if token=="p" and not silence and harm>0:
   var healing=mini(3,enemy_hp-eh);eh+=healing;r.regen+=healing;r.events.append(["regen",healing,eh])
 r.survivable=hp>0 and eh<=0
 if r.survivable and not silence:r.heal_after=mini(reap,r.damage)
 return r
