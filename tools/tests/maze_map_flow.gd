extends "res://tools/tests/ch2_chest_flow.gd"
const MapProjection := preload("res://data/maze/entry_map_projection.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_check_exploration_reveal()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await get_tree().process_frame
			await _map_walkthrough()
			if failures: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trajectory":trajectory,"display":DisplayServer.get_name()}, "\t"))
	print("MAZE_MAP ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _map_walkthrough() -> void:
	_completed()
	sm._active_save_path = "user://save.json"
	_check(ProjectSettings.globalize_path(sm.active_save_path()).replace("\\","/").begins_with(OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/")), "实际写入档位处于隔离目录", {"path":ProjectSettings.globalize_path(sm.active_save_path())})
	_check(sm.save(), "建立本分辨率独立存档")
	await _open_scene()
	await _enter_from_restaurant()
	if failures: return
	var map = maze.map_ui
	await RenderingServer.frame_post_draw
	_check(map.mini_button.is_visible_in_tree() and map.mini_button.position == Vector2(map.size.x-120,20), "圆形局部小地图固定右上角")
	_check(map.mini_view.size == Vector2(100,100) and map.mini_view.marker_position() == Vector2(50,50), "100像素局部视野主角位于圆心")
	_check(map.mini_button.get_children().all(func(c): return not c is Label), "常驻小地图没有文字说明")
	await _click_map_corner()
	_check(not map.expanded, "圆形之外的透明四角点击不打开地图")
	await _prompt_overlap_check()
	_check(map.mini_view.unlocked, "沿用旧盐池解锁状态")
	_check(map.visible_resources.any(func(r): return r.id == "entry_corridor_north"), "揭示长廊显示未领宝箱")
	_check(map.visible_resources.all(func(r): return r.kind == "chest"), "小地图与全图均隐藏挖掘点")
	_check(map.visible_resources.size() == 5, "当前可走区域五个未领取宝箱显示")
	var tracker = maze.task_tracker
	_check(tracker.get_script() == load("res://scripts/ui/order_tracking.gd") and tracker.is_visible_in_tree(), "左上角复用餐厅任务组件")
	_check(sm.has_unread_quests(), "进入迷宫不会自动清除未读任务")
	await _click(tracker._task_button)
	_check(tracker._expanded and not sm.has_unread_quests(), "主动展开当前任务后才标记已读")
	_check(sm.active_save_path() == "user://save.json", "任务已读事务保留隔离档位")
	_check(tracker._exploration_task.visible, "迷宫展示同一探索任务")
	await get_tree().create_timer(0.3).timeout
	await _shot("current_tasks")
	await _shot("mini_spawn")
	await _modal_checks()
	if failures: return
	var trunk: PackedVector2Array = Roads.roads()[0].points
	await _route(trunk.slice(2,5), "corridor_dig")
	await get_tree().process_frame
	await _check_marker("corridor", Vector2(1450,200), 4.0)
	for keys in [[KEY_W],[KEY_D],[KEY_S],[KEY_A],[KEY_W,KEY_D],[KEY_S,KEY_A]]:
		await _hold(keys,0.055)
		await get_tree().process_frame
		_check(map.mini_view.facing.is_equal_approx(maze.player.facing), "按键转向同步：" + str(keys))
		var direction: Vector2 = map.mini_view.facing
		await get_tree().create_timer(0.07).timeout
		_check(map.mini_view.facing == direction, "停下保留朝向")
		await _shot("direction_" + str(keys))
	await _move_to(Vector2(933,269), "dig_recenter")
	await get_tree().process_frame
	_check(is_instance_valid(maze.dig_target) and maze.dig_target.site_id == "entry_dig_west_fork", "道路靠近真实挖掘点")
	await RenderingServer.frame_post_draw
	var dig_prompt: Sprite2D = maze.dig_target.prompt
	var expected_prompt: Vector2 = maze.dig_target.get_global_transform_with_canvas() * Vector2(0,-48)
	_check(dig_prompt.get_parent() == maze._prompt_host and dig_prompt.global_position.distance_to(expected_prompt) < 0.1, "挖掘E提示提升到小地图上层且保留世界锚点")
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_dig_site_claimed("entry_dig_west_fork"), "按E真实领取木材")
	_check(not map.visible_resources.any(func(r): return r.id == "entry_dig_west_fork"), "领取成功立即移除挖掘图标")
	await get_tree().process_frame
	_check(map.mini_button.disabled, "奖励弹窗阻止叠开地图")
	_check(not maze._task_host.visible and tracker._task_button.disabled, "奖励期间任务入口隐藏并禁用")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked, "原奖励弹窗关闭恢复移动")
	_check(maze._task_host.visible and not tracker._task_button.disabled, "奖励关闭恢复任务入口")
	await _route(trunk.slice(5,8), "north_chest")
	await _move_to(Vector2(750,352), "north_chest_side")
	await get_tree().process_frame
	_check(is_instance_valid(maze.chest_target), "连续行走靠近宝箱")
	_check(maze.chest_target.prompt.get_parent() == maze._prompt_host, "宝箱E提示位于小地图上层")
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_chest_claimed("entry_corridor_north"), "按E真实开箱")
	_check(not map.visible_resources.any(func(r): return r.id == "entry_corridor_north"), "宝箱成功领取移除图标")
	await _click(maze.loot_modal._confirm_button)
	await _click(map.mini_button)
	await _shot("claimed_map")
	await _send_key(KEY_ESCAPE)
	await _route(trunk.slice(8), "ring_north")
	await _check_marker("ring_north", Vector2(1350,243), 4.0)
	var ring: PackedVector2Array = Roads.roads()[1].points
	await _route(ring.slice(1,9), "west_fork")
	await _check_marker("west_fork", Vector2(1270,337), 4.0)
	await _exit_marker_checks()
	await _route(ring.slice(9,19), "gate_junction")
	await _route(Roads.roads()[4].points, "gate")
	await _check_marker("gate", Vector2(1340,497), 5.0)
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and map.mini_button.disabled, "原栅栏确认与地图互斥")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked, "取消通行恢复移动")
	await _route(_reversed(Roads.roads()[4].points), "gate_return")
	await _route(ring.slice(19,22), "south_rim")
	await _check_marker("south_rim", Vector2(1430,579), 5.0)
	await _route(ring.slice(22,30), "east_rim")
	await _check_marker("east_rim", Vector2(1545,421), 5.0)
	await _click(map.mini_button)
	await _shot("fogged_position")
	await _send_key(KEY_ESCAPE)
	_check(maze._save_position(), "保存真实行走位置")
	var saved_position: Vector2 = maze.player.position
	await _close_scene()
	sm.load_data()
	scene = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	maze = scene
	await get_tree().process_frame
	await get_tree().process_frame
	map = maze.map_ui
	_check(maze.player.position.distance_to(saved_position) < 0.1, "读档恢复当前位置")
	_check(not map.visible_resources.any(func(r): return r.id in ["entry_corridor_north","entry_dig_west_fork"]), "读档保持已领取标记消失")
	await _click(map.mini_button)
	_check(map.expanded and map.full_view.unlocked, "读档后默认浅层与既有迷雾")
	await _shot("reloaded_map")
	await _send_key(KEY_ESCAPE)
	await _close_scene()
	maze = null

