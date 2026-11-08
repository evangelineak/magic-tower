class_name TowerLegacyStrategy
extends RefCounted
# Versioned horizontal options, not permanent character stats. Offers use explicit
# FNV-1a uint32 ranking, reproducible with JS Math.imul; never global RNG.
const Profile=preload("res://scripts/legacy_profile.gd")
const VERSION=1
const IDS=["study","forager","channel","reserve","ambush_hunter","last_gambit"]
const TEMPLATES={
 "study":{"name":"Dedicated study","description":"Skill level +4 / ATK -4 / DEF -2."},
 "forager":{"name":"Battlefield forager","description":"Surviving a kill heals 12 HP; monster gold loses 25%, rounded up."},
 "channel":{"name":"Deep channel","description":"DEF -3. Surviving a kill against original enemy HP 180 or more restores 1 focus, up to the cap."},
 "reserve":{"name":"Held reserve","description":"ATK -3. Unarmed-skill battles gain DEF +4; armed battles gain no defense."},
 "ambush_hunter":{"name":"Ambush hunter","description":"DEF -2. ATK +6 against an uncancelled enemy first strike, otherwise ATK -2."},
 "last_gambit":{"name":"Last gambit","description":"DEF -2. Starting battle below 200 HP grants ATK +6."}
}
static func _integer(value,low:int,high:int)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and floor(float(value))==float(value)
static func valid_milestones(values)->bool:
 if not values is Array or values.size()>3:return false
 for i in values.size():
  if not _integer(values[i],3,8) or int(values[i])!=[3,5,8][i]:return false
 return true
static func pool_for_milestones(values)->Array:
 if not valid_milestones(values) or values.is_empty():return []
 return IDS.slice(0,values.size()+3)
static func valid_pool(values)->bool:
 if not values is Array or values.size() not in [0,4,5,6]:return false
 for i in values.size():
  if not values[i] is String or values[i]!=IDS[i]:return false
 return true
static func valid_id(value)->bool:
 return value is String and (value=="none" or TEMPLATES.has(value))
static func rank(seed_value:int,id:String)->int:
 var hash_value:int=2166136261
 for byte in ("legacy-strategy-v1|%d|%s"%[seed_value,id]).to_utf8_buffer():
  hash_value=((hash_value ^ byte)*16777619)&0xffffffff
 return hash_value
static func offers(seed_value,pool)->Array:
 if not _integer(seed_value,0,2147483647) or not valid_pool(pool):return []
 var ordered:Array=pool.duplicate()
 ordered.sort_custom(func(a,b):
  var ra=rank(int(seed_value),a);var rb=rank(int(seed_value),b)
  return a<b if ra==rb else ra<rb)
 return ordered.slice(0,mini(3,ordered.size()))
static func valid_offers(seed_value,pool,values)->bool:
 if not _integer(seed_value,0,2147483647) or not valid_pool(pool) or not values is Array:return false
 return values==offers(seed_value,pool)
static func valid_choice(values,choice)->bool:
 if not values is Array or values.size() not in [0,3] or not valid_id(choice):return false
 var seen={}
 for id in values:
  if not id is String or not TEMPLATES.has(id) or seen.has(id):return false
  seen[id]=true
 return choice=="none" or choice in values
static func pool_from_profile(profile)->Array:
 if not Profile.validate(profile).ok:return []
 return pool_for_milestones(profile.milestones)
static func draft(seed_value,pool)->Dictionary:
 if not _integer(seed_value,0,2147483647) or not valid_pool(pool):return {}
 return {"version":VERSION,"pool":pool.duplicate(),"offers":offers(seed_value,pool),"choice":"none" if pool.is_empty() else ""}
static func valid_draft(seed_value,value)->bool:
 if not value is Dictionary or value.size()!=4:return false
 for key in ["version","pool","offers","choice"]:
  if not value.has(key):return false
 if not value.choice is String:return false
 if _integer(value.version,0,0):return value.pool is Array and value.pool.is_empty() and value.offers is Array and value.offers.is_empty() and value.choice=="none"
 if not _integer(value.version,VERSION,VERSION) or not valid_offers(seed_value,value.pool,value.offers):return false
 if value.pool.is_empty():return value.choice=="none"
 return value.choice=="" or valid_choice(value.offers,value.choice)
# skill means an actually invested skill (armed AND focus available).
# first_strike_suppressed incorporates oath/flank; hp is start-of-battle HP.
static func modifiers(id,context:Dictionary={})->Dictionary:
 if not valid_id(id):return {}
 for key in ["skill","first_strike","first_strike_suppressed"]:
  if not context.get(key,false) is bool:return {}
 for key in ["hp","enemy_hp"]:
  if not _integer(context.get(key,200 if key=="hp" else 0),0,2147483647):return {}
 var result={"atk":0,"def":0,"levels":0,"heal_after":0,"focus_after":0,"gold_tax_percent":0}
 match id:
  "study":result.atk=-4;result.def=-2;result.levels=4
  "forager":result.heal_after=12;result.gold_tax_percent=25
  "channel":result.def=-3;result.focus_after=1 if context.get("enemy_hp",0)>=180 else 0
  "reserve":result.atk=-3;result.def=0 if context.get("skill",false) else 4
  "ambush_hunter":
   result.atk=6 if context.get("first_strike",false) and not context.get("first_strike_suppressed",false) else -2;result.def=-2
  "last_gambit":result.atk=6 if context.get("hp",200)<200 else 0;result.def=-2
 return result
# Gains apply only after an actual surviving kill. The caller applies the heal
# under its existing HP rules; focus gain is already bounded to the stated cap.
static func kill_rewards(id,enemy_hp,enemy_gold,survived,focus,focus_cap)->Dictionary:
 if not valid_id(id) or not survived is bool:return {}
 for value in [enemy_hp,enemy_gold,focus,focus_cap]:
  if not _integer(value,0,2147483647):return {}
 if focus>focus_cap:return {}
 var result={"heal":0,"focus":0,"gold":0,"gold_penalty":0}
 if not survived:return result
 result.gold=int(enemy_gold)
 if id=="forager":
  result.heal=12;result.gold_penalty=int(ceil(float(enemy_gold)/4.0));result.gold-=result.gold_penalty
 if id=="channel" and enemy_hp>=180:result.focus=mini(1,int(focus_cap-focus))
 return result
