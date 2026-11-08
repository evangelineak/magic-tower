extends SceneTree
# Godot --headless --path . --script tools/generate_legacy_strategy_vectors.gd
# Independent JS implementations consume these outputs, not a second formula here.
const S=preload("res://scripts/legacy_strategy.gd")
const OUTPUT="res://tests/fixtures/legacy-strategy-vectors.json"
func _init():
 var cases=[]
 for milestones in [[],[3],[3,5],[3,5,8]]:
  var pool=S.pool_for_milestones(milestones)
  for seed_value in [0,1,2,3,7,42,99,1024,65535,2147483646,2147483647]:
   var ranks={}
   for id in pool:ranks[id]=S.rank(seed_value,id)
   cases.append({"seed":seed_value,"milestones":milestones,"pool":pool,"ranks":ranks,"expected_offers":S.offers(seed_value,pool),"expected_draft":S.draft(seed_value,pool)})
 var invalid=[]
 for pool in [null,true,{},["study"],["study","forager","channel","study"],["forager","study","channel","reserve"],["study","forager","channel","fake"]]:
  invalid.append({"seed":0,"pool":pool,"valid_pool":S.valid_pool(pool),"expected_offers":S.offers(0,pool)})
 for seed_value in [null,true,"42",-1,1.5,2147483648]:
  invalid.append({"seed":seed_value,"pool":S.IDS,"valid_pool":true,"expected_offers":S.offers(seed_value,S.IDS)})
 var modifiers=[]
 for id in ["none"]+S.IDS:
  for context in [{},{"hp":199,"skill":true,"first_strike":true,"enemy_hp":180},{"hp":200,"skill":false,"first_strike":true,"first_strike_suppressed":true,"enemy_hp":179}]:
   modifiers.append({"id":id,"context":context,"expected":S.modifiers(id,context)})
 var output={"version":S.VERSION,"algorithm":"fnv1a32 UTF8 legacy-strategy-v1|<decimal seed>|<id>; unsigned ascending rank then ID ascending; first three","cases":cases,"invalid_cases":invalid,"modifier_cases":modifiers}
 var file=FileAccess.open(OUTPUT,FileAccess.WRITE);assert(file!=null)
 file.store_string(JSON.stringify(output,"  ")+"\n");file.close()
 print("STRATEGY VECTORS: ",cases.size()," offers, ",invalid.size()," invalid, ",modifiers.size()," modifiers")
 quit()
