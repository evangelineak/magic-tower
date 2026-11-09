extends SceneTree
const P=preload("res://scripts/progression.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func _init():
 var gaoler={"hp":260,"atk":68,"def":48,"thorns":6,"heavy_every":3}
 var ferry={"hp":180,"atk":62,"def":30,"first_strike":true}
 var boss={"hp":720,"atk":65,"def":45}
 for c in [[103,36,gaoler,false,"warden",198,3,4],[103,36,gaoler,true,"ranger",84,2,2],[103,36,gaoler,true,"warden",129,3,4],[115,44,gaoler,false,"warden",68,2,2],[103,36,ferry,false,"warden",90,2,2],[103,36,boss,false,"warden",396,7,12]]:
  var p=P.battle(c[0],c[1],1000,c[2],c[4],c[3],"maul",[])
  check(p.valid and p.damage==c[5] and p.rounds==c[6] and p.retaliations==c[7],"measured maul hero/enemy thresholds")
  check(p.attack_multiplier==2 and p.retaliations_per_hit==2 and p.feint_damage==0,"double counters are normal attacks, not extra opening hits")
 var p=P.battle(103,36,1000,gaoler,"ranger",true,"maul",[])
 check(p.damage<P.battle(103,36,1000,gaoler,"ranger",true,"repeater",[]).damage,"precision maul beats repeater against gaoler")
 check(P.battle(103,36,1000,boss,"warden",false,"maul",[]).damage>P.battle(103,36,1000,boss,"warden",false,"balanced",[]).damage,"defense cost is real against long boss")
 var tiny={"hp":14,"atk":20,"def":0,"first_strike":true,"thorns":3,"heavy_every":3}
 p=P.battle(7,10,100,tiny,"warden",false,"maul",[])
 check(p.hit==14 and p.rounds==1 and p.retaliations==0 and p.first_strike_damage==14 and p.thorns_damage==3 and p.damage==17,"one killing heavy strike triggers ambush and one thorn, no doubled counter")
 var long_enemy={"hp":70,"atk":20,"def":0,"thorns":3,"heavy_every":3}
 p=P.battle(10,10,100,long_enemy,"warden",false,"maul",[])
 check(p.rounds==4 and p.retaliations==6 and p.charged_damage==28 and p.normal_damage==84 and p.thorns_damage==12 and p.damage==124,"heavy cadence counts six actual counters and four player thorn triggers")
 var percent_enemy={"hp":180,"atk":0,"def":0}
 p=P.battle(7,10,100,percent_enemy,"warden",false,"maul",["clean_finish","last_stand","giant_slayer"])
 check(p.hit==18,"floor(7*1.3) then double yields18, not floor(14*1.3)")
 check(not P.battle(10,10,100,{"hp":10,"atk":10,"def":10},"warden",false,"maul",[]).valid,"doubling cannot bypass unbroken armor")
 for gear in P.GEAR:
  p=P.battle(103,36,1000,ferry,"warden",false,gear,[],"none",true)
  check(p.first_strike_suppressed and p.first_strike_suppression=="flank" and p.flank_blocked==p.first_strike_damage,"flank suppresses ambush for every loadout")
  check(p.normal_damage+p.feint_damage+p.charged_damage+p.first_strike_damage+p.thorns_damage-p.blocked_damage==p.damage,"flank included in total reduction exactly once")
 p=P.battle(30,10,100,tiny,"warden",false,"buckler",[],"watch",true)
 check(p.rounds==1 and p.flank_blocked==4 and p.oath_blocked==2 and p.equipment_blocked==0 and p.damage==1,"oath plus flank share ambush once and shield does not block a nonexistent swing")
 p=P.battle(20,10,100,{"hp":30,"atk":20,"def":0,"first_strike":true,"thorns":3},"warden",true,"balanced",[],"watch",true)
 check(p.damage==15 and p.flank_blocked==10 and p.oath_blocked==6,"brace applies after disjoint flank and oath reductions")
 var snapshot=gaoler.duplicate(true)
 var a=P.battle(103,36,1000,gaoler,"ranger",true,"maul",[],"none",false)
 check(a==P.battle(103,36,1000,gaoler,"ranger",true,"maul",[]) and snapshot==gaoler,"default flank preserves pure preview")
 print("MAUL: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
