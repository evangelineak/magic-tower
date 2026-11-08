extends SceneTree
const W=preload("res://scripts/world.gd")
const G=preload("res://scripts/generation.gd")
const DIR={"U":Vector2i.UP,"D":Vector2i.DOWN,"L":Vector2i.LEFT,"R":Vector2i.RIGHT}
func route(w,f,target):
 var start=Vector3i(w.pos.x,w.pos.y,w.floor_index);var end=Vector3i(target.x,target.y,f)
 var queue=[start];var prev={start:null};var arrows={}
 while not queue.is_empty():
  var p=queue.pop_front()
  if p==end:
   var result=""
   while p!=start:result=arrows[p]+result;p=prev[p]
   return result
  for key in DIR:
   var n=Vector2i(p.x,p.y)+DIR[key]
   if n.x<1 or n.x>9 or n.y<1 or n.y>9:continue
   var token=w.floors[p.z][n.y][n.x]
   if not token in [".","k","h","a","d","C","I","M","J","O","F","N","E","Q","X","<",">"]:continue
   var q=Vector3i(n.x,n.y,p.z)
   if token in ["<",">"]:
    var dest=W.Layout.stair_destination(w.floors,w.layout_revision,p.z,n)
    if not dest.ok or not w.floor_seen[dest.floor]:continue
    q=Vector3i(dest.pos.x,dest.pos.y,dest.floor)
   if prev.has(q):continue
   prev[q]=p;arrows[q]=key;queue.append(q)
 return null
func go(w,f,target):
 var r=route(w,f,target)
 assert(r!=null,"route unavailable "+str(w.pos)+" to "+str(target))
 for key in r:assert(w.step(DIR[key]),w.message)
 return r.length()
func _init():
 for shipped in [false,true]:
  var w=W.new(1);var proof=G.generate(1,W.MAPS).validation.route
  var chosen=false;var measured=false;var info={"shipped":shipped,"extra_steps":0}
  for key in proof:
   var token=w.tile(w.pos+DIR[key])
   if w.floor_index==0 and token==">" and not chosen:
    var origin=w.pos;info.source_before={"hp":w.hp,"keys":w.keys}
    info.extra_steps+=go(w,0,Vector2i(8,3))
    if shipped:assert(w.action("cargo_ship"))
    else:
     assert(w.step(Vector2i.UP));assert(w.step(Vector2i.RIGHT));assert(w.step(Vector2i.LEFT));assert(w.step(Vector2i.DOWN))
    info.extra_steps+=go(w,0,origin);chosen=true
    info.source_after={"hp":w.hp,"keys":w.keys,"state":w.cargo.state}
   if w.floor_index==1 and token==">" and not measured:
    info.after2={"hp":w.hp,"keys":w.keys}
    var origin=w.pos
    var back=go(w,0,Vector2i(3,9));info.return_L_steps=back
    var gold=w.gold;var can=w.step(Vector2i.LEFT);info.L_open=can
    if can:
     assert(w.step(Vector2i.LEFT));info.L_gold=w.gold-gold;info.L_remaining_keys=w.keys
    info.after_L={"hp":w.hp,"keys":w.keys}
    info.back_to_2_steps=go(w,1,origin);measured=true
   if token=="K":info.before_K={"hp":w.hp,"damage":w.battle_preview("K","",w.pos+DIR[key]).damage}
   assert(w.step(DIR[key]),w.message)
  info.chapter1={"hp":w.hp,"keys":w.keys,"gold":w.gold,"cargo_ready":w.cargo_ready()}
  if shipped:
   assert(w.action("expedition"));info.after_continue_ready=w.cargo_ready()
   var ret=route(w,4,Vector2i(1,3));info.claim_path=ret
   if ret!=null:
    for dir in ret:assert(w.step(DIR[dir]))
    info.before_claim_hp=w.hp;assert(w.action("cargo_claim"));info.after_claim_hp=w.hp
  print(JSON.stringify(info))
 quit()
