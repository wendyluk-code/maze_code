extends "res://tools/tests/ch1_qte_03_input.gd"
## 在真实餐厅场景注入方向键，验证逐帧动画、脚底、碰撞和对白锁定。

var evidence := ""

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "存档隔离")
	_check(DisplayServer.get_name() != "headless", "实际图形渲染")
	if failures == 0:
		DisplayServer.window_set_size(Vector2i(1152, 648))
		await _prepare_scene()
		var player = scene.get_node("Player")
		await get_tree().create_timer(0.5).timeout
		_check(player.spawn_ready and player.input_locked, "教程对白正常定位并锁住玩家")
		_check(player.position.distance_to(Vector2(1000, 850)) < 0.1, "新游戏第一章保持原出生点")
		var shadow: Sprite2D = player.get_node("GroundShadow")
		_check(shadow.texture.resource_path == "res://assets/characters/tieshan/ground_shadow.png" and shadow.scale == Vector2(0.64, 0.64) and shadow.position == Vector2(0, 1), "餐厅统一组件保留原柔和阴影贴图、尺寸和位置")
		var locked_position: Vector2 = player.global_position
		_key(KEY_D, true)
		await get_tree().create_timer(0.25).timeout
		_key(KEY_D, false)
		_check(player.global_position == locked_position and str(player.animation_name).ends_with("_idle"), "对白中按移动键仍原地待机")
		await _capture(evidence, "tutorial_locked")
		tm._cancel_current_run()
		await get_tree().process_frame
		_check(not player.input_locked and player.is_physics_processing(), "教程解锁恢复操作")
		_check(player.collision.shape.radius == 20.0, "原碰撞半径保持20")
		var anims: SpriteFrames = player.ANIMATIONS
		for name in anims.get_animation_names():
			var expected := 8 if str(name).ends_with("walk") else 4
			_check(anims.get_frame_count(name) == expected, str(name) + " 帧数")
			var duration := 0.0
			for i in expected:
				duration += anims.get_frame_duration(name, i) / anims.get_animation_speed(name)
				var image := anims.get_frame_texture(name, i).get_image()
				_check(image.get_size() == Vector2i(384, 360) and image.get_pixel(0, 0).a == 0.0, str(name) + " 透明帧 " + str(i))
			_check(absf(duration - (0.88 if expected == 8 else 2.34)) < 0.001, str(name) + " 原始时长保留")
		for spec in [[KEY_S, Vector2.DOWN, "front"], [KEY_W, Vector2.UP, "back"], [KEY_A, Vector2.LEFT, "left"], [KEY_D, Vector2.RIGHT, "right"]]:
			await _direction_case(player, spec[0], spec[1], spec[2])
		# 压向边界后脚底仍合法，外观替换不改变可走判定。
		var origin := _clear_start(player, Vector2.RIGHT)
		player.global_position = origin
		player.last_valid = origin
		_key(KEY_D, true)
		await get_tree().create_timer(3.0).timeout
		_key(KEY_D, false)
		_check(player.is_walkable_footprint(player.global_position), "连续移动触及边界仍在可走区")
		await get_tree().process_frame
		# 验证现有E交互信号和距离选择，不修改经营状态。
		var target := scene.get_node("InteractPoints/Store")
		player.global_position = _stand(target)
		player.last_valid = player.global_position
		var observed: Array = []
		var capture := func(node: Node2D): observed.append(node)
		player.interacted.connect(capture)
		await _send_key(KEY_E)
		_check(observed.has(target), "E仍按原距离选择仓库并发送交互信号")
		player.interacted.disconnect(capture)
	var report := {"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name(), "user_dir": ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("HERO_ANIMATION ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _direction_case(player, key: Key, direction: Vector2, label: String) -> void:
	var start := _clear_start(player, direction)
	_check(start != Vector2.ZERO, label + " 存在真实可走测试路径")
	player.global_position = start
	player.last_valid = start
	_key(key, true)
	var seen := {}
	for i in 20:
		await get_tree().physics_frame
		await get_tree().process_frame
		seen[player.animation_frame] = true
	_check(player.animation_name == StringName(label + "_walk") and seen.size() >= 2, label + " 方向键驱动行走换帧")
	_check((player.global_position - start).dot(direction) > 30.0, label + " 真实位移")
	_check(not player.body.flip_h, label + " 使用独立方向而非镜像")
	_check(player.body.to_global(player.body.offset + player.FRAME_FOOT).distance_to(player.global_position) < 0.01, label + " 脚底与碰撞中心一致")
	_check(absf(player.body.scale.y * 300.0 - 130.0) < 0.01 and player.body.position == Vector2.ZERO, label + " 实际人物高度130且取消额外跳动")
	await RenderingServer.frame_post_draw
	await _capture(evidence, label + "_walk")
	_key(key, false)
	await get_tree().physics_frame
	await get_tree().process_frame
	var stopped: Vector2 = player.global_position
	_check(player.animation_name == StringName(label + "_idle"), label + " 停止后保留朝向并待机")
	seen.clear()
	var captures := {}
	var until := Time.get_ticks_msec() + 2450
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		seen[player.animation_frame] = true
		if not captures.has(player.animation_frame):
			captures[player.animation_frame] = true
			await RenderingServer.frame_post_draw
			await _capture(evidence, label + "_idle_" + str(player.animation_frame))
	_check(seen.size() == 4 and player.global_position.distance_to(stopped) < 0.01, label + " 四帧待机循环且无滑动")
	# 暂停物理帧但保留显示处理，模拟现有剧情/弹窗锁。
	_key(key, true)
	await get_tree().physics_frame
	await get_tree().process_frame
	player.input_locked = true
	player.set_physics_process(false)
	await get_tree().process_frame
	_check(player.animation_name == StringName(label + "_idle"), label + " 行走时锁定即时切回待机")
	_key(key, false)
	player.input_locked = false
	player.set_physics_process(true)
	await get_tree().physics_frame

func _clear_start(player, direction: Vector2) -> Vector2:
	for y in range(850, 150, -20):
		for x in range(1000, 200, -20):
			var point := Vector2(x, y)
			var valid := true
			for distance in range(0, 151, 10):
				if not player.is_walkable_footprint(point + direction * distance):
					valid = false
					break
			if valid:
				return point
	return Vector2.ZERO

func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
