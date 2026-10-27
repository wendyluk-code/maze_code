extends Node
const Registry := preload("res://scripts/quests/quest_registry.gd")
const Elder := preload("res://data/maze/elder_firewood.gd")
const Roads := preload("res://data/maze/entry_roads.gd")
var sm: Node
var checks := 0
var failures := 0
var results: Array = []
const NEAR := Vector2(839, 503)

func _ready() -> void:
	call_deferred("_run")

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.substr(prefix.length())
	return ""

func _check(ok: bool, name: String) -> void:
	checks += 1
	results.append({"name": name, "passed": ok})
	if not ok:
		failures += 1
		push_error("ELDER 验收失败：" + name)

func _isolation() -> bool:
	var path := OS.get_user_data_dir().replace("\\", "/")
	var expected := _arg("--isolation-root=").replace("\\", "/")
	print("ELDER_USER_DIR=", path)
	return not expected.is_empty() and path.begins_with(expected)

func _seed(wood := 0) -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://elder-state.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.save(), "前置存档初始化")
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success and sm.deliver_first_order().success, "真实首单事务完成")
	for expected in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(expected): continue
		if sm.departure_state().step == "ready_to_depart": break
		_check(sm.advance_departure(expected).success, "前置：" + expected)
	for expected in ["party", "home", "maze", "title"]:
		_check(sm.advance_chapter_1_outro(expected).success, "章末：" + expected)
	sm.data.inventory.wood = wood
	_check(sm.record_maze_location("maze_entry", NEAR).success, "合法迷宫接入")

func _site_approach(site: Dictionary) -> Vector2:
	var closest := Roads.SPAWN
	var distance := INF
	for road in Roads.roads():
		var points: PackedVector2Array = road.points
		for i in range(points.size()-1):
			var point := Geometry2D.get_closest_point_to_segment(site.position, points[i], points[i+1])
			if Roads.is_walkable(point) and point.distance_to(site.position) < distance:
				closest = point
				distance = point.distance_to(site.position)
	return closest

func _unchanged(action: Callable, name: String) -> void:
	var before := JSON.stringify(sm.data)
	var bytes := FileAccess.get_file_as_bytes(sm._active_save_path)
	var result: Dictionary = action.call()
	_check(not result.success and JSON.stringify(sm.data) == before and FileAccess.get_file_as_bytes(sm._active_save_path) == bytes, name)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	_check(_isolation(), "实际用户目录隔离")
	if failures == 0: _matrix()
	_finish()

