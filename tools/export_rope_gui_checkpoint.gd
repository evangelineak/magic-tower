extends SceneTree
# Actual new native registration + legal World actions + atomic save; no grafting.
const Store=preload("res://scripts/session_storage.gd")
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const DIR={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var actions=[]
func act(w,id):assert(w.action(id),id);actions.append({"type":"action","id":id})
func move(w,d):assert(w.step(d),w.message);actions.append({"type":"step","delta":[d.x,d.y]})
func _initialize():call_deferred("run")
func run():
 var nonce=Crypto.new().generate_random_bytes(16).hex_encode()
 var store=Store.new("user://journeys-v1-test-rope-gui-"+nonce)
 var born=await store.create_run(0,2,"safe",false,nonce);assert(born.ok)
 var w=W.from_snapshot(born.snapshot);act(w,"hero_ranger")
 for key in G.generate(0,W.MAPS).validation.route:
  if W.ENEMIES.has(w.tile(w.pos+DIR[key])) and w.focus>0 and not w.skill_armed:act(w,"arm")
  move(w,DIR[key])
 act(w,"expedition")
 for key in E.generate(0).witness:
  if w.tile(w.pos+DIR[key])=="H":break
  move(w,DIR[key])
 assert(w.rope_preview().available,"checkpoint did not reach usable real rope")
 var saved=await store.commit_run(born.slot,born.revision,born.run_id,w.save_data(),"rope_gui_checkpoint_"+nonce);assert(saved.ok)
 var path=store.native.root.path_join("store.json")
 assert(DirAccess.copy_absolute(path,"/tmp/rope-gui-checkpoint.json")==OK)
 var evidence={"source":"tools/export_rope_gui_checkpoint.gd; real Store.create_run then legal actions then Store.commit_run","run_id":w.run_id,"seed":0,"mode":"safe","schema":w.save_data().version,"native_path":path,"sha256":FileAccess.get_file_as_string(path).sha256_text(),"actions":actions,"checkpoint":{"floor":w.floor_index+1,"position":[w.pos.x,w.pos.y],"hp":w.hp,"focus":w.focus,"gold":w.gold,"moves":w.moves,"rope":w.rope},"preview":w.rope_preview()}
 var file=FileAccess.open("/tmp/rope-gui-checkpoint-provenance.json",FileAccess.WRITE);file.store_string(JSON.stringify(evidence,"  "));file.close()
 print(JSON.stringify({"path":path,"export":"/tmp/rope-gui-checkpoint.json","evidence":"/tmp/rope-gui-checkpoint-provenance.json","checkpoint":evidence.checkpoint,"sha256":evidence.sha256}))
 quit()
