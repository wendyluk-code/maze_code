extends RefCounted
## 纯状态推进；出场、落点、计时和水团随外层探索事务保存。
const Config = preload("res://data/maze/fenshui_boss.gd")
const Skills = preload("res://scripts/maze/team_attack.gd")
const Counter = preload("res://scripts/maze/wind_frog_counter.gd")
const ElectricArea = preload("res://scripts/maze/fenshui_electric_area.gd")
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
const SLAM_RADIUS := Config.SLAM_RADIUS

static func initialize(a: Dictionary) -> void:
	a.frog_phase="dormant"
	a.frog_left=0.0
	a.frog_jump=6.0
	a.frog_target=[Config.HOME.x,Config.HOME.y]
	a.frog_origin=a.position.duplicate()
	a.frog_aim=[0.0,1.0]
	a.frog_shots=[]
	a.frog_air_duration=Counter.AIR_TIME
	a.frog_facing=0
	a.frog_spit_left=0.0
	a.frog_heal_quiet=0.0

static func vec(p: Array) -> Vector2:
	return Vector2(p[0],p[1])
static func pack(p: Vector2) -> Array:
	return [p.x,p.y]

static func ordinary_busy(run: Dictionary) -> bool:
	if not str(run.pending).is_empty(): return true
	for id in run.combat.actors:
		if not str(id).begins_with("fenshui_") or id==Config.ID: continue
		if run.monsters[id].status=="alive" and (run.combat.actors[id].hp<=0 or run.combat.actors[id].mode in ["chase","windup"]): return true
	return not run.combat.shots.is_empty() or not run.combat.get("enemy_shots",[]).is_empty()

static func hurt(run: Dictionary, point: Vector2, source: Vector2, hurt_feedback: Array=[], kind: String="slam") -> void:
	var c: Dictionary=run.combat
	var hp_before:=float(c.hp)
	if not Skills.receive_damage(run,int(Tuning.effect(kind,"damage",preload("res://scripts/maze/monster_editor.gd").attack("wind_frog",6)))): return
	preload("res://scripts/maze/player_hurt_event.gd").record(c,hp_before,kind,point,source,hurt_feedback)
	c.last_attacker="wind_frog"
	var direction := source.direction_to(point)
	if direction.is_zero_approx(): direction=Vector2.DOWN
	c.hit_velocity=pack(direction*150.0)
	c.hit_remaining=0.12
	c.flash_remaining=0.1

