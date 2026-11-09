extends SceneTree
var G=load("res://scripts/endless_generation_v14.gd")
var Old=load("res://scripts/endless_generation_v13.gd")
const ENEMIES=["g","w","b","r","c","t","p","V"]
var checks:=0
var failures:=[]
var inherited_notes:=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func reach(grid:Array,start:Vector2i,blocked:Array)->Dictionary:
 var queue=[start];var seen={start:true};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d
   if n.y<0 or n.y>=grid.size() or n.x<0 or n.x>=grid[n.y].size() or seen.has(n):continue
   if n in blocked or grid[n.y][n.x] in ["#","M","S","E"]:continue
   seen[n]=true;queue.append(n)
 return seen
func positions(grid:Array,tokens:Array)->Array:
 var result=[]
 for y in grid.size():
  for x in grid[y].size():
   if grid[y][x] in tokens:result.append(Vector2i(x,y))
 return result
func wall_signature(grid:Array)->String:
 var signatures=[];var n=grid.size()
 for flip in [false,true]:
  for rotation in 4:
   var key=""
   for y in n:
    for x in n:
     var p=Vector2i(x,y)
     if flip:p.x=n-1-p.x
     for turn in rotation:p=Vector2i(n-1-p.y,p.x)
     key+="#" if grid[p.y][p.x]=="#" else "."
   signatures.append(key)
 signatures.sort();return signatures[0]
func distances(grid:Array,start:Vector2i,blocked:Array)->Dictionary:
 var queue=[start];var dist={start:0};var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var q=p+d
   if q.x<0 or q.y<0 or q.y>=grid.size() or q.x>=grid[q.y].size() or dist.has(q) or q in blocked or grid[q.y][q.x] in ["#","M","S","E"]:continue
   dist[q]=dist[p]+1;queue.append(q)
 return dist
