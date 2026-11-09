extends Node2D
# A separate mode and storage namespace: the classic journey is untouched.
const Actors=preload("res://scripts/endless_actor_art.gd")
const Symbols=preload("res://scripts/map_symbols.gd")
const CELL=64.0
const ORIGIN=Vector2(24,72)
const VIEW=11
const INK=Color("e5ebee")
const GOLD=Color("dfbd72")
const TEAL=Color("72b7ad")
var world=null
var store=null
var revision=0
var records:Array=[]
var busy=false
var notice="正在读取独立的无尽旅程……"
var modal_notice=""
var camera=Vector2i.ZERO
var hover=Vector2i(-1,-1)
var walk:Array=[]
var walk_time=0.0
var modal=""
var pending=Vector2i.ZERO
var pending_revision=-1
var pending_origin=Vector2i.ZERO
var pending_floor=0
var pending_token=""
var choices:Array=[]
var battle:Dictionary={}
var battle_time=0.0
var font=ThemeDB.fallback_font
var drag=false
var drag_origin=Vector2.ZERO
var drag_camera=Vector2i.ZERO
var WorldType
var StoreType
func _ready():
 font=load("res://assets/fonts/MagicTowerCJK.otf")
 WorldType=load("res://scripts/endless_world.gd")
 StoreType=load("res://scripts/endless_store.gd")
 if store==null:store=StoreType.new()
 await reload_run()
func text(p:Vector2,s:String,size=18,color=INK):draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func panel(r:Rect2,color=Color("182a39")):draw_rect(r,color)
func draw_wrapped(s:String,p:Vector2,width:float,size=16,color=INK,max_lines=9):
 var line="";var y=p.y;var count=0
 for ch in s:
  if ch=="\n" or font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
   text(Vector2(p.x,y),line,size,color);line="";y+=size+6;count+=1
   if count>=max_lines:return
  if ch!="\n":line+=ch
 if line!="":text(Vector2(p.x,y),line,size,color)
func center_camera():
 if world!=null:camera=Vector2i(clampi(world.pos.x-5,0,4),clampi(world.pos.y-5,0,4))
func screen_tile(p:Vector2)->Vector2i:
 var q=Vector2i(((p-ORIGIN)/CELL).floor())
 return q+camera if Rect2(ORIGIN,Vector2(704,704)).has_point(p) else Vector2i(-1,-1)
func reload_run():
 if busy:return
 busy=true;walk.clear()
 var r:Dictionary=await store.read()
 busy=false
 if r.get("ok",false):
  modal="";pending=Vector2i.ZERO;pending_revision=-1;choices.clear();battle.clear();battle_time=0
  revision=int(r.revision);records=r.get("records",[])
  if r.get("snapshot") is Dictionary and not r.snapshot.is_empty():
   world=WorldType.from_data(r.snapshot);notice="旅程已恢复。经典魔塔存档不受影响。"
   if world!=null and world.ended:modal="ended" if r.get("status")=="finished" else "finish_retry"
  else:modal="start";notice="全新的15×15连续远征，与经典旅程分开保存。"
 else:
  notice="读取失败：%s。没有覆盖存档。按L重试。"%str(r.get("status","unknown"))
  if str(r.get("status","")) in ["empty","missing"]:modal="start";revision=int(r.get("revision",0))
 center_camera();queue_redraw()
func start_run(seed_value:int,rule_version:int=4):
 if busy:return
 busy=true;walk.clear()
 var candidate=WorldType.new_run(seed_value,rule_version)
 var r:Dictionary=await store.start(candidate.save_data(),revision)
 busy=false
 if r.get("ok",false):
  world=candidate;revision=int(r.revision);records=r.get("records",[]);modal="";notice="无尽远征开始。先观察损伤与路线，再决定如何成长。";center_camera()
 else:notice="新局保存尚未确认：%s。按L核对当前已存旅程。"%str(r.get("status","unknown"));modal_notice=notice
 queue_redraw()
