extends "res://tools/tests/ch1_07_cooking_suite.gd"
## 所有场景与输入均使用生产组件；阶段检查点通过独立进程恢复。

const EXPECTED_DIALOGUE := [
	["？？？", "……缓过来了。"],
	["？？？", "这是岩鬃兽的肉？那东西又硬又腥，你居然能做成这样。"],
	["芽芽", "他以前做得更好。"], ["主角", "以前？"], ["芽芽", "……嗯。"],
	["？？？", "还能再来一份吗？"], ["芽芽", "再去仓库看看吧。"],
	["？？？", "迷宫浅层，旧盐池附近，我就是从那边回来的。"],
	["？？？", "我叫铁山，是个冒险者。"], ["铁山", "你如果要去，我可以带路。"],
	["芽芽", "……不行。"], ["芽芽", "你才刚醒，连自己是谁都不记得。"],
	["主角", "可我还记得怎么做饭，我想继续做下去。"], ["主角", "没有食材，就做不了下一顿。"],
	["芽芽", "……那我也去。"], ["芽芽", "谁都不许往深处走。"], ["铁山", "说定了。拿够食材就回来。"],
]

func _run() -> void:
	var isolation := _arg("--isolation-root=").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if OS.get_environment("MAZE_CH1_09_ISOLATED") != "1" or isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("拒绝运行：存档目录未隔离")
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	mode = _arg("--mode=")
	await _wrapup_run()
	var report := {"ticket": "CH1-09", "mode": mode, "checks": checks, "failures": failures,
		"state": sm.data, "idx": tm.idx}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CH1_09 ", mode, " checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _wrapup_run() -> void:
	if mode == "warehouse":
		sm.data = sm._defaults()
		_check(sm.save(), "建立隔离默认存档")
		_reject_advance("relief", "not_settled_or_not_empty", "未交付不能收束")
		_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success
			and sm.cook_first_order().success and sm.deliver_first_order().success, "通过真实事务准备已结算首单")
		var before: Dictionary = sm.data.duplicate(true)
		sm.data.inventory.rock_salt = 1
		_reject_advance("relief", "not_settled_or_not_empty", "非空库存拒绝准备态")
		sm.data = before
		_reject_advance("agreement", "wrong_step", "乱序不能加入队伍")
		var actual_dialogue: Array = []
		for step in tm.departure_lesson():
			if step.type == "dialog":
				actual_dialogue.append([step.speaker, step.lines[0]])
		_check(actual_dialogue == EXPECTED_DIALOGUE, "阶段7全部精确对白与说话人顺序")
		await _start_scene()
		_check(tm.idx == 16 and tm.current_stage == 7, "真实结算恢复阶段7第一句")
		await _capture("relief")
		# 确认第一句后重建场景，应仅继续下一句。
		await _finish_dialogue()
		await _reenter()
		_check(_step() == "meat" and sm.departure_state().step == "meat", "重进不重复已经确认的第一句")
		while tm.active and tm.steps[tm.idx].type == "dialog":
			_check(not sm.departure_state().tieshan_name_revealed, "自报姓名前保持未知")
			await _finish_dialogue()
		_check(_step() == "warehouse_move", "对白后引导真实仓库移动")
		await _walk_to("Store", 24)
		await _warehouse_negative_checks()
		_press_e()
		var modal := scene.get_node("UIOverlay/WarehouseModal")
		_check(modal.visible and modal._empty_stock and modal._message.text == "没有任何食物", "E打开同一仓库的空库存界面")
		_check(modal._meat_slot.text == "岩鬃肉\n×0" and modal._salt_slot.text == "岩盐\n×0"
			and modal._meat_slot.disabled and modal._salt_slot.disabled, "真实库存数量0且不可选择")
		before = sm.data.duplicate(true)
		for i in 5:
			_press_e()
			player.interacted.emit(scene.get_node("InteractPoints/Store"))
			modal._on_claim_pressed()
		_check(sm.data == before and _step() == "warehouse_inspect", "重复E和领取不补发、不提前推进")
		await _capture("empty-warehouse")
		# 新增空仓库模态的取消边界；不覆盖CH1-11全章节跳过/重播矩阵。
		tm.skip_all()
		_check(not modal.visible and not player.input_locked and not sm.is_chapter_1_done(), "跳过当前空仓库时关闭模态且不标记完成")
		await _reenter()
		_check(_step() == "warehouse_inspect", "空仓库跳过后重进仍恢复未确认检查点")
	elif mode == "map":
		await _start_scene()
		_check(_step() == "warehouse_inspect", "独立进程恢复待检查仓库而非开场")
		await _walk_to("Store", 24)
		_press_e()
		var modal := scene.get_node("UIOverlay/WarehouseModal")
		modal._on_cancel_pressed()
		_check(sm.departure_state().empty_warehouse_checked and _step() == "salt_pool", "确认空仓库后才进入地图线索")
		# 线索对白结束时制造单次保存失败，不能解锁地图或丢失检查点。
		var temporary := ProjectSettings.globalize_path("user://save.json.tmp")
		_check(DirAccess.make_dir_absolute(temporary) == OK, "建立阶段保存失败夹具")
		var before: Dictionary = sm.data.duplicate(true)
		var disk := _disk()
		await _finish_dialogue(false)
		_check(sm.data == before and _disk() == disk and _step() == "salt_pool", "地图解锁写盘失败时完整回滚")
		_check(DirAccess.remove_absolute(temporary) == OK, "移除保存失败夹具")
		await _finish_dialogue()
		await get_tree().process_frame
		_assert_map()
		_check(scene.get_node("UIOverlay/DeparturePanel")._open and _step() == "map_review", "线索后打开最小地图状态面板")
		_check(sm.departure_state().party.is_empty() and not sm.departure_state().entrance_lit, "地图已解锁时仍未提前加入队伍或点亮入口")
		await _capture("map-unlocked")
		tm.skip_all()
		_check(not scene.get_node("UIOverlay/DeparturePanel")._open and not player.input_locked
			and not sm.is_tutorial_done(), "跳过地图确认时释放模态与输入，不写完成标记")
		await _reenter()
		await get_tree().process_frame
		_check(_step() == "map_review" and scene.get_node("UIOverlay/DeparturePanel")._open, "地图模态跳过后重进恢复检查点")
	elif mode == "decide":
		await _start_scene()
		await get_tree().process_frame
		_assert_map()
		_check(_step() == "map_review" and scene.get_node("UIOverlay/DeparturePanel")._open, "独立进程恢复地图确认面板，不重复线索对白")
		scene.get_node("UIOverlay/DeparturePanel").close_map()
		_check(_step() == "introduction" and not sm.departure_state().tieshan_name_revealed, "自报姓名句仍显示问号")
		await _finish_dialogue()
		_check(_step() == "offer" and sm.departure_state().tieshan_name_revealed and tm.steps[tm.idx].speaker == "铁山", "自报姓名确认后改用铁山")
		await _reenter()
		_check(_step() == "offer", "重进不重复自报姓名或地图解锁")
		while tm.active and tm.steps[tm.idx].type == "dialog":
			await _finish_dialogue()
		await get_tree().process_frame
		_assert_ready()
		await _capture("ready")
	elif mode in ["resume", "resume_again"]:
		await _start_scene()
		_assert_ready()
		var before: Dictionary = sm.data.duplicate(true)
		var disk := _disk()
		tm.start()
		_check(not tm.active and sm.data == before and _disk() == disk, "准备态显式启动守卫不会从第一阶段重播")
		var entrance := scene.get_node("DepartureEntrance") as Node2D
		player.global_position = _stand(entrance)
		await get_tree().process_frame
		_check(entrance.lit and entrance.is_in_group("interactable"), "真实左侧门亮起且可查询")
		_press_e()
		_check(scene.get_node("UIOverlay/DeparturePanel")._open and get_tree().current_scene == scene, "入口E展示状态且不切换到迷宫")
		await _capture("entrance-map")
		scene.get_node("UIOverlay/DeparturePanel").close_map()
		_check(not player.input_locked and player.is_physics_processing(), "地图关闭恢复原输入")
		_check(sm.data == before and _disk() == disk, "重复查看地图不改持久化状态")
		await _capture("entrance-lit")
		await _reenter()
		_assert_ready()
	else:
		_check(false, "未知验收模式")

