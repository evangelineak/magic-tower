extends Node2D
# A separate mode and storage namespace: the classic journey is untouched.
const Enemies7=preload("res://scripts/endless_enemy_v7_art.gd")
const GearArt=preload("res://scripts/endless_gear_art.gd")
const Props=preload("res://scripts/endless_interaction_art.gd")
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
   if world!=null and world.rule_version()<WorldType.CURRENT_VERSION:notice="继续规则v%d；新版v%d内容需明确新开局。" % [world.rule_version(),WorldType.CURRENT_VERSION]
   if world!=null and world.ended:modal="ended" if r.get("status")=="finished" else "finish_retry"
  else:modal="start";notice="全新的15×15连续远征，与经典旅程分开保存。"
 else:
  notice="读取失败：%s。没有覆盖存档。按L重试。"%str(r.get("status","unknown"))
  if str(r.get("status","")) in ["empty","missing"]:modal="start";revision=int(r.get("revision",0))
 center_camera();queue_redraw()
func start_run(seed_value:int,rule_version:int=0):
 if busy:return
 busy=true;walk.clear()
 var candidate=WorldType.new_run(seed_value,WorldType.CURRENT_VERSION if rule_version==0 else rule_version)
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
 if result.get("confirm",false) and kind=="act" and str(value)=="job_cancel":
  busy=false;walk.clear();pending_revision=revision;pending_origin=world.pos;pending_floor=world.floor_number;modal="confirm_job";notice=str(result.get("message","取消委托会损失12金币押金。"));queue_redraw();return
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
 if str(value).begins_with("enc_") and kind=="act":open_supply_panel("encounter");modal_notice=notice
 if str(value).begins_with("job_") and kind=="act":open_supply_panel("contract");modal_notice=notice
 if (str(value).begins_with("buy_") or str(value).begins_with("gear_")) and kind=="act":open_supply_panel("gear");modal_notice=notice
 if str(value).begins_with("arm_") and kind=="act":open_supply_panel("items");modal_notice=notice
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
  if modal=="growth":
   if Rect2(910,687,250,45).has_point(p):modal=""
   return
  if modal in ["encounter","contract"] and world!=null and world.has_method("contract_view"):
   if Rect2(160,102,250,38).has_point(p):open_supply_panel("encounter");return
   if Rect2(430,102,250,38).has_point(p):open_supply_panel("contract");return
  if modal in ["items","gear"] and world!=null and world.has_method("gear_view"):
   if Rect2(160,102,250,38).has_point(p):open_supply_panel("items");return
   if Rect2(430,102,250,38).has_point(p):open_supply_panel("gear");return
  if modal in ["encounter","contract","items","gear"]:
   if Rect2(910,687,250,45).has_point(p):modal="";return
   for i in choices.size():
    if Rect2(185,425+i*70,910,62).has_point(p):await transact("act",choices[i].id);return
   return
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
  if Rect2(950,396,138,32).has_point(p):open_supply_panel("encounter");return
  if Rect2(1096,396,138,32).has_point(p):open_supply_panel("items");return
  if Rect2(950,354,284,32).has_point(p) and world!=null and world.has_method("growth_view"):open_growth();return
  if Rect2(768,562,476,24).has_point(p):open_build();return
  if Rect2(768,587,476,24).has_point(p):open_case();return
  if Rect2(768,662,220,44).has_point(p):
   if world!=null and world.has_method("camp_return_view"):await start_camp_return()
   else:center_camera()
   return
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
   if event.keycode==KEY_TAB and modal in ["encounter","contract"] and world!=null and world.has_method("contract_view"):
    open_supply_panel("contract" if modal=="encounter" else "encounter");return
   if event.keycode==KEY_TAB and modal in ["items","gear"] and world!=null and world.has_method("gear_view"):
    open_supply_panel("gear" if modal=="items" else "items");return
   if event.keycode==KEY_ESCAPE:
    if modal=="start":get_tree().change_scene_to_file("res://main.tscn")
    else:modal=""
   elif event.keycode==KEY_ENTER:await confirm_modal()
   elif modal in ["choices","case","build","encounter","contract","items","gear"] and event.keycode>=KEY_1 and event.keycode<KEY_1+choices.size():await transact("act",choices[event.keycode-KEY_1].id)
   return
  if event.keycode==KEY_T:await start_camp_return();return
  if event.keycode==KEY_SPACE:center_camera();return
  if event.keycode==KEY_N:modal="new";return
  if event.keycode==KEY_Q:open_case();return
  if event.keycode==KEY_B:open_build();return
  if event.keycode==KEY_G:open_growth();return
  if event.keycode==KEY_H:modal="help";return
  if event.keycode==KEY_R:open_supply_panel("encounter");return
  if event.keycode==KEY_I:open_supply_panel("items");return
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
  "confirm_job":
   modal=""
   if world==null or revision!=pending_revision or world.pos!=pending_origin or world.floor_number!=pending_floor:
    notice="旅程状态已变化，请重新查看委托再确认取消。";return
   await transact("act","job_cancel!")
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
 if Enemies7.draw_enemy(self,c,t,64):return
 if t in ["g","b","w","V"]:
  Actors.draw_enemy(self,c,t,64);return
 if Props.draw_token(self,c,t,64):return
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
 if world.has_method("gear_view"):
  stats[1][0]="常驻攻击";stats[2][0]="常驻防御"
 for i in stats.size():
  var p=Vector2(768+(i%3)*160,96+(i/3)*72)
  text(p,str(stats[i][0]),15,TEAL);text(p+Vector2(0,29),str(stats[i][1]),25)
 if world.has_method("gear_view"):
  var combat:Dictionary=world.gear_view()
  text(Vector2(928,147),"实战 %d" % int(combat.effective_atk),14,TEAL)
  text(Vector2(1088,147),"实战 %d" % int(combat.effective_def),14,TEAL)
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
 draw_wrapped("WASD / 方向键移动\n点击邻格互动，远处安全寻路\n右拖地图，空格回到角色\nH查看玩法；金=宝物，青=楼梯",Vector2(950,280),282,16,INK,5)
 if world.has_method("growth_view"):
  panel(Rect2(950,354,284,32),Color("365347"));text(Vector2(958,376),"G 成长 / 全旅程预算",15,GOLD)
 if world.has_method("encounter_view"):
  panel(Rect2(950,396,138,32),Color("293e50"));text(Vector2(958,418),"R 遭遇/订单" if world.has_method("contract_view") else "R 营地遭遇",15,GOLD)
  panel(Rect2(1096,396,138,32),Color("293e50"));text(Vector2(1104,418),"I 道具/装备" if world.has_method("gear_view") else "I 战斗道具",15,GOLD)
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
 if world.has_method("camp_return_view"):labels[1]=camp_button_label(world.camp_return_view())
 var rects=[Rect2(768,610,476,42),Rect2(768,662,220,44),Rect2(1000,662,244,44),Rect2(768,714,220,44),Rect2(1000,714,244,44)]
 for i in rects.size():panel(rects[i],Color("293e50"));text(rects[i].position+Vector2(12,28),labels[i],16)
 text(Vector2(24,796),"视窗 (%d,%d) · 自动保存 · H玩法说明 · 经典存档独立保留"%[camera.x,camera.y],13,TEAL)
 if world.has_method("build_view"):
  panel(Rect2(768,562,476,22),Color("293e50"))
  text(Vector2(776,579),"B · 英雄战术与遗物成长："+str(world.build_view().get("title","")),13,GOLD)
 if world.has_method("case_view"):
  panel(Rect2(768,587,476,22),Color("293e50"))
  text(Vector2(776,604),"Q · 信使历史路线图与回访线索",13,GOLD)
 if modal!="":draw_modal()
 elif world.has_method("camp_return_view") and Rect2(768,662,220,44).has_point(get_global_mouse_position()):
  var camp_info:Dictionary=world.camp_return_view()
  var camp_text=camp_tooltip(camp_info)
  var camp_box=tooltip_layout(camp_text,Vector2(760,570))
  panel(camp_box,Color("07121c"));draw_rect(camp_box,TEAL,false,1)
  draw_wrapped(camp_text,camp_box.position+Vector2(12,23),camp_box.size.x-24,15,INK,14)
 elif hover.x>=0 and hover.y>=0 and not busy:
  var info:Dictionary=world.preview(hover)
  var content=str(info.get("title",""))
  for line in info.get("lines",[]):
   if str(line)!=str(info.get("title","")):content+="\n"+str(line)
  if content!="":
   var box=tooltip_layout(content,ORIGIN+Vector2(hover-camera)*CELL+Vector2(66,8))
   panel(box,Color("07121c"));draw_rect(box,TEAL,false,1)
   draw_wrapped(content,box.position+Vector2(12,23),box.size.x-24,15,INK,14)
 if battle_time>0:
  panel(Rect2(150,220,560,300),Color("252432"));text(Vector2(180,258),"战斗结算",23,GOLD)
  draw_hero(Vector2(260,332));draw_token(Vector2(585,332),str(battle.get("token","g")))
  var strike=Vector2(310,330).lerp(Vector2(540,330),clampf((2.4-battle_time)/1.2,0,1))
  draw_line(strike-Vector2(12,17),strike+Vector2(12,-17),GOLD,4)
  draw_wrapped("%s · %d击 · 损失%d生命"%[str(battle.get("title","敌人")).get_slice("：",0),int(battle.get("rounds",0)),int(battle.get("damage",0))],Vector2(180,407),500,17,INK,2)
  if battle.has("heal_after"):
   text(Vector2(180,435),"实际承伤%d · 胜后恢复%d · 净损耗%d"%[int(battle.damage),int(battle.heal_after),int(battle.get("net_damage",battle.damage))],14,TEAL)
  if battle.has("mechanic_note"):
   draw_wrapped(str(battle.mechanic_note),Vector2(180,461),500,15,GOLD,2)
  text(Vector2(180,507),"示意动画，结算仅一次 · 点击或按键跳过",13,TEAL)
 if busy:panel(Rect2(380,15,370,43),Color("293e50"));text(Vector2(397,43),"正在安全保存，请稍候……",18,GOLD)
