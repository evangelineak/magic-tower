extends SceneTree
const P = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+message)
func fight(attack:=18, defense:=8, hp:=360, hero:="warden", skill:=false, gear:="balanced", talents: Array=[], enemy: Dictionary={"name":"Mossling","hp":35,"atk":14,"def":3}) -> Dictionary:
	return P.battle(attack,defense,hp,enemy,hero,skill,gear,talents)
func _init():
	check(P.HEROES.size()==3 and P.GEAR.size()==4,"three archetypes and exclusive gear loadouts")
	check(P.FOCUS_START==2 and P.FOCUS_MAX==3,"finite focus defaults")
	var b=fight()
	check(b.valid and b.survivable and b.damage==12 and b.hit==15 and b.rounds==3,"baseline equals original deterministic formula")
	check(not b.skill_consumed and b.heal_after==0,"baseline no hidden resource effects")
	for hero in P.HEROES:
		check(fight(18,8,360,hero).damage==12,"archetypes preserve baseline witness without skills")
	b=fight(18,8,360,"warden",true)
	check(b.damage==8 and b.blocked_damage==4 and b.skill_consumed,"brace floors35percent of total12 loss to4 blocked")
	b=fight(18,8,360,"ranger",true)
	check(b.enemy_def==0 and b.hit==18 and b.damage==6 and b.skill_consumed,"precision cannot drive defense below zero")
	b=fight(18,8,360,"scholar",true)
	check(b.damage==12 and not b.skill_consumed,"scholar combat toggle cannot heal or consume focus")
	check(P.mend_heal([])==80 and P.mend_heal(["iron_skin","trained_focus"])==100,"scholar healing explicit and talent-aware")
	b=fight(3)
	check(not b.valid and b.damage==-1 and b.rounds==0,"zero-hit damage impossible")
	check(not fight(3,8,360,"warden",true).skill_consumed,"impossible battle never consumes focus")
	check(fight(3,8,360,"ranger",true).valid,"precision may unlock an armored enemy")
	b=fight(18,8,12)
	check(b.valid and not b.survivable and b.damage==12,"exact HP loss is lethal")
	b=fight(18,8,6,"ranger",true)
	check(not b.survivable and not b.skill_consumed,"lethal skill preview is free")
	b=fight(18,8,360,"warden",false,"buckler")
	check(b.effective_atk==14 and b.effective_def==14 and b.damage==0,"buckler trades attack for defense")
	b=fight(18,8,360,"warden",false,"duelist")
	check(b.effective_atk==24 and b.effective_def==5 and b.enemy_def==0 and b.damage==18 and b.feint_damage==9,"duelist armor feint has an extra counter cost")
	check(fight(18,0,360,"warden",false,"duelist").effective_def==0,"negative effective defense is clamped")
	check(not fight(3,8,360,"warden",false,"buckler").valid,"equipment can make formerly possible battles impossible")
	check(fight(18,8,360,"warden",false,"balanced",["iron_skin"]).damage==8,"flat defense applied once")
	check(fight(18,8,360,"warden",false,"balanced",["keen_edge"]).damage==6,"flat attack applied once")
	check(fight(18,14,360,"warden",false,"balanced",["clean_finish"]).heal_after==15,"zero-loss victory grants clean finish once")
	check(fight(18,8,360,"warden",false,"balanced",["clean_finish"]).heal_after==0,"taking damage disables clean finish")
	var giant={"name":"Vault Colossus","hp":180,"atk":100,"def":65}
	b=fight(80,8,199,"warden",false,"balanced",["keen_edge","last_stand","giant_slayer"],giant)
	check(b.hit==23,"percent bonuses add then floor once: floor((83-65)*1.30)=23")
	check(fight(80,8,200,"warden",false,"balanced",["keen_edge","last_stand","giant_slayer"],giant).hit==19,"last stand is strictly below 200 HP")
	check(fight(18,8,199,"warden",false,"balanced",["iron_skin","last_stand","giant_slayer"]).hit==18,"giant bonus requires at least180 enemy HP")
	var sentinel={"name":"Sentinel","hp":75,"atk":25,"def":10}
	check(fight(30,8,360,"warden",false,"balanced",["iron_skin","sentinel_lore"],sentinel).effective_def==14,"lore applies against sentinel")
	check(fight(30,8,360,"warden",false,"balanced",["iron_skin","sentinel_lore"]).effective_def==10,"lore not applied to other enemies")
	b=fight(30,8,360,"warden",true,"balanced",["keen_edge","trained_focus"],sentinel)
	check(b.damage==29 and b.blocked_damage==22,"trained brace blocks floor(51x45percent)=22")
	b=fight(70,8,360,"ranger",true,"balanced",["iron_skin","trained_focus"],giant)
	check(b.enemy_def==51 and b.hit==19,"trained precision ignores14 defense")
	b=fight(18,14,360,"warden",true,"balanced",["clean_finish","trained_focus","battle_medic"])
	check(b.heal_after==25,"clean finish and battle medic add after surviving victory")
	b=fight(18,8,12,"warden",false,"balanced",["clean_finish","trained_focus","battle_medic"])
	check(not b.survivable and b.heal_after==0,"post-fight healing cannot rescue lethal outcome")
	check(fight(30,8,400,"warden",false,"balanced",["keen_edge","trained_focus","unbroken"],sentinel).damage==31,"unbroken works at400 HP")
	check(fight(30,8,399,"warden",false,"balanced",["keen_edge","trained_focus","unbroken"],sentinel).damage==51,"unbroken disabled below400 HP")
	check(P.valid_talents([]),"empty talents valid")
	check(P.valid_talents(["iron_skin","last_stand","unbroken"]),"one talent per tier valid")
	for invalid in [["last_stand"],["iron_skin","keen_edge"],["iron_skin","last_stand","unbroken","battle_medic"],[123],["unknown"]]:
		check(not P.valid_talents(invalid),"invalid talent selection rejected")
	check(P.talent_options(2,[]).is_empty(),"no early offer")
	check(P.talent_options(3,[])==P.TALENT_TIERS[0].choices,"tier1 at3 kills")
	check(P.talent_options(6,["iron_skin"]).is_empty(),"tier2 waits for7")
	check(P.talent_options(7,["iron_skin"])==P.TALENT_TIERS[1].choices,"tier2 at7 kills")
	check(P.talent_options(12,["iron_skin","last_stand"])==P.TALENT_TIERS[2].choices,"tier3 at12 kills")
	check(P.talent_options(99,["iron_skin","last_stand","unbroken"]).is_empty(),"no repeated tier3")
	check(P.talent_options(99,["invalid"]).is_empty(),"invalid saved choices do not offer a new tier")
	var options=P.talent_options(3,[])
	options.clear()
	check(P.TALENT_TIERS[0].choices.size()==3,"returned options cannot mutate constant choices")
	for invalid_enemy in [{},{"hp":0,"atk":1,"def":0},{"hp":10,"atk":-1,"def":0},{"hp":10,"atk":1,"def":0.5},{"hp":"ten","atk":1,"def":0}]:
		check(not fight(18,8,360,"warden",false,"balanced",[],invalid_enemy).valid,"malformed enemy fails safely")
	check(not fight(18,8,360,"invalid").valid,"invalid hero rejected")
	check(not fight(18,8,360,"warden",false,"invalid").valid,"invalid equipment rejected")
	var original_enemy=sentinel.duplicate(true)
	var original_talents=["keen_edge","trained_focus","battle_medic"]
	P.battle(30,8,360,sentinel,"ranger",true,"buckler",original_talents)
	check(sentinel==original_enemy and original_talents==["keen_edge","trained_focus","battle_medic"],"pure battle leaves caller-owned data unchanged")
	var ambush={"name":"Ambusher","hp":35,"atk":14,"def":3,"first_strike":true}
	b=fight(99,8,360,"warden",false,"balanced",[],ambush)
	check(b.rounds==1 and b.normal_damage==0 and b.first_strike_damage==6 and b.damage==6,"one-shot ambusher still strikes first")
	check(b.thorns_damage==0 and b.blocked_damage==0,"absent thorns and mitigation add nothing")
	b=fight(18,8,360,"warden",false,"balanced",[],ambush)
	check(b.normal_damage==12 and b.first_strike_damage==6 and b.damage==18,"ambush adds one defense-adjusted hit")
	check(fight(99,14,360,"warden",false,"balanced",[],ambush).first_strike_damage==0,"defense blocks ambush normally")
	check(not fight(99,8,6,"warden",false,"balanced",[],ambush).survivable,"opening first strike can be lethal even with one-shot hero")
	var thorn={"name":"Thorn guard","hp":35,"atk":14,"def":3,"thorns":4}
	b=fight(99,99,360,"warden",false,"balanced",[],thorn)
	check(b.rounds==1 and b.normal_damage==0 and b.thorns_damage==4 and b.damage==4,"killing attack reflects thorns even through high defense")
	b=fight(18,8,360,"warden",false,"balanced",[],thorn)
	check(b.rounds==3 and b.normal_damage==12 and b.thorns_damage==12 and b.damage==24,"thorns applies to all3 attacks")
	b=fight(18,8,360,"ranger",true,"balanced",[],thorn)
	check(b.rounds==2 and b.normal_damage==6 and b.thorns_damage==8 and b.damage==14,"precision reduces retaliation and reflection by shortening battle")
	var combined={"name":"Briar ambusher","hp":35,"atk":14,"def":3,"first_strike":true,"thorns":5}
	b=fight(18,8,360,"warden",true,"balanced",[],combined)
	check(b.normal_damage==12 and b.first_strike_damage==6 and b.thorns_damage==15 and b.damage==22 and b.blocked_damage==11,"brace blocks floor(33x35percent)=11 across all components")
	b=fight(18,8,360,"warden",true,"balanced",["clean_finish","trained_focus"],combined)
	check(b.damage==19 and b.blocked_damage==14 and b.heal_after==0,"trained brace cannot turn positive loss into a clean finish by itself")
	b=fight(18,8,400,"warden",false,"balanced",["clean_finish","trained_focus","unbroken"],combined)
	check(b.damage==13 and b.blocked_damage==20,"unbroken mitigates complete damage sum")
	b=fight(18,8,400,"warden",true,"balanced",["clean_finish","trained_focus","unbroken"],combined)
	check(b.damage==0 and b.blocked_damage==33,"multiple total mitigations cannot over-block")
	b=fight(18,8,33,"warden",false,"balanced",["clean_finish","trained_focus","battle_medic"],combined)
	check(not b.survivable and b.heal_after==0,"post-heal cannot rescue combined thorn and ambush lethal loss")
	check(not fight(3,8,360,"warden",true,"balanced",[],combined).skill_consumed,"unbreakable thorn enemy costs no focus when blocked")
	var rounded={"name":"Briar giant","hp":180,"atk":14,"def":3,"thorns":2,"first_strike":true}
	b=fight(18,8,199,"warden",false,"balanced",["clean_finish","last_stand","giant_slayer"],rounded)
	check(b.hit==19 and b.rounds==10 and b.thorns_damage==20 and b.normal_damage==54 and b.first_strike_damage==6 and b.damage==80,"percentage rounding precedes round-count and thorns calculation")
	var combined_original=combined.duplicate(true)
	P.battle(18,8,360,combined,"ranger",true,"buckler",[])
	check(combined==combined_original,"special enemy traits remain unchanged by preview")
	for invalid_trait in [{"first_strike":1},{"first_strike":"true"},{"thorns":-1},{"thorns":1.5},{"thorns":true},{"thorns":"2"}]:
		var bad=thorn.duplicate(true)
		bad.merge(invalid_trait,true)
		check(not fight(18,8,360,"warden",false,"balanced",[],bad).valid,"invalid optional enemy trait rejected")
	check(P.brace_percent([])==35 and P.brace_percent(["iron_skin","trained_focus"])==45,"brace rates follow trained focus")
	check("35%" in P.skill_description("warden",[]) and "45%" in P.skill_description("warden",["iron_skin","trained_focus"]),"UI description shares brace percentage values")
	check("10 enemy DEF" in P.skill_description("ranger",[]) and "14 enemy DEF" in P.skill_description("ranger",["iron_skin","trained_focus"]),"UI description follows precision upgrade")
	check("80 HP" in P.skill_description("scholar",[]) and "100 HP" in P.skill_description("scholar",["iron_skin","trained_focus"]),"scholar heal stays80 or100")
	check(P.skill_description("unknown",[])=="Unknown hero.","unknown description fails clearly")
	for raw in [0,1,2,3,19,20,99,100,1000]:
		var incoming={"name":"Shield test","hp":1,"atk":raw+8,"def":0,"first_strike":true}
		b=fight(18,8,2000,"warden",true,"balanced",[],incoming)
		var expected_block=int(floor(float(raw*35)/100.0))
		check(b.damage==raw-expected_block and b.blocked_damage==expected_block,"35percent exact rounding for raw%d"%raw)
		b=fight(18,8,2000,"warden",true,"balanced",["clean_finish","trained_focus"],incoming)
		expected_block=int(floor(float(raw*45)/100.0))
		check(b.damage==raw-expected_block and b.blocked_damage==expected_block,"45percent exact rounding for raw%d"%raw)
	var ordering={"name":"Shield order","hp":1,"atk":108,"def":0,"first_strike":true}
	b=fight(18,8,400,"warden",true,"balanced",["clean_finish","sentinel_lore","unbroken"],ordering)
	check(b.damage==45 and b.blocked_damage==55,"35percent of100 blocked BEFORE flat20 unbroken")
	b=fight(18,8,400,"warden",true,"balanced",["clean_finish","trained_focus","unbroken"],ordering)
	check(b.damage==35 and b.blocked_damage==65,"45percent of100 blocked BEFORE flat20 unbroken")
	# v0.8: equipment changes attack order rather than silently multiplying stats.
	var easy={"name":"Easy target","hp":10,"atk":25,"def":0}
	var balanced_easy=fight(30,20,360,"warden",false,"balanced",[],easy)
	var duelist_easy=fight(30,20,360,"warden",false,"duelist",[],easy)
	check(balanced_easy.damage==0 and duelist_easy.damage==8 and duelist_easy.rounds==1 and duelist_easy.retaliations==1,"duelist really loses8 HP on an otherwise free one-shot")
	check(duelist_easy.normal_damage==0 and duelist_easy.feint_damage==8,"one-shot feint not double-counted as normal damage")
	var balanced_hard=fight(73,24,3000,"warden",false,"balanced",[],giant)
	var duelist_hard=fight(73,24,3000,"warden",false,"duelist",[],giant)
	check(balanced_hard.damage==1672 and duelist_hard.damage==711,"duelist also has a real high-armor win, not merely a penalty")
	check(duelist_hard.enemy_def==57 and duelist_hard.normal_damage==632 and duelist_hard.feint_damage==79,"feint armor break and cost separately exposed")
	b=fight(60,24,3000,"ranger",true,"duelist",["iron_skin","trained_focus"],giant)
	check(b.enemy_def==43 and b.hit==23,"trained precision14 and feint8 add without percentage stacking")
	b=fight(18,8,360,"ranger",true,"duelist",["iron_skin","trained_focus"],easy)
	check(b.enemy_def==0,"combined armor breaks never create negative armor")
	var no_break={"name":"Unbreakable","hp":10,"atk":25,"def":100}
	b=fight(1,8,360,"warden",true,"duelist",[],no_break)
	check(not b.valid and b.damage==-1 and b.feint_damage==0 and b.retaliations==0 and not b.skill_consumed,"unbreakable preview never executes feint or consumes skill")
	b=fight(99,8,360,"warden",false,"buckler",[],ambush)
	check(b.rounds==1 and b.first_strike_damage==0 and b.equipment_blocked==0,"zero-damage first strike does not invent a shield benefit")
	var shield_ambush={"name":"Shielded ambush","hp":10,"atk":30,"def":0,"first_strike":true,"thorns":7}
	b=fight(99,8,360,"warden",false,"buckler",[],shield_ambush)
	check(b.first_strike_damage==16 and b.equipment_blocked==16 and b.thorns_damage==7 and b.damage==7,"buckler intercepts ambush even on one-shot but leaves thorns intact")
	var shield_normal={"name":"Shielded counter","hp":30,"atk":30,"def":0,"thorns":7}
	b=fight(18,8,360,"warden",false,"buckler",[],shield_normal)
	check(b.rounds==3 and b.normal_damage==32 and b.equipment_blocked==16 and b.thorns_damage==21 and b.damage==37,"buckler blocks exactly one ordinary counter, never repeated hits or thorns")
	var one_shot_thorn={"name":"Single thorn","hp":1,"atk":30,"def":0,"thorns":7}
	b=fight(99,8,360,"warden",false,"buckler",[],one_shot_thorn)
	check(b.equipment_blocked==0 and b.damage==7,"no enemy attack means no equipment block to spend on thorns")
	b=fight(99,8,360,"warden",false,"duelist",[],one_shot_thorn)
	check(b.feint_damage==25 and b.thorns_damage==7 and b.damage==32,"feint adds one counter but no extra contact or thorn proc")
	var heavy={"name":"Clockwork Mauler","hp":180,"atk":32,"def":20,"heavy_every":3}
	check(fight(43,20,360,"warden",false,"balanced",[],heavy).damage==108,"authored example balanced loses108")
	check(fight(43,20,360,"warden",false,"buckler",[],heavy).damage==66,"authored example buckler loses66")
	check(fight(43,20,360,"warden",false,"duelist",[],heavy).damage==90,"authored example duelist loses90")
	for count in [0,1,2,3,4,5,6,9]:
		var paced={"name":"Paced attacker","hp":count+1,"atk":10,"def":0,"heavy_every":3}
		b=fight(1,0,1000,"warden",false,"balanced",[],paced)
		check(b.retaliations==count and b.normal_damage==count*10 and b.charged_damage==floori(float(count)/3.0)*10,"third-counter thresholds at %d"%count)
		paced.first_strike=true
		var with_ambush=fight(1,0,1000,"warden",false,"balanced",[],paced)
		check(with_ambush.charged_damage==b.charged_damage and with_ambush.first_strike_damage==10,"first strike never advances heavy counter at %d"%count)
	var feint_threshold={"name":"Feint threshold","hp":3,"atk":10,"def":6,"heavy_every":3}
	b=fight(1,0,1000,"warden",false,"duelist",[],feint_threshold)
	check(b.rounds==1 and b.retaliations==1 and b.charged_damage==0,"one-shot feint counter alone cannot trigger third-counter strike")
	# Effective ATK=7, enemy DEF after feint=6, so three damaging hits.
	feint_threshold.def=14
	b=fight(1,0,1000,"warden",false,"duelist",[],feint_threshold)
	check(b.rounds==3 and b.retaliations==3 and b.normal_damage==20 and b.feint_damage==10 and b.charged_damage==10 and b.damage==40,"feint advances a two-counter fight across the third-counter threshold")
	var shield_threshold={"name":"Shield threshold","hp":4,"atk":10,"def":0,"heavy_every":3}
	b=fight(5,0,1000,"warden",false,"buckler",[],shield_threshold)
	check(b.rounds==4 and b.retaliations==3 and b.charged_damage==4 and b.equipment_blocked==4 and b.damage==12,"blocking retaliation1 does not delay charged retaliation3")
	var shield_order={"name":"Shield order2","hp":4,"atk":106,"def":0,"heavy_every":3,"first_strike":true,"thorns":5}
	b=fight(5,0,400,"warden",true,"buckler",["clean_finish","trained_focus","unbroken"],shield_order)
	# 300 normal +100 charge +100 ambush +20 thorns =520. Shield100,
	# then Brace floor(420*.45)=189, then Unbroken20 =>211.
	check(b.normal_damage==300 and b.charged_damage==100 and b.first_strike_damage==100 and b.thorns_damage==20,"five damage components exposed before mitigation")
	check(b.equipment_blocked==100 and b.blocked_damage==309 and b.damage==211,"equipment then percentage then flat shield ordering exact")
	check(b.damage==b.normal_damage+b.feint_damage+b.charged_damage+b.first_strike_damage+b.thorns_damage-b.blocked_damage,"component accounting exactly equals final loss")
	b=fight(30,20,8,"warden",false,"duelist",["clean_finish","trained_focus","battle_medic"],easy)
	check(not b.survivable and b.heal_after==0,"a lethal opening feint cannot be rescued by victory healing")
	var high_def_heavy={"name":"Harmless Mauler","hp":100,"atk":10,"def":0,"heavy_every":3,"thorns":2}
	b=fight(18,50,360,"warden",false,"balanced",[],high_def_heavy)
	check(b.charged_damage==0 and b.normal_damage==0 and b.damage==b.thorns_damage,"heavy doubles post-defense loss, never bypasses high defense")
	for invalid_period in [0,1,2,4,-3,3.5,true,"3",null,INF,NAN]:
		var invalid_heavy=heavy.duplicate(true)
		invalid_heavy.heavy_every=invalid_period
		check(not fight(43,20,360,"warden",false,"balanced",[],invalid_heavy).valid,"invalid heavy_every value rejected")
	var json_heavy:Dictionary=JSON.parse_string(JSON.stringify(heavy))
	check(fight(43,20,360,"warden",false,"balanced",[],json_heavy).damage==108,"JSON float3 retains valid heavy-period semantics")
	var pure_enemy=shield_order.duplicate(true)
	var pure_talents=["clean_finish","trained_focus","unbroken"]
	var first=P.battle(5,0,400,pure_enemy,"warden",true,"buckler",pure_talents)
	var second=P.battle(5,0,400,pure_enemy,"warden",true,"buckler",pure_talents)
	check(first==second and pure_enemy==shield_order and pure_talents==["clean_finish","trained_focus","unbroken"],"repeated equipment previews are stateless and cannot refresh resources")
	check("EXTRA" in P.GEAR.duelist.description and "one-shot" in P.GEAR.duelist.description,"duelist opening cost is prominent in shared item description")
	var ferry={"hp":180,"atk":62,"def":30,"first_strike":true}
	b=fight(103,36,500,"warden",false,"repeater",[],ferry)
	check(b.damage==32 and b.rounds==3 and b.retaliations==0 and b.first_strike_damage==32,"repeater opening three hits still pay enemy first strike")
	check(b.damage<fight(103,36,500,"warden",false,"buckler",[],ferry).damage,"repeater beats buckler at a real ferry threshold")
	var castellan={"hp":720,"atk":65,"def":45}
	b=fight(103,36,1000,"warden",false,"repeater",[],castellan)
	check(b.damage==385 and b.retaliations==11 and b.damage>fight(103,36,1000,"warden",false,"balanced",[],castellan).damage,"repeater loses to baseline in a long boss battle")
	var combo={"hp":50,"atk":20,"def":0,"first_strike":true,"thorns":3,"heavy_every":3}
	b=fight(13,16,500,"warden",false,"repeater",[],combo)
	check(b.rounds==5 and b.retaliations==2 and b.normal_damage==20 and b.first_strike_damage==10 and b.thorns_damage==15 and b.charged_damage==0 and b.damage==45,"opening volley does not waive thorns or ambush; heavy counts only actual counters")
	combo.hp=60
	b=fight(13,16,500,"warden",false,"repeater",[],combo)
	check(b.retaliations==3 and b.charged_damage==10 and b.damage==68,"sixth shot reaches third counter and heavy threshold")
	check(fight(13,16,500,"warden",true,"repeater",[],combo).damage==45,"brace floors block after all repeater components")
	check(fight(13,16,68,"warden",false,"repeater",["iron_skin","trained_focus","battle_medic"],combo).survivable,"gear combines with existing valid talent tiers")
	b=fight(13,16,68,"warden",false,"repeater",["clean_finish","trained_focus","battle_medic"],combo)
	check(b.damage==68 and not b.survivable and b.heal_after==0,"repeater lethal loss cannot be rescued by post-battle healing")
	combo.hp=10
	b=fight(13,16,500,"ranger",true,"repeater",[],combo)
	check(b.rounds==1 and b.damage==13 and b.retaliations==0,"one-shot volley pays one thorn trigger and first strike, not three shots")
	check(not fight(3,16,500,"warden",false,"repeater",[],combo).valid,"repeater attack penalty can prevent breaking armor")
	var immutable=combo.duplicate(true)
	check(fight(13,16,500,"warden",false,"repeater",[],combo)==fight(13,16,500,"warden",false,"repeater",[],combo) and combo==immutable,"repeater preview is pure and charges never persist")
	print("PROGRESSION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
