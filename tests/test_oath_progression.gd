extends SceneTree
const P=preload("res://scripts/progression.gd")
const W=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func _init():
 for c in [[103,36,"balanced","warden",false,"H",78,52],[103,36,"repeater","warden",false,"H",32,0],[103,36,"balanced","warden",true,"W",124,137],[103,36,"buckler","ranger",true,"W",134,148],[103,36,"balanced","warden",false,"Z",348,406],[103,36,"repeater","warden",false,"Z",385,455],[88,32,"duelist","ranger",true,"W",264,249],[103,36,"buckler","warden",false,"H",40,40]]:
  var before=P.battle(c[0],c[1],1000,W.ENEMIES[c[5]],c[3],c[4],c[2],[])
  var after=P.battle(c[0],c[1],1000,W.ENEMIES[c[5]],c[3],c[4],c[2],[],"watch")
  check(before.damage==c[6] and after.damage==c[7],"measured favorable/unfavorable oath threshold: "+str(c))
  check(after.effective_atk==maxi(0,before.effective_atk-10),"flat attack cost applied once")
  var raw=after.normal_damage+after.feint_damage+after.charged_damage+after.first_strike_damage+after.thorns_damage
  check(raw-after.blocked_damage==after.damage,"raw breakdown includes oath in total reduction exactly once")
 var enemy={"hp":30,"atk":20,"def":0,"first_strike":true,"thorns":3,"heavy_every":3}
 var saved=enemy.duplicate(true)
 var b=P.battle(20,10,100,enemy,"warden",false,"balanced",[],"watch")
 check(b.rounds==3 and b.damage==23 and b.oath_blocked==16,"odd thorns rounds each trigger down: 3 becomes 1; ambush canceled")
 b=P.battle(20,10,100,enemy,"warden",true,"balanced",[],"watch")
 check(b.damage==15 and b.blocked_damage==24,"brace applies after oath, floor(23*35%)=8")
 b=P.battle(30,10,100,enemy,"warden",false,"buckler",[],"watch")
 check(b.rounds==2 and b.equipment_blocked==4 and b.damage==2,"shield moves to first actual ordinary counter after suppressed ambush")
 b=P.battle(60,10,100,enemy,"warden",false,"buckler",[],"watch")
 check(b.rounds==1 and b.equipment_blocked==0 and b.damage==1,"one-shot plus oath leaves no actual enemy swing for shield")
 check(not P.battle(10,10,100,enemy,"warden",false,"balanced",[],"watch").valid,"oath can prevent breaking armor")
 check(not P.battle(20,10,100,enemy,"warden",false,"balanced",[],"unknown").valid,"unknown oath rejected")
 b=P.battle(20,10,23,enemy,"warden",false,"balanced",["clean_finish","trained_focus","battle_medic"],"watch")
 check(b.damage==23 and not b.survivable and b.heal_after==0,"oath does not let post-heal rescue lethal damage")
 check(enemy==saved,"all oath previews leave enemy dictionary unchanged")
 var normal=P.battle(20,10,100,enemy,"warden",false,"balanced",[])
 check(normal==P.battle(20,10,100,enemy,"warden",false,"balanced",[],"none"),"default none preserves old calls exactly")
 print("OATH PROGRESSION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
