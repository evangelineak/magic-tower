extends SceneTree
# Independent review. Real chapter routes establish map/identity state; any
# edited local obstacle fixtures below are explicitly safety-negative tests.
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const L=preload("res://scripts/layout.gd")
const N=preload("res://scripts/navigation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func state(w)->Dictionary:return {"save":w.save_data().duplicate(true),"message":w.message,"battle":w.last_battle.duplicate(true)}
func begun(seed_value:int=0):
 var w=W.new(seed_value)
 for c in G.generate(seed_value,W.MAPS).validation.route:
  check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"real no-skill first-chapter route")
 check(w.won and w.action("expedition"),"real continuation establishes current expedition map")
 return w
func find(w,token:String)->Vector2i:
 for y in range(1,10):
  for x in range(1,10):
   if w.tile(Vector2i(x,y))==token:return Vector2i(x,y)
 return Vector2i(-1,-1)
func query(w,target:Vector2i)->Dictionary:
 var before=state(w)
 var result=w.tactical_forecast(target)
 check(state(w)==before,"tactical query never changes save/message/battle/armed/focus")
 check(w.tactical_forecast(target)==result,"repeated query deterministic without action or reroll")
 return result
func walk_no_fight(w,goal:Vector2i)->bool:
 var queue:Array=[w.pos];var parents:Dictionary={w.pos:Vector2i(-1,-1)};var head:=0
 while head<queue.size():
  var p:Vector2i=queue[head];head+=1
  if p==goal:break
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var n:Vector2i=p+d
   if n.x<1 or n.x>9 or n.y<1 or n.y>9 or parents.has(n):continue
   var t:String=w.tile(n)
   if t in W.ENEMIES or t in ["#","D","L","~","c","n","e","m","t","R","T","<",">"]:continue
   if t=="=" and not w.expedition_bridge:continue
   parents[n]=p;queue.append(n)
 if not parents.has(goal):return false
 var p:=goal;var path:Array=[]
 while p!=w.pos:
  var prev:Vector2i=parents[p];path.push_front(p-prev);p=prev
 for d in path:
  if not w.step(d):return false
 return true
