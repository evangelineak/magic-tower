extends Node2D
# A separate mode and storage namespace: the classic journey is untouched.
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
func start_run(seed_value:int):
 if busy:return
 busy=true;walk.clear()
 var candidate=WorldType.new_run(seed_value)
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
  if modal!="":
   if Rect2(280,575,330,48).has_point(p):await confirm_modal();return
   if Rect2(650,575,330,48).has_point(p):
    if modal=="start":get_tree().change_scene_to_file("res://main.tscn")
    else:modal=""
    return
   if modal=="choices":
    for i in choices.size():
     if Rect2(280,225+i*58,720,50).has_point(p):await transact("act",choices[i].id);return
   return
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
   elif modal=="choices" and event.keycode>=KEY_1 and event.keycode<KEY_1+choices.size():await transact("act",choices[event.keycode-KEY_1].id)
   return
  if event.keycode==KEY_SPACE:center_camera();return
  if event.keycode==KEY_N:modal="new";return
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
 draw_colored_polygon(PackedVector2Array([c+Vector2(-13,-8),c+Vector2(13,-8),c+Vector2(25,27),c+Vector2(0,19),c+Vector2(-25,27)]),Color("397b78"))
 panel(Rect2(c+Vector2(-10,-5),Vector2(20,26)),Color("a9bec9"))
 draw_circle(c+Vector2(0,-15),11,GOLD)
 draw_colored_polygon(PackedVector2Array([c+Vector2(-13,-12),c+Vector2(-10,-26),c+Vector2(0,-31),c+Vector2(10,-26),c+Vector2(13,-12)]),TEAL)
 draw_line(c+Vector2(-6,-16),c+Vector2(6,-16),Color("172735"),3)
 draw_colored_polygon(PackedVector2Array([c+Vector2(-25,-1),c+Vector2(-9,-1),c+Vector2(-10,16),c+Vector2(-17,23),c+Vector2(-24,16)]),GOLD)
 draw_line(c+Vector2(20,-22),c+Vector2(20,18),INK,4);draw_line(c+Vector2(12,7),c+Vector2(27,7),GOLD,3)
func draw_token(c:Vector2,t:String):
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
 text(Vector2(768,59),"种子 %d · 按需生成，没有八层终点"%world.seed,14,TEAL)
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
 draw_wrapped(notice,Vector2(768,463),468,16,TEAL,6)
 var labels=["结束本局并记入本设备榜","回到角色 · Space","本设备历史榜","重新开始 · N","返回经典魔塔"]
 var rects=[Rect2(768,610,476,42),Rect2(768,662,220,44),Rect2(1000,662,244,44),Rect2(768,714,220,44),Rect2(1000,714,244,44)]
 for i in rects.size():panel(rects[i],Color("293e50"));text(rects[i].position+Vector2(12,28),labels[i],16)
 text(Vector2(24,796),"视窗 (%d,%d) · 自动保存 · 经典存档独立保留"%[camera.x,camera.y],13,TEAL)
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
  text(Vector2(180,450),"示意动画，结算仅一次 · 点击或按键跳过",14,TEAL)
 if busy:panel(Rect2(380,15,370,43),Color("293e50"));text(Vector2(397,43),"正在安全保存，请稍候……",18,GOLD)
func draw_modal():
 panel(Rect2(0,0,1280,800),Color(0,0,0,0.70));panel(Rect2(245,145,790,505),Color("152736"))
 var title="确认"
 var body=notice
 match modal:
  "start":title="踏入更深的塔";body="15×15地图，安全寻路与相邻点击。每层先找入口附近训练宝石与补给，再挑战关隘。强敌宝库可成长后回访。无尽模式独立保存，不替换经典旅程。首版数值安全界限100万层、10万动作，达到动作界限仍可结算。"
  "new":title="重新开始无尽旅程？";body="会替换当前无尽旅程。经典魔塔存档与已结算的本设备历史榜保留。"
  "retire":title="结束并结算本局？";body="结算后不能继续这次无尽旅程，成绩只保存在本设备。不是公开全球排名。"
  "ranking":title="本设备历史榜";body="仅当前浏览器或电脑可见，不上传服务器，不是全球榜。"
  "ended":title="本次远征结束";body="成绩已保存到本设备历史榜。下一次仍有不同路线与成长选择。"
  "finish_retry":title="结算等待重试"
  "choices":title="选择行动";body=""
 text(Vector2(280,190),title,26,GOLD)
 if modal=="choices":
  for i in mini(6,choices.size()):panel(Rect2(280,225+i*58,720,50),Color("2a4051"));draw_wrapped("%d  %s"%[i+1,str(choices[i].label)],Vector2(293,253+i*58),690,16,INK,2)
 elif modal=="ranking":
  draw_wrapped(body,Vector2(280,230),710,16,TEAL,2)
  for i in mini(8,records.size()):
   var record:Dictionary=records[i]
   draw_wrapped("%d.  第%d层 · 击杀%d · 金币%d · 种子%d"%[i+1,int(record.get("max_floor",1)),int(record.get("kills",0)),int(record.get("gold",0)),int(record.get("seed",0))],Vector2(280,285+i*32),710,16,INK,1)
 else:draw_wrapped(body,Vector2(280,245),710,20,INK,11)
 if modal_notice!="" and modal in ["choices","new","start"]:draw_wrapped(modal_notice,Vector2(280,535),710,15,Color("efb18e"),2)
 panel(Rect2(280,575,330,48),Color("365347"));text(Vector2(300,606),"确认 / Enter" if modal not in ["ranking","choices"] else "关闭",18)
 panel(Rect2(650,575,330,48),Color("384152"));text(Vector2(670,606),"取消 / Esc",18)
