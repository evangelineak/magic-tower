extends SceneTree
const G=preload("res://scripts/endless_generation_v22.gd")
func encoded(value):
 if value is Vector2i:return [value.x,value.y]
 if value is Array:
  var arr=[]
  for item in value:arr.append(encoded(item))
  return arr
 if value is Dictionary:
  var result={}
  for key in value:result[key]=encoded(value[key])
  return result
 return value
func _initialize():
 var samples=[]
 var problems=[]
 for seed_value in range(32):
  for block in range(4):
   var floors=[]
   for depth in range(4+8*block,12+8*block):
    if G.is_water(seed_value,depth):floors.append(depth)
   if floors.size()!=1 or floors[0] not in [4+8*block,6+8*block]:problems.append(["schedule",seed_value,block,floors]);continue
   var depth:int=floors[0];var m:Dictionary=G.water_manifest(seed_value,depth)
   var built:Dictionary=G.generate(seed_value,depth)
   samples.append({"seed":seed_value,"floor":depth,"variant":m.variant,"initial_state":m.initial_state,"grid":encoded(built.grid),"state0":encoded(G.state_grid(seed_value,depth,0)),"state1":encoded(G.state_grid(seed_value,depth,1)),"manifest":encoded(m)})
 var distribution={"0:0":0,"0:1":0,"1:0":0,"1:1":0}
 for seed_value in range(10000):
  for block in range(4):
   for depth in [4+8*block,6+8*block]:
    if not G.is_water(seed_value,depth):continue
    var info:Dictionary=G.water_manifest(seed_value,depth)
    distribution[str(info.variant)+":"+str(info.initial_state)]+=1
 for key in distribution:
  if distribution[key]<9000 or distribution[key]>11000:problems.append(["shape_state_correlation",key,distribution[key]])
 print("WATER_SPACE_EXPORT "+JSON.stringify({"samples":samples,"problems":problems,"distribution":distribution,"distribution_samples":40000,"distribution_scope":"Fixed 10000 seeds x four scheduled rooms, wide empirical regression bounds; not a proof of independent or truly random generation."}))
 quit(0 if problems.is_empty() else 1)
