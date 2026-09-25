extends Node
## 所有输入投递至真实 Viewport；只在隔离 user:// 中构造存档与失败夹具。

var checks: Array[Dictionary] = []
var failures := 0
var sm: Node
var mode := ""
var screen: Control
var captures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _arg(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _check(passed: bool, description: String) -> void:
	checks.append({"passed": passed, "description": description})
	if not passed:
		failures += 1
		print("START01 FAIL: ", description)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _disk(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _run() -> void:
	var isolation := OS.get_environment("MAZE_START01_ROOT").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("START01 拒绝运行：user:// 未隔离")
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	mode = _arg("--mode=")
	if mode == "state":
		_state_suite()
	elif mode == "restart":
		_restart_suite()
	else:
		await _visual_suite()
	var report := {"checks": checks, "failures": failures, "mode": mode, "captures": captures,
		"user_dir": actual, "renderer": DisplayServer.get_name(), "active_path": sm.active_save_path()}
	_write(_arg("--report="), JSON.stringify(report, "\t"))
	print("START01 ", mode, " checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _state_suite() -> void:
	_check(sm.list_save_slots().slots.is_empty(), "空目录没有伪造存档")
	_write(sm.SAVE_PATH, '{"tutorial_done":true,"chapter_1_intro":"awakened","sentinel":42}')
	var legacy := _disk(sm.SAVE_PATH)
	_check(sm.load_save_slot(sm.SAVE_PATH).success and sm.is_prologue_done(), "旧 save.json 迁移并保留序章规则")
	_check(sm.data.sentinel == 42 and _disk(sm.SAVE_PATH) == legacy, "旧档未知字段保留且迁移读取不落盘")
	var first: Dictionary = sm.create_new_game()
	_check(first.success and not sm.is_prologue_done() and sm.lifecycle_stage() == "not_started", "新档从序章开始")
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "档 A 通过真实接单和取料")
	var a_disk := _disk(first.id)
	var second: Dictionary = sm.create_new_game()
	_check(second.success and first.id != second.id, "每次新建使用独立档")
	_check(sm.accept_first_order().success, "档 B 通过真实接单")
	var b_disk := _disk(second.id)
	_check(_disk(first.id) == a_disk and _disk(sm.SAVE_PATH) == legacy, "新建与自动保存未改旧档 A 和 legacy")
	_check(sm.load_save_slot(first.id).success and sm.lifecycle_stage() == "ingredients_collected", "选择档 A 恢复取料进度")
	_check(sm.cook_first_order().success and sm.lifecycle_stage() == "dish_ready", "当前档 A 继续真实烹饪并保存")
	_check(_disk(second.id) == b_disk, "档 A 自动保存不串写档 B")
	_check(sm.load_save_slot(second.id).success and sm.lifecycle_stage() == "order_accepted", "选择档 B 恢复接单进度")
	var before: Dictionary = sm.data.duplicate(true)
	var previous_path: String = sm.active_save_path()
	_write("user://saves/broken.json", "{invalid")
	_check(not sm.load_save_slot("user://saves/broken.json").success, "坏档返回读取失败")
	_check(sm.data == before and sm.active_save_path() == previous_path, "失败载入保留内存和活动档")
	_check(not sm.load_save_slot("user://saves/missing.json").success and sm.data == before, "消失的存档不当作新游戏")
	_check(not sm.load_save_slot("user://saves/../save.json").success, "拒绝越界存档路径")
	var temporary: String = second.id + ".tmp"
	DirAccess.make_dir_absolute(temporary)
	_check(not sm.claim_first_order_ingredients().success and sm.data == before and _disk(second.id) == b_disk, "保存失败事务完整回滚且旧档不变")
	DirAccess.remove_absolute(temporary)
	DirAccess.rename_absolute(sm.SLOTS_DIR, "user://saves-kept")
	_write(sm.SLOTS_DIR, "阻止创建目录")
	_check(not sm.create_new_game().success and sm.data == before and sm.active_save_path() == previous_path, "新建失败不切换内存或活动档")
	DirAccess.remove_absolute(sm.SLOTS_DIR)
	DirAccess.rename_absolute("user://saves-kept", sm.SLOTS_DIR)
	sm.begin_replay()
	_check(not sm.create_new_game().success and not sm.load_save_slot(first.id).success, "重播拒绝切换正式档")
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "重播副本可执行经营")
	_check(sm.data == before and _disk(second.id) == b_disk, "重播不污染正式内存和磁盘")
	sm.end_replay()
	_check(sm.active_save_path() == previous_path and sm.data == before, "退出重播仍对应原活动档")
	_write("user://restart_expect.json", JSON.stringify({"a": first.id, "b": second.id}))

func _restart_suite() -> void:
	var expected: Dictionary = JSON.parse_string(_disk("user://restart_expect.json"))
	_check(sm.list_save_slots().slots.size() == 4, "新进程发现两个新档、旧档及坏档")
	_check(sm.load_save_slot(expected.a).success and sm.lifecycle_stage() == "dish_ready", "重启后档 A 恢复烹饪结果")
	_check(sm.load_save_slot(expected.b).success and sm.lifecycle_stage() == "order_accepted", "重启后档 B 独立恢复接单进度")

func _click(control: Control) -> void:
	await get_tree().process_frame
	await _click_at(control.get_global_rect().get_center())

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(event, true)
		await get_tree().create_timer(0.05).timeout

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _arg("--output-dir=").path_join(mode + "-" + label + ".png")
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "截图 " + label)
	captures.append(path)

func _wait_scene(path: String) -> bool:
	for frame in 900:
		if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path == path:
			return true
		await get_tree().process_frame
	return false

