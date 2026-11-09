extends SceneTree
const A=preload("res://scripts/attunement.gd")
const P=preload("res://scripts/progression.gd")
const ENEMIES={"H":{"hp":180,"atk":62,"def":30,"first_strike":true},"W":{"hp":260,"atk":68,"def":48,"thorns":6,"heavy_every":3},"Z":{"hp":720,"atk":65,"def":45}}
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok: failures+=1; push_error(label)
func _init():
 check(A.TEMPLATE_IDS.size()==6 and A.GEAR_IDS.size()==P.GEAR.size(),"six templates and all five current equipment IDs")
 var unique_sets={}; var offered={}
 for run_seed in range(100):
  for gear in A.GEAR_IDS:
   var options=A.offers(run_seed,gear)
   check(A.valid_offers(options) and options==A.offers(run_seed,gear),"fixed seed and gear offer three unique reproducible candidates")
   check(A.valid_selection(options,"none"),"original equipment is always available without attunement")
   var sorted=options.duplicate(); sorted.sort(); unique_sets[str(sorted)]=true
   for id in options:
    offered[id]=true
    check(A.valid_selection(options,id),"every offered ID can be selected")
   check(A.valid_offers(JSON.parse_string(JSON.stringify(options))),"saved actual offers survive JSON without reroll")
 check(unique_sets.size()>1 and offered.size()==6,"sampling changes combinations, not merely presentation order")
 check(A.offers(0,"balanced")==["guard_deep","edge_deep","focus_light"],"revision-one deterministic sampling fixture")
 check(A.offers(0,"maul")==["edge_deep","guard_deep","focus_deep"],"gear identity changes the deterministic draft")
 for invalid_seed in [-1,2147483648,9223372036854775807]:check(A.offers(invalid_seed,"balanced").is_empty(),"out-of-range seed rejected before arithmetic")
 check(A.offers(0,"unknown").is_empty(),"unknown equipment has no draft")
 for invalid in [null,true,1,"none",[],["none","edge_light","guard_light"],["focus_light","focus_light","guard_light"],["focus_light","unknown","guard_light"],["focus_light","guard_light"]]:check(not A.valid_offers(invalid),"malformed offers rejected")
 check(not A.valid_selection(["focus_light","edge_light","guard_light"],"focus_deep"),"cannot select an unoffered template")
 for invalid in [null,true,3,[],"unknown"]:check(not A.valid_id(invalid),"invalid choice identifier rejected")
 var options=A.offers(0,"balanced"); options[0]="unknown"
 check(A.offers(0,"balanced")[0]=="guard_deep","returned offers cannot mutate the catalog")
 var modifiers=A.modifiers("edge_deep"); modifiers.atk=999
 check(A.modifiers("edge_deep").atk==6,"returned modifiers are isolated")
 seed(919); var first=randi(); A.offers(42,"maul"); var following=randi()
 seed(919); check(randi()==first and randi()==following,"draft sampling never consumes the global random stream")
 var trained=["clean_finish","trained_focus"]
 check(P.skill_level([])==10 and P.skill_level(trained)==14,"old base and trained skill levels")
 check(P.brace_percent([])==35 and P.brace_percent(trained)==45,"old Brace values exactly unchanged")
 check(P.mend_heal([])==80 and P.mend_heal(trained)==100,"old Mend values exactly unchanged")
 check(P.brace_percent([],"focus_light")==37 and P.brace_percent(trained,"focus_light")==47,"half-point Brace percentages round down")
 check(P.mend_heal([],"focus_light")==85 and P.mend_heal([],"focus_deep")==90 and P.mend_heal(trained,"focus_deep")==110,"healing uses current selected attunement")
 check(P.mend_heal([])==80,"switching back to original equipment does not retain a higher healing level")
 check(P.skill_level_info(trained,"focus_deep")=={"base":10,"training":4,"gear":2,"effective":16,"cap":20,"attainable_max":16,"strategy":0,"legacy":0,"raw":16,"overflow":0},"UI receives honest level breakdown and currently reachable maximum")
 var largest=0
 for id in A.TEMPLATE_IDS:
  largest=maxi(largest,P.skill_level(trained,id))
 check(largest==16 and largest<P.SKILL_LEVEL_CAP,"without strategy or legacy study, cap20 is not misrepresented as obtainable")
 var before=P.battle(103,36,1000,ENEMIES.W,"ranger",true,"maul",trained)
 check(before==P.battle(103,36,1000,ENEMIES.W,"ranger",true,"maul",trained,"none",false,"none"),"default optional arguments preserve old behavior")
 var tuned=P.battle(103,36,1000,ENEMIES.W,"ranger",true,"maul",trained,"none",false,"edge_deep")
 check(tuned.effective_atk==109 and tuned.effective_def==27 and tuned.skill_level==14,"one current equipment attunement applies once with equipment penalties")
 check(before==P.battle(103,36,1000,ENEMIES.W,"ranger",true,"maul",trained),"another equipment preview cannot retain the previous attunement")
 check(not P.battle(103,36,1000,ENEMIES.W,"ranger",true,"maul",trained,"none",false,"unknown").valid,"battle rejects unknown attunement")
 var examples=[
 ["focus_light",88,32,"W","repeater","ranger",true,trained,1000,204,118],
 ["focus_deep",88,32,"W","repeater","ranger",true,trained,1000,204,120],
 ["edge_light",88,32,"W","repeater","ranger",true,trained,1000,204,118],
 ["edge_deep",109,36,"W","maul","warden",false,[],1000,198,94],
 ["guard_light",88,32,"Z","maul","warden",false,[],1000,592,560],
 ["guard_deep",103,36,"Z","maul","warden",false,[],1000,396,348],
 ["focus_light",88,32,"Z","buckler","warden",false,[],1000,459,493],
 ["focus_deep",103,36,"Z","maul","warden",false,[],1000,396,432],
 ["edge_light",88,32,"Z","maul","ranger",true,[],1000,444,468],
 ["edge_deep",88,32,"Z","maul","ranger",true,[],1000,444,504],
 ["guard_light",103,36,"W","maul","warden",false,["clean_finish","last_stand"],199,84,188],
 ["guard_deep",103,36,"W","maul","warden",false,["clean_finish","last_stand"],199,84,178]]
 var evidence={}
 for c in examples:
  check(c[4] in ["buckler","duelist","repeater","maul"],"gameplay evidence uses only tunable equipment, never the original traveler kit")
  if not evidence.has(c[0]): evidence[c[0]]={"better":false,"worse":false}
  evidence[c[0]]["better" if c[10]<c[9] else "worse"]=true
  var base=P.battle(c[1],c[2],c[8],ENEMIES[c[3]],c[5],c[6],c[4],c[7])
  var result=P.battle(c[1],c[2],c[8],ENEMIES[c[3]],c[5],c[6],c[4],c[7],"none",false,c[0])
  check(base.damage==c[9] and result.damage==c[10] and base.survivable and result.survivable,"concrete favorable/unfavorable surviving encounter: "+str(c))
 for id in A.TEMPLATE_IDS:
  check(evidence.has(id) and evidence[id].better and evidence[id].worse,"every template has both favorable and unfavorable allowed-equipment evidence")
 var enemy=ENEMIES.H.duplicate(true)
 var saved_enemy=enemy.duplicate(true)
 var talents=["clean_finish","trained_focus","unbroken"]
 for gear in P.GEAR:
  for id in A.TEMPLATE_IDS:
   var result=P.battle(103,36,500,enemy,"warden",true,gear,talents,"watch",true,id)
   check(result.valid and result.first_strike_suppressed and result.first_strike_suppression=="flank","attunement combines with oath and flanking without replacing context")
   var raw=result.normal_damage+result.feint_damage+result.charged_damage+result.first_strike_damage+result.thorns_damage
   check(raw-result.blocked_damage==result.damage,"all equipment/skill/terrain reductions remain exact")
 check(enemy==saved_enemy and talents==["clean_finish","trained_focus","unbroken"],"combined previews do not mutate inputs")
 print("ATTUNEMENT: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
