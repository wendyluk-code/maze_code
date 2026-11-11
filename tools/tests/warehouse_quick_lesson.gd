extends "res://tools/tests/restaurant_rest05b.gd"
const QuickLesson := preload("res://scripts/ui/components/warehouse_quick_lesson.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_fresh()
		_open({A:3})
		_order()
		var hud = await _open_restaurant()
		var w = get_tree().get_first_node_in_group("warehouse_modal")
		hud._player.position = _stand(scene.get_node("InteractPoints/Store"))
		hud._player.last_valid = hud._player.position
		await _send_key(KEY_E)
		await get_tree().create_timer(0.3).timeout
		var lesson = w._quick_lesson
		_check(is_instance_valid(lesson),"首次快速选择触发教学")
		if not is_instance_valid(lesson): continue
		_check(lesson.dialog._lines[0]==QuickLesson.LINE,"指定芽芽文案")
		var rect: Rect2 = w._quick_panel.get_global_rect()
		_check(lesson.dim.material.get_shader_parameter("ingredients_rect")==Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y),"仅挖空快速选择整栏")
		_check(w._slot_by_id.rock_salt.modulate==Color.WHITE and w._slot_by_id.rockmane_meat.modulate==Color.WHITE,"订单食材无黄色染色")
		var clock: float = Day.snapshot(sm).remaining
		await get_tree().create_timer(0.3).timeout
		_check(Day.snapshot(sm).remaining==clock,"教学冻结营业计时")
		await _send_key(KEY_ESCAPE)
		_check(w.visible and is_instance_valid(w._quick_lesson),"Esc不穿透关闭仓库")
		lesson.dialog._advance()
		await _shot("warehouse_quick_lesson")
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		lesson._finish()
		_check(not sm.data.get(QuickLesson.KEY,false) and is_instance_valid(w._quick_lesson),"保存失败保留教学可重试")
		sm._active_save_path = path
		lesson._finish()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(sm.data.get(QuickLesson.KEY,false) and not is_instance_valid(w._quick_lesson),"已读持久化并撤掉蒙层")
		_check(hud._player.input_locked,"教学结束保留仓库锁")
		await _click(w._quick_buttons[0])
		_check(w._selected==Recipe.get_recipe(A).ingredients,"教学后快捷选择正常")
		await _shot("warehouse_quick_selected")
		await _click(w._claim_button)
		_check(not w.visible and not hud._player.input_locked,"取料关闭恢复输入")
		sm.load_data()
		w.open_stock()
		await get_tree().create_timer(0.2).timeout
		_check(not is_instance_valid(w._quick_lesson),"读档再开不重复教学")
		w.close_modal()
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
