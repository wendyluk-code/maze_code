extends "res://tools/tests/chapter_ending_input.gd"
var continued := 0
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离用户目录")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			await get_tree().process_frame
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			_seed()
			for step in ["party","home","maze"]: sm.advance_chapter_1_outro(step)
			await _open_scene()
			_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro._ending.visible,240), "实际title检查点恢复章末")
			var ending = tm._chapter_outro._ending
			ending.continue_requested.connect(func(): continued += 1)
			await _animation_checks(ending)
			var player = scene.get_node("Player")
			_check(player.input_locked, "章末期间锁定玩家")
			await _send_key(KEY_E)
			_check(await _wait_until(func(): return not tm.active,120), "提示后新按E正常保存关闭")
			_check(not player.input_locked and player.is_physics_processing(), "关闭恢复输入")
			_check(sm.chapter_1_outro_state() == "done", "继续保存原检查点")
			await _close_scene()
		await _lifecycle_checks()
	var report := {"checks":checks,"failures":failures,"results":results,"user_dir":ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CH-END-01 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _shot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _capture(evidence,label+suffix)

func _animation_checks(ending: Control) -> void:
	continued = 0
	# 重置同一个真实调用方拥有的章末组件，准确采样从present起的时序。
	ending.present("第一章：第一顿饭", "你苏醒后，和芽芽一起结识了铁山，\n准备一同前往迷宫浅层探索")
	var start := Time.get_ticks_msec()
	var press := InputEventKey.new(); press.keycode=KEY_E; press.pressed=true
	get_viewport().push_input(press)
	await get_tree().create_timer(0.9).timeout
	_check(ending._titles.modulate.a > 0 and ending._titles.modulate.a < 1 and ending._description.modulate.a == 0 and ending._prompt.modulate.a == 0,"标题先渐显，说明与提示不可见")
	await _shot("title_reveal")
	await get_tree().create_timer(0.8).timeout
	_check(ending._titles.modulate.a == 1 and ending._description.modulate.a > 0 and ending._description.modulate.a < 1 and ending._prompt.modulate.a == 0,"说明第二阶段渐显")
	await _shot("description_reveal")
	await get_tree().create_timer(0.7).timeout
	_check(ending._description.modulate.a == 1 and ending._prompt.modulate.a > 0 and ending._prompt.modulate.a < 1 and not ending._ready_for_input,"提示第三阶段渐显且不接收继续")
	await _shot("prompt_reveal")
	var ready := await _wait_until(func(): return ending._ready_for_input,120)
	_check(ready, "提示完整才开放输入", {"elapsed_ms":Time.get_ticks_msec()-start})
	_check(continued == 0 and not ending._armed, "早按和长按E均不穿透")
	var echo := InputEventKey.new(); echo.keycode=KEY_E; echo.pressed=true; echo.echo=true
	get_viewport().push_input(echo)
	var click := InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=ending.get_global_rect().get_center()
	get_viewport().push_input(click)
	await get_tree().process_frame
	_check(continued == 1,"鼠标点击触发继续信号")
	_check(ending._description.get_theme_font("font").resource_path == "res://assets/ui/zcool_kuail.ttf","说明使用原生快乐体字体")
	for child in ending._prompt.get_children():
		if child is Label:
			_check(child.get_theme_font("font").resource_path == "res://assets/ui/zcool_kuail.ttf","继续文案使用原生快乐体字体")
	_check(ending._description.text.replace("\n","") == "你苏醒后，和芽芽一起结识了铁山，准备一同前往迷宫浅层探索","说明精确文案")
	var title: Label = ending._title
	_check(title.visible and title.text == "第一章：第一顿饭" and title.get_theme_font("font").resource_path == "res://assets/ui/zcool_kuail.ttf", "标题使用游戏字体")
	_check(title.material == null and ending._titles.find_children("*", "TextureRect", true, false).is_empty(), "标题无图片或着色器")
	_check(title.get_theme_constant("outline_size") == 0 and title.get_theme_color("font_color") == Color("e8ba62"), "整行标题暖金无描边")
	_check(ending.get_global_rect().encloses(title.get_global_rect()), "原生标题完整位于视口内")
	await _shot("chapter_end")
	var release := InputEventKey.new(); release.keycode=KEY_E
	get_viewport().push_input(release)
	await get_tree().process_frame

func _lifecycle_checks() -> void:
	var ending = preload("res://scripts/ui/chapter_end_overlay.gd").new()
	add_child(ending)
	ending.present("第一章：第一顿饭", "测试")
	await get_tree().create_timer(0.8).timeout
	ending.cancel()
	ending.present("第一章：第一顿饭", "重开")
	_check(ending._titles.modulate.a == 0 and ending._description.modulate.a == 0 and ending._prompt.modulate.a == 0,"取消重开从初态开始")
	await get_tree().create_timer(0.7).timeout
	_check(ending._description.modulate.a == 0 and not ending._ready_for_input,"旧动画不会提前显示说明或开放输入")
	ending.dismiss()
	await get_tree().create_timer(0.1).timeout
	ending.dismiss()
	await get_tree().create_timer(0.1).timeout
	ending.present("第一章：第一顿饭", "再次重开")
	await get_tree().create_timer(0.4).timeout
	_check(ending.visible and ending.modulate.a == 1 and not ending._ready_for_input,"重复dismiss后重开不被旧协程隐藏")
	ending.cancel()
	await get_tree().create_timer(3.0).timeout
	_check(not ending.visible and not ending._ready_for_input,"取消后旧渐显不继续生效")
	ending.queue_free()
