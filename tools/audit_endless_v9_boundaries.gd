extends "res://tools/audit_endless_v8_balance.gd"
var checks:=0
var failures:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func advance(w,buy:bool=true)->bool:
 var f:int=w.floor_number;var y:int=1 if f%2 else 13
 if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)) or not go(w,Vector2i(2,y)):return false
 apply_policy(w,"balanced",y)
 if not go(w,Vector2i(2,y)):return false
 if buy and w.gold>=40:action(w,"job_buyward")
 return go(w,G.anchors(f).exit)
func prepared():
 var w=W.new_run(42);lane="primary";problem="";supply_policy="skip_plus_potion";boxes_used=0;boxes_left=0
 for f in range(1,41):
  var y:int=1 if f%2 else 13
  if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)) or not go(w,Vector2i(2,y)):return null
  if w.items.ward==9 and w.gold>=12:
   for option in w.contract_options():
    if option.id=="job_accept":return w
  if not advance(w):return null
 return null
func clear_target(w):
 var manifest:Dictionary=G.manifest(w.seed,int(w.contract.source))
 lane="primary" if manifest.route==0 else "alternate"
 var points:Array=manifest.points.duplicate()
 if w.floor_number%2==0:points.reverse()
 for point in points:
  if not go(w,point):return
func run():
 W=load("res://scripts/endless_world_v9.gd");G=load("res://scripts/endless_generation_v9.gd")
 var base=prepared()
 if base==null:push_error("Cannot build legal full-inventory fixture: "+problem);quit(1);return
 check(replay_matches(base),"full inventory was legally acquired and replays")
 var w=base.clone();var source:int=w.floor_number;var y:int=1 if source%2 else 13;var money:int=w.gold
 check(w.act("job_accept").changed and w.gold==money-12,"accept only takes 12, not abandoned20")
 var accepted=w.save_data()
 check(not w.act("job_accept").changed and w.save_data()==accepted,"duplicate accept unchanged")
 var cancel=w.clone();var before=cancel.save_data();var confirm:Dictionary=cancel.act("job_cancel")
 check(confirm.get("confirm",false) and not confirm.changed and cancel.save_data()==before,"cancel asks without event or money mutation")
 check(cancel.act("job_cancel!").changed and cancel.gold==money-12,"confirmed cancel loses only deposit")
 before=cancel.save_data();check(not cancel.act("job_cancel!").changed and cancel.save_data()==before,"cancel retry no duplicate loss")
 check(replay_matches(cancel),"confirmed cancel replays")
 var retired=w.clone();var at_retire:int=retired.gold
 check(retired.act("retire").changed and retired.gold==at_retire,"retire does not refund")
 check(not retired.act("job_refund").changed and replay_matches(retired),"ended run cannot redeem")
 var direct=base.clone();var direct_money:int=direct.gold
 check(direct.act("job_buypierce").changed and direct.gold==direct_money-18,"alternative direct purchase costs18")
 before=direct.save_data();check(not direct.act("job_accept").changed and direct.save_data()==before,"direct purchase consumes local order chance")
 check(replay_matches(direct),"direct purchase replays")
 clear_target(w)
 check(problem.is_empty() and not w.ended and w.contract_view().phase=="complete","actual guards cleared")
 # Leave the source floor with a completed unpaid contract; save/reload first.
 go(w,G.anchors(source).exit)
 check(w.floor_number==source+1 and replay_matches(w),"completed contract survives next floor/reload")
 before=w.save_data();check(not w.act("job_refund").changed and w.save_data()==before,"wrong floor cannot refund")
 var stair:Vector2i=G.anchors(w.floor_number).entry
 var off=false
 for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
  if w.tile(w.pos+d)==".":off=w.step(d).changed;break
 check(off and go(w,stair) and w.floor_number==source,"walk back via paired staircase")
 go(w,Vector2i(2,y));var before_refund:int=w.gold
 check(w.items.ward==9,"inventory still full before refund")
 check(w.act("job_refund").changed and w.gold==before_refund+12 and w.contract_view().phase=="voucher","full inventory never blocks deposit refund")
 before=w.save_data();check(not w.act("job_refund").changed and w.save_data()==before,"refund retry cannot mint money")
 check(replay_matches(w) and W.from_data(w.save_data()).contract_view().phase=="voucher","save after refund retains unspent voucher")
 var away=w.clone();var voucher_before:int=away.gold
 go(away,G.anchors(source).exit)
 var away_snapshot=away.save_data()
 check(away.floor_number==source+1 and not away.act("job_pierce").changed and away.save_data()==away_snapshot,"remote voucher exchange cannot bypass original camp")
 check(away.gold==voucher_before and replay_matches(away),"pending voucher persists across floors without second refund")
 var refunded=w.clone()
 before=w.save_data();check(not w.act("job_ward").changed and w.save_data()==before and w.contract_view().phase=="voucher","full reward inventory rejects atomically and keeps voucher")
 var claimed=w.clone();var count:int=claimed.contract_view().reward_count;var before_claim:int=claimed.gold
 check(claimed.act("job_pierce").changed and claimed.gold==before_claim-8 and claimed.items.pierce==count,"alternate reward exchanges exact count for8")
 before=claimed.save_data();check(not claimed.act("job_pierce").changed and claimed.save_data()==before,"exchange retry no duplication")
 check(replay_matches(claimed),"cross-floor full-inventory refund and later exchange replays")
 var before_decline:int=refunded.gold
 check(refunded.act("job_decline").changed and refunded.gold==before_decline,"decline is free")
 check(replay_matches(refunded),"decline replays")
 # Fresh cloned run without a job: prior kills cannot become a retroactive contract.
 var retro=base.clone();var offer:Dictionary=G.manifest(retro.seed,retro.floor_number)
 lane="primary" if offer.route==0 else "alternate"
 var first:Vector2i=offer.points[-1] if retro.floor_number%2==0 else offer.points[0]
 go(retro,first);go(retro,Vector2i(2,y));before=retro.save_data()
 check(not retro.act("job_accept").changed and retro.save_data()==before,"cannot accept after a target already died")
 check(replay_matches(retro),"retroactive reject leaves valid replay")
 print("CONTRACT_BOUNDARY_RESULT "+JSON.stringify({"design":"CONTRACT-9B","checks":checks,"failures":failures,"source_floor":source,"full_ward_inventory":base.items.ward,"fixture_actions":base.actions.size(),"cross_floor":true,"reward_count":count,"replay_verified":failures==0,"fixture_problem":problem}))
 quit(0 if failures==0 and problem.is_empty() else 1)
