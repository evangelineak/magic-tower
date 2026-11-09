extends SceneTree
const World=preload("res://scripts/world.gd")
const Generator=preload("res://scripts/generation.gd")
func _initialize():
 var current=World.new(0)
 assert(current.layout_revision==2)
 var proof=Generator.validate(current.floors,2)
 assert(proof.solvable)
 for c in proof.route:
  assert(current.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]))
 assert(current.won and current.action("expedition"))
 capture(current,"layout2")
 var legacy=World.new(0)
 assert(legacy.restore(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema10-armory.json"))))
 assert(legacy.layout_revision==1 and legacy.expedition_started and legacy.rescue_state==2)
 assert(legacy.action("rescue_repeater"))
 capture(legacy,"layout1")
 quit()
func capture(world,branch:String):
 var data=world.save_data()
 assert(data.version==11 and data.expedition_started and data.floors.size()==8 and not data.won)
 var file=FileAccess.open("/tmp/tower-v18-legacy/schema11-"+branch+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(data));file.close()
 print(branch,": moves=",world.moves," hp=",world.hp," floor=",world.floor_index+1," pos=",world.pos)
