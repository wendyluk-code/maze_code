extends "res://tools/tests/combat_skill_01.gd"
func _combat_scene() -> void:
	await _new_scene()
	_fixture()
	maze.set_process(false)
	maze.player.position=Vector2(1040,205)
	if is_instance_valid(maze._prompt_host): maze._prompt_host.hide()
	maze.capture_flow.skill_bar.hide()
	maze.capture_flow.controls_hint.hide()
	var dialog=preload("res://scripts/ui/components/character_details_modal.gd").new()
	maze._ui_root.add_child(dialog)
	await get_tree().process_frame
	for id in ["yaya", "tieshan"]:
		dialog.present(id)
		_check(dialog.level_label.text == "等级 1", "等级仅显示当前值")
		_check(dialog.active_interval.text == "%s 秒" % str(Skills.PERIOD[id]), "技能间隔读取战斗参数")
		_check(dialog.active_icon.size == Vector2(44,44), "技能图标与属性图标同尺寸")
		await get_tree().process_frame
		await _capture_image("layout_" + id)
	dialog.queue_free()
	await _close_scene()