func _check_exploration_reveal() -> void:
	var projection := MapProjection.new()
	var samples := 0
	var covered: Array = []
	var unmapped: Array = []
	# 实际可走脚底网格，包括道路两侧；不只验证几个中心点。
	for y in range(0, int(Roads.SIZE.y), 4):
		for x in range(0, int(Roads.SIZE.x), 4):
			var point := Vector2(x,y)
			if Roads.is_walkable(point):
				samples += 1
				var atlas := projection.project(point)
				if atlas == Vector2(1554,139) and point.distance_to(Roads.ENTRANCE) > 1.0:
					unmapped.append(str(point))
				if not MapProjection.is_revealed(atlas, true):
					covered.append(str(point))
	_check(samples > 1000 and covered.is_empty(), "全部当前可走脚底网格均露出", {"samples":samples, "covered":covered.slice(0,10)})
	_check(unmapped.is_empty(), "全部可走脚底均有映射，不错误回落入口", {"unmapped":unmapped.slice(0,30)})
	for point in [Vector2(1460,415),Vector2(1470,470),Vector2(1495,530),Vector2(1370,75),Vector2(1130,260),Vector2(975,100),Vector2(1150,100),Vector2(1600,580)]:
		_check(MapProjection.is_revealed(point,true), "红线区域完整揭示，包括道路外地形：" + str(point))
		_check(not MapProjection.is_revealed(point,false), "未解锁时不揭示区域：" + str(point))
	for point in [Vector2(1386,723),Vector2(218,157),Vector2(444,188),Vector2(275,641),Vector2(842,775),Vector2(151,840),Vector2(1200,50),Vector2(1640,680)]:
		_check(not MapProjection.is_revealed(point,true), "非道路未解锁区域仍遮挡：" + str(point))

