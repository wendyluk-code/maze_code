extends "res://tools/tests/team_entry_01.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			_completed()
			sm.cancel_maze_entry()
			sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
			for phase in ["unseen","farewell","fade"]:
				_check(sm.set_yufeng_salia_state(phase).success, "剧情夹具 " + phase)
				_check(not sm.freezer_unlocked() and sm.freezer_action("store").reason == "story_locked", "剧情未完成禁止冰柜事务 " + phase)
			await _load_restaurant()
			var fridge: Node2D = scene.get_node("InteractPoints/Fridge")
			hud._player.global_position = _stand(fridge)
			await get_tree().create_timer(0.15).timeout
			await _send_key(KEY_E)
			_check(not hud.freezer.visible and not hud._player.input_locked, "锁定冰柜不打开不锁玩家")
			await _capture(_arg("--output-dir="), "locked_%d" % resolution.x)
			scene.queue_free()
			await get_tree().process_frame
			_check(sm.set_yufeng_salia_state("done").success and sm.freezer_unlocked(), "御风完成解锁")
			sm.load_data()
			await _load_restaurant()
			var guide = hud.exploration_guide
			_check(guide.reading and guide.lesson_id == guide.FREEZER_NOTICE and hud._player.input_locked, "首次返店芽芽对白并锁输入")
			_check(sm.freezer_notice_pending(), "读完前不提前标记")
			await _send_key(KEY_E)
			await RenderingServer.frame_post_draw
			await _capture(_arg("--output-dir="), "unlocked_dialog_%d" % resolution.x)
			var save_path: String = sm._active_save_path
			sm._active_save_path = ""
			await _send_key(KEY_E)
			_check(guide.pending_save.is_valid() and sm.freezer_notice_pending(), "提示保存失败可重试")
			sm._active_save_path = save_path
			await _send_key(KEY_E)
			_check(not guide.reading and not hud._player.input_locked and not sm.freezer_notice_pending(), "重试保存成功恢复输入")
			hud._player.global_position = _stand(scene.get_node("InteractPoints/Fridge"))
			await get_tree().create_timer(0.15).timeout
			await _send_key(KEY_E)
			_check(hud.freezer.visible, "解锁后实际E打开冰柜")
			await _send_key(KEY_ESCAPE)
			scene.queue_free()
			await get_tree().process_frame
			sm.load_data()
			await _load_restaurant()
			_check(not hud.exploration_guide.reading and not sm.freezer_notice_pending(), "重载返店不重复提示")
			scene.queue_free()
			await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _load_restaurant() -> void:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.7).timeout
	hud = get_tree().get_first_node_in_group("restaurant_hud")
