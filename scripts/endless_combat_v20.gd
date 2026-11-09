class_name TowerEndlessCombatV20
extends RefCounted
# Pure deterministic combat. First prove termination without player HP, then
# apply ordered events until victory or the exact first lethal event.
static func simulate(input:Dictionary)->Dictionary:
	var foe:Dictionary=input.foe;var token:String=input.token
	var shock:bool=input.rune=="shock";var silent:bool=input.rune=="silence"
	var guarding:bool=input.armed and input.focus>0 and input.hero=="warden"
	var precise:bool=input.armed and input.focus>0 and input.hero=="ranger"
	var hero_pierce:int=8 if precise else 0
	var effective_def:int=maxi(0,int(foe.def)-int(input.pierce)-hero_pierce)
	var hit:int=maxi(0,int(input.atk)-effective_def)
	var per_hit:int=maxi(0,int(foe.atk)-int(input.defense))
	var first:int=per_hit*(2 if token=="c" else 1)*(2 if shock and token!="r" else 1)
	var block:int=mini(int(input.brace),first)
	var cloth:int=mini(int(input.cloak),maxi(0,first-block))
	var ward:int=mini(int(input.ward),maxi(0,first-block-cloth))
	var info:Dictionary={"enemy":foe.duplicate(true),"valid":hit>0,"survivable":false,"rounds":0,"damage":0,"raw_damage":0,"reduction":0,"gear_reduction":0,"item_reduction":0,"hero_reduction":0,"hero_attacks":0,"hero_pierce":hero_pierce,"hero_skill_used":guarding or precise,"heal_after":0,"potential_heal":0,"net_damage":0,"reflection_damage":0,"regen_total":0,"healed_turns":0,"termination_reason":"victory","opening_damage":0,"opening_raw":0,"opening_lethal":false,"charge_extra":0,"charge_extra_damage":0,"first_hit":hit*(2 if shock else 1),"later_hit":hit,"first_counter_raw":first,"effective_enemy_def":effective_def,"normal_counter_damage":0}
	var events:Array=[];var attack_count:=0
	if token=="r":
		var raw:int=per_hit*(2 if shock else 1);var reduction:int=int(raw/2) if guarding else 0
		events.append({"type":"opening","raw":raw,"fixed":0,"hero":reduction,"dealt":raw-reduction,"cloth":0,"ward":0,"extra":0});attack_count+=1
	var health:int=foe.hp;var turn:=0;var seen:Dictionary={}
	while health>0 and hit>0:
		var state:String="%d:%d:%d" % [health,mini(turn,1),mini(attack_count,2)]
		if seen.has(state):info.valid=false;info.termination_reason="regeneration_stall";break
		seen[state]=true
		turn+=1;health-=hit*(2 if shock and turn==1 else 1)
		events.append({"type":"hit"})
		if token=="t":events.append({"type":"reflection","raw":4 if shock and turn==1 else 2})
		if health<=0:break
		var raw:int=first if turn==1 else per_hit
		var fixed:int=block+cloth+ward if turn==1 else 0
		var reduction:int=int((raw-fixed)/2) if guarding and attack_count<2 else 0
		var dealt:int=raw-fixed-reduction
		events.append({"type":"counter","raw":raw,"fixed":fixed,"hero":reduction,"dealt":dealt,"cloth":cloth if turn==1 else 0,"ward":ward if turn==1 else 0,"extra":per_hit*(2 if shock else 1) if token=="c" and turn==1 else 0})
		attack_count+=1
		if token=="p" and not silent and dealt>0:
			var heal:int=mini(3,int(foe.hp)-health);health+=heal;events.append({"type":"regen","heal":heal})
	if hit<=0:info.termination_reason="no_penetration"
	if not info.valid:return info
	var left:int=input.hp
	for event in events:
		if event.type=="hit":info.rounds+=1;continue
		if event.type=="regen":info.regen_total+=event.heal;info.healed_turns+=1;continue
		if event.type=="reflection":
			left-=event.raw;info.reflection_damage+=event.raw;info.raw_damage+=event.raw
			if left<=0:info.termination_reason="reflection_death";break
			continue
		left-=event.dealt;info.raw_damage+=event.raw;info.reduction+=event.fixed+event.hero;info.hero_reduction+=event.hero
		info.hero_attacks+=1;info.gear_reduction+=event.cloth;info.item_reduction+=event.ward
		info.charge_extra+=event.extra;info.charge_extra_damage+=event.extra
		if event.type=="opening":info.opening_damage=event.dealt;info.opening_raw=event.raw
		else:info.normal_counter_damage+=event.raw-event.extra
		if left<=0:
			info.termination_reason="opening_death" if event.type=="opening" else "counter_death";info.opening_lethal=event.type=="opening";break
	info.damage=int(input.hp)-left;info.survivable=left>0
	info.potential_heal=mini(int(input.reap),int(info.damage)) if not silent else 0
	info.heal_after=info.potential_heal if info.survivable else 0;info.net_damage=info.damage-info.heal_after
	return info
