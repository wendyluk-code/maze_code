extends "res://tools/tests/tutorial_checkpoint_flow.gd"
## 用真实餐厅、首单事务和键盘输入验证菜谱蒙层时序，复用已有隔离验收辅助方法。

func _run() -> void:
	report_path = _arg("--report=")
	var isolation := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if isolation.is_empty() or not actual.begins_with(isolation + "/") or report_path.is_empty():
		quit(2)
		return
	sm = root.get_node("SaveManager")
	tm = root.get_node("TutorialManager")
	_check("创建隔离新游戏", sm.create_new_game().success)
	sm.data.prologue_done = true
	_check("保存隔离新游戏", sm.save())
	await _open_scene()
	var hud = get_first_node_in_group("restaurant_hud")
	var deadline := Time.get_ticks_msec() + 20000
	while tm.active and Time.get_ticks_msec() < deadline:
		var step: Dictionary = tm.steps[tm.idx]
		if step.get("target", "") == "前台":
			break
		if hud._recipe_unlock.visible:
			_check("接单之前不显示菜谱蒙层", false)
			_write_report(actual)
			return
		if step.get("type") == "dialog":
			await _confirm_line()
		else:
			await process_frame
	_check("开场对白后进入前台引导", tm.steps[tm.idx].get("target", "") == "前台")
	_check("接单之前不显示菜谱蒙层", not hud._recipe_unlock.visible)
	_check("前台可交互站位", _stand_near(tm.resolve_target("前台")))
	await process_frame
	await process_frame
	await _press_e()
	_check("实际接单进入芽芽说明", sm.lifecycle_stage() == "order_accepted" and tm._order_explanation_pending)
	_check("仓库说明对白中不显示蒙层", tm.guide.dialog.visible and not hud._recipe_unlock.visible)
	await _press_e()
	_check("补全文字不会提前弹蒙层", tm.guide.dialog.visible and not hud._recipe_unlock.visible)
	await _capture("warehouse_dialog.png")
	await _press_e()
	_check("说明关闭后弹菜谱蒙层", not tm.guide.dialog.visible and hud._recipe_unlock.visible)
	_check("蒙层期间锁定移动且未领取材料", tm.player.input_locked and sm.lifecycle_stage() == "order_accepted")
	await _capture("recipe_after_dialog.png")
	await _press_e()
	await create_timer(0.65).timeout
	_check("关闭后恢复仓库引导和移动", not hud._recipe_unlock.visible and not tm.player.input_locked and tm.steps[tm.idx].get("target", "") == "仓库")
	await _reload()
	hud = get_first_node_in_group("restaurant_hud")
	_check("读档保持仓库引导且不重复蒙层", not hud._recipe_unlock.visible and tm.steps[tm.idx].get("target", "") == "仓库")
	_check("仓库可交互站位", _stand_near(tm.resolve_target("仓库")))
	await process_frame
	await process_frame
	await _press_e()
	var warehouse = current_scene.get_node("UIOverlay/WarehouseModal")
	_check("实际交互打开仓库", warehouse._open)
	await _capture("warehouse_after_recipe.png")
	warehouse._on_slot_selected("rockmane_meat")
	warehouse._on_slot_selected("rock_salt")
	_check("材料选择后可领取", not warehouse._claim_button.disabled)
	warehouse._claim_button.pressed.emit()
	await process_frame
	_check("领取食材成功并进入烹饪引导", sm.lifecycle_stage() == "ingredients_collected" and tm.current_stage == 5 and not warehouse._open and not tm.player.input_locked)
	_write_report(actual)