static func advance(run: Dictionary, point: Vector2, dt: float, held: float = 0.0, hurt_feedback: Array=[]) -> void:
	# 目标停顿只影响身体；已经离体的水团仍消耗原场景时间。
	var scene_dt:=dt
	if held>0.000001: advance_projectiles(run,point,held,hurt_feedback)
	dt=maxf(0.0,dt-held)
	var c: Dictionary=run.combat
	if c.get("region","")!="fenshui" or not c.get("frog_encounter",false): return
	var a: Dictionary=c.actors[Config.ID]
	if Skills.Trail.paralyzed(a):
		a.velocity=[0.0,0.0]
		advance_projectiles(run,point,dt,hurt_feedback)
		return
	if float(a.get("wind_left",0.0))>0: return
	if run.monsters[Config.ID].status!="alive" or a.hp<=0:
		a.frog_shots=[]
		return
	if Counter.enabled(c,Config.ID): Counter.water_clock(a,scene_dt)
	if dt<=0.000001:
		advance_healing(c,a,scene_dt)
		return
	a.frog_spit_left=maxf(0.0,float(a.get("frog_spit_left",0.0))-dt)
	var pos:=vec(a.position)
	a.velocity=[0.0,0.0]
	if Counter.enabled(c,Config.ID):
		if Counter.advance(a,dt):
			a.frog_heal_quiet=0.0
			Counter.water_clock(a,0.0)
			advance_projectiles(run,point,dt,hurt_feedback)
			return
	if float(a.get("hit_remaining",0))>0 and a.frog_phase!="airborne":
		var next:=Config.move(pos,vec(a.hit_velocity)*minf(dt,float(a.hit_remaining)))
		if preload("res://scripts/maze/water_spacing.gd").clear(run,Config.ID,next):
			a.position=pack(next)
			a.velocity=pack((next-pos)/dt)
		a.hit_remaining=maxf(0,a.hit_remaining-dt)
		if a.frog_phase=="warning":
			a.frog_origin=a.position.duplicate()
			if not Config.jump_line(vec(a.frog_origin),vec(a.frog_target)): a.frog_phase="active"
		advance_healing(c,a,scene_dt)
		return
	var pursuing: bool=c.get("frog_unlocked",false) and Config.Roads.is_walkable(point) and Config.water(point)
	# 旧档可能正处于零距离起落；恢复活动判断，而非续播无位移的完整跳跃。
	if a.frog_phase in ["warning","airborne","landing"] and vec(a.frog_origin).distance_squared_to(vec(a.frog_target))<0.01:
		a.frog_phase="active"
		a.frog_left=0.0
		a.windup=0.0
	a.cooldown=maxf(0.0,a.cooldown-dt)
	if a.frog_phase=="dormant":
		# 从进图起就在中央小跳；沿用旧档阶段名，绝不重复生成或发奖。
		a.frog_left=fmod(float(a.frog_left)+dt,1.2)
		if not pursuing:
			advance_healing(c,a,scene_dt)
			return
		a.frog_phase="active"
		a.mode="chase"
	if a.frog_phase=="emerging":
		# 旧出水中存档仍可接续，但新趟不再走隐藏出水流程。
		if Counter.enabled(c,Config.ID): a.frog_heal_quiet=0.0
		a.frog_left=maxf(0.0,a.frog_left-dt)
		if a.frog_left>0.0: return
		a.frog_phase="active"
	if a.frog_phase=="warning":
		if float(a.frog_spit_left)<=0.0: a.frog_facing=Counter.direction_for(vec(a.frog_target)-vec(a.frog_origin),Counter.facing(a))
		a.frog_left=maxf(0.0,a.frog_left-dt)
		if a.frog_left<=0.00001:
			a.frog_phase="airborne"
			a.frog_air_duration=Counter.AIR_TIME if Counter.enabled(c,Config.ID) else 0.35
			a.frog_left=a.frog_air_duration
	elif a.frog_phase=="airborne":
		a.frog_left=maxf(0.0,a.frog_left-dt*Skills.Tide.speed(a))
		var target:=vec(a.frog_target)
		a.position=pack(vec(a.frog_origin).lerp(target,1.0-a.frog_left/Counter.flight_time(a)))
		a.velocity=pack((vec(a.position)-pos)/dt)
		if a.frog_left<=0.00001:
			a.position=pack(target)
			var hit: bool=point.distance_to(target)<=65.0 and Config.line(target,point) if c.get("fs01_trial",false) else ElectricArea.contains(ElectricArea.polygon(target,Config.ID+"_slam"),point)
			if a.mode!="return" and hit: hurt(run,point,target,hurt_feedback,"slam")
			if a.mode!="return" and not c.get("fs01_trial",false): slam_monsters(run,target)
			a.frog_phase="landing"
			a.frog_left=Tuning.effect("slam","recover",1200.0)/1000.0
	elif a.frog_phase=="landing":
		a.frog_left=maxf(0.0,a.frog_left-dt)
		if a.frog_left<=0.00001:
			a.frog_phase="active"
			# 脱战后完成本次落地即可安静恢复，不必再跳回中央坐标。
			if not pursuing and Counter.enabled(c,Config.ID) and Config.allowed(pos):
				a.frog_phase="dormant"
				a.frog_left=0.0
				a.mode="idle"
				a.frog_shots=[]
			elif pursuing and a.cooldown<=0 and pos.distance_to(point)<Tuning.effect("water","trigger",180.0) and Config.line(pos,point):
				prepare_spit(a,pos,point)
	elif a.frog_phase=="active":
		if a.mode=="windup" and pursuing:
			a.windup=maxf(0.0,a.windup-dt)
			if a.windup<=0.00001:
				a.frog_shots.append({"position":pack(pos),"direction":a.frog_aim.duplicate(),"distance":0.0})
				a.frog_spit_left=Tuning.effect("water","recover",280.0)/1000.0
				a.mode="chase"
		elif float(a.frog_spit_left)>0.0:
			# 水枪收势是实际动作锁，不只是显示计时；离体水团仍在下方推进。
			pass
		elif not pursuing and pos.distance_to(Config.HOME)<2.0:
			a.frog_phase="dormant"
			a.frog_left=0.0
			a.mode="idle"
			if not Counter.enabled(c,Config.ID): a.hp=Tuning.number("base.wind_frog","hp",96.0)
			a.frog_shots=[]
		elif a.frog_left>0.0:
			# 暂无出路时沿用活动阶段的剩时重查，不反复安排零距离起落。
			a.frog_left=maxf(0.0,a.frog_left-dt)
		else:
			a.mode="chase" if pursuing else "return"
			a.windup=0.0
			var destination:=preload("res://scripts/maze/frog_water_path.gd").landing(run,pos,point if pursuing else Config.HOME)
			if destination.distance_squared_to(pos)<0.01 and pursuing:
				if pos.distance_to(point)<Tuning.effect("water","trigger",180.0) and Config.line(pos,point):
					if a.cooldown<=0.0: prepare_spit(a,pos,point)
				else:
					a.mode="return"
					destination=preload("res://scripts/maze/frog_water_path.gd").landing(run,pos,Config.HOME)
			a.frog_origin=pack(pos)
			a.frog_target=pack(destination)
			if destination.distance_squared_to(pos)>=0.01:
				a.frog_phase="warning"
				a.frog_left=Tuning.effect("slam","windup",1000.0)/1000.0
				if float(a.frog_spit_left)<=0.0: a.frog_facing=Counter.direction_for(destination-pos,Counter.facing(a))
			elif a.mode!="windup":
				a.frog_left=0.25
	if Counter.enabled(c,Config.ID): Counter.water_clock(a,0.0)
	advance_healing(c,a,scene_dt)
	advance_projectiles(run,point,dt,hurt_feedback)

