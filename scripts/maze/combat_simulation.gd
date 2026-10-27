extends RefCounted
## 本趟冻结属性与可序列化战斗状态。所有推进通过 CaptureRun 的事务提交。
const Roads = preload("res://data/maze/entry_roads.gd")
const Catalog = preload("res://data/maze/capture_catalog.gd")
const Rock = preload("res://scripts/maze/rockmane_combat.gd")
const Crystals = preload("res://scripts/maze/salt_crystals.gd")
const Frog = preload("res://scripts/maze/wind_frog_combat.gd")
const WaterSpacing = preload("res://scripts/maze/water_spacing.gd")
const STATS = {
	"rockmane":{"attack":8,"hp":120,"windup":0.7},
	"mimic_crab":{"attack":5,"hp":28,"interval":2.0,"windup":0.65,"speed":80.0,"trigger":100.0,"leash":145.0,"home_limit":75.0,"reach":34.0},
	"blind_scorpion":{"attack":4,"hp":22,"interval":1.8,"windup":0.6,"speed":90.0,"trigger":100.0,"leash":145.0,"home_limit":75.0,"reach":42.0},
	"wind_frog":{"attack":6,"hp":96},
	"silverfish":{"attack":4,"hp":20,"interval":1.8,"windup":0.55,"speed":65.0,"trigger":110.0,"leash":150.0,"home_limit":85.0,"reach":35.0},
	"thunder_eel":{"attack":5,"hp":30,"interval":2.2,"windup":0.8,"speed":55.0,"trigger":110.0,"leash":150.0,"home_limit":85.0,"reach":70.0},
	"slime":{"attack":3,"hp":14,"interval":1.8,"windup":0.45,"speed":85.0,"trigger":150.0,"leash":420.0,"home_limit":600.0,"reach":32.0},
	"snail":{"attack":5,"hp":28,"interval":2.0,"windup":0.6,"speed":65.0,"trigger":140.0,"leash":380.0,"home_limit":520.0,"reach":32.0},
	"beetle":{"attack":4,"hp":21,"interval":1.3,"windup":0.35,"speed":145.0,"trigger":190.0,"leash":500.0,"home_limit":750.0,"reach":32.0},
	"lizard":{"attack":8,"hp":84,"interval":2.2,"windup":0.7,"speed":100.0,"trigger":200.0,"leash":550.0,"home_limit":700.0,"reach":40.0}
}
const INTERVAL = 0.9
const RANGE = 180.0
const FLIGHT = 0.35
const HIT_DURATION = 0.12
const FLASH_DURATION = 0.1
const Skills = preload("res://scripts/maze/team_attack.gd")

# 受击状态随伤害事务保存；读档仅续完剩余时间，不重放整段。
static func hit(actor: Dictionary, position: Vector2, source: Vector2, distance: float) -> void:
	var direction := source.direction_to(position)
	if direction.is_zero_approx(): direction = Vector2.DOWN
	actor.hit_velocity = pack(direction * distance / HIT_DURATION)
	actor.hit_remaining = HIT_DURATION
	actor.flash_remaining = FLASH_DURATION

static func advance_hit(actor: Dictionary, position: Vector2, dt: float, region: String = "maze_entry", home: Vector2 = Vector2.INF) -> Vector2:
	actor.flash_remaining = maxf(0.0, float(actor.get("flash_remaining", 0.0)) - dt)
	var remaining := float(actor.get("hit_remaining", 0.0))
	if remaining <= 0.0: return position
	var displacement := vec(actor.get("hit_velocity", [0.0, 0.0])) * minf(dt, remaining)
	actor.hit_remaining = maxf(0.0, remaining - dt)
	# 沿受击射线截断，不使用道路移动的贴墙滑动，防止改变击退方向。
	var steps := maxi(1, ceili(displacement.length() / 0.5))
	var current := position
	for i in range(1, steps + 1):
		var next := position + displacement * float(i) / steps
		if not terrain(region).is_walkable(next) or (home!=Vector2.INF and not (Catalog.Salt.allowed(next,home) if region=="salt_pool" else Catalog.Fenshui.allowed(next,home))):
			actor.hit_remaining = 0.0
			break
		current = next
	return current

