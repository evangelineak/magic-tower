extends SceneTree
const W=preload("res://scripts/world.gd")
const E=preload("res://scripts/expedition.gd")
const G=preload("res://scripts/generation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func get_goal(w,id:String)->Dictionary:
 var before=w.save_data().duplicate(true);var message:String=w.message;var battle:Dictionary=w.last_battle.duplicate(true)
 var goals=w.exploration_goals()
 check(w.save_data()==before and w.message==message and w.last_battle==battle,"query is wholly read only")
 for item in goals:
  check(item.position==item.pos and item.lines==[item.why,item.missing,item.status],"view contract aliases consistent")
  if item.id==id:return item
 return {}
func _init():
 var w=W.new(0)
 check(get_goal(w,"vault").is_empty() and get_goal(w,"survey").is_empty() and get_goal(w,"mira").is_empty(),"newborn cannot know unseen quests or vault")
 check(not get_goal(w,"cargo").is_empty(),"visible source sign is a known local choice")
 w.quest_state=1;w.rescue_state=1
 check(get_goal(w,"survey").floor==2 and get_goal(w,"survey").position==Vector2i(-1,-1),"accepted sample quest knows floor but not hidden coordinates")
 var mira=get_goal(w,"mira")
 check(mira.floor==6 and mira.position==Vector2i(-1,-1) and not mira.missing.contains("winch"),"accepted Mira quest does not reveal unseen winch or coordinate")
 w.floor_seen[1]=true;w.floor_seen[2]=true
 check(get_goal(w,"vault").position==Vector2i(9,3),"seen vault has actual treasure coordinate")
 check(get_goal(w,"survey").position==Vector2i(2,8),"seen sample uses actual token location")
 w.quest_state=2
 check(get_goal(w,"survey").missing.contains("F on floor 4"),"carried sample preserves branch choice without auto-selecting reward")
 w.water_choice="drain"
 check(get_goal(w,"survey").missing.contains("unavailable"),"drain updates actual remaining sample branches")
 w.quest_state=3;check(get_goal(w,"survey").is_empty(),"delivered sample no longer a pending goal")
 w.floors[2][3][8]="."
 check(get_goal(w,"vault").status=="Ready to collect","defeated guard changes goal to real remaining pickup")
 w.floors[2][3][9]=".";check(get_goal(w,"vault").is_empty(),"collected treasure removed")
 w.cargo.state="shipped";w.floors[0][2][8]=".";w.floors[0][2][9]="."
 check(not get_goal(w,"cargo").missing.contains("Defeat"),"ready cargo does not ask to kill already defeated guardian")
 w.cargo.state="claimed";check(get_goal(w,"cargo").is_empty(),"claimed cargo removed")
 w.floors.append_array(E.generate(0).maps);w.expedition_started=true;w.expedition_revision=3
 w.floor_seen=[true,true,true,true,true,true,true,false]
 check(get_goal(w,"mira").missing.contains("winch"),"seen actual winch becomes a legitimate rescue alternative")
 w.winch_choice="rescue"
 check(get_goal(w,"mira").status=="Rescue route open","opened side gate updates rescue access")
 w.rescue_state=2
 check(get_goal(w,"mira").missing.contains("OR U"),"rescued apprentice still offers mutually exclusive reward destinations")
 w.rescue_state=3;check(get_goal(w,"mira").is_empty(),"rewarded rescue removed")
 w=W.new(1);w.cargo.state="shipped";w.floors[0][2][8]=".";w.floors[0][2][9]="."
 check(get_goal(w,"cargo").floor==4 and get_goal(w,"cargo").position==Vector2i(-1,-1),"cargo public sign reveals destination floor but not unseen grid")
 # True no-skill route supplies real won/continuation state.
 var proof=G.generate(1,W.MAPS).validation
 for c in proof.route:check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"actual route reaches chapter pause")
 check(w.won and get_goal(w,"cargo").missing.contains("continue"),"K pause explicitly blocks ordinary collection until continuation")
 check(w.action("expedition") and get_goal(w,"cargo").missing.contains("collect"),"continued chapter unlocks accurate crown collection guidance")
 w.won=true;check(w.exploration_goals().is_empty(),"final won has no misleading executable collection targets")
 # Tooltip uses forecast needed for victory, not impossible actual overkill HP loss.
 for mode in ["safe","risk"]:
  w=W.new(0,2,"exploration_test_0001",mode)
  for c in "DRDDDLDDRRRRRRRRDDLLLLUULL":check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"genuine lethal encounter route")
  var before=w.save_data().duplicate(true);var lines=" ".join(w.tooltip_data(w.pos+Vector2i.LEFT).lines)
  check(lines.contains("Damage required to defeat") and lines.contains("current HP: 268") and not lines.contains("Predicted loss: 408"),"lethal forecast distinguished from actual fatal prefix")
  check(lines.contains("separate confirmed attempt") if mode=="risk" else lines.contains("Lethal battle is blocked"),"tooltip accurately distinguishes safe refusal and confirmed risk")
  check(w.save_data()==before,"tooltip never performs battle")
 # Controlled existing mechanism state, never invoke choice during a tooltip query.
 w=W.new(0);w.floors.append_array(E.generate(0).maps);w.floor_index=6;w.expedition_revision=3
 var point=Vector2i(7,4)
 check(" ".join(w.tooltip_data(point).lines).contains("either"),"unused guarded winch explains two currently available choices")
 w.floors[6][2][9]="."
 check(" ".join(w.tooltip_data(point).lines).contains("no longer needs"),"dead gaoler removes obsolete rescue option from tooltip")
 w.winch_choice="armory"
 check(not " ".join(w.tooltip_data(point).lines).contains("unused winch"),"selected winch reports current state rather than fresh choices")
 print("EXPLORATION: %d checks, failures=%d"%[checks,failures]);quit(1 if failures else 0)
