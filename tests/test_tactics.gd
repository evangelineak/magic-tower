extends SceneTree
const World=preload("res://scripts/world.gd")
var checks:=0
var failures:=0
func check(ok: bool, label: String):
	checks+=1
	if not ok: failures+=1; push_error(label)
func fixture(gear: String="balanced", hero: String="warden", armed: bool=false):
	var w=World.new(0)
	w.enter_floor(3); w.pos=Vector2i(7,9)
	w.atk=50; w.defense=10; w.hp=500; w.hero_id=hero; w.skill_armed=armed
	if gear!="balanced": w.inventory.append(gear); w.chest_claimed=true
	w.equipped=gear
	return w
func state(w) -> Dictionary:
	return w.save_data().duplicate(true)
func _initialize():
	call_deferred("run_tests")
func run_tests():
	# Independently calculated outcomes for the real 180/32/20 Juggernaut.
	# [gear, hero, armed, total loss, normal, feint, charge, shield, retaliations]
	for row in [["balanced","warden",false,132,110,0,22,0,5],["buckler","warden",false,112,96,0,32,16,6],["duelist","warden",false,150,100,25,25,0,5],["duelist","ranger",true,125,75,25,25,0,4],["duelist","warden",true,98,100,25,25,0,5]]:
		var w=fixture(row[0],row[1],row[2])
		var original: Dictionary=state(w)
		var preview: Dictionary=w.battle_preview("w")
		check(preview.damage==row[3] and preview.normal_damage==row[4] and preview.feint_damage==row[5] and preview.charged_damage==row[6] and preview.equipment_blocked==row[7] and preview.retaliations==row[8],"precise independent Juggernaut arithmetic: "+str(row.slice(0,3)))
		for i in range(4): w.battle_preview("w")
		check(state(w)==original,"preview cannot pre-consume block, focus or charge counter")
		check(w.step(Vector2i.UP) and w.hp==500-int(row[3]) and w.gold==24 and w.kills==1 and w.tile(Vector2i(7,8))==".","real monster resolution equals expected loss and single reward")
		check(w.focus==int(original.focus)-(1 if row[2] else 0),"focus only spent when successful armed battle resolves")
		var after: Dictionary=state(w)
		w.step(Vector2i.DOWN); w.step(Vector2i.UP)
		check(w.hp==after.hp and w.gold==after.gold and w.kills==after.kills,"revisiting cleared monster cannot retrigger damage, shield heal or loot")
		check(w.restore(original) and state(w)==original,"whole-state combat rollback restores monster, focus, health and gear")
		var loaded=World.new(0)
		check(loaded.restore(JSON.parse_string(JSON.stringify(after))) and state(loaded)==after,"new tactical result persists without serializing transient battle counters")
	var w=fixture("duelist","ranger",true); w.hp=125
	var before: Dictionary=state(w)
	check(w.battle_preview("w").damage==125 and not w.step(Vector2i.UP) and state(w)==before,"exact-lethal gear battle consumes no focus, HP, loot or enemy")
	w=fixture("duelist"); w.atk=100; w.defense=8; w.enter_floor(0); w.pos=Vector2i(5,3)
	check(w.battle_preview("s").damage==9 and w.battle_preview("s").rounds==1,"duelist still pays one opening enemy hit on one-shot")
	check(w.step(Vector2i.LEFT) and w.hp==491,"one-shot opening hit is actually charged")
	w=fixture("buckler"); w.atk=500; w.defense=8; w.pos=Vector2i(4,8)
	check(w.battle_preview("u").first_strike_damage==28 and w.battle_preview("u").equipment_blocked==28 and w.battle_preview("u").damage==0,"buckler blocks first-strike attack even when hero one-shots")
	check(w.step(Vector2i.UP) and w.hp==500,"buckler ambush block resolves without extra healing")
	w=fixture("buckler"); w.atk=500; w.defense=8; w.enter_floor(1); w.pos=Vector2i(7,3)
	check(w.battle_preview("b").damage==2 and w.battle_preview("b").equipment_blocked==0,"buckler cannot block thorns when there is no enemy attack")
	check(w.step(Vector2i.RIGHT) and w.hp==498,"thorns remains real damage despite one-shot shield")
	w=fixture("buckler"); before=state(w)
	for i in range(4): w.action("equip_balanced"); w.action("equip_buckler")
	check(w.hp==before.hp and w.gold==before.gold and w.focus==before.focus and w.kills==before.kills,"repeated equipment swaps cannot heal or farm combat outcomes")
	# Legacy v4 had identical equipment IDs/stats, no bridge field, and a Sentinel
	# in the new heavy enemy's slot. Loading it must preserve its actual map.
	w=fixture("duelist"); var legacy: Dictionary=state(w)
	legacy.version=4; legacy.erase("bridge_built"); legacy.floors[3][8][7]="g"
	var loaded=World.new(0)
	check(loaded.restore(legacy) and loaded.equipped=="duelist" and loaded.inventory.has("duelist") and loaded.tile(Vector2i(7,8))=="g","legacy v4 gear save loads without silently replacing old map enemy")
	check(loaded.battle_preview("g").feint_damage>0,"loaded legacy gear receives current documented combat rule")
	# Controller presentation must expose the same decomposition, without
	# subtracting the buckler twice or narrating an attack as free.
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene); scene.save_path="user://tactics-integration-test.json"
	scene.world=fixture("buckler"); scene.growth=false
	await process_frame
	var details: Dictionary=scene.world.battle_preview("w")
	var lines: Array=scene.battle_breakdown(details)
	check(lines.size()==4 and "charge bonus 32" in lines[1] and "6 retaliations" in lines[1] and "Shield 16 / oath 0 / flank 0 / total reduction 16" in lines[2] and "Final loss 112" in lines[3],"UI breakdown exposes heavy bonus and shield without double subtraction")
	before=state(scene.world)
	scene.move(Vector2i.UP)
	check(scene.world.hp==388 and scene.battle_loss==112 and scene.battle_details.charged_damage==32,"controller retains exact resolved heavy-battle breakdown")
	scene.undo()
	check(state(scene.world)==before and scene.battle_time==0,"controller undo restores gear battle atomically")
	DirAccess.remove_absolute(scene.save_path)
	print("TACTICS: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(0 if failures==0 else 1)
