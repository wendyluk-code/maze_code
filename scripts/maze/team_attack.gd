extends RefCounted
## 队伍招式和怪物技能的可保存状态。不得持有显示节点或直接写盘。
const Catalog = preload("res://data/maze/capture_catalog.gd")
const Roads = preload("res://data/maze/entry_roads.gd")
const Crystals=preload("res://scripts/maze/salt_crystals.gd")
const Hitstop=preload("res://scripts/maze/axe_hitstop.gd")
const FrogCounter=preload("res://scripts/maze/wind_frog_counter.gd")
const PlayerHurt=preload("res://scripts/maze/player_hurt_event.gd")
const PlayerCombatRules=preload("res://scripts/maze/player_combat_rules.gd")
const Monster=preload("res://scripts/maze/monster_combat.gd")
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
const Charge=preload("res://scripts/maze/lanjiao_charge.gd")
const Trail=preload("res://scripts/maze/ahong_trail.gd")
const Guard=preload("res://scripts/maze/chengyan_guard.gd")
const Tide=preload("res://scripts/maze/xiluomei_net.gd")
const Smoke=preload("res://scripts/maze/jiaopopo_smoke.gd")
const AXE_RADIUS := 66.0
const NAMES := {"hero":"锅铲","yaya":"芽芽","tieshan":"铁山","yufeng":"御风","salia":"萨莉亚","dingdang":"叮当","jiaopopo":"椒婆婆","xiluomei":"汐罗美","lanjiao":"岚角"}
const PERIOD := {"hero":0.65,"yaya":0.42,"tieshan":0.8}
const LENGTH := {"hero":210.0,"yaya":310.0,"yufeng":320.0,"salia":360.0}

static func rank_for(run: Dictionary, id: String) -> int:
	for member in run.members:
		if member.id == id: return int(member.rank)
	return 1

static func reach(run: Dictionary, id: String) -> float:
	if id == "xiluomei": return 280.0
	if id == "jiaopopo": return float(Smoke.rules(rank_for(run,id)).range)
	if id == "dingdang": return float(dingdang_rules(rank_for(run,id)).range)
	return float(LENGTH.get(id,AXE_RADIUS)) + (40.0 if id == "yufeng" and rank_for(run,id)>=3 else 0.0)

const Growth = preload("res://scripts/characters/character_progression.gd")

static func dingdang_rules(rank: int) -> Dictionary:
	var rules: Dictionary = Growth.CHARACTERS.dingdang.active_rules.duplicate(true)
	for i in clampi(rank,0,6):
		rules.merge(Growth.CHARACTERS.dingdang.star_effects[i],true)
	return rules

static func clear_marks(c: Dictionary) -> bool:
	var changed := false
	for actor in c.get("actors",{}).values():
		changed = actor.erase("lock_mark") or changed
	return changed

static func apply_mark(run: Dictionary, id: String, rank: int) -> void:
	if not Catalog.targetable(run.combat,id) or run.combat.actors[id].hp<=0: return
	var rules := dingdang_rules(rank)
	run.combat.actors[id]["lock_mark"]={"left":float(rules.mark_seconds),"bonus":float(rules.mark_damage_bonus)}

## 仅主动直接命中调用；雷链继续调用 damage，不消费或传播锁印。
static func direct_damage(run: Dictionary, id: String, amount: int, knockback: bool = true) -> void:
	if not Catalog.targetable(run.combat,id): return
	var actor: Dictionary = run.combat.actors[id]
	var mark: Dictionary = actor.get("lock_mark",{})
	if float(mark.get("left",0.0))>0:
		amount = roundi(float(amount)*(1.0+float(mark.bonus)))
		actor.erase("lock_mark")
	damage(run,id,amount,knockback)

static func level_for(run: Dictionary, id: String) -> int:
	for member in run.members:
		if member.id == id: return int(run.combat.get("skill_levels", {}).get(id, member.level))
	return 1

static func defense(run: Dictionary) -> int:
	var total := 0
	for member in run.members: total += Growth.defense(member.id, level_for(run, member.id))
	return total + int(run.get("bento",{}).get("defense",0))

static func incoming_damage(run: Dictionary, power: int) -> int:
	if power <= 0: return 0
	# 比例减伤最高75%；有效命中保留至少1点伤害。
	var multiplier := maxf(0.25, 20.0 / (20.0 + maxi(0, defense(run))))
	return maxi(1, ceili(float(power) * multiplier))

static func receive_damage(run: Dictionary, power: int) -> bool:
	return Guard.damage(run,incoming_damage(run,power))