static func slam_monsters(run: Dictionary, center: Vector2) -> void:
	var c: Dictionary=run.combat
	var shape:=ElectricArea.polygon(center,Config.ID+"_slam")
	for id in c.actors:
		if not str(id).begins_with("fenshui_silverfish_") and not str(id).begins_with("fenshui_thunder_eel_"): continue
		if not Skills.Catalog.active(c,id) or run.monsters[id].status!="alive": continue
		var target: Dictionary=c.actors[id]
		var point:=vec(target.position)
		if target.hp<=0.0 or not ElectricArea.contains(shape,point): continue
		# 环境攻击沿原6点基础伤害及水中保护结算，不记作玩家命中或触发玩家招式。
		var amount: float=preload("res://scripts/maze/silverfish_combat.gd").damage_amount(c,id,6)
		amount=preload("res://scripts/maze/thunder_eel_combat.gd").damage_amount(c,id,amount)
		target.hp=maxf(0.0,float(target.hp)-amount)
		target.flash_remaining=0.1

static func advance_healing(c: Dictionary, a: Dictionary, dt: float) -> void:
	if not Counter.enabled(c,Config.ID): return
	# 水中未受有效攻击的场景时间，与追击/待机及身体局部停顿分开。
	if a.hp<=0 or c.hp<=0 or a.frog_phase not in ["dormant","active","warning","landing"] or not Config.allowed(vec(a.position)):
		a.frog_heal_quiet=0.0
		return
	var quiet:=float(a.get("frog_heal_quiet",0.0))
	var healing_dt:=maxf(0.0,quiet+dt-2.0)
	a.frog_heal_quiet=minf(2.0,quiet+dt)
	var maximum:=Tuning.number("base.wind_frog","hp",96.0)
	a.hp=minf(maximum,float(a.hp)+healing_dt*maximum/6.0)

static func prepare_spit(a: Dictionary, pos: Vector2, point: Vector2) -> void:
	a.mode="windup"
	a.windup=Tuning.effect("water","windup",800.0)/1000.0
	a.cooldown=2.2*Tuning.effect("water","interval_scale",100.0)/100.0
	var direction:=pos.direction_to(point)
	a.frog_aim=pack(Vector2.DOWN if direction.is_zero_approx() else direction)
	a.frog_facing=Counter.direction_for(vec(a.frog_aim),Counter.facing(a))

