extends SceneTree
# Read-only gameplay audit. No injected HP, kills, inventory or profile awards.
# Run: godot --headless --path . --script tools/audit_legacy_points_routes.gd
# Not a CI gate or global optimizer; see docs/LEGACY-POINTS-ROUTE-AUDIT.md.
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const E=preload("res://scripts/expedition.gd")
const P=preload("res://scripts/legacy_profile.gd")
const S=preload("res://scripts/legacy_strategy.gd")
const DIR={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
var profile={}
func _init():
 # Earn the entire configuration capacity with a legal original-rules expedition.
 var earning=W.new(1,2,"earning_run_0123456789")
 assert(earning.action("hero_scholar"))
 var earned_stats=stats()
 follow(earning,G.generate(1,W.MAPS).validation.route,earned_stats)
 assert(earning.action("expedition"))
 follow(earning,E.generate(1).witness,earned_stats)
 assert(earning.won and earning.finish_run("victory"))
 profile=P.settle(P.fresh(),earning.run_id,earning.settlement_summary("victory").summary).profile
 print(JSON.stringify({"evidence":"capacity-earned","seed":1,"hero":"scholar","run_id":earning.run_id,"outcome":"victory","moves":earning.moves,"highest_floor":earning.highest_seen_floor(),"milestones":profile.milestones,"receipt":profile.receipts[earning.run_id]}))
 for seed_id in [1,23]:
  for hero in ["warden","ranger","scholar"]:
   for loadout in [{"study":0,"reserve":0},{"study":2,"reserve":1},{"study":1,"reserve":2}]:evaluate(seed_id,hero,loadout)
 for strategy in ["study","channel"]:
  for loadout in [{"study":0,"reserve":0},{"study":2,"reserve":1},{"study":1,"reserve":2}]:evaluate(23,"scholar",loadout,strategy,"adversity_charge")
 quit()
func stats(tier2="trained_focus"):return {"tier2":tier2,"loss":0,"healed":0,"skills":0,"supplies":0,"end3":{}}
func upkeep(w,st):
 if not w.talent_options().is_empty():
  var choice=""
  if w.talents.size()==0:choice="keen_edge" if "keen_edge" in w.talent_options() else w.talent_options()[0]
  elif w.talents.size()==1:choice=st.tier2 if st.tier2 in w.talent_options() else w.talent_options()[0]
  else:choice="battle_medic"
  assert(w.action("talent_"+choice))
 if w.hero_id=="scholar":
  while not w.won and (w.focus>0 or w.legacy_reserves>0):
   if w.focus==0:assert(w.action("legacy_focus"));st.supplies+=1
   var old=w.hp;assert(w.action("mend"));st.skills+=1;st.healed+=w.hp-old
func follow(w,route,st):
 for key in route:
  upkeep(w,st)
  var target=w.pos+DIR[key];var token=w.tile(target)
  if W.ENEMIES.has(token) and w.hero_id!="scholar":
   var plain=w.battle_preview(token,"",target)
   var probe=W.from_snapshot(w.save_data())
   var supply=false
   if probe.focus==0 and probe.legacy_reserves>0:assert(probe.action("legacy_focus"));supply=true
   if probe.focus>0:
    assert(probe.action("arm"))
    var active=probe.battle_preview(token,"",target)
    if active.valid and active.damage<plain.damage:
     if supply:assert(w.action("legacy_focus"));st.supplies+=1
     assert(w.action("arm"));st.skills+=1
  var preview=w.battle_preview(token,"",target) if W.ENEMIES.has(token) else {}
  var f=w.floor_index
  assert(w.step(DIR[key]),w.message)
  if not preview.is_empty():st.loss+=preview.damage
  if f==2 and w.floor_index==3:st.end3={"hp":w.hp,"focus":w.focus,"supplies":w.legacy_reserves,"damage":st.loss,"heal":st.healed,"casts":st.skills}
func evaluate(seed_id,hero,allocation,strategy="none",tier2="trained_focus"):
 var w=W.new(seed_id,2,"points_run_0123456789","safe",false,S.pool_from_profile(profile))
 assert(w.choose_strategy(strategy,allocation));assert(w.action("hero_"+hero))
 var st=stats(tier2);var proof=G.generate(seed_id,W.MAPS).validation.route
 follow(w,proof,st)
 var chapter={"hp":w.hp,"focus":w.focus,"supplies":w.legacy_reserves,"damage":st.loss,"heal":st.healed,"casts":st.skills}
 assert(w.action("expedition"))
 follow(w,E.generate(seed_id).witness,st)
 print(JSON.stringify({"seed":seed_id,"hero":hero,"strategy":strategy,"tier2":tier2,"allocation":allocation,"end3":st.end3,"chapter1":chapter,"final":{"hp":w.hp,"focus":w.focus,"supplies":w.legacy_reserves},"stats":st}))