func transact(kind:String,value,confirmed=false):
 if busy or world==null:return
 busy=true
 var candidate=world.clone()
 var result:Dictionary=candidate.step(value,confirmed) if kind=="step" else candidate.act(str(value))
 if result.get("confirm",false):
  busy=false;walk.clear();pending=value;pending_revision=revision;pending_origin=world.pos;pending_floor=world.floor_number;pending_token=world.tile(world.pos+value);modal="confirm";notice=str(result.get("message","确认行动？"));queue_redraw();return
 if not result.get("changed",false):
  if result.get("options") is Array and not result.options.is_empty():choices=result.options;modal="choices"
  busy=false;walk.clear();notice=str(result.get("message","这条路现在走不通。"));modal_notice=notice;queue_redraw();return
 var r:Dictionary=await store.commit(candidate.save_data(),revision)
 busy=false
 if not r.get("ok",false):
  walk.clear();notice="保存未确认，画面未前进：%s。按L核对已存旅程。"%str(r.get("status","unknown"));queue_redraw();return
 world=candidate;revision=int(r.revision);records=r.get("records",records);modal="";modal_notice="";notice=str(result.get("message",""));center_camera()
 if result.get("battle") is Dictionary:
  battle=result.battle;battle_time=2.4;walk.clear()
 if str(value).begins_with("case_") and kind=="act":open_case();modal_notice=notice
 if str(value).begins_with("tactic_") and kind=="act":open_build();modal_notice=notice
 if world.ended:
  await settle_run()
 queue_redraw()
func settle_run():
 if busy or world==null:return
 busy=true;walk.clear()
 var r:Dictionary=await store.finish(world.save_data(),revision)
 busy=false
 if r.get("ok",false):revision=int(r.revision);records=r.get("records",records);modal="ended"
 else:notice="结算未写入：%s。可以重试，不会重复登记。"%str(r.get("status","unknown"));modal="finish_retry"
func map_click(target:Vector2i):
 if busy or world==null or world.ended or modal!="":return
 walk.clear()
 var delta:Vector2i=target-world.pos
 if absi(delta.x)+absi(delta.y)==1:
  choices=world.options(target)
  if not choices.is_empty():modal="choices";modal_notice="";return
  await transact("step",delta);return
 if world.tile(target)==".":
  walk=world.safe_path(target);walk_time=0.0
  if walk.is_empty():notice="没有完全安全的路线。不会自动跨过怪物、物品、门或楼梯。"
 else:notice="先靠近到正交相邻格，再点击互动。"
func _process(delta):
 hover=screen_tile(get_global_mouse_position())
 battle_time=maxf(0.0,battle_time-delta)
 if not walk.is_empty() and not busy and modal=="" and world!=null:
  walk_time+=delta
  if walk_time>=0.13:
   walk_time=0
   var next:Vector2i=walk.pop_front()
   if world.tile(next)!="." or absi(next.x-world.pos.x)+absi(next.y-world.pos.y)!=1:walk.clear()
   else:await transact("step",next-world.pos)
 queue_redraw()
func _unhandled_input(event):
 if battle_time>0 and ((event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed)):
  battle_time=0;return
 if event is InputEventMouseMotion:
  hover=screen_tile(event.position)
  if drag:camera=drag_camera-Vector2i(((event.position-drag_origin)/CELL).round());camera.x=clampi(camera.x,0,4);camera.y=clampi(camera.y,0,4)
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_RIGHT:
   drag=event.pressed;drag_origin=event.position;drag_camera=camera;walk.clear();return
  if event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return
  walk.clear()
  if busy:return
  var p=event.position
  if modal=="build":
   if Rect2(910,687,250,45).has_point(p):modal="";return
   for i in choices.size():
    if Rect2(665,275+i*74,495,65).has_point(p):await transact("act",choices[i].id);return
   return
  if modal=="case":
   if Rect2(1035,710,150,42).has_point(p):modal="";return
   for i in choices.size():
    if Rect2(645,480+i*44,540,40).has_point(p):await transact("act",choices[i].id);return
   return
  if modal!="":
   if Rect2(280,575,330,48).has_point(p):await confirm_modal();return
   if Rect2(650,575,330,48).has_point(p):
    if modal=="start":get_tree().change_scene_to_file("res://main.tscn")
    else:modal=""
    return
   if modal=="choices":
    for i in choices.size():
     if Rect2(280,215+i*52,720,48).has_point(p):await transact("act",choices[i].id);return
   return
  if Rect2(768,562,476,24).has_point(p):open_build();return
  if Rect2(768,587,476,24).has_point(p):open_case();return
  if Rect2(768,662,220,44).has_point(p):center_camera();return
  if Rect2(1000,662,244,44).has_point(p):modal="ranking";return
  if Rect2(768,714,220,44).has_point(p):modal="new";return
  if Rect2(1000,714,244,44).has_point(p):get_tree().change_scene_to_file("res://main.tscn");return
  if Rect2(768,610,476,42).has_point(p):modal="retire";return
  await map_click(screen_tile(p))
 if event is InputEventKey and event.pressed and not event.echo:
  walk.clear()
  if busy:return
  if event.keycode==KEY_L:await reload_run();return
  if modal!="":
   if event.keycode==KEY_ESCAPE:
    if modal=="start":get_tree().change_scene_to_file("res://main.tscn")
    else:modal=""
   elif event.keycode==KEY_ENTER:await confirm_modal()
   elif modal in ["choices","case","build"] and event.keycode>=KEY_1 and event.keycode<KEY_1+choices.size():await transact("act",choices[event.keycode-KEY_1].id)
   return
  if event.keycode==KEY_SPACE:center_camera();return
  if event.keycode==KEY_N:modal="new";return
  if event.keycode==KEY_Q:open_case();return
  if event.keycode==KEY_B:open_build();return
  if world==null or world.ended:return
  match event.keycode:
   KEY_W,KEY_UP:await transact("step",Vector2i.UP)
   KEY_S,KEY_DOWN:await transact("step",Vector2i.DOWN)
   KEY_A,KEY_LEFT:await transact("step",Vector2i.LEFT)
   KEY_D,KEY_RIGHT:await transact("step",Vector2i.RIGHT)
   KEY_E:
    choices=world.options(hover)
    if choices.is_empty():
     for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
      choices=world.options(world.pos+direction)
      if not choices.is_empty():break
    if not choices.is_empty():modal="choices"
   KEY_N:modal="new"
