extends "res://tools/tests/ch2_guide_01.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _buttons_flow()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _buttons_flow() -> void:
	_fresh()
	sm.data[Run.KEY].combat.actors.slime_1.hp = 0
	sm.data[Guide.KEY] = {"revision":2,"step":"explore","seen":{"05_power":true,"06_absorb":true},"banked":{}}
	_check(Run.defeat(sm,"slime_1",Catalog.find("slime_1").position).success,"准备真实待捕获存档")
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	var g: Node = maze.exploration_guide
	await get_tree().create_timer(1.0).timeout
	g = maze.exploration_guide
	var flow: Node = maze.capture_flow
	_check(await _wait_until(func(): return g.gate and g.lesson_id == "06_yes",180),"胜利教学操作出现")
	if not g.gate: return
	_check(flow.dialog._cancel_button.disabled and not flow.dialog._confirm_button.disabled,"胜利教学仅否禁用")
	flow.dialog.tutorial_only_yes = false
	_check(not flow.dialog._cancel_button.disabled,"解除胜利教学恢复否")
	flow.dialog.tutorial_only_yes = true
	await _verify_glow(g,"victory_yes")
	await _tap(flow.dialog._cancel_button)
	await _send_key(KEY_ESCAPE)
	await _send_key(KEY_ENTER)
	_check(flow.dialog.visible and not flow.attempt.visible,"否、Esc、Enter均不能绕过目标")
	await _tap(flow.dialog._confirm_button)
	_check(await _wait_until(func(): return g.reading and g.lesson_id == "07_capture",180),"点击是进入下一段说明")
	await _finish_reading(g)
	await get_tree().create_timer(0.3).timeout
	_check(g.gate and g.lesson_id == "07_yes","后续确认操作出现")
	_check(flow.attempt.no_button.disabled and flow.attempt.close_button.disabled and not flow.attempt.yes_button.disabled,"捕获教学禁用否和关闭")
	flow.attempt.tutorial_only_yes = false
	_check(not flow.attempt.no_button.disabled and not flow.attempt.close_button.disabled,"解除捕获教学恢复否和关闭")
	flow.attempt.tutorial_only_yes = true
	await _verify_glow(g,"capture_yes")
	await _tap(flow.attempt.no_button)
	await _tap(flow.attempt.close_button)
	await _send_key(KEY_ESCAPE)
	_check(flow.attempt.mode == "ready","后续否、关闭和Esc均拦截")
	var food: float = Run.snapshot(sm).satiety
	await _tap(flow.attempt.yes_button)
	await get_tree().create_timer(0.2).timeout
	_check(flow.attempt.mode == "throw" and Run.snapshot(sm).satiety == food-1,"是正常推进且只扣一次")
	_check(not g.gate and g.operation_glows.is_empty() and g.operation_shades.is_empty(),"操作结束清除光效并恢复底色")
	await get_tree().create_timer(2.8).timeout
	await _finish_reading(g)
	await get_tree().create_timer(11.5).timeout
	_check(flow.reward.visible,"捕获完成奖励正常出现")
	_check(not flow.reward._body_label.visible and flow.reward._body_label.text.is_empty(),"捕获成功无获得食材文案及正文占位")
	await _capture_image("capture_success_compact")
	await _tap(flow.reward._confirm_button)
	await get_tree().create_timer(1.0).timeout
	await _finish_reading(g)
	await get_tree().create_timer(0.2).timeout
	_check(not maze.player.input_locked and maze.player.is_physics_processing(),"结束说明恢复玩家输入")
	maze.queue_free()
	await get_tree().process_frame

func _verify_glow(g: Node, label: String) -> void:
	await get_tree().create_timer(0.15).timeout
	_check(not g.guide.dim.visible,"操作无教学蒙层："+label)
	_check(g.operation_glows.size()==1 and not g.operation_shades.is_empty(),"唯一目标光效且业务蒙层已接管："+label)
	for shade in g.operation_shades:
		_check(is_zero_approx(shade.color.a),"业务蒙层透明但保留输入拦截")
	var style: StyleBoxFlat = g.operation_glows[0].get_theme_stylebox("panel")
	var alpha := style.shadow_color.a
	await _capture_image(label+"_bright")
	var low := alpha
	var high := alpha
	for sample in range(12):
		await get_tree().create_timer(0.1).timeout
		low = minf(low, style.shadow_color.a)
		high = maxf(high, style.shadow_color.a)
	_check(high-low>0.4,"完整周期呼吸光随时间变化："+label)
	await _capture_image(label+"_dim")


func _finish_reading(g: Node) -> void:
	await get_tree().create_timer(0.25).timeout
	for press in range(5):
		if not g.reading: return
		await _send_key(KEY_E)
		await get_tree().create_timer(0.2).timeout