func _exit_marker_checks() -> void:
	await _route(Roads.roads()[2].points.slice(1,6), "minimap_exit_approach")
	await _move_to(Vector2(4,699), "minimap_exit_edge")
	await _hold([KEY_A],0.12)
	await get_tree().process_frame
	await _check_marker("left_exit_edge", Vector2(1157,414), 5.0)
	var map = maze.map_ui
	var before: Vector2 = map.mini_view.atlas_position
	var stationary: Vector2 = maze.player.position
	await _click(map.mini_button)
	_check(map.expanded and map.full_view.atlas_position.distance_to(before) < 0.1, "出口边缘展开全图保持同一位置")
	await _shot("left_exit_expanded")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked and maze.player.position == stationary, "出口边缘关闭地图恢复输入且不移动角色")
	var jump := 0.0
	_set_keys([KEY_D])
	for frame in 12:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var current: Vector2 = map.mini_view.atlas_position
		jump = maxf(jump,current.distance_to(before))
		before = current
	_set_keys([])
	_check(maze.player.position.x > 15 and jump < 10.0, "从出口边缘走回道路时小地图连续移动", {"max_jump":jump,"world":str(maze.player.position)})
	await _move_to(Vector2(57,711), "minimap_exit_return")
	await _route(_reversed(Roads.roads()[2].points.slice(0,6)), "minimap_exit_to_fork")

func _enter_from_restaurant() -> void:
	await _restaurant_to_entrance()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var player = scene.get_node("Player")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	var entrance_button: Control = ui._buttons[scene.get_node("DepartureEntrance")]
	var before: Dictionary = sm.data.duplicate(true)
	var position_before: Vector2 = player.position
	await _hold([KEY_E],0.25)
	_check(hud.confirmation.visible and hud.question.text == "是否前往迷宫？" and not Transition.is_active(get_tree()), "长按一次E仅打开迷宫二次确认")
	_check(hud.cancel_button.has_focus() and player.input_locked and not player.is_physics_processing(), "默认取消焦点并锁住餐厅移动")
	_check(not entrance_button.visible, "确认期间隐藏入口E按钮")
	await _hold([KEY_A],0.1)
	_check(player.position == position_before, "确认期间移动不穿透")
	await _shot("restaurant_maze_confirmation")
	await _click(hud.cancel_button)
	_check(not hud.confirmation.visible and not player.input_locked and player.is_physics_processing() and sm.data == before, "鼠标取消留餐厅且恢复输入不改进度")
	await _click(entrance_button)
	_check(hud.confirmation.visible and not Transition.is_active(get_tree()), "鼠标入口同样先二次确认")
	await _send_key(KEY_ESCAPE)
	_check(not hud.confirmation.visible and not player.input_locked and sm.data == before, "Esc取消不转场不改进度")
	await _send_key(KEY_E)
	if suffix == "_1152x648":
		await _click(hud.confirm_button)
	else:
		await _send_key(KEY_E)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")) and not Transition.is_active(get_tree()),240), "鼠标或再次E确认后进入迷宫并完成转场")
	maze = get_tree().get_first_node_in_group("maze_entry")
	scene = maze
	await RenderingServer.frame_post_draw

func _check_marker(label: String, expected: Vector2, tolerance: float) -> void:
	await get_tree().process_frame
	var map = maze.map_ui
	_check(map.mini_view.atlas_position.distance_to(expected) < tolerance, "总图地标校准：" + label, {"atlas":str(map.mini_view.atlas_position), "world":str(maze.player.position)})
	_check(map.mini_view.facing.is_equal_approx(maze.player.facing), "行走朝向同步：" + label)
	_check(map.mini_view.marker_position() == map.mini_view.size * 0.5, "移动后主角仍在圆心：" + label)
	var offset: Vector2 = map.mini_view.to_view(map.mini_view.atlas_position + Vector2(50,0)) - map.mini_view.marker_position()
	_check(offset.is_equal_approx(Vector2(50.0 * 100.0 / 290.0,0)), "固定半径且地图北朝上：" + label)
	await _shot("landmark_" + label)