func confirm_modal():
 match modal:
  "start","new","ended":await start_run(randi_range(0,2147483647))
  "confirm":
   modal=""
   if world==null or revision!=pending_revision or world.pos!=pending_origin or world.floor_number!=pending_floor or world.tile(world.pos+pending)!=pending_token:
    notice="位置或旅程已变化，请重新查看目标再确认。";return
   await transact("step",pending,true)
  "retire":modal="";await transact("act","retire")
  "finish_retry":await settle_run()
  _:modal=""
func draw_hero(c:Vector2):
 var stance="none"
 if world!=null and world.has_method("build_view"):stance=str(world.build_view().get("stance","none"))
 stance={"brace":"guard","reap":"harvest"}.get(stance,stance)
 Actors.draw_hero(self,c,stance,64)
func draw_token(c:Vector2,t:String):
 if t in ["g","b","w","V"]:
  Actors.draw_enemy(self,c,t,64);return
 if t=="C":
  panel(Rect2(c+Vector2(-23,-17),Vector2(46,38)),Color("94724e"))
  draw_rect(Rect2(c+Vector2(-23,-17),Vector2(46,38)),GOLD,false,3)
  panel(Rect2(c+Vector2(-4,-19),Vector2(8,42)),Color("ded4af"))
  draw_circle(c+Vector2(0,2),8,Color("bc6b68"));draw_line(c+Vector2(-4,2),c+Vector2(4,2),GOLD,2)
  return
 if t=="b":
  draw_colored_polygon(PackedVector2Array([c+Vector2(-27,-7),c+Vector2(-11,-22),c+Vector2(0,-12),c+Vector2(11,-22),c+Vector2(27,-7),c+Vector2(16,11),c+Vector2(0,20),c+Vector2(-16,11)]),Color("bb9771"))
  draw_circle(c+Vector2(-8,-3),4,Color("172735"));draw_circle(c+Vector2(8,-3),4,Color("172735"))
  draw_line(c+Vector2(-20,19),c+Vector2(20,19),Color("a9bec9"),4)
  draw_colored_polygon(PackedVector2Array([c+Vector2(17,13),c+Vector2(29,19),c+Vector2(17,25)]),INK)
  return
 if t=="w":
  draw_colored_polygon(PackedVector2Array([c+Vector2(0,-29),c+Vector2(-16,-9),c+Vector2(-25,26),c+Vector2(0,18),c+Vector2(25,26),c+Vector2(16,-9)]),Color("8b718f"))
  panel(Rect2(c+Vector2(-7,-12),Vector2(14,12)),Color("172735"));draw_line(c+Vector2(-4,-7),c+Vector2(4,-7),TEAL,3)
  draw_line(c+Vector2(23,-15),c+Vector2(23,25),GOLD,3);draw_circle(c+Vector2(23,-21),6,TEAL)
  return
 if t=="g" and world!=null and world.rule_version()>=2:
  draw_colored_polygon(PackedVector2Array([c+Vector2(-25,-16),c+Vector2(-9,-27),c+Vector2(9,-27),c+Vector2(25,-16),c+Vector2(19,26),c+Vector2(-19,26)]),Color("647b8c"))
  draw_line(c+Vector2(-9,-11),c+Vector2(9,-11),GOLD,3)
  draw_colored_polygon(PackedVector2Array([c+Vector2(-23,0),c+Vector2(8,0),c+Vector2(8,21),c+Vector2(-7,30),c+Vector2(-23,21)]),Color("496b7b"))
  draw_line(c+Vector2(-18,5),c+Vector2(3,23),GOLD,3);draw_line(c+Vector2(25,-23),c+Vector2(25,27),INK,4)
  return
 if Symbols.draw_icon(self,t,Rect2(c-Vector2(29,29),Vector2(58,58))):return
 match t:
  "#":panel(Rect2(c-Vector2(28,28),Vector2(56,56)),Color("293b4b"));draw_line(c+Vector2(-25,-19),c+Vector2(25,-19),Color("3c5160"),2)
  "k":draw_circle(c+Vector2(-7,0),7,GOLD,false,3);draw_line(c,c+Vector2(18,0),GOLD,3);draw_line(c+Vector2(13,0),c+Vector2(13,7),GOLD,3)
  "h":draw_circle(c+Vector2(0,6),15,TEAL);panel(Rect2(c-Vector2(6,20),Vector2(12,20)),TEAL);draw_line(c+Vector2(-6,7),c+Vector2(6,7),INK,3)
  "a","d":draw_colored_polygon(PackedVector2Array([c+Vector2(0,-21),c+Vector2(13,0),c+Vector2(0,21),c+Vector2(-13,0)]),Color("df888a") if t=="a" else Color("83b5da"))
  "D","L":panel(Rect2(c-Vector2(19,25),Vector2(38,50)),Color("936e44"));draw_rect(Rect2(c-Vector2(15,21),Vector2(30,42)),GOLD,false,3);draw_circle(c+Vector2(8,3),4,Color("18222e"))
  "<",">":
   for i in 4:panel(Rect2(c+Vector2(-23,14-i*10),Vector2(32-i*4,7)),TEAL)
   text(c+Vector2(11,7),"↑" if t==">" else "↓",27,GOLD)
  "S":
   panel(Rect2(c-Vector2(21,24),Vector2(42,48)),Color("4d466c"))
   for i in 3:draw_circle(c+Vector2(0,-14+i*14),5,[GOLD,TEAL,INK][i])
  ".":pass
  _:
   var big=t in ["V","B","K","Z"]
   if big:
    draw_colored_polygon(PackedVector2Array([c+Vector2(-28,-18),c+Vector2(-16,-24),c+Vector2(16,-24),c+Vector2(28,-18),c+Vector2(23,24),c+Vector2(0,31),c+Vector2(-23,24)]),Color("a57a62"))
    panel(Rect2(c+Vector2(-16,-23),Vector2(32,27)),Color("647b8c"))
    draw_line(c+Vector2(-10,-10),c+Vector2(-4,-10),GOLD,4);draw_line(c+Vector2(4,-10),c+Vector2(10,-10),GOLD,4)
    draw_colored_polygon(PackedVector2Array([c+Vector2(-16,7),c+Vector2(16,7),c+Vector2(12,24),c+Vector2(0,31),c+Vector2(-12,24)]),Color("344b5b"))
    draw_line(c+Vector2(0,10),c+Vector2(0,24),GOLD,3)
    return
   var col=Color("8ba775")
   draw_colored_polygon(PackedVector2Array([c+Vector2(-24,-21),c+Vector2(-10,-13),c+Vector2(0,-24),c+Vector2(10,-13),c+Vector2(24,-21),c+Vector2(21,19),c+Vector2(0,27),c+Vector2(-21,19)]),col)
   draw_line(c+Vector2(-14,-4),c+Vector2(-4,0),Color("172735"),4);draw_line(c+Vector2(4,0),c+Vector2(14,-4),Color("172735"),4)
   if big:draw_colored_polygon(PackedVector2Array([c+Vector2(0,-16),c+Vector2(8,0),c+Vector2(0,16),c+Vector2(-8,0)]),GOLD)
