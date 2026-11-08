class_name TowerBattleTimeline
extends RefCounted
const P=preload("res://scripts/progression.gd")
const LIMIT=8192
# Contact thorns happen before the corresponding hero hit. A lethal contact
# stops that hit; this is explicit risk-mode ordering, not an old death rule.
static func simulate(attack:int,defense:int,hp:int,enemy:Dictionary,hero:String,skill:bool,equipment:String,talents:Array,oath:String="none",flank:bool=false,attunement:String="none",strategy:String="none")->Dictionary:
 var invalid={"valid":false,"reason":"Invalid timeline input.","events":[]}
 for value in [attack,defense,hp]:
  if value<0 or value>10000000:return invalid
 for key in ["hp","atk","def","thorns"]:
  var value=enemy.get(key,0)
  if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>10000000:return invalid
 var forecast=P.battle(attack,defense,hp,enemy,hero,skill,equipment,talents,oath,flank,attunement,strategy)
 if not forecast.valid:return invalid
 var r=forecast.duplicate(true)
 r.forecast=forecast.duplicate(true);r.events=[];r.start_hp=hp;r.remaining_hp=hp;r.enemy_hp=int(enemy.hp)
 r.fatal=false;r.fatal_index=-1;r.fatal_round=-1;r.hero_hits=0;r.counter_count=0
 r._raw=0;r._net=0;r._rate=P.brace_percent(talents,attunement,strategy) if skill and hero=="warden" else 0
 r._barrier=20 if "unbroken" in talents and hp>=400 else 0
 r._shield=equipment=="buckler";r._limit=false
 for key in ["damage","normal_damage","first_strike_damage","thorns_damage","blocked_damage","feint_damage","charged_damage","equipment_blocked","oath_blocked","flank_blocked","retaliations","rounds","heal_after"]:r[key]=0
 r.skill_consumed=skill and hero in ["warden","ranger"]
 var incoming=maxi(0,int(enemy.atk)-int(forecast.effective_def))
 if enemy.get("first_strike",false):
  var suppressed=bool(forecast.first_strike_suppressed)
  r.first_strike_damage+=incoming
  if suppressed:
   if flank:r.flank_blocked+=incoming
   else:r.oath_blocked+=incoming
  _hurt(r,"first_strike",0 if suppressed else incoming,0,not suppressed)
 if not _stopped(r) and equipment=="duelist":_counter(r,incoming,enemy,"feint",0)
 for turn in range(1,mini(int(forecast.rounds),LIMIT)+1):
  if _stopped(r):break
  var thorn=int(enemy.get("thorns",0))
  if thorn>0:
   r.thorns_damage+=thorn
   var paid=floori(float(thorn)/2.0) if oath=="watch" else thorn
   r.oath_blocked+=thorn-paid
   _hurt(r,"thorns",paid,turn,false)
  if _stopped(r):break
  if not _room(r):break
  r.hero_hits+=1;r.enemy_hp=maxi(0,int(r.enemy_hp)-int(forecast.hit))
  r.events.append({"kind":"hero_hit","round":turn,"damage":int(forecast.hit),"loss":0,"hp":r.remaining_hp,"enemy_hp":r.enemy_hp})
  if r.enemy_hp==0:break
  if equipment=="repeater" and turn<3:continue
  for unused in range(2 if equipment=="maul" else 1):
   if _stopped(r):break
   _counter(r,incoming,enemy,"counter",turn)
 if not r.fatal and r.enemy_hp>0:r._limit=true
 if r._limit:return {"valid":false,"reason":"TIMELINE_LIMIT","events":[]}
 r.rounds=r.hero_hits;r.retaliations=r.counter_count
 r.overkill=maxi(0,int(r._net)-hp)
 r.damage=hp-int(r.remaining_hp);r.survivable=not r.fatal and r.enemy_hp==0
 r.heal_after=int(forecast.heal_after) if r.survivable else 0
 r.focus_after=int(forecast.get("focus_after",0)) if r.survivable else 0
 r.gold_after=int(forecast.get("gold_after",0)) if r.survivable else 0
 r.gold_tax=int(forecast.get("gold_tax",0)) if r.survivable else 0
 r.blocked_damage=int(r.normal_damage)+int(r.feint_damage)+int(r.charged_damage)+int(r.first_strike_damage)+int(r.thorns_damage)-int(r._net)
 r.reason="Victory possible." if r.survivable else "Defeated. Contact thorns resolve before the hero hit."
 for key in ["_raw","_net","_rate","_barrier","_shield","_limit"]:r.erase(key)
 return r
static func _room(r:Dictionary)->bool:
 if r.events.size()>=LIMIT:r._limit=true;return false
 return true
static func _stopped(r:Dictionary)->bool:return r.fatal or r._limit
static func _hurt(r:Dictionary,kind:String,amount:int,turn:int,shieldable:bool):
 if not _room(r):return
 var paid=amount
 if shieldable and r._shield:
  r._shield=false;r.equipment_blocked+=amount;paid=0
 r._raw+=paid
 var next=maxi(0,int(r._raw)-floori(float(int(r._raw)*int(r._rate))/100.0)-int(r._barrier))
 var delta=next-int(r._net);r._net=next
 var loss=mini(int(r.remaining_hp),delta)
 r.remaining_hp-=loss
 r.events.append({"kind":kind,"round":turn,"damage":delta,"loss":loss,"hp":r.remaining_hp,"enemy_hp":r.enemy_hp})
 if r.remaining_hp==0:
  r.fatal=true;r.fatal_index=r.events.size()-1;r.fatal_round=turn
static func _counter(r:Dictionary,incoming:int,enemy:Dictionary,kind:String,turn:int):
 r.counter_count+=1
 if kind=="feint":r.feint_damage+=incoming
 else:r.normal_damage+=incoming
 _hurt(r,kind,incoming,turn,true)
 if not _stopped(r) and enemy.get("heavy_every",0)==3 and int(r.counter_count)%3==0:
  r.charged_damage+=incoming
  _hurt(r,"charged",incoming,turn,false)