static func sync_levels(run: Dictionary, sm: Node) -> void:
	var levels := {}
	for member in run.members:
		var stats := Growth.record(sm, member.id)
		levels[member.id] = stats.level if stats.get("valid", false) else member.level
	run.combat["skill_levels"] = levels

static func pack(p: Vector2) -> Array:
	return [p.x,p.y]

static func vec(a: Array) -> Vector2:
	return Vector2(a[0],a[1])

static func ensure(c: Dictionary) -> void:
	# 旧档字段仅作迁移清理，不再参与动作、伤害或显示。
	for key in ["guard_left", "guard_reuse", "guard_aim", "impacts", "blocks"]: c.erase(key)
	var defaults := {"selected":0,"action":"","action_left":0.0,"aim":[1.0,0.0],"enemy_shots":[],"axe_pending":false,"seed_remaining":0,"seed_wait":0.0,"seed_damage":0}
	for key in defaults:
		if not c.has(key): c[key]=defaults[key]

static func kind(run: Dictionary, slot: int) -> String:
	if slot==0: return "hero"
	if slot<1 or slot>run.members.size(): return ""
	var id: String = run.members[slot-1].id
	return id if NAMES.has(id) else ""

static func select(run: Dictionary, slot: int) -> bool:
	if Charge.active(run.combat) or kind(run,slot).is_empty(): return false
	ensure(run.combat)
	run.combat.selected=slot
	run.combat.seed_remaining=0
	run.combat.seed_wait=0.0
	return true

static func attack(run: Dictionary, point: Vector2, direction: Vector2) -> bool:
	var c: Dictionary=run.combat
	ensure(c)
	if c.hp<=0 or Charge.active(c) or PlayerHurt.recovering(c): return false
	if kind(run,int(c.selected))=="xiluomei" and c.has("xiluomei_net"):
		if c.xiluomei_net.left<=0.0000001 or c.xiluomei_net.outward: return false
		c.xiluomei_net.outward=true
		return true
	if c.cooldown>0.00001 or c.action_left>0: return false
	if not direction.is_finite() or direction.is_zero_approx(): return false
	var id := kind(run,int(c.selected))
	if id.is_empty(): return false
	var aim := direction.normalized()
	c.aim=pack(aim)
	c.action=id
	c.action_left=action_duration(id)
	var stats := Growth.active_skill(id, level_for(run, id))
	c.cooldown=stats.interval*Tuning.effect(id,"interval_scale",100.0)/100.0
	var amount := roundi(float(c.attack) * float(stats.multiplier)*Tuning.effect(id,"damage_scale",100.0)/100.0)
	c.throws+=1
	var element := Growth.element(id)
	c["basic_element"]=element
	c["basic_serial"]=int(c.throws)
	if id=="lanjiao":
		Charge.begin(c,rank_for(run,id),amount,aim)
	elif id=="xiluomei":
		Tide.open(run,Tide.center_for(point,aim,str(c.get("region","maze_entry"))),rank_for(run,id),amount,aim)
	elif id=="tieshan":
		c.axe_pending=true
		c["axe_damage"]=amount
	else:
		if id=="yaya":
			var per_seed: float=Tuning.effect(id,"burst_damage_scale",25.0)/100.0
			amount=maxi(1,roundi(amount*per_seed)) if amount>0 and per_seed>0.0 else 0
			c.seed_remaining=int(Tuning.effect(id,"burst_count",3.0))-1
			c.seed_wait=Tuning.effect(id,"burst_interval",0.1) if c.seed_remaining>0 else 0.0
			c.seed_damage=amount
			c.cooldown=yaya_cooldown(float(stats.interval))
		_projectile(run,point,aim,id,amount,element)
	return true

static func _projectile(run: Dictionary, origin: Vector2, aim: Vector2, id: String, amount: int, element: String) -> void:
	var c: Dictionary=run.combat
	var lives := {}
	for key in run.monsters: lives[key]=int(run.monsters[key].get("refresh_count",0))
	var distance: float=Tuning.effect(id,"distance",reach(run,id))
	var default_speed: float=310.0 if id=="yaya" else distance/(0.5 if id=="hero" else 0.6)
	var flight: float=distance/Tuning.effect(id,"speed",default_speed)
	c.shots.append({"origin":pack(origin),"target":pack(origin+aim*distance),"position":pack(origin),"time":0.0,"flight":flight,"kind":id,"lives":lives,"damage":amount,"basic":true,"element":element,"attack_serial":int(c.throws),"rank":rank_for(run,id),"hit_ids":[]})

