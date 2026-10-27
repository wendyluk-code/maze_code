extends RefCounted
## 单次探索状态。所有变更与位置、奖励一起保存，失败全量回滚。
const Combat = preload("res://scripts/maze/combat_simulation.gd")
const Bento = preload("res://scripts/restaurant/bento_store.gd")
const KEY := "capture_run_v1"
const ROCK_FIRST := "rockmane_first_bound_v1"
const Crystals=preload("res://scripts/maze/salt_crystals.gd")
const SEEN := "capture_first_visit_started"
const PITY_KEY := "capture_failure_streaks_v1"

## 当前玩家存档全局、按种类计数；旧存档缺省为零，不回推历史失败。
static func failure_streak(sm: Node, kind: String) -> int:
	var counts: Variant = sm.get("_state").get(PITY_KEY,{})
	if not counts is Dictionary: return 0
	var value: Variant = counts.get(kind,0)
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return 0
	return clampi(int(value),0,3)
const Catalog := preload("res://data/maze/capture_catalog.gd")
const Progression := preload("res://scripts/characters/character_progression.gd")
const Roads := preload("res://data/maze/entry_roads.gd")

static func snapshot(sm: Node) -> Dictionary:
	var raw: Variant = sm.get("_state").get(KEY, {})
	return raw.duplicate(true) if raw is Dictionary else {}

static func catalog_version(run: Dictionary) -> int:
	return int(run.get("catalog_version", 1))

static func monsters_for(run: Dictionary) -> Array[Dictionary]:
	return Catalog.rows(run.combat, true) if run.has("combat") else Catalog.all(catalog_version(run), run.get("layout", []))

static func monster_for(run: Dictionary, id: String) -> Dictionary:
	for row in monsters_for(run):
		if row.id==id: return row
	return {}

static func _commit(sm: Node, previous: Dictionary) -> Dictionary:
	if sm.save(): return {"success":true}
	sm.set("_state", previous)
	return {"success":false,"reason":"save_failed"}

