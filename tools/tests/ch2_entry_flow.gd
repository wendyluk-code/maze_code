extends "res://tools/tests/ch2_entry_state.gd"
const Transition := preload("res://scripts/ui/components/scene_transition.gd")
var maze: Node
var held_keys: Array = []
var trajectory: Array = []
var checkpoint := ""
var captured_encounters: Dictionary = {}
var observed_walk_frames: Dictionary = {}
var captured_walk: Dictionary = {}
var restaurant_appearance: Dictionary = {}

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _walkthrough()
			if failures > 0: break
		await _entry_failure()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trajectory":trajectory,"display":DisplayServer.get_name()},"\t"))
	print("CH2_FLOW ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _walkthrough() -> void:
	captured_encounters.clear()
	observed_walk_frames.clear()
	captured_walk.clear()
	_completed()
	# 使用真实存档槽，以便稍后从标题选择继续。
	sm._active_save_path = "user://save.json"
	_check(sm.save(), "建立隔离可继续存档")
	var baseline: Dictionary = sm.data.duplicate(true)
	await _open_scene()
	_check(not tm.active, "完成第一章后输入已恢复")
	_check(scene.get_node("Player").position.distance_to(Vector2(1000, 850)) < 0.1, "正常进入餐厅保留原出生点")
	await _restaurant_to_entrance()
	if failures > 0: return
	await RenderingServer.frame_post_draw
	restaurant_appearance = _appearance_snapshot(scene.get_node("Player"))
	await _shot("restaurant_reference")
	var restaurant_frames: SpriteFrames = scene.get_node("Player").ANIMATIONS
	var confirmation_script = scene.get_node("Player").get_tree().get_first_node_in_group("restaurant_hud").confirmation.get_script()
	var toast_script = get_tree().get_first_node_in_group("restaurant_hud").toast_label.get_script()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	if suffix == "_1152x648":
		var ui = get_tree().get_first_node_in_group("ui_layer")
		await _click(ui._buttons[scene.get_node("DepartureEntrance")])
	else:
		await _send_key(KEY_E)
	_check(hud.confirmation.visible and not Transition.is_active(get_tree()), "鼠标或一次E先打开迷宫二次确认")
	await _click(hud.confirm_button)
	await _observe_transition("to_maze")
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")), 240), "直接进入正式迷宫")
	maze = get_tree().get_first_node_in_group("maze_entry")
	if not is_instance_valid(maze): return
	scene = maze
	await get_tree().process_frame
	_check(maze._entry_ready and maze.player.position.distance_to(Roads.SPAWN) < 0.1, "石门前安全出生并首次开始第二章")
	_check(maze.player.position == Vector2(1088, 170) and Roads.is_walkable(maze.player.position), "出生脚底下移到红框内的安全路面")
	_check(not maze.toast_label.visible and maze.last_message.is_empty(), "首次进入迷宫不显示顶部进图Toast")
	await _shot("stone_gate_spawn")
	_check(maze.player.ANIMATIONS == restaurant_frames, "餐厅转场后共用同一新版动画资源")
	await _maze_idle_and_lock()
	await get_tree().create_timer(0.3).timeout
	_check(is_instance_valid(maze) and maze.player.position.distance_to(Roads.SPAWN) < 0.1, "出生不会自动返回餐厅")
	_check(maze.confirmation.get_script() == confirmation_script and maze.toast_label.get_script() == toast_script, "餐厅迷宫复用同一确认与Toast组件")
	_check(not maze.find_children("*", "Label", true, false).any(func(label): return label.text in ["迷宫浅层 · 旧城长廊", "WASD / 方向键移动    E 交互", "【E】返回餐厅"]), "旧标题操作说明与底部提示已移除")
	_check(not maze.find_children("*", "Button", true, false).any(func(button): return button.text in ["保存", "返回标题"]), "旧保存与返回标题按钮已移除")
	await _destination_ui_checks("餐厅", maze.entrance_prompt)
	await _return_save_failure()
	# 石门到分水庭出口：全部使用移动按键，不传送。
	var trunk: PackedVector2Array = Roads.roads()[0].points
	await _route(trunk.slice(1), "old_corridor")
	await RenderingServer.frame_post_draw
	_check(not maze.entrance_prompt.visible and not maze.workshop_prompt.visible, "离开入口范围隐藏交互按钮")
	var ring: PackedVector2Array = Roads.roads()[1].points
	await _route(ring.slice(1,9), "west_rim")
	await _route(Roads.roads()[2].points.slice(1,6), "exit_approach")
	_check(not maze.trigger_counts.has("exit"), "出口前道路不提前提示分水庭")
	await _move_to(Roads.EXIT, "actual_exit")
	await get_tree().process_frame
	_check(maze.last_message == "分水庭区域制作中" and get_tree().current_scene == maze, "真正图边出口提示且留本图")
	await _shot("fen_shui_exit")
	var exit_count: int = maze.trigger_counts.get("exit",0)
	await get_tree().create_timer(0.5).timeout
	_check(maze.trigger_counts.get("exit",0) == exit_count, "出口停留不刷屏")
	await _route(_reversed(Roads.roads()[2].points.slice(0,6)), "return_from_exit")
	# 从西侧分岔沿环路下半、东半、北半回到同一西侧分岔。
	await _route(ring.slice(9,19), "southwest_rim")
	await _route(Roads.roads()[4].points, "gate_branch")
	await get_tree().process_frame
	_check(not maze.trigger_counts.has("gate"), "靠近栅栏不自动提示未开放")
	await _destination_ui_checks("水轮工坊", maze.workshop_prompt)
	var gate_position: Vector2 = maze.player.position
	await _send_key(KEY_E)
	await _shot("workshop_confirmation")
	await _click(maze.confirmation.confirm_button)
	_check(maze.last_message == "当前区域未开放，以后再来探索吧~" and maze.trigger_counts.get("gate", 0) == 1, "确认后才显示准确未开放文案")
	_check(get_tree().current_scene == maze and maze.player.position == gate_position and not maze.player.input_locked, "确认未开放入口留原图并恢复输入")
	_check(maze.toast_label.is_visible_in_tree() and maze.toast_label.get_global_rect().position.y == 22, "餐厅同款Toast顶部居中显示")
	await _shot("gate_blocked_branch")
	var gate_count: int = maze.trigger_counts.get("gate",0)
	await _hold([KEY_S], 0.55)
	_check(maze.player.position.y <= 1077.1, "持续向下不能穿过栅栏")
	await _hold([KEY_A,KEY_S], 0.45)
	_check(maze.player.position.y <= 1077.1, "斜向无法绕过栅栏")
	await get_tree().create_timer(0.5).timeout
	_check(maze.trigger_counts.get("gate",0) == gate_count, "栅栏停留不重复触发")
	await _move_to(Vector2(653,1064), "gate_recenter")
	await _route(_reversed(Roads.roads()[4].points), "leave_gate")
	await _route(Roads.roads()[4].points, "reenter_gate")
	_check(maze.trigger_counts.get("gate",0) == gate_count, "再次靠近栅栏仍须确认才提示")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	_check(maze.trigger_counts.get("gate",0) == gate_count + 1, "重新E确认可再次提示")
	await _route(_reversed(Roads.roads()[4].points), "gate_to_ring")
	await _route(ring.slice(19,30), "south_and_east_rim")
	await _shot("ring_south_east")
	# 当前位于东环，尝试横穿枯水渠。
	await _hold([KEY_A], 0.8)
	_check(maze.player.position.x > 1060.0 and Roads.is_walkable(maze.player.position), "横穿沟壑被阻挡")
	await _move_to(ring[29], "east_recenter")
	await _route(ring.slice(30), "complete_ring_north")
	await _shot("ring_north")
	await _route(ring.slice(1,9), "ring_closed")
	_check(maze.player.position.distance_to(ring[8]) < 4.0, "完整环路连续输入回到同一分岔")
	_check(is_instance_valid(maze.slime) and maze.slime.visible and not maze.trigger_counts.has("monster") and not maze.trigger_counts.has("team"), "史莱姆保留，魔物与队伍均不触发遭遇占位")
	# 从西环向树林行走不穿林。
	await _route(_reversed(ring.slice(5,9)), "forest_probe_approach")
	await _hold([KEY_A,KEY_W], 0.7)
	_check(maze.player.position.distance_to(ring[5]) < 35.0, "树林斜向不可穿", {"actual":str(maze.player.position)})
	await _shot("forest_boundary")
	await _move_to(ring[5], "forest_recenter")
	await _route(ring.slice(6,9), "west_recenter")
	await _route(ring.slice(9,16), "inner_branch_junction")
	await _route(Roads.roads()[3].points.slice(1), "inner_connected_branch")
	await _shot("inner_branch")
	await _route(_reversed(Roads.roads()[3].points), "inner_return")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var saved_position: Vector2 = maze.player.position
	_check(await _wait_until(func(): return sm.maze_exploration_state().position == [saved_position.x,saved_position.y], 300), "移除按钮后停步自动保存当前有效脚底站位")
	await _shot("saved_position")
	# 重开标题作为读档夹具，地图不再提供返回标题按钮。
	_check(get_tree().change_scene_to_file("res://scenes/start_screen.tscn") == OK, "读档夹具重新打开标题")
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("start_screen")),240), "标题就绪")
	var start = get_tree().get_first_node_in_group("start_screen")
	await _click(start.continue_button)
	await get_tree().process_frame
	# 标题的真实存档槽入口，选择当前隔离旧槽。
	var slot_button: Button = start.save_modal._rows.get("user://save.json")
	_check(slot_button != null, "继续列表显示已存档槽")
	if slot_button == null: return
	await _click(slot_button)
	await _click(start.save_modal._confirm_button)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")),240), "标题继续恢复迷宫")
	maze = get_tree().get_first_node_in_group("maze_entry")
	scene = maze
	_check(maze.player.position.distance_to(saved_position) < 0.1, "读档恢复精确有效站位")
	_check(not maze.toast_label.visible and maze.last_message.is_empty(), "继续迷宫不显示已返回迷宫浅层Toast")
	await _shot("continue_restored")
	await _route(_reversed(ring.slice(0,16)), "return_north")
	await _route(_reversed(trunk.slice(1)), "return_stone_gate")
	for direction in ["front", "back", "left", "right"]:
		var frames: Dictionary = observed_walk_frames.get(direction + "_walk", {})
		_check(frames.size() >= 2, direction + " 连续道路按键移动播放新版行走多帧")
	# 主动 E 打开确认，再新按E返回；未完成探索或第二章，未生成首客。
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and get_tree().current_scene == maze, "回餐厅必须先二次确认")
	await _shot("return_restaurant_confirmation")
	await _send_key(KEY_E)
	await _observe_transition("to_restaurant")
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")),240), "石门主动E返回真实餐厅")
	scene = get_tree().current_scene
	_check(sm.resume_scene_path() == sm.RESTAURANT_SCENE and sm.maze_exploration_state().chapter_2_started, "返回后区域正确且开始标记不丢失")
	_check(sm.quest_snapshot().active.any(func(q): return q.id == "chapter_1_salt_pool") and not sm.data.get("chapter_2_done",false), "全流程不误完成盐池或第二章")
	_check(sm.reputation() == baseline.reputation and sm.inventory_snapshot() == baseline.inventory and sm.waiting_customer_orders().is_empty(), "探索不发奖不产生顾客")
	_check(not tm.active and not scene.get_node("Player").input_locked, "返回餐厅不重播第一章且输入恢复")
	var returned = scene.get_node("Player")
	_check(returned.spawn_ready and returned.position.distance_to(Vector2(210, 940)) < 0.1 and returned.position == scene.get_node("MazeReturnSpawn").position, "返回餐厅落在左侧木门前冰柜左边指定点", {"position": str(returned.position)})
	_check(returned.is_walkable_footprint(returned.position), "返回落点完整脚底在可走路面")
	_check(not get_tree().has_meta("restaurant_return_from_maze"), "成功返回后一次性入口标志已消费")
	await get_tree().create_timer(0.4).timeout
	_check(get_tree().current_scene == scene and not get_tree().get_first_node_in_group("restaurant_hud").confirmation.visible, "返回门前停留不自动打开确认或重新进入迷宫")
	await _shot("returned_restaurant")
	var return_position: Vector2 = returned.position
	await _hold([KEY_S], 0.15)
	_check(returned.position.y > return_position.y + 10 and returned.is_walkable_footprint(returned.position), "返回门前可以按键正常走开")
	await _close_scene()
	await _open_scene()
	_check(scene.get_node("Player").position.distance_to(Vector2(1000, 850)) < 0.1, "普通重新进入餐厅不残留上次迷宫返回标志")
	await _close_scene()

