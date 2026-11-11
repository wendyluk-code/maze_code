extends RefCounted
## 冲撞状态和碰撞分类；伤害由统一主动入口结算，事务由探索负责。
const Catalog=preload("res://data/maze/capture_catalog.gd")
const Tide=preload("res://scripts/maze/xiluomei_net.gd")
const Roads=preload("res://data/maze/entry_roads.gd")
const Fenshui=preload("res://data/maze/fenshui_roads.gd")
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Moss=preload("res://data/maze/moss_pool_roads.gd")
const Routes=preload("res://data/maze/region_routes.gd")
static func rules(rank: int) -> Dictionary:
	return {"distance":120.0 if rank>=3 else 100.0,"damage":1.0 if rank>=6 else (0.9 if rank>=2 else 0.8),"wall":0.9 if rank>=6 else (0.7 if rank>=4 else 0.5),"boost":rank>=5}
static func active(c: Dictionary) -> bool: return c.has("lanjiao_charge")
static func speed(c: Dictionary) -> float: return 1.15 if float(c.get("lanjiao_boost",0.0))>0 else 1.0
static func clear(c: Dictionary) -> bool:
	var changed:=c.erase("lanjiao_charge")
	return c.erase("lanjiao_boost") or changed
static func begin(c: Dictionary,rank: int,amount: int,aim: Vector2) -> void:
	c.lanjiao_charge={"rank":rank,"damage":amount,"aim":[aim.x,aim.y],"warmup":0.2,"left":0.25,"hit_ids":[]}
static func terrain(region: String):
	if region=="fenshui": return Fenshui
	if region=="salt_pool": return Salt
	if region=="moss_pool": return Moss
	return Roads
static func portals(region: String) -> Array:
	if region=="maze_entry": return [preload("res://data/maze/settlement_exit.gd").POSITION]
	var points: Array=[Routes.route(region).marker]
	if region=="fenshui": points.append(Salt.FENSHUI_PORTAL)
	if region=="salt_pool": points.append(Moss.SALT_SIDE_MARKER)
	if region=="moss_pool": points.append(Moss.SALT_MARKER)
	return points
static func player_allowed(a: Vector2,b: Vector2,region: String) -> bool:
	if not terrain(region).is_walkable(b): return false
	for p in portals(region):
		var next: Vector2=b-p
		if absf(next.x)>=58 or absf(next.y)>=20: continue
		var old: Vector2=a-p
		if absf(old.x)<58 and absf(old.y)<20 and next.length_squared()>old.length_squared(): continue
		return false
	return true
## 地图边界和站位留白不是实体障碍；仅复用既有栅栏、岛礁、盐晶。
static func solid(p: Vector2,region: String,radius: float=0.0) -> bool:
	if region=="moss_pool": return false
	if region=="maze_entry": return p.y+radius>1081.0 and p.x-radius<684.0 and p.x>=0 and p.y>=0 and p.x<=Roads.SIZE.x and p.y<=Roads.SIZE.y
	if region=="fenshui":
		if preload("res://data/maze/fenshui_gates.gd").blocks(p,radius): return true
		for shape in Fenshui.ISLANDS:
			if ((p-Vector2(shape.x,shape.y))/(Vector2(shape.z,shape.w)+Vector2.ONE*radius)).length()<=1: return true
	else:
		for shape in Salt.OBSTACLES:
			if ((p-Vector2(shape.x,shape.y))/(Vector2(shape.z,shape.w)+Vector2.ONE*radius)).length()<=1: return true
		for shapes in preload("res://scripts/maze/salt_crystals.gd").SHAPES:
			for polygon in shapes:
				if Geometry2D.is_point_in_polygon(p,polygon): return true
				for i in polygon.size():
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()]))<radius: return true
	return false
static func push(run: Dictionary,row: Dictionary,aim: Vector2) -> bool:
	var a: Dictionary=run.combat.actors[row.id]
	var current:=Tide.vec(a.position)
	var region:=str(run.combat.get("region","maze_entry"))
	var radius:=Catalog.Fenshui.BODY_RADIUS if region=="fenshui" else (Catalog.Salt.BODY_RADIUS if region=="salt_pool" else Roads.FOOT_RADIUS)
	for i in 60:
		var next:=current+aim*0.5
		if solid(next,region,radius): return true
		var moved:=Tide.displace(run,row,current,aim*0.5)
		if moved.distance_to(next)>0.01: return false
		current=moved
		a.position=Tide.pack(current)
	return false
static func advance(run: Dictionary,dt: float) -> Array:
	var c: Dictionary=run.combat
	if c.has("lanjiao_boost"):
		c.lanjiao_boost=maxf(0.0,float(c.lanjiao_boost)-dt)
		if c.lanjiao_boost<=0: c.erase("lanjiao_boost")
	if not active(c): return []
	if c.hp<=0: clear(c); return []
	var s: Dictionary=c.lanjiao_charge
	var used:=minf(dt,float(s.warmup))
	s.warmup=maxf(0,float(s.warmup)-used)
	dt-=used
	if dt<=0.0000001: return []
	used=minf(dt,float(s.left))
	var config:=rules(int(s.rank))
	var aim:=Tide.vec(s.aim)
	var distance:=float(config.distance)*used/0.25
	var origin:=Tide.vec(c.hero)
	var current:=origin
	var region:=str(c.get("region","maze_entry"))
	var blocked:=false
	var events: Array=[]
	var count:=maxi(1,ceili(distance/0.5))
	for i in range(1,count+1):
		var next:=origin+aim*distance*float(i)/count
		if not player_allowed(current,next,region): blocked=true; break
		current=next
		for row in Catalog.rows(c):
			var a: Dictionary=c.actors[row.id]
			if row.id in s.hit_ids or run.monsters[row.id].status!="alive" or a.hp<=0 or a.mode=="return" or not Catalog.targetable(c,row.id): continue
			if current.distance_to(Tide.vec(a.position))>24: continue
			if not Tide.visible_line(current,Tide.vec(a.position),region): continue
			s.hit_ids.append(row.id)
			var wall:=false
			if row.kind not in ["wind_frog","rockmane","lizard"] and not row.get("elite",false): wall=push(run,row,aim)
			events.append({"id":row.id,"damage":roundi(float(s.damage)*float(config.damage)),"wall":roundi(float(s.damage)*float(config.wall)) if wall else 0})
	c.hero=Tide.pack(current)
	s.left=maxf(0.0,float(s.left)-used)
	if blocked or s.left<=0.0000001:
		c.erase("lanjiao_charge")
		if config.boost: c.lanjiao_boost=1.0
	return events
static func valid(c: Dictionary) -> bool:
	if c.has("lanjiao_boost") and not Tide.number(c.lanjiao_boost,1): return false
	if not active(c): return true
	var s: Variant=c.lanjiao_charge
	if not s is Dictionary: return false
	if not Tide.number(s.get("rank"),6) or s.rank<1 or floor(float(s.rank))!=s.rank: return false
	if not Tide.number(s.get("damage"),9007199254740991) or floor(float(s.damage))!=s.damage: return false
	if not Tide.point(s.get("aim")) or absf(Tide.vec(s.aim).length()-1)>0.001: return false
	if not Tide.number(s.get("warmup"),0.2) or not Tide.number(s.get("left"),0.25) or s.left<=0: return false
	if not s.get("hit_ids") is Array: return false
	var seen: Dictionary={}
	for id in s.hit_ids:
		if not id is String or not c.actors.has(id) or seen.has(id): return false
		seen[id]=true
	return true
