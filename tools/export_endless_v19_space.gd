extends SceneTree
func _initialize():
 var G=load("res://scripts/endless_generation_v19.gd");var Old=load("res://scripts/endless_generation_v16.gd")
 var samples=[];var failures=[]
 for seed in range(64):
  var floors:Array=G.cart_floors(seed)
  if floors.size()>2:failures.append([seed,"too many events"])
  for f in floors:
   if f not in [3,5,9,11] or Old.has_bridge(seed,f):failures.append([seed,f,"schedule collision"])
   var data:Dictionary=G.generate(seed,f)
   # Export actual grid, never treat production validate/proof as our proof.
   samples.append({"seed":seed,"floor":f,"variant":G.cart_manifest(seed,f).variant,"grid":data.grid})
 print("SPACE_EXPORT "+JSON.stringify({"samples":samples,"schedule_failures":failures}))
 quit(0 if failures.is_empty() else 1)