static func action_duration(id: String) -> float:
	if id=="yaya": return maxf(burst_span()+0.05,0.30*Tuning.effect(id,"action_scale",100.0)/100.0)
	return (0.48 if id=="tieshan" else 0.30)*Tuning.effect(id,"action_scale",100.0)/100.0

static func burst_span() -> float:
	return (Tuning.effect("yaya","burst_count",3.0)-1.0)*Tuning.effect("yaya","burst_interval",0.1)

static func yaya_cooldown(base_interval: float) -> float:
	return maxf(base_interval*Tuning.effect("yaya","interval_scale",100.0)/100.0,maxf(Tuning.effect("yaya","burst_cooldown",0.45),burst_span()+0.05))

static func clear_line(a: Vector2, b: Vector2, region: String = "maze_entry") -> bool:
	var n := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(n+1):
		var terrain = preload("res://data/maze/fenshui_roads.gd") if region=="fenshui" else (preload("res://data/maze/salt_pool_roads.gd") if region=="salt_pool" else Roads)
		if not terrain.is_walkable(a.lerp(b,float(i)/n)): return false
	return true

# 教学状态由 CaptureRun 与经营存档一起提交，模拟本身不访问单例或写盘。
static func sync_lesson(run: Dictionary, guide: Dictionary) -> void:
	var seen: Dictionary = guide.get("seen", {})
	var lesson: Dictionary = run.combat.get("slime_lesson", {})
	lesson.enabled = run.combat.get("region","maze_entry")=="maze_entry" and not guide.is_empty() and guide.get("step", "") != "done" and not seen.get("05_spit_complete", false)
	lesson.attack_read = bool(seen.get("05_power", false))
	lesson.switch_read = bool(seen.get("05_switch", false))
	lesson.erase("guard_read")
	lesson.erase("guard_pending")
	lesson.hits = int(guide.get("combat_hits", 0))
	lesson.completed = bool(seen.get("05_spit_complete", false))
	run.combat.slime_lesson = lesson

static func protected_slime(run: Dictionary, id: String) -> bool:
	return Monster.protected_slime(run,id)

static func damage(run: Dictionary, id: String, amount: int = -1, knockback: bool = true) -> void:
	Monster.damage(run,id,amount,knockback)

static func impact(run: Dictionary, id: String, amount: int, weapon: String, contact: Vector2, direction: Vector2, feedback: Array, clock: Dictionary={}, source: Vector2=Vector2.INF) -> void:
	if Monster.eligible(run,id) and not Monster.protected_rockmane(run,id):
		var actor: Dictionary=run.combat.actors[id]
		var mark: Dictionary=actor.get("lock_mark",{})
		if float(mark.get("left",0.0))>0:
			amount=roundi(float(amount)*(1.0+float(mark.bonus)))
			actor.erase("lock_mark")
	Monster.impact(run,id,amount,weapon,contact,direction,feedback,clock,source)

