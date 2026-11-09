extends SceneTree
var G=load("res://scripts/endless_generation_v16.gd")
var W=load("res://scripts/endless_world_v16.gd")
const ENEMIES=["g","w","b","r","c","t","p","V"]
var checks:=0
var failures=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func cells(grid:Array,tokens:Array)->Array:
 var found=[]
 for y in 15:
  for x in 15:
   if grid[y][x] in tokens:found.append(Vector2i(x,y))
 return found
func reach(grid:Array,start:Vector2i,blocked:Array)->Dictionary:
 var seen={start:true};var queue=[start];var head=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var q=p+d
   if q.x<0 or q.y<0 or q.x>=15 or q.y>=15 or seen.has(q) or q in blocked:continue
   if grid[q.y][q.x] in ["#","M","S","N","u","v"]:continue
   seen[q]=true;queue.append(q)
 return seen
func _initialize():call_deferred("run")
func run():
 var sampled=0;var bridges=0;var branch_maps=0
 for seed in range(64):
  for f in [1,2,3,4,17,50,100,1000000]:
   sampled+=1;var data:Dictionary=G.generate(seed,f);var tag=str([seed,f])
   check(data.get("ok",false),tag+" generation valid")
   if not data.get("ok",false):continue
   var original:Array=data.grid
   if cells(original,["N"]).is_empty():continue
   bridges+=1
   for choice in ["","short","loot"]:
    branch_maps+=1;var w=W.new_run(seed);w.floor_number=f
    if choice!="":w.bridges[f]=choice
    var grid=original.duplicate(true)
    for y in 15:
     for x in 15:grid[y][x]=w.tile(Vector2i(x,y))
    var label=tag+" "+choice;var entry:Vector2i=G.anchors(f).entry;var exit:Vector2i=G.anchors(f).exit
    var guards=cells(grid,ENEMIES);var doors=cells(grid,["D"]);var blocked=guards+doors
    check(not reach(grid,entry,blocked).has(exit),label+" no zero-battle path")
    var routes:Array=G.routes(seed,f)
    for index in 2:
     var allowed:Array=routes[index].points.duplicate()
     if choice=="short" and index==1:allowed.erase(Vector2i(8,8))
     var banned=blocked.duplicate()
     for p in allowed:banned.erase(p)
     check(reach(grid,entry,banned).has(exit) and reach(grid,exit,banned).has(entry),label+" expected main/side route works both ways")
     for p in allowed:check(not reach(grid,entry,banned+[p]).has(exit),label+" every remaining required guard is a real cut")
    check(grid[8][8] in ENEMIES,label+" skipped guard remains in world")
    for p in cells(original,["u","v"]):
     var selected:bool=(original[p.y][p.x]=="u" and choice=="short") or (original[p.y][p.x]=="v" and choice=="loot")
     check((grid[p.y][p.x]==".")==selected,label+" only selected bridge opens")
    var unrestricted=reach(grid,entry,[])
    var box:Vector2i=cells(grid,["B"])[0]
    check(unrestricted.has(box)==(choice=="loot"),label+" explicit loot island only accessible through loot choice")
    if choice=="loot":check(not reach(grid,entry,[Vector2i(6,4)]).has(box),label+" extra loot guard cannot be bypassed")
    for door in doors:
     var shut=reach(grid,entry,[door]);var valuable=false
     for reward in cells(grid,["$","T"]):
      if unrestricted.has(reward) and not shut.has(reward):valuable=true
     check(valuable,label+" original key door remains a valuable true cut")
    for guard in cells(grid,["V"]):
     var shut=reach(grid,entry,[guard]);var valuable=false
     for relic in cells(grid,["T"]):
      if unrestricted.has(relic) and not shut.has(relic):valuable=true
     check(valuable,label+" relic guard remains a real cut")
    check(grid[entry.y][entry.x]=="<" and grid[exit.y][exit.x]==">",label+" original stairs preserved")
    if f<1000000:check(G.generate(seed,f+1).grid[exit.y][exit.x]=="<",label+" next actual stair at same coordinate")
 check(bridges>0,"bridge family represented")
 print("BRIDGE_SPACE_RESULT "+JSON.stringify({"rules":16,"samples":sampled,"bridge_floors":bridges,"branch_maps":branch_maps,"checks":checks,"failures":failures,"note":"Controlled branch overlay for independent spatial proof, not a legal acquisition history; all movement BFS is independent of production validate"}))
 quit(0 if failures.is_empty() else 1)