static func begin(sm: Node, point: Vector2, region: String = "maze_entry") -> Dictionary:
	if not sm.can_enter_maze() or not sm.maze_terrain(region).is_walkable(point): return {"success":false,"reason":"invalid_location"}
	var state: Dictionary = sm.get("_state")
	if state.has(KEY) and not state[KEY] is Dictionary: return {"success":false,"reason":"invalid_run"}
	var existing := snapshot(sm)
	if existing.get("active",false):
		if not existing.has("combat"): return {"success":false,"reason":"unsupported_combat_version"}
		if not existing.combat is Dictionary or not Combat.valid(existing.combat) or not Catalog.valid_layout(existing.get("layout",[])): return {"success":false,"reason":"invalid_run"}
		# 校验补存前的怪物集合，避免损坏档在迁移时访问缺失记录。
		if not existing.get("monsters") is Dictionary: return {"success":false,"reason":"invalid_run"}
		if not existing.combat.get("frog_encounter",false) and (existing.monsters.has(Catalog.Frog.ID) or existing.combat.actors.has(Catalog.Frog.ID)): return {"success":false,"reason":"invalid_run"}
		if not existing.combat.get("rock_encounter",false) and (existing.monsters.has(Catalog.Rock.ID) or existing.combat.actors.has(Catalog.Rock.ID)): return {"success":false,"reason":"invalid_run"}
		if existing.combat.get("rock_encounter",false) and not existing.monsters.get(Catalog.Rock.ID) is Dictionary: return {"success":false,"reason":"invalid_run"}
		var prior_layout: Array = existing.get("layout",[])
		if prior_layout.is_empty(): prior_layout = existing.combat.get("layout",[])
		var prior_rows := Catalog.all(catalog_version(existing),prior_layout)
		if existing.combat.get("fenshui_encounters",false):
			prior_rows.append_array(Catalog.Fenshui.all())
		else:
			# 只有真正的旧十怪存档可迁移；缺版本标记的区域残片不能覆盖重抽。
			for id in existing.monsters.keys()+existing.combat.actors.keys():
				if str(id).begins_with("fenshui_"): return {"success":false,"reason":"invalid_run"}
		if existing.combat.get("salt_encounters",false):
			prior_rows.append_array(Catalog.Salt.all())
		else:
			for id in existing.monsters.keys()+existing.combat.actors.keys():
				if str(id).begins_with("salt_pool_"): return {"success":false,"reason":"invalid_run"}
		for row in prior_rows:
			if not existing.monsters.get(row.id) is Dictionary: return {"success":false,"reason":"invalid_run"}
		if existing.combat.get("frog_encounter",false):
			if not existing.monsters.get(Catalog.Frog.ID) is Dictionary: return {"success":false,"reason":"invalid_run"}
		var layout_changed := ensure_layout(existing)
		layout_changed = ensure_region(existing,region) or layout_changed
		if not valid(existing): return {"success":false,"reason":"invalid_run"}
		var previous := state.duplicate(true)
		var migration := migrate_food(sm, existing)
		if not migration.success: return migration
		state[KEY] = existing
		var resumed: Dictionary = sm.record_maze_location(region,point)
		if not resumed.success:
			sm.set("_state", previous)
			return resumed
		if resumed.get("reason", "") == "unchanged" and (layout_changed or migration.get("changed", false)): return _commit(sm, previous)
		return resumed
	if region != "maze_entry": return {"success":false,"reason":"missing_active_run"}
	var party: Array = sm.exploration_entry_party()
	if party.is_empty() or party.size()>4: return {"success":false,"reason":"invalid_party"}
	var members: Array = []
	var power := 0
	var health := 0
	var food := 0.0
	var food_state := Progression.satiety_snapshot(sm)
	if not food_state.valid: return {"success":false,"reason":food_state.reason}
	for id in party:
		var row := Progression.record(sm,id)
		if not row.get("valid",false): return {"success":false,"reason":"invalid_character"}
		members.append({"id":id,"rank":row.rank,"level":row.level,"element":Progression.element(id)})
		power += int(row.attack)
		health += int(row.health)
		food += float(food_state.values[id])
	power = team_power(power,members)
	var previous := state.duplicate(true)
	state[sm.UNLOCKED_RECIPES_KEY]=sm.unlocked_recipe_ids()
	Progression.store_satiety(sm, food_state, true)
	var layout: Array = Catalog.random_layout(randi())
	var monsters := {}
	for row in Catalog.all(Catalog.BALANCE_VERSION, layout):
		monsters[row.id] = {"status":"alive","capture_roll":randf(),"drop_roll":randf(),"copy_roll":randf(),"extra_roll":randf(),"guaranteed":false,"respawn_at":0.0,"spawn_position":[row.position.x,row.position.y],"refresh_count":0}
	var first: bool = not state.get(SEEN,false) and not sm.maze_exploration_state().chapter_2_started
	state[SEEN] = true
	# 首次进入迷宫即建立探索教学，不要求玩家先接顾客订单。
	# 已由首单接单流程建立的 lesson 保留 recipe 入口，避免重复覆盖餐厅提示。
	if not state.has("ch2_guide_01"):
		state["ch2_guide_01"] = {"step":"explore", "recipe":"", "seen":{}, "banked":{}, "revision":2}
	state[KEY] = {"version":1,"active":true,"base_power":power,"absorbed":0,"satiety":food,"satiety_max":food,"members":members,"monsters":monsters,"layout":layout,"bag":{},"first_eligible":first,"first_used":false,"yaya_counter":0,"pending":"","maze_elapsed":0.0}
	state[KEY]["combat"] = Combat.create(power,health,point, Catalog.all(Catalog.BALANCE_VERSION, layout))
	state[KEY]["catalog_version"] = Catalog.BALANCE_VERSION
	state[KEY]["spawn_rng_state"] = str(randi())
	state[KEY]["food_version"] = 1
	state[KEY]["food_cursor"] = 0
	state[KEY]["satiety_max"] = 0
	for member in members: state[KEY].satiety_max += int(Progression.record(sm, member.id).satiety_max)
	# 沿用现有入场事务，包括其他任务接入的体力扣除；本服务不重设体力规则。
	var entry: Dictionary = sm.record_maze_location("maze_entry",point)
	if not entry.success:
		sm.set("_state",previous)
		sm.cancel_maze_entry()
		return entry
	if entry.get("reason","")=="unchanged": return _commit(sm,previous)
	return entry

static func team_power(base: int, members: Array) -> int:
	var bonus := 0
	for member in members:
		if member.id != "tieshan": continue
		var count := 0
		for other in members:
			if other.id != member.id and other.element == member.element: count += 1
		var rank := int(member.rank)
		var each := 7 if rank>=6 else (5 if rank>=4 else (4 if rank>=2 else 3))
		bonus += count*each + (3 if rank>=3 and count>=2 else 0) + (4 if rank>=5 and count>=3 else 0)
	return floori(base*(1.0+bonus/100.0))

## 新战斗档缺布局时仅补存既有出生点；不生成新怪、不改血量与已付费状态。
static func ensure_layout(run: Dictionary) -> bool:
	var changed := false
	if not run.has("layout") or run.layout.is_empty():
		run.layout = run.combat.get("layout", []).duplicate(true)
		if run.layout.is_empty():
			for row in Catalog.all(catalog_version(run)):
				run.layout.append({"kind":row.kind,"position":Combat.pack(row.position)})
		changed = true
	if not run.has("spawn_rng_state"):
		# 保留旧存档随机源字段，不重抽当前生命的四个随机结果。
		run.spawn_rng_state = "303"
		changed = true
	if not run.has("maze_elapsed"):
		run.maze_elapsed = 0.0
		changed = true
	if not run.combat.has("layout") or run.combat.layout.is_empty():
		run.combat.layout = run.layout.duplicate(true)
		changed = true
	for row in monsters_for(run):
		var monster: Dictionary = run.monsters[row.id]
		if row.id==Catalog.Rock.ID and monster.get("spawn_position",[])==[1025,205]:
			var rock: Dictionary=run.combat.actors[row.id]
			if monster.status=="alive" and rock.mode=="idle" and rock.hp==120 and Combat.vec(rock.position).distance_to(Vector2(1025,205))<2:
				rock.position=Combat.pack(Catalog.Rock.HOME)
			monster.spawn_position=Combat.pack(Catalog.Rock.HOME)
			changed=true
		if monster.status == "alive" and row.get("region","maze_entry")=="maze_entry":
			var safe_home := Catalog.nearest_clear_point(row.position)
			if safe_home != row.position:
				for index in run.layout.size():
					if run.layout[index].position == Combat.pack(row.position):
						run.layout[index].position = Combat.pack(safe_home)
						run.combat.layout[index].position = Combat.pack(safe_home)
				monster.spawn_position = Combat.pack(safe_home)
				changed = true
			var actor: Dictionary = run.combat.actors[row.id]
			var safe_position := Catalog.nearest_clear_point(Combat.vec(actor.position))
			if safe_position != Combat.vec(actor.position):
				actor.position = Combat.pack(safe_position)
				changed = true
		if not monster.has("spawn_position"):
			monster.spawn_position = Combat.pack(row.position)
			changed = true
		if not monster.has("refresh_count"):
			monster.refresh_count = 0
			changed = true
		if not monster.has("respawn_at"):
			# 旧档缺少兼容字段时补零；死亡结果保持到本趟结束。
			monster.respawn_at = 0.0
			changed = true
	return changed

