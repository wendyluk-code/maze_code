extends "res://tools/tests/yufeng_sitting_flow.gd"

func _verify_isolation() -> bool:
	var actual := ProjectSettings.globalize_path("user://").replace("\\","/").to_lower()
	return actual.begins_with(OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").to_lower()+"/")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"跨进程仍使用隔离目录")
	var checkpoint := OS.get_environment("YF_SITTING_CHECKPOINT")
	sm._active_save_path = "user://yf-checkpoint-"+checkpoint+".json"
	_check(FileAccess.file_exists(sm._active_save_path),"来自真实流程的检查点存在")
	if failures == 0:
		sm.load_data()
		var stock: Dictionary = sm.warehouse_snapshot()
		var owned: Array = sm.owned_characters()
		await _open_map()
		var e = maze.yf_encounter
		_check(e.phase == checkpoint,"独立进程恢复阶段："+checkpoint)
		_check(sm.warehouse_snapshot() == stock and sm.owned_characters() == owned,"打开场景不重复赠礼或入队")
		_check(e.idle.visible == (checkpoint != "done"),"角色可见性与任务完成一致")
		if checkpoint == "joined":
			_check(e.join_overlay.visible and owned.has("yufeng") and owned.has("salia"),"中断入队演出后保留角色并续播")
		if checkpoint == "done":
			_check(not maze.player.input_locked and not e.talk_prompt.visible and not e.clue_prompt.visible,"完成检查点无输入锁或残留提示")
			var selector = preload("res://scripts/ui/components/team_entry_modal.gd").new()
			maze._ui_root.add_child(selector)
			selector.open_exploration()
			_check(selector.set_selected("yufeng",true) and selector.set_selected("salia",true),"真实选队组件可选入两人")
			_check(selector.selected.has("yufeng") and selector.selected.has("salia"),"选队草稿包含新角色")
			selector.queue_free()
			var original = preload("res://scripts/ui/party_cards_overlay.gd").new()
			maze._ui_root.add_child(original)
			_check(original.cards[0].get_node("CharacterFace").character_id == "yaya" and original.cards[1].get_node("CharacterFace").character_id == "tieshan","共用入队组件默认仍为芽芽、铁山")
			original.queue_free()
		await _close_map()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("YUFENG_RESUME ",checkpoint," ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)