func _draw():
 panel(Rect2(0,0,1280,800),Color("0b1420"));text(Vector2(24,40),"无尽远征",27,GOLD);text(Vector2(210,39),"15×15 · 大图探索 · 独立旅程",17,TEAL)
 if world==null:
  draw_wrapped(notice,Vector2(60,180),1100,22)
  text(Vector2(60,260),"L重试读取；N明确开始新局。",18,TEAL)
  panel(Rect2(1000,714,244,44),Color("293e50"));text(Vector2(1012,742),"返回经典魔塔",18)
  if modal!="":draw_modal()
  return
 text(Vector2(768,34),"第 %d 层 · 已抵达 %d 层"%[world.floor_number,world.max_floor],21,GOLD)
 text(Vector2(768,59),"种子 %d · 规则 v%d · 持续生成"%[world.seed,int(world.rule_version())],14,TEAL)
 panel(Rect2(20,68,712,712),Color("182a39"))
 for y in VIEW:
  for x in VIEW:
   var p=Vector2i(x,y)+camera;var c=ORIGIN+Vector2(x,y)*CELL+Vector2(32,32)
   panel(Rect2(c-Vector2(31,31),Vector2(62,62)),Color("152432") if (p.x+p.y)%2==0 else Color("192a38"))
   draw_token(c,world.tile(p))
 for p in walk:
  var screen=Vector2(p-camera)
  if screen.x>=0 and screen.y>=0 and screen.x<VIEW and screen.y<VIEW:draw_circle(ORIGIN+screen*CELL+Vector2(32,32),4,TEAL)
 var hero=world.pos-camera
 if hero.x>=0 and hero.y>=0 and hero.x<VIEW and hero.y<VIEW:
  var c=ORIGIN+Vector2(hero)*CELL+Vector2(32,32)
  draw_hero(c);draw_rect(Rect2(c-Vector2(30,30),Vector2(60,60)),TEAL,false,2)
 panel(Rect2(752,72,504,704))
 var stats=[["生命",world.hp],["攻击",world.atk],["防御",world.defense],["金币",world.gold],["钥匙",world.keys],["击杀",world.kills]]
 for i in stats.size():
  var p=Vector2(768+(i%3)*160,96+(i/3)*72)
  text(p,str(stats[i][0]),15,TEAL);text(p+Vector2(0,29),str(stats[i][1]),25)
 var overview:Dictionary=world.summary() if world.has_method("summary") else {}
 if not overview.is_empty():
  text(Vector2(768,239),str(overview.get("layout","双路线远征")),17,GOLD)
 else:
  var entrance_y=1 if world.floor_number%2==1 else 13
  var training=Vector2i(2 if entrance_y==1 else 12,entrance_y)
  var supply=Vector2i(3 if entrance_y==1 else 11,entrance_y)
  text(Vector2(768,239),"训练%s · 补给%s · 关隘%s"%["✓" if world.tile(training)=="." else "□","✓" if world.tile(supply)=="." else "□","✓" if world.tile(Vector2i(3,7))=="." else "□"],17,GOLD)
 for y in 15:
  for x in 15:
   var t=world.tile(Vector2i(x,y));var color=Color("344655") if t=="#" else Color("14212d")
   if t in ["<",">"]:color=TEAL
   elif t in ["D","$","T"]:color=GOLD
   elif t not in ["#","."]:color=Color("ab7970")
   panel(Rect2(768+x*11,264+y*11,10,10),color)
 draw_rect(Rect2(Vector2(768,264)+Vector2(camera)*11,Vector2(121,121)),INK,false,1)
 draw_circle(Vector2(773,269)+Vector2(world.pos)*11,4,TEAL)
 draw_wrapped("WASD / 方向键移动\n点击邻格拾取、战斗或互动\n点击空地仅走安全路径\n右键拖动地图，空格回到角色
概览：红=互动/敌人
金=门/宝物，青=楼梯",Vector2(950,280),282,16,INK,8)
 if not overview.is_empty():
  var line_y=456
  for route in overview.get("routes",[]):
   text(Vector2(768,line_y),"%s：%s · +%d金"%[str(route.get("label","路线")),("净损%d生命"%int(route.get("net_damage",route.get("damage",0))) if route.get("survivable",true) else "当前会致死") if route.get("valid",false) else "不能破防",int(route.get("gold",0))],15,GOLD)
   line_y+=21
  text(Vector2(768,line_y),"仅计剩余守卫；安全空地寻路不会自动战斗。",12,TEAL)
  draw_wrapped(str(overview.get("cargo","")),Vector2(768,line_y+22),468,14,INK,2)
  draw_wrapped(notice,Vector2(768,554),468,13,TEAL,1)
 else:draw_wrapped(notice,Vector2(768,463),468,16,TEAL,6)
 var labels=["结束本局并记入本设备榜","回到角色 · Space","本设备历史榜","重新开始 · N","返回经典魔塔"]
 var rects=[Rect2(768,610,476,42),Rect2(768,662,220,44),Rect2(1000,662,244,44),Rect2(768,714,220,44),Rect2(1000,714,244,44)]
 for i in rects.size():panel(rects[i],Color("293e50"));text(rects[i].position+Vector2(12,28),labels[i],16)
 text(Vector2(24,796),"视窗 (%d,%d) · 自动保存 · 经典存档独立保留"%[camera.x,camera.y],13,TEAL)
 if world.has_method("build_view"):
  text(Vector2(768,579),"B · 英雄战术与遗物成长："+str(world.build_view().get("title","")),13,GOLD)
 if world.has_method("case_view"):
  text(Vector2(768,599),"Q · 信使历史路线图与回访线索",13,GOLD)
 if modal!="":draw_modal()
 elif hover.x>=0 and hover.y>=0 and not busy:
  var info:Dictionary=world.preview(hover)
  var content=str(info.get("title",""))
  for line in info.get("lines",[]):
   if str(line)!=str(info.get("title","")):content+="\n"+str(line)
  if content!="":
   var anchor=ORIGIN+Vector2(hover-camera)*CELL+Vector2(66,8)
   anchor.x=clampf(anchor.x,30,935);anchor.y=clampf(anchor.y,80,560)
   var rows=1;var partial=""
   for ch in content:
    if ch=="\n" or font.get_string_size(partial+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>290:rows+=1;partial=""
    if ch!="\n":partial+=ch
   var height=mini(205,22+rows*21)
   panel(Rect2(anchor,Vector2(315,height)),Color("07121c"));draw_rect(Rect2(anchor,Vector2(315,height)),TEAL,false,1);draw_wrapped(content,anchor+Vector2(12,23),290,15,INK,8)
 if battle_time>0:
  panel(Rect2(150,220,560,250),Color("252432"));text(Vector2(180,258),"战斗结算",23,GOLD)
  draw_hero(Vector2(260,332));draw_token(Vector2(585,332),str(battle.get("token","g")))
  var strike=Vector2(310,330).lerp(Vector2(540,330),clampf((2.4-battle_time)/1.2,0,1))
  draw_line(strike-Vector2(12,17),strike+Vector2(12,-17),GOLD,4)
  draw_wrapped("%s · %d击 · 损失%d生命"%[str(battle.get("title","敌人")),int(battle.get("rounds",0)),int(battle.get("damage",0))],Vector2(180,407),500,17,INK,2)
  if battle.has("heal_after"):
   text(Vector2(180,435),"实际承伤%d · 胜后恢复%d · 净损耗%d"%[int(battle.damage),int(battle.heal_after),int(battle.get("net_damage",battle.damage))],14,TEAL)
  text(Vector2(180,457),"示意动画，结算仅一次 · 点击或按键跳过",13,TEAL)
 if busy:panel(Rect2(380,15,370,43),Color("293e50"));text(Vector2(397,43),"正在安全保存，请稍候……",18,GOLD)
func draw_modal():
 if modal=="case":draw_case();return
 if modal=="build":draw_build();return
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.70));panel(Rect2(245,145,790,505),Color("152736"))
 var title="确认"
 var body=notice
 match modal:
  "start":title="踏入更深的塔";body="15×15地图，安全寻路与相邻点击。新局使用v4：先取训练，再比较重甲短路与轻敌长路的损伤。封存补给可立即使用，也可承担两层运输委托；中途允许拆封。强敌宝库可成长后回访。第四层商人处有可推理的信使奇遇，Q查看历史图。B查看英雄战术，在商人旁切换；训练上限3级，遗物可额外提高2级。旧v1/v2/v3旅程按原规则继续。无尽模式独立保存，不替换经典旅程。首版数值安全界限100万层、10万动作，达到动作界限仍可结算。"
  "new":title="重新开始无尽旅程？";body="会替换当前无尽旅程。经典魔塔存档与已结算的本设备历史榜保留。"
  "retire":title="结束并结算本局？";body="结算后不能继续这次无尽旅程，成绩只保存在本设备。不是公开全球排名。"
  "ranking":title="本设备历史榜";body="仅本设备可见，不上传服务器；v1与v2规则不同，标注版本，不代表同难度竞技。"
  "ended":title="本次远征结束";body="成绩已保存到本设备历史榜。下一次仍有不同路线与成长选择。"
  "finish_retry":title="结算等待重试"
  "choices":title="选择行动";body=""
 text(Vector2(280,190),title,26,GOLD)
 if modal=="choices":
  for i in mini(6,choices.size()):panel(Rect2(280,215+i*52,720,48),Color("2a4051"));draw_wrapped("%d  %s"%[i+1,str(choices[i].label)],Vector2(293,241+i*52),690,16,INK,2)
 elif modal=="ranking":
  draw_wrapped(body,Vector2(280,230),710,16,TEAL,2)
  for i in mini(8,records.size()):
   var record:Dictionary=records[i]
   draw_wrapped("%d.  v%d · 第%d层 · 击杀%d · 金币%d"%[i+1,int(record.get("rule_version",1)),int(record.get("max_floor",1)),int(record.get("kills",0)),int(record.get("gold",0))],Vector2(280,285+i*32),710,16,INK,1)
 else:draw_wrapped(body,Vector2(280,245),710,20,INK,11)
 if modal_notice!="" and modal in ["choices","new","start"]:draw_wrapped(modal_notice,Vector2(280,535),710,15,Color("efb18e"),2)
 panel(Rect2(280,575,330,48),Color("365347"));text(Vector2(300,606),"确认 / Enter" if modal not in ["ranking","choices"] else "关闭",18)
 panel(Rect2(650,575,330,48),Color("384152"));text(Vector2(670,606),"取消 / Esc",18)
