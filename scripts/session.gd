class_name TowerSession
extends RefCounted
# World mutations are speculative until the adapter's durable CAS succeeds.
# Adapters MUST deduplicate stable request IDs, including create acknowledgements
# lost after commit. No file I/O fallback is permitted here.
const World = preload("res://scripts/world.gd")
var world = null
var history:Array = []
var busy = false
var read_only = false
var last_error = ""
var slot:int = -1
var revision:int = -1
var adapter
var _pending:Dictionary = {}

func _init(storage): adapter = storage
func _reply(ok:bool,status:String,reason:String="",committed:bool=false) -> Dictionary:
 return {"ok":ok,"status":status,"reason":reason,"committed":committed}
func _gate() -> Dictionary:
 if busy: return _reply(false,"busy","A storage operation is in progress.")
 if read_only: return _reply(false,"readonly","Reload the current journey before changing it.")
 if not _pending.is_empty(): return _reply(false,"pending","Retry the pending save or reload before another action.")
 return {}
func _nonce() -> String: return Crypto.new().generate_random_bytes(16).hex_encode()
func _clone(snapshot:Dictionary):
 return World.from_snapshot(snapshot)
func new_run(seed_value:int,layout:int=2,replace_active:bool=false) -> Dictionary:
 var gate=_gate()
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
 slot=int(result.slot); revision=int(result.revision)
 history.clear(); _pending.clear(); read_only=false; last_error=""
 return _reply(true,"loaded")
func _validated_response(result):
 if not result.get("eligible") is bool or result.eligible != true: return null
 if not result.get("snapshot") is Dictionary or not result.get("run_id") is String: return null
 for key in ["slot","revision"]:
  var value=result.get(key)
  if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>2147483647 or floor(float(value))!=value: return null
 var candidate=_clone(result.snapshot)
 if candidate==null or candidate.run_id!=result.run_id or not candidate.reward_eligible() or candidate.ended_reason!="": return null
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
 if _pending.kind=="commit":
  if int(result.slot)!=_pending.slot or int(result.revision)!=_pending.revision+1 or result.run_id!=_pending.run_id or restored.save_data()!=_pending.snapshot:
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
  if int(result.revision)!=0 or int(result.slot)<=slot or restored.run_id!=_pending.request_id or restored.save_data()!=fresh.save_data():
   read_only=true
   return _reply(false,"invalid_response","Created journey does not match the requested fresh run.")
  world=restored
  history.clear()
 slot=int(result.slot);revision=int(result.revision)
 var effect:Dictionary=_pending.effect.duplicate(true)
 _pending.clear();read_only=false;last_error=""
 var reply=_reply(true,"committed","",true)
 reply.effect=effect
 return reply