func tooltip_layout(content:String,desired:Vector2)->Rect2:
 # Keep complete battle reasoning beside its tile, including narrow-view edges.
 var width:=360.0
 var rows:=1
 var partial:=""
 for ch in content:
  if ch=="\n":
   rows+=1;partial="";continue
  if font.get_string_size(partial+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>width-24:
   rows+=1;partial=""
  partial+=ch
 var height:=float(22+mini(rows,14)*21)
 return Rect2(Vector2(clampf(desired.x,20,1260-width),clampf(desired.y,70,780-height)),Vector2(width,height))

func draw_modal():
 if modal=="gear":draw_gear_panel();return
 if modal in ["encounter","contract","items"]:draw_supply_panel();return
 if modal=="growth":draw_growth();return
 if modal=="case":draw_case();return
 if modal=="build":draw_build();return
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.70));panel(Rect2(245,145,790,505),Color("152736"))
 var title="确认"
 var body=notice
 match modal:
  "start":title="第一次远征：先学会选择";body="1. 点击身旁的剑盾训练包，获得基础成长。\n2. 靠近篷车商人按B，免费选择战术；先看伤害再开战。\n3. 观察两条关隘路线，选择付得起代价的一条。\n\n点击邻格才互动，远处只沿安全空地寻路；强敌宝库可以留到成长后再来。\n\nH随时查看完整玩法。新局使用规则v%d，已有旧局不会偷偷改变规则。独立存档，不覆盖经典旅程。" % WorldType.CURRENT_VERSION
  "help":title="怎样让这趟远征走得更远";body="B：查看战术。仅在商人旁免费切换。普通训练最高3级，宝库遗物最多再加2级。\nR：本层营地遭遇，选择前看清代价；I：装备或收起一次性战斗道具。\nQ：查看信使历史图。第四层商人给出可推理的路线线索。\n封存箱：立即回复20生命，或保留运到两层后的商人换奖励；中途可拆封。\n门与宝库：钥匙换有价值的奖励，强敌可以回访，不必当场硬打。\n鼠标：邻格互动，远处空地安全寻路；右拖地图，空格回到角色。\nL重新读取；N明确重开。旧规则不自动升级。\n本设备榜不是全球榜。安全上限为100万层、10万动作。"

  "new":title="重新开始无尽旅程？";body="将创建规则v%d的新局，并替换当前无尽旅程。已有旅程不会自动升级；取消可继续旧局。经典魔塔存档与已结算的本设备历史榜保留。" % WorldType.CURRENT_VERSION
  "confirm_job":title="放弃委托并损失12金币押金？";body=notice+"\n仅放弃当前委托，不会结束整局。取消这个弹窗则保留委托。"
  "retire":title="结束并结算本局？";body="结算后不能继续这次无尽旅程，成绩只保存在本设备。不是公开全球排名。"
  "ranking":title="本设备历史榜";body="仅本设备可见，不上传服务器；不同规则版本难度不同，标注版本，不代表同难度竞技。"
  "ended":title="本次远征结束";body="成绩已保存到本设备历史榜。下一次仍有不同路线与成长选择。"
  "finish_retry":title="结算等待重试"
  "choices":title="选择行动";body=""
 if modal=="help" and world!=null and world.has_method("growth_view"):body=growth_help_text()
 if modal=="help" and world!=null and world.has_method("contract_view"):body=body.replace("R营地遭遇", "R遭遇/订单（Tab切换）")
 if modal=="help" and world!=null and world.has_method("gear_view"):body=body.replace("I道具", "I道具/装备（Tab切换）")
 if modal=="help" and world!=null and world.has_method("camp_return_view"):body=body.replace("右拖地图，空格回角色", "T安全回营（一次保存），空格回角色")
 text(Vector2(280,190),title,26,GOLD)
 if modal=="choices":
  for i in mini(6,choices.size()):panel(Rect2(280,215+i*52,720,48),Color("2a4051"));draw_wrapped("%d  %s"%[i+1,str(choices[i].label)],Vector2(293,241+i*52),690,16,INK,2)
 elif modal=="ranking":
  draw_wrapped(body,Vector2(280,230),710,16,TEAL,2)
  for i in mini(8,records.size()):
   var record:Dictionary=records[i]
   draw_wrapped("%d.  v%d · 第%d层 · 击杀%d · 金币%d"%[i+1,int(record.get("rule_version",1)),int(record.get("max_floor",1)),int(record.get("kills",0)),int(record.get("gold",0))],Vector2(280,285+i*32),710,16,INK,1)
 elif modal in ["help","start"]:draw_wrapped(body,Vector2(280,230),710,17,INK,14)
 else:draw_wrapped(body,Vector2(280,245),710,20,INK,11)
 if modal_notice!="" and modal in ["choices","new","start"]:draw_wrapped(modal_notice,Vector2(280,535),710,15,Color("efb18e"),2)
 panel(Rect2(280,575,330,48),Color("365347"));text(Vector2(300,606),"确认 / Enter" if modal not in ["ranking","choices","help"] else "关闭",18)
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
 text(Vector2(125,492),"战术训练 %d / 3"%int(info.get("training_level",1)),20,GOLD)
 text(Vector2(125,528),"遗物加成 +%d / 2"%int(info.get("relic_bonus",0)),20,TEAL)
 text(Vector2(125,564),"战术有效等级 %d / 5"%int(info.get("effective_level",1)),22,INK)
 draw_wrapped("战术训练有上限，宝库遗物可提高战术等级。收割必须先活过战斗，战后回复不能救回致死伤害。",Vector2(125,617),485,16,TEAL,4)
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