static func clear_hit(actor: Dictionary) -> void:
	actor.erase("hit_remaining")
	actor.erase("hit_velocity")
	actor.erase("flash_remaining")

## 物件只限制魔物站位；玩家通路和拾取范围保持原规则。
static func move_monster(origin: Vector2, target: Vector2, distance: float) -> Vector2:
	var start := Catalog.nearest_clear_point(origin)
	var goal := Catalog.nearest_clear_point(target)
	var direction := start.direction_to(goal)
	var step := minf(distance,start.distance_to(goal))
	var best := start
	var score := start.distance_squared_to(goal)
	for angle in [0.0,0.4,-0.4,0.8,-0.8,1.2,-1.2]:
		var candidate := Roads.move_on_road(start,direction.rotated(angle)*step)
		if not Catalog.clear_of_props(candidate): continue
		if candidate.distance_squared_to(goal) < score:
			best = candidate
			score = candidate.distance_squared_to(goal)
	return best

static func vec(a: Array) -> Vector2:
	return Vector2(float(a[0]),float(a[1]))

static func pack(p: Vector2) -> Array:
	return [p.x,p.y]

static func create(attack: int, health: int, point: Vector2, rows: Array = []) -> Dictionary:
	var actors := {}
	if rows.is_empty(): rows = Catalog.all()
	for row in rows:
		actors[row.id] = fresh_actor(row.kind, row.position)
	return {"version":1,"attack":attack,"max_hp":health,"hp":health,"hero":pack(point),"cooldown":INTERVAL,"actors":actors,"shots":[],"last_attacker":"slime","elapsed":0.0,"sprint":1.0,"sprint_rest":0.0,"throws":0,"hits":0,"layout":rows.map(func(r): return {"kind":r.kind,"position":[r.position.x,r.position.y]})}

static var navigation: AStar2D
static var segments: Array = []
static var nav_count := 0

static func fresh_actor(kind: String, point: Vector2) -> Dictionary:
	return {"position":pack(point),"hp":STATS[kind].hp,"mode":"idle","windup":0.0,"cooldown":0.0,"away":0.0,"velocity":[0.0,0.0]}

static func life_ids(run: Dictionary) -> Dictionary:
	var lives := {}
	for id in run.monsters: lives[id] = int(run.monsters[id].get("refresh_count",0))
	return lives

static func _navigation() -> void:
	if navigation!=null: return
	navigation=AStar2D.new()
	var ids := {}
	for road in Roads.roads():
		var last := -1
		for point in road.points:
			if not ids.has(point):
				ids[point]=ids.size()
				navigation.add_point(ids[point],point)
			var index: int=ids[point]
			if last>=0:
				if not navigation.are_points_connected(last,index): navigation.connect_points(last,index)
				segments.append({"a":navigation.get_point_position(last),"b":point,"from":last,"to":index,"width":road.width})
			last=index
	nav_count=ids.size()

static func walkable(point: Vector2, radius: float = 0.0) -> bool:
	# 玩家、追击直线与近战共用道路并集，包含已校准的额外可走区。
	# 道路中心线仍用于绕障寻路，不能代替实际脚底可走范围。
	return Roads.is_walkable(point, radius)

static func clear_line(a: Vector2, b: Vector2, radius: float = 0.0) -> bool:
	var count := maxi(1,ceili(a.distance_to(b)/3.0))
	for i in range(count+1):
		if not walkable(a.lerp(b,float(i)/count),radius): return false
	return true

