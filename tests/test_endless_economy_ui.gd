extends SceneTree
# Isolated economic UI states, not a legal acquisition/path proof.
const W=preload("res://scripts/endless_world_v17.gd")
var checks=0
var failures=0
class Memory:
 extends RefCounted
 var revision=0
 var writes=0
 var failing=false
 func read():return {"ok":true,"snapshot":{},"revision":revision,"records":[]}
 func commit(_s,r):
  if failing:return {"ok":false,"status":"io_error"}
  if r!=revision:return {"ok":false,"status":"conflict"}
  revision+=1;writes+=1;return read()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func potion_row(w)->Dictionary:
 for row in w.options(Vector2i(2,2)):
  if row.id=="buy_potion":return row
 return {}
func fixture(hp:int,gold:int=30):
 var w=W.new_run(1);w.pos=Vector2i(2,1);w.hp=hp;w.gold=gold;return w
func _initialize():call_deferred("run")
func run():
 var ui=load("res://endless.tscn").instantiate();var memory=Memory.new();ui.store=memory;root.add_child(ui)
 await process_frame;ui.set_process(false)
 ui.world=fixture(150);ui.modal="";await ui.map_click(Vector2i(2,2))
 check(ui.quoted_choice_page() and ui.choice_footer_y()==650,"new quotes use readable original choice sheet, not a new menu")
 check("150 / 180" in ui.choice_resources_text() and "金币 30" in ui.choice_resources_text(),"current HP cap and wallet visible")
 var row=potion_row(ui.world);var text=ui.choice_display_text(row)
 check("150→180" in text and "实际+30" in text and "未用20" in text,"50-point medicine discloses actual 30 and overflow 20")
 check("15金币" in text,"price taken from core quote")
 ui.queue_redraw();await process_frame
 var click=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=ui.choice_rect(0).get_center()
 var before=ui.world.save_data();memory.failing=true;await ui._unhandled_input(click)
 check(ui.world.hp==150 and ui.world.gold==30 and ui.world.save_data()==before,"failed persistence leaves actual resources unchanged")
 memory.failing=false;await ui._unhandled_input(click)
 check(ui.world.hp==180 and ui.world.gold==15,"click result matches both quoted HP and cost")
 var writes=memory.writes;await ui.transact("act","buy_potion")
 check(memory.writes==writes and ui.world.gold==15,"repeated potion cannot charge twice")
 ui.world=fixture(100);row=potion_row(ui.world)
 check(row.quote.heal_actual==50 and row.quote.overflow==0 and "100→150" in ui.choice_display_text(row),"low HP receives complete effect with zero overflow")
 ui.world=fixture(180);ui.modal="";await ui.map_click(Vector2i(2,2));row=potion_row(ui.world)
 check(not row.quote.allowed and "已满" in ui.choice_display_text(row),"full health disabled reason shown rather than promised heal")
 writes=memory.writes;await ui.transact("act","buy_potion")
 check(ui.world.gold==30 and memory.writes==writes,"full health attempt spends nothing")
 ui.world=fixture(150,0);row=potion_row(ui.world)
 check(not row.quote.allowed and "金币不足" in ui.choice_display_text(row) and "15金币" in ui.choice_display_text(row),"insufficient gold does not turn price into free")
 ui.world=fixture(150);ui.world.pos=Vector2i(3,1)
 var mend:Dictionary={}
 for offer in ui.world.options(Vector2i(3,2)):
  if offer.id=="skill_mend":mend=offer
 check(not mend.is_empty() and "课时" in ui.choice_display_text(mend) and "150→180" in ui.choice_display_text(mend),"free-gold healing retains non-gold lesson cost")
 ui.world=fixture(150);var data=ui.world.contract_view()
 check("护符%d金" % ui.world.tool_price("ward") in ui.contract_body(data) and "自选%d金币" % data.exchange_price in ui.contract_body(data),"order description follows world price API and view, not stale display price")
 ui.world=fixture(180);ui.world.pos=Vector2i(11,10);ui.world.bonus_atk=6;ui.world.bonus_def=4;ui.world.relic_bonus=2;ui.world.atk=26;ui.world.defense=14;ui.modal=""
 before=ui.world.save_data();writes=memory.writes;await ui.map_click(Vector2i(12,10))
 check(ui.world.tile(Vector2i(12,10))=="T" and ui.world.save_data()==before and memory.writes==writes,"zero-benefit relic click stays on map without consumption")
 check("保留原地" in ui.notice,"refusal tells player why revisit can matter")
 ui.world.hp=170;await ui.map_click(Vector2i(12,10))
 check(ui.world.hp==180 and ui.world.tile(Vector2i(12,10))==".","injured revisit takes only real remaining heal and consumes once")
 var found_medicine=false
 for seed_value in range(100):
  var candidate=W.new_run(seed_value);candidate.pos=Vector2i(2,1);candidate.gold=30;candidate.hp=150
  for offer in candidate.encounter_options():
   if offer.id=="enc_medicine":
    ui.world=candidate;ui.open_supply_panel("encounter")
    check("150→180" in ui.choice_display_text(offer) and "未用5" in ui.choice_display_text(offer),"R medicine reads actual 35-point quote rather than potion 50")
    ui.queue_redraw();await process_frame;found_medicine=true;break
  if found_medicine:break
 check(found_medicine,"actual seeded medicine encounter fixture exists")
 ui.world=fixture(150);ui.world.floor_number=4;ui.world.pos=Vector2i(12,13);ui.world.messenger.state="found"
 var case_rows=ui.world.case_options()
 check(case_rows.size()==2 and "150→180" in ui.choice_display_text(case_rows[0]) and "未用10" in ui.choice_display_text(case_rows[0]),"messenger supply uses its actual 40-point quote")
 check("领取时" in case_rows[1].label and "8金币" in case_rows[1].label,"future reward explains cap conversion at collection time")
 ui.open_case();ui.queue_redraw();await process_frame
 # Isolated treasure-island fixtures verify UI economics, not legal access proof.
 ui.world=W.new_run(1);ui.world.pos=Vector2i(5,7);ui.world.keys=1;ui.modal=""
 var bridge_view=ui.world.bridge_view();var loot:Dictionary=bridge_view.arms[1]
 check(loot.reward.ward==2 and loot.reward.pierce==2 and loot.reward.gold==0,"final v17 treasure view has two of each tool and no box gold")
 check("护符2件" in ui.bridge_reward_text(loot.reward) and "凿甲钉2件" in ui.bridge_reward_text(loot.reward),"bridge reward text reads actual quantity")
 check(loot.guardian.gold==22 and "另得22金币" in ui.bridge_loot_text(loot),"island guardian bounty visible separately from zero-gold box")
 ui.open_bridge();ui.queue_redraw();await process_frame
 var box_preview=ui.world.preview(Vector2i(6,3));var box_copy=str(box_preview)
 check("2" in box_preview.title and "空位" in box_copy and "1个空位" not in box_copy,"box hover uses new actual inventory requirement")
 ui.world.pos=Vector2i(5,3);ui.world.items.ward=8;ui.world.items.pierce=7;ui.modal=""
 before=ui.world.save_data();writes=memory.writes;await ui.map_click(Vector2i(6,3))
 check(ui.world.tile(Vector2i(6,3))=="B" and ui.world.items.ward==8 and ui.world.items.pierce==7 and memory.writes==writes and ui.world.save_data()==before,"one ward space refuses whole box without partial award or write")
 check("2" in ui.notice and "保留" in ui.notice,"inventory refusal explains two spaces and retained box")
 ui.world.items.ward=7;ui.world.items.pierce=8;await ui.map_click(Vector2i(6,3))
 check(ui.world.items.ward==7 and ui.world.items.pierce==8 and ui.world.tile(Vector2i(6,3))=="B","one pierce space also refuses whole box")
 ui.world.items.pierce=7;await ui.map_click(Vector2i(6,3))
 check(ui.world.items.ward==9 and ui.world.items.pierce==9 and ui.world.tile(Vector2i(6,3))==".","two spaces each allows exactly two of each once")
 check(ui.world.tool_price("ward")==4 and ui.world.tool_price("pierce")==8 and ui.world.exchange_price(1)==2 and ui.world.exchange_price(2)==4,"final B prices exposed by actual API")
 ui.world=load("res://scripts/endless_world_v16.gd").new_run(1);ui.modal="choices"
 check(not ui.quoted_choice_page() and ui.choice_footer_y()==575,"old versions retain original choice geometry")
 check(ui.choice_display_text({"label":"old exact wording"})=="old exact wording","legacy unquoted rows unchanged")
 ui.queue_free();await process_frame
 print("ECONOMY UI: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]);quit(0 if failures==0 else 1)
