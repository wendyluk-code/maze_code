extends "res://tools/tests/ch1_qte_03_input.gd"
var ending_events := 0
var evidence := ""
var suffix := ""

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		tm.chapter_1_finished.connect(func(): ending_events += 1)
		_data_checks()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _flow()
		await _resume_checks()
		await _party_cancel_check()
	var report := {"checks":checks,"failures":failures,"results":results,"user_dir":ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CHAPTER_ENDING ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _seed(step := "ready_to_depart") -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://chapter-ending-test.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.save(), "初始化隔离存档")
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success and sm.deliver_first_order().success, "真实首单事务达成收尾前置")
	for expected in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(expected): continue
		if sm.departure_state().step == step: break
		if not sm.advance_departure(expected).success:
			_check(false,"推进前置步骤：" + expected)
			break

func _data_checks() -> void:
	_seed()
	_check(sm.chapter_1_outro_state() == "party", "旧就绪未完成档从入队弹窗开始")
	var rep: int = sm.reputation()
	_check(not sm.advance_chapter_1_outro("maze").success, "不能跳过两个入口对白")
	_check(not tm.confirm_chapter_1().success, "旧手动完成入口不可绕过收尾")
	for expected in ["party","home","maze","title"]:
		var before: Dictionary = sm.data.duplicate(true)
		var original_path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not sm.advance_chapter_1_outro(expected).success and sm.data == before,"保存失败完整回滚：" + expected)
		sm._active_save_path = original_path
		_check(sm.advance_chapter_1_outro(expected).success, "合法收尾提交：" + expected)
		sm.load_data()
		_check(not sm.has_pending_chapter_1_outro() if expected == "title" else sm.has_pending_chapter_1_outro(), "收尾检查点可重载：" + expected)
		if expected == "maze":
			_check(sm.is_chapter_1_complete() and sm.chapter_1_outro_state() == "title", "对白后完成章节且蒙层仍待确认")
	_check(sm.reputation() == rep and sm.departure_state().party == ["yaya","tieshan"],"收尾不重复奖励或入队")
	sm.data.erase("chapter_1_outro")
	_check(sm.chapter_1_outro_state() == "done", "旧已完成档不重播结尾")
	var formal: Dictionary = sm.data.duplicate(true)
	sm.begin_replay()
	# 重播前置通过同一业务事务生成，不写正式存档。
	sm.accept_first_order(); sm.claim_first_order_ingredients(); sm.cook_first_order(); sm.deliver_first_order()
	for expected in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(expected): continue
		if expected != "ready_to_depart": sm.advance_departure(expected)
	for expected in ["party","home","maze","title"]:
		_check(sm.advance_chapter_1_outro(expected).success,"回放收尾："+expected)
	_check(sm.data == formal,"回放不污染正式状态")
	sm.end_replay()

func _open_scene() -> void:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	tm.start()
	await get_tree().process_frame

func _close_scene() -> void:
	tm._cancel_current_run()
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame

func _shot(label: String) -> void:
	await _capture(evidence,label+suffix)

func _dialog_finish() -> void:
	var dialog = scene.get_node("UIOverlay/TutorialGuide").dialog
	await _send_key(KEY_E)
	if dialog.visible: await _send_key(KEY_E)

