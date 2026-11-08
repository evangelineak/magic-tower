class_name TowerTacticalForecast
extends RefCounted
# Read-only counterfactuals. Never applies skill, changes gear, travels, or attacks.
# available = preparation prerequisites, NOT adjacency/survival. immediate requires
# the exact live gear/armed/position plus a surviving adjacent fight. focus_cost is
# the proposed skill investment, never evidence that a charge was consumed.
# focus_after/restored only describe a survivable, sufficiently funded outcome.
static func build(w,target:Vector2i)->Dictionary:
 var result={"valid":false,"reason":"No visible enemy on this floor.","target":target,"origin":w.pos,"kind":"","skill_supported":w.hero_id in ["warden","ranger"],"focus":w.focus,"flank":{"available":false,"position":Vector2i(-1,-1),"reachable":false,"path":[],"steps":-1},"rows":[]}
 if not w.generation_valid or w.floors.is_empty() or not w.floor_seen[w.floor_index] or not w.ENEMIES.has(w.tile(target)):return result
 var kind:String=w.tile(target)
 result.valid=true;result.reason="";result.kind=kind
 var flank:Vector2i=w.flank_position(target)
 if flank!=Vector2i(-1,-1):
  var path=w.safe_walk_path(flank)
  result.flank={"available":true,"position":flank,"reachable":flank==w.pos or not path.is_empty(),"path":path.duplicate(),"steps":0 if flank==w.pos else (path.size() if not path.is_empty() else -1)}
 for gear in w.inventory:
  var current:bool=w.skill_armed and w.focus>0
  var row={"id":gear,"current":branch(w,kind,target,gear,w.pos,current,true),"unarmed":branch(w,kind,target,gear,w.pos,false,true),"armed":{},"flank_unarmed":{},"flank_armed":{}}
  if result.skill_supported:row.armed=branch(w,kind,target,gear,w.pos,true,true)
  if result.flank.available:
   row.flank_unarmed=branch(w,kind,target,gear,flank,false,result.flank.reachable)
   if result.skill_supported:row.flank_armed=branch(w,kind,target,gear,flank,true,result.flank.reachable)
  result.rows.append(row)
 return result
static func branch(w,kind:String,target:Vector2i,gear:String,at:Vector2i,skill:bool,reachable:bool)->Dictionary:
 var preview:Dictionary=w._battle_preview_with_talents(kind,gear,target,w.talents,w.floor_index,skill,at)
 var alive:bool=preview.get("valid",false) and preview.get("survivable",false)
 var active:bool=not w.strategy_pending() and w.ended_reason=="" and not w.won
 var enough:bool=not skill or w.focus>0
 var available:bool=active and enough and reachable
 var same_skill:bool=skill==(w.skill_armed and w.focus>0)
 var immediate:bool=available and alive and gear==w.equipped and at==w.pos and same_skill and absi(target.x-at.x)+absi(target.y-at.y)==1
 var spent:int=1 if preview.get("skill_consumed",false) else 0
 var restored:int=mini(maxi(0,w.focus_cap-w.focus+spent),int(preview.get("focus_after",0))) if alive and enough else 0
 var focus_after=null
 if alive and enough:focus_after=w.focus-spent+restored
 var reason=""
 if not active:reason="This journey is not currently accepting actions."
 elif not enough:reason="No focus available; this skill forecast is theoretical."
 elif not reachable:reason="No cleared-floor walking path to this position; forecast only."
 return {"preview":preview,"after_hp":w.hp-int(preview.damage)+int(preview.get("heal_after",0)) if alive else -1,"focus_cost":1 if skill else 0,"focus_restored":restored,"focus_after":focus_after,"available":available,"immediate":immediate,"reason":reason,"position":at,"theoretical":not immediate}