func _visual_suite() -> void:
	_check(DisplayServer.get_name() != "headless", "真实渲染器运行")
	# 将观察器移至根节点，生产场景转场不会删除验收脚本。
	get_tree().current_scene = null
	var a := ""
	var b := ""
	if mode.contains("continue"):
		a = sm.create_new_game().id
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		sm.complete_prologue()
		b = sm.create_new_game().id
		sm.accept_first_order()
		sm.complete_prologue()
		_write("user://saves/broken.json", "{invalid")
	screen = load("res://scenes/start_screen.tscn").instantiate()
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	screen.save_modal._confirm_button.pressed.connect(func(): print("START01 confirm pressed; busy=", screen._busy, " selected=", screen.save_modal._selected))
	screen.save_modal._confirm_button.button_down.connect(func(): print("START01 confirm down"))
	screen.save_modal._confirm_button.button_up.connect(func(): print("START01 confirm up"))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().current_scene == screen, "旧档序章标记不会绕过封面")
	await _capture("cover")
	if mode.contains("failure"):
		await _failure_ui()
		return
	var before := JSON.stringify(sm.data)
	await _click(screen.continue_button)
	_check(screen.save_modal.visible, "真实点击继续游戏打开弹窗")
	await _capture("modal")
	var count: int = sm.list_save_slots().slots.size()
	await _click_at(screen.new_button.get_global_rect().get_center())
	_check(sm.list_save_slots().slots.size() == count and screen.save_modal.visible, "遮罩阻止底层新游戏点击")
	await _key(KEY_ESCAPE)
	_check(not screen.save_modal.visible and JSON.stringify(sm.data) == before, "Esc 取消不改变存档状态")
	await _click(screen.continue_button)
	await _click(screen.save_modal._cancel_button)
	_check(not screen.save_modal.visible and JSON.stringify(sm.data) == before, "取消按钮无副作用")
	await _click(screen.continue_button)
	await _click(screen.save_modal._close_button)
	_check(not screen.save_modal.visible, "关闭按钮可关闭弹窗")
	if mode.contains("new"):
		_check(count == 0, "无档时列表为空且载入禁用")
		await _key(KEY_TAB)
		_check(screen.new_button.has_focus(), "Tab 将焦点移动到新游戏")
		await _capture("focus")
		var hover := InputEventMouseMotion.new()
		hover.position = screen.new_button.get_global_rect().get_center()
		get_viewport().push_input(hover, true)
		await _capture("hover")
		var down := InputEventMouseButton.new()
		down.position = hover.position
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		get_viewport().push_input(down, true)
		await _capture("pressed")
		down.pressed = false
		down.position = Vector2(2, 2)
		get_viewport().push_input(down, true)
		var position: Vector2 = screen.new_button.get_global_rect().get_center()
		await _click_at(position)
		_check(await _wait_scene("res://scenes/prologue.tscn"), "真实点击新游戏进入既有序章")
		await _click_at(position)
		_check(sm.list_save_slots().slots.size() == 1, "连续点击只创建一份独立档")
		await get_tree().create_timer(1.0).timeout
		await _capture("prologue")
		await _key(KEY_ESCAPE)
	else:
		await _click(screen.continue_button)
		await _select_row("user://saves/broken.json")
		await _click(screen.save_modal._confirm_button)
		_check(screen.save_modal.visible and screen.save_modal._body_label.text.contains("损坏"), "坏档载入显示真实错误并留在弹窗")
		await _capture("broken")
		var target := b if mode.contains("continue-b") else a
		await _select_row(target)
		await _capture("selected")
		await _click(screen.save_modal._confirm_button)
		_check(sm.active_save_path() == target and sm.lifecycle_stage() == ("order_accepted" if target == b else "ingredients_collected"), "真实选择和载入恢复对应档案")
		_check(a != b, "测试档案相互独立")
	_check(await _wait_scene("res://scenes/restaurant_map_2d.tscn"), "按钮流程最终进入餐厅")
	await get_tree().create_timer(2.0).timeout
	await _capture("restaurant")

func _failure_ui() -> void:
	_write(sm.SAVE_PATH, '{"chapter_1_intro":"awakened","sentinel":"保留旧档"}')
	sm.load_save_slot(sm.SAVE_PATH)
	var before := JSON.stringify(sm.data)
	var disk := _disk(sm.SAVE_PATH)
	_write(sm.SLOTS_DIR, "占位，模拟目录无法创建")
	await _click(screen.new_button)
	_check(screen._error_modal.visible and get_tree().current_scene == screen, "新建保存失败仍留在封面并显示错误")
	_check(JSON.stringify(sm.data) == before and _disk(sm.SAVE_PATH) == disk, "界面保存失败不破坏旧档与内存")
	await _capture("save-failed")
	await _key(KEY_ESCAPE)
	await _click(screen.continue_button)
	_check(screen.save_modal._body_label.text.contains("无法读取"), "目录读取失败显示真实提示")
	await _capture("read-failed")
	await _key(KEY_ESCAPE)
	DirAccess.remove_absolute(sm.SLOTS_DIR)
	await _key(KEY_ENTER)
	_check(screen.save_modal.visible, "键盘 Enter 打开继续游戏弹窗")
	await _key(KEY_ESCAPE)

func _select_row(path: String) -> void:
	var modal = screen.save_modal
	var index: int = modal._slots.find(modal._slots.filter(func(slot): return slot.id == path)[0])
	var rows: Array = modal.slot_list._items_box.get_children().filter(func(child): return child is SproutButton and not child.is_queued_for_deletion())
	await _click(rows[index])
