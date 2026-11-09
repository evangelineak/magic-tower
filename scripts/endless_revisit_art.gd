class_name TowerEndlessRevisitArt
extends RefCounted
const A=preload("res://scripts/endless_actor_art.gd")
# Pure derived presentation: never records discovery, moves, or consumes resources.
static func quote_status(quote:Dictionary)->Dictionary:
 return {"blocked":not bool(quote.get("allowed",true)),"reason":str(quote.get("reason",""))}
static func status(world,target:Vector2i)->Dictionary:
 var token:String=world.tile(target)
 if token=="$" and world.has_method("vault_quote"):return quote_status(world.vault_quote(target))
 if token=="T" and world.has_method("relic_quote"):return quote_status(world.relic_quote())
 if token!="B" or not world.has_method("bridge_view"):return {}
 var reward:Dictionary=world.preview(target).get("reward",{})
 if reward.is_empty():
  if world.rule_version()!=16:return {}
  reward={"ward":1,"pierce":1}
 var ward:int=maxi(0,int(world.items.ward)+int(reward.get("ward",0))-9)
 var pierce:int=maxi(0,int(world.items.pierce)+int(reward.get("pierce",0))-9)
 return {"blocked":ward+pierce>0,"reason":"宝箱保留：护符还缺%d格，凿甲钉还缺%d格；整箱领取。" % [ward,pierce]}
static func draw_seal(c:CanvasItem,center:Vector2,size:float=64):
 if size<=0:return
 c.draw_set_transform(center,0,Vector2.ONE*size/64.0)
 # Folded linen tag at lower right; an open return hook, not a lock or reward star.
 A.poly(c,[[10,7],[26,7],[30,11],[30,29],[10,29]],A.LIGHT)
 A.poly(c,[[26,7],[26,12],[30,12]],A.STEEL)
 A.line(c,Vector2(24,15),Vector2(24,23),A.CLOTH,2.5)
 A.line(c,Vector2(24,23),Vector2(16,23),A.CLOTH,2.5)
 A.line(c,Vector2(16,23),Vector2(16,18),A.CLOTH,2.5)
 A.line(c,Vector2(13,20),Vector2(16,17),A.CLOTH,2)
 A.line(c,Vector2(16,17),Vector2(19,20),A.CLOTH,2)
 c.draw_set_transform(Vector2.ZERO)