func _matrix() -> void:
	var definition: Dictionary = Registry.definition("elder_firewood")
	_check(definition.type == "collection" and definition.subtasks.is_empty() and definition.completion_condition.quantity == 12, "已确认任务定义与空子任务")
	_check(Roads.is_walkable(NEAR) and NEAR.distance_to(Elder.POSITION) <= Elder.INTERACT_RADIUS, "红圈路边有可达交互站位")
	_seed(15)
	_unchanged(func(): return sm.deliver_elder_firewood(NEAR), "未接取不得交付")
	_unchanged(func(): return sm.accept_elder_firewood(Roads.SPAWN), "远距不得接取")
	_unchanged(func(): return sm.accept_elder_firewood(Vector2(864, 450)), "树林站位不得接取")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not sm.accept_elder_firewood(NEAR).success and sm.data == before, "接取无保存路径完整回滚")
	sm._active_save_path = path
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	_unchanged(func(): return sm.accept_elder_firewood(NEAR), "接取真实临时文件打开失败内存文件回滚")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	_check(sm.accept_elder_firewood(NEAR).success, "真实接取落盘")
	_check(sm.elder_firewood_state().wood == 15 and sm.elder_firewood_state().unread, "接前木材计入且新任务未读")
	var bytes := FileAccess.get_file_as_bytes(path)
	var memory := JSON.stringify(sm.data)
	for i in 3:
		sm.elder_firewood_state(); sm.elder_backpack_unlocked(); sm.quest_snapshot()
	_check(JSON.stringify(sm.data) == memory and FileAccess.get_file_as_bytes(path) == bytes, "全部查询纯读")
	_check(sm.accept_elder_firewood(NEAR).created == false and FileAccess.get_file_as_bytes(path) == bytes, "重复接取不写盘")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.mark_active_quests_read().success and sm.data == before, "主动已读保存失败保留未读与全部内存")
	sm._active_save_path = path
	_check(sm.mark_active_quests_read().success and not sm.elder_firewood_state().unread, "主动读取事务")
	for wood in [11,12,15]:
		sm.data.inventory.wood = wood
		sm.data.quest_journal.instances.elder_firewood = {"status":"active", "unread":true}
		sm.data.elder_magic_backpack_unlocked = false
		var ingredient_before: Dictionary = sm.warehouse_snapshot()
		_check(sm.save(), "边界存档：" + str(wood))
		if wood == 11:
			_unchanged(func(): return sm.deliver_elder_firewood(NEAR), "11木材拒绝且全量不变")
			continue
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
		_unchanged(func(): return sm.deliver_elder_firewood(NEAR), "交付真实保存失败全量回滚：" + str(wood))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
		_check(sm.deliver_elder_firewood(NEAR).success and sm.elder_firewood_state().wood == wood-12, "交付精确扣12且余量保留：" + str(wood))
		for id in ["moondew_honey", "cooking_sake", "sour_vine_juice"]:
			_check(int(sm.warehouse_snapshot().get(id, 0)) == int(ingredient_before.get(id, 0)) + 3, "食材奖励直接进入仓库并精确叠加："+id)
		_check(sm.elder_backpack_unlocked() and sm.elder_firewood_state().status == "archived" and not sm.elder_firewood_state().unread, "解锁与归档同事务")
		_check(sm.quest_snapshot().active.all(func(q): return q.id != "elder_firewood") and sm.quest_snapshot().archived.any(func(q): return q.id == "elder_firewood"), "完成移出当前任务并留归档")
		_unchanged(func(): return sm.deliver_elder_firewood(NEAR), "重复交付零奖励")
		_unchanged(func(): return sm.accept_elder_firewood(NEAR), "归档不复活")
		sm.load_data()
		_check(sm.elder_backpack_unlocked() and sm.elder_firewood_state().wood == wood-12, "交付后重载一致")
		for id in ["moondew_honey", "cooking_sake", "sour_vine_juice"]:
			_check(int(sm.warehouse_snapshot().get(id, 0)) == int(ingredient_before.get(id, 0)) + 3, "读盘恢复仓库食材不重复发放："+id)
	# 坏值必须保留原始材料和奖励，拒绝业务而不补发。
	for bad in [-1,12.5,"15",true,NAN,INF,9007199254740992]:
		sm.data.inventory.wood = bad
		sm.data.quest_journal.instances.elder_firewood = {"status":"active", "unread":true}
		sm.data.elder_magic_backpack_unlocked = false
		var raw := JSON.stringify(sm.data)
		_check(not sm.deliver_elder_firewood(NEAR).success and JSON.stringify(sm.data) == raw and not sm.elder_backpack_unlocked(), "坏木材拒绝保留：" + str(bad))
	for bad in [1,"true",null,{},true]:
		sm.data.inventory.wood = 15
		sm.data.elder_magic_backpack_unlocked = bad
		var raw := JSON.stringify(sm.data)
		_check(not sm.deliver_elder_firewood(NEAR).success and JSON.stringify(sm.data) == raw and not sm.elder_backpack_unlocked(), "奖励非布尔/无归档凭证拒绝："+str(bad))
	sm.data.elder_magic_backpack_unlocked = false
	for bad in [null,{}, {"status":"active","unread":"yes"}, {"status":"archived","unread":false}]:
		sm.data.quest_journal.instances.elder_firewood = bad
		var raw := JSON.stringify(sm.data)
		_check(not sm.accept_elder_firewood(NEAR).success and not sm.deliver_elder_firewood(NEAR).success and JSON.stringify(sm.data) == raw, "坏实例拒绝不重接："+str(bad))
	for bad_journal in [null, {}, {"version":2,"instances":{}}, {"version":"1","instances":{}}, {"version":1,"instances":{"elder_firewood":{"status":"active","unread":"yes"}}}]:
		sm.data.inventory.wood = 15
		sm.data.elder_magic_backpack_unlocked = false
		sm.data.quest_journal = bad_journal
		_check(sm._write_atomic(path, sm.data), "建立原始坏日志文件")
		bytes = FileAccess.get_file_as_bytes(path)
		sm.load_data()
		var loaded := JSON.stringify(sm.data)
		_check(sm.data.quest_journal == JSON.parse_string(JSON.stringify(bad_journal)) and not sm.accept_elder_firewood(NEAR).success and not sm.deliver_elder_firewood(NEAR).success and JSON.stringify(sm.data) == loaded and FileAccess.get_file_as_bytes(path) == bytes, "坏日志跨读盘保留且拒绝："+str(bad_journal))
	sm.data.quest_journal = {"version":1,"instances":{"elder_firewood":{"status":"active","unread":true}}}
	for bad_reward in ["true",1,null]:
		sm.data.elder_magic_backpack_unlocked = bad_reward
		_check(sm._write_atomic(path, sm.data), "建立原始坏奖励文件")
		bytes = FileAccess.get_file_as_bytes(path)
		sm.load_data()
		_check(sm.data.elder_magic_backpack_unlocked == bad_reward and not sm.elder_backpack_unlocked() and not sm.deliver_elder_firewood(NEAR).success and FileAccess.get_file_as_bytes(path) == bytes, "坏奖励跨读盘严格布尔拒绝："+str(bad_reward))
	sm.data.elder_magic_backpack_unlocked = false
	sm.data.quest_journal = {"version":1,"instances":{"elder_firewood":{"status":"active","unread":true}}}
	# JSON 能表示的坏字段跨读盘不洗白；读取不写盘。
	for bad in [12.5,"15",true,-1]:
		sm.data.inventory.wood = bad
		sm.data.quest_journal.instances.elder_firewood = {"status":"active","unread":true}
		_check(sm.save(), "写入坏木材测试档")
		bytes = FileAccess.get_file_as_bytes(path)
		sm.load_data()
		_check(sm.data.inventory.wood == bad and not sm.deliver_elder_firewood(NEAR).success and FileAccess.get_file_as_bytes(path) == bytes, "坏字段读盘保留且纯读：" + str(bad))
	sm.data.inventory.wood = 15
	sm.data.erase("elder_magic_backpack_unlocked")
	sm.data.erase("quest_journal")
	_check(sm.save(), "建立无老者字段旧档")
	bytes = FileAccess.get_file_as_bytes(path)
	sm.load_data()
	_check(sm.elder_firewood_state().status == "inactive" and not sm.elder_backpack_unlocked() and sm.elder_firewood_state().wood == 15 and FileAccess.get_file_as_bytes(path) == bytes, "旧档未接取未解锁且不吞木材不写盘")
	_check(sm.accept_elder_firewood(NEAR).success, "旧档合法接入")
	_check(sm.quest_snapshot().active.any(func(q): return q.type == "exploration"), "原探索任务仍存在")
	_check(sm.quest_snapshot().archived.any(func(q): return q.type == "order"), "原订单归档保留")
	# 奖励库存损坏或无法精确累加时，不得扣木材或部分发奖。
	for bad in [-1, true, "3", 1.5, 9007199254740990]:
		_seed(15)
		_check(sm.accept_elder_firewood(NEAR).success, "奖励边界接取")
		sm.data.warehouse_stock = {"moondew_honey": 0, "cooking_sake": bad, "sour_vine_juice": 0}
		_check(sm.save(), "奖励边界落盘")
		_unchanged(func(): return sm.deliver_elder_firewood(NEAR), "非法食材库存拒绝且全量不变："+str(bad))

func _finish() -> void:
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()}, "\t"))
	print("ELDER_STATE ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)


