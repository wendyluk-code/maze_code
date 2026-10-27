extends "res://tools/tests/ch1_qte_03_input.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	var evidence := _arg("--output-dir=")
	if failures == 0:
		scene = load("res://scenes/start_screen.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.2).timeout
		await _click(scene.new_button)
		await get_tree().create_timer(1).timeout
		_check(get_tree().current_scene.scene_file_path == "res://scenes/prologue.tscn", "新游戏实际进入序章")
		await _capture(evidence, "prologue")
		await _click(get_tree().current_scene.get_node("SkipPrologue"))
		await get_tree().create_timer(1).timeout
		_check(get_tree().current_scene.scene_file_path == "res://scenes/restaurant_map_2d.tscn" and tm.active, "跳过序章进入餐厅正式教程")
		var guide = get_tree().get_first_node_in_group("tutorial_guide")
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
		await _send_key(KEY_E)
		_check(sm.tutorial_checkpoint().next_index > 0 or sm.tutorial_checkpoint().line_index > 0, "E推进真实对白并保存检查点")
		var checkpoint: Dictionary = sm.tutorial_checkpoint().duplicate(true)
		var save_path: String = sm._active_save_path
		await _capture(evidence, "tutorial_dialog")
		tm._cancel_current_run()
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
		await get_tree().create_timer(0.3).timeout
		scene = get_tree().current_scene
		await _click(scene.continue_button)
		_check(scene.save_modal.visible and scene.save_modal._rows.size() == 1, "继续游戏列出刚创建的存档")
		await _send_key(KEY_ESCAPE)
		_check(not scene.save_modal.visible and not scene.continue_button.disabled, "Esc关闭存档列表恢复菜单")
		await _click(scene.continue_button)
		await _click(scene.save_modal._rows.values()[0])
		await _click(scene.save_modal._confirm_button)
		await get_tree().create_timer(1).timeout
		_check(get_tree().current_scene.scene_file_path == "res://scenes/restaurant_map_2d.tscn" and sm._active_save_path == save_path, "继续游戏回到同一存档餐厅")
		_check(sm.tutorial_checkpoint() == checkpoint and tm.active, "重进保留对白检查点")
		await _capture(evidence, "continue_restored")
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
