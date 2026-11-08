class_name TowerSession
extends RefCounted
# World mutations are speculative until the adapter's durable CAS succeeds.
# Adapters MUST deduplicate stable request IDs, including create acknowledgements
# lost after commit. No file I/O fallback is permitted here.
const World = preload("res://scripts/world.gd")
const Profile = preload("res://scripts/legacy_profile.gd")
var world = null
var history:Array = []
var busy = false
var read_only = false
var terminal = false
var receipt:Dictionary = {}
var profile:Dictionary = {}
var last_error = ""
var slot:int = -1
var revision:int = -1
var adapter
var _pending:Dictionary = {}

func _init(storage): adapter = storage
func _reply(ok:bool,status:String,reason:String="",committed:bool=false) -> Dictionary:
 return {"ok":ok,"status":status,"reason":reason,"committed":committed}
func _gate(allow_terminal:bool=false) -> Dictionary:
 if busy: return _reply(false,"busy","A storage operation is in progress.")
 if read_only: return _reply(false,"readonly","Reload the current journey before changing it.")
 if not _pending.is_empty(): return _reply(false,"pending","Retry the pending save or reload before another action.")
 if terminal and not allow_terminal: return _reply(false,"terminal","This journey is settled. Start a new journey to play again.")
 return {}
func _nonce() -> String: return Crypto.new().generate_random_bytes(16).hex_encode()
func _clone(snapshot:Dictionary):
 return World.from_snapshot(snapshot)
func new_run(seed_value:int,layout:int=2,replace_active:bool=false) -> Dictionary:
 var gate=_gate(true)
 if not gate.is_empty(): return gate
 if seed_value<0 or seed_value>2147483647 or not layout in [1,2]: return _reply(false,"invalid","Invalid new journey options.")
 _pending={"kind":"create","seed":seed_value,"layout":layout,"replace":replace_active,"request_id":_nonce(),"effect":{"operation":"create"}}
 return await _commit_pending()
func open_current() -> Dictionary:
 if busy: return _reply(false,"busy")
 busy=true
 var result=await adapter.read_active()
 busy=false
 return _load_result(result)
func reacquire_and_reload() -> Dictionary:
 if busy: return _reply(false,"busy")
 busy=true
 var result=await adapter.reacquire_and_read()
 busy=false
 return _load_result(result)
func _load_result(result) -> Dictionary:
 if not result is Dictionary or not result.get("ok",false):
  last_error=str(result.get("reason","Cannot read journey.")) if result is Dictionary else "Invalid storage response."
  read_only=true
  # An actually empty store permits a fresh create, but never erases a live view.
  if result is Dictionary and result.get("status")=="empty" and world==null:
   read_only=false
   _pending.clear()
  return _reply(false,str(result.get("status","storage_error")) if result is Dictionary else "storage_error",last_error)
 var candidate=_validated_response(result)
 if candidate==null:
  read_only=true
  return _reply(false,"invalid_response","Stored journey failed full validation.")
 world=candidate
 _publish_terminal(result)
 slot=int(result.slot); revision=int(result.revision)
 history.clear(); _pending.clear(); read_only=false; last_error=""
 return _reply(true,"loaded")
func _publish_terminal(result:Dictionary):
 terminal=result.status=="archived"
 receipt=result.receipt.duplicate(true) if terminal else {}
 if result.get("profile") is Dictionary: profile=result.profile.duplicate(true)
func _same_json(left, right) -> bool:
 # JSON transports integer fields as floats. Compare validated values without
 # treating booleans as numbers or weakening schema/type validation.
 if (left is int or left is float) and (right is int or right is float): return left==right
 if typeof(left)!=typeof(right): return false
 if left is Dictionary:
  if left.size()!=right.size(): return false
  for key in left:
   if not right.has(key) or not _same_json(left[key],right[key]): return false
  return true
 if left is Array:
  if left.size()!=right.size(): return false
  for i in left.size():
   if not _same_json(left[i],right[i]): return false
  return true
 return left==right
