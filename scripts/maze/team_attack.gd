extends RefCounted
## 队伍招式和怪物技能的可保存状态。不得持有显示节点或直接写盘。
const Catalog = preload("res://data/maze/capture_catalog.gd")
const Roads = preload("res://data/maze/entry_roads.gd")
const Crystals=preload("res://scripts/maze/salt_crystals.gd")
const AXE_RADIUS := 66.0
const NAMES := {"hero":"锅铲","yaya":"芽芽","tieshan":"铁山"}
const PERIOD := {"hero":0.65,"yaya":0.42,"tieshan":0.8}
const LENGTH := {"hero":210.0,"yaya":310.0}

const Growth = preload("res://scripts/characters/character_progression.gd")

static func level_for(run: Dictionary, id: String) -> int:
	for member in run.members:
		if member.id == id: return int(run.combat.get("skill_levels", {}).get(id, member.level))
	return 1

static func defense(run: Dictionary) -> int:
	var total := 0
	for member in run.members: total += Growth.defense(member.id, level_for(run, member.id))
	return total + int(run.get("bento",{}).get("defense",0))

static func incoming_damage(run: Dictionary, power: int) -> int:
	return maxi(0, power - defense(run))

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
	var defaults := {"selected":0,"action":"","action_left":0.0,"aim":[1.0,0.0],"enemy_shots":[],"axe_pending":false}
	for key in defaults:
		if not c.has(key): c[key]=defaults[key]

static func kind(run: Dictionary, slot: int) -> String:
	if slot==0: return "hero"
	if slot<1 or slot>run.members.size(): return ""
	var id: String = run.members[slot-1].id
	return id if NAMES.has(id) else ""

static func select(run: Dictionary, slot: int) -> bool:
	if kind(run,slot).is_empty(): return false
	ensure(run.combat)
	run.combat.selected=slot
	return true

static func attack(run: Dictionary, point: Vector2, direction: Vector2) -> bool:
	var c: Dictionary=run.combat
	ensure(c)
	if c.hp<=0 or c.cooldown>0.00001 or c.action_left>0: return false
	if not direction.is_finite() or direction.is_zero_approx(): return false
	var id := kind(run,int(c.selected))
	if id.is_empty(): return false
	var aim := direction.normalized()
	c.aim=pack(aim)
	c.action=id
	c.action_left=0.48 if id=="tieshan" else 0.30
	var stats := Growth.active_skill(id, level_for(run, id))
	c.cooldown=stats.interval
	var amount := roundi(float(c.attack) * float(stats.multiplier))
	c.throws+=1
	var element := Growth.element(id)
	c["basic_element"]=element
	c["basic_serial"]=int(c.throws)
	if id=="tieshan":
		c.axe_pending=true
		c["axe_damage"]=amount
	else:
		var lives := {}
		for key in run.monsters: lives[key]=int(run.monsters[key].get("refresh_count",0))
		c.shots.append({"origin":pack(point),"target":pack(point+aim*LENGTH[id]),"position":pack(point),"time":0.0,"flight":0.5 if id=="hero" else 0.6,"kind":id,"lives":lives,"damage":amount,"basic":true,"element":element,"attack_serial":int(c.throws)})
	return true

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
	var lesson: Dictionary = run.combat.get("slime_lesson", {})
	return id == "slime_1" and lesson.get("enabled", false) and not lesson.get("completed", false)

static func damage(run: Dictionary, id: String, amount: int = -1) -> void:
	var c: Dictionary = run.combat
	if not Catalog.targetable(c,id): return
	c.actors[id].hp = maxi(1 if protected_slime(run, id) else 0, c.actors[id].hp - (int(c.attack) if amount < 0 else amount))
	var direction:=vec(c.hero).direction_to(vec(c.actors[id].position))
	if direction.is_zero_approx(): direction=Vector2.DOWN
	c.actors[id].hit_velocity=[direction.x*100.0,direction.y*100.0]
	c.actors[id].hit_remaining=0.12
	c.actors[id].flash_remaining=0.1
	if id==Catalog.Frog.ID and c.actors[id].hp<=0: c.actors[id].frog_shots.clear()
	c.hits += 1
	var lesson: Dictionary = c.get("slime_lesson", {})
	if lesson.get("enabled", false) and lesson.get("attack_read", false) and not lesson.get("switch_read", false):
		lesson.hits = mini(3, int(lesson.get("hits", 0)) + 1)

