extends RefCounted
## 雷鸣足迹只修改本趟事务状态；无伤害、击退、移速和主动攻击事件。
const Catalog=preload("res://data/maze/capture_catalog.gd")
const Water=preload("res://scripts/maze/ahong_water.gd")
const EPS=0.000001

static func rules(rank: int) -> Dictionary:
	return {"distance":48.0,"interval":0.6,"radius":30.0 if rank>=3 else 24.0,"duration":4.0 if rank>=2 else 3.0,"limit":8 if rank>=5 else 6,"stun":0.5 if rank>=4 else 0.4,"reuse":3.0,"water":2.0 if rank>=6 else 1.0}

static func rank_for(run: Dictionary) -> int:
	for member in run.members:
		if member.id=="ahong": return int(member.rank)
	return 0

static func fighting(run: Dictionary) -> bool:
	var c: Dictionary=run.combat
	if c.hp<=0: return false
	if bool(c.get("axe_pending",false)) or float(c.get("action_left",0.0))>0: return true
	for key in ["shots","enemy_shots"]:
		if not c.get(key,[]).is_empty(): return true
	for id in c.actors:
		if not Catalog.active(c,id) or run.monsters[id].status!="alive": continue
		var a: Dictionary=c.actors[id]
		if a.hp>0 and a.mode in ["chase","windup"]: return true
		if not a.get("frog_shots",[]).is_empty(): return true
	return false

static func clear(c: Dictionary) -> bool:
	var changed:=c.erase("ahong_trail")
	for a in c.get("actors",{}).values(): changed=a.erase("ahong_stun") or changed
	return changed

static func paralyzed(a: Dictionary) -> bool:
	return float(a.get("ahong_stun",0.0))>EPS

static func begin_step(run: Dictionary,point: Vector2,dt: float) -> void:
	var c: Dictionary=run.combat
	var rank:=rank_for(run)
	if rank<=0 or not fighting(run):
		clear(c)
		return
	var config:=rules(rank)
	if not c.has("ahong_trail"):
		c.ahong_trail={"position":c.hero.duplicate(),"distance":0.0,"clock":0.0,"marks":[],"reuse":{},"region":str(c.get("region","maze_entry")),"rank":rank}
	var s: Dictionary=c.ahong_trail
	if s.region!=str(c.get("region","maze_entry")):
		clear(c)
		return
	for id in s.reuse.keys():
		s.reuse[id]=maxf(0.0,float(s.reuse[id])-dt)
		if s.reuse[id]<=EPS: s.reuse.erase(id)
	var remaining: Array=[]
	for mark in s.marks:
		mark.left=maxf(0.0,float(mark.left)-dt)
		if mark.left>EPS: remaining.append(mark)
	s.marks=remaining
	var last:=Vector2(s.position[0],s.position[1])
	var moved:=last.distance_to(point)
	s.distance=minf(48.0,float(s.distance)+moved)
	s.clock=minf(float(config.interval),float(s.clock)+dt)
	s.position=[point.x,point.y]
	if moved>EPS and s.distance+0.001>=float(config.distance) and s.clock+EPS>=float(config.interval):
		var water_id:=Water.component(point,str(s.region))
		s.marks.append({"position":[point.x,point.y],"left":float(config.water) if water_id>0 else float(config.duration),"water":water_id})
		while s.marks.size()>int(config.limit): s.marks.pop_front()
		s.distance=0.0
		s.clock=0.0
	for row in Catalog.rows(c):
		var a: Dictionary=c.actors[row.id]
		if run.monsters[row.id].status!="alive" or a.hp<=0 or a.mode=="return" or not Catalog.targetable(c,row.id): continue
		var life:=str(row.id)+":"+str(run.monsters[row.id].get("refresh_count",0))
		if s.reuse.has(life): continue
		var p:=Vector2(a.position[0],a.position[1])
		for mark in s.marks:
			var touched:=Water.component(p,str(s.region))==int(mark.water) if int(mark.water)>0 else p.distance_to(Vector2(mark.position[0],mark.position[1]))<=float(config.radius)
			if not touched: continue
			a.ahong_stun=float(config.stun)
			a.velocity=[0.0,0.0]
			s.reuse[life]=float(config.reuse)
			break

static func end_step(run: Dictionary,dt: float) -> void:
	var c: Dictionary=run.combat
	for a in c.actors.values():
		if not a.has("ahong_stun"): continue
		a.ahong_stun=maxf(0.0,float(a.ahong_stun)-dt)
		if a.ahong_stun<=EPS or a.hp<=0: a.erase("ahong_stun")
	if not fighting(run): clear(c)

static func valid(c: Dictionary) -> bool:
	if not c.get("actors",{}) is Dictionary: return false
	for a in c.get("actors",{}).values():
		if not a is Dictionary: return false
		if a.has("ahong_stun") and not number(a.ahong_stun,0.5): return false
	if not c.has("ahong_trail"): return true
	var s: Variant=c.ahong_trail
	if not s is Dictionary or not point(s.get("position")) or not number(s.get("distance"),48.0) or not number(s.get("clock"),0.6): return false
	if not number(s.get("rank"),6) or s.rank<1 or floor(float(s.rank))!=float(s.rank): return false
	if s.get("region") not in ["maze_entry","fenshui","salt_pool","moss_pool"]: return false
	if not s.get("marks") is Array or s.marks.size()>int(rules(int(s.rank)).limit) or not s.get("reuse") is Dictionary: return false
	for m in s.marks:
		if not m is Dictionary or not point(m.get("position")) or not number(m.get("water"),100000) or floor(float(m.water))!=float(m.water): return false
		if not number(m.get("left"),float(rules(int(s.rank)).water) if m.water>0 else float(rules(int(s.rank)).duration)) or m.left<=0: return false
	for value in s.reuse.values():
		if not number(value,3.0): return false
	return true

static func number(value: Variant,maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value>=0 and value<=maximum+EPS

static func point(value: Variant) -> bool:
	if not value is Array or value.size()!=2: return false
	for v in value:
		if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)): return false
	return true