func _flow() -> void:
	_seed("yaya_ready")
	await _open_scene()
	var events_before := ending_events
	var player = scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/Store"))
	player.last_valid = player.global_position
	_check(player.nearest_interactable() == scene.get_node("InteractPoints/Store"),"实际仓库站位可触发取货")
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	_check(guide.dialog.visible, "从最后一句现有对白开始")
	await _dialog_finish()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase == "party" and tm._chapter_outro._party.visible,180),"对白结束显示入队卡牌")
	if not is_instance_valid(tm._chapter_outro): return
	var outro = tm._chapter_outro
	var party = outro._party
	var opening := InputEventKey.new(); opening.keycode = KEY_E; opening.pressed = true
	get_viewport().push_input(opening)
	await get_tree().create_timer(0.25).timeout
	_check(party._progress > 0.0 and party._progress < 1.0 and outro._busy,"存在扇形展开中间态且禁止继续")
	await _shot("party_opening")
	_check(await _wait_until(func(): return not outro._busy,180),"扇形展开完成")
	_check(party.visible and outro.phase == "party" and not party._armed,"展开期间长按E不会跳过卡牌")
	_check(party.cards.size() == 2 and party.cards[0].rotation < 0 and party.cards[1].rotation > 0,"两张卡向左右扇形展开")
	_check(party.find_children("*", "Button", true, false).is_empty() and party.find_children("*", "PanelContainer", true, false).is_empty(),"独立卡牌无外框或关闭按钮")
	_check(party._prompt.text == "按 E 继续" and party._prompt.modulate.a == 1.0,"底部提示正确且完整出现")
	for card in party.cards:
		var rectangle := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
		var bounds := Rect2(card.get_global_transform()*Vector2.ZERO,Vector2.ZERO)
		for corner in [Vector2.ZERO,Vector2(card.size.x,0),card.size,Vector2(0,card.size.y)]:
			var point: Vector2 = card.get_global_transform()*corner
			_check(rectangle.has_point(point),"旋转后卡牌完整位于视口")
			bounds = bounds.expand(point)
		_check(bounds.end.y < party._prompt.position.y,"卡牌不遮挡底部继续提示")
	await _send_key(KEY_SPACE)
	var echo_key := InputEventKey.new(); echo_key.keycode = KEY_E; echo_key.pressed = true; echo_key.echo = true
	get_viewport().push_input(echo_key)
	await _click(party.cards[0])
	_check(outro.phase == "party" and party.visible,"空格鼠标与E重复事件均不关闭卡牌")
	_check(player.input_locked and outro._party.visible,"入队弹窗锁定场景交互")
	_check_prompts_hidden("入队弹窗")
	await _shot("party")
	var released := InputEventKey.new(); released.keycode = KEY_E
	get_viewport().push_input(released)
	await get_tree().process_frame
	var original_path: String = sm._active_save_path
	sm._active_save_path = ""
	await _send_key(KEY_E)
	_check(outro.phase == "party" and party.visible and not party._error.text.is_empty(),"保存失败保留卡牌并可重试")
	sm._active_save_path = original_path
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return outro.phase == "home" and not outro._busy,180),"关闭弹窗进入冒险者之家特写")
	_check(not outro._party.visible and guide.dialog._lines == [outro.HOME_LINE],"芽芽冒险者之家对白准确")
	await _check_focus("InteractPoints/AdventurerHomeDoor","home")
	await _dialog_finish()
	_check(await _wait_until(func(): return outro.phase == "maze" and not outro._busy,180),"冒险者之家对白结束切迷宫特写")
	_check(guide.dialog._lines == [outro.MAZE_LINE],"芽芽迷宫对白准确")
	await _check_focus("DepartureEntrance","maze")
	_check(not sm.is_chapter_1_complete(),"最后一句关闭前不算完章")
	# 最后一句补全文本后持续按住E，跨越蒙层淡入。
	var held := InputEventKey.new(); held.keycode = KEY_E; held.pressed = true
	get_viewport().push_input(held)
	_check(await _wait_until(func(): return outro.phase == "title" and outro._ending.visible,240),"对白结束进入结尾蒙层")
	_check(sm.is_chapter_1_complete(),"显示结尾画面前章节已完成")
	_check(not is_instance_valid(outro._entrance_highlight),"迷宫对白结束进入标题前移除高亮")
	_check(scene.get_node("DepartureEntrance").is_in_group("interactable"),"移除弧条后迷宫入口仍可交互")
	_check(ending_events == events_before + 1,"对白完成仅发出一次章节完成信号")
	_check_prompts_hidden("结尾蒙层")
	await get_tree().create_timer(0.25).timeout
	_check(outro._ending._veil.modulate.a > 0 and outro._ending._veil.modulate.a < 1,"蒙层存在渐显中间态")
	await get_tree().create_timer(1.3).timeout
	_check(tm.active and player.input_locked and outro._ending.visible,"长按E不穿透结尾画面")
	var echo := InputEventKey.new(); echo.keycode = KEY_E; echo.pressed = true; echo.echo = true
	get_viewport().push_input(echo)
	await get_tree().process_frame
	await _send_key(KEY_SPACE)
	_check(outro._ending.visible,"重复事件和空格不能关闭蒙层")
	_check(outro._ending._title.text == "第一章 · 第一顿饭" and outro._ending._prompt.text == "按 E 继续","结尾标题及提示准确")
	_check(not outro._ending._armed,"跨越结尾持续按E仍未解锁继续")
	await _shot("chapter_end")
	var release := InputEventKey.new(); release.keycode = KEY_E
	get_viewport().push_input(release)
	await get_tree().process_frame
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return not tm.active,120),"新按E关闭蒙层并结束教程")
	_check(not player.input_locked and player.is_physics_processing(),"返回游戏恢复移动和交互")
	await get_tree().process_frame
	_check(scene.get_node("UIOverlay")._buttons[scene.get_node("InteractPoints/Store")].visible,"回到仓库旁恢复取货提示")
	var camera = scene.get_node("Camera")
	_check(not camera.paused and camera.zoom.is_equal_approx(Vector2(0.85,0.85)),"返回游戏恢复镜头跟随与倍率")
	_check(sm.chapter_1_outro_state() == "done", "关闭蒙层状态保存")
	_check(not sm.quest_snapshot().active.is_empty(),"盐池探索任务仍进行中")
	await _shot("back_to_game")
	await _close_scene()
	sm.load_data()
	await _open_scene()
	_check(not tm.active and not is_instance_valid(tm._chapter_outro),"完章重进不重复弹窗")
	await _close_scene()