## 空中投射物不沿用脚下道路通行范围；只检查地图边界与已有实体栅栏。
static func projectile_clear(point: Vector2, region: String = "maze_entry") -> bool:
	if region in ["fenshui","salt_pool"]:
		var bounds: Vector2 = terrain(region).SIZE
		if not point.is_finite() or point.x<0 or point.y<0 or point.x>bounds.x or point.y>bounds.y: return false
		# 水面、岸边和行走遮罩不属于空中弹道障碍；实体物件单独处理。
		if region=="fenshui":
			if preload("res://data/maze/fenshui_gates.gd").blocks(point,0.0): return false
			for island in preload("res://data/maze/fenshui_roads.gd").ISLANDS:
				if ((point-Vector2(island.x,island.y))/Vector2(island.z,island.w)).length()<=1.0: return false
		else:
			for obstacle in preload("res://data/maze/salt_pool_roads.gd").OBSTACLES:
				if ((point-Vector2(obstacle.x,obstacle.y))/Vector2(obstacle.z,obstacle.w)).length()<=1.0: return false
			for shapes in Crystals.SHAPES:
				for polygon in shapes:
					if Geometry2D.is_point_in_polygon(point,polygon): return false
		return true
	if not point.is_finite() or point.x<0 or point.y<0 or point.x>Roads.SIZE.x or point.y>Roads.SIZE.y: return false
	return not (point.y>1081.0 and point.x<684.0)

static func _nearest_segment(point: Vector2) -> Dictionary:
	var best := INF
	var result := {}
	for segment in segments:
		var distance := point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,segment.a,segment.b))
		if distance<best:
			best=distance
			result=segment
	return result

# 复用道路图，仅接入所在路段两端；不逐帧重建图或遍历所有可见点。
static func next_waypoint(origin: Vector2, target: Vector2) -> Vector2:
	if clear_line(origin,target,Roads.FOOT_RADIUS): return target
	_navigation()
	var start_segment := _nearest_segment(origin)
	var end_segment := _nearest_segment(target)
	navigation.add_point(nav_count,origin)
	navigation.add_point(nav_count+1,target)
	for id in [start_segment.from,start_segment.to]: navigation.connect_points(nav_count,id)
	for id in [end_segment.from,end_segment.to]: navigation.connect_points(nav_count+1,id)
	var path := navigation.get_point_path(nav_count,nav_count+1)
	navigation.remove_point(nav_count)
	navigation.remove_point(nav_count+1)
	# 临时起点可能与道路节点重合；跳过零长度首边，避免原地重复寻路。
	for point in path:
		if origin.distance_squared_to(point)>0.0001: return point
	return origin