func _validated_response(result):
 if not result.get("status") is String or not result.status in ["active","archived"]: return null
 if not result.get("profile") is Dictionary or not Profile.validate(result.profile).ok: return null
 if not result.get("eligible") is bool or result.eligible != true: return null
 if not result.get("snapshot") is Dictionary or not result.get("run_id") is String: return null
 for key in ["slot","revision"]:
  var value=result.get(key)
  if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>2147483647 or floor(float(value))!=value: return null
 var candidate=_clone(result.snapshot)
 if candidate==null or candidate.run_id!=result.run_id or not candidate.reward_eligible() or candidate.mode!="safe": return null
 if result.status=="active":
  if candidate.ended_reason!="": return null
  if result.profile.receipts.has(candidate.run_id): return null
 else:
  if candidate.ended_reason=="" or not result.get("receipt") is Dictionary or not result.get("profile") is Dictionary: return null
  if not Profile.validate(result.profile).ok or not result.profile.receipts.has(candidate.run_id): return null
  if not _same_json(result.receipt,result.profile.receipts[candidate.run_id]): return null
  var outcome=result.receipt.summary.outcome
  if not outcome in ["withdrawn","chapter1","victory"]: return null
  var derived=candidate.settlement_summary(outcome)
  if not derived.get("ok",false) or not _same_json(derived.summary,result.receipt.summary): return null
 return candidate
func step(delta:Vector2i) -> Dictionary: return await _perform("step",delta)
func action(id:String) -> Dictionary: return await _perform("action",id)
func safe_walk(next:Vector2i,expected_floor:int,expected_pos:Vector2i) -> Dictionary:
 return await _perform("walk",{"next":next,"floor":expected_floor,"pos":expected_pos})
func save() -> Dictionary: return await _perform("save",null)
func undo() -> Dictionary: return await _perform("undo",null)
func _perform(kind:String,value) -> Dictionary:
 var gate=_gate()
 if not gate.is_empty(): return gate
 if world==null: return _reply(false,"empty","No active journey.")
 if kind=="undo" and history.is_empty(): return _reply(false,"invalid","No move to undo in this session.")
 var before:Dictionary=world.save_data().duplicate(true)
 var candidate=_clone(history.back() if kind=="undo" else before)
 if candidate==null or candidate.run_id!=world.run_id: return _reply(false,"invalid","Journey identity or history is invalid.")
 var accepted=true
 match kind:
  "step": accepted=candidate.step(value)
  "action": accepted=candidate.action(value)
  "walk": accepted=candidate.safe_walk_step(value.next,value.floor,value.pos)
  "undo": candidate.message="One step back. A different possibility."
  "save": candidate.message="Journey saved locally."
  _: accepted=false
 if not accepted: return _reply(false,"rejected",candidate.message)
 var effect={"operation":kind}
 if kind=="step":
  effect.input=value
  effect.token=world.tile(world.pos+value)
  effect.hero=world.hero_id
 elif kind=="action": effect.input=value
 _pending={"effect":effect,"kind":"commit","operation":kind,"candidate":candidate,"before":before,"snapshot":candidate.save_data().duplicate(true),"slot":slot,"revision":revision,"run_id":world.run_id,"request_id":_nonce()}
 return await _commit_pending()
func finish(outcome:String) -> Dictionary:
 var gate=_gate()
 if not gate.is_empty(): return gate
 if world==null: return _reply(false,"empty","No active journey.")
 if not outcome in ["withdrawn","chapter1","victory"]: return _reply(false,"invalid","Unsupported settlement outcome.")
 var candidate=_clone(world.save_data())
 if candidate==null or candidate.mode!="safe" or not candidate.finish_run(outcome): return _reply(false,"rejected","This journey cannot settle with that outcome.")
 var summary=candidate.settlement_summary(outcome)
 if not summary.get("ok",false): return _reply(false,"invalid","Journey settlement summary is invalid.")
 _pending={"kind":"settle","outcome":outcome,"candidate":candidate,"snapshot":candidate.save_data().duplicate(true),"summary":summary.summary.duplicate(true),"slot":slot,"revision":revision,"run_id":world.run_id,"request_id":_nonce(),"effect":{"operation":"settle","input":outcome}}
 return await _commit_pending()
