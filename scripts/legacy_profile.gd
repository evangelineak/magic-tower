class_name TowerLegacyProfile
extends RefCounted
## Pure settlement ledger, NOT persistence, a lock, or offline anti-cheat.
## The caller must transact against the latest profile and derive summaries from
## authoritative run state. Unlock IDs have no automatic gameplay effects.
const REVISION = 1
const MAX_RECEIPTS = 4096
const MILESTONES = [3, 5, 8]
const UNLOCKS = ["legacy_scout", "legacy_tactician", "legacy_veteran"]
const OUTCOMES = ["withdrawn", "chapter1", "victory", "defeat"]

static func fresh() -> Dictionary:
 return {"revision":REVISION,"milestones":[],"receipts":{},"unlocked":[]}

static func _integer(value, low:int, high:int) -> bool:
 if not (value is int or value is float): return false
 return is_finite(float(value)) and value >= low and value <= high and floor(float(value)) == value

static func _keys(value, keys:Array) -> bool:
 if not value is Dictionary or value.size() != keys.size(): return false
 for key in keys:
  if not value.has(key): return false
 return true

static func valid_run_id(value) -> bool:
 if not value is String or value.length() < 16 or value.length() > 64: return false
 for c in value:
  if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-"): return false
 return true

static func _summary(value) -> Dictionary:
 if not _keys(value,["seed","max_floor","moves","outcome"]): return {}
 if not _integer(value.seed,0,2147483647) or not _integer(value.max_floor,1,8) or not _integer(value.moves,0,10000000): return {}
 if not value.outcome is String or not value.outcome in OUTCOMES: return {}
 if value.outcome == "chapter1" and value.max_floor < 5: return {}
 if value.outcome == "victory" and value.max_floor != 8: return {}
 return {"seed":int(value.seed),"max_floor":int(value.max_floor),"moves":int(value.moves),"outcome":value.outcome}

static func _awards(milestones, unlocked) -> bool:
 if not milestones is Array or not unlocked is Array or milestones.size() > 3 or milestones.size() != unlocked.size(): return false
 var previous = 0
 for i in milestones.size():
  var value = milestones[i]
  if not _integer(value,3,8): return false
  var index = MILESTONES.find(int(value))
  if index < 0 or value <= previous or not unlocked[i] is String or unlocked[i] != UNLOCKS[index]: return false
  previous = int(value)
 return true

static func _invalid(reason:String) -> Dictionary:
 return {"ok":false,"reason":reason}

static func validate(profile) -> Dictionary:
 if not _keys(profile,["revision","milestones","receipts","unlocked"]): return _invalid("Invalid profile fields.")
 if not _integer(profile.revision,REVISION,REVISION): return _invalid("Unsupported profile revision.")
 if not _awards(profile.milestones,profile.unlocked): return _invalid("Invalid profile unlocks.")
 if not profile.receipts is Dictionary or profile.receipts.size() > MAX_RECEIPTS: return _invalid("Invalid receipt ledger.")
 var awarded = {}
 var reached = {}
 for run_id in profile.receipts:
  if not valid_run_id(run_id): return _invalid("Invalid run identifier.")
  var receipt = profile.receipts[run_id]
  if not _keys(receipt,["run_id","summary","milestones","unlocked"]) or not receipt.run_id is String or receipt.run_id != run_id: return _invalid("Invalid receipt fields.")
  var summary = _summary(receipt.summary)
  if summary.is_empty() or not _awards(receipt.milestones,receipt.unlocked): return _invalid("Invalid receipt summary or unlocks.")
  for milestone in MILESTONES:
   if milestone <= summary.max_floor: reached[milestone] = true
  for value in receipt.milestones:
   var milestone = int(value)
   if milestone > summary.max_floor or awarded.has(milestone): return _invalid("Duplicate or unearned milestone.")
   awarded[milestone] = true
 if awarded.size() != reached.size() or awarded.size() != profile.milestones.size(): return _invalid("Milestone ledger does not match profile.")
 for milestone in reached:
  if not awarded.has(milestone): return _invalid("Reached milestone is missing its receipt.")
 for value in profile.milestones:
  if not awarded.has(int(value)): return _invalid("Profile unlock has no receipt.")
 return {"ok":true,"reason":""}

static func _result(ok:bool,status:String,reason:String,profile,receipt:Dictionary={},unlocks:Array=[]) -> Dictionary:
 # Invalid data is never silently converted to a fresh profile.
 return {"ok":ok,"status":status,"reason":reason,"profile":profile.duplicate(true) if profile is Dictionary else null,"receipt":receipt.duplicate(true),"new_unlocks":unlocks.duplicate()}

static func settle(profile,run_id,summary) -> Dictionary:
 var validation = validate(profile)
 if not validation.ok: return _result(false,"invalid",validation.reason,profile)
 if not valid_run_id(run_id): return _result(false,"invalid","Invalid run identifier.",profile)
 var canonical = _summary(summary)
 if canonical.is_empty(): return _result(false,"invalid","Invalid settlement summary.",profile)
 if profile.receipts.has(run_id):
  var original:Dictionary = profile.receipts[run_id]
  if _summary(original.summary) == canonical: return _result(true,"duplicate","This run was already settled.",profile,original)
  return _result(false,"conflict","This run was settled with a different summary; its original receipt is final.",profile,original)
 if profile.receipts.size() >= MAX_RECEIPTS: return _result(false,"full","Receipt ledger is full; no receipts were removed.",profile)
 var next:Dictionary = profile.duplicate(true)
 var milestones:Array = []
 var unlocks:Array = []
 for i in MILESTONES.size():
  var milestone:int = MILESTONES[i]
  if milestone <= canonical.max_floor and not profile.milestones.has(milestone) and not profile.milestones.has(float(milestone)):
   milestones.append(milestone)
   unlocks.append(UNLOCKS[i])
 var receipt = {"run_id":run_id,"summary":canonical,"milestones":milestones,"unlocked":unlocks}
 next.receipts[run_id] = receipt.duplicate(true)
 # Canonicalize profile-level numeric arrays, including profiles parsed from JSON.
 next.revision = REVISION
 next.milestones = []
 next.unlocked = []
 for i in MILESTONES.size():
  if profile.milestones.has(MILESTONES[i]) or profile.milestones.has(float(MILESTONES[i])) or milestones.has(MILESTONES[i]):
   next.milestones.append(MILESTONES[i])
   next.unlocked.append(UNLOCKS[i])
 return _result(true,"applied","",next,receipt,unlocks)
