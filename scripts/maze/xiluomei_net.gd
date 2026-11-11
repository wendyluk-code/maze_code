extends RefCounted
## 潮汐之网纯状态。伤害由主动入口结算，保存与回滚由探索事务负责。
const Catalog=preload("res://data/maze/capture_catalog.gd")
const Roads=preload("res://data/maze/entry_roads.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")

static func rules(rank: int) -> Dictionary:
	return {"range":280.0,"radius":105.0 if rank>=3 else 90.0,"first":0.7 if rank>=5 else 0.5,"out":0.9 if rank>=4 else 0.7,"close":1.1 if rank>=2 else 0.9,"pull":40.0,"push":45.0 if rank>=6 else 30.0,"root":0.6 if rank>=6 else 0.0}

static func vec(p: Array) -> Vector2: return Vector2(p[0],p[1])
static func pack(p: Vector2) -> Array: return [p.x,p.y]
static func rooted(a: Dictionary) -> bool: return float(a.get("tide_root",0.0))>0.0
static func speed(a: Dictionary) -> float: return 0.7 if float(a.get("tide_slow",0.0))>0.0 else 1.0

static func center_for(origin: Vector2,aim: Vector2,region: String) -> Vector2:
	var size: Vector2=Catalog.Fenshui.Roads.SIZE if region=="fenshui" else (Catalog.Salt.Roads.SIZE if region=="salt_pool" else Roads.SIZE)
	var result:=origin
	for i in range(1,561):
		var p:=origin+aim*float(i)*0.5
		if p.x<0 or p.y<0 or p.x>size.x or p.y>size.y or not visible_line(result,p,region): break
		result=p
	return result

static func clear(c: Dictionary) -> bool:
	var changed:=c.erase("xiluomei_net")
	changed=c.erase("xiluomei_feedback") or changed
	for a in c.get("actors",{}).values():
		changed=a.erase("tide_slow") or changed
		changed=a.erase("tide_root") or changed
	return changed

static func open(run: Dictionary, center: Vector2, rank: int, damage: int, aim: Vector2) -> void:
	run.combat.xiluomei_net={"position":pack(center),"rank":rank,"damage":damage,"left":1.5,"first_pending":true,"outward":false,"aim":pack(aim),"region":str(run.combat.get("region","maze_entry"))}

static func finish(run: Dictionary, outward: bool) -> Array:
	if not run.combat.has("xiluomei_net"): return []
	var events:=resolve(run,"out" if outward else "close")
	run.combat.erase("xiluomei_net")
	return events

static func resolve(run: Dictionary, stage: String) -> Array:
	var c: Dictionary=run.combat
	var net: Dictionary=c.xiluomei_net
	var config:=rules(int(net.rank))
	var center:=vec(net.position)
	var events: Array=[]
	for row in Catalog.rows(c):
		var a: Dictionary=c.actors[row.id]
		if run.monsters[row.id].status!="alive" or a.hp<=0 or a.mode=="return" or not Catalog.targetable(c,row.id): continue
		var at:=vec(a.position)
		if at.distance_to(center)>float(config.radius) or not visible_line(center,at,str(c.get("region","maze_entry"))): continue
		events.append({"id":row.id,"damage":roundi(float(net.damage)*float(config[stage]))})
		var small: bool=row.kind not in ["wind_frog","rockmane","lizard"] and not bool(row.get("elite",false))
		if stage=="close":
			a.tide_slow=1.0
			if small and config.root>0: a.tide_root=float(config.root)
		elif small:
			var direction:=at.direction_to(center) if stage=="first" else center.direction_to(at)
			if direction.is_zero_approx(): direction=vec(net.aim) if stage=="out" else Vector2.ZERO
			var distance:=minf(float(config.pull),at.distance_to(center)) if stage=="first" else float(config.push)
			a.position=pack(displace(run,row,at,direction*distance))
		if a.mode=="idle": a.mode="chase"
	c.xiluomei_feedback={"position":net.position.duplicate(),"rank":net.rank,"stage":stage,"left":0.3}
	return events

