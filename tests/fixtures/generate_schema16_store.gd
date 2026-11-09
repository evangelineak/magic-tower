extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
const Expedition=preload("res://scripts/expedition.gd")
const D={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
func _initialize():call_deferred("run")
func capture(store,label):
 var file=FileAccess.open("/tmp/schema16-"+label+"-store.json",FileAccess.WRITE)
 file.store_string(FileAccess.get_file_as_string(store.native.root.path_join("store.json")));file.close()
func run():
 var store=Store.new("user://journeys-v1-test-schema16-source-"+Crypto.new().generate_random_bytes(8).hex_encode())
 var fresh=await store.create_run(0,2,"risk",false,"schema16_fixture_run_0001");assert(fresh.ok)
 var w=World.from_snapshot(fresh.snapshot)
 for c in Generator.validate(w.floors).route:assert(w.step(D[c]))
 assert(w.action("expedition"))
 var route:String=Expedition.generate(0).witness;var i=0
 while w.floor_index<6:assert(w.step(D[route[i]]));i+=1
 for delta in Expedition.path_to(w.floors[w.floor_index],w.pos,Vector2i(8,2),{"hp":w.hp,"atk":w.atk,"def":w.defense}):assert(w.step(delta))
 var active=await store.commit_run(fresh.slot,fresh.revision,fresh.run_id,w.save_data(),"schema16_fixture_save_0001");assert(active.ok)
 capture(store,"active")
 var dead=await store.settle_death(active.slot,active.revision,active.run_id,Vector2i.RIGHT,"schema16_fixture_death_01");assert(dead.ok)
 capture(store,"death")
 var pending=await store.create_run(51,2,"safe",true,"schema16_fixture_pending01");assert(pending.ok)
 capture(store,"pending")
 quit()
