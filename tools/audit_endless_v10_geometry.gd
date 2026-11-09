extends SceneTree
const G=preload("res://scripts/endless_generation_v10.gd")
const Old=preload("res://scripts/endless_generation_v9.gd")
const ENEMIES=["g","w","b","r","c","V"]
var checks:=0
var failures:=[]
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
func _initialize():call_deferred("run")
func run():
 var old_shapes={};var shapes={};var new_shapes={};var maps=0;var channels=0
 for seed in range(48):
  for f in [1,2,3,4,17,50,100,1000000]:old_shapes[wall_signature(Old.generate(seed,f).grid)]=true
 for seed in range(48):
  for f in [1,2,3,4,17,50,100,1000000]:
   maps+=1
   var data:Dictionary=G.generate(seed,f);var grid:Array=data.grid;var tag=str([seed,f]);var sig=wall_signature(grid)
   shapes[sig]=true
   if not old_shapes.has(sig):new_shapes[sig]=true
   if G.is_channel(seed,f):channels+=1
   var stairs_down=positions(grid,["<"]);var stairs_up=positions(grid,[">"])
   check(stairs_down.size()==1 and stairs_up.size()==1,tag+" one stair each")
   var entry:Vector2i=stairs_down[0];var exit:Vector2i=stairs_up[0]
   check(exit==G.anchors(f+1).entry,tag+" upstairs paired same coordinate")
   if f<1000000:
    var next_grid:Array=G.generate(seed,f+1).grid
    check(next_grid[exit.y][exit.x]=="<",tag+" actual next floor landing is stair")
   else:check(not G.generate(seed,f+1).get("ok",false),tag+" terminal safety boundary rejects extra floor")
   var routes:Array=G.routes(seed,f);var monsters=positions(grid,ENEMIES);var doors=positions(grid,["D"]);var blocked=monsters+doors
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
   var camp:Vector2i=G.camp_position(seed,f)
   check(grid[camp.y][camp.x]=="M",tag+" declared camp matches actual cell")
 check(channels>0 and new_shapes.size()>0,"new wall topology is not any sampled old rotation/reflection")
 print("GEOMETRY_RESULT "+JSON.stringify({"rules":10,"maps":maps,"seeds":48,"depths":[1,2,3,4,17,50,100,1000000],"checks":checks,"failures":failures,"channel_maps":channels,"old_canonical_wall_shapes":old_shapes.size(),"sampled_wall_shapes":shapes.size(),"new_canonical_wall_shapes":new_shapes.size(),"method":"Independent BFS; no calls to core validate as oracle; wall masks canonicalized over all eight rotations/reflections"}))
 quit(0 if failures.is_empty() else 1)
