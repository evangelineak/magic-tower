extends "res://tools/audit_legacy_points_routes.gd"
# Independent legal-route alternatives, never edited states or UI play claims.
var audits=0
func _init():
 var earning=W.new(1,2,"rope_earning_0123456789")
 assert(earning.action("hero_scholar"))
 var earned=stats();follow(earning,G.generate(1,W.MAPS).validation.route,earned)
 assert(earning.action("expedition"));follow(earning,E.generate(1).witness,earned)
 assert(earning.won and earning.finish_run("victory"))
 profile=P.settle(P.fresh(),earning.run_id,earning.settlement_summary("victory").summary).profile
 print(JSON.stringify({"stage":"earned_capacity","milestones":profile.milestones,"moves":earning.moves,"receipt":profile.receipts[earning.run_id]}))
 for hero in ["warden","ranger","scholar"]:audit(hero,false)
 audit("scholar",true)
 assert(audits==4,"missing actual hero comparison")
 print("ROPE ROUTE AUDIT PASS: "+str(audits)+" legally reached checkpoints")
 quit()
func audit(hero,high_channel):
 var seed_value=23 if high_channel else 0
 var pool=S.pool_from_profile(profile) if high_channel else []
 var w=W.new(seed_value,2,"rope_probe_0123456789","safe",false,pool)
 if high_channel:assert(w.choose_strategy("channel",{"study":2,"reserve":1}))
 assert(w.action("hero_"+hero))
 var st=stats("adversity_charge" if high_channel else "trained_focus")
 follow(w,G.generate(seed_value,W.MAPS).validation.route,st)
 assert(w.action("expedition"))
 var witness=E.generate(seed_value).witness
 for key in witness:
  if w.tile(w.pos+DIR[key])=="H":
   compare(w,hero,high_channel);audits+=1;return
  # Reach the actual first ferry without gratuitously exhausting the last point
  # on optional Mend before the decision. All earlier skill use was real.
  assert(w.step(DIR[key]),w.message)
 assert(false,"first ferry was not reached")
func record(w):return {"hp":w.hp,"focus":w.focus,"gold":w.gold,"kills":w.kills,"armed":w.skill_armed,"position":str(w.pos),"moves":w.moves,"rope":w.rope.duplicate(),"skill_level":w.skill_level_info().effective,"strategy":w.current_strategy(),"talents":w.talents.duplicate()}
func compare(w,hero,high_channel):
 var initial=w.save_data().duplicate(true);var info=w.rope_preview()
 assert(info.valid and w.pos==info.origin,"witness did not reach genuine rope takeoff")
 assert(w.save_data()==initial,"rope inspection mutated world")
 var result={"hero":hero,"high_channel":high_channel,"before":record(w),"offer":info}
 var crossed=W.from_snapshot(initial)
 var available=crossed.action("rope_cross")
 result.rope_available=available
 if available:
  assert(crossed.pos==info.landing and crossed.focus==w.focus-1 and crossed.hp==w.hp and crossed.gold==w.gold and crossed.kills==w.kills,"rope gave fight rewards or wrong cost")
  assert(crossed.tile(info.target)=="H" and crossed.rope.state=="spent","rope removed guardian or failed to snap")
  assert(crossed.skill_armed==(w.skill_armed and w.focus>1),"last-focus armed state disagrees")
  var unchanged=crossed.save_data().duplicate(true)
  assert(not crossed.action("rope_cross") and crossed.save_data()==unchanged,"spent crossing repeat had effects")
  result.after_rope=record(crossed)
  var return_fight=W.from_snapshot(crossed.save_data())
  if hero in ["warden","ranger"] and return_fight.focus>0 and not return_fight.skill_armed:assert(return_fight.action("arm"))
  var rear_preview=return_fight.battle_preview("H","",info.target)
  assert(rear_preview.get("flank_active",false),"rope landing failed to use actual flank side")
  var can_return=return_fight.step(info.target-return_fight.pos)
  result.return_fight_won=can_return
  if can_return:result.after_rope_return_fight=record(return_fight)
 var fought=W.from_snapshot(initial)
 if hero in ["warden","ranger"] and fought.focus>0 and not fought.skill_armed:assert(fought.action("arm"))
 var prediction=fought.battle_preview("H","",info.target)
 result.fight_preview={"damage":prediction.damage,"survivable":prediction.survivable,"focus_after":prediction.get("focus_after",0),"skill_consumed":prediction.skill_consumed}
 var victory=fought.step(info.target-fought.pos);result.fight_won=victory
 if victory:
  assert(fought.hp==w.hp-int(prediction.damage)+int(prediction.heal_after),"fight HP disagrees with actual preview")
  result.after_fight=record(fought)
  if hero=="scholar" and available:
   var equal_focus=W.from_snapshot(fought.save_data())
   while equal_focus.focus>crossed.focus:assert(equal_focus.action("mend"))
   result.fight_then_mend_equal_focus=record(equal_focus)
 # A focus point's concrete opportunity cost for the scholar is a legal Mend,
 # not a claimed universal HP conversion for every class.
 if hero=="scholar" and w.focus>0:
  var healed=W.from_snapshot(initial);assert(healed.action("mend"));result.after_mend=record(healed)
 # An already armed last point is obtained by the real arm action, not a flag.
 if hero in ["warden","ranger"] and w.focus==1:
  var armed=W.from_snapshot(initial);assert(armed.action("arm"));assert(armed.rope_preview().disarm)
  assert(armed.action("rope_cross") and not armed.skill_armed and armed.focus==0)
  result.last_focus_disarm=record(armed)
 var bridged=W.from_snapshot(initial)
 var worksite=Vector2i(-1,-1)
 for y in range(1,10):
  for x in range(1,10):
   if bridged.tile(Vector2i(x,y))=="Y":worksite=Vector2i(x,y)
 var bridge_steps=walk_cleared(bridged,worksite)
 assert(bridged.action("camp_bridge"),"actual gold did not buy bridge alternative")
 bridge_steps+=walk_cleared(bridged,info.landing)
 assert(bridged.tile(info.target)=="H" and bridged.hp==w.hp and bridged.focus==w.focus and bridged.gold==w.gold-80,"bridge alternative cost/reward changed")
 assert(not bridged.rope_preview().available,"rope should not waste focus after bridge purchased")
 result.after_bridge=record(bridged);result.bridge_steps=bridge_steps
 print(JSON.stringify(result))

func walk_cleared(w,target):
 var queue=[w.pos];var paths={w.pos:[]}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p==target:
   for d in paths[p]:assert(w.step(d),w.message)
   return paths[p].size()
  for d in DIR.values():
   var n=p+d
   if n.x<1 or n.x>9 or n.y<1 or n.y>9 or paths.has(n):continue
   var t=w.tile(n)
   if not t in [".","Y","U","v"] and not (t=="=" and w.expedition_bridge):continue
   paths[n]=paths[p]+[d];queue.append(n)
 assert(false,"actual cleared route missing to "+str(target))
 return -1