func _warehouse_negative_checks() -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	var store := scene.get_node("InteractPoints/Store")
	player.interacted.emit(scene.get_node("InteractPoints/Register"))
	var stand: Vector2 = player.global_position
	player.global_position = Vector2(-10000, -10000)
	_press_e()
	player.interacted.emit(store)
	_check(sm.data == before and _disk() == disk and _step() == "warehouse_inspect"
		and not scene.get_node("UIOverlay/WarehouseModal").visible, "错目标、超距输入和信号不打开仓库、不推进")
	player.global_position = stand
	player.last_valid = stand

func _finish_dialogue(expect_advance := true) -> void:
	var current: int = tm.idx
	_check(tm.steps[current].type == "dialog" and guide.dialog.visible, "播放真实对白 " + _step())
	# 真实组件先补完打字，再确认单句；无需直接发完成信号。
	guide.dialog._advance()
	if tm.idx == current:
		guide.dialog._advance()
	await get_tree().process_frame
	if expect_advance:
		_check(not tm.active or tm.idx != current, "确认对白推进并保存")

func _reenter() -> void:
	scene.queue_free()
	await get_tree().process_frame
	await _start_scene()

func _step() -> String:
	return str(tm.steps[tm.idx].get("wrapup_id", "")) if tm.active else "inactive"

func _assert_map() -> void:
	var map: Dictionary = sm.departure_state().map
	_check(map.unlocked_floors == [1] and map.visible_regions == ["old_salt_pool"] and map.other_regions == "fog", "仅第一层和旧盐池可见，其余迷雾")

func _assert_ready() -> void:
	_assert_map()
	var state: Dictionary = sm.departure_state()
	_check(sm.is_ready_to_depart() and state.step == "ready_to_depart" and not tm.active, "准备态稳定且引导停止")
	_check(state.party == ["yaya", "tieshan"] and state.entrance_lit and state.objective == "与芽芽、铁山一同进入迷宫浅层", "队伍、入口和精确目标持久化")
	_check(state.cards == {"status": "pending_content", "unlocked": false, "card_ids": []}, "卡牌待提供且未解锁，没有伪造卡牌")
	_check(not sm.is_chapter_1_done() and not sm.is_tutorial_done(), "CH1-10/11未完成时两个完成标记均为false")
	_check(sm.can_start_departure() and sm.reputation() == 20 and not sm.has_active_order(), "首单结算与零库存保持不变")
	_check(not guide.should_start_chapter_1() and not guide.visible and not player.input_locked, "入口守卫隐藏引导并解除玩家锁定")
	var before: Dictionary = sm.data.duplicate(true)
	_check(not sm.claim_first_order_ingredients().success and not sm.deliver_first_order().success and sm.data == before,
		"准备态重复领取/交付不重复经营事务")

func _reject_advance(step: String, reason: String, label: String) -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var disk := _disk()
	var result: Dictionary = sm.advance_departure(step)
	_check(not result.success and result.reason == reason and sm.data == before and _disk() == disk, label)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := _arg("--output-dir=").path_join("CH1-09-" + mode + "-" + label + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "保存实际界面 " + label, {"path": path})