static func advance(run: Dictionary, point: Vector2, dt: float, sprinting: bool = false) -> void:
	var c: Dictionary = run.combat
	c.hero=pack(point)
	Rock.advance(run, point, dt)
	Frog.advance(run, point, dt)
	Skills.advance(run, point, dt)
	# 旧档缺字段按满条初始化；只保存资源与恢复时钟，不保存按键。
	c.sprint = clampf(float(c.get("sprint",1.0)),0.0,1.0)
	c.sprint_rest = float(c.get("sprint_rest",0.0))
	if sprinting and c.sprint>0.0:
		c.sprint=maxf(0.0,c.sprint-dt/5.0)
		c.sprint_rest=0.0
	else:
		var recovery := maxf(0.0,c.sprint_rest+dt-1.0)-maxf(0.0,c.sprint_rest-1.0)
		c.sprint_rest=minf(1.0,c.sprint_rest+dt)
		c.sprint=minf(1.0,c.sprint+recovery/8.0)
	point = advance_hit(c, point, dt, str(c.get("region","maze_entry")))
	c.hero = pack(point)
	c.elapsed += dt
	# 近战先于投射物结算：同一推进中主角归零优先失败。
	for row in Catalog.rows(c):
		var a: Dictionary = c.actors[row.id]
		if run.monsters[row.id].status!="alive" or a.hp<=0: continue
		if row.kind in ["wind_frog","rockmane"]:
			a.flash_remaining=maxf(0.0,float(a.get("flash_remaining",0.0))-dt)
			continue
		var s: Dictionary = STATS[row.kind]
		var pos := vec(a.position)
		var recoiling := float(a.get("hit_remaining", 0.0)) > 0.0
		var hit_position := advance_hit(a, pos, dt, str(c.get("region","maze_entry")),row.position if row.get("region","") in ["fenshui","salt_pool"] else Vector2.INF)
		if row.get("region","")=="fenshui" and not WaterSpacing.clear(run,row.id,hit_position): hit_position=pos
		a.position = pack(hit_position if row.get("region","") in ["fenshui","salt_pool"] or Catalog.clear_of_props(hit_position) else Catalog.nearest_clear_point(pos))
		pos = vec(a.position)
		var distance := pos.distance_to(point)
		# 玩家可以站在可交互物件旁；魔物接近物件边缘后仍可攻击，避免安全岛。
		var attack_distance := distance if row.get("region","") in ["fenshui","salt_pool"] else pos.distance_to(Catalog.nearest_clear_point(point))
		a.cooldown = maxf(0.0,a.cooldown-dt)
		if recoiling:
			a.velocity=a.get("hit_velocity",[0.0,0.0]).duplicate()
			continue
		if a.mode=="idle" and distance<=s.trigger and not protected(row,point): a.mode="chase"
		if a.mode in ["chase","windup"]:
			a.away = a.away+dt if distance>s.leash else 0.0
			if a.away>=1.0 or (row.get("region","")!="fenshui" and pos.distance_to(row.position)>=s.home_limit) or protected(row,point):
				a.mode="return"
				a.windup=0.0
		if a.mode=="return":
			clear_hit(a)
			if row.get("region","")=="fenshui":
				a.mode="idle"
				a.hp=s.hp
				a.away=0.0
				a.velocity=[0.0,0.0]
				continue
			var destination: Vector2 = row.position if row.get("region","") in ["fenshui","salt_pool"] else next_waypoint(pos,row.position)
			var moved := move_actor(row,pos,pos.direction_to(destination)*minf(s.speed*dt,pos.distance_to(destination))) if row.get("region","") in ["fenshui","salt_pool"] else move_monster(pos,destination,s.speed*dt)
			a.position=pack(moved)
			if moved.distance_to(row.position)<=2.0:
				a.position=pack(row.position if row.get("region","") in ["fenshui","salt_pool"] else Catalog.nearest_clear_point(row.position))
				a.hp=s.hp
				a.mode="idle"
				a.away=0.0
				a.cooldown=0.0
		elif a.mode=="windup":
			a.windup=maxf(0.0,a.windup-dt)
			if a.windup<=0.00001:
				if c.hp>0 and attack_distance<=s.reach and attack_line(row,pos,point) and aimed_hit(a,row,pos,point):
					c.hp=maxf(0,c.hp-Skills.incoming_damage(run, int(s.attack)))
					c.last_attacker=row.kind
					hit(c, point, pos, 18.0)
				a.mode="chase"
		elif a.mode=="chase":
			if attack_distance<=s.reach and attack_line(row,pos,point):
				if a.cooldown<=0.00001:
					a.mode="windup"
					a.windup=s.windup
					if row.get("region","")=="salt_pool":
						var aim := pos.direction_to(point)
						a["attack_aim"]=pack(Vector2.DOWN if aim.is_zero_approx() else aim)
					a.cooldown=s.interval
			elif float(a.get("cast",0.0)) <= 0.0 and not recoiling:
				var destination: Vector2 = point if row.get("region","") in ["fenshui","salt_pool"] else next_waypoint(pos,point)
				a.position=pack(move_actor(row,pos,pos.direction_to(destination)*minf(s.speed*dt,pos.distance_to(destination))) if row.get("region","") in ["fenshui","salt_pool"] else move_monster(pos,destination,s.speed*dt))
				if row.get("region","")=="fenshui": a.position=pack(WaterSpacing.swim(run,row,pos,pos.direction_to(destination),minf(s.speed*dt,pos.distance_to(destination))))
		elif a.mode=="idle" and row.get("region","")=="fenshui" and not recoiling:
			WaterSpacing.patrol(run,row,dt)
		a.velocity=pack((vec(a.position)-pos)/dt)
	if c.hp<=0:
		clear_hit(c)
		for actor in c.actors.values(): clear_hit(actor)
		c.shots.clear()
		c.enemy_shots.clear()
		c.action_left=0.0
		c.axe_pending=false
		return
	var flying: Array = []
	for shot in c.shots:
		if not shot.has("lives"): shot.lives = life_ids(run)
		var old := vec(shot.position)
		var flight: float = shot.get("flight", FLIGHT)
		shot.time=minf(flight,shot.time+dt)
		var next := vec(shot.origin).lerp(vec(shot.target),shot.time/flight)
		var used := false
		# 沿轨迹细分检测，最近命中单体后立即终止，障碍先阻挡。
		var steps := maxi(1,ceili(old.distance_to(next)/2.0))
		for i in range(1,steps+1):
			var p := old.lerp(next,float(i)/steps)
			if Crystals.projectile(c,p,shot):
				used=true
				break
			if not projectile_clear(p,str(c.get("region","maze_entry"))):
				used=true
				break
			for row in Catalog.rows(c):
				var a: Dictionary=c.actors[row.id]
				if run.monsters[row.id].status!="alive" or a.hp<=0 or a.mode=="return" or not Catalog.targetable(c,row.id): continue
				if int(shot.lives.get(row.id,-1)) != int(run.monsters[row.id].get("refresh_count",0)): continue
				if p.distance_to(vec(a.position))<=14.0:
					Skills.damage(run, row.id, int(shot.get("damage", c.attack)))
					if a.hp > 0: hit(a, vec(a.position), vec(shot.origin), 12.0)
					else: clear_hit(a)
					if a.mode=="idle": a.mode="chase"
					used=true
					break
			if used: break
		shot.position=pack(next)
		if not used and shot.time<flight: flying.append(shot)
	c.shots=flying
	c.cooldown=maxf(0.0,c.cooldown-dt)