func _init():
 var w=begun()
 var target:=find(w,"H");var flank:Vector2i=w.flank_position(target)
 var fresh=query(w,target)
 check(fresh.valid and fresh.flank.available and not fresh.flank.reachable,"real uncleared river route is not an instantaneous flank")
 check(fresh.rows.size()==1 and fresh.rows[0].id=="balanced","only actually owned gear is offered")
 check(fresh.rows[0].current.preview==w.battle_preview("H","balanced",target),"current forecast is the existing actual-position combat calculation")
 check(not fresh.rows[0].flank_unarmed.available and not fresh.rows[0].flank_unarmed.immediate and fresh.rows[0].flank_unarmed.theoretical,"unreachable flank remains theoretical regardless lower damage")
 check(fresh.rows[0].flank_unarmed.preview.damage<fresh.rows[0].unarmed.preview.damage,"flank difference is shown without secretly applying it")
 check(not query(w,Vector2i(-1,-1)).valid and not query(w,Vector2i(100,100)).valid,"outside targets reveal no enemy")
 var seen=w.floor_seen[w.floor_index];w.floor_seen[w.floor_index]=false
 check(not query(w,target).valid,"unseen current floor is never exposed even with supplied enemy coordinate")
 w.floor_seen[w.floor_index]=seen
 var revision:int=w.expedition_revision;w.expedition_revision=2
 check(not query(w,target).flank.available,"old expedition revision does not acquire new flank rule")
 w.expedition_revision=revision
 # Real paid bridge action and manual movement establish the far bank; no jump.
 check(walk_no_fight(w,find(w,"Y")) and w.action("camp_bridge"),"real roadworks paid before crossing")
 check(not query(w,target).flank.reachable,"even an opened bridge is not cleared-floor auto-walking")
 check(walk_no_fight(w,flank),"actual manual movement crosses bridge and reaches legitimate flank")
 var at_flank=query(w,target)
 check(at_flank.flank.reachable and at_flank.flank.steps==0 and at_flank.rows[0].unarmed.immediate,"only the real arrived position permits immediate flank combat")
 check(at_flank.rows[0].unarmed.preview==w.battle_preview("H","",target),"arrived preview agrees with theoretical flank model")
 # Step away along already cleared floor, then validate every offered walk edge.
 var away:=Vector2i(-1,-1)
 for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
  if w.tile(w.pos+d)==".":away=w.pos+d;break
 check(away!=Vector2i(-1,-1) and w.step(away-w.pos),"normal move establishes a nearby cleared approach")
 var plan=query(w,target)
 check(plan.flank.reachable and plan.flank.steps>0,"real cleared route can be suggested")
 var previous:Vector2i=w.pos
 for p in plan.flank.path:
  check(w.tile(p)=="." and absi(p.x-previous.x)+absi(p.y-previous.y)==1,"every suggested edge is adjacent and only cleared floor")
  previous=p
 # Controlled obstacle negative fixture replaces the target stand only, no map rewards.
 for blocker in ["#","D","L","~","=","h","k","a","d","M","N","Q","c","n","e",">","<","s"]:
  var old:String=w.tile(flank);w.floors[w.floor_index][flank.y][flank.x]=blocker
  var denied=query(w,target)
  check(not denied.flank.reachable and not denied.rows[0].flank_unarmed.available,"safe flank suggestion never crosses occupied stand "+blocker)
  w.floors[w.floor_index][flank.y][flank.x]=old
 # All row calculations remain pure across focus/oath/hero differences.
 var original=state(w)
 for hero in ["warden","ranger","scholar"]:
  for oath in ["fresh","active"]:
   for focus in [0,1,3]:
    w.hero_id=hero;w.oath_state=oath;w.focus=focus;w.skill_armed=hero!="scholar"
    var forecast=query(w,target);var row:Dictionary=forecast.rows[0]
    check(row.current.preview==w.battle_preview("H","",target),"current direction and actual skill flags agree for every hero/oath/focus")
    if hero=="scholar":check(row.armed.is_empty() and row.flank_armed.is_empty() and not forecast.skill_supported,"scholar has no invented armed combat branch")
    elif focus==0:
     check(not row.armed.available and not row.armed.immediate and row.armed.focus_after==null and row.armed.focus_restored==0,"zero-focus armed forecast cannot be executed or grant imaginary focus rewards")
    if oath=="active":
     check(row.unarmed.preview.damage==row.flank_unarmed.preview.damage,"oath already cancels ambush, flank does not double-discount")
 check(w.restore(original.save),"restore real pre-matrix state after controlled forecast fixtures")
 # Perform the suggested cleared path through the actual World API, then fight.
 for p in plan.flank.path:check(w.safe_walk_step(p,w.floor_index,w.pos),"suggested move executes only as ordinary guarded safe-walk steps")
 var arrived=query(w,target);var expected:Dictionary=arrived.rows[0].unarmed.preview
 var hp:int=w.hp;var focus:int=w.focus
 check(w.step(target-w.pos),"actual adjacent flank fight succeeds only after real movement")
 check(w.last_battle.damage==expected.damage and w.hp==hp-int(expected.damage)+int(expected.heal_after),"real fight HP equals the forecast at the reached position")
 check(w.focus==focus-int(expected.skill_consumed)+int(expected.focus_after),"unarmed real fight focus matches actual reward computation")
 check(not query(w,target).valid,"defeated enemy no longer yields stale tactical forecasts")
 # Genuine old save owns differently attuned maul/repeater. Position alone is
 # controlled for a visible live V; this is not presented as an executed route.
 var owned=W.from_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema12-layout1.json")))
 check(owned!=null,"true historical multi-gear fixture loads without granting new equipment")
 if owned!=null:
  owned.floor_index=2;owned.pos=Vector2i(7,3);owned.skill_armed=false
  var gear_rows=query(owned,Vector2i(8,3)).rows
  check(gear_rows.size()==owned.inventory.size(),"every owned equipment option appears exactly once")
  for row in gear_rows:
   check(row.current.preview==owned.battle_preview("V",row.id,Vector2i(8,3)),"each gear uses its own actual attunement rather than current gear tuning")
   check(row.unarmed.immediate==(row.id==owned.equipped and row.unarmed.preview.survivable),"different gear cannot be represented as immediately equipped")
 print("TACTICAL REVIEW: %d checks, failures=%d"%[checks,failures]);quit(1 if failures else 0)
