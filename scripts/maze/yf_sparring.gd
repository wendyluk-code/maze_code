extends RefCounted
## 切磋专属内存模拟；不写探索战斗、库存或奖励。
const Terrain = preload("res://data/maze/fenshui_roads.gd")
const Skills = preload("res://scripts/maze/team_attack.gd")
const Growth = preload("res://scripts/characters/character_progression.gd")
const Site = preload("res://data/maze/yf_encounter_site.gd")
const POSITIONS := Site.POSITIONS

static func create(source: Dictionary) -> Dictionary:
	var run := source.duplicate(true)
	var c: Dictionary = run.combat
	c.actors = {}
	run.monsters = {}
	for id in POSITIONS:
		var stats: Dictionary = Growth.CHARACTERS[id]
		c.actors[id] = {"position":Skills.pack(POSITIONS[id]),"hp":float(stats.health),"max_hp":float(stats.health),"attack":int(stats.attack),"cooldown":0.8 if id=="yufeng" else 1.0,"mode":"chase","cast":0.0}
		run.monsters[id] = {"status":"alive","refresh_count":0}
	c.shots=[]
	c.enemy_shots=[]
	c.action_left=0.0
	c.axe_pending=false
	c.cooldown=0.0
	c.slime_lesson={}
	c["lock_left"]=-1.0
	c["start_hp"]=float(c.hp)
	c["stop_hp"]=float(c.hp)*0.2
	c["control_left"]=0.0
	c["control_reuse"]=0.0
	c["elapsed"]=0.0
	c["lightning_hits"]=[]
	return run

static func clear_line(a: Vector2, b: Vector2, water_only: bool = false) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(steps+1):
		var p := a.lerp(b,float(i)/steps)
		if not Terrain.is_walkable(p) or (water_only and Terrain.terrain_multiplier(p)==1.0): return false
	return true

static func conduction(origin: Vector2, candidates: Dictionary, struck: String) -> Array:
	var result: Array=[]
	if Terrain.terrain_multiplier(origin)==1.0 or not Terrain.is_walkable(origin): return result
	var current := origin
	var visited := [struck]
	for hop in 3:
		var closest := ""
		var distance := 120.001
		for id in candidates:
			var p: Vector2=candidates[id]
			if id in visited or current.distance_to(p)>120.0 or not clear_line(current,p,true): continue
			if current.distance_to(p)<distance:
				distance=current.distance_to(p)
				closest=id
		if closest.is_empty(): break
		result.append(closest)
		visited.append(closest)
		current=candidates[closest]
	return result

static func chain_hits(origin: Vector2, candidates: Dictionary, struck: String, direct_damage: float) -> Array:
	var hits: Array=[]
	for id in conduction(origin,candidates,struck): hits.append({"id":id,"damage":direct_damage*0.6})
	return hits

static func hurt(run: Dictionary, id: String, amount: float) -> void:
	var c: Dictionary=run.combat
	if c.lock_left>=0: return
	var actor: Dictionary=c.actors[id]
	# 切磋对手不能被击杀，但不会因对手血量触发剧情。
	actor.hp=maxf(1.0,actor.hp-maxf(0.0,amount-Growth.defense(id,1)))
	actor["flash"]=0.1

static func attack(run: Dictionary, point: Vector2, aim: Vector2) -> bool:
	if run.combat.control_left>0 or run.combat.lock_left==0: return false
	return Skills.attack(run,point,aim)

