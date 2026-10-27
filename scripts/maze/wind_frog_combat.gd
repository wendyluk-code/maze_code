extends RefCounted
## 纯状态推进；出场、落点、计时和水团随外层探索事务保存。
const Config = preload("res://data/maze/fenshui_boss.gd")
const Skills = preload("res://scripts/maze/team_attack.gd")

static func initialize(a: Dictionary) -> void:
	a.frog_phase="dormant"
	a.frog_left=0.0
	a.frog_jump=6.0
	a.frog_target=[Config.HOME.x,Config.HOME.y]
	a.frog_origin=a.position.duplicate()
	a.frog_aim=[0.0,1.0]
	a.frog_shots=[]

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

static func hurt(run: Dictionary, point: Vector2, source: Vector2) -> void:
	var c: Dictionary=run.combat
	c.hp=maxf(0.0,c.hp-Skills.incoming_damage(run,6))
	c.last_attacker="wind_frog"
	var direction := source.direction_to(point)
	if direction.is_zero_approx(): direction=Vector2.DOWN
	c.hit_velocity=pack(direction*150.0)
	c.hit_remaining=0.12
	c.flash_remaining=0.1

static func advance(run: Dictionary, point: Vector2, dt: float) -> void:
	var c: Dictionary=run.combat
	if c.get("region","")!="fenshui" or not c.get("frog_encounter",false): return
	var a: Dictionary=c.actors[Config.ID]
	if run.monsters[Config.ID].status!="alive" or a.hp<=0:
		a.frog_shots=[]
		return
	var pos:=vec(a.position)
	a.velocity=[0.0,0.0]
	if float(a.get("hit_remaining",0))>0 and a.frog_phase!="airborne":
		var next:=Config.move(pos,vec(a.hit_velocity)*minf(dt,float(a.hit_remaining)))
		if preload("res://scripts/maze/water_spacing.gd").clear(run,Config.ID,next):
			a.position=pack(next)
			a.velocity=pack((next-pos)/dt)
		a.hit_remaining=maxf(0,a.hit_remaining-dt)
		if a.frog_phase=="warning":
			a.frog_origin=a.position.duplicate()
			if not Config.jump_line(vec(a.frog_origin),vec(a.frog_target)): a.frog_phase="active"
		return
	var pursuing: bool=c.get("frog_unlocked",false) and Config.Roads.is_walkable(point) and Config.Roads.terrain_multiplier(point)<1.0
	a.cooldown=maxf(0.0,a.cooldown-dt)
	if a.frog_phase=="dormant":
		# 从进图起就在中央小跳；沿用旧档阶段名，绝不重复生成或发奖。
		a.frog_left=fmod(float(a.frog_left)+dt,1.2)
		if not pursuing: return
		a.frog_phase="active"
		a.mode="chase"
	if a.frog_phase=="emerging":
		# 旧出水中存档仍可接续，但新趟不再走隐藏出水流程。
		a.frog_left=maxf(0.0,a.frog_left-dt)
		if a.frog_left>0.0: return
		a.frog_phase="active"
	if a.frog_phase=="warning":
		a.frog_left=maxf(0.0,a.frog_left-dt)
		if a.frog_left<=0.00001:
			a.frog_phase="airborne"
			a.frog_left=0.35
	elif a.frog_phase=="airborne":
		a.frog_left=maxf(0.0,a.frog_left-dt)
		var target:=vec(a.frog_target)
		a.position=pack(vec(a.frog_origin).lerp(target,1.0-a.frog_left/0.35))
		a.velocity=pack((vec(a.position)-pos)/dt)
		if a.frog_left<=0.00001:
			a.position=pack(target)
			if a.mode!="return" and point.distance_to(target)<=65.0 and Config.line(target,point): hurt(run,point,target)
			a.frog_phase="landing"
			a.frog_left=1.2
	elif a.frog_phase=="landing":
		a.frog_left=maxf(0.0,a.frog_left-dt)
		if a.frog_left<=0.00001:
			a.frog_phase="active"
			if pursuing and a.cooldown<=0 and pos.distance_to(point)<180 and Config.line(pos,point):
				a.mode="windup"
				a.windup=0.8
				a.cooldown=2.2
				var direction:=pos.direction_to(point)
				a.frog_aim=pack(Vector2.DOWN if direction.is_zero_approx() else direction)
	elif a.frog_phase=="active":
		if a.mode=="windup" and pursuing:
			a.windup=maxf(0.0,a.windup-dt)
			if a.windup<=0.00001:
				a.frog_shots.append({"position":pack(pos),"direction":a.frog_aim.duplicate(),"distance":0.0})
				a.mode="chase"
		elif not pursuing and pos.distance_to(Config.HOME)<2.0:
			a.frog_phase="dormant"
			a.frog_left=0.0
			a.mode="idle"
			a.hp=96
			a.frog_shots=[]
		else:
			a.mode="chase" if pursuing else "return"
			a.windup=0.0
			var destination:=preload("res://scripts/maze/frog_water_path.gd").landing(run,pos,point if pursuing else Config.HOME)
			a.frog_phase="warning"
			a.frog_left=1.0
			a.frog_origin=pack(pos)
			a.frog_target=pack(destination)
	var flying: Array=[]
	for shot in a.frog_shots:
		var old := vec(shot.position)
		var next := old+vec(shot.direction)*190.0*dt
		var used := false
		var steps := maxi(1,ceili(old.distance_to(next)/2.0))
		for i in range(1,steps+1):
			var p := old.lerp(next,float(i)/steps)
			if not Config.water(p):
				used=true
				break
			if p.distance_to(point)<=20.0 and Config.line(p,point):
				hurt(run,point,p-vec(shot.direction))
				used=true
				break
		shot.position=pack(next)
		shot.distance+=190.0*dt
		if not used and shot.distance<320: flying.append(shot)
	a.frog_shots=flying

static func valid(a: Dictionary) -> bool:
	if not Skills.point(a.get("position")): return false
	if a.get("frog_phase") not in ["dormant","emerging","active","warning","airborne","landing"]: return false
	if not Skills.number(a.get("frog_left"),1.2) or not Skills.number(a.get("frog_jump"),6.0): return false
	for key in ["frog_target","frog_origin","frog_aim"]:
		if not Skills.point(a.get(key)): return false
	if absf(vec(a.frog_aim).length()-1.0)>0.001: return false
	if not Config.allowed(vec(a.frog_target)) or not Config.allowed(vec(a.frog_origin)): return false
	if a.frog_phase=="airborne":
		if not Config.jump_line(vec(a.frog_origin),vec(a.frog_target)): return false
		var expected:=vec(a.frog_origin).lerp(vec(a.frog_target),1.0-float(a.frog_left)/0.35)
		if a.frog_left>0.35 or expected.distance_to(vec(a.position))>0.01: return false
	elif not Config.allowed(vec(a.position)): return false
	if not a.get("frog_shots") is Array or a.frog_shots.size()>4: return false
	for shot in a.frog_shots:
		if not shot is Dictionary or not Skills.point(shot.get("position")) or not Skills.point(shot.get("direction")) or not Skills.number(shot.get("distance"),320): return false
		if absf(vec(shot.direction).length()-1.0)>0.001: return false
	return true