static func select_target(run: Dictionary, point: Vector2) -> String:
	var c: Dictionary=run.combat
	if c.hp<=0: return ""
	var nearest := ""
	var distance := RANGE+0.001
	for row in Catalog.rows(c):
		var a: Dictionary=c.actors[row.id]
		if run.monsters[row.id].status!="alive" or a.hp<=0 or a.mode=="return" or not Catalog.targetable(c,row.id): continue
		var d := point.distance_to(vec(a.position))
		if d<=RANGE and d<distance:
			nearest=row.id
			distance=d
	return nearest

static func attack(run: Dictionary, point: Vector2, aim: Vector2 = Vector2.RIGHT) -> bool:
	return Skills.attack(run,point,aim)

static func valid(c: Dictionary) -> bool:
	if not Skills.valid(c): return false
	if c.has("rock_shake_left") and not Skills.number(c.rock_shake_left,0.45): return false
	for flag in ["frog_encounter","frog_unlocked","salt_encounters","rock_encounter"]:
		if c.has(flag) and not c[flag] is bool: return false
	if c.get("frog_encounter",false) and not c.get("fenshui_encounters",false): return false
	if c.get("rock_encounter",false) and not c.get("salt_encounters",false): return false
	if not _valid_hit(c): return false
	for key in ["sprint","sprint_rest"]:
		if c.has(key):
			if typeof(c[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(c[key])) or c[key]<0 or c[key]>1: return false
	if c.get("version")!=1: return false
	if c.get("region","maze_entry") not in ["maze_entry","fenshui","salt_pool","moss_pool"]: return false
	if c.has("fenshui_encounters") and not c.fenshui_encounters is bool: return false
	if not Catalog.valid_layout(c.get("layout",[])): return false
	for key in ["attack","max_hp","hp","cooldown","elapsed","throws","hits"]:
		var value: Variant=c.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0: return false
	if c.max_hp<1 or c.hp>c.max_hp or not c.get("actors") is Dictionary or not c.get("shots") is Array or not _point(c.get("hero")): return false
	if c.shots.size()>8 or not STATS.has(c.get("last_attacker")): return false
	for row in Catalog.rows(c,true):
		var a: Variant=c.actors.get(row.id)
		if not a is Dictionary or not _point(a.get("position")) or not _point(a.get("velocity")): return false
		if not _valid_hit(a): return false
		if a.has("swim_heading") and (not _point(a.swim_heading) or vec(a.swim_heading).length()>1.001): return false
		if a.has("swim_left") and (typeof(a.swim_left) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(a.swim_left)) or a.swim_left<0 or a.swim_left>3.5): return false
		if a.has("attack_aim") and (not _point(a.attack_aim) or vec(a.attack_aim).length()>1.001): return false
		if row.kind=="wind_frog" and not Frog.valid(a): return false
		if row.kind=="rockmane" and not Rock.valid(a): return false
		if a.get("mode") not in ["idle","chase","windup","return"]: return false
		for key in ["hp","windup","cooldown","away"]:
			var value: Variant=a.get(key)
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0: return false
		if a.hp>STATS[row.kind].hp: return false
	for shot in c.shots:
		if not shot is Dictionary: return false
		for key in ["origin","target","position"]:
			if not _point(shot.get(key)): return false
		var time: Variant=shot.get("time")
		var flight: Variant = shot.get("flight", FLIGHT)
		if typeof(flight) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(flight)) or flight<=0 or flight>1.5: return false
		if typeof(time) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(time)) or time<0 or time>flight: return false
	return true

