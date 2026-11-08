extends SceneTree
const W=preload("res://scripts/world.gd")
const S=preload("res://scripts/legacy_strategy.gd")
const P=preload("res://scripts/progression.gd")
const G=preload("res://scripts/generation.gd")
var checks:=0
var failures:=0
const ID="strategy_world_0000001"
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func state(w)->Dictionary:return w.save_data().duplicate(true)
func chosen(id:String,mode:String="safe"):
 for seed in range(100):
  if id not in S.offers(seed,S.IDS):continue
  var w=W.new(seed,2,ID,mode,false,S.IDS)
  check(w.choose_strategy(id),"choose reproducible offered strategy "+id)
  return w
 check(false,"strategy appears in finite tested seeds")
 return null
func at_enemy(w,token:String,floor_id:int=0)->Vector2i:
 w.floor_index=floor_id
 for i in range(floor_id+1):w.floor_seen[i]=true
 for y in range(1,10):
  for x in range(1,10):
   var target=Vector2i(x,y)
   if w.tile(target)!=token:continue
   for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    if w.tile(target-delta)==".":w.pos=target-delta;return delta
 check(false,"fixture has real enemy and clear adjacent space")
 return Vector2i.ZERO
func _init():
 var w=W.new(42,2,ID,"safe",false,S.IDS)
 check(w.generation_valid and w.strategy_pending() and w.draft.offers==S.offers(42,S.IDS),"new eligible pool has fixed actual offers and pending choice")
 var initial=state(w)
 check(W.from_snapshot(JSON.parse_string(JSON.stringify(initial))).save_data()==initial,"JSON canonical draft version and exact offers")
 check(not w.step(Vector2i.RIGHT) and not w.action("arm") and not w.finish_run("withdrawn") and not w.lethal_fight(Vector2i.RIGHT) and w.safe_walk_path(Vector2i(2,1)).is_empty() and state(w)==initial,"pending blocks all actual gameplay and terminal transitions")
 var missing=""
 for id in S.IDS:
  if id not in w.draft.offers:missing=id;break
 check(not w.choose_strategy(missing) and state(w)==initial,"cannot choose an unoffered strategy")
 var preview=w.strategy_preview(w.draft.offers[0])
 check(preview.valid and preview.can_choose and state(w)==initial,"candidate preview is read-only")
 check(w.choose_strategy("none") and not w.strategy_pending() and w.moves==0 and w.atk==18 and w.defense==8,"original option locks without stat/resource/move edits")
 var locked=state(w)
 check(not w.choose_strategy(w.draft.offers[0]) and state(w)==locked,"locked choice cannot be replaced even before moving")
 check(w.step(Vector2i.RIGHT) and not w.choose_strategy("none"),"first actual action cannot reopen choice")
 for patch in [{"choice":"bogus"},{"offers":[]},{"version":true},{"extra":1},{"pool":["study"]}]:
  var bad=initial.duplicate(true);bad.draft.merge(patch,true)
  var untouched=state(w)
  check(not w.restore(bad) and state(w)==untouched,"invalid draft rejects atomically")
 var bad=initial.duplicate(true);bad.moves=1
 check(not w.restore(bad),"pending cannot coexist with already performed moves")
 for field in ["ended_reason","moves","won"]:
  for value in [[],{},"invalid",null]:
   var malformed=initial.duplicate(true);malformed[field]=value
   check(not w.restore(malformed),"pending raw field types reject without script exception")
 var empty=W.new(0,2,ID)
 check(not empty.strategy_pending() and empty.current_strategy()=="none" and empty.draft.version==1,"empty eligible pool auto-locks original")
 # Original choice leaves the true authored route proof unchanged.
 w=W.new(0,2,ID,"safe",false,S.IDS);check(w.choose_strategy("none"),"none offered independently of three candidates")
 for c in G.generate(0,W.MAPS).validation.route:
  check(w.step({"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}[c]),"original strategy real baseline route")
 check(w.won and w.hp==157,"original conservative authored victory unchanged")
 # Scholar and gear comparisons use the same actually selected skill source.
 w=chosen("study");w.hero_id="scholar";w.kills=7;w.talents=["keen_edge","trained_focus"]
 w.inventory.append("buckler");w.chest_claimed=true;w.equipped="buckler";w.gear_offers.buckler=["focus_deep","edge_light","guard_light"];w.gear_choices.buckler="focus_deep"
 check(str(w.tooltip_data(w.pos).lines).contains("Dedicated study") and str(w.tooltip_data(w.pos).lines).contains("ATK -4 / DEF -2"),"hero tooltip identifies selected strategy and its costs")
 check(w.skill_level()==20 and w.skill_level_info().strategy==4 and w.mend_heal()==130,"equipped gear plus training plus study reaches genuine20")
 var hp_before=w.hp;var focus_before=w.focus
 check(w.action("mend") and w.hp==hp_before+130 and w.focus==focus_before-1,"scholar actual heal uses level20 source")
 check(w.battle_preview("s","balanced").skill_level==18 and w.battle_preview("s","buckler").skill_level==20,"gear override uses corresponding tuning plus same strategy")
 check(w.action("equip_balanced") and w.skill_level()==18,"removing level gear immediately lowers current level")
 # Forager adds surviving recovery and taxes only monster income.
 w=chosen("forager");var delta=at_enemy(w,"s");w.hp=500;w.atk=50;w.defense=8
 var before=state(w);var b=w.battle_preview("s","",w.pos+delta)
 check(b.gold_after==6 and b.gold_tax==2 and b.heal_after==12,"forager preview shows exact eight-gold kill tax")
 check(w.step(delta) and w.hp==int(before.hp)-int(b.damage)+12 and w.gold==int(before.gold)+6,"forager surviving actual rewards match forecast")
 var gold_before=w.gold;w.gain_gold(20);check(w.gold==gold_before+20,"ordinary non-monster income is not taxed")
 # Controlled encounter-position fixture, not a new campaign route. Debt itself
 # is prepared only through real borrow/repay/checkpoint mechanisms, never by
 # assigning principal/fees/interest/overdue. Forager taxes BEFORE collections.
 for small_debt in [false,true]:
  w=chosen("forager");at_enemy(w,"M")
  check(w.action("borrow"),"debt fixture uses actual merchant loan")
  if small_debt:check(w.action("repay"),"partial principal uses actual fee-first payment")
  w.settle_checkpoint(2)
  check(w.overdue and w.debt()==(4 if small_debt else 50),"actual scheduled interest prepares controlled overdue balance")
  delta=at_enemy(w,"s");w.hp=500;w.atk=50;w.defense=8
  check(W.from_snapshot(state(w))!=null,"controlled loan encounter still passes full snapshot validation")
  var debt_before=w.debt();var pocket_before=w.gold
  b=w.battle_preview("s","",w.pos+delta)
  check(b.gold_tax==2 and b.gold_after==6 and w.victory_reward_text(b).contains("before debt"),"eight-gold enemy promises six tax-adjusted loot before debt, not net pocket income")
  check(w.step(delta),"survive forager taxed kill while overdue")
  if small_debt:
   check(w.debt()==0 and not w.overdue and w.gold==pocket_before+2,"four debt consumes four of six loot, remaining two enters pocket")
  else:
   check(w.debt()==debt_before-6 and w.gold==pocket_before and w.overdue,"large overdue debt falls by six, never original eight, with no pocket gain")
 # Channel pays its defense cost and refunds focus only after a real elite kill.
 w=chosen("channel");delta=at_enemy(w,"w",3);w.hp=1000;w.atk=100;w.defense=24;w.focus=1;w.skill_armed=true
 b=w.battle_preview("w","",w.pos+delta)
 check(w.victory_reward_text(b).contains("+1 focus") and w.victory_reward_text(b).contains("before debt"),"reward helper owns actual focus capacity and distinguishes loot from net gold")
 check(b.focus_after==1 and b.effective_def==21,"elite preview names focus reward and lower defense")
 check(w.step(delta) and w.focus==1 and not w.skill_armed,"consume armed focus before bounded channel reward")
 w=chosen("channel");delta=at_enemy(w,"w",3);w.hp=1000;w.atk=100;w.focus=w.focus_cap
 check(w.victory_reward_text(w.battle_preview("w","",w.pos+delta)).contains("+0 focus"),"full focus forecast does not promise an unavailable refill")
 check(w.step(delta) and w.focus==w.focus_cap,"channel cannot exceed cap")
 # Every strategy death replays with its exact locked starting context and no reward.
 for id in S.IDS:
  w=chosen(id,"risk");delta=at_enemy(w,"s");w.hp=1
  before=state(w)
  check(w.lethal_fight(delta) and w.last_battle.heal_after==0 and w.last_battle.focus_after==0 and w.last_battle.gold_after==0 and w.gold==before.gold and w.kills==before.kills,"strategy death grants no on-kill reward: "+id)
  var restored=W.from_snapshot(JSON.parse_string(JSON.stringify(state(w))))
  check(restored!=null and restored.current_strategy()==id and state(restored)==state(w),"death record recomputes locked strategy: "+id)
 # Genuine v14 active/death snapshots do not receive a new draw.
 for name in ["schema14-active.json","schema14-death.json"]:
  var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name))
  w=W.from_snapshot(old)
  check(w!=null and w.draft=={"version":0,"pool":[],"offers":[],"choice":"none"} and not w.strategy_pending(),"legacy remains original without new draw: "+name)
  if w==null:continue
  var now=JSON.parse_string(JSON.stringify(state(w)))
  for key in old:
   if key!="version":check(now[key]==old[key],"legacy field conserved: "+key)
 print("STRATEGY WORLD: %d checks, failures=%d"%[checks,failures])
 quit(1 if failures else 0)
