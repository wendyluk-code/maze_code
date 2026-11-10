extends RefCounted
const Config=preload("res://data/maze/salt_boss.gd")
const Skills=preload("res://scripts/maze/team_attack.gd")
const RoarArea=preload("res://scripts/maze/rockmane_roar_area.gd")
const Bodies=preload("res://scripts/maze/rock_bodies.gd")
static var LUNGE_DISTANCE: float=160.0
static var LUNGE_SPEED: float=200.0
const LUNGE_REACH=18.0
static var LUNGE_DURATIONS: Dictionary={"lunge_charge":1.2,"lunge":0.8,"lunge_recover":2.0,"stunned":1.5}
static var COMBO_CHARGES: Array=[1.1,0.85,0.85,1.3]
static var COMBO_RECOVERS: Array=[0.35,0.45,0.55,0.8]
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
const ComboPath=preload("res://scripts/maze/rock_combo_path.gd")

static func configure() -> void:
	LUNGE_DISTANCE=Tuning.number("rock.lunge","distance",160.0)
	LUNGE_SPEED=Tuning.number("rock.lunge","speed",200.0)
	LUNGE_DURATIONS.lunge=LUNGE_DISTANCE/LUNGE_SPEED
	LUNGE_DURATIONS.lunge_charge=Tuning.number("rock.lunge","charge",1.2)
	LUNGE_DURATIONS.lunge_recover=Tuning.number("rock.lunge","recover",2.0)
	LUNGE_DURATIONS.stunned=Tuning.number("rock.lunge","stun",1.5)

static func start_combo(a: Dictionary,point: Vector2) -> void:
	a.mode="chase"
	a.rock_combo=true
	a.rock_chain_left=4
	a.rock_combo_angle=point.angle_to_point(vec(a.position))
	a.rock_combo_note=""
	a.rock_combo_released=0
	queue_side(a)

static func queue_side(a: Dictionary) -> void:
	a.rock_phase="combo_reposition"
	a.rock_left=0.0
	a.rock_orbit_left=6.0
	a.rock_orbit_path=[]
	a.rock_orbit_blocked=0.0

static func stop_combo(a: Dictionary,note: String) -> void:
	a.rock_phase="rest"
	a.rock_left=Tuning.number("rock.roar","rest",5.0)
	a.rock_combo=false
	a.rock_chain_left=0
	a.rock_orbit_path=[]
	a.rock_combo_note=note

static func advance_side(run: Dictionary,a: Dictionary,point: Vector2,dt: float) -> void:
	a.rock_orbit_left=maxf(0.0,float(a.get("rock_orbit_left",6.0))-dt)
	if a.rock_orbit_left<=0.0:
		stop_combo(a,"四侧冲撞中止：目标持续移动或绕位空间不足")
		return
	var pos:=vec(a.position)
	var angle:=float(a.get("rock_combo_angle",vec(a.rock_aim).angle()+PI))+combo_index(a)*PI/2.0
	if a.get("rock_orbit_path",[]).is_empty():
		var route:=ComboPath.plan(run,pos,point,angle)
		if route.is_empty():
			stop_combo(a,"四侧冲撞中止：该侧没有无穿透可达路径")
			return
		a.rock_orbit_path=route
	var budget:=230.0*dt
	var current:=pos
	while budget>0.00001 and not a.rock_orbit_path.is_empty():
		var target:=vec(a.rock_orbit_path[0])
		var delta:=current.direction_to(target)*minf(budget,current.distance_to(target))
		var next:=Bodies.move(run,Config.ID,current,Config.move(current,delta))
		var moved:=current.distance_to(next)
		current=next
		budget-=moved
		if current.distance_to(target)<0.01: a.rock_orbit_path.pop_front()
		elif moved<0.001:
			a.rock_orbit_blocked=float(a.get("rock_orbit_blocked",0.0))+dt
			if a.rock_orbit_blocked>0.25:
				a.rock_orbit_path=[]
				a.rock_orbit_blocked=0.0
			break
		else: break
	a.position=pack(current)
	a.velocity=pack((current-pos)/dt)
	if not a.rock_orbit_path.is_empty(): return
	if absf(wrapf(point.angle_to_point(current)-angle,-PI,PI))<=0.45 and can_lunge(current,point):
		begin_lunge(a,point)

static func combo_index(a: Dictionary) -> int:
	return clampi(4-int(a.get("rock_chain_left",4)),0,3)
static func charge_duration(a: Dictionary) -> float:
	return COMBO_CHARGES[combo_index(a)] if a.get("rock_combo",false) else LUNGE_DURATIONS.lunge_charge
