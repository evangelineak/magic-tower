extends SceneTree
# Fixed event/combat fixtures use legacy coordinates; seeded determinism below stays layout 2.
# Synthetic deep-floor fixtures below explicitly include previously traversed floors.
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+message)
func snapshot(w) -> Dictionary:
	return w.save_data().duplicate(true)
func roundtrip(w, description: String):
	var restored=World.new(0,1)
	check(restored.restore(JSON.parse_string(JSON.stringify(snapshot(w)))) and snapshot(restored)==snapshot(w),description)
func _init():
	for seed_value in [0,1,42,123456]:
		var first=World.new(seed_value)
		var second=World.new(seed_value)
		check(snapshot(first)==snapshot(second),"same seed reproduces complete start %d" % seed_value)
		first.step(Vector2i.RIGHT)
		roundtrip(first,"seeded progress loads without reroll %d" % seed_value)
	var w=World.new(0,1)
	check(w.action("hero_ranger") and w.hero_id=="ranger","select ranger before exploring")
	w.step(Vector2i.RIGHT)
	check(not w.action("hero_scholar") and w.hero_id=="ranger","hero locked after journey starts")
	var focus_before: int=w.focus
	check(w.action("arm") and w.skill_armed,"ranger can prepare skill")
	check(w.focus==focus_before,"arming does not consume focus before a battle")
	var before: Dictionary=snapshot(w)
	for i in range(5): w.damage("g")
	check(snapshot(w)==before,"repeated preview cannot consume skill or change world")
	w.pos=Vector2i(1,1)
	check(not w.step(Vector2i.UP) and w.skill_armed and w.focus==focus_before,"wall does not spend skill")
	w.floor_seen=[true,true,true,false,false]; w.enter_floor(2); w.pos=Vector2i(7,3); focus_before=w.focus
	check(not w.step(Vector2i.RIGHT) and w.skill_armed and w.focus==focus_before,"impossible fight does not spend skill")
	w=World.new(0,1); w.action("hero_warden"); w.action("arm"); w.pos=Vector2i(5,3)
	var hp_before: int=w.hp
	focus_before=w.focus
	var predicted: int=w.damage("s")
	check(w.step(Vector2i.LEFT) and w.hp==hp_before-predicted,"actual armed battle exactly matches preview")
	check(w.focus==focus_before-1 and not w.skill_armed and w.kills==1,"successful battle consumes skill once and counts kill")
	roundtrip(w,"combat state survives JSON")
	w=World.new(0,1); w.action("hero_scholar"); hp_before=w.hp; focus_before=w.focus
	check(w.action("mend") and w.hp==hp_before+80 and w.focus==focus_before-1,"scholar heals at known focus cost")
	w.focus=0; before=snapshot(w)
	check(not w.action("mend") and snapshot(w)==before,"empty focus cannot heal")
	w=World.new(0,1)
	check(not w.action("talent_keen_edge"),"talent cannot unlock before kills")
	w.kills=3
	check(w.action("talent_keen_edge") and "keen_edge" in w.talents,"first talent unlocks at three kills")
	check(not w.action("talent_iron_skin"),"same-tier talent choices exclusive")
	check(not w.action("equip_duelist"),"unowned equipment unavailable")
	# Water is a spatial choice, not an elemental damage multiplier.
	w=World.new(0,1); w.enter_floor(1); w.pos=Vector2i(7,3)
	check(not w.step(Vector2i.UP),"flooded alcove is blocked")
	w.pos=Vector2i(1,4)
	check(w.action("drain"),"valve drains flooded alcove")
	check(not w.action("spring"),"water choices are mutually exclusive")
	w.pos=Vector2i(7,3)
	check(w.step(Vector2i.UP),"drained water is walkable")
	w.pos=Vector2i(8,2)
	check(w.action("relic_duelist") and w.chest_claimed and "duelist" in w.inventory,"relic chest choice awards equipment")
	check(not w.action("relic_buckler"),"relic chest cannot be claimed twice")
	check(w.action("equip_balanced") and w.action("equip_duelist") and w.equipped=="duelist","owned relic can be equipped")
	roundtrip(w,"drain and equipment choice persist")
	w=World.new(0,1); w.enter_floor(1); w.pos=Vector2i(1,4); hp_before=w.hp
	check(w.action("spring") and w.hp>hp_before,"spring exchanges access for immediate recovery")
	check(not w.action("drain"),"spring closes drainage choice")
	w.pos=Vector2i(7,3)
	check(not w.step(Vector2i.UP),"spring retains flooded treasure cost")
	# Quest rewards are one-off and mutually exclusive.
	w=World.new(0,1)
	check(w.action("quest_accept") and w.quest_state==1,"NPC quest accepted")
	check(not w.action("quest_gold"),"quest reward requires sample")
	w.floor_seen=[true,true,true,false,false]; w.enter_floor(2); w.pos=Vector2i(2,7)
	check(w.step(Vector2i.DOWN) and w.quest_state==2,"sample acquired through movement")
	w.enter_floor(0); w.pos=Vector2i(1,1)
	var gold_before: int=w.gold
	check(w.action("quest_gold") and w.quest_state==3 and w.gold>gold_before,"returned sample pays chosen reward")
	check(not w.action("quest_scroll") and not w.action("quest_gold"),"quest reward cannot be doubled")
	roundtrip(w,"completed quest persists")
	# Bargain has an explicit, survivable cost and cannot be rerolled.
	w=World.new(0,1); w.floor_seen=[true,true,true,true,false]; w.enter_floor(3); w.pos=Vector2i(2,4); w.hp=80; before=snapshot(w)
	check(not w.action("bargain_blood") and snapshot(w)==before,"blood bargain cannot kill player")
	w.hp=81
	var atk_before: int=w.atk
	check(w.action("bargain_blood") and w.hp==1 and w.atk==atk_before+6,"blood bargain pays exact declared cost")
	check(not w.action("bargain_gold") and not w.action("bargain_leave"),"bargain selection irreversible within state")
	w=World.new(0,1); w.floor_seen=[true,true,true,true,false]; w.enter_floor(3); w.pos=Vector2i(2,4); w.gold=24
	check(not w.action("bargain_gold"),"gold bargain cannot overdraw")
	w.gold=25
	var def_before: int=w.defense
	check(w.action("bargain_gold") and w.gold==0 and w.defense==def_before+5,"gold bargain cost and reward")
	w=World.new(0,1); w.floor_seen=[true,true,true,true,false]; w.enter_floor(3); w.pos=Vector2i(2,4)
	check(w.action("bargain_leave") and w.event_done,"leaving event is a real completed choice")
	check(not w.action("bargain_blood"),"cannot return to reverse leaving")
	roundtrip(w,"event decision persists")
	print("ADVENTURE: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