func open_supply_panel(kind:String):
 if world==null:return
 var view_method={"encounter":"encounter_view","contract":"contract_view","items":"item_view","gear":"gear_view"}.get(kind,"item_view")
 var option_method={"encounter":"encounter_options","contract":"contract_options","items":"item_options","gear":"gear_options"}.get(kind,"item_options")
 if not world.has_method(view_method):notice="此旧规则旅程没有这项内容；可继续旧局或明确新开局。";return
 walk.clear();choices=world.call(option_method) if world.has_method(option_method) else world.call(view_method).get("options",[]);modal=kind;modal_notice="";queue_redraw()
func draw_supply_panel():
 var data:Dictionary=world.call({"encounter":"encounter_view","contract":"contract_view","items":"item_view"}[modal])
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.70));panel(Rect2(120,85,1040,665),Color("152736"))
 var gear_tabs:bool=modal=="items" and world.has_method("gear_view")
 var tabbed:bool=(modal in ["encounter","contract"] and world.has_method("contract_view")) or gear_tabs
 if tabbed:
  for i in 2:
   var active:bool=(modal in ["encounter","items"] and i==0) or (modal=="contract" and i==1)
   panel(Rect2(160+i*270,102,250,38),Color("365347") if active else Color("293e50"))
   text(Vector2(174+i*270,128),(["消耗品","持久装备"] if gear_tabs else ["本层遭遇","路线委托"])[i],19,GOLD if active else INK)
  text(Vector2(725,128),"Tab 切换 · 预览不会购买/装备" if gear_tabs else "Tab 切换 · 不会自动接单",15,TEAL)
 var heading=str(data.get("title","营地选择"))
 if modal=="contract":heading=contract_heading(data)
 text(Vector2(160,180 if tabbed else 140),heading,26,GOLD)
 var body=contract_body(data) if modal=="contract" else str(data.get("body",data.get("description","")))
 draw_wrapped(body,Vector2(160,220 if tabbed else 185),950,19,INK,4 if tabbed else 7)
 var status:String=""
 if modal=="encounter":
  status=str(data.get("status",""))+"\n"+("本层机会已用完。" if data.get("resolved",false) else ("现在可选；一次选择，不是无限商店。" if data.get("available",false) else "靠近本层篷车商人后才能选择。"))
 elif modal=="contract":
  status=str(data.get("status",""))
 else:
  var inventory:Dictionary=data.get("inventory",{})
  status="护符 %d / 凿甲钉 %d；已装备：%s" % [int(inventory.get("ward",0)),int(inventory.get("pierce",0)),{"":"无","ward":"护符","pierce":"凿甲钉"}.get(str(data.get("armed","")),"无")]
 draw_wrapped(status,Vector2(160,350),950,17,TEAL,3)
 for i in mini(3,choices.size()):
  panel(Rect2(185,425+i*70,910,62),Color("2a4051"))
  draw_wrapped("%d  %s"%[i+1,str(choices[i].label)],Vector2(200,451+i*70),880,17,INK,2)
 if modal_notice!="":draw_wrapped(modal_notice,Vector2(160,665),720,15,Color("efb18e"),2)
 panel(Rect2(910,687,250,45),Color("384152"));text(Vector2(928,715),"关闭 · Esc",18)

