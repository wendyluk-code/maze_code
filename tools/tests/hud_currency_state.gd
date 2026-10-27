extends "res://tools/tests/ch2_chest_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_chest_state()
		_currency_state()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _currency_state() -> void:
	_completed()
	_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success, "金币资格测试建立真实前置")
	var path: String = sm.active_save_path()
	sm.data.erase("gold")
	sm.data.erase("claimed_chests")
	_check(sm.save(), "无金币字段旧档落盘")
	var bytes := FileAccess.get_file_as_bytes(path)
	sm.load_data()
	_check(not sm.is_gold_display_unlocked() and sm.gold_balance() == 0, "缺字段未获币旧档不解锁")
	_check(FileAccess.get_file_as_bytes(path) == bytes, "资格查询不改旧档字节")
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	_check(not sm.claim_exploration_chest(Chests.all()[0].id, STANDS[0]).success and not sm.is_gold_display_unlocked(), "真实保存失败不解锁")
	DirAccess.remove_absolute(path + ".tmp")
	_check(sm.claim_exploration_chest(Chests.all()[0].id, STANDS[0]).success and sm.is_gold_display_unlocked(), "真实开箱成功才解锁")
	bytes = FileAccess.get_file_as_bytes(path)
	_check(not sm.claim_exploration_chest(Chests.all()[0].id, STANDS[0]).success and sm.gold_balance() == 100 and FileAccess.get_file_as_bytes(path) == bytes, "重复领取不加钱不写盘")
	sm.data.gold = 0
	_check(sm.save(), "等价消费夹具保存零余额并保留领取凭证")
	sm.load_data()
	_check(sm.gold_balance() == 0 and sm.is_gold_display_unlocked(), "获币后归零重载仍解锁")
	var prior := "user://saves/hud-zero.json"
	DirAccess.make_dir_recursive_absolute("user://saves")
	_check(sm._write_atomic(prior, sm.data), "建立合法零余额旧槽")
	_check(sm.create_new_game().success and not sm.is_gold_display_unlocked(), "新档不串显示资格")
	_check(sm.load_save_slot(prior).success and sm.is_gold_display_unlocked() and sm.gold_balance() == 0, "切回旧档恢复零余额资格")
	var valid: Dictionary = sm.data.duplicate(true)
	for probe in [{"gold":25}, {"claimed_chests":["future_chest"]}]:
		sm.data = valid.duplicate(true)
		sm.data.erase("gold")
		sm.data.erase("claimed_chests")
		sm.data.merge(probe, true)
		_check(sm.save(), "历史金币或凭证单独落盘")
		bytes = FileAccess.get_file_as_bytes(sm.active_save_path())
		sm.load_data()
		_check(sm.is_gold_display_unlocked() and FileAccess.get_file_as_bytes(sm.active_save_path()) == bytes, "合法历史金币或凭证只读恢复")
	for bad in [-1, 0.5, "100", INF]:
		sm.data = valid.duplicate(true)
		sm.data.gold = bad
		var before: Dictionary = sm.data.duplicate(true)
		_check(not sm.is_gold_display_unlocked() and sm.data == before, "坏金币不解锁不静默修复：" + str(bad))
	for bad in [{}, [null], [3], [""]]:
		sm.data = valid.duplicate(true)
		sm.data.claimed_chests = bad
		var before: Dictionary = sm.data.duplicate(true)
		_check(not sm.is_gold_display_unlocked() and sm.data == before, "坏凭证不解锁不静默修复")
	sm.data = valid
	_check(not sm.migration_diagnostics.is_empty(), "坏数据仍保留诊断")
