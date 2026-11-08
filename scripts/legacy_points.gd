class_name TowerLegacyPoints
extends RefCounted
const Strategy=preload("res://scripts/legacy_strategy.gd")
const VERSION=1
const LEVELS_PER_POINT=2
static func integer(value,low:int,high:int)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=low and value<=high
static func capacity_for_pool(pool)->int:
 if not Strategy.valid_pool(pool):return -1
 return 0 if pool.is_empty() else pool.size()-3
static func valid_allocation(capacity:int,allocation)->bool:
 if capacity<0 or capacity>3 or not allocation is Dictionary:return false
 if allocation.is_empty():return true
 if allocation.size()!=2 or not allocation.has("study") or not allocation.has("reserve"):return false
 return integer(allocation.study,0,2) and integer(allocation.reserve,0,2) and allocation.study+allocation.reserve<=capacity
static func allocate(capacity:int,allocation:Dictionary={})->Dictionary:
 if not valid_allocation(capacity,allocation):return {}
 return {"version":VERSION,"capacity":capacity,"study":int(allocation.get("study",0)),"reserve":int(allocation.get("reserve",0))}
static func legacy()->Dictionary:return {"version":0,"capacity":0,"study":0,"reserve":0}
static func valid_record(value,reserves,pool,pending:bool)->bool:
 if not value is Dictionary or value.size()!=4:return false
 for key in ["version","capacity","study","reserve"]:
  if not value.has(key):return false
 if not integer(value.version,0,1) or not integer(value.capacity,0,3) or not integer(reserves,0,2):return false
 if not valid_allocation(int(value.capacity),{"study":value.study,"reserve":value.reserve}):return false
 if value.version==0:return value.capacity==0 and value.study==0 and value.reserve==0 and reserves==0
 if int(value.capacity)!=capacity_for_pool(pool) or reserves>value.reserve:return false
 return not pending or (value.study==0 and value.reserve==0 and reserves==0)
