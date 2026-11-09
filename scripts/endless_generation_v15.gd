class_name TowerEndlessGenerationV15
extends "res://scripts/endless_generation_v14.gd"
const G14=preload("res://scripts/endless_generation_v14.gd")
const ENEMIES:Array=["g","b","w","r","c","t","p","V"]
static func camp_position(_seed:int,f:int)->Vector2i:return Vector2i(2,2) if f%2 else Vector2i(12,12)
static func skill_position(_seed:int,f:int)->Vector2i:return Vector2i(3,2) if f%2 else Vector2i(11,12)
static func connected(g:Array,start:Vector2i,safe:bool=false)->Dictionary:
	var seen:Dictionary={start:true};var queue:Array[Vector2i]=[start];var head:=0
	while head<queue.size():
		var p:=queue[head];head+=1
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var q:Vector2i=p+d
			if q.x<0 or q.y<0 or q.x>=15 or q.y>=15 or seen.has(q):continue
			var t:String=g[q.y][q.x]
			if t=="#" or (safe and (t in ENEMIES or t in ["D","M","S"])):continue
			seen[q]=true;queue.append(q)
	return seen
static func generate(seed:int,f:int)->Dictionary:
	var data:Dictionary=G14.generate(seed,f)
	if not data.ok:return data
	var g:Array=data.grid;var repairs:Array=[]
	for token in ["M","S"]:
		var destination:Vector2i=camp_position(seed,f) if token=="M" else skill_position(seed,f)
		if g[destination.y][destination.x]==token:continue
		if g[destination.y][destination.x] not in [".","#"]:return {"ok":false,"errors":["station relocation would overwrite object"]}
		for y in 15:
			for x in 15:
				if g[y][x]==token:g[y][x]="."
		g[destination.y][destination.x]=token;repairs.append({"station":token,"to":destination})
	# Retain every old floor/reward. Only add audited connecting passages.
	for attempt in range(225):
		var seen:=connected(g,data.entry);var island:=Vector2i(-1,-1)
		for y in 15:
			for x in 15:
				if g[y][x]!="#" and not seen.has(Vector2i(x,y)):island=Vector2i(x,y);break
			if island.x>=0:break
		if island.x<0:break
		var candidates:Array=[]
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var p:=island;var carve:Array=[];var length:=0
			while true:
				p+=d;length+=1
				if p.x<=0 or p.y<=0 or p.x>=14 or p.y>=14:break
				if seen.has(p):
					candidates.append({"carve":carve.duplicate(),"length":length});break
				if g[p.y][p.x]=="#":carve.append(p)
		candidates.sort_custom(func(a,b):return a.carve.size()<b.carve.size() if a.carve.size()!=b.carve.size() else a.length<b.length)
		var accepted:=false
		for candidate in candidates:
			var trial:Dictionary=data.duplicate(true)
			for p in candidate.carve:trial.grid[p.y][p.x]="."
			if G14.validate(trial).ok:
				for p in candidate.carve:g[p.y][p.x]="."
				repairs.append({"island":island,"carved":candidate.carve});accepted=true;break
		if not accepted:return {"ok":false,"errors":["no safe island connection"],"seed":seed,"floor":f,"island":island}
	data.repairs=repairs;data.revision=15;data.proof=validate(data);data.ok=data.proof.ok;return data
static func validate(data:Dictionary)->Dictionary:
	var prior:Dictionary=G14.validate(data)
	if not prior.ok:return prior
	var g:Array=data.grid;var errors:Array=[];var all:=connected(g,data.entry);var safe:=connected(g,data.entry,true)
	for y in 15:
		for x in 15:
			if g[y][x]!="#" and not all.has(Vector2i(x,y)):errors.append("isolated floor or object")
	for p in [camp_position(data.seed,data.floor),skill_position(data.seed,data.floor)]:
		if g[p.y][p.x]!=("M" if p==camp_position(data.seed,data.floor) else "S"):errors.append("station identity")
		var reachable:=false
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if safe.has(p+d):reachable=true
		if not reachable:errors.append("station outside entrance safe zone")
	return {"ok":errors.is_empty(),"errors":errors}
