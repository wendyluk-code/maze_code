extends "res://tools/tests/ch2_entry_state.gd"
const Chests := preload("res://data/maze/entry_chests.gd")
const STANDS := [Vector2(725,369), Vector2(413,646), Vector2(745,642), Vector2(1060,636), Vector2(795,1170)]

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_chest_state()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("CH2_CHEST_STATE ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _chest_state() -> void:
	_completed()
	_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success, "建立真实迷宫前置")
	sm.data["future_unknown"] = {"keep": [1,2,3]}
	sm.data.erase("gold")
	sm.data.erase("claimed_chests")
	_check(sm.save(), "写入无金币与宝箱字段旧档")
	var path: String = sm.active_save_path()
	var old_bytes := FileAccess.get_file_as_bytes(path)
	sm.load_data()
	_check(sm.gold_balance() == 0 and sm.data.claimed_chests == [], "旧档缺字段默认金币0且全部未领取")
	_check(FileAccess.get_file_as_bytes(path) == old_bytes, "迁移只读不写旧档")
	_check(sm.data.future_unknown.keep.size() == 3 and int(sm.data.future_unknown.keep[0]) == 1 and int(sm.data.future_unknown.keep[1]) == 2 and int(sm.data.future_unknown.keep[2]) == 3 and sm.can_enter_maze(), "保留未知字段与原章进度")
	var baseline: Dictionary = sm.data.duplicate(true)
	_check(not sm.claim_exploration_chest("not_a_chest", STANDS[0]).success and sm.data == baseline, "拒绝未知ID不改状态")
	_check(not sm.claim_exploration_chest(Chests.all()[0].id, Roads.SPAWN).success and sm.data == baseline, "远处不能开箱")
	_check(not sm.claim_exploration_chest(Chests.all()[0].id, Vector2(650,530)).success, "非法路面不能开箱")
	# 在正式隔离文件的临时路径建立目录，真实触发写入失败，不模拟成功返回。
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	_check(not sm.claim_exploration_chest(Chests.all()[0].id, STANDS[0]).success and sm.data == baseline, "真实文件写入失败全量回滚")
	_check(FileAccess.get_file_as_bytes(path) == old_bytes, "保存失败原文件字节不变")
	DirAccess.remove_absolute(path + ".tmp")
	for i in Chests.all().size():
		var chest: Dictionary = Chests.all()[i]
		_check(Roads.is_walkable(STANDS[i]) and STANDS[i].distance_to(chest.position) <= Chests.INTERACT_RADIUS, "合法道路可开箱：" + chest.id)
		var result: Dictionary = sm.claim_exploration_chest(chest.id, STANDS[i])
		_check(result.success and result.amount == 100 and sm.gold_balance() == (i+1)*100, "领取并精确加100：" + chest.id)
		var bytes := FileAccess.get_file_as_bytes(path)
		var snapshot: Dictionary = sm.data.duplicate(true)
		_check(not sm.claim_exploration_chest(chest.id, STANDS[i]).success and sm.data == snapshot and FileAccess.get_file_as_bytes(path) == bytes, "重复领取不写盘不发奖：" + chest.id)
		sm.load_data()
		_check(sm.is_chest_claimed(chest.id) and sm.gold_balance() == (i+1)*100, "重载领取ID和金币一致：" + chest.id)
	_check(sm.gold_balance() == 500 and sm.data.claimed_chests.size() == 5, "五箱合计500")
	_check(sm.data.future_unknown == baseline.future_unknown and sm.reputation() == baseline.reputation and sm.quest_snapshot().active.any(func(q): return q.id == "chapter_1_salt_pool") and not sm.data.get("chapter_2_done",false), "不影响未知字段、声望、盐池任务或章节")
	var completed: Dictionary = sm.data.duplicate(true)
	_check(sm.record_maze_location("restaurant", STANDS[4]).success and sm.record_maze_location("maze_entry", Roads.SPAWN).success, "返回再入保留金币和领取记录")
	_check(sm.gold_balance() == 500 and sm.data.claimed_chests == completed.claimed_chests, "跨区域不刷新宝箱")
	var original_path: String = sm.active_save_path()
	# 创建新档是真实独立路径；旧测试档迁到合法槽用于切换验证。
	DirAccess.make_dir_recursive_absolute("user://saves")
	var prior_slot := "user://saves/chest-old.json"
	_check(sm._write_atomic(prior_slot, sm.data), "准备旧存档槽")
	var old_slot_bytes := FileAccess.get_file_as_bytes(prior_slot)
	var new_game: Dictionary = sm.create_new_game()
	_check(new_game.success and sm.active_save_path() != original_path and sm.gold_balance() == 0 and sm.data.claimed_chests == [], "新游戏独立从0开始")
	_check(FileAccess.get_file_as_bytes(prior_slot) == old_slot_bytes, "新游戏不改旧档")
	_check(sm.load_save_slot(prior_slot).success and sm.gold_balance() == 500 and sm.data.claimed_chests.size() == 5, "切回旧档仍500且五箱已领")
	# 新版本未知ID保留；非法状态拒绝增奖，不静默清空既有领取记录。
	sm.data.claimed_chests.append("future_region_chest")
	_check(sm.save(), "未知宝箱记录保存")
	sm.load_data()
	_check(sm.is_chest_claimed("future_region_chest"), "未知宝箱ID读档保留")
	for bad in [-1, 0.5, "100", INF, 9007199254740992]:
		sm.data.gold = bad
		_check(not sm.chest_reward_state_valid(), "非法金币阻止发奖：" + str(bad))
	sm.data.gold = 0
	for bad in [{}, [null], [3], [""]]:
		sm.data.claimed_chests = bad
		_check(not sm.chest_reward_state_valid(), "损坏领取记录阻止发奖")
	sm.data = completed
	sm.begin_replay()
	_check(not sm.claim_exploration_chest(Chests.all()[0].id, STANDS[0]).success, "重播不能领取正式金币")
	sm.end_replay()
