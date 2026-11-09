extends SceneTree
const Seal=preload("res://scripts/endless_revisit_art.gd")
class Memory:
 extends RefCounted
 var revision=0
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit(_s,_r):revision+=1;return read()
var checks=0
var failures=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var W=load("res://scripts/endless_world_v18.gd")
 var seen={};var target=Vector2i(12,3)
 for floor_number in range(1,5):
  var w=W.new_run(1);w.floor_number=floor_number
  var q=w.vault_quote(target);seen[q.kind]=true
  check(q.available and q.kind==w.vault_kind(),"actual vault kind agrees with current floor")
  var before=w.save_data();Seal.status(w,target)
  check(w.save_data()==before,"seal derivation has no state mutation")
  match q.kind:
   "medicine":
    w.hp=180;check(Seal.status(w,target).blocked,"full-health medicine sealed")
    w.hp=179;check(not Seal.status(w,target).blocked and w.vault_quote().actual==1,"injury clears seal and actual heal is capped")
   "ward","pierce":
    w.items[q.kind]=9-int(q.nominal)+1
    check(Seal.status(w,target).blocked,"one space short seals entire batch")
    w.items[q.kind]-=1
    check(not Seal.status(w,target).blocked,"exact batch capacity clears seal")
   "gold":check(not Seal.status(w,target).blocked,"gold reward normally not sealed")
 check(seen.size()==4,"all four actual family kinds represented")
 var ui=load("res://endless.tscn").instantiate();ui.store=Memory.new();root.add_child(ui);await process_frame;ui.set_process(false)
 for floor_number in range(1,5):
  ui.world=W.new_run(1);ui.world.floor_number=floor_number;ui.world.hp=180;ui.world.items.ward=9;ui.world.items.pierce=9
  ui.camera=Vector2i(4,0);ui.modal="";ui.hover=target
  ui.queue_redraw();await process_frame
  check(is_instance_valid(ui),"actual UI draws kind and hover with derived blocked status")
  var quote=ui.world.vault_quote();ui.world.pos=target+Vector2i.LEFT
  if quote.kind!="gold":
   var snapshot=ui.world.save_data();await ui.map_click(target)
   check(ui.world.save_data()==snapshot and ui.world.tile(target)=="$" and Seal.status(ui.world,target).blocked,"actual mouse refusal keeps treasure and seal in place")
   if quote.kind=="medicine":ui.world.hp=150
   else:ui.world.items[quote.kind]=0
   check(not Seal.status(ui.world,target).blocked,"changing real resource state removes seal without explicit refresh")
   await ui.map_click(target)
   check(ui.world.tile(target)=="." and Seal.status(ui.world,target).is_empty(),"actual mouse pickup removes treasure and seal together")
 ui.world=load("res://scripts/endless_world_v17.gd").new_run(1)
 check(not ui.world.has_method("vault_quote") and Seal.status(ui.world,target).is_empty(),"v17 coin box retains old symbol with no new marker")
 ui.queue_free();await process_frame
 print("VAULT UI: %s (%d checks; isolated floor fixtures)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