static func advance(run: Dictionary, point: Vector2, dt: float, axe_clock: Dictionary={}, feedback: Array=[], hurt_feedback: Array=[]) -> void:
	var c: Dictionary=run.combat
	ensure(c)
	if kind(run,int(c.selected)).is_empty(): c.selected=0
	for key in c.actors:
		var actor: Dictionary = c.actors[key]
		if not actor.has("lock_mark"): continue
		actor.lock_mark.left=maxf(0.0,float(actor.lock_mark.left)-dt)
		if actor.lock_mark.left<=0 or actor.hp<=0 or actor.mode=="return" or not Catalog.active(c,str(key)) or run.monsters[key].status!="alive": actor.erase("lock_mark")
	if c.hp<=0 or PlayerHurt.recovering(c) or c.action!="yaya" or kind(run,int(c.selected))!="yaya":
		c.seed_remaining=0
		c.seed_wait=0.0
	elif c.seed_remaining>0 and dt>0.0:
		c.seed_wait=maxf(0.0,float(c.seed_wait)-Hitstop.action_delta(axe_clock,dt))
		if c.seed_wait<=0.000001:
			_projectile(run,point,vec(c.aim),"yaya",int(c.seed_damage),str(c.basic_element))
			c.seed_remaining-=1
			c.seed_wait=Tuning.effect("yaya","burst_interval",0.1) if c.seed_remaining>0 else 0.0
	c.action_left=maxf(0.0,float(c.action_left)-Hitstop.action_delta(axe_clock,dt))
	if c.seed_remaining>0: c.action_left=maxf(float(c.action_left),0.05)
	if c.axe_pending and c.action_left<=action_duration("tieshan")*0.625:
		c.axe_pending=false
		var hit_ids: Array=[]
		Crystals.melee(c,point,str(c.get("basic_element","")),int(c.get("basic_serial",-1)))
		for key in c.actors:
			if not Monster.eligible(run,str(key)): continue
			var a: Dictionary=c.actors[key]
			var pos := vec(a.position)
			if pos.distance_to(point)<=Tuning.effect("tieshan","hit_radius",AXE_RADIUS) and clear_line(point,pos,str(c.get("region","maze_entry"))):
				var direction:=point.direction_to(pos)
				impact(run,key,int(c.get("axe_damage",c.attack)),"tieshan",pos-direction*minf(14.0,point.distance_to(pos)),direction,feedback)
				if not Monster.protected_rockmane(run,str(key)): hit_ids.append(str(key))
		Hitstop.trigger(axe_clock,int(c.throws),hit_ids)
	# 蓄力锁定发射方向，弹丸释放后不跟踪玩家。近战仍由原模拟独立处理。
	for key in c.actors:
		if not Catalog.active(c,str(key)): continue
		if not str(key).begins_with("slime_"): continue
		var a: Dictionary=c.actors[key]
		if Smoke.retreating(c,str(key)) or Trail.paralyzed(a): continue
		if float(a.get("wind_left",0.0))>0: continue
		var protected := protected_slime(run, str(key))
		var lesson: Dictionary = c.get("slime_lesson", {})
		a.skill_reuse=maxf(0.0,float(a.get("skill_reuse",1.5))-dt)
		var actor_dt:=Hitstop.actor_delta(axe_clock,str(key),dt)
		var was_spitting := float(a.get("spit_left",0.0)) > 0.0
		a.spit_left=maxf(0.0,float(a.get("spit_left",0.0))-actor_dt)
		if run.monsters[key].status!="alive" or a.hp<=0 or a.mode=="return":
			a.cast=0.0
			a.spit_left=0.0
			continue
		if actor_dt<=0.000001: continue
		if protected and was_spitting and a.spit_left <= 0.0:
			lesson.completed = true
		var pos := vec(a.position)
		if float(a.get("cast",0.0))>0:
			a.cast=maxf(0.0,float(a.cast)-actor_dt)
			if a.cast<=0:
				var aim := vec(a.cast_aim)
				c.enemy_shots.append({"position":pack(pos),"direction":pack(aim),"distance":0.0,"source":str(key)})
				a.spit_left=Tuning.number("slime.spit","recover",0.28)
		elif (a.mode=="chase" or (protected and a.mode=="windup")) and a.skill_reuse<=0 and (protected or pos.distance_to(point)>42.0) and pos.distance_to(point)<180.0 and clear_line(pos,point):
			if protected and not lesson.get("switch_read", false): continue
			a.cast=Tuning.number("slime.spit","charge",0.65)
			var aim := pos.direction_to(point)
			if aim.is_zero_approx(): aim = Vector2.DOWN
			a.cast_aim=pack(aim)
			a.skill_reuse=Tuning.number("slime.spit","interval",2.4)
	var flying: Array=[]
	for shot in c.enemy_shots:
		var old := vec(shot.position)
		var direction := vec(shot.direction)
		var travel:=minf(Tuning.number("slime.spit","speed",190.0)*dt,maxf(0.0,Tuning.number("slime.spit","distance",320.0)-float(shot.distance)))
		var next := old+direction*travel
		var used := false
		var steps := maxi(1,ceili(old.distance_to(next)/2.0))
		for i in range(1,steps+1):
			var pos := old.lerp(next,float(i)/steps)
			if not Roads.is_walkable(pos):
				used=true
				break
			if pos.distance_to(point)<=Tuning.number("slime.spit","hit_radius",20.0):
				var hp_before: float=c.hp
				if receive_damage(run,int(Tuning.number("slime.spit","damage",preload("res://scripts/maze/monster_editor.gd").attack("slime",3)))):
					c.last_attacker="slime"
					c.flash_remaining=0.1
					PlayerHurt.record(c,hp_before,"physical",point,old,hurt_feedback)
					if c.hp>0: c.hurt_recovery_left=Tuning.number("melee.slime","hurt",600.0)/1000.0
				used=true
				break
		shot.position=pack(next)
		shot.distance+=travel
		if not used and shot.distance<Tuning.number("slime.spit","distance",320.0): flying.append(shot)
	c.enemy_shots=flying
	if c.hp<=0:
		c.enemy_shots.clear()
		c.action_left=0.0
		c.axe_pending=false

static func number(value: Variant, limit: float) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and value>=0 and value<=limit

static func point(value: Variant) -> bool:
	return value is Array and value.size()==2 and typeof(value[0]) in [TYPE_INT,TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value[0])) and is_finite(float(value[1]))

