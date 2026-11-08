extends SceneTree
const P=preload("res://scripts/progression.gd")
func _initialize():
 var cases=[]
 for seed_value in [0,1,2,3,7,42,51,999,2147483647]:
  for version in [0,1]:cases.append({"seed":seed_value,"expected":P.talent_draft(seed_value,version)})
 var file=FileAccess.open("res://tests/fixtures/talent-storage-vectors.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source":"actual progression.gd talent_draft output","cases":cases},"  ")+"\n")
 file.close();quit()
