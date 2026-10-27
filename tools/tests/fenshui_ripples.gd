extends "res://tools/tests/combat_07_flow.gd"
const FS = preload("res://data/maze/fenshui_roads.gd")

func _combat_scene() -> void:
	await _new_scene()
	_check(maze.player.water_ripples == null,"枯水渠不安装浅水效果")
	maze.capture_flow.set_process(false)
	_check(Run.change_region(sm,"fenshui",Vector2(920,440)).success,"切入分水庭水面")
	await _close_scene()
	maze = load(sm.resume_scene_path()).instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().process_frame
	await get_tree().process_frame
	maze.capture_flow.window_focused = true
	maze.capture_flow.set_process(false)
	var effect = maze.player.water_ripples
	_check(is_instance_valid(effect) and effect.get_index()<maze.player.body.get_index(),"波纹贴脚底并绘制在人物身后")
	Input.action_press("ui_left")
	await get_tree().create_timer(0.48).timeout
	_check(effect.ripples.size()>=2 and effect.ripples.size()<=4,"实际浅水行走按距离产生疏落波纹",{"count":effect.ripples.size()})
	await _capture_image("01_walking_water")
	Input.action_release("ui_left")
	await get_tree().create_timer(0.1).timeout
	var first_serial: int = effect._serial
	var age: float = effect.ripples[0].age
	var center: Vector2 = effect.ripples[0].center
	await get_tree().create_timer(0.1).timeout
	_check(effect._serial==first_serial and effect.ripples[0].age>age and effect.ripples[0].center==center,"停步不生成，余波留在原水面扩散")
	await _capture_image("02_fading_water")
	await get_tree().create_timer(1.0).timeout
	_check(effect.ripples.is_empty(),"停步余波在0.9秒内完全消散")
	await _capture_image("03_stopped_clear")
	maze.player.position = Vector2(725,440)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_press("ui_right")
	await get_tree().create_timer(0.2).timeout
	_check(not effect.ripples.is_empty(),"再次下水恢复波纹")
	# 跨过中央窄岸，按实际地形确认到达陆地之后不再发射。
	var timeout := Time.get_ticks_msec()+2000
	while FS.terrain_multiplier(maze.player.position)<1.0 and Time.get_ticks_msec()<timeout:
		await get_tree().physics_frame
	Input.action_release("ui_right")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(FS.terrain_multiplier(maze.player.position)==1.0,"连续行走上岸")
	first_serial = effect._serial
	await get_tree().create_timer(1.0).timeout
	_check(effect._serial==first_serial and effect.ripples.is_empty(),"上岸不生成且余波消散")
	await _capture_image("04_on_shore")
	maze.player.position = Vector2(920,440)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_press("ui_down")
	await get_tree().create_timer(0.35).timeout
	Input.action_release("ui_down")
	maze.map_ui.open_map()
	age = effect.ripples[0].age
	first_serial = effect._serial
	await get_tree().create_timer(0.25).timeout
	_check(effect.ripples[0].age==age and effect._serial==first_serial,"地图模态冻结波纹与生成")
	await _send_key(KEY_ESCAPE)
	await get_tree().create_timer(1.0).timeout
	_check(not maze.player.input_locked and effect.ripples.is_empty(),"关闭地图恢复且无补发水花")
	maze.player.position = Vector2(920,440)
	await get_tree().process_frame
	await get_tree().process_frame
	maze.player.sprint_held = true
	Input.action_press("ui_left")
	await get_tree().create_timer(0.3).timeout
	_check(maze.player.sprinting and effect.ripples.size()>=2,"冲刺与波纹同时工作")
	await _capture_image("05_sprint_water")
	Input.action_release("ui_left")
	maze.player.clear_combat_input()
	var before: Dictionary = sm.data.duplicate(true)
	effect._process(0.02)
	_check(sm.data==before,"效果更新不写经营或存档状态")
	_check(maze._save_position(),"波纹存在时可正常保存")
	await _close_scene()
	sm.load_data()
	maze = load(sm.resume_scene_path()).instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().process_frame
	await get_tree().process_frame
	_check(maze.player.water_ripples.ripples.is_empty(),"重新加载不恢复过期波纹")
	await _close_scene()