## 空中水网可跨水面；实体遮挡与原投射物保持一致，由调用方传入固定落点。
static func visible_line(a: Vector2,b: Vector2,region: String) -> bool:
	var count:=maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(count+1):
		var p:=a.lerp(b,float(i)/count)
		if region=="fenshui":
			if preload("res://data/maze/fenshui_gates.gd").blocks(p,0.0): return false
			for island in preload("res://data/maze/fenshui_roads.gd").ISLANDS:
				if ((p-Vector2(island.x,island.y))/Vector2(island.z,island.w)).length()<=1: return false
		elif region=="salt_pool":
			for obstacle in preload("res://data/maze/salt_pool_roads.gd").OBSTACLES:
				if ((p-Vector2(obstacle.x,obstacle.y))/Vector2(obstacle.z,obstacle.w)).length()<=1: return false
			for shapes in preload("res://scripts/maze/salt_crystals.gd").SHAPES:
				for polygon in shapes:
					if Geometry2D.is_point_in_polygon(p,polygon): return false
		elif p.y>1081.0 and p.x<684.0: return false
	return true

## 半像素射线截断，不贴墙滑动，不越过怪物活动边界或身体间距。
static func displace(run: Dictionary,row: Dictionary,start: Vector2,delta: Vector2) -> Vector2:
	var count:=maxi(1,ceili(delta.length()/0.5))
	var result:=start
	for i in range(1,count+1):
		var p:=start+delta*float(i)/count
		var region:=str(row.get("region","maze_entry"))
		if region=="fenshui":
			if not Catalog.Fenshui.allowed(p,row.position) or not Spacing.clear(run,row.id,p): break
		elif region=="salt_pool":
			if not Catalog.Salt.allowed(p,row.position): break
		elif not Roads.is_walkable(p) or not Catalog.clear_of_props(p): break
		result=p
	return result

static func advance_controls(run: Dictionary,dt: float) -> void:
	var c: Dictionary=run.combat
	for id in c.actors:
		var a: Dictionary=c.actors[id]
		for key in ["tide_slow","tide_root"]:
			if not a.has(key): continue
			a[key]=maxf(0.0,float(a[key])-dt)
			if a[key]<=0 or a.hp<=0 or a.mode=="return" or run.monsters[id].status!="alive" or not Catalog.active(c,id): a.erase(key)
	if c.has("xiluomei_feedback"):
		c.xiluomei_feedback.left=maxf(0.0,float(c.xiluomei_feedback.left)-dt)
		if c.xiluomei_feedback.left<=0: c.erase("xiluomei_feedback")

static func initial_hits(run: Dictionary) -> Array:
	var c: Dictionary=run.combat
	if c.hp<=0 or not c.has("xiluomei_net"): return []
	if c.xiluomei_net.region!=str(c.get("region","maze_entry")) or not c.xiluomei_net.first_pending: return []
	c.xiluomei_net.first_pending=false
	return resolve(run,"first")

static func advance(run: Dictionary,dt: float) -> Array:
	var c: Dictionary=run.combat
	if c.hp<=0:
		clear(c)
		return []
	if not c.has("xiluomei_net"): return []
	if c.xiluomei_net.region!=str(c.get("region","maze_entry")):
		clear(c)
		return []
	var events: Array=[]
	if c.xiluomei_net.outward:
		events.append_array(finish(run,true))
		return events
	c.xiluomei_net.left=maxf(0.0,float(c.xiluomei_net.left)-dt)
	if c.xiluomei_net.left<=0.0000001: events.append_array(finish(run,false))
	return events

static func number(v: Variant,limit: float) -> bool:
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and v>=0 and v<=limit
static func point(v: Variant) -> bool:
	if not v is Array or v.size()!=2: return false
	for n in v:
		if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)): return false
	return true
static func valid(c: Dictionary) -> bool:
	if not c.get("actors",{}) is Dictionary: return false
	for a in c.get("actors",{}).values():
		if not a is Dictionary: return false
		for key in ["tide_slow","tide_root"]:
			if a.has(key) and not number(a[key],1.0 if key=="tide_slow" else 0.6): return false
	for key in ["xiluomei_net","xiluomei_feedback"]:
		if not c.has(key): continue
		var s: Variant=c[key]
		if not s is Dictionary or not point(s.get("position")) or not number(s.get("rank"),6) or s.rank<1 or floor(float(s.rank))!=float(s.rank): return false
		if not number(s.get("left"),1.5 if key=="xiluomei_net" else 0.3) or s.left<=0: return false
		if key=="xiluomei_net":
			if not s.get("first_pending") is bool or not s.get("outward") is bool: return false
			if not number(s.get("damage"),9007199254740991) or floor(float(s.damage))!=float(s.damage): return false
			if not point(s.get("aim")) or absf(vec(s.aim).length()-1)>0.001: return false
			if s.get("region")!=str(c.get("region","maze_entry")): return false
		elif s.get("stage") not in ["first","out","close"]: return false
	return true
