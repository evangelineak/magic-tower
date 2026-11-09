extends RefCounted
# Independent small-step reference, not the production algebraic combat solver.
# Explicit controlled inputs. This does not generate legal player histories.
static func fight(token:String,player_hp:int,enemy_hp:int,hit:int,counter:int,brace:int,cloak:int,ward:int,reap:int)->Dictionary:
 var result={"valid":false,"survivable":false,"damage":0,"heal_after":0,"rounds":0,"regen":0,"thorns":0,"events":[]}
 if hit<=0:return result
 # Feasibility first: priest repeating enemy states means no victory is possible,
 # regardless of the player's finite HP. First-counter shields apply once only.
 var eh=enemy_hp;var first=true;var seen={}
 while eh>0:
  var key=str(eh)+":"+str(first)
  if seen.has(key):result.events.append("repeat_enemy_state");return result
  seen[key]=true
  eh-=hit
  if eh<=0:break
  var harm=counter
  if first:harm=maxi(0,harm-brace-cloak-ward)
  if token=="p" and harm>0:eh=mini(enemy_hp,eh+3)
  first=false
 result.valid=true;eh=enemy_hp;first=true;var hp=player_hp
 # The feasibility pass proves termination without HP death. This pass also stops
 # immediately when the real player dies, so it never invents later counterattacks.
 while hp>0 and eh>0:
  result.rounds+=1;eh-=hit;result.events.append(["hit",hit,maxi(0,eh)])
  if token=="t":
   hp-=2;result.damage+=2;result.thorns+=2;result.events.append(["thorns",2,maxi(0,hp)])
  if hp<=0:break
  if eh<=0:break
  var harm=counter
  if first:harm=maxi(0,harm-brace-cloak-ward)
  first=false;hp-=harm;result.damage+=harm;result.events.append(["counter",harm,maxi(0,hp)])
  if hp<=0:break
  if token=="p" and harm>0:
   var heal=mini(3,enemy_hp-eh);eh+=heal;result.regen+=heal;result.events.append(["regen",heal,eh])
 result.survivable=hp>0 and eh<=0
 if result.survivable:result.heal_after=mini(reap,result.damage)
 return result
