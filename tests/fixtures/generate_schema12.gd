extends SceneTree
# Run against the isolated schema-12 source commit documented in README.md.
const World=preload("res://scripts/world.gd")
func _initialize():
 for branch in ["layout2","layout1"]:
  var world=World.new(0)
  var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema11-"+branch+".json"))
  assert(old.version==11 and world.restore(old))
  assert(world.layout_revision==int(branch.right(1)))
  assert(world.gear_choices.is_empty())
  if branch=="layout1":
   for gear in ["maul","repeater"]:
    assert(gear in world.inventory)
    var options:Array=world.attunement_offers(gear)
    assert(not options.is_empty())
    # The actual first offered non-none action, never injected/rerolled offers.
    var action_id:String=options[0][0]
    assert(action_id.begins_with("attune_"+gear+"_"))
    assert(world.action(action_id))
    print(branch," selected ",action_id)
  var data:Dictionary=world.save_data()
  assert(data.version==12 and data.expedition_started and data.floors.size()==8 and not data.won)
  assert(not data.has("expedition_id") and not data.has("legacy_eligible"))
  var roundtrip=World.new(0)
  assert(roundtrip.restore(JSON.parse_string(JSON.stringify(data))))
  assert(JSON.stringify(roundtrip.save_data())==JSON.stringify(data))
  var file=FileAccess.open("/tmp/tower-schema12-output/schema12-"+branch+".json",FileAccess.WRITE)
  assert(file!=null)
  file.store_string(JSON.stringify(data));file.close()
  print(branch,": moves=",world.moves," hp=",world.hp," choices=",world.gear_choices)
 quit()
