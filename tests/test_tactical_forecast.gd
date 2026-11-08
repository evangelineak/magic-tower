extends SceneTree
const W=preload("res://scripts/world.gd")
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;push_error(label)
# Controlled numerical fixtures, not progression/unlock evidence. Independent
# audit_tactical_routes checks ownership and movement on real generated routes.
func fixture(enemy="W"):
 var w=W.new(23)
 w.hero_id="ranger";w.hp=600;w.atk=103;w.defense=36
 w.pos=Vector2i(3,3);w.floors[0][3][3]=".";w.floors[0][3][4]=enemy
 w.inventory=["balanced","buckler","maul","repeater"]
 return w
func row(result,id):
 for r in result.rows:
  if r.id==id:return r
 return {}
func _init():
 var w=fixture();var target=Vector2i(4,3)
 var before=w.save_data().duplicate(true);var message=w.message;var last=w.last_battle.duplicate(true)
 var forecast=w.tactical_forecast(target)
 check(forecast.valid and forecast.rows.size()==4,"only owned gear produces rows")
 check(w.save_data()==before and w.message==message and w.last_battle==last,"forecast has no persistent or transient effects")
 check(forecast==w.tactical_forecast(target),"stable repeated forecast")
 var maul=row(forecast,"maul");var balanced=row(forecast,"balanced")
 check(maul.unarmed.preview.damage==198 and maul.armed.preview.damage==84,"Precision changes maul from costly to effective")
 check(balanced.unarmed.preview.damage==190 and balanced.armed.preview.damage==152,"same enemy ordinary gear costs differ")
 check(row(forecast,"repeater").unarmed.preview.damage==row(forecast,"repeater").armed.preview.damage,"zero marginal skill benefit is represented honestly")
 for gear in w.inventory:
  check(row(forecast,gear).current.preview==w.battle_preview("W",gear,target),"current preview API compatibility "+gear)
  for armed in [false,true]:
   var actual=fixture()
   check(actual.equipped==gear or actual.action("equip_"+gear),"owned gear can be equipped")
   if armed:check(actual.action("arm"),"skill can be prepared")
   var branch=row(actual.tactical_forecast(target),gear).armed if armed else row(actual.tactical_forecast(target),gear).unarmed
   check(branch.immediate,"matching actual adjacent state is immediately actionable")
   var old_hp=actual.hp
   check(actual.step(Vector2i.RIGHT),"forecasted surviving fight executes")
   check(actual.last_battle.damage==branch.preview.damage and actual.hp==branch.after_hp and actual.focus==branch.focus_after,"real fight matches branch HP/focus "+gear)
   check(old_hp-actual.hp==branch.preview.damage,"no unaccounted healing in baseline fixture")
 w.focus=0
 var empty=row(w.tactical_forecast(target),"maul").armed
 check(not empty.available and not empty.immediate and empty.theoretical and empty.focus_after==null and empty.focus_restored==0 and empty.preview.damage==84,"zero-focus skill only theoretical; no promised reward")
 w.hero_id="scholar"
 for r in w.tactical_forecast(target).rows:check(r.armed.is_empty() and r.flank_armed.is_empty(),"scholar never has a fake armed combat column")
 w=fixture();w.draft.choice="reserve";w.atk=100;w.defense=20;w.floors[0][3][4]="s"
 var reserve=row(w.tactical_forecast(target),"balanced")
 # Change to a sufficiently long armored fight where losing reserve defense costs.
 w.floors[0][3][4]="W";w.atk=150
 reserve=row(w.tactical_forecast(target),"balanced")
 check(reserve.armed.preview.damage>reserve.unarmed.preview.damage,"armed Precision can be worse when reserve defense is lost without reducing rounds")
 w=fixture("H");w.draft.choice="channel";w.focus=3
 var channel=row(w.tactical_forecast(target),"balanced")
 check(channel.unarmed.focus_restored==0 and channel.armed.focus_restored==1 and channel.armed.focus_after==3,"candidate skill spend creates capacity before postbattle focus reward")
 w=fixture("g");w.atk=40;w.defense=5;w.talents=["keen_edge","adversity_charge"]
 var adversity=row(w.tactical_forecast(target),"balanced")
 check(adversity.unarmed.preview.damage>=40 and adversity.armed.preview.damage<40,"Precision can cross the adversity threshold")
 check(adversity.unarmed.focus_restored==1 and adversity.armed.focus_restored==0,"reward follows candidate actual loss rather than current armed flag")
 w.hp=1
 for r in w.tactical_forecast(target).rows:
  for branch in [r.unarmed,r.armed]:
   if not branch.preview.survivable:check(branch.after_hp==-1 and branch.focus_after==null and branch.focus_restored==0 and not branch.immediate,"lethal prediction promises no postbattle recovery")
 check(not w.tactical_forecast(Vector2i(-1,-1)).valid,"out of bounds has no enemy")
 check(not w.tactical_forecast(w.pos).valid,"empty tile has no forecast")
 print("TACTICAL FORECAST: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
 quit(0 if failures==0 else 1)