static func valid(run: Dictionary) -> bool:
	if not Bento.valid_effects(run): return false
	if not Catalog.valid_layout(run.get("layout",[])): return false
	if run.has("combat") and (not run.combat is Dictionary or not Combat.valid(run.combat)): return false
	if run.get("version") != 1 or not run.get("monsters") is Dictionary or not run.get("bag") is Dictionary or not run.get("members") is Array: return false
	if run.has("combat"):
		var count := (16 if run.combat.get("fenshui_encounters",false) else 10)+(1 if run.combat.get("frog_encounter",false) else 0)+(6 if run.combat.get("salt_encounters",false) else 0)+(1 if run.combat.get("rock_encounter",false) else 0)
		if run.combat.actors.size()!=count or run.monsters.size()!=count: return false
		if not run.get("layout",[]).is_empty() and not run.combat.get("layout",[]).is_empty() and run.layout!=run.combat.layout: return false
	if not Progression._integer(run.get("catalog_version", 1), 1, Catalog.BALANCE_VERSION): return false
	var elapsed: Variant = run.get("maze_elapsed",0.0)
	if typeof(elapsed) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(elapsed)) or elapsed<0: return false
	if run.has("spawn_rng_state") and (not run.spawn_rng_state is String or not run.spawn_rng_state.is_valid_int()): return false
	for key in ["base_power","absorbed","satiety_max","yaya_counter"]:
		var value: Variant = run.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0 or float(value)!=floor(float(value)): return false
	if not Progression._food_number(run.get("satiety")) or run.satiety>run.satiety_max: return false
	if run.has("food_version") and (run.food_version != 1 or not Progression._integer(run.get("food_cursor"),0,run.members.size()-1)): return false
	for key in ["active","first_eligible","first_used"]:
		if not run.get(key) is bool: return false
	if not run.get("pending") is String or run.members.is_empty() or run.members.size()>4: return false
	var member_ids := {}
	for member in run.members:
		if not member is Dictionary or not member.get("id") is String or member_ids.has(member.id) or not Catalog.ELEMENTS.has(member.get("element")): return false
		if not Progression._integer(member.get("rank"),1,6) or not Progression._integer(member.get("level"),1,30): return false
		member_ids[member.id] = true
	var allowed_items := {"rock_salt":true,"cool_whisker_herb":true,"canal_lotus_root":true,"lantern_fruit":true}
	var claims: Variant=run.get("resource_claims",[])
	if not claims is Array: return false
	var seen_claims: Dictionary={}
	for id in claims:
		if not id is String or seen_claims.has(id): return false
		var resource: Dictionary=preload("res://data/maze/region_resources.gd").find(id)
		if resource.is_empty() or resource.permanent: return false
		seen_claims[id]=true
	for row in monsters_for(run):
		for item in row.drops: allowed_items[item] = true
	for item in run.bag:
		if not allowed_items.has(item) or not Progression._integer(run.bag[item],1,100000): return false
	var pending_count := 0
	for row in monsters_for(run):
		var monster: Variant = run.monsters.get(row.id)
		if not monster is Dictionary or monster.get("status") not in ["alive","pending","captured","failed","skipped"]: return false
		if run.has("combat") and not run.combat.actors.has(row.id): return false
		if not Progression._integer(monster.get("refresh_count",0),0,100000000): return false
		var deadline: Variant = monster.get("respawn_at",0.0)
		if typeof(deadline) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(deadline)) or deadline<0: return false
		if not monster.get("guaranteed") is bool: return false
		if monster.has("attempt"):
			var attempt: Variant = monster.attempt
			if not attempt is Dictionary or monster.status != "pending": return false
			if not attempt.get("passed") is bool or not attempt.get("finished") is bool: return false
			var started: Variant = attempt.get("started_at")
			if typeof(started) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(started)) or float(started)<=0: return false
		if monster.status=="pending":
			pending_count += 1
			if run.pending!=row.id: return false
		for key in ["capture_roll","drop_roll","copy_roll","extra_roll"]:
			var roll: Variant = monster.get(key)
			if typeof(roll) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(roll)) or roll<0 or roll>1: return false
	return pending_count==(0 if run.pending.is_empty() else 1)