static func advance_projectiles(run: Dictionary, point: Vector2, dt: float, hurt_feedback: Array=[]) -> void:
	var c: Dictionary=run.combat
	if c.get("region","")!="fenshui" or not c.get("frog_encounter",false): return
	var a: Dictionary=c.actors[Config.ID]
	if run.monsters[Config.ID].status!="alive" or a.hp<=0:
		a.frog_shots=[]
		return
	var flying: Array=[]
	for shot in a.frog_shots:
		var old := vec(shot.position)
		var travel:=minf(Tuning.effect("water","speed",190.0)*dt,maxf(0.0,Tuning.effect("water","distance",320.0)-float(shot.distance)))
		var next := old+vec(shot.direction)*travel
		var used := false
		var steps := maxi(1,ceili(old.distance_to(next)/2.0))
		for i in range(1,steps+1):
			var p := old.lerp(next,float(i)/steps)
			if not Config.water(p):
				used=true
				break
			if p.distance_to(point)<=Tuning.effect("water","hit_radius",20.0) and Config.line(p,point):
				hurt(run,point,p-vec(shot.direction),hurt_feedback,"water")
				used=true
				break
		shot.position=pack(next)
		shot.distance+=travel
		if not used and shot.distance<Tuning.effect("water","distance",320.0): flying.append(shot)
	a.frog_shots=flying

static func valid(a: Dictionary) -> bool:
	if not Counter.valid(a): return false
	if a.has("frog_heal_quiet") and not Skills.number(a.frog_heal_quiet,2.0): return false
	if not Skills.point(a.get("position")): return false
	if a.get("frog_phase") not in ["dormant","emerging","active","warning","airborne","landing","toppling","exposed","recovering"]: return false
	var maximum: float={"toppling":Counter.TOPPLE_TIME,"exposed":Counter.EXPOSED_TIME,"recovering":Counter.RISE_TIME}.get(a.frog_phase,1.2)
	if a.frog_phase=="warning": maximum=maxf(maximum,Tuning.effect("slam","windup",1000.0)/1000.0)
	if a.frog_phase=="landing": maximum=maxf(maximum,Tuning.effect("slam","recover",1200.0)/1000.0)
	if not Skills.number(a.get("frog_left"),maximum) or not Skills.number(a.get("frog_jump"),6.0): return false
	for key in ["frog_target","frog_origin","frog_aim"]:
		if not Skills.point(a.get(key)): return false
	if absf(vec(a.frog_aim).length()-1.0)>0.001: return false
	if not Config.allowed(vec(a.frog_target)) or not Config.allowed(vec(a.frog_origin)): return false
	if a.frog_phase=="airborne":
		if not Config.jump_line(vec(a.frog_origin),vec(a.frog_target)): return false
		var expected:=vec(a.frog_origin).lerp(vec(a.frog_target),1.0-float(a.frog_left)/Counter.flight_time(a))
		if a.frog_left>Counter.flight_time(a) or expected.distance_to(vec(a.position))>0.01: return false
	elif a.frog_phase=="toppling":
		if not Counter.point(a.get("frog_counter_from")) or not Config.jump_line(vec(a.frog_origin),vec(a.frog_target)): return false
		var start:=vec(a.frog_counter_from)
		if start.distance_to(Geometry2D.get_closest_point_to_segment(start,vec(a.frog_origin),vec(a.frog_target)))>0.01: return false
		var expected:=start.lerp(vec(a.frog_target),1.0-float(a.frog_left)/Counter.TOPPLE_TIME)
		if expected.distance_to(vec(a.position))>0.01: return false
	elif not Config.allowed(vec(a.position)): return false
	if not a.get("frog_shots") is Array or a.frog_shots.size()>4: return false
	for shot in a.frog_shots:
		if not shot is Dictionary or not Skills.point(shot.get("position")) or not Skills.point(shot.get("direction")) or not Skills.number(shot.get("distance"),Tuning.effect("water","distance",320.0)): return false
		if absf(vec(shot.direction).length()-1.0)>0.001: return false
	return true
