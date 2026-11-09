class_name TowerMapSymbols
extends RefCounted
## Original flat heraldic props. All coordinates use a 64 x 64 design square.
const TOKENS := ["M","C","E","F","T","N","Q","I","O","R","X","U","Y","$","A","P"]
const OUTLINE := Color("172735")
const GOLD := Color("dfbd72")
const LIGHT := Color("f2dfac")
const TEAL := Color("72b7ad")
const STEEL := Color("a9bec9")
const WOOD := Color("94724e")
const RED := Color("bc6b68")
const PAPER := Color("ded4af")

static func supports(token: String) -> bool:
	return token in TOKENS

static func polygon(c: CanvasItem, points: Array, color: Color):
	var p:=PackedVector2Array()
	for v in points: p.append(Vector2(v[0],v[1]))
	c.draw_colored_polygon(p,color)
	p.append(p[0]); c.draw_polyline(p,OUTLINE,2.5,true)
static func box(c: CanvasItem,x:float,y:float,w:float,h:float,color:Color):
	c.draw_rect(Rect2(x,y,w,h),color)
	c.draw_rect(Rect2(x,y,w,h),OUTLINE,false,2.5)
static func line(c:CanvasItem,a:Vector2,b:Vector2,color:Color=OUTLINE,width:float=2.5):
	c.draw_line(a,b,color,width,true)
static func ring(c:CanvasItem,p:Vector2,r:float,color:Color):
	c.draw_circle(p,r,color)
	c.draw_arc(p,r,0,TAU,40,OUTLINE,2.5,true)
static func blade(c:CanvasItem):
	polygon(c,[[32,7],[39,18],[35,39],[29,39],[25,18]],STEEL)
	line(c,Vector2(32,13),Vector2(32,35),LIGHT,2)
	box(c,22,38,20,5,GOLD);box(c,29,43,6,12,WOOD)
static func chest(c:CanvasItem,color:Color):
	polygon(c,[[11,29],[16,20],[48,20],[53,29],[53,51],[11,51]],WOOD)
	box(c,11,29,42,22,color)
	line(c,Vector2(12,34),Vector2(52,34));box(c,28,30,8,12,GOLD)
	line(c,Vector2(18,22),Vector2(18,50),LIGHT,3)
	line(c,Vector2(46,22),Vector2(46,50),LIGHT,3)