static func valid(c: Dictionary) -> bool:
	if c.has("seed_remaining") and not Growth._integer(c.seed_remaining,0,11): return false
	if c.has("seed_wait") and not number(c.seed_wait,0.3): return false
	if c.has("seed_damage") and not Growth._integer(c.seed_damage,0,9007199254740991): return false
	if not Charge.valid(c): return false
	if not Guard.valid(c): return false
	if not Tide.valid(c): return false
	if not Trail.valid(c): return false
	if not Smoke.valid(c): return false
	if c.has("salt_attack_receipts"):
		if not c.salt_attack_receipts is Array or c.salt_attack_receipts.size()>33: return false
		var receipts: Dictionary={}
		for serial in c.salt_attack_receipts:
			if not number(serial,float(c.get("throws",0))) or float(serial)!=floor(float(serial)) or receipts.has(int(serial)): return false
			receipts[int(serial)]=true
	if c.has("basic_serial") and (not number(c.basic_serial,float(c.get("throws",0))) or float(c.basic_serial)!=floor(float(c.basic_serial))): return false
	if c.has("basic_element") and c.basic_element not in ["","fire","grass","earth","thunder","water","wind"]: return false
	if c.has("salt_impacts"):
		if not c.salt_impacts is Array or c.salt_impacts.size()>8: return false
		for event in c.salt_impacts:
			if not event is Dictionary or event.get("id") not in ["left","right"] or event.get("element") not in ["","fire","grass","earth","thunder","water","wind"]: return false
	if c.has("skill_levels"):
		if not c.skill_levels is Dictionary: return false
		for id in c.skill_levels:
			if not Growth.CHARACTERS.has(id) or not Growth._integer(c.skill_levels[id], 1, 30): return false
	if c.has("axe_damage") and not Growth._integer(c.axe_damage, 0, 9007199254740991): return false
	if not c.get("shots", []) is Array: return false
	for shot in c.get("shots", []):
		if shot is Dictionary:
			if shot.has("rank") and not Growth._integer(shot.rank,1,6): return false
			if shot.has("hit_ids") and (not shot.hit_ids is Array or shot.hit_ids.size()>2): return false
			if shot.has("tracking_id") and not shot.tracking_id is String: return false
			if shot.has("distance") and not number(shot.distance,360.0): return false
		if shot is Dictionary and shot.has("damage") and not Growth._integer(shot.damage, 0, 9007199254740991): return false
	if not c.get("actors",{}) is Dictionary: return false
	if c.has("slime_lesson"):
		if not c.slime_lesson is Dictionary: return false
		for key in ["enabled", "attack_read", "switch_read", "completed"]:
			if c.slime_lesson.has(key) and not c.slime_lesson[key] is bool: return false
		var hits: Variant = c.slime_lesson.get("hits", 0)
		if not number(hits, 3) or float(hits) != floor(float(hits)): return false
	for key in ["action_left"]:
		if c.has(key) and not number(c[key],4.0 if c.get("action","")=="yaya" else 1.0): return false
	if c.has("hurt_recovery_left") and not number(c.hurt_recovery_left,2.0): return false
	if c.has("selected") and (not number(c.selected,4) or float(c.selected)!=int(c.selected)): return false
	for key in ["aim"]:
		if c.has(key) and (not point(c[key]) or absf(vec(c[key]).length()-1.0)>0.001): return false
	if c.has("action") and c.action != "" and not NAMES.has(c.action): return false
	if c.has("axe_pending") and not c.axe_pending is bool: return false
	for key in ["enemy_shots"]:
		if not c.get(key,[]) is Array or c.get(key,[]).size()>32: return false
		for row in c.get(key,[]):
			if not row is Dictionary or not point(row.get("position")) or not point(row.get("direction")): return false
			if absf(vec(row.direction).length()-1.0)>0.001: return false
			if key=="enemy_shots" and (not number(row.get("distance"),maxf(400.0,Tuning.number("slime.spit","distance",320.0))) or not row.get("source") is String): return false
	for a in c.get("actors",{}).values():
		if not a is Dictionary: return false
		if a.has("lock_mark"):
			if not a.lock_mark is Dictionary or not number(a.lock_mark.get("left"),5.0): return false
			if a.lock_mark.get("bonus") not in [0.15,0.25]: return false
		for key in ["cast","skill_reuse","spit_left"]:
			if a.has(key) and not number(a[key],3.0): return false
		if float(a.get("cast",0.0))>0 and not a.has("cast_aim"): return false
		if a.has("cast_aim") and (not point(a.cast_aim) or absf(vec(a.cast_aim).length()-1.0)>0.001): return false
	return true