static func chance(run: Dictionary, monster: Dictionary) -> int:
	if monster.kind!="rockmane" and run.monsters[monster.id].get("guaranteed",false): return 100
	var bonus := 0
	for member in run.members:
		if Catalog.COUNTERS.get(member.element,"") == monster.element:
			bonus += 14 if member.level>=20 else (12 if member.level>=10 else 10)
	return mini(95,int(monster.chance)+mini(30,bonus))

static func defeat(sm: Node, id: String, point: Vector2) -> Dictionary:
	var run := snapshot(sm)
	var row := monster_for(run, id)
	if row.is_empty() or not valid(run) or not run.get("active",false) or not Catalog.active(run.combat,id): return {"success":false,"reason":"invalid_encounter"}
	if run.monsters[id].status!="alive" or not str(run.pending).is_empty(): return {"success":false,"reason":"already_defeated"}
	if not run.has("combat") or run.combat.hp<=0 or run.combat.actors[id].hp>0: return {"success":false,"reason":"not_defeated"}
	var previous: Dictionary = sm.get("_state").duplicate(true)
	run.monsters[id].status = "pending"
	run.monsters[id].respawn_at = 0.0
	run.pending = id
	if row.kind=="rockmane" and not sm.get("_state").get(ROCK_FIRST,false):
		run.monsters[id].guaranteed=true
		sm.get("_state")[ROCK_FIRST]=true
	if row.kind=="slime" and run.first_eligible and not run.first_used:
		run.monsters[id].guaranteed = true
		run.first_used = true
	sm.get("_state")[KEY] = run
	sm.get("_state")[sm.MAZE_STATE_KEY].position = [point.x,point.y]
	return _commit(sm,previous)

## 在捕获窗确认时持久化扣费；已有付费标记时不再扣费。
static func start_capture(sm: Node, id: String) -> Dictionary:
	var run := snapshot(sm)
	if not valid(run) or not run.get("active",false) or run.pending != id or not run.monsters.has(id): return {"success":false,"reason":"invalid_encounter"}
	if run.monsters[id].has("attempt"): return {"success":true,"resumed":true}
	var payer := payer_index(sm, run)
	if payer < 0: return {"success":false,"reason":"hungry"}
	var previous: Dictionary = sm.get("_state").duplicate(true)
	run.satiety -= 1
	if run.get("food_version",0) == 1:
		var food := Progression.satiety_snapshot(sm)
		food.values[run.members[payer].id] -= 1.0
		Progression.store_satiety(sm,food,true)
		run.food_cursor = (payer+1)%run.members.size()
		run.satiety = _party_food(food,run.members)
	run.monsters[id].attempt = {"finished":false,"passed":false,"started_at":Time.get_unix_time_from_system()}
	sm.get("_state")[KEY] = run
	return _commit(sm,previous)

## 先保存操作结论；奖励保存失败重试时沿用结论，不重新挑战。
static func finish_capture(sm: Node, id: String, passed: bool) -> Dictionary:
	var run := snapshot(sm)
	if not valid(run) or not run.get("active",false) or run.pending != id or not run.monsters.has(id) or not run.monsters[id].has("attempt"): return {"success":false,"reason":"invalid_attempt"}
	if run.monsters[id].attempt.finished: return {"success":true}
	var previous: Dictionary = sm.get("_state").duplicate(true)
	run.monsters[id].attempt.finished = true
	run.monsters[id].attempt.passed = passed
	sm.get("_state")[KEY] = run
	return _commit(sm,previous)

