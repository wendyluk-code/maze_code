extends SceneTree
## 隔离存档中的正式餐厅对白回放；视口事件来自引擎，不依赖系统键鼠。

const SCENE := "res://scenes/restaurant_map_2d.tscn"
const PORTRAITS := {
	"你": "res://assets/characters/player_portrait.png",
	"芽芽": "res://assets/characters/yaya_portrait.png",
	"？？？": "res://assets/characters/tieshan/tieshan_portrait.png",
	"铁山": "res://assets/characters/tieshan/tieshan_portrait.png",
}

var sm
var tm
var scene: Node2D
var guide: Control
var output_dir := ""
var checks: Array = []
var failures: Array[String] = []
var checkpoints := {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	output_dir = _arg("--output-dir=")
	var isolation := _arg("--isolation-root=").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if output_dir.is_empty() or isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("CH1-DIALOG-02 拒绝运行：输出目录或隔离存档不符合要求")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	sm = root.get_node("SaveManager")
	tm = root.get_node("TutorialManager")
	_audit_lesson()
	sm.data = sm._defaults()
	_check("建立隔离存档", sm.save())
	_check("真实首单准备", sm.accept_first_order().success
		and sm.claim_first_order_ingredients().success
		and sm.cook_first_order().success
		and sm.deliver_first_order().success)
	_check("首单已结算且库存清空", sm.can_start_departure())
	await _load_scene()
	_check("从首单结算恢复阶段7", _step() == "relief" and tm.current_stage == 7)
	while tm.active and _step() != "warehouse_move":
		var id := _step()
		if not await _finish_dialog(id, KEY_SPACE, id in ["relief", "yaya_past", "hero_past"]):
			break
	if _step() == "warehouse_move":
		var store := scene.get_node("InteractPoints/Store") as Node2D
		var player := scene.get_node("Player") as CharacterBody2D
		player.global_position = _stand_near(store, player)
		player.last_valid = player.global_position
		await _wait_for_step("warehouse_inspect", 120)
		_check("真实移动到仓库检查", _step() == "warehouse_inspect"
			and player.nearest_interactable() == store,
			{"step": _step(), "player": player.global_position, "store": store.global_position,
			"nearest": str(player.nearest_interactable())})
		await _send_key(KEY_E)
		var modal := scene.get_node("UIOverlay/WarehouseModal")
		_check("E打开真实空仓库", modal.visible and modal._empty_stock)
		await _capture("warehouse_empty")
		await _click(modal._cancel_button)
		_check("关仓库后第一句未被点击吞掉", not modal.visible and _step() == "yaya_empty"
			and guide.dialog.visible and guide.dialog.speaker_name.text == "芽芽")
		await _finish_dialog("yaya_empty", KEY_SPACE, true, true)
		_check("芽芽后接主角追问", _step() == "hero_where")
		await _reload_scene()
		_check("追问读档称呼头像一致", _step() == "hero_where"
			and _dialog_identity_ok("hero_where"))
		await _finish_dialog("hero_where", KEY_E, true)
		_check("追问后才到旧盐池回答", _step() == "salt_pool")
		checkpoints["salt_pool"] = sm.data.duplicate(true)
		await _finish_dialog("salt_pool", KEY_SPACE, true)
		await process_frame
		await process_frame
		var panel := scene.get_node("UIOverlay/DeparturePanel")
		_check("回答后才开地图", _step() == "map_review" and panel._open)
		panel.close_map()
		await process_frame
		_check("自报句立即显示铁山", _step() == "introduction" and _dialog_identity_ok("introduction")
			and guide.dialog.speaker_name.text == "铁山")
		await _finish_dialog("introduction", KEY_SPACE, true)
		_check("合并自报和带路后直接接芽芽反对", _step() == "no" and _dialog_identity_ok("no"))
		while tm.active and _step() != "ready_to_depart":
			var id := _step()
			if id == "agreement":
				checkpoints["agreement"] = sm.data.duplicate(true)
			if id == "yaya_ready":
				_check("同行解锁后才播放最终芽芽句", sm.departure_state().party == ["yaya", "tieshan"]
					and sm.departure_state().entrance_lit and not sm.is_ready_to_depart())
				await _reload_scene()
				_check("最终芽芽句读档不丢失", _step() == "yaya_ready" and _dialog_identity_ok(id))
			if not await _finish_dialog(id, KEY_E, id in ["no", "cooking", "yaya_join", "agreement", "yaya_ready"]):
				break
		await process_frame
		await process_frame
		_check("最终一句确认后进入入队卡牌", tm.active and sm.is_ready_to_depart()
			and not sm.is_chapter_1_done() and is_instance_valid(tm._chapter_outro)
			and tm._chapter_outro.phase == "party")
		await _verify_legacy_checkpoints()
	_test_missing_portrait_reset()
	_write_report()
	quit(0 if failures.is_empty() else 1)

func _audit_lesson() -> void:
	var steps: Array = tm.chapter_1_lesson()
	var dialogues := 0
	var lines := 0
	var ids: Array[String] = []
	for step in steps:
		if step.get("type", "") != "dialog":
			continue
		dialogues += 1
		lines += step.get("lines", []).size()
		var speaker := str(step.get("speaker", ""))
		var path := str(step.get("portrait", ""))
		_check("对白数据头像 %s %s" % [str(step.get("wrapup_id", "stage_" + str(step.get("stage", 0)))), speaker],
			PORTRAITS.has(speaker) and path == PORTRAITS[speaker] and load(path) is Texture2D)
		if step.has("wrapup_id"):
			ids.append(str(step.wrapup_id))
	_check("正式和兼容入口完整", steps == tm.restaurant_lesson())
	_check("对白数和文本行数", dialogues == 21 and lines == 22)
	_check("缺句和终句检查点顺序", ids.find("warehouse_inspect") == -1
		and ids.find("yaya_empty") + 1 == ids.find("hero_where")
		and ids.find("hero_where") + 1 == ids.find("salt_pool")
		and ids.find("agreement") + 1 == ids.find("yaya_ready"))
	_check("自报姓名当句称铁山", steps.filter(func(step): return step.get("wrapup_id", "") == "introduction")[0].speaker == "铁山")
	for retired in ["offer", "memory", "ingredients", "stay_shallow"]:
		_check("已合并句不再单独展示 " + retired, not ids.has(retired))
	_check("三档顾客评价是系统提示", tm._quality_feedback(1, 60) != tm._quality_feedback(2, 80)
		and tm._quality_feedback(2, 80) != tm._quality_feedback(3, 100))

func _load_scene() -> void:
	change_scene_to_file(SCENE)
	await scene_changed
	await process_frame
	await process_frame
	scene = current_scene as Node2D
	guide = scene.get_node("UIOverlay/TutorialGuide")

func _reload_scene() -> void:
	tm._cancel_current_run()
	scene.queue_free()
	await process_frame
	sm.load_data()
	await _load_scene()

func _dialog_identity_ok(expected_id: String) -> bool:
	if _step() != expected_id or not guide.dialog.visible:
		return false
	var step: Dictionary = tm.steps[tm.idx]
	var dialog = guide.dialog
	var path := str(step.get("portrait", ""))
	return dialog.speaker_name.text == str(step.speaker) and dialog.speaker_name.visible \
		and dialog.portrait.visible and dialog.portrait_texture.visible \
		and not dialog.portrait_fallback.visible \
		and dialog.portrait_texture.texture == load(path)

func _finish_dialog(expected_id: String, key: Key, capture: bool, mouse := false) -> bool:
	var initial: int = tm.idx
	var valid := _dialog_identity_ok(expected_id)
	_check("实际姓名头像 %s" % expected_id, valid)
	if not valid:
		return false
	var line := str(tm.steps[tm.idx].lines[0])
	if guide.dialog.dialog_text.text != line:
		if mouse:
			await _click(guide.dialog)
		else:
			await _send_key(key)
		_check("首次输入只补全文字 %s" % expected_id,
			tm.idx == initial and guide.dialog.dialog_text.text == line)
	else:
		_check("打字已自然完成 %s" % expected_id, true)
	if capture:
		await _capture(expected_id)
	if mouse:
		await _click(guide.dialog)
	else:
		await _send_key(key)
	_check("再次输入推进且保存 %s" % expected_id, not tm.active or tm.idx != initial)
	return not tm.active or tm.idx != initial

func _verify_legacy_checkpoints() -> void:
	var done: Dictionary = sm.data.duplicate(true)
	for id in ["salt_pool", "agreement"]:
		if not checkpoints.has(id):
			_check("旧检查点快照存在 " + id, false)
			continue
		sm.data = checkpoints[id].duplicate(true)
		_check("旧检查点保存 " + id, sm.save())
		await _reload_scene()
		_check("旧检查点读档不回退 " + id, _step() == id and sm.departure_state().step == id
			and _dialog_identity_ok(id))
	for old_id in {"offer": "no", "memory": "cooking", "ingredients": "yaya_join", "stay_shallow": "agreement"}:
		sm.data = checkpoints["agreement"].duplicate(true)
		sm.data.chapter_1_departure.step = old_id
		_check("被删句旧档保存 " + old_id, sm.save())
		await _reload_scene()
		var next_id: String = {"offer": "no", "memory": "cooking", "ingredients": "yaya_join", "stay_shallow": "agreement"}[old_id]
		_check("被删句旧档直接接续 " + old_id, _step() == next_id and _dialog_identity_ok(next_id)
			and sm.departure_state().tieshan_name_revealed)
		var original_path: String = sm._active_save_path
		var before: Dictionary = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check("接续后写盘失败不丢进度 " + old_id, not sm.advance_departure(next_id).success and sm.data == before)
		sm._active_save_path = original_path
		await _finish_dialog(next_id, KEY_E, false)
	sm.data = done
	_check("准备态旧档保存", sm.save())
	await _reload_scene()
	_check("准备态读档恢复入队展示", tm.active and sm.is_ready_to_depart() and sm.chapter_1_outro_state() == "party"
		and is_instance_valid(tm._chapter_outro) and tm._chapter_outro.is_inside_tree()
		and tm._chapter_outro.phase == "party" and tm._chapter_outro._party.visible)
	tm._cancel_current_run()
	for phase in ["party", "home", "maze", "title"]:
		_check("完成态沿章节收尾门禁提交 " + phase, sm.advance_chapter_1_outro(phase).success)
	await _reload_scene()
	_check("完成态旧档读档不重播对白", not tm.active and sm.is_chapter_1_complete())

func _test_missing_portrait_reset() -> void:
	var dialog = (load("res://scenes/ui/dialog_box.tscn") as PackedScene).instantiate()
	root.add_child(dialog)
	dialog.start("你", ["头像状态"], load(PORTRAITS["你"]))
	_check("有头像显示真实纹理", dialog.portrait.visible and dialog.portrait_texture.visible)
	dialog.start("测试", ["缺素材"], null)
	_check("缺素材不残留上一头像或首字占位", dialog.speaker_name.text == "测试"
		and not dialog.portrait.visible and not dialog.portrait_texture.visible
		and dialog.portrait_texture.texture == null and not dialog.portrait_fallback.visible)
	dialog.start("", ["旁白"], null)
	_check("真正旁白不伪装成角色", not dialog.speaker_name.visible and not dialog.portrait.visible)
	dialog.queue_free()

func _send_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	root.push_input(event)
	await process_frame

func _click(control: Control) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var center := control.get_global_rect().get_center()
	root.warp_mouse(center)
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = center
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = center
	event.pressed = false
	root.push_input(event)
	await process_frame

func _stand_near(target: Node2D, player: CharacterBody2D) -> Vector2:
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if not player.is_walkable_footprint(candidate):
				continue
			player.global_position = candidate
			if player.nearest_interactable() == target:
				return candidate
	return player.global_position

func _wait_for_step(id: String, frames: int) -> void:
	for _i in frames:
		if _step() == id:
			return
		await process_frame

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := output_dir.path_join(label + ".png")
	var error := image.save_png(path)
	_check("截图 " + label, error == OK and image.get_width() == int(_arg("--width=")),
		{"path": path, "size": image.get_size()})

func _step() -> String:
	return str(tm.steps[tm.idx].get("wrapup_id", "")) if tm.active and tm.idx < tm.steps.size() else "inactive"

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func _check(name: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	if not passed:
		failures.append(name)
		push_error("CH1-DIALOG-02: " + name + " " + JSON.stringify(details))

func _write_report() -> void:
	var path := output_dir.path_join("report.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures,
		"save_path": ProjectSettings.globalize_path("user://save.json")}, "\t"))
	file.close()
	print("CH1-DIALOG-02 checks=", checks.size(), " failures=", failures.size(), " report=", path)