func retry_pending() -> Dictionary:
 if busy: return _reply(false,"busy")
 if read_only: return _reply(false,"readonly","Reload the current journey before retrying.")
 if _pending.is_empty(): return _reply(false,"empty","No save is pending.")
 return await _commit_pending()
func _commit_pending() -> Dictionary:
 busy=true
 var result
 if _pending.kind=="create":
  result=await adapter.create_run(_pending.seed,_pending.layout,"safe",_pending.replace,_pending.request_id)
 elif _pending.kind=="settle":
  result=await adapter.settle_run(_pending.slot,_pending.revision,_pending.run_id,_pending.outcome,_pending.request_id)
 else:
  result=await adapter.commit_run(_pending.slot,_pending.revision,_pending.run_id,_pending.snapshot.duplicate(true),_pending.request_id)
 busy=false
 if not result is Dictionary or not result.get("ok",false):
  last_error=str(result.get("reason","Storage commit failed.")) if result is Dictionary else "Invalid storage response."
  read_only=not (result is Dictionary and result.get("retryable",false)==true)
  return _reply(false,str(result.get("status","storage_error")) if result is Dictionary else "storage_error",last_error)
 var restored=_validated_response(result)
 if restored==null:
  read_only=true
  return _reply(false,"invalid_response","Committed journey response failed validation; reload required.")
 if _pending.kind!="settle" and not profile.is_empty() and not _same_json(profile,result.profile):
  read_only=true
  return _reply(false,"invalid_response","A non-settlement operation changed the profile ledger.")
 if _pending.kind=="settle":
  if result.status!="archived" or int(result.slot)!=_pending.slot+1 or int(result.revision)!=_pending.revision+1 or result.run_id!=_pending.run_id or restored.save_data()!=_pending.snapshot or not _same_json(result.receipt.summary,_pending.summary):
   read_only=true
   return _reply(false,"invalid_response","Settlement acknowledgement does not match the pending journey.")
  if not profile.is_empty():
   var expected=Profile.settle(profile,_pending.run_id,_pending.summary)
   if not expected.ok or expected.status!="applied" or not _same_json(expected.profile,result.profile) or not _same_json(expected.receipt,result.receipt):
    read_only=true
    return _reply(false,"invalid_response","Settlement rewards do not match the current profile ledger.")
  world=_pending.candidate
  history.clear()
 elif _pending.kind=="commit":
  if result.status!="active" or int(result.slot)!=_pending.slot or int(result.revision)!=_pending.revision+1 or result.run_id!=_pending.run_id or restored.save_data()!=_pending.snapshot:
   read_only=true
   return _reply(false,"invalid_response","Commit acknowledgement does not match the pending journey.")
  if _pending.operation=="undo": history.pop_back()
  elif _pending.operation!="save":
   history.append(_pending.before.duplicate(true))
   if history.size()>100: history.pop_front()
  # Keep the speculative transient message/battle snapshot for effects only now.
  world=_pending.candidate
 else:
  var fresh=World.new(_pending.seed,_pending.layout,_pending.request_id,"safe")
  if result.status!="active" or int(result.revision)!=0 or int(result.slot)<=slot or restored.run_id!=_pending.request_id or restored.save_data()!=fresh.save_data():
   read_only=true
   return _reply(false,"invalid_response","Created journey does not match the requested fresh run.")
  world=restored
  history.clear()
 _publish_terminal(result)
 slot=int(result.slot);revision=int(result.revision)
 var effect:Dictionary=_pending.effect.duplicate(true)
 _pending.clear();read_only=false;last_error=""
 var reply=_reply(true,"committed","",true)
 reply.effect=effect
 return reply
