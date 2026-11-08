extends SceneTree
const N=preload("res://scripts/navigation.gd")
const W=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func corridor()->Array:
 var grid=[]
 for y in range(11):
  var row=[]
  for x in range(11): row.append("#")
  grid.append(row)
 for x in range(1,7): grid[1][x]="."
 return grid
func _init():
 var grid=corridor()
 var before=grid.duplicate(true)
 var route=N.walk_path(grid,Vector2i(1,1),Vector2i(6,1))
 check(route==[Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),Vector2i(5,1),Vector2i(6,1)],"absolute adjacent path excludes origin")
 check(grid==before,"planning is pure")
 for token in ["s","W","H","Z","h","a","d","k","D","L","n","e","m","t","J","N","M","E","U","Y","v","<",">","~","=","?","$","A","P","T","C","I","O","R","Q","F","X"]:
  grid=corridor(); grid[1][3]=token
  check(N.walk_path(grid,Vector2i(1,1),Vector2i(6,1)).is_empty(),"auto walking cannot cross "+token)
  check(N.walk_path(grid,Vector2i(1,1),Vector2i(3,1)).is_empty(),"auto walking cannot target "+token)
 for origin in ["J","N","E","<",">"]:
  grid=corridor(); grid[1][1]=origin
  check(N.walk_path(grid,Vector2i(1,1),Vector2i(6,1)).size()==5,"can leave current NPC/stair without activating it")
 grid=corridor()
 check(N.walk_path(grid,Vector2i(1,1),Vector2i(1,1)).is_empty(),"no-op target empty")
 check(N.walk_path(grid,Vector2i(-1,1),Vector2i(2,1)).is_empty(),"invalid origin rejected")
 check(N.walk_path(grid,Vector2i(1,1),Vector2i(100,1)).is_empty(),"invalid target rejected")
 grid[1].pop_back()
 check(N.walk_path(grid,Vector2i(1,1),Vector2i(2,1)).is_empty(),"malformed rows rejected")
 var w=W.new(0)
 w.floors[0]=corridor(); w.pos=Vector2i(1,1)
 var saved=w.save_data().duplicate(true)
 check(w.safe_walk_step(Vector2i(2,1),0,Vector2i(1,1)),"world accepts exact cleared adjacent context")
 var expected=saved.duplicate(true); expected.x=2; expected.moves+=1
 check(w.save_data()==expected,"safe step changes only coordinates and one move, never resources/anchors")
 saved=w.save_data().duplicate(true)
 check(not w.safe_walk_step(Vector2i(3,1),1,Vector2i(2,1)) and w.save_data()==saved,"stale floor rejected atomically")
 check(not w.safe_walk_step(Vector2i(3,1),0,Vector2i(1,1)) and w.save_data()==saved,"stale origin rejected atomically")
 check(not w.safe_walk_step(Vector2i(4,1),0,Vector2i(2,1)) and w.save_data()==saved,"cannot skip intermediate cells")
 var plan=w.safe_walk_path(Vector2i(6,1)); w.floors[0][1][3]="h"
 saved=w.save_data().duplicate(true)
 check(not plan.is_empty() and not w.safe_walk_step(plan[0],0,w.pos) and w.save_data()==saved,"new pickup blocks stale route without consuming it")
 w.floors[0][1][3]="."; w.won=true
 check(w.safe_walk_path(Vector2i(6,1)).is_empty() and not w.safe_walk_step(Vector2i(3,1),0,w.pos),"won blocks planning and movement")
 w.won=false; w.generation_valid=false
 check(w.safe_walk_path(Vector2i(6,1)).is_empty() and not w.safe_walk_step(Vector2i(3,1),0,w.pos),"invalid generation blocks planning and movement")
 w=W.new(0); saved=w.save_data().duplicate(true)
 var info=w.tooltip_data(Vector2i(3,1))
 check(info.title=="Gold key" and info.lines.size()>0,"resource tooltip reports known facts")
 check(w.save_data()==saved,"tooltip never discovers, spends or claims")
 w=W.new(0,2)
 info=w.tooltip_data(Vector2i(8,2))
 check("Sealed room reward: 70 HP." in info.lines,"new one-key room reveals actual promised reward")
 w.floors[0][2][9]="."
 info=w.tooltip_data(Vector2i(8,2))
 check("The room's reward has already been collected." in info.lines and not "Sealed room reward: 70 HP." in info.lines,"collected room no longer advertises unclaimed loot")
 w=W.new(0,1)
 info=w.tooltip_data(Vector2i(6,3))
 check("Legacy shortcut: this old layout may have another way around." in info.lines,"legacy bypassable door is not misrepresented as sealed room")
 print("SAFE WALK: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