func _reversed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.reverse()
	return result

func _route(points: PackedVector2Array, label: String) -> void:
	for point in points:
		if not await _move_to(point, label): return

func _move_to(point: Vector2, label: String) -> bool:
	checkpoint = label
	var actor = maze.player if is_instance_valid(maze) else scene.get_node("Player")
	for frame in 240:
		var delta: Vector2 = point - actor.position
		if delta.length() <= (3.0 if is_instance_valid(maze) else 5.0):
			_set_keys([])
			if is_instance_valid(maze):
				for kind in ["monster", "team"]:
					var location: Vector2 = Roads.MONSTER if kind == "monster" else Roads.TEAM
					if actor.position.distance_to(location) < 27 and not captured_encounters.has(kind):
						await get_tree().process_frame
						await _shot(kind + "_placeholder")
						captured_encounters[kind] = true
			return true
		var keys: Array = []
		if absf(delta.x) > 2.0: keys.append(KEY_D if delta.x > 0 else KEY_A)
		if absf(delta.y) > 2.0: keys.append(KEY_S if delta.y > 0 else KEY_W)
		_set_keys(keys)
		await get_tree().physics_frame
		if is_instance_valid(maze):
			if not Roads.is_walkable(actor.position):
				_check(false, "移动过程中脚底越界：" + label)
				break
			await _observe_maze_animation()
			var half: Vector2 = get_viewport().get_visible_rect().size / maze.camera.zoom * 0.5
			var center: Vector2 = maze.camera.global_position
			if center.x < half.x - 0.1 or center.y < half.y - 0.1 or center.x > Roads.SIZE.x - half.x + 0.1 or center.y > Roads.SIZE.y - half.y + 0.1:
				_check(false, "移动过程中镜头越图："+label)
				break
		if frame % 20 == 0:
			trajectory.append({"route":label+suffix,"x":actor.position.x,"y":actor.position.y})
	_set_keys([])
	_check(false, "连续输入到达失败："+label, {"target":str(point),"actual":str(actor.position)})
	await _shot("FAILED_"+label)
	return false