static func draw_icon(c: CanvasItem, token: String, rect: Rect2) -> bool:
	if not supports(token) or rect.size.x<=0 or rect.size.y<=0: return false
	c.draw_set_transform(rect.position,0,rect.size/64.0)
	match token:
		"M": # striped market canopy, counter and coin sign
			box(c,14,21,4,33,WOOD);box(c,46,21,4,33,WOOD)
			polygon(c,[[8,25],[17,10],[47,10],[56,25]],RED)
			polygon(c,[[24,10],[31,10],[28,25],[19,25]],PAPER)
			polygon(c,[[38,10],[45,10],[48,25],[39,25]],PAPER)
			box(c,11,39,42,15,WOOD);ring(c,Vector2(32,46),6,GOLD)
		"C": # socketed crystal core, not a treasure box
			polygon(c,[[20,44],[44,44],[48,53],[16,53]],STEEL)
			polygon(c,[[32,7],[43,22],[39,41],[32,47],[25,41],[21,22]],TEAL)
			line(c,Vector2(32,10),Vector2(32,40),LIGHT,3)
			line(c,Vector2(23,22),Vector2(40,22),LIGHT,2)
		"E": # pulley and open lift cage
			box(c,11,9,5,46,WOOD);box(c,48,9,5,46,WOOD);box(c,10,8,44,6,WOOD)
			ring(c,Vector2(32,17),6,GOLD);line(c,Vector2(32,23),Vector2(32,30),GOLD,3)
			box(c,20,30,24,24,STEEL);box(c,25,34,14,16,OUTLINE)
			line(c,Vector2(32,34),Vector2(32,50),STEEL,3)
		"F": # anvil and hammer
			polygon(c,[[7,25],[45,25],[55,18],[55,32],[39,37],[38,46],[47,52],[17,52],[26,45],[25,35],[13,33]],STEEL)
			line(c,Vector2(25,11),Vector2(40,24),WOOD,6)
			polygon(c,[[16,9],[23,4],[34,14],[27,21]],GOLD)
		"T": # crowned star vault
			chest(c,GOLD)
			polygon(c,[[18,19],[15,7],[25,12],[32,3],[39,12],[49,7],[46,19]],GOLD)
			polygon(c,[[32,33],[35,38],[41,39],[36,43],[37,49],[32,46],[27,49],[28,43],[23,39],[29,38]],LIGHT)
		"N": # rounded stele, engraved lines
			polygon(c,[[16,53],[16,19],[22,9],[42,9],[48,19],[48,53]],STEEL)
			for y in [24,32,40]: line(c,Vector2(23,y),Vector2(40,y),OUTLINE,3)
			box(c,11,52,42,5,WOOD)
		"Q": # sealed arch with four symbol sockets
			polygon(c,[[12,55],[12,22],[22,10],[42,10],[52,22],[52,55]],STEEL)
			polygon(c,[[22,53],[22,26],[28,20],[36,20],[42,26],[42,53]],OUTLINE)
			for p in [Vector2(18,25),Vector2(46,25),Vector2(18,43),Vector2(46,43)]: ring(c,p,4,TEAL)
			polygon(c,[[32,29],[38,36],[32,43],[26,36]],GOLD)
		"I": # specimen jar with a branch inside
			box(c,22,9,20,7,WOOD)
			polygon(c,[[23,16],[41,16],[41,23],[48,30],[48,51],[16,51],[16,30],[23,23]],TEAL)
			line(c,Vector2(31,45),Vector2(34,25),OUTLINE,3)
			polygon(c,[[32,36],[22,29],[22,37]],GOLD)
			polygon(c,[[33,40],[42,33],[42,42]],GOLD)
		"O": # water valve, visible spokes and pipe
			box(c,9,40,46,12,STEEL);box(c,27,27,10,19,STEEL)
			ring(c,Vector2(32,25),17,TEAL);ring(c,Vector2(32,25),11,OUTLINE)
			for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: line(c,Vector2(32,25),Vector2(32,25)+d*14,GOLD,4)
			ring(c,Vector2(32,25),4,GOLD)
		"R": # open armory, shield plus blade
			polygon(c,[[9,25],[32,18],[32,42],[21,55],[9,43]],TEAL)
			line(c,Vector2(20,27),Vector2(20,44),LIGHT,3)
			polygon(c,[[44,7],[51,17],[47,40],[41,40],[37,17]],STEEL)
			box(c,34,38,20,5,GOLD);box(c,41,43,6,12,WOOD)
		"X": # forked signpost, branching choice not question mark
			box(c,29,12,6,44,WOOD)
			polygon(c,[[9,15],[39,15],[49,23],[39,31],[9,31]],PAPER)
			polygon(c,[[55,34],[25,34],[15,42],[25,50],[55,50]],TEAL)
			line(c,Vector2(17,23),Vector2(35,23),WOOD,3)
			line(c,Vector2(29,42),Vector2(47,42),OUTLINE,3)
		"U": # tent and camp pennant
			line(c,Vector2(33,8),Vector2(33,53),WOOD,3)
			polygon(c,[[34,7],[49,12],[34,18]],RED)
			polygon(c,[[5,53],[30,20],[57,53]],PAPER)
			polygon(c,[[20,53],[30,31],[40,53]],OUTLINE)
			line(c,Vector2(30,22),Vector2(46,52),GOLD,3)
		"Y": # engineering desk and unmistakable open-ended wrench
			box(c,9,39,46,7,WOOD);box(c,13,46,5,10,WOOD);box(c,46,46,5,10,WOOD)
			polygon(c,[[21,10],[21,22],[27,26],[33,20],[33,8],[39,16],[38,25],[32,31],[24,43],[17,39],[25,26],[17,21]],STEEL)
			box(c,39,31,11,8,PAPER)
		"$":
			chest(c,WOOD)
			for p in [Vector2(23,18),Vector2(35,15),Vector2(43,21)]: ring(c,p,7,GOLD)
		"A":
			blade(c)
			polygon(c,[[11,24],[14,29],[19,32],[14,35],[11,40],[8,35],[3,32],[8,29]],GOLD)
		"P": # bound medical provisions, not generic chest
			box(c,10,26,29,27,WOOD);box(c,20,26,8,27,PAPER)
			box(c,41,12,10,7,GOLD)
			polygon(c,[[40,19],[52,19],[52,27],[57,32],[57,51],[35,51],[35,32],[40,27]],TEAL)
			line(c,Vector2(40,40),Vector2(52,40),LIGHT,4)
			line(c,Vector2(46,34),Vector2(46,46),LIGHT,4)
	c.draw_set_transform(Vector2.ZERO)
	return true