static func recover_duration(a: Dictionary) -> float:
	return COMBO_RECOVERS[combo_index(a)] if a.get("rock_combo",false) else LUNGE_DURATIONS.lunge_recover
static func initialize(a: Dictionary) -> void:
	configure()
	a.rock_phase="active"
	a.rock_left=0.0
	a.rock_reuse=Tuning.number("rock.roar","reuse",12.0)
	a.rock_distance=0.0
	a.rock_hit=false
	a.rock_aim=[0.0,1.0]
	a.rock_chain_left=0
	a.rock_combo=false

static func slow_factor(c: Dictionary) -> float:
	if c.get("region","")!="salt_pool" or float(c.get("hp",0))<=0 or float(c.get("rock_slow_left",0))<=0: return 1.0
	return float(c.get("rock_slow_factor",1.0))

static func apply_slow(c: Dictionary, distance: float) -> void:
	var factor: float=0.05 if distance<RoarArea.RADIUS/3.0 else (0.15 if distance<RoarArea.RADIUS*2.0/3.0 else 0.25)
	c.rock_slow_factor=minf(slow_factor(c),factor)
	c.rock_slow_left=5.0

static func advance_status(c: Dictionary, dt: float) -> void:
	if c.get("region","")!="salt_pool" or float(c.get("hp",0))<=0:
		c.rock_slow_left=0.0
		c.rock_slow_factor=1.0
		c.rock_stun_left=0.0
		c.rock_launch_guard=0.0
		return
	c.rock_launch_guard=maxf(0.0,float(c.get("rock_launch_guard",0.0))-dt)
	if c.has("rock_slow_left"):
		c.rock_slow_left=maxf(0.0,float(c.rock_slow_left)-dt)
		if c.rock_slow_left<=0.0: c.rock_slow_factor=1.0

static func begin_lunge(a: Dictionary, point: Vector2) -> void:
	if not can_lunge(vec(a.position),point):
		a.rock_phase="active"
		a.rock_left=0.0
		return
	a.rock_phase="lunge_charge"
	a.rock_left=charge_duration(a)
	var aim:=vec(a.position).direction_to(point)
	a.rock_aim=pack(Vector2.DOWN if aim.is_zero_approx() else aim)


static func clearance(origin: Vector2, point: Vector2) -> float:
	var aim:=origin.direction_to(point)
	if aim.is_zero_approx(): return 0.0
	return origin.distance_to(Config.move(origin,aim*LUNGE_DISTANCE))

static func can_lunge(origin: Vector2, point: Vector2) -> bool:
	return origin.distance_to(point)>=65.0 and clearance(origin,point)>=40.0

static func reposition(run: Dictionary, origin: Vector2, point: Vector2, dt: float) -> Vector2:
	var aim:=origin.direction_to(point)
	if aim.is_zero_approx(): aim=Vector2.DOWN
	var best:=origin
	var score:=-INF
	for angle in [PI/2.0,-PI/2.0,PI,-PI/4.0,PI/4.0,3.0*PI/4.0,-3.0*PI/4.0]:
		var candidate:=Config.move(origin,aim.rotated(angle)*32.0)
		if candidate.distance_to(origin)<16.0: continue
		var first_step:=Config.move(origin,origin.direction_to(candidate)*minf(70.0*dt,origin.distance_to(candidate)))
		if Bodies.move(run,Config.ID,origin,first_step).distance_to(origin)<0.001: continue
		var spacing:=minf(candidate.distance_to(point),85.0)*2.0 if origin.distance_to(point)<65.0 else -candidate.distance_to(point)*0.05
		var value:=clearance(candidate,point)+spacing
		if value>score:
			score=value
			best=candidate
	return Bodies.move(run,Config.ID,origin,Config.move(origin,origin.direction_to(best)*minf(70.0*dt,origin.distance_to(best))))
static func vec(p: Array) -> Vector2: return Vector2(p[0],p[1])
static func pack(p: Vector2) -> Array: return [p.x,p.y]
static func hurt(run: Dictionary,point: Vector2,source: Vector2,hurt_feedback: Array=[]) -> void:
	var c: Dictionary=run.combat
	var hp_before: float=c.hp
	c.hp=maxf(0,c.hp-Skills.incoming_damage(run,int(Tuning.number("rock.lunge" if c.actors[Config.ID].rock_phase=="lunge" else "rock.roar","damage",preload("res://scripts/maze/monster_editor.gd").attack("rockmane",8)))))
	c.last_attacker="rockmane"
	var direction:=source.direction_to(point)
	if direction.is_zero_approx(): direction=Vector2.DOWN
	c.hit_velocity=pack(direction*150.0)
	c.hit_remaining=0.12
	c.flash_remaining=0.1
	Skills.PlayerHurt.record(c,hp_before,"physical",point,source,hurt_feedback)