static func resolve(sm: Node, id: String, capture: bool) -> Dictionary:
	var run := snapshot(sm)
	if not valid(run) or not run.get("active",false) or run.pending!=id or not run.monsters.has(id) or run.monsters[id].status!="pending": return {"success":false,"reason":"already_resolved"}
	var paid: bool = run.monsters[id].has("attempt")
	if paid and (not capture or not run.monsters[id].attempt.finished): return {"success":false,"reason":"attempt_in_progress"}
	var payer := payer_index(sm, run)
	if capture and not paid and payer < 0: return {"success":false,"reason":"hungry"}
	var previous: Dictionary = sm.get("_state").duplicate(true)
	var row := monster_for(run, id)
	var monster: Dictionary = run.monsters[id]
	var pity := capture and failure_streak(sm,row.kind) >= 3
	var items := {}
	var caught := false
	var copies := 0
	if capture:
		if not paid: run.satiety -= 1
		if not paid and run.get("food_version", 0) == 1:
			var food_state := Progression.satiety_snapshot(sm)
			food_state.values[run.members[payer].id] -= 1.0
			Progression.store_satiety(sm, food_state, true)
			run.food_cursor = (payer + 1) % run.members.size()
			run.satiety = _party_food(food_state, run.members)
		caught = pity or monster.guaranteed or float(monster.capture_roll)*100 < chance(run,row)
		if paid and not monster.guaranteed and not pity: caught = caught and bool(monster.attempt.passed)
		if caught:
			for item in row.drops: items[item] = 1
			if row.kind=="slime" and not monster.guaranteed:
				var pick := mini(2,int(float(monster.drop_roll)*3))
				if pick==0: items.erase("slime_shell")
				if pick==1: items.erase("slime_gel")
			for member in run.members:
				if member.id!="yaya": continue
				var rank := int(member.rank)
				var countered: bool = Catalog.COUNTERS.get(member.element,"")==row.element
				var probability := 25 if rank>=4 else (20 if rank>=2 else 15)
				if rank>=3 and countered: probability += 10
				var guaranteed: bool = rank>=6 and countered and run.yaya_counter<3
				if countered: run.yaya_counter += 1
				if guaranteed or float(monster.copy_roll)*100<probability:
					copies = 1 + (1 if rank>=5 and float(monster.extra_roll)<0.2 else 0)
			for item in items:
				items[item] *= 1+copies
				run.bag[item] = int(run.bag.get(item,0))+int(items[item])
	if caught:
		preload("res://scripts/maze/capture_recipes.gd").unlock(sm,row.kind)
	if capture:
		var counts := {}
		for kind in Catalog.capture_kinds(): counts[kind] = failure_streak(sm,kind)
		counts[row.kind] = 0 if caught else mini(3,counts[row.kind]+1)
		sm.get("_state")[PITY_KEY] = counts
	# 计数、奖励、结算记录同一事务提交，保存失败全部回滚。
	monster["capture_result"] = {
		"chance":chance(run,row), "roll":float(monster.capture_roll),
		"operation_passed":bool(monster.get("attempt",{}).get("passed",not paid)),
		"guaranteed":bool(monster.guaranteed),
		"pity":pity,
		"reason":"skipped" if not capture else ("captured" if caught else ("operation_failed" if paid and not monster.attempt.passed else "probability_failed"))
	}
	monster.erase("attempt")
	monster.status = ("captured" if caught else "failed") if capture else "skipped"
	monster.respawn_at = 0.0
	run.pending = ""
	sm.get("_state")[KEY] = run
	var result := _commit(sm,previous)
	if result.success: result.merge({"caught":caught,"items":items,"copies":copies})
	return result

static func finish(sm: Node, bank: bool, point: Vector2) -> Dictionary:
	var run := snapshot(sm)
	if not valid(run) or not run.get("active",false) or not str(run.pending).is_empty(): return {"success":false,"reason":"invalid_run"}
	if bank and run.has("combat") and run.combat.hp<=0: return {"success":false,"reason":"defeated"}
	if bank and portal_combat_locked(sm): return {"success":false,"reason":"in_combat"}
	if bank and not _at_salt_moss_link(sm,point) and not (preload("res://data/maze/settlement_exit.gd").can_bank(point) if sm.maze_exploration_state().region == "maze_entry" else (point.distance_to(sm.maze_terrain(sm.maze_exploration_state().region).ENTRANCE)<sm.maze_terrain(sm.maze_exploration_state().region).INTERACT_RADIUS or (sm.maze_exploration_state().region == "fenshui" and (point.distance_to(preload("res://data/maze/salt_pool_roads.gd").FENSHUI_PORTAL)<65.0 or point.distance_to(preload("res://data/maze/moss_pool_roads.gd").FENSHUI_PORTAL)<70.0)))): return {"success":false,"reason":"not_exit"}
	var state: Dictionary = sm.get("_state")
	var previous := state.duplicate(true)
	var food_state := Progression.satiety_snapshot(sm)
	if not food_state.valid: return {"success":false,"reason":food_state.reason}
	if run.get("food_version", 0) != 1:
		# 已确认兼容：本趟沿用旧池，离场时才按历史总消耗重建个人扣除。
		var remaining := maxf(0.0, float(run.satiety_max) - float(run.satiety))
		while remaining > 0.0:
			var paid := 0.0
			for member in run.members:
				var amount := minf(1.0, minf(remaining, float(food_state.values.get(member.id, 0.0))))
				food_state.values[member.id] = maxf(0.0, float(food_state.values.get(member.id, 0.0)) - amount)
				remaining -= amount
				paid += amount
				if remaining <= 0.0: break
			if paid <= 0.0: break
	Progression.store_satiety(sm, food_state, false)
	if bank:
		# 结算带回的食材进入餐厅仓库库存；背包是本趟临时储备，不能只写入携带栏。
		var warehouse: Dictionary = sm.warehouse_snapshot() if sm.has_method("warehouse_snapshot") else {}
		for id in run.bag:
			warehouse[id] = clampi(int(warehouse.get(id, 0)) + int(run.bag[id]), 0, 999)
		state["warehouse_stock"] = warehouse
	var lesson: Variant = state.get("ch2_guide_01", {})
	if lesson is Dictionary and not lesson.is_empty() and lesson.get("step", "") != "done":
		lesson["step"] = "warehouse" if bank and not run.bag.is_empty() else "entrance"
		lesson["banked"] = run.bag.duplicate(true) if bank else {}
		state["ch2_guide_01"] = lesson
	Bento.finish(sm,run)
	run.active = false
	run.bag = {}
	run.absorbed = 0
	state[KEY] = run
	state[sm.MAZE_STATE_KEY] = {"version":1,"region":"restaurant","position":[point.x,point.y],"chapter_2_started":true}
	if state.get("customer_05_trip_started", false): state["customer_05_returned"] = true
	return _commit(sm,previous)

