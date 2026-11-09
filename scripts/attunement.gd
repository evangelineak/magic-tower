class_name TowerAttunement
extends RefCounted
# Revision 1 is deterministic without consuming Godot/global random streams.
# Persist actual offers in the run; future revisions must not reroll old choices.
const REVISION=1
const GEAR_IDS=["balanced","buckler","duelist","repeater","maul"]
const TEMPLATE_IDS=["focus_light","focus_deep","edge_light","edge_deep","guard_light","guard_deep"]
const TEMPLATES={
 "focus_light":{"name":"Clear focus","description":"Skill level +1 / DEF -2. Armor penetration, Brace and Mend use the new level.","atk":0,"def":-2,"levels":1},
 "focus_deep":{"name":"Deep focus","description":"Skill level +2 / ATK -1 / DEF -3. Stronger skills, weaker physical defenses.","atk":-1,"def":-3,"levels":2},
 "edge_light":{"name":"Honed edge","description":"ATK +3 / DEF -2. Faster kills can cost more damage per counter.","atk":3,"def":-2,"levels":0},
 "edge_deep":{"name":"Razor edge","description":"ATK +6 / DEF -5. Stronger attacks at a larger defensive cost.","atk":6,"def":-5,"levels":0},
 "guard_light":{"name":"Light plating","description":"DEF +2 / ATK -2. Softer counters, but armor thresholds may worsen.","atk":-2,"def":2,"levels":0},
 "guard_deep":{"name":"Heavy plating","description":"DEF +4 / ATK -5. Stronger protection at a larger attack cost.","atk":-5,"def":4,"levels":0}
}
static func valid_id(value)->bool:
 return value is String and (value=="none" or TEMPLATES.has(value))
static func modifiers(id:String)->Dictionary:
 if id=="none": return {"atk":0,"def":0,"levels":0}
 if not TEMPLATES.has(id): return {}
 return {"atk":TEMPLATES[id].atk,"def":TEMPLATES[id].def,"levels":TEMPLATES[id].levels}
static func offers(seed_value:int,gear_id:String)->Array:
 if seed_value<0 or seed_value>2147483647 or not gear_id in GEAR_IDS: return []
 # Small explicit LCG stays safely below int64 overflow and is engine-independent.
 var state:int=(seed_value+104729*(GEAR_IDS.find(gear_id)+1)+0x2D57A1)%2147483647
 if state==0: state=1
 var pool=TEMPLATE_IDS.duplicate()
 for i in range(pool.size()-1,0,-1):
  state=(state*48271)%2147483647
  var j:int=state%(i+1)
  var swap=pool[i]; pool[i]=pool[j]; pool[j]=swap
 return pool.slice(0,3)
static func valid_offers(values)->bool:
 if not values is Array or values.size()!=3: return false
 var found={}
 for id in values:
  if not id is String or not TEMPLATES.has(id) or found.has(id): return false
  found[id]=true
 return true
static func valid_selection(values,selected)->bool:
 return valid_offers(values) and valid_id(selected) and (selected=="none" or selected in values)