static func lunge_hurt(run: Dictionary,point: Vector2,source: Vector2,aim: Vector2,hurt_feedback: Array=[]) -> void:
	var c: Dictionary=run.combat
	if float(c.get("rock_launch_guard",0.0))>0.0 or float(c.get("rock_stun_left",0.0))>0.0: return
	hurt(run,point,source,hurt_feedback)
	if c.hp<=0 or not Skills.PlayerHurt.enabled(c): return
	c.hurt_recovery_left=0.3
	c.rock_stun_left=0.0
	c.rock_launch_guard=1.0
	c.action=""
	c.action_left=0.0
	c.axe_pending=false
	c.hit_remaining=0.0
	c.rock_launch_left=0.3
	c.rock_launch_velocity=pack(aim*(40.0/0.3))
static func advance(run: Dictionary,point: Vector2,dt: float,held: float=0.0,hurt_feedback: Array=[]) -> void:
	configure()
	var c: Dictionary=run.combat
	if c.get("region","")!="salt_pool" or not c.get("rock_encounter",false): return
	c.rock_shake_left=maxf(0,float(c.get("rock_shake_left",0))-dt)
	dt=maxf(0.0,dt-held)
	if dt<=0.000001: return
	var a: Dictionary=c.actors[Config.ID]
	if run.monsters[Config.ID].status!="alive" or a.hp<=0 or c.hp<=0: return
	var pos:=vec(a.position)
	a.velocity=[0.0,0.0]
	a.rock_reuse=maxf(0.0,float(a.rock_reuse)-dt)
	if float(a.get("hit_remaining",0))>0:
		var used:=minf(dt,float(a.hit_remaining))
		var next:=Bodies.move(run,Config.ID,pos,Config.move(pos,vec(a.hit_velocity)*used))
		a.position=pack(next)
		a.velocity=pack((next-pos)/dt)
		a.hit_remaining=maxf(0,a.hit_remaining-dt)
		if a.rock_phase=="stunned":
			a.rock_left=maxf(0.0,float(a.rock_left)-dt)
			if a.rock_left<=0.00001: a.rock_phase="active"
		return
	if a.mode in ["idle","return"]:
		if pos.distance_to(point)>300: return
		a.mode="chase"
	if a.rock_phase=="combo_reposition":
		advance_side(run,a,point,dt)
		return
	# 保留旧阶段名兼容探索存档；rush 现在表示咆哮释放，不再冲撞。
	if a.rock_phase=="lunge_charge":
		a.rock_left=maxf(0.0,float(a.rock_left)-dt)
		if a.rock_left<=0.00001:
			a.rock_phase="lunge"
			a.rock_left=LUNGE_DISTANCE/LUNGE_SPEED
			a.rock_distance=0.0
			a.rock_hit=false
			if a.get("rock_combo",false): a.rock_combo_released=int(a.get("rock_combo_released",0))+1
	elif a.rock_phase=="lunge":
		var progress:=clampf(1.0-maxf(0.0,float(a.rock_left)-dt)/float(LUNGE_DURATIONS.lunge),0.0,1.0)
		var distance:=maxf(0.0,LUNGE_DISTANCE*smoothstep(0.0,1.0,progress)-float(a.rock_distance))
		var terrain_next:=Config.move(pos,vec(a.rock_aim)*distance)
		var wall_hit:=pos.distance_to(terrain_next)+0.001<distance
		if not a.rock_hit and Bodies.hero_contact(pos,terrain_next,point):
			a.rock_hit=true
			lunge_hurt(run,point,terrain_next,vec(a.rock_aim),hurt_feedback)
		var next:=Bodies.move(run,Config.ID,pos,terrain_next)
		var moved:=pos.distance_to(next)
		a.position=pack(next)
		a.velocity=pack((next-pos)/dt)
		a.rock_distance=minf(LUNGE_DISTANCE,float(a.rock_distance)+moved)
		a.rock_left=maxf(0.0,float(a.rock_left)-dt)
		if wall_hit and next.distance_to(terrain_next)<0.01:
			var speed:=6.0*progress*(1.0-progress)*LUNGE_SPEED
			var direct: float=Config.ChargeTerrain.impact_alignment(terrain_next,vec(a.rock_aim))
			if float(a.rock_distance)>=40.0 and speed>=LUNGE_SPEED and direct>=0.8:
				a.rock_phase="stunned"
				a.rock_left=LUNGE_DURATIONS.stunned
				a.rock_chain_left=0
				a.rock_combo=false
			else:
				a.rock_phase="lunge_recover"
				a.rock_left=recover_duration(a)
		elif float(a.rock_distance)>=LUNGE_DISTANCE-0.001 or a.rock_left<=0.00001:
			a.rock_phase="lunge_recover"
			a.rock_left=recover_duration(a)
	elif a.rock_phase in ["lunge_recover","stunned"]:
		a.rock_left=maxf(0.0,float(a.rock_left)-dt)
		if a.rock_left<=0.00001:
			if a.rock_phase=="lunge_recover" and a.get("rock_combo",false):
				a.rock_chain_left=maxi(0,int(a.get("rock_chain_left",0))-1)
				if a.rock_chain_left>0: queue_side(a)
				else:
					a.rock_phase="rest"
					a.rock_left=Tuning.number("rock.roar","rest",5.0)
					a.rock_combo=false
			else: a.rock_phase="active"
	elif a.rock_phase=="charge":
		a.rock_left=maxf(0,a.rock_left-dt)
		if a.rock_left<=0.00001:
			a.rock_phase="rush"
			a.rock_left=Tuning.number("rock.roar","release",0.45)
			a.rock_hit=true
			# 震屏触发状态沿用0.45秒契约；可调释放时长不改变镜头状态上限。
			c.rock_shake_left=0.45
			a.rock_combo=roar_hits(pos,vec(a.rock_aim),point)
			a.rock_chain_left=4 if a.rock_combo else 0
			if a.rock_combo:
				hurt(run,point,pos,hurt_feedback)
				if c.hp>0: apply_slow(c,pos.distance_to(point))
	elif a.rock_phase=="rush":
		a.rock_left=maxf(0,a.rock_left-dt)
		if a.rock_left<=0.00001:
			if a.get("rock_combo",false): start_combo(a,point)
			else:
				a.rock_phase="rest"
				a.rock_left=Tuning.number("rock.roar","rest",5.0)
	elif a.rock_phase=="rest":
		a.rock_left=maxf(0,a.rock_left-dt)
		if a.rock_left<=0.00001:
			a.rock_phase="active"
			a.rock_reuse=Tuning.number("rock.roar","reuse",12.0)
	else:
		a.mode="chase"
		a.windup=0.0
		if pos.distance_to(point)<=RoarArea.RADIUS and roar_clear(pos,point):
			if a.rock_reuse<=0.00001 and not a.get("rock_combo",false):
				a.rock_phase="charge"
				a.rock_left=Tuning.number("rock.roar","charge",1.1)
				a.rock_reuse=Tuning.number("rock.roar","reuse",12.0)
				var aim:=pos.direction_to(point)
				a.rock_aim=pack(Vector2.DOWN if aim.is_zero_approx() else aim)
			elif can_lunge(pos,point): begin_lunge(a,point)
			else:
				var next:=reposition(run,pos,point,dt)
				a.position=pack(next)
				a.velocity=pack((next-pos)/dt)
		else:
			var next:=Bodies.move(run,Config.ID,pos,preload("res://scripts/maze/rockmane_path.gd").step(pos,point,70*dt))
			a.position=pack(next)
			a.velocity=pack((next-pos)/dt)