func open_case():
 if world==null or not world.has_method("case_view"):
  notice="这段旧规则旅程没有信使事件。新局使用新版规则。";return
 walk.clear();choices.clear()
 for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
  for option in world.options(world.pos+d):
   if str(option.id).begins_with("case_") and not choices.any(func(x):return x.id==option.id):choices.append(option)
 modal="case";modal_notice="";queue_redraw()
func draw_case():
 var data:Dictionary=world.case_view()
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.8));panel(Rect2(75,65,1130,700),Color("152736"))
 text(Vector2(100,109),str(data.get("title","失踪信使 · 出发时路线图")),27,GOLD)
 draw_wrapped("这是信使出发时的记录，不是玩家清理后的现场。",Vector2(100,145),1050,17,TEAL,2)
 var cells:Array=data.get("grid",[])
 for y in cells.size():
  for x in cells[y].size():
   var c=Vector2(125+x*60,205+y*60)
   panel(Rect2(c-Vector2(28,28),Vector2(56,56)),Color("263c4b"))
   draw_case_token(c,str(cells[y][x]))
 var rule_text=""
 for rule in data.get("rules",[]):rule_text+=str(rule).replace("从s出发","从旗帜营地出发").replace("钟楼T","钟楼").replace("D锁门和g守卫","锁门和守卫").replace("水井W","水井").replace("墙#","黑墙").replace("A/B/C是三个候选地点","仓库／庭院／驿站是三个候选地点")+"\n"
 if rule_text=="":rule_text="前往第4层商人营地，阅读失踪信使的记录。"
 draw_wrapped(rule_text,Vector2(645,203),530,18,INK,6)
 draw_wrapped(str(data.get("status","调查时可以对照路线图，先排除不符合线索的地点。")),Vector2(645,359),530,17,TEAL,4)
 for i in mini(5,choices.size()):
  panel(Rect2(645,480+i*44,540,40),Color("2a4051"))
  draw_wrapped("%d  %s"%[i+1,str(choices[i].label)],Vector2(655,505+i*44),515,15,INK,1)
 if choices.is_empty():draw_wrapped("当前没有可执行的事件行动，请查看上方进度条件。" if data.get("available",false) else "这里只读查看。调查、选择或领奖请回第4层商人旁。",Vector2(645,500),530,17,GOLD,3)
 text(Vector2(100,629),"旗帜=起点  钟楼=必经  水井=禁行",14,TEAL)
 text(Vector2(100,652),"锁门/守卫不可过；仓/庭/驿是待调查地点。",14,TEAL)
 draw_wrapped(modal_notice,Vector2(100,689),510,14,Color("efb18e"),3)
 panel(Rect2(1035,710,150,42),Color("384152"));text(Vector2(1050,737),"关闭 · Esc",17)
