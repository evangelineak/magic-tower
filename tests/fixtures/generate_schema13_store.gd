extends SceneTree
const Store=preload("res://scripts/session_storage.gd")
func _initialize():call_deferred("run")
func run():
 var store=Store.new("user://journeys-v1-test-schema13-source-"+Crypto.new().generate_random_bytes(8).hex_encode())
 var active=await store.create_run(0,2,"safe",false,"schema13_fixture_run_0001")
 assert(active.ok)
 var moved=Store.World.from_snapshot(active.snapshot);assert(moved.step(Vector2i.RIGHT))
 active=await store.commit_run(active.slot,active.revision,active.run_id,moved.save_data(),"schema13_fixture_save_0001");assert(active.ok)
 var out=FileAccess.open("/tmp/schema13-active-store.json",FileAccess.WRITE);out.store_string(FileAccess.get_file_as_string(store.native.root.path_join("store.json")));out.close()
 var archived=await store.settle_run(active.slot,active.revision,active.run_id,"withdrawn","schema13_fixture_settle_01");assert(archived.ok)
 out=FileAccess.open("/tmp/schema13-archived-store.json",FileAccess.WRITE);out.store_string(FileAccess.get_file_as_string(store.native.root.path_join("store.json")));out.close()
 quit()