static func _party_food(food: Dictionary, members: Array) -> float:
	var total := 0.0
	for member in members: total += float(food.values.get(member.id, 0.0))
	return total

static func payer_index(sm: Node, run: Dictionary) -> int:
	if run.get("food_version", 0) != 1: return 0 if float(run.get("satiety", 0)) >= 1.0 else -1
	var food := Progression.satiety_snapshot(sm)
	if not food.valid or run.members.is_empty(): return -1
	for offset in run.members.size():
		var index: int = (int(run.get("food_cursor", 0)) + offset) % run.members.size()
		if float(food.values.get(run.members[index].id, 0.0)) >= 1.0: return index
	return -1

static func capture_count(sm: Node, run: Dictionary) -> int:
	if run.get("food_version", 0) != 1: return floori(float(run.get("satiety", 0)))
	var food := Progression.satiety_snapshot(sm)
	if not food.valid: return 0
	var count := 0
	for member in run.members: count += floori(float(food.values.get(member.id, 0.0)))
	return count
# 旧探索没有逐人历史，只能按已用总量和当趟顺序重建一次；不重新抽随机数。
static func migrate_food(sm: Node, run: Dictionary) -> Dictionary:
	if run.get("food_version", 0) == 1: return {"success":true,"changed":false}
	var food := Progression.satiety_snapshot(sm)
	if not food.valid: return {"success":false,"reason":food.reason}
	var capacity := 0
	for member in run.members:
		var stats := Progression.record(sm, member.id)
		if not stats.valid: return {"success":false,"reason":"invalid_character"}
		capacity += int(stats.satiety_max)
	# 历史容量不匹配版本沿用本趟旧池，finish离场事务再补扣；正常容量立即迁移。
	if int(run.satiety_max) != capacity: return {"success":true,"changed":false}
	var spent := maxi(0, int(run.satiety_max) - int(run.satiety))
	var cursor := 0
	for charge in mini(spent, capacity):
		for offset in run.members.size():
			var index: int = (cursor + offset) % run.members.size()
			var id: String = run.members[index].id
			if float(food.values.get(id, 0.0)) >= 1.0:
				food.values[id] -= 1.0
				cursor = (index + 1) % run.members.size()
				break
	Progression.store_satiety(sm, food, true)
	run.food_version = 1
	run.food_cursor = cursor
	run.satiety = _party_food(food, run.members)
	return {"success":true,"changed":true}

static func respawn_delay(kind: String) -> float:
	return {"slime":60.0,"snail":90.0,"beetle":90.0,"lizard":180.0}.get(kind,90.0)

## 候选点须在道路上、距主角260以外且完整身体在视口外，并避开其他出生点和活体。
static func safe_spawn(run: Dictionary, id: String, candidate: Vector2, point: Vector2, visible: Rect2) -> bool:
	if not Catalog.clear_of_props(candidate): return false
	if not Catalog.spawn_inside_exit(candidate): return false
	if visible.size.x<=0 or visible.size.y<=0: return false
	if not Roads.is_walkable(candidate) or candidate.distance_to(point)<260.0 or visible.grow(80.0).has_point(candidate): return false
	for row in monsters_for(run):
		if row.id==id: continue
		if candidate.distance_to(row.position)<Catalog.MONSTER_CLEARANCE: return false
		if run.monsters[row.id].status=="alive" and candidate.distance_to(Combat.vec(run.combat.actors[row.id].position))<Catalog.MONSTER_CLEARANCE: return false
	return true

## 保留旧调用接口；每只怪物在本趟仅有一次生命，新探索由 begin 重新建立。
## 旧档 respawn_at / refresh_count / 随机源仍可读取，但不再驱动复活。
static func refresh_due(_run: Dictionary, _point: Vector2, _visible: Rect2) -> bool:
	return false

static func combat_attack(sm: Node, point: Vector2, aim: Vector2 = Vector2.RIGHT) -> Dictionary:
	var run := snapshot(sm)
	if not valid(run) or not run.get("active",false) or not run.has("combat") or not str(run.pending).is_empty() or not sm.maze_terrain(sm.maze_exploration_state().region).is_walkable(point):
		return {"success":false,"reason":"invalid_combat"}
	var previous: Dictionary=sm.get("_state").duplicate(true)
	Combat.Skills.sync_levels(run, sm)
	if not Combat.attack(run,point,aim): return {"success":true,"fired":false}
	run.combat.hero=Combat.pack(point)
	sm.get("_state")[KEY]=run
	sm.get("_state")[sm.MAZE_STATE_KEY].position=Combat.pack(point)
	return _commit(sm,previous)

## 换区只提交位置和瞬时战斗清理，同一趟队伍、生命、饱腹、携物及原区怪物保持。
static func portal_combat_locked(sm: Node) -> bool:
	var run := snapshot(sm)
	if not run.has("combat"): return false
	if bool(run.combat.get("axe_pending",false)) or float(run.combat.get("action_left",0.0))>0: return true
	for id in run.combat.actors:
		if Catalog.active(run.combat,id) and run.monsters[id].status == "alive" and run.combat.actors[id].mode in ["chase","windup"]: return true
	for key in ["shots","enemy_shots"]:
		if not run.combat.get(key, []).is_empty(): return true
	return false

