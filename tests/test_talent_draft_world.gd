extends SceneTree
const W=preload("res://scripts/world.gd")
const P=preload("res://scripts/progression.gd")
const G=preload("res://scripts/generation.gd")
const S=preload("res://scripts/legacy_strategy.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func state(w)->Dictionary:return w.save_data().duplicate(true)
func fixture(strategy:String="none",mode:String="safe"):
 for seed in range(1000):
  var cards=P.talent_draft(seed).offers
  if "tactical_review" not in cards[0] or "adversity_charge" not in cards[1]:continue
  if strategy!="none" and strategy not in S.offers(seed,S.IDS):continue
  var w=W.new(seed,2,"talent_world_fixture_01",mode,false,S.IDS if strategy!="none" else [])
  if strategy!="none":check(w.choose_strategy(strategy),"fixture locks offered strategy")
  # Controlled talent unlock fixture, not a claim of having played these kills.
  w.kills=7
  check(w.action("talent_tactical_review") and w.action("talent_adversity_charge"),"fixture chooses real offered cards through tier order")
  return w
 check(false,"new talents have seeds with required offers");return null
func encounter(w,kind:String,floor_id:int)->Vector2i:
 w.floor_index=floor_id
 for i in range(floor_id+1):w.floor_seen[i]=true
 for y in range(1,10):
  for x in range(1,10):
   var target=Vector2i(x,y)
   if w.tile(target)!=kind:continue
   for delta in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
    if w.tile(target-delta)==".":w.pos=target-delta;return delta
 check(false,"real enemy fixture exists");return Vector2i.ZERO
func _init():
 var w=W.new(0);var birth=state(w);var offers=w.talent_draft.duplicate(true)
 check(w.save_data().version==18 and w.last_kill_kind=="" and w.talent_options().is_empty() and w.talent_progress().next_kills==3,"new run starts with fixed hidden future cards and no prior kill")
 check(W.from_snapshot(JSON.parse_string(JSON.stringify(birth))).save_data()==birth,"new candidates survive canonical JSON roundtrip")
 check(not w.talent_preview_targets().any(func(t):return t.floor==2 and t.kind=="V"),"unseen third-floor vault is not exposed")
 var first_done:=false;var second_done:=false;var floor_three:=false
 var route:String=G.generate(0,W.MAPS).validation.route
 for symbol in route:
  var old_kills=w.kills;var prior=w.last_kill_kind
  var delta:Vector2i={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[symbol]
  var target_kind=w.tile(w.pos+delta)
  check(w.step(delta),"actual unchanged map witness remains playable")
  if w.kills>old_kills:check(w.last_kill_kind==target_kind,"only actual surviving kill records kind")
  else:check(w.last_kill_kind==prior,"walking and pickups do not alter kill memory")
  if w.kills==3 and not first_done:
   check(w.floor_index==0 and w.talent_options().size()==3 and w.talent_progress().available,"first real three kills reveal three-card choice on floor1")
   var options=w.talent_options();var omitted=""
   for id in P.TALENT_POOLS[0]:
    if id not in options:omitted=id
   var before=state(w)
   check(not w.action("talent_"+omitted) and state(w)==before,"omitted first-tier card is not secretly selectable")
   check(not w.action("talent_"+w.talent_draft.offers[1][0]) and state(w)==before,"cannot select second tier before first")
   var targets=w.talent_preview_targets();check(not targets.is_empty(),"current real targets available for card comparison")
   var target=targets[0];var card=w.talent_preview(options[0],target.kind,target.pos,target.floor)
   check(card.valid and card.can_choose and card.before==w.battle_preview(target.kind,"",target.pos) and state(w)==before,"card comparison uses exact live before state without mutation")
   check(w.action("talent_"+options[0]) and card.after==w.battle_preview(target.kind,"",target.pos),"selected card actual forecast equals shown after")
   check(w.talent_options().is_empty() and w.talent_progress().next_kills==7,"no extra tier until seven kills")
   var undo=W.from_snapshot(before)
   check(undo!=null and undo.talent_draft==offers and undo.talent_options()==options,"full-state selection undo restores same offers, not reroll")
   first_done=true
  if w.kills==7 and not second_done:
   check(w.floor_index==1 and w.talent_options().size()==3,"second real seven kills reveal second pack on floor2")
   check(w.action("talent_"+w.talent_options()[0]) and w.talents.size()==2,"second pack locks one actual candidate")
   second_done=true
  if w.floor_index==2 and not floor_three:
   check(w.talent_preview_targets().any(func(t):return t.kind=="V" and t.floor==2),"visited third-floor living vault can inform future card choice")
   floor_three=true
 check(first_done and second_done and floor_three and w.won and w.talent_draft==offers,"true campaign route preserves all originally frozen offers")
 # Continue the real chapter-winning run; only the local audit interaction
 # position is controlled, while reading/solving/retraining use real actions.
 check(w.action("expedition"),"real chosen-card run can continue into expedition")
 encounter(w,"Y",5)
 check(w.action("audit_read") and w.action("audit_guess_"+str(w.audit_puzzle.solution)),"existing audit mechanism unlocks real respec choice")
 var old_offers=w.talent_draft.duplicate(true);var last=w.last_kill_kind
 var prior_hp=w.hp;var prior_focus=w.focus;var prior_kills=w.kills
 check(w.action("audit_retrain"),"real audit action clears existing selected cards")
 check(w.talent_options()==old_offers.offers[0] and w.talent_draft==old_offers and w.last_kill_kind==last and w.hp==prior_hp and w.focus==prior_focus and w.kills==prior_kills,"actual respec preserves packs and kill memory without refunds")
 check(W.from_snapshot(state(w))!=null,"actual retrained current-version state remains reloadable")
 # Focus order: real skill payment, then additive channel+adversity, then cap.
 for start in [1,3]:
  w=fixture("channel");var delta=encounter(w,"w",3)
  w.hp=1000;w.atk=100;w.defense=0;w.focus=start;w.skill_armed=true
  check(W.from_snapshot(state(w))!=null,"controlled reward-stack fixture fully validates")
  var preview=w.battle_preview("w","",w.pos+delta)
  check(preview.damage==42 and preview.focus_after==2,"actual Brace-adjusted42 damage qualifies alongside channel")
  check(w.step(delta) and w.focus==mini(3,start-1+2) and w.last_kill_kind=="w","World pays skill then adds both refunds once up to cap")
 # Death keeps the prior real-kind memory and grants neither bonus.
 w=fixture("channel","risk");var delta=encounter(w,"s",0);w.hp=1;w.last_kill_kind="g"
 var before=state(w)
 check(w.lethal_fight(delta) and w.last_kill_kind=="g" and w.kills==before.kills and w.focus==before.focus and w.last_battle.focus_after==0,"fatal attempt cannot update last kill or trigger adversity/channel")
 var restored=W.from_snapshot(JSON.parse_string(JSON.stringify(state(w))))
 check(restored!=null and state(restored)==state(w) and restored.last_battle==w.last_battle,"death reload replays exact prior-kind/talent context")
 # Every malformed candidate mutation is rejected atomically, including JSON types.
 var good=birth.duplicate(true);var receiver=W.from_snapshot(birth)
 for patch in [{"version":true},{"version":2},{"offers":{}},{"offers":[[],[],[]]},{"extra":1}]:
  var bad=good.duplicate(true);bad.talent_draft.merge(patch,true)
  check(not receiver.restore(bad) and state(receiver)==birth,"invalid saved card catalog rejects atomically")
 for value in [null,true,0,[],{},"unknown"]:
  var bad=good.duplicate(true);bad.last_kill_kind=value
  check(not receiver.restore(bad) and state(receiver)==birth,"invalid last-kind input rejects without exceptions")
 # Real old15 active/death preserves all existing gameplay and receives only legacy pools.
 for name in ["schema15-active.json","schema15-death.json"]:
  var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name))
  var migrated=W.from_snapshot(old)
  check(migrated!=null and migrated.talent_draft==P.talent_draft(0,0) and migrated.last_kill_kind=="","real schema15 migrates without a fresh draw or invented kill")
  if migrated==null:continue
  var now=JSON.parse_string(JSON.stringify(state(migrated)))
  for key in old:
   if key!="version":check(now[key]==old[key],"legacy field conserved: "+key)
 print("TALENT DRAFT WORLD: %d checks, failures=%d"%[checks,failures])
 quit(1 if failures else 0)
