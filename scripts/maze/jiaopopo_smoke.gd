extends RefCounted
## 椒婆婆烟区纯状态；外层探索事务负责保存和失败回滚。
const Catalog = preload("res://data/maze/capture_catalog.gd")

static func rules(rank: int) -> Dictionary:
	return {"range":260.0,"radius":80.0 if rank>=3 else 65.0,"duration":4.0 if rank>=5 else 3.0,"ratio":0.4 if rank>=2 else 0.35,"slow":0.3 if rank>=4 else 0.2,"retreat":rank>=6}

static func clear(c: Dictionary) -> bool:
	return c.erase("jiaopopo_smoke")

static func land(c: Dictionary, position: Vector2, rank: int, damage: int) -> void:
	c.jiaopopo_smoke={"position":[position.x,position.y],"rank":rank,"damage":damage,"elapsed":0.0,"ticks":0,"stays":{},"retreated":{},"retreats":{}}

static func contains(c: Dictionary, point: Vector2) -> bool:
	var smoke: Dictionary=c.get("jiaopopo_smoke",{})
	if smoke.is_empty(): return false
	var config:=rules(int(smoke.rank))
	return float(smoke.elapsed)<float(config.duration) and point.distance_to(Vector2(smoke.position[0],smoke.position[1]))<=float(config.radius)

static func speed(c: Dictionary, point: Vector2) -> float:
	if not contains(c,point): return 1.0
	return 1.0-float(rules(int(c.jiaopopo_smoke.rank)).slow)

static func retreating(c: Dictionary, id: String) -> bool:
	return c.get("jiaopopo_smoke",{}).get("retreats",{}).has(id)

static func retreat_step(c: Dictionary, id: String, dt: float, base_speed: float) -> Vector2:
	var retreats: Dictionary=c.get("jiaopopo_smoke",{}).get("retreats",{})
	if not retreats.has(id): return Vector2.ZERO
	var r: Dictionary=retreats[id]
	var used:=minf(dt,float(r.left))
	r.left=maxf(0.0,float(r.left)-dt)
	var step:=Vector2(r.direction[0],r.direction[1])*base_speed*used
	if r.left<=0.0000001: retreats.erase(id)
	return step

## 在期限端点结算最后一跳，再清除烟区。此函数返回伤害名单，不调用直接命中。
static func advance(run: Dictionary, dt: float) -> Array:
	var c: Dictionary=run.combat
	if c.hp<=0:
		clear(c)
		return []
	var smoke: Dictionary=c.get("jiaopopo_smoke",{})
	if smoke.is_empty(): return []
	var config:=rules(int(smoke.rank))
	var finish:=minf(float(config.duration),float(smoke.elapsed)+dt)
	if finish>=float(config.duration)-0.0000001: finish=float(config.duration)
	var ticks:=mini(int(config.duration),int(floor(finish+0.0000001)))
	var events: Array=[]
	for row in Catalog.rows(c):
		var actor: Dictionary=c.actors[row.id]
		var life:=str(row.id)+":"+str(run.monsters[row.id].get("refresh_count",0))
		if run.monsters[row.id].status!="alive" or actor.hp<=0 or actor.mode=="return" or not Catalog.targetable(c,row.id):
			smoke.stays.erase(life)
			smoke.retreats.erase(row.id)
			continue
		var position:=Vector2(actor.position[0],actor.position[1])
		if not contains(c,position):
			smoke.stays.erase(life)
			continue
		if config.retreat and row.kind not in ["wind_frog","rockmane","lizard"]:
			smoke.stays[life]=minf(2.0,float(smoke.stays.get(life,0.0))+finish-float(smoke.elapsed))
			if float(smoke.stays[life])>=2.0-0.0000001 and not smoke.retreated.has(life):
				var direction:=Vector2(smoke.position[0],smoke.position[1]).direction_to(position)
				if direction.is_zero_approx(): direction=Vector2(c.hero[0],c.hero[1]).direction_to(position)
				if direction.is_zero_approx(): direction=Vector2.RIGHT
				smoke.retreated[life]=true
				smoke.retreats[row.id]={"left":0.6,"direction":[direction.x,direction.y]}
				actor.windup=0.0
				actor.cast=0.0
				actor.mode="chase"
		for tick in range(int(smoke.ticks),ticks):
			events.append({"id":row.id,"damage":roundi(float(smoke.damage)*float(config.ratio))})
	smoke.elapsed=finish
	smoke.ticks=ticks
	if finish>=float(config.duration): clear(c)
	return events

static func valid(c: Dictionary) -> bool:
	if not c.has("jiaopopo_smoke"): return true
	var s: Variant=c.jiaopopo_smoke
	if not s is Dictionary: return false
	if not s.get("position") is Array or s.position.size()!=2: return false
	for value in s.position:
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
	for key in ["rank","damage","elapsed","ticks"]:
		if typeof(s.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(s[key])) or s[key]<0: return false
	if s.rank<1 or s.rank>6 or floor(float(s.rank))!=float(s.rank): return false
	if floor(float(s.damage))!=float(s.damage) or s.damage>9007199254740991: return false
	if s.elapsed>=float(rules(int(s.rank)).duration): return false
	if s.ticks!=floor(float(s.elapsed)+0.0000001): return false
	for key in ["stays","retreated","retreats"]:
		if not s.get(key) is Dictionary: return false
	for value in s.stays.values():
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0 or value>2: return false
	for value in s.retreated.values():
		if value!=true: return false
	for id in s.retreats:
		var r: Variant=s.retreats[id]
		if not c.get("actors",{}).has(id) or not r is Dictionary: return false
		if typeof(r.get("left")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(r.left)) or r.left<=0 or r.left>0.6: return false
		if not r.get("direction") is Array or r.direction.size()!=2: return false
		for value in r.direction:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
		if absf(Vector2(r.direction[0],r.direction[1]).length()-1)>0.001: return false
	return true