static func change_region(sm: Node, region: String, point: Vector2) -> Dictionary:
	var run := snapshot(sm)
	if portal_combat_locked(sm): return {"success":false,"reason":"in_combat"}
	if region not in ["maze_entry","fenshui","salt_pool","moss_pool"] or not valid(run) or not run.get("active",false) or not str(run.pending).is_empty(): return {"success":false,"reason":"invalid_region_change"}
	var previous: Dictionary = sm.get("_state").duplicate(true)
	var c: Dictionary = run.combat
	if region == "maze_entry" and sm.maze_exploration_state().region == "fenshui":
		run["returned_regions"] = run.get("returned_regions", {})
		run.returned_regions[region] = true
		for row in Catalog.all(catalog_version(run),run.layout):
			run.monsters[row.id].status = "skipped"
			run.monsters[row.id].respawn_at = 1.0e20
	ensure_region(run,region)
	c.hero = Combat.pack(point)
	Combat.Skills.ensure(c)
	for key in ["shots","enemy_shots"]: c[key] = []
	for key in ["hit_remaining","flash_remaining","action_left"]: c[key] = 0.0
	c["axe_pending"] = false
	sm.get("_state")[KEY] = run
	var result: Dictionary = sm.record_maze_location(region,point)
	if not result.success: sm.set("_state",previous)
	return result

## 无魔物区域复用既有技能/冲刺计时，在临时副本屏蔽原区怪物；不结算原区事件。
static func _quiet_region_tick(sm: Node, run: Dictionary, point: Vector2, dt: float, sprinting: bool) -> Dictionary:
	var previous: Dictionary = sm.get("_state").duplicate(true)
	var original_monsters: Dictionary = run.monsters.duplicate(true)
	var original_actors: Dictionary = run.combat.actors.duplicate(true)
	for monster in run.monsters.values(): monster.status = "skipped"
	Combat.Skills.sync_levels(run, sm)
	run.combat["frog_unlocked"]=sm.yufeng_salia_state()=="done"
	Combat.advance(run,point,dt,sprinting)
	var healing := Bento.advance(run,dt)
	run.monsters = original_monsters
	run.combat.actors = original_actors
	run.combat.hero = Combat.pack(point)
	run.combat["checkpoint"] = float(run.combat.get("checkpoint",0.0))+dt
	sm.get("_state")[KEY] = run
	sm.get("_state")[sm.MAZE_STATE_KEY].position = Combat.pack(point)
	if healing or run.combat.checkpoint >= 0.5:
		run.combat.checkpoint = 0.0
		return _commit(sm,previous)
	return {"success":true}

static func combat_command(sm: Node, command: String, value: Variant) -> Dictionary:
	var run := snapshot(sm)
	if not valid(run) or not run.get("active",false) or not run.has("combat") or not str(run.pending).is_empty() or run.combat.hp<=0:
		return {"success":false,"reason":"invalid_combat"}
	var previous: Dictionary=sm.get("_state").duplicate(true)
	var changed := false
	if command=="select": changed=Combat.Skills.select(run,int(value))
	if not changed: return {"success":true,"changed":false}
	sm.get("_state")[KEY]=run
	return _commit(sm,previous)