func draw_case_token(c:Vector2,t:String):
 match t:
  "#":panel(Rect2(c-Vector2(27,27),Vector2(54,54)),Color("0b1420"))
  ".":draw_circle(c,3,TEAL)
  "s":
   draw_line(c+Vector2(-8,-23),c+Vector2(-8,24),INK,3)
   draw_colored_polygon(PackedVector2Array([c+Vector2(-8,-23),c+Vector2(23,-16),c+Vector2(-8,-4)]),TEAL)
  "T":
   panel(Rect2(c+Vector2(-15,-21),Vector2(30,46)),Color("647b8c"))
   draw_circle(c+Vector2(0,-9),11,GOLD);draw_line(c+Vector2(0,-9),c+Vector2(0,-17),Color("172735"),2);draw_line(c+Vector2(0,-9),c+Vector2(6,-5),Color("172735"),2)
  "W":
   draw_circle(c+Vector2(0,7),21,Color("647b8c"));draw_circle(c+Vector2(0,7),13,Color("194a66"))
   draw_line(c+Vector2(-22,-19),c+Vector2(22,-19),GOLD,4);draw_line(c+Vector2(-18,-19),c+Vector2(-18,15),GOLD,3);draw_line(c+Vector2(18,-19),c+Vector2(18,15),GOLD,3)
  "A":
   panel(Rect2(c+Vector2(-20,-5),Vector2(40,27)),Color("94724e"))
   draw_colored_polygon(PackedVector2Array([c+Vector2(-25,-6),c+Vector2(0,-24),c+Vector2(25,-6)]),GOLD)
   text(c+Vector2(-16,16),"仓",16,INK)
  "B":
   draw_circle(c,22,Color("566e57"));draw_circle(c,13,TEAL,false,3);text(c+Vector2(-8,7),"庭",16,INK)
  "C":
   draw_colored_polygon(PackedVector2Array([c+Vector2(-25,23),c+Vector2(0,-24),c+Vector2(25,23)]),Color("8b718f"));text(c+Vector2(-8,15),"驿",16,INK)
  _:
   draw_token(c,t)
