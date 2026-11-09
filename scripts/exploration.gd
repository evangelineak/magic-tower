class_name TowerExploration
extends RefCounted
# No discovery flags, route execution, rewards, or mutations. Existing visible
# floors and explicitly accepted quest/sign information are the only sources.
static func seen(w,f:int)->bool:
	return f>=0 and f<w.floor_seen.size() and w.floor_seen[f]
static func find(w,f:int,token:String)->Vector2i:
	if not seen(w,f) or f>=w.floors.size():return Vector2i(-1,-1)
	for y in range(11):
		for x in range(11):
			if w.floors[f][y][x]==token:return Vector2i(x,y)
	return Vector2i(-1,-1)
static func goal(id:String,title:String,f:int,p:Vector2i,why:String,missing:String,status:String)->Dictionary:
	return {"id":id,"title":title,"floor":f,"position":p,"pos":p,"why":why,"missing":missing,"status":status,"lines":[why,missing,status]}
static func goals(w)->Array:
	var result:Array=[]
	if not w.generation_valid or w.floors.is_empty() or w.ended_reason!="" or (w.won and w.expedition_started):return result
	if w.cargo.version==1 and w.cargo.state!="claimed":
		if w.cargo.state=="waiting" or (w.cargo.state=="opened" and w.floors[0][2][9]=="h"):
			result.append(goal("cargo","Sealed medical supply",0,Vector2i(8,2) if w.cargo.state=="waiting" else Vector2i(9,2),"The original supply restores 70 HP, once.","Spend one key now or inspect the fixed shipping destination." if w.cargo.state=="waiting" else "The source door is open; collect the supply locally.",w.cargo_status()))
		elif w.cargo.state=="shipped":
			var f:=2 if w.cargo.destination=="vault" else 4
			var p:=Vector2i(9,2) if f==2 else Vector2i(1,3)
			if not seen(w,f):p=Vector2i(-1,-1)
			result.append(goal("cargo","Shipped medical supply",f,p,"Shipping saved the source key; this is still the same 70 HP supply.","Return to the marked freight location and collect the original supply manually." if w.cargo_ready() else ("Defeat the Vault Colossus, then collect beside the freight chute." if f==2 else "Defeat the Regent, continue the expedition, then return beside the calibration stand."),w.cargo_status()))
	var vault:=find(w,2,"T")
	if vault!=Vector2i(-1,-1):
		var guarded:=find(w,2,"V")!=Vector2i(-1,-1)
		result.append(goal("vault","Star vault",2,vault,"The vault holds 10 ATK and 45 gold; returning stronger can change the route.","The Vault Colossus still guards the entrance. Compare battle loss before returning." if guarded else "The guardian is gone. Enter the treasure tile to collect it.","Guarded" if guarded else "Ready to collect"))
	if w.quest_state<3:
		var sample:=find(w,2,"I")
		if w.quest_state==2:
			result.append(goal("survey","Choose the survey's use",0,find(w,0,"J"),"One sample serves one branch: Ilen's gold or focus training, or the forge's flood bridge.","Visit J for gold or focus. The bridge at F is unavailable after draining." if w.water_choice=="drain" else "Visit J for gold or focus, or keep the sample for F on floor 4 to preserve the spring.","Sample carried; no reward chosen"))
		elif w.quest_state==1 or sample!=Vector2i(-1,-1):
			result.append(goal("survey","Find the survey sample",2,sample,"The sample can fund a reward at J or a spring-preserving bridge at F.","Explore floor 3 and collect the sample. Its location stays hidden until that floor is seen.","Sample not collected"))
	if w.rescue_state<3 and w.expedition_revision!=1:
		var apprentice:=find(w,6,"t")
		if w.rescue_state==2:
			result.append(goal("mira","Choose Mira's destination",0,find(w,0,"J"),"Bring Mira home for the repeating crossbow, or support the expedition camp instead.","Choose J's crossbow OR U's camp reward. The two rewards are exclusive.","Mira rescued; destination undecided"))
		elif w.rescue_state==1 or apprentice!=Vector2i(-1,-1):
			var ready:bool=seen(w,6) and (find(w,6,"W")==Vector2i(-1,-1) or w.winch_choice=="rescue")
			result.append(goal("mira","Find Mira",6,apprentice,"Ilen's missing apprentice can be rescued on floor 7.","The rescue route is open. Reach Mira before the final battle." if ready else ("Explore floor 7. Defeat the gaoler or inspect the rescue winch." if w.expedition_revision>=3 else "Explore floor 7 and defeat the gaoler guarding Mira.") if seen(w,6) else "Explore floor 7 to find Mira. Her exact location is not yet known.","Rescue route open" if ready else "Mira not rescued"))
	if w.won:
		for item in result:
			item.status="First chapter complete; exploration is paused."
			item.missing="Choose to continue the expedition before returning to this unfinished goal."
			item.lines=[item.why,item.missing,item.status]
	return result
