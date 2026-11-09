extends "res://tools/audit_endless_v19_journeys.gd"
func build_world():
 var w=W.new_run(0)
 for f in range(1,13):
  var y:int=1 if f%2 else 13
  if not go(w,Vector2i(2 if f%2 else 12,y)) or not go(w,Vector2i(3 if f%2 else 11,y)):return w
  apply_balanced(w)
  for point in G.routes(0,f)[0].points:
   if not go(w,point):return w
  if f<12 and not go(w,G.anchors(f).exit):return w
 return w
func unchanged(w,before:Dictionary)->bool:return w.save_data()==before
func run():
 W=load("res://scripts/endless_world_v19.gd");G=load("res://scripts/endless_generation_v19.gd");lane="primary";active_policy="none";allow_door=false;supply_policy="skip_plus_potion"
 var base=build_world();check(problem.is_empty() and base.floor_number==12,"legal grown base")
 if not problem.is_empty() or base.floor_number!=12:quit(1);return
 var histories=[]
 for floor_number in G.cart_floors(0):
  for side in ["supply","archive"]:
   problem="";var w=base.clone();check(move_floors(w,floor_number),"physical return to event")
   var m:Dictionary=G.cart_manifest(0,floor_number)
   var bad_direction:Vector2i=Vector2i.UP if m.variant==1 else Vector2i.DOWN
   check(go(w,m.cart_origin-bad_direction),"stand behind blocked push")
   var before:Dictionary=w.save_data();var r:Dictionary=w.step(bad_direction)
   check(not r.get("changed",false) and not r.get("confirm",false) and unchanged(w,before),"pillar/offrail push no event")
   # One push then actual adjacent reset, player not moved.
   var first:Vector2i=Vector2i.LEFT if m.variant==1 else Vector2i.UP
   check(go(w,m.cart_origin-first) and w.step(first).get("changed",false),"legal initial displacement")
   check(go(w,Vector2i(3,7)),"reach actual reset station")
   var player:Vector2i=w.pos;r=action(w,"cart_reset")
   check(r.get("changed",false) and w.pos==player and find_token(w,"O")==m.cart_origin,"reset returns cart not player")
   var origin_case=w.clone();origin_case.pos=m.cart_origin;before=origin_case.save_data()
   r=origin_case.act("cart_reset")
   check(not r.get("changed",false) and origin_case.pos==m.cart_origin and origin_case.save_data()==before,"controlled invalid origin-occupant reset never overlays or moves player")
   check(solve_cart(w,side),"solve actual variant")
   if side=="archive":check(go(w,m.guardian),"actual archive guardian fight")
   var reward:Vector2i=m.rewards[side]
   check(go(w,reward+Vector2i.DOWN),"stand at claim")
   var saturated=w.clone()
   if side=="supply":saturated.items.ward=9
   else:saturated.bonus_atk=6;saturated.bonus_def=4;saturated.relic_bonus=2;saturated.hp=180
   before=saturated.save_data();r=saturated.step(Vector2i.UP,true)
   check(not r.get("changed",false) and saturated.save_data()==before and saturated.carts[floor_number].claim=="" and saturated.tile(reward) in ["J","L"],"controlled full/zero reward preserved without shared claim")
   before=w.save_data();r=w.step(Vector2i.UP)
   check(r.get("confirm",false) and not r.get("changed",false) and w.save_data()==before,"reward confirmation has no effect")
   check(w.step(Vector2i.UP,true).get("changed",false) and w.carts[floor_number].claim==side,"confirmed reward locks exactly one side")
   var alternative_case=w.clone();var other:String="archive" if side=="supply" else "supply"
   alternative_case.pos=m.rewards[other]+Vector2i.DOWN;before=alternative_case.save_data()
   r=alternative_case.step(Vector2i.UP,true)
   check(not r.get("changed",false) and alternative_case.save_data()==before and alternative_case.carts[floor_number].claim==side,"controlled alternative-adjacent attempt cannot claim twice even ignoring closed gate")
   check(go(w,Vector2i(3,7)),"can exit after latch")
   before=w.save_data();r=w.act("cart_reset")
   check(not r.get("changed",false) and unchanged(w,before),"claimed cart cannot reset")
   check(w.tile(m.gates[side])=="." and w.tile(m.gates["archive" if side=="supply" else "supply"]) in ["u","v"],"selected gate latches other stays closed")
   var restored=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
   check(restored!=null and restored.carts==w.carts and restored.items==w.items and restored.deltas==w.deltas,"all legal event actions replay exact reward/lock")
   histories.append(w.save_data())
  # Killing archive guardian does not commit choice; reset, then supply.
  problem="";var swap=base.clone();check(move_floors(swap,floor_number),"return for guardian swap test")
  var meta:Dictionary=G.cart_manifest(0,floor_number)
  check(solve_cart(swap,"archive") and go(swap,meta.guardian),"kill guardian before claim")
  check(go(swap,Vector2i(3,7)) and action(swap,"cart_reset").get("changed",false),"unclaimed archive reset allowed")
  check(solve_cart(swap,"supply") and go(swap,meta.rewards.supply),"can change to supply after kill")
  check(swap.tile(meta.guardian)=="." and swap.carts[floor_number].claim=="supply","dead guardian not resurrected by alternative claim")
  var loaded=W.from_data(JSON.parse_string(JSON.stringify(swap.save_data())))
  check(loaded!=null and loaded.tile(meta.guardian)=="." and loaded.carts==swap.carts,"guardian swap history replay")
 print("CART_INDEPENDENT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"legal_histories":histories,"controlled_cases":"capacity, zero-gain, invalid origin occupancy and forced alternative adjacency only; all ordinary journey/push/claim/swap paths are legal"}))
 quit(0 if failures==0 else 1)
