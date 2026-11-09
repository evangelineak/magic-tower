extends SceneTree
const W=preload("res://scripts/endless_world_v2.gd")
const V1=preload("res://scripts/endless_world_v1.gd")
const G=preload("res://scripts/endless_generation_v2.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func path(w,target:Vector2i,alternate:bool=false)->Array[Vector2i]:
	var q:Array[Vector2i]=[w.pos];var parents:Dictionary={w.pos:w.pos};var head:=0
	while head<q.size():
		var p:=q[head];head+=1
		if p==target:
			var result:Array[Vector2i]=[]
			while p!=w.pos:result.push_front(p);p=parents[p]
			return result
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var n:Vector2i=p+d;var t:String=w.tile(n)
			if parents.has(n) or t in ["#","M","S","D","V"] or (t=="b" and not alternate) or (t in ["g","w"] and alternate) or (t in ["<",">"] and n!=target):continue
			parents[n]=p;q.append(n)
	return []
func go(w,target:Vector2i,alternate:bool=false,transport:bool=false):
	var route:=path(w,target,alternate)
	check(w.pos==target or not route.is_empty(),"real path exists")
	for p in route:
		if w.tile(p)=="C":check(w.act("cargo_accept" if transport and w.cargo.state=="fresh" else "cargo_use").changed,"resolve actual supply cost")
		check(w.step(p-w.pos).changed and not w.ended,"actual route action survives")
func cross(w,alternate:bool=false,transport:bool=false):
	var f:int=w.floor_number
	var y:int=1 if f%2==1 else 13
	go(w,Vector2i(2 if f%2==1 else 12,y),alternate,transport)
	go(w,Vector2i(3 if f%2==1 else 11,y),alternate,transport)
	go(w,G.anchors(f).exit,alternate,transport)
func _init():
	for seed in range(64):
		for f in [1,2,3,40,1000000]:
			var generated:=G.generate(seed,f)
			check(generated.ok,"geometry gates and rewards validated")
			check(generated==G.generate(seed,f),"seed replay")
			check(generated.exit==G.anchors(f+1).entry,"aligned stairs")
	for seed in [0,1,42,2147483647]:
		for alternate in [false,true]:
			var w=W.new_run(seed)
			for f in range(1,41):cross(w,alternate)
			check(w.floor_number==41 and w.hp>0,"40 real budget floors")
			check(w.kills==80 if alternate else w.kills==40,"no costless depth")
			var loaded=W.from_data(JSON.parse_string(JSON.stringify(w.save_data())))
			check(loaded!=null and loaded.hp==w.hp and loaded.deltas==w.deltas,"full replay exact")
	var w=W.new_run(42)
	go(w,Vector2i(2,1));var hp:int=w.hp
	check(w.act("cargo_accept").changed and w.hp==hp,"transport sacrifices actual 20hp")
	check(w.tile(Vector2i(3,1))=="." and not w.act("cargo_accept").changed,"source removed once")
	check(w.cargo.target==3,"delivery two floors later")
	check(not w.act("cargo_deliver").changed,"early delivery rejected")
	go(w,G.anchors(1).exit);cross(w)
	go(w,Vector2i(2,1))
	check(w.act("cargo_deliver").changed,"destination merchant delivery")
	check(w.options(Vector2i(2,2)).size()==3,"reward independent three choices")
	var old_atk:int=w.atk
	check(w.act("cargo_mod_power").changed and w.atk==old_atk+4,"reward actual upgrade")
	check(not w.act("cargo_mod_keys").changed and not w.act("cargo_deliver").changed,"no duplicate reward")
	check(W.from_data(w.save_data()).cargo==w.cargo,"cargo replay exact")
	var opened=W.new_run(9);go(opened,Vector2i(2,1));opened.act("cargo_accept")
	check(opened.act("cargo_open").changed and opened.hp==170,"opening restores original supply")
	check(not opened.act("cargo_open").changed and not opened.act("cargo_deliver").changed,"opened cargo cannot reward")
	var copy=w.clone();check(copy.cargo==w.cargo and copy.save_data()==w.save_data(),"clone task exact")
	var v1=V1.new_run(42);v1.step(Vector2i.RIGHT)
	check(v1.save_data().version==1 and V1.from_data(v1.save_data())!=null,"frozen v1 replay")
	check(W.from_data(v1.save_data())==null and V1.from_data(w.save_data())==null,"no cross-version replay")
	var malformed:Dictionary=w.save_data();malformed["cargo"]={"state":"delivered"}
	check(W.from_data(malformed)==null,"task injection rejected")
	var start=W.new_run(1);var routes:Array=start.summary().routes
	check(routes.size()==2 and routes[0].damage!=routes[1].damage,"different route costs exposed")
	check(not start.act("cargo_mod_power").changed,"no remote reward")
	var broken:=G.generate(1,1);broken.grid[7][1]="."
	check(not G.validate(broken).ok,"free route bypass rejected")
	broken=G.generate(1,1);broken.grid[2][12]="."
	check(not G.validate(broken).ok,"treasure bypass rejected")
	print("ENDLESS V2: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(1 if failures else 0)