func open_growth():
 if world==null or not world.has_method("growth_view"):
  notice="此旧规则旅程不采用新版成长预算；旧局保持原规则，新开局才使用新版。";return
 walk.clear();modal="growth";choices.clear();queue_redraw()
func growth_help_text()->String:
 return "G：查看成长与全旅程预算。每层剑盾包领取一次，固定攻击+3、防御+2；回访不重复领，也不降低基础。\n所有额外永久攻防共用攻击+6、防御+4上限，不是每层重置。\n全旅程6课时：攻击、防御、急救共用；战术训练仍最高3，遗物最多额外2级。\n生命上限180。全旅程10份免费箱补给，每份最多8生命；用尽后4金币一份。满血不购买，也可免费放弃箱子开路。\nB战术；R营地遭遇；I道具；Q第四层信使线索。\n鼠标邻格互动，远处安全寻路；右拖地图，空格回角色。\nL读取；N明确重开。旧规则不自动升级；本设备榜不是全球榜。"
func growth_lines(data:Dictionary)->Array[String]:
 return ["已领取%d份基础包：攻击%d / 防御%d" % [int(data.training_packs),int(data.base_atk),int(data.base_def)],
  "每层包仅领一次：攻击+3、防御+2；不是天赋等级。",
  "本层基础包："+("仍可领取" if data.local_pack_available else "已领取"),
  "额外永久攻击 +%d / %d；还可增加%d" % [int(data.bonus_atk),int(data.bonus_atk_cap),int(data.remaining_atk)],
  "额外永久防御 +%d / %d；还可增加%d" % [int(data.bonus_def),int(data.bonus_def_cap),int(data.remaining_def)],
  "技能、商店、宝库与任务奖励共用上限，不按层重置。",
  "全旅程课时：已用%d / %d，剩%d" % [int(data.lessons_used),int(data.lesson_cap),int(data.lessons_remaining)],
  "攻击、防御、急救共用；战术等级另有3+2上限。"]