static func combat_tick(sm: Node, point: Vector2, dt: float, visible: Rect2 = Rect2(), sprinting: bool = false) -> Dictionary:
	var run := snapshot(sm)
	if not is_finite(dt) or dt<=0.0 or dt>0.5: return {"success":false,"reason":"invalid_delta"}
	if not valid(run) or not run.get("active",false) or not run.has("combat") or not str(run.pending).is_empty() or run.combat.hp<=0 or not sm.maze_terrain(sm.maze_exploration_state().region).is_walkable(point):
		return {"success":false,"reason":"invalid_combat"}
	var previous: Dictionary = sm.get("_state").duplicate(true)
	var before: Dictionary = run.combat.duplicate(true)
	var migrated := ensure_layout(run)
	run.maze_elapsed = float(run.maze_elapsed) + dt
	var refreshed := refresh_due(run,point,visible)
	var guide: Dictionary = sm.get("_state").get("ch2_guide_01", {})
	Combat.Skills.sync_lesson(run, guide)
	Combat.Skills.sync_levels(run, sm)
	run.combat["frog_unlocked"]=sm.yufeng_salia_state()=="done"
	Combat.advance(run,point,dt,sprinting)
	var mining := Crystals.apply(sm.get("_state"),run,Crystals.day())
	if not mining.success:
		sm.set("_state",previous)
		return mining
	var healing := Bento.advance(run,dt)
	var lesson: Dictionary = run.combat.slime_lesson
	if lesson.enabled:
		guide["combat_hits"] = lesson.hits
		if lesson.completed:
			if not guide.has("seen"): guide.seen = {}
			guide.seen["05_spit_complete"] = true
		sm.get("_state")["ch2_guide_01"] = guide
	var lesson_changed: bool = before.get("slime_lesson", {}) != lesson
	# 只处理本次推进中从存活变为零生命的击杀，排队捕获不会延迟经验。
	# HP与经验、生命代数回执在同一事务中保存，旧档已死生命不追发。
	var awarded := false
	if run.combat.hp > 0:
		for row in monsters_for(run):
			var monster: Dictionary = run.monsters[row.id]
			if before.actors[row.id].hp <= 0 or run.combat.actors[row.id].hp > 0: continue
			if int(monster.get("experience_generation", -1)) == int(monster.refresh_count): continue
			var amount: int = {"slime":20,"snail":35,"beetle":35,"lizard":150,"silverfish":25,"thunder_eel":40,"wind_frog":120,"mimic_crab":35,"blind_scorpion":30,"rockmane":150}[row.kind]
			var growth := Progression.grant_experience(sm, run.members.map(func(member): return member.id), amount)
			if not growth.success:
				sm.set("_state", previous)
				return growth
			Combat.Skills.sync_levels(run, sm)
			monster.experience_generation = int(monster.refresh_count)
			awarded = true
	run.combat["checkpoint"] = float(before.get("checkpoint",0.0))+dt
	sm.get("_state")[KEY]=run
	sm.get("_state")[sm.MAZE_STATE_KEY].position=run.combat.hero.duplicate()
	var frog_changed: bool = run.combat.get("frog_encounter",false) and run.combat.actors[Catalog.Frog.ID]!=before.actors[Catalog.Frog.ID]
	var rock_changed: bool=run.combat.get("rock_encounter",false) and run.combat.actors[Catalog.Rock.ID]!=before.actors[Catalog.Rock.ID]
	if mining.changed or not mining.feedback.is_empty() or rock_changed or frog_changed or healing or lesson_changed or awarded or migrated or refreshed or run.combat.hp!=before.hp or run.combat.hits!=before.hits or run.combat.throws!=before.throws or run.combat.get("blocks",0)!=before.get("blocks",0) or run.combat.checkpoint>=0.5:
		run.combat.checkpoint=0.0
		var committed:=_commit(sm,previous)
		if committed.success: committed["mining_feedback"]=mining.feedback
		return committed
	return {"success":true}


static func ensure_region(run: Dictionary, region: String) -> bool:
	var changed: bool = run.combat.get("region","maze_entry")!=region
	run.combat["region"]=region
	if region=="salt_pool" and not run.combat.get("salt_encounters",false):
		for row in Catalog.Salt.all():
			run.monsters[row.id]={"status":"alive","capture_roll":randf(),"drop_roll":randf(),"copy_roll":randf(),"extra_roll":randf(),"guaranteed":false,"respawn_at":0.0,"spawn_position":Combat.pack(row.position),"refresh_count":0}
			run.combat.actors[row.id]=Combat.fresh_actor(row.kind,row.position)
		run.combat["salt_encounters"]=true
		changed=true
	if region=="fenshui" and not run.combat.get("fenshui_encounters",false):
		for row in Catalog.Fenshui.all():
			run.monsters[row.id]={"status":"alive","capture_roll":randf(),"drop_roll":randf(),"copy_roll":randf(),"extra_roll":randf(),"guaranteed":false,"respawn_at":0.0,"spawn_position":Combat.pack(row.position),"refresh_count":0}
			run.combat.actors[row.id]=Combat.fresh_actor(row.kind,row.position)
		run.combat["fenshui_encounters"]=true
		changed=true
	if region=="salt_pool" and not run.combat.get("rock_encounter",false):
		var row:=Catalog.Rock.row()
		run.monsters[row.id]={"status":"alive","capture_roll":randf(),"drop_roll":randf(),"copy_roll":randf(),"extra_roll":randf(),"guaranteed":false,"respawn_at":0.0,"spawn_position":Combat.pack(row.position),"refresh_count":0}
		var actor:=Combat.fresh_actor(row.kind,row.position)
		Combat.Rock.initialize(actor)
		run.combat.actors[row.id]=actor
		run.combat["rock_encounter"]=true
		changed=true
	if region=="fenshui" and not run.combat.get("frog_encounter",false):
		var row := Catalog.Frog.row()
		run.monsters[row.id]={"status":"alive","capture_roll":randf(),"drop_roll":randf(),"copy_roll":randf(),"extra_roll":randf(),"guaranteed":false,"respawn_at":0.0,"spawn_position":Combat.pack(row.position),"refresh_count":0}
		var actor := Combat.fresh_actor(row.kind,row.position)
		Combat.Frog.initialize(actor)
		run.combat.actors[row.id]=actor
		run.combat["frog_encounter"]=true
		changed=true
	return changed

## 新连接仍使用原有结束探索事务，仅扩充合法路标范围。
static func _at_salt_moss_link(sm: Node, point: Vector2) -> bool:
	var region: String = sm.maze_exploration_state().region
	var link = preload("res://data/maze/moss_pool_roads.gd")
	if region == "salt_pool": return point.distance_to(link.SALT_SIDE_MARKER)<80.0
	if region == "moss_pool": return point.distance_to(link.SALT_MARKER)<80.0
	return false
