class_name TowerRope
extends RefCounted
const Layout=preload("res://scripts/layout.gd")
static func legacy()->Dictionary:return {"version":0,"state":"off"}
static func birth(layout_revision:int)->Dictionary:return {"version":1,"state":"ready"} if layout_revision==2 else legacy()
static func valid_record(value,layout_revision:int,started:bool,seen:Array,expedition_revision:int)->bool:
	if not value is Dictionary or value.size()!=2 or not value.has("version") or not value.has("state"):return false
	if not (value.version is int or value.version is float) or not is_finite(float(value.version)) or (value.version!=0 and value.version!=1) or not value.state is String:return false
	if value.version==0:return value.state=="off"
	if layout_revision!=2 or value.state not in ["ready","spent"]:return false
	if started and expedition_revision!=3:return false
	return value.state!="spent" or (started and seen.size()==8 and seen[5] is bool and seen[5])
static func context(w)->bool:
	return w.rope.version==1 and w.layout_revision==2 and w.expedition_started and w.expedition_revision==3 and w.floor_index==5 and w.floor_seen.size()==8 and w.floor_seen[5]
static func preview(w)->Dictionary:
	var result:Dictionary={"valid":false,"available":false,"origin":Vector2i(-1,-1),"landing":Vector2i(-1,-1),"target":Vector2i(-1,-1),"cost":1,"disarm":false,"reason":"No single-use ferry rope is known here.","status":str(w.rope.state)}
	if not context(w):return result
	var target:=Vector2i(-1,-1)
	for y in range(1,10):
		for x in range(1,10):
			var p:=Vector2i(x,y)
			var canonical:=Layout.point(5,p,w.layout_revision)
			if canonical.x==5 and canonical.y in [6,7,8] and w.tile(p)=="H":target=p
	if target==Vector2i(-1,-1):
		result.reason="The ferry guardian is gone. Keep your focus; no rope crossing is needed."
		return result
	var direction:=Layout.direction(5,Vector2i.RIGHT,w.layout_revision)
	result.valid=true;result.target=target;result.origin=target-direction;result.landing=target+direction
	result.disarm=w.focus==1 and w.skill_armed
	if not w.generation_valid or w.strategy_pending() or w.ended_reason!="" or w.won or w.hp<=0 or w.moves>=1000000:result.reason="This journey is not currently accepting actions."
	elif w.rope.state!="ready":result.reason="The rope was used and snapped. Return by the bridge or by fighting the guardian."
	elif w.expedition_bridge:result.reason="The bridges are already open. Keep your focus and use the bridge."
	elif w.tile(result.landing)!=".":result.reason="The landing is not cleared floor. The rope cannot be used."
	elif w.pos!=result.origin:result.reason="Stand at the marked entrance-side takeoff point before crossing."
	elif w.focus<1:result.reason="No focus available. The normal battle and bridge routes remain available."
	else:
		result.available=true
		result.reason="Spend the last focus and cancel the armed skill; cross once without fighting. The rope then snaps." if result.disarm else "Spend 1 focus to cross once without fighting. The rope then snaps; no kill, gold or victory recovery."
	return result