func draw_growth():
 var data:Dictionary=world.growth_view()
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.8));panel(Rect2(95,85,1090,665),Color("152736"))
 text(Vector2(125,132),"成长与预算 · 当前规则 v%d" % world.rule_version(),25,GOLD)
 text(Vector2(125,176),"固定基础成长 ≠ 有限的额外成长",22,TEAL)
 var lines=growth_lines(data)
 for i in lines.size():
  text(Vector2(125,222+i*38),lines[i],16,GOLD if i in [0,3,4,6] else INK)
 text(Vector2(125,557),"生命 %d / %d；箱补给每份最多恢复%d" % [world.hp,int(data.hp_cap),int(data.supply_heal)],17,TEAL)
 draw_wrapped("本层箱："+("尚可互动" if data.local_supply_available else "已处理")+"。补给额度与课时均跨层共享。",Vector2(125,594),500,16,INK,2)
 text(Vector2(125,650),"全旅程免费补给：剩%d / %d；本次费用%d金" % [int(data.relief_remaining),int(data.relief_total),int(data.supply_price)],17,GOLD)
 text(Vector2(665,176),"当前两条路线 · 只计剩余守卫",20,GOLD)
 var y=220
 for route in data.get("routes",[]):
  var status="不能破防" if not route.get("valid",false) else ("当前会致死" if not route.get("survivable",false) else "可存活 · 净损%d生命" % int(route.get("net_damage",route.get("damage",0))))
  draw_wrapped(str(route.get("label","路线"))+"："+status,Vector2(665,y),480,18,TEAL,2)
  y+=70
 draw_wrapped("只读预算，不会购买或战斗。预估按当前战术、已装备道具顺序结算，不含途中拾取、购物或新成长。不是自动通关承诺。",Vector2(665,383),480,17,INK,5)
 draw_wrapped("旧旅程保持原规则；这份预算只适用于当前新版旅程。",Vector2(665,560),480,17,TEAL,3)
 panel(Rect2(910,687,250,45),Color("384152"));text(Vector2(930,717),"关闭 · Esc / Enter",17)