static func roar_clear(origin: Vector2,target: Vector2) -> bool:
	return RoarArea.clear(origin,target)

static func roar_hits(origin: Vector2,aim: Vector2,point: Vector2) -> bool:
	return RoarArea.contains(RoarArea.polygon(origin,aim),point)
static func valid(a: Dictionary) -> bool:
	configure()
	if a.has("rock_combo") and not a.rock_combo is bool: return false
	if a.has("rock_chain_left") and (not Skills.number(a.rock_chain_left,4) or float(a.rock_chain_left)!=floor(float(a.rock_chain_left))): return false
	if not Config.allowed(vec(a.position)) or a.get("rock_phase") not in ["active","charge","rush","rest","lunge_charge","lunge","lunge_recover","stunned","combo_reposition"]: return false
	if a.has("rock_orbit_left") and not Skills.number(a.rock_orbit_left,6.0): return false
	if a.has("rock_combo_angle") and (typeof(a.rock_combo_angle) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(a.rock_combo_angle))): return false
	if not a.get("rock_orbit_path",[]) is Array or a.get("rock_orbit_path",[]).size()>500: return false
	for p in a.get("rock_orbit_path",[]):
		if not Skills.point(p): return false
	if not Skills.number(a.get("rock_left"),5.0) or not Skills.number(a.get("rock_reuse"),12.0) or not Skills.number(a.get("rock_distance"),maxf(180.001,LUNGE_DISTANCE+0.001)): return false
	return a.get("rock_hit") is bool and Skills.point(a.get("rock_aim")) and absf(vec(a.rock_aim).length()-1)<0.001