func open_build():
 if world==null or not world.has_method("build_view"):
  notice="这段旧规则旅程没有战术槽，新局可体验新版构筑。";return
 walk.clear();var info:Dictionary=world.build_view();choices=info.get("options",[])
 modal="build";modal_notice="";queue_redraw()
func draw_build():
 var info:Dictionary=world.build_view()
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.8));panel(Rect2(95,85,1090,665),Color("152736"))
 text(Vector2(125,132),"英雄战术 · 改变出手方式，而不只是加数值",25,GOLD)
 text(Vector2(125,172),"当前："+str(info.get("title","旅行者")),21,TEAL)
 draw_hero(Vector2(245,282))
 var details=str(info.get("description",""))
 if info.get("effects") is Array:
  details+="\n"+"\n".join(info.effects)
 draw_wrapped(details,Vector2(125,339),485,16,INK,6)
 text(Vector2(125,492),"普通训练 %d / 3"%int(info.get("training_level",1)),20,GOLD)
 text(Vector2(125,528),"遗物加成 +%d / 2"%int(info.get("relic_bonus",0)),20,TEAL)
 text(Vector2(125,564),"当前有效等级 %d / 5"%int(info.get("effective_level",1)),22,INK)
 draw_wrapped("普通成长有上限，宝库遗物可以突破。收割必须先活过战斗，战后回复不能救回致死伤害。",Vector2(125,617),485,16,TEAL,4)
 text(Vector2(665,211),"商人营地可免费切换",21,GOLD)
 if choices.is_empty():
  draw_wrapped("现在只能查看。靠近商人后再按B切换；已结束旅程不可改动。",Vector2(665,290),485,18,INK,4)
  draw_wrapped("破甲：降低敌方防御\n架盾：削减首次反击\n收割：胜利后返还部分损伤\n不同怪物与路线可能适合不同战术。",Vector2(665,410),485,18,TEAL,6)
 else:
  for i in mini(5,choices.size()):
   panel(Rect2(665,275+i*74,495,65),Color("2a4051"))
   draw_wrapped("%d  %s"%[i+1,str(choices[i].label)],Vector2(677,301+i*74),470,17,INK,2)
 draw_wrapped(modal_notice,Vector2(665,656),485,14,Color("efb18e"),2)
 panel(Rect2(910,687,250,45),Color("384152"));text(Vector2(930,717),"关闭 · Esc",18)