static func advance(run: Dictionary, point: Vector2, dt: float) -> void:
	var c: Dictionary=run.combat
	ensure(c)
	if kind(run,int(c.selected)).is_empty(): c.selected=0
	c.action_left=maxf(0.0,float(c.action_left)-dt)
	if c.axe_pending and c.action_left<=0.30:
		c.axe_pending=false
		Crystals.melee(c,point,str(c.get("basic_element","")),int(c.get("basic_serial",-1)))
		for key in c.actors:
			if not Catalog.active(c,str(key)): continue
			var a: Dictionary=c.actors[key]
			if run.monsters[key].status!="alive" or a.hp<=0 or a.mode=="return" or not Catalog.targetable(c,str(key)): continue
			var pos := vec(a.position)
			if pos.distance_to(point)<=AXE_RADIUS and clear_line(point,pos,str(c.get("region","maze_entry"))):
				damage(run, key, int(c.get("axe_damage", c.attack)))
				a.mode="chase"
	# 蓄力锁定发射方向，弹丸释放后不跟踪玩家。近战仍由原模拟独立处理。
	for key in c.actors:
		if not Catalog.active(c,str(key)): continue
		if not str(key).begins_with("slime_"): continue
		var a: Dictionary=c.actors[key]
		var protected := protected_slime(run, str(key))
		var lesson: Dictionary = c.get("slime_lesson", {})
		a.skill_reuse=maxf(0.0,float(a.get("skill_reuse",1.5))-dt)
		var was_spitting := float(a.get("spit_left",0.0)) > 0.0
		a.spit_left=maxf(0.0,float(a.get("spit_left",0.0))-dt)
		if run.monsters[key].status!="alive" or a.hp<=0 or a.mode=="return":
			a.cast=0.0
			a.spit_left=0.0
			continue
		if protected and was_spitting and a.spit_left <= 0.0:
			lesson.completed = true
		var pos := vec(a.position)
		if float(a.get("cast",0.0))>0:
			a.cast=maxf(0.0,float(a.cast)-dt)
			if a.cast<=0:
				var aim := vec(a.cast_aim)
				c.enemy_shots.append({"position":pack(pos),"direction":pack(aim),"distance":0.0,"source":str(key)})
				a.spit_left=0.28
		elif (a.mode=="chase" or (protected and a.mode=="windup")) and a.skill_reuse<=0 and (protected or pos.distance_to(point)>42.0) and pos.distance_to(point)<180.0 and clear_line(pos,point):
			if protected and not lesson.get("switch_read", false): continue
			a.cast=0.65
			var aim := pos.direction_to(point)
			if aim.is_zero_approx(): aim = Vector2.DOWN
			a.cast_aim=pack(aim)
			a.skill_reuse=2.4
	var flying: Array=[]
	for shot in c.enemy_shots:
		var old := vec(shot.position)
		var direction := vec(shot.direction)
		var next := old+direction*190.0*dt
		var used := false
		var steps := maxi(1,ceili(old.distance_to(next)/2.0))
		for i in range(1,steps+1):
			var pos := old.lerp(next,float(i)/steps)
			if not Roads.is_walkable(pos):
				used=true
				break
			if pos.distance_to(point)<=20.0:
				c.hp=maxf(0,c.hp-incoming_damage(run, 3))
				c.last_attacker="slime"
				c.flash_remaining=0.1
				used=true
				break
		shot.position=pack(next)
		shot.distance+=190.0*dt
		if not used and shot.distance<320.0: flying.append(shot)
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
		if shot is Dictionary and shot.has("damage") and not Growth._integer(shot.damage, 0, 9007199254740991): return false
	if not c.get("actors",{}) is Dictionary: return false
	if c.has("slime_lesson"):
		if not c.slime_lesson is Dictionary: return false
		for key in ["enabled", "attack_read", "switch_read", "completed"]:
			if c.slime_lesson.has(key) and not c.slime_lesson[key] is bool: return false
		var hits: Variant = c.slime_lesson.get("hits", 0)
		if not number(hits, 3) or float(hits) != floor(float(hits)): return false
	for key in ["action_left"]:
		if c.has(key) and not number(c[key],1.0): return false
	if c.has("selected") and (not number(c.selected,4) or float(c.selected)!=int(c.selected)): return false
	for key in ["aim"]:
		if c.has(key) and (not point(c[key]) or absf(vec(c[key]).length()-1.0)>0.001): return false
	if c.has("action") and c.action not in ["","hero","yaya","tieshan"]: return false
	if c.has("axe_pending") and not c.axe_pending is bool: return false
	for key in ["enemy_shots"]:
		if not c.get(key,[]) is Array or c.get(key,[]).size()>32: return false
		for row in c.get(key,[]):
			if not row is Dictionary or not point(row.get("position")) or not point(row.get("direction")): return false
			if absf(vec(row.direction).length()-1.0)>0.001: return false
			if key=="enemy_shots" and (not number(row.get("distance"),400) or not row.get("source") is String): return false
	for a in c.get("actors",{}).values():
		if not a is Dictionary: return false
		for key in ["cast","skill_reuse","spit_left"]:
			if a.has(key) and not number(a[key],3.0): return false
		if float(a.get("cast",0.0))>0 and not a.has("cast_aim"): return false
		if a.has("cast_aim") and (not point(a.cast_aim) or absf(vec(a.cast_aim).length()-1.0)>0.001): return false
	return true
