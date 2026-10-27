extends "res://tools/tests/ch2_entry_state.gd"
const Sites := preload("res://data/maze/entry_dig_sites.gd")
const STANDS := [Vector2(933,269), Vector2(982,596), Vector2(799,888), Vector2(918,1208)]

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_dig_state()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("CH2_DIG_STATE ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _dig_state() -> void:
	_completed()
	_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success, "真实迷宫前置")
	sm.data.erase("claimed_dig_sites")
	sm.data.inventory.erase("wood")
	sm.data.future_unknown = {"keep": true}
	_check(sm.save(), "旧档缺采集字段")
	var path: String = sm.active_save_path()
	var bytes := FileAccess.get_file_as_bytes(path)
	sm.load_data()
	_check(sm.dig_reward_state_valid() and sm.inventory_quantity("wood") == 0 and sm.data.claimed_dig_sites == [], "旧档默认四处未领且木材零")
	_check(FileAccess.get_file_as_bytes(path) == bytes, "迁移只读不发奖")
	var before: Dictionary = sm.data.duplicate(true)
	for probe in [["unknown", STANDS[0]], [Sites.all()[0].id, Roads.SPAWN], [Sites.all()[0].id, Vector2(369,629)]]:
		_check(not sm.claim_exploration_dig_site(probe[0], probe[1]).success and sm.data == before, "拒绝未知点、远距离或非法路面")
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	_check(not sm.claim_exploration_dig_site(Sites.all()[0].id, STANDS[0]).success and sm.data == before, "真实保存失败全量回滚木材和标记")
	_check(FileAccess.get_file_as_bytes(path) == bytes, "失败不损坏原存档")
	DirAccess.remove_absolute(path + ".tmp")
	for i in Sites.all().size():
		var site: Dictionary = Sites.all()[i]
		_check(Roads.is_walkable(STANDS[i]) and STANDS[i].distance_to(site.position) <= Sites.INTERACT_RADIUS, "合法路面可达：" + site.id)
		var result: Dictionary = sm.claim_exploration_dig_site(site.id, STANDS[i])
		_check(result.success and result.amount == 3 and sm.inventory_quantity("wood") == (i+1)*3, "每点精确木材×3：" + site.id)
		bytes = FileAccess.get_file_as_bytes(path)
		var snapshot: Dictionary = sm.data.duplicate(true)
		_check(not sm.claim_exploration_dig_site(site.id, STANDS[i]).success and sm.data == snapshot and FileAccess.get_file_as_bytes(path) == bytes, "重复不发奖不写盘：" + site.id)
		sm.load_data()
		_check(sm.is_dig_site_claimed(site.id) and sm.inventory_quantity("wood") == (i+1)*3, "读档同步库存和领取：" + site.id)
	_check(sm.inventory_quantity("wood") == 12 and sm.data.claimed_dig_sites.size() == 4, "四处合计12木材")
	_check(sm.gold_balance() == before.gold and sm.data.claimed_chests == before.claimed_chests and sm.reputation() == before.reputation and sm.data.future_unknown == before.future_unknown and not sm.data.get("chapter_2_done", false), "不影响宝箱、声望、未知字段或章节")
	_check(sm.record_maze_location("restaurant", STANDS[3]).success and sm.record_maze_location("maze_entry", Roads.SPAWN).success and sm.inventory_quantity("wood") == 12, "往返不刷新木材")
	DirAccess.make_dir_recursive_absolute("user://saves")
	var slot := "user://saves/dig-old.json"
	_check(sm._write_atomic(slot, sm.data), "保存独立旧槽")
	var old_bytes := FileAccess.get_file_as_bytes(slot)
	_check(sm.create_new_game().success and sm.inventory_quantity("wood") == 0 and sm.data.claimed_dig_sites == [], "新档四处独立可领")
	_check(FileAccess.get_file_as_bytes(slot) == old_bytes, "新档不动旧档")
	_check(sm.load_save_slot(slot).success and sm.inventory_quantity("wood") == 12 and sm.data.claimed_dig_sites.size() == 4, "切档恢复12木材与四处标记")
	sm.data.claimed_dig_sites.append("future_site")
	_check(sm.save(), "保存未知领取ID")
	sm.load_data()
	_check(sm.is_dig_site_claimed("future_site"), "未知ID读档保留")
	var completed: Dictionary = sm.data.duplicate(true)
	for bad in [-1, 0.5, "3", INF, 9007199254740992]:
		sm.data.inventory.wood = bad
		_check(not sm.dig_reward_state_valid() and not sm.claim_exploration_dig_site(Sites.all()[0].id, STANDS[0]).success, "非法木材阻止发奖：" + str(bad))
	sm.data.inventory.wood = 0
	for bad in [{}, [null], [3], [""]]:
		sm.data.claimed_dig_sites = bad
		_check(not sm.dig_reward_state_valid(), "损坏记录不静默重置")
	sm.data = completed
	sm.data.claimed_dig_sites = []
	sm.data.inventory.wood = 9007199254740990
	_check(not sm.claim_exploration_dig_site(Sites.all()[0].id, STANDS[0]).success, "溢出前拒绝奖励")
	sm.data = completed.duplicate(true)
	sm.begin_replay()
	_check(not sm.claim_exploration_dig_site(Sites.all()[0].id, STANDS[0]).success, "重播不领取")
	sm.end_replay()