func contract_heading(data:Dictionary)->String:
 var phase=str(data.get("phase","offer"))
 return {"offer":"订单预览 · 尚未接单","active":"已接委托 · 第%d层" % int(data.get("source",0)),"complete":"目标完成 · 等待退押金","voucher":"押金已退 · 可折价兑换","closed":"本层订单已结束"}.get(phase,"路线委托")

func contract_body(data:Dictionary)->String:
 var phase=str(data.get("phase","offer"))
 var cost="可直接买1护符12金 / 1凿甲钉18金，或押12金接单。" if phase=="offer" else "已接订单：12金币是押金，退还不是额外收入。"
 if phase=="voucher":cost="押金已经退还，不会再次领取。兑换是可选的。"
 if phase=="closed":cost="此层订单已结算，不重复购买、接单或领奖。"
 return cost+"\n目标：第%d层 · %s；剩%d名。兑现须回第%d层商人。\n完成先退12，再自选8金币换%d件道具；也可免费放弃兑换。\n不限时；未履约取消或结束旅程，未退押金损失。" % [int(data.get("source",0)),str(data.get("route_label","指定路线")),int(data.get("remaining",0)),int(data.get("source",0)),int(data.get("reward_count",1))]

func camp_button_label(data:Dictionary)->String:
 if data.get("available",false):return "T 安全回营 · %d步" % int(data.get("steps",0))
 return "T 安全回营 · 已到" if "已经在营地" in str(data.get("reason","")) else "T 安全回营 · 不可用"