static func _valid_hit(actor: Dictionary) -> bool:
	for key in ["hit_remaining", "flash_remaining"]:
		if actor.has(key):
			var value: Variant = actor[key]
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0.0 or value > HIT_DURATION: return false
	if actor.has("hit_velocity") and not _point(actor.hit_velocity): return false
	if actor.has("hit_velocity") and vec(actor.hit_velocity).length() > 150.001: return false
	if float(actor.get("flash_remaining", 0.0)) > FLASH_DURATION: return false
	if float(actor.get("hit_remaining", 0.0)) > 0.0 and not actor.has("hit_velocity"): return false
	return true

static func _point(value: Variant) -> bool:
	if not value is Array or value.size()!=2: return false
	for number in value:
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
	return true


static func terrain(region: String):
	if region=="moss_pool": return preload("res://data/maze/moss_pool_roads.gd")
	if region=="fenshui": return preload("res://data/maze/fenshui_roads.gd")
	if region=="salt_pool": return preload("res://data/maze/salt_pool_roads.gd")
	return Roads

static func region_line(a: Vector2,b: Vector2,region: String) -> bool:
	if region=="maze_entry": return clear_line(a,b)
	var count := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(count+1):
		if not terrain(region).is_walkable(a.lerp(b,float(i)/count)): return false
	return true

static func move_actor(row: Dictionary, origin: Vector2, displacement: Vector2) -> Vector2:
	if row.get("region","")=="fenshui": return Catalog.Fenshui.move(origin,displacement,row.position)
	if row.get("region","")=="salt_pool": return Catalog.Salt.move(origin,displacement,row.position)
	return Roads.move_on_road(origin,displacement)



static func water_line(a: Vector2,b: Vector2) -> bool:
	var count := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(count+1):
		var p := a.lerp(b,float(i)/count)
		if not Catalog.Fenshui.water(p,0.0): return false
	return true

static func protected(row: Dictionary,point: Vector2) -> bool:
	if row.get("region","")=="salt_pool": return Catalog.Salt.protected(point)
	return row.get("region","")=="fenshui" and Catalog.Fenshui.protected(point)

static func attack_line(row: Dictionary,a: Vector2,b: Vector2) -> bool:
	if row.get("region","")=="salt_pool": return region_line(a,b,"salt_pool")
	return water_line(a,b) if row.get("region","")=="fenshui" else clear_line(a,b)

static func aimed_hit(actor: Dictionary,row: Dictionary,origin: Vector2,point: Vector2) -> bool:
	if row.kind!="blind_scorpion": return true
	var aim := vec(actor.get("attack_aim",[0.0,0.0]))
	if aim.is_zero_approx(): return false
	var offset := point-origin
	if offset.length()<=24.0: return true
	return offset.dot(aim)>=0.0 and absf(offset.cross(aim))<=12.0