static func advance(run: Dictionary, point: Vector2, dt: float, sprinting: bool) -> Vector2:
	var c: Dictionary=run.combat
	if c.lock_left==0: return point
	c.elapsed+=dt
	var effects: Array=[]
	for effect in c.lightning_hits:
		effect.left-=dt
		if effect.left>0: effects.append(effect)
	c.lightning_hits=effects
	c.cooldown=maxf(0,c.cooldown-dt)
	c.action_left=maxf(0,c.action_left-dt)
	c.control_reuse=maxf(0,c.control_reuse-dt)
	# 与普通探索相同：5秒耗尽，停1秒后8秒回满；不持久扣费。
	c.sprint=clampf(float(c.get("sprint",1.0)),0,1)
	c.sprint_rest=float(c.get("sprint_rest",0.0))
	if sprinting and c.sprint>0:
		c.sprint=maxf(0,c.sprint-dt/5.0)
		c.sprint_rest=0.0
	else:
		var recovery: float = maxf(0,c.sprint_rest+dt-1.0)-maxf(0,c.sprint_rest-1.0)
		c.sprint_rest=minf(1,c.sprint_rest+dt)
		c.sprint=minf(1,c.sprint+recovery/8.0)
	c.flash_remaining=0.0
	if c.control_left>0:
		var prior: float=c.control_left
		c.control_left=maxf(0,c.control_left-dt)
		var start := 0.3-prior
		var finish: float = 0.3-c.control_left
		var moving_time := 0.0
		# 每段前60毫秒后退12像素，后40毫秒停顿，形成可辨认的三下。
		for pulse in 3:
			var begin := float(pulse)*0.1
			moving_time+=maxf(0.0,minf(finish,begin+0.06)-maxf(start,begin))
		var displacement := Skills.vec(c.control_direction)*200.0*moving_time
		var steps := maxi(1,ceili(displacement.length()/0.5))
		for i in steps:
			if Terrain.is_walkable(point+displacement/steps): point+=displacement/steps
			else: break
		c.flash_remaining=0.01 if fmod(0.3-c.control_left,0.1)<0.06 else 0.0
	if c.lock_left>=0:
		c.lock_left=maxf(0,c.lock_left-dt)
	if c.axe_pending and c.action_left<=0.30:
		c.axe_pending=false
		for id in c.actors:
			var target := Skills.vec(c.actors[id].position)
			if target.distance_to(point)<=Skills.AXE_RADIUS and clear_line(point,target): hurt(run,id,c.get("axe_damage",c.attack))
	var flying: Array=[]
	for shot in c.shots:
		var old := Skills.vec(shot.position)
		shot.time+=dt
		var next := Skills.vec(shot.origin).lerp(Skills.vec(shot.target),minf(1,shot.time/shot.flight))
		var used := not clear_line(old,next)
		if not used:
			for id in c.actors:
				var target := Skills.vec(c.actors[id].position)
				if target.distance_to(Geometry2D.get_closest_point_to_segment(target,old,next))<=19:
					hurt(run,id,shot.get("damage",c.attack))
					used=true
					break
		shot.position=Skills.pack(next)
		if not used and shot.time<shot.flight: flying.append(shot)
	c.shots=flying
	for id in c.actors:
		var actor: Dictionary=c.actors[id]
		actor.flash=maxf(0,float(actor.get("flash",0))-dt)
		actor.cast=maxf(0,actor.cast-dt)
		actor.cooldown-=dt
		var position := Skills.vec(actor.position)
		var reach := 105.0 if id=="yufeng" else 145.0
		actor["moving"]=false
		if actor.cast<=0 and (position.distance_to(point)>reach or not clear_line(position,point)):
			var destination := chase_target(position,point)
			var moved := Terrain.move_on_road(position,position.direction_to(destination)*minf(90.0*Terrain.terrain_multiplier(position)*dt,position.distance_to(destination)))
			actor["moving"]=moved.distance_to(position)>0.01
			actor.position=Skills.pack(moved)
			position=moved
		if c.hp>0 and actor.cooldown<=0 and position.distance_to(point)<=reach and clear_line(position,point):
			actor.cooldown=0.8 if id=="yufeng" else 1.0
			actor.cast=0.48
			c.enemy_shots.append({"position":Skills.pack(position),"direction":Skills.pack(position.direction_to(point)),"distance":0.0,"source":id})
	flying=[]
	for shot in c.enemy_shots:
		if c.hp<=0: break
		var old := Skills.vec(shot.position)
		if shot.source=="salia": shot.direction=Skills.pack(old.direction_to(point))
		var next := old+Skills.vec(shot.direction)*230.0*dt
		var used := not clear_line(old,next)
		if not used and point.distance_to(Geometry2D.get_closest_point_to_segment(point,old,next))<=16:
			c.hp=maxf(c.stop_hp,float(c.hp)-Skills.incoming_damage(run,c.actors[shot.source].attack))
			if shot.source=="salia": c.lightning_hits.append({"position":Skills.pack(point),"left":0.24})
			c.flash_remaining=0.1
			if shot.source=="yufeng" and c.control_reuse<=0:
				c.control_left=0.3
				c.control_reuse=2.0
				c.control_direction=shot.direction.duplicate()
			used=true
			# 本场只有一个玩家，已命中集合排除自身，不虚构传导目标。
			if c.hp<=c.stop_hp:
				c.lock_left=0.0
				c.control_left=0.0
				c.shots=[]
				c.enemy_shots=[]
				return point
		shot.position=Skills.pack(next)
		shot.distance+=230.0*dt
		if not used and shot.distance<(320 if shot.source=="yufeng" else 360): flying.append(shot)
	c.enemy_shots=flying
	return point

# 使用分水庭可走区域规划追击，逐步移动仍经过真实碰撞检查。
static var grid: AStarGrid2D
static func chase_target(origin: Vector2, target: Vector2) -> Vector2:
	if clear_line(origin,target): return target
	if grid==null:
		grid=AStarGrid2D.new()
		grid.region=Rect2i(0,0,215,115)
		grid.cell_size=Vector2(8,8)
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for y in 115:
			for x in 215: grid.set_point_solid(Vector2i(x,y),not Terrain.is_walkable(Vector2(x*8,y*8)))
	var start := nearest_cell(origin)
	var finish := nearest_cell(target)
	if start.x<0 or finish.x<0: return origin
	var path := grid.get_point_path(start,finish)
	for i in range(path.size()-1,-1,-1):
		if clear_line(origin,path[i]): return path[i]
	return origin

static func nearest_cell(point: Vector2) -> Vector2i:
	var center := Vector2i((point/8.0).round())
	var best := Vector2i(-1,-1)
	var distance := INF
	for y in range(center.y-3,center.y+4):
		for x in range(center.x-3,center.x+4):
			var cell := Vector2i(x,y)
			if grid.region.has_point(cell) and not grid.is_point_solid(cell):
				var pos := Vector2(cell)*8.0
				if point.distance_squared_to(pos)<distance and clear_line(point,pos):
					best=cell
					distance=point.distance_squared_to(pos)
	return best