func camp_tooltip(data:Dictionary)->String:
 if not data.get("available",false):return str(data.get("reason","暂无安全路线。"))+"\n仅同层安全空地；不会穿过物品、怪物、门或楼梯。"
 var target:Vector2i=data.get("target",Vector2i.ZERO)
 return "沿安全空路快速回营 %d步\n第%d层商人邻格（%d,%d）\n一次保存全部步行记录，不沿途互动、不跨层。触发后不能中途撤销；保存未确认时画面不前进。" % [int(data.get("steps",0)),int(data.get("source_floor",0)),target.x,target.y]
func start_camp_return():
 if busy or modal!="" or world==null:return
 walk.clear()
 if not world.has_method("camp_return_view"):
  notice="此旧规则旅程没有安全快捷回营；可继续使用安全空地寻路。";return
 var view:Dictionary=world.camp_return_view()
 if not view.get("available",false):notice=str(view.get("reason","没有安全回营路线。"));return
 if not store.has_method("commit_walk"):
  notice="快捷回营存储尚不可用，没有移动。";return
 busy=true
 var candidate=world.clone()
 var outcome:Dictionary=candidate.return_to_camp()
 if not outcome.get("changed",false):
  busy=false;notice=str(outcome.get("message","安全路线已变化，没有移动。"));return
 var result:Dictionary=await store.commit_walk(candidate.save_data(),revision)
 busy=false
 if not result.get("ok",false):
  notice="回营保存未确认，位置未前进：%s。按L核对已存旅程。" % str(result.get("status","unknown"));queue_redraw();return
 world=candidate;revision=int(result.revision);records=result.get("records",records);center_camera()
 notice="已沿%d格安全空路回到本层商人旁；每步均已记录。" % int(view.get("steps",0));queue_redraw()

func gear_entry_status(entry:Dictionary)->String:
 if entry.get("equipped",false):return "已穿戴 · 重穿不收费"
 if entry.get("owned",false):return "已拥有 · 营地免费切换"
 return "一次购买 %d金币 · 不自动穿戴" % int(entry.get("price",40))
func draw_gear_panel():
 var data:Dictionary=world.gear_view()
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.70));panel(Rect2(120,85,1040,665),Color("152736"))
 for i in 2:
  panel(Rect2(160+i*270,102,250,38),Color("365347") if i==1 else Color("293e50"))
  text(Vector2(174+i*270,128),["消耗品","持久装备"][i],19,GOLD if i==1 else INK)
 text(Vector2(725,128),"Tab 切换 · 预览不会购买/装备",15,TEAL)
 text(Vector2(160,180),"持久装备 · 可不装，仅一件生效",26,GOLD)
 text(Vector2(160,212),"商人旁购买、免费切换或卸下。购买不自动穿；不会随战斗消耗。",17,INK)
 var entries:Array=data.get("entries",[])
 for i in mini(2,entries.size()):
  var entry:Dictionary=entries[i];var x=160+i*490
  panel(Rect2(x,230,470,164),Color("233c49"))
  GearArt.draw_gear(self,Vector2(x+54,280),str(entry.id),64)
  text(Vector2(x+100,260),str(entry.name),22,GOLD)
  draw_wrapped(gear_entry_status(entry),Vector2(x+100,287),350,15,TEAL,2)
  var effects=entry.get("effects",[])
  var effect_text="\n".join(effects) if effects is Array else str(effects)
  draw_wrapped(effect_text,Vector2(x+18,333),435,17,INK,3)
 text(Vector2(160,414),"当前实战 攻击%d / 防御%d（常驻%d / %d）；%s" % [int(data.effective_atk),int(data.effective_def),int(data.base_atk),int(data.base_def),str(data.get("status",""))],15,TEAL)
 for i in mini(3,choices.size()):
  panel(Rect2(185,425+i*70,910,62),Color("2a4051"))
  draw_wrapped("%d  %s" % [i+1,str(choices[i].label)],Vector2(200,451+i*70),880,17,INK,2)
 if modal_notice!="":draw_wrapped(modal_notice,Vector2(160,665),720,15,Color("efb18e"),2)
 panel(Rect2(910,687,250,45),Color("384152"));text(Vector2(928,715),"关闭 · Esc",18)