func route_geometry(grid:Array,start:Vector2i,end:Vector2i,blocked:Array)->Array:
 var dist=distances(grid,start,blocked)
 if not dist.has(end):return [-1,-1]
 var dirs=[Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
 var costs={start:{-1:0}}
 # distances inserts cells in BFS order, so all predecessor depths are complete.
 for point in dist:
  if not costs.has(point):continue
  for i in 4:
   var next=point+dirs[i]
   if not dist.has(next) or dist[next]!=dist[point]+1:continue
   if not costs.has(next):costs[next]={}
   for prior in costs[point]:
    var turns:int=costs[point][prior]+(1 if prior!=-1 and prior!=i else 0)
    costs[next][i]=mini(costs[next].get(i,2147483647),turns)
 var best=2147483647
 for turns in costs.get(end,{}).values():best=mini(best,turns)
 return [dist[end],best]
func metric_signature(grid:Array,routes:Array)->String:
 var start:Vector2i=positions(grid,["<"])[0];var end:Vector2i=positions(grid,[">"])[0]
 var closed=positions(grid,ENEMIES+["D"]);var lengths=[]
 for route in routes:
  var banned=closed.duplicate()
  for point in route.points:banned.erase(point)
  lengths.append(route_geometry(grid,start,end,banned))
 var landmarks=positions(grid,["<",">","D","V","$","T"]);var ds=[]
 for i in landmarks.size():
  var d=distances(grid,landmarks[i],[])
  for j in range(i+1,landmarks.size()):ds.append(d.get(landmarks[j],-1))
 ds.sort()
 return str([lengths,ds,middle_cycle_rank(grid)])
func middle_cycle_rank(grid:Array)->int:
 var vertices={};var edges=0
 for y in range(4,11):
  for x in range(1,14):
   if grid[y][x] not in ["#","M","S","E"]:vertices[Vector2i(x,y)]=true
 for p in vertices:
  for d in [Vector2i.RIGHT,Vector2i.DOWN]:
   if vertices.has(p+d):edges+=1
 var unvisited=vertices.duplicate();var components=0
 while not unvisited.is_empty():
  components+=1;var q=[unvisited.keys()[0]];unvisited.erase(q[0]);var head=0
  while head<q.size():
   var p=q[head];head+=1
   for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    if unvisited.has(p+d):unvisited.erase(p+d);q.append(p+d)
 return edges-vertices.size()+components
func _initialize():call_deferred("run")
func run():
 var old_shapes={};var shapes={};var new_shapes={};var maps=0;var channels=0
 var old_metrics={};var metrics={};var new_metrics={};var details=[]
 for seed in range(64):
  for f in [1,2,3,4,17,50,100,1000000]:
   var old:Dictionary=Old.generate(seed,f)
   old_shapes[wall_signature(old.grid)]=true
   old_metrics[metric_signature(old.grid,Old.routes(seed,f))]=true
 for seed in range(64):
  for f in [1,2,3,4,17,50,100,1000000]:
   maps+=1
   var data:Dictionary=G.generate(seed,f);var grid:Array=data.grid;var tag=str([seed,f]);var sig=wall_signature(grid)
   shapes[sig]=true
   if not old_shapes.has(sig):new_shapes[sig]=true
   if G.layout_name(seed,f)=="分叉沟渠":channels+=1
   var metric=metric_signature(grid,G.routes(seed,f));metrics[metric]=true
   if not old_metrics.has(metric):new_metrics[metric]=true
   details.append({"seed":seed,"floor":f,"layout":G.layout_name(seed,f),"metric":metric,"middle_cycle_rank":middle_cycle_rank(grid)})
   var stairs_down=positions(grid,["<"]);var stairs_up=positions(grid,[">"])
   check(stairs_down.size()==1 and stairs_up.size()==1,tag+" one stair each")
   var entry:Vector2i=stairs_down[0];var exit:Vector2i=stairs_up[0]
   check(exit==G.anchors(f+1).entry,tag+" upstairs paired same coordinate")
   if f<1000000:
    var next_grid:Array=G.generate(seed,f+1).grid
    check(next_grid[exit.y][exit.x]=="<",tag+" actual next floor landing is stair")
   else:check(not G.generate(seed,f+1).get("ok",false),tag+" terminal safety boundary rejects extra floor")
   var routes:Array=G.routes(seed,f);var monsters=positions(grid,ENEMIES);var doors=positions(grid,["D"]);var blocked=monsters+doors
   if G.is_ring(seed,f):
    var side_lengths=[]
    for side in [-1,1]:
     var local_block=[]
     for yy in 15:
      for xx in 15:
       if yy<6 or yy>8 or xx<5 or xx>9 or (side==-1 and xx>7) or (side==1 and xx<7):local_block.append(Vector2i(xx,yy))
     var local_dist=distances(grid,Vector2i(7,6),local_block)
     var distance:int=local_dist.get(Vector2i(7,8),-1);side_lengths.append(distance)
     check(distance==(6 if grid[7][7+side]=="#" else 4),tag+" independent left/right ring arc remains genuinely usable")
    details.back().ring_side_lengths=side_lengths

   check(not reach(grid,entry,blocked).has(exit),tag+" no free mandatory bypass")
   for route in routes:
    var permitted:Array=route.points;var banned=blocked.duplicate()
    for point in permitted:banned.erase(point)
    check(reach(grid,entry,banned).has(exit) and reach(grid,exit,banned).has(entry),tag+" route works both directions")
    for point in permitted:
     check(grid[point.y][point.x] in ENEMIES,tag+" declared guard exists")
     check(not reach(grid,entry,banned+[point]).has(exit),tag+" each route guard is necessary")
   for door in doors:
    var closed=reach(grid,entry,[door]);var opened=reach(grid,entry,[]);var valuable=0
    for point in positions(grid,["$","T"]):
     if opened.has(point) and not closed.has(point):valuable+=1
    check(valuable>0,tag+" door is true cut to valuable reward")
   for guard in positions(grid,["V"]):
    var closed=reach(grid,entry,[guard]);var opened=reach(grid,entry,[]);var relic=false
    for point in positions(grid,["T"]):
     if opened.has(point) and not closed.has(point):relic=true
    check(relic,tag+" vault guard actually gates relic")
   check(positions(grid,["M"]).size()==1 and positions(grid,["S"]).size()==1,tag+" camps and skill station unique")
   var safe=reach(grid,entry,blocked)
   for resource in positions(grid,["a","C"]):check(safe.has(resource),tag+" entry resource reachable without combat/door")
   for station in positions(grid,["M","S"]):
    var adjacent=false
    for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     if safe.has(station+direction):adjacent=true
    if G.is_ring(seed,f):check(adjacent,tag+" new station usable from safe entrance area")
    elif not adjacent:inherited_notes.append(tag+" inherited station requires crossing combat "+str(station))
   var all_open=reach(grid,entry,[])
   for cell in positions(grid,[".","a","C","k","$","T","D","V","g","w","b","r","c","t","p"]):
    if G.is_ring(seed,f) or grid[cell.y][cell.x]!=".":check(all_open.has(cell),tag+" traversable or functional cell not orphaned "+str(cell))
    elif not all_open.has(cell):inherited_notes.append(tag+" inherited isolated decorative floor "+str(cell))
   var camp:Vector2i=G.camp_position(seed,f)
   check(grid[camp.y][camp.x]=="M",tag+" declared camp matches actual cell")
 check(channels>0 and new_shapes.size()>0 and new_metrics.size()>0,"new wall topology is not any sampled old rotation/reflection")
 print("GEOMETRY_RESULT "+JSON.stringify({"rules":14,"maps":maps,"seeds":64,"depths":[1,2,3,4,17,50,100,1000000],"checks":checks,"failures":failures,"inherited_notes":inherited_notes,"channel_maps":channels,"old_metric_signatures":old_metrics.size(),"new_metric_signatures":new_metrics.size(),"details":details,"old_canonical_wall_shapes":old_shapes.size(),"sampled_wall_shapes":shapes.size(),"new_canonical_wall_shapes":new_shapes.size(),"method":"Independent BFS; no calls to core validate as oracle; wall masks canonicalized over all eight rotations/reflections"}))
 quit(0 if failures.is_empty() else 1)