func _modal_checks() -> void:
	var map = maze.map_ui
	var before: Dictionary = sm.data.duplicate(true)
	var position_before: Vector2 = maze.player.position
	await _click(map.mini_button)
	_check(map.expanded and map.overlay.visible and maze.player.input_locked, "鼠标打开浅层全图并锁移动")
	_check(not maze._task_host.visible and not maze.task_tracker._expanded, "展开全图时任务详情收起并隔离输入")
	_check(Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(map.full_view.get_global_rect()), "完整地图不越屏")
	_check(map.full_view.size.x > 650 and map.full_view.size.y > 360, "全图等比展开到可读尺寸")
	_check(map.full_view.atlas_position == map.mini_view.atlas_position, "小图与全图坐标一致")
	await _shot("expanded_shallow")
	await _click(map.deep_button)
	_check(map.expanded and map.locked_toast.visible and map.locked_toast.text == "深层暂未解锁", "深层按钮准确提示并保留浅层")
	await _shot("deep_locked")
	await _hold([KEY_A, KEY_E],0.2)
	_check(maze.player.position == position_before and not maze.confirmation.visible and not maze.loot_modal.visible, "地图输入不穿透移动或交互")
	await _click_loot_backdrop()
	_check(map.expanded, "点击暗幕不穿透场景")
	for i in 5:
		await _send_key(KEY_TAB)
		_check(get_viewport().gui_get_focus_owner() in [map.shallow_button,map.deep_button,map.close_button], "焦点限制地图内")
	await _click(map.close_button)
	_check(not map.expanded and not maze.player.input_locked and maze.player.is_physics_processing(), "点击关闭恢复原输入")
	_check(sm.data == before, "查看地图及未解锁提示不修改存档")
	await _click(map.mini_button)
	await _send_key(KEY_ESCAPE)
	_check(not map.expanded and not maze.player.input_locked, "重复打开Esc关闭")
	# 在隔离内存中模拟缺失解锁，不落盘，检验遮挡与资源一起收起。
	var map_state: Dictionary = sm.data[sm.WRAPUP_KEY].duplicate(true)
	sm.data[sm.WRAPUP_KEY].map.unlocked_floors = []
	map.refresh_resources()
	await get_tree().process_frame
	_check(map.visible_resources.is_empty() and not map._unlocked, "未解锁状态不泄露资源或地形")
	sm.data[sm.WRAPUP_KEY] = map_state
	map.refresh_resources()

func _click_map_corner() -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = maze.map_ui.mini_button.global_position + Vector2(2,2)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame

func _click(control: Control) -> void:
	if not is_instance_valid(maze) or control != maze.map_ui.mini_button:
		await super._click(control)
		return
	# E按钮现在会覆盖圆心附近；从未被遮挡的上半圆打开地图。
	var point := control.global_position + Vector2(control.size.x * 0.5,24)
	get_viewport().warp_mouse(point)
	await get_tree().process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		get_viewport().push_input(event)
		await get_tree().process_frame

func _prompt_overlap_check() -> void:
	await RenderingServer.frame_post_draw
	var map = maze.map_ui
	var button: Control = maze.entrance_prompt.button
	var overlap := button.get_global_rect().intersection(map.mini_button.get_global_rect())
	var hit := Vector2(-1,-1)
	for y in range(int(overlap.position.y)+2,int(overlap.end.y)-2,2):
		for x in range(int(overlap.position.x)+2,int(overlap.end.x)-2,2):
			if map.mini_button._has_point(Vector2(x,y)-map.mini_button.global_position):
				hit = Vector2(x,y)
	if hit.x < 0:
		_check(maze.entrance_prompt.visible, "缩小后入口E按钮完整可见")
		await _shot("prompt_beside_minimap")
		await _click(button)
		_check(maze.confirmation.visible and not map.expanded, "缩小后E按钮仍正常触发交互")
		await _send_key(KEY_ESCAPE)
		return
	_check(maze.entrance_prompt.visible, "真实入口E按钮与圆形小地图存在重叠")
	await _shot("prompt_over_minimap")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = hit
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
	_check(maze.confirmation.visible and not map.expanded, "点击重叠区优先触发E交互而非展开地图")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked and maze.entrance_prompt.visible, "取消通行后恢复移动与上层E按钮")

