extends "res://tools/tests/combat_02_flow.gd"
func shift(on: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=KEY_SHIFT
	event.physical_keycode=KEY_SHIFT
	event.pressed=on
	get_viewport().push_input(event)
func _combat_scene() -> void:
	await _new_scene()
	await get_tree().create_timer(0.6).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	var player=maze.player
	var wind=player.get_node("SprintWind")
	_check(wind.get_script()==load("res://scripts/characters/sprint_wind.gd"),"复用餐厅原风线组件")
	player.position=Vector2(860,295)
	maze.camera.snap_to_target()
	Input.action_press("ui_left")
	await get_tree().create_timer(0.05).timeout
	_check(wind.strength==0,"普通走路无风线")
	shift(true)
	await get_tree().create_timer(0.1).timeout
	_check(player.sprinting and wind.strength>0.5,"Shift移动显示餐厅同款风线")
	_check(is_equal_approx(wind.scale.x,0.85/maze.camera.zoom.y),"风线按主角镜头比例缩放")
	await _capture_image("maze_shift_wind")
	shift(false)
	await get_tree().create_timer(0.2).timeout
	_check(wind.strength==0,"松开Shift风线淡出")
	player.position=Vector2(860,295)
	shift(true)
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_left")
	await get_tree().create_timer(0.2).timeout
	_check(wind.strength==0,"按住Shift但停步时无风线")
	player.position=Vector2(860,295)
	Input.action_press("ui_left")
	await get_tree().create_timer(0.1).timeout
	sm.data[Run.KEY].combat.sprint=0
	await get_tree().create_timer(0.2).timeout
	_check(not player.sprinting and wind.strength==0,"体力耗尽且Shift仍按住时无风线")
	shift(false)
	sm.data[Run.KEY].combat.sprint=1
	player.position=Vector2(860,295)
	shift(true)
	await get_tree().create_timer(0.1).timeout
	player.input_locked=true
	await get_tree().create_timer(0.2).timeout
	_check(wind.strength==0,"交互锁定后风线消失")
	shift(false)
	Input.action_release("ui_left")
	await _capture_image("maze_wind_off")
	await _close_scene()