func _check_focus(path: String,label: String) -> void:
	_check_prompts_hidden(label)
	var outro = tm._chapter_outro
	if label in ["home", "maze"]:
		var glow = outro._entrance_highlight
		_check(is_instance_valid(glow) and glow.visible,"对白立即高亮入口："+label)
		if is_instance_valid(glow):
			_check(glow.name == ("HomeEntranceHighlight" if label == "home" else "MazeEntranceHighlight"),"入口高亮对象正确："+label)
			_check((glow.outline[0].x < 300.0) == (label == "maze"),"不同入口使用各自轮廓："+label)
			_check(glow.get_index() > tm.guide.dim.get_index() and glow.get_index() < tm.guide.dialog.get_index(),"高亮位于暗幕之上对白之下")
			_check(glow.transform.is_equal_approx(scene.get_node("BG").get_global_transform_with_canvas()),"高亮跟随镜头准确贴合背景")
			var peak := 0.0
			var trough := 1.0
			var end := Time.get_ticks_msec() + 1600
			while Time.get_ticks_msec() < end:
				peak = maxf(peak,glow.strength)
				trough = minf(trough,glow.strength)
				if glow.strength > 0.99: await _shot(label+"_glow_bright")
				if glow.strength < 0.01: await _shot(label+"_glow_dim")
				await get_tree().process_frame
			_check(peak > 0.95 and trough < 0.05,"门口高亮持续明暗闪烁")
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	var target: Node2D = scene.get_node(path)
	var camera = scene.get_node("Camera")
	var screen_point: Vector2 = get_viewport().get_canvas_transform()*target.global_position
	_check(camera.paused and camera.zoom.x > 1.5,"入口特写放大并暂停跟随："+label)
	_check(get_viewport().get_visible_rect().has_point(screen_point),"入口在画面内："+label)
	_check(screen_point.y < guide.dialog.get_global_rect().position.y,"对白不遮挡入口："+label)
	_check(guide.dialog.speaker_name.text == "芽芽" and guide.dialog.portrait_texture.texture.resource_path == "res://assets/characters/yaya_portrait.png","芽芽姓名头像正确："+label)
	# 闪烁采样已可能让打字机自然完成，不再额外按 E 误关闭对白。
	if guide.dialog._shown < str(guide.dialog._lines[guide.dialog._line_idx]).length():
		await _send_key(KEY_E)
	await _shot(label)

func _check_prompts_hidden(label: String) -> void:
	var hidden := true
	for button in scene.get_node("UIOverlay")._buttons.values():
		if button.visible: hidden = false
	_check(hidden,"收尾不残留道具E提示："+label)

func _resume_checks() -> void:
	for expected in ["party","home","maze","title"]:
		_seed()
		for previous in ["party","home","maze"]:
			if sm.chapter_1_outro_state() == expected: break
			sm.advance_chapter_1_outro(previous)
		sm.load_data()
		await _open_scene()
		_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase == expected and not tm._chapter_outro._busy,240),"重进恢复收尾检查点："+expected)
		var glow = tm._chapter_outro._entrance_highlight
		_check(is_instance_valid(glow) == (expected in ["home","maze"]),"读档仅在入口对白恢复高亮："+expected)
		var old_camera = scene.get_node("Camera")
		tm._cancel_current_run()
		_check(not is_instance_valid(glow) or not glow.visible,"取消立即隐藏高亮："+expected)
		_check(not old_camera.paused and old_camera.zoom.is_equal_approx(Vector2(0.85,0.85)),"取消恢复镜头："+expected)
		_check(not scene.get_node("Player").input_locked,"取消释放输入锁："+expected)
		await _close_scene()

func _party_cancel_check() -> void:
	_seed()
	await _open_scene()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro._party.visible,180),"取消测试进入展卡")
	var party = tm._chapter_outro._party
	await get_tree().create_timer(0.15).timeout
	var before: Dictionary = sm.data.duplicate(true)
	tm._cancel_current_run()
	_check(not party.visible and party._tween == null,"展开中途取消立即隐藏并停止Tween")
	await get_tree().create_timer(1.2).timeout
	_check(sm.data == before and not tm.active,"取消后无旧回调推进剧情")
	await _close_scene()