func _set_keys(keys: Array) -> void:
	for key in held_keys:
		if key not in keys: _movement_key(key, false)
	for key in keys:
		if key not in held_keys: _movement_key(key, true)
	held_keys = keys.duplicate()

func _movement_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _hold(keys: Array, seconds: float) -> void:
	_set_keys(keys)
	await get_tree().create_timer(seconds).timeout
	_set_keys([])
	await get_tree().physics_frame

func _restaurant_to_entrance() -> void:
	var actor = scene.get_node("Player")
	var target = scene.get_node("DepartureEntrance")
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,91,68)
	grid.cell_size = Vector2(16,16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var end := Vector2i.ZERO
	var best := INF
	for y in 68:
		for x in 91:
			var point := Vector2(x*16,y*16)
			var valid: bool = actor.is_walkable_footprint(point)
			grid.set_point_solid(Vector2i(x,y),not valid)
			var distance := point.distance_to(target.position)
			if valid and distance < best:
				best = distance
				end = Vector2i(x,y)
	var start := Vector2i((actor.position / 16.0).round())
	var path := grid.get_point_path(start,end)
	_check(path.size() > 0 and best < 115, "餐厅出生点到迷宫入口存在脚底安全路线", {"path_points":path.size(),"distance":best,"target":str(target.position),"end":str(end)})
	for point in path:
		if not await _move_to(point,"restaurant_departure"): return
	_check(actor.nearest_interactable() == target, "餐厅路径终点可与迷宫入口交互")

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await super._shot(label)

func _entry_failure() -> void:
	_completed()
	sm._active_save_path = ""
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	scene = maze
	await get_tree().process_frame
	_check(not maze._entry_ready and maze.player.input_locked and not sm.maze_exploration_state().chapter_2_started, "实际地图首次保存失败不开始第二章")
	sm._active_save_path = "user://entry-retry.json"
	var deadline := Time.get_ticks_msec() + 6500
	while not maze._entry_ready and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(maze._entry_ready and not maze.player.input_locked, "移除保存按钮后首次保存失败自动重试并恢复输入", {"retry_seconds": maze._entry_retry_seconds})
	await _close_scene()

func _maze_idle_and_lock() -> void:
	var actor = maze.player
	var origin: Vector2 = actor.position
	var seen := {}
	var until := Time.get_ticks_msec() + 2450
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		seen[actor.animation_frame] = true
	_check(actor.animation_name == &"front_idle" and seen.size() == 4, "迷宫出生播放四帧新版待机循环")
	_check(actor.position == origin, "待机脚底不滑动")
	_check(actor.body.to_global(actor.body.offset + actor.FRAME_FOOT).distance_to(actor.global_position) < 0.01, "迷宫新版人物脚底对齐道路站位")
	var actual := _appearance_snapshot(actor)
	_check(absf(actual.body_height - restaurant_appearance.body_height) < 0.01 and actor.body.position == Vector2.ZERO, "迷宫与餐厅人物屏幕高度相同且无额外跳动", {"restaurant": restaurant_appearance.body_height, "maze": actual.body_height})
	_check(actual.shadow_texture == restaurant_appearance.shadow_texture and actual.shadow_size.distance_to(restaurant_appearance.shadow_size) < 0.01 and actual.shadow_offset.distance_to(restaurant_appearance.shadow_offset) < 0.01, "迷宫共用餐厅阴影贴图、屏幕尺寸与脚底偏移", {"restaurant_size": str(restaurant_appearance.shadow_size), "maze_size": str(actual.shadow_size)})
	actor.input_locked = true
	await _hold([KEY_A], 0.25)
	await get_tree().process_frame
	_check(actor.position == origin and actor.animation_name == &"front_idle", "迷宫输入锁定保持原地待机")
	actor.input_locked = false

func _appearance_snapshot(actor: Node2D) -> Dictionary:
	var visual: Sprite2D = actor.get_node("Body")
	var shadow: Sprite2D = actor.get_node("GroundShadow")
	var shadow_transform := shadow.get_global_transform_with_canvas()
	return {
		"body_height": visual.get_global_transform_with_canvas().y.length() * 300.0,
		"shadow_texture": shadow.texture,
		"shadow_size": Vector2(shadow_transform.x.length(), shadow_transform.y.length()) * shadow.texture.get_size(),
		"shadow_offset": shadow_transform.origin - actor.get_global_transform_with_canvas().origin,
	}

func _observe_maze_animation() -> void:
	var actor = maze.player
	var animation: String = str(actor.animation_name)
	if not animation.ends_with("_walk"):
		return
	if not observed_walk_frames.has(animation):
		observed_walk_frames[animation] = {}
	observed_walk_frames[animation][actor.animation_frame] = true
	if observed_walk_frames[animation].size() >= 2 and not captured_walk.has(animation):
		captured_walk[animation] = true
		_check(not actor.body.flip_h and actor.body.texture == actor.ANIMATIONS.get_frame_texture(actor.animation_name, actor.animation_frame), animation + " 使用独立方向新版帧")
		await _shot("hero_" + animation)
		# 松键后核对保留朝向并切回待机，随后恢复本次行走输入。
		var resume_keys: Array = held_keys.duplicate()
		_set_keys([])
		await get_tree().physics_frame
		await get_tree().physics_frame
		# process_frame 信号早于节点的 _process；断言等待实际显示更新。
		await RenderingServer.frame_post_draw
		_check(actor.animation_name == StringName(animation.replace("_walk", "_idle")), animation + " 松键后同朝向待机", {"actual": str(actor.animation_name), "facing": str(actor.facing), "input": str(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"))})
		await _shot("hero_" + animation.replace("_walk", "_idle"))
		_set_keys(resume_keys)

func _destination_ui_checks(destination: String, prompt: Control) -> void:
	await RenderingServer.frame_post_draw
	_check(prompt.is_visible_in_tree() and prompt.button.get_node("Content/ActionLabel").text == "前往" + destination, destination + " 靠近显示餐厅同款悬浮交互")
	var rect: Rect2 = prompt.button.get_global_rect()
	var projected: Vector2 = get_viewport().get_canvas_transform() * prompt.world_anchor
	_check(rect.size.y == 48 and absf(rect.get_center().x - projected.x) < 1 and absf(rect.end.y + 8 - projected.y) < 1, destination + " 锚定入口世界位置且尺寸固定", {"rect": str(rect), "projected": str(projected)})
	_check(get_viewport().get_visible_rect().encloses(rect), destination + " 提示不越屏幕边界")
	await _shot("prompt_" + ("restaurant" if destination == "餐厅" else "workshop"))
	var origin: Vector2 = maze.player.position
	var previous_count: int = maze.trigger_counts.get("gate", 0)
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and maze.confirmation.question.text == "是否前往%s？" % destination and maze.player.input_locked and not prompt.visible, destination + " E只打开二次确认并隐藏提示锁定移动")
	var repeat := InputEventKey.new()
	repeat.keycode = KEY_E
	repeat.pressed = true
	repeat.echo = true
	get_viewport().push_input(repeat)
	await get_tree().process_frame
	_check(maze.confirmation.visible, destination + " 长按重复E不能确认")
	await _hold([KEY_A], 0.2)
	_check(maze.player.position == origin, destination + " 弹窗期间按移动键不移动")
	await _send_key(KEY_ESCAPE)
	await RenderingServer.frame_post_draw
	_check(not maze.confirmation.visible and not maze.player.input_locked and maze.player.is_physics_processing() and prompt.visible, destination + " Esc取消恢复原输入与悬浮提示")
	await _send_key(KEY_E)
	await _send_key(KEY_ENTER)
	_check(not maze.confirmation.visible and get_tree().current_scene == maze, destination + " 默认Enter执行取消")
	await _click(prompt.button)
	_check(maze.confirmation.visible, destination + " 点击悬浮按钮进入相同确认流程")
	await _click(prompt.button)
	_check(maze.confirmation.visible and maze.player.position == origin, destination + " 弹窗遮罩拦截背后交互")
	await _click(maze.confirmation.cancel_button)
	_check(not maze.confirmation.visible and maze.trigger_counts.get("gate", 0) == previous_count and not maze.toast_label.visible, destination + " 鼠标取消不提示未开放")

func _return_save_failure() -> void:
	var original: String = sm._active_save_path
	sm._active_save_path = ""
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	_check(get_tree().current_scene == maze and not maze.player.input_locked and maze.last_message == "返回进度未保存，请重试", "回餐厅保存失败留原图并恢复输入")
	_check(not Transition.is_active(get_tree()), "保存失败不开始转场、不残留遮罩")
	sm._active_save_path = original

func _observe_transition(label: String) -> void:
	var overlay = get_tree().get_first_node_in_group(Transition.GROUP)
	_check(is_instance_valid(overlay), label + " 通行启动共用转场")
	if not is_instance_valid(overlay): return
	var source_id := get_tree().current_scene.get_instance_id()
	var source_player = get_tree().current_scene.get_node("Player")
	var original_position: Vector2 = source_player.position
	var switches: Array = []
	var switched := func(): switches.append({"alpha": overlay.curtain.color.a, "scene": get_tree().current_scene.scene_file_path})
	get_tree().scene_changed.connect(switched)
	_check(await Transition.change_scene(get_tree(), load("res://scenes/maze_entry.tscn")) == ERR_BUSY, label + " 转场期间重复切图被拒绝")
	_set_keys([KEY_D])
	await _send_key(KEY_E)
	var captures := {}
	var phases := {}
	var locked := true
	var stationary := true
	var target_origin := Vector2.ZERO
	var deadline := Time.get_ticks_msec() + 5000
	while Transition.is_active(get_tree()) and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(overlay): break
		var active = get_tree().current_scene
		if not is_instance_valid(active): continue
		var actor = active.get_node_or_null("Player")
		if overlay.phase != "finished" and is_instance_valid(actor):
			locked = locked and actor.input_locked and not actor.is_physics_processing()
			if active.get_instance_id() == source_id:
				stationary = stationary and actor.position == original_position
			else:
				if target_origin == Vector2.ZERO: target_origin = actor.position
				stationary = stationary and actor.position == target_origin
		if overlay.phase == "fade_in": _set_keys([])
		var alpha: float = overlay.curtain.color.a
		if alpha > 0.15 and alpha < 0.9:
			phases[overlay.phase] = true
			if not captures.has(overlay.phase):
				captures[overlay.phase] = true
				var frame := get_viewport().get_texture().get_image()
				DirAccess.make_dir_recursive_absolute(evidence)
				frame.save_png(evidence.path_join(label + "_" + overlay.phase + suffix + ".png"))
	_set_keys([])
	get_tree().scene_changed.disconnect(switched)
	_check(not Transition.is_active(get_tree()), label + " 动画完成后移除遮罩")
	_check(phases.has("fade_out") and phases.has("fade_in"), label + " 实际渲染渐隐与渐显中间帧")
	_check(switches.size() == 1 and is_equal_approx(switches[0].alpha, 1.0), label + " 全遮盖时只切换一次场景", {"switches": switches})
	_check(locked and stationary, label + " 两侧人物转场中锁定且方向键不能移动")
	var target = get_tree().current_scene.get_node("Player")
	_check(not target.input_locked and target.is_physics_processing(), label + " 动画结束恢复新场景人物输入")
	await get_tree().process_frame
