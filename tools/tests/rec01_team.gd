extends "res://tools/tests/rec01_flow.gd"
const Run = preload("res://scripts/maze/capture_run.gd")
const Roads = preload("res://data/maze/entry_roads.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720), Vector2i(1920,1080)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _team_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _team_flow() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
	sm.data.gold = 10000
	for value in [0.0, 0.2]: sm.recruit(1, func(): return value)
	var rolls := [0.4, 0.0]
	sm.recruit(1, func(): return rolls.pop_front())
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.save()
	await _open_scene()
	var player = scene.get_node("Player")
	var target = scene.get_node("DepartureEntrance")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var modal = hud.confirmation
	_check(modal.visible and player.input_locked, "真实迷宫入口组队锁定输入")
	await _click(modal.slots[0])
	_check(modal.checks.size() == 5, "五人选择列表")
	for id in ["salia", "yufeng", "dingdang", "yaya"]:
		modal.selection_scroll.ensure_control_visible(modal.row_panels[id])
		await get_tree().process_frame
		await _click(modal.checks[id])
	_check(modal.selected == ["salia", "yufeng", "dingdang", "yaya"], "真实鼠标选四人")
	_check(not modal.set_selected("tieshan", true), "已有四人拒绝第五人")
	modal.selection_scroll.scroll_vertical = 0
	await _shot("five_character_selector")
	await _click(modal.selection_done)
	await _shot("four_character_team")
	await _click(modal.slot_names[0])
	_check(modal.details.character_id == "salia", "选队新角色详情")
	await _send_key(KEY_ESCAPE)
	await _click(modal.cancel_button)
	_check(not player.input_locked and sm.remembered_maze_party().is_empty(), "取消恢复输入且不保存草稿")
	await _close_scene()
	_check(sm.request_maze_entry(["salia", "yufeng", "dingdang", "yaya"]).success, "新队伍入场预留")
	_check(Run.begin(sm, Roads.SPAWN).success, "新队伍真实入场事务")
	var run := Run.snapshot(sm)
	_check(Run.valid(run) and run.members[0].element == "thunder" and run.members[1].element == "wind", "新角色元素与探索记录有效")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)) and sm.remembered_maze_party().size() == 4, "新角色探索队伍重载有效")
	var maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.set_process(false)
	var bar = maze.capture_flow.skill_bar
	_check(bar.captions[1].text == "萨莉亚" and bar.rarities[1].visible and bar.rarities[3].visible, "实际战斗栏新角色姓名与稀有度")
	for id in ["salia", "yufeng", "dingdang"]:
		var path: String = "res://assets/ui/combat_skills/"+id+".png"
		_check(Growth.skill_icon_path(id) == path and bar.icons[id] == preload("res://scripts/ui/components/bag_icon_display.gd").texture(load(path)), "实际技能栏使用正式图标:"+id)
	await _shot("maze_party_badges")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	event.position = bar.buttons[1].get_global_rect().get_center()
	get_viewport().push_input(event)
	await get_tree().process_frame
	_check(maze.capture_flow.character_details.visible and maze.capture_flow.character_details.character_id == "salia", "实际战斗栏双击新角色详情")
	await _shot("maze_new_character_details")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked, "迷宫详情退出恢复输入")
	maze.return_to_restaurant(false)
	await get_tree().create_timer(1.5).timeout
	_check(sm.maze_exploration_state().region == "restaurant" and not Run.snapshot(sm).active, "实际退出探索回餐厅")
	sm.load_data()
	_check(sm.owned_characters().size() == 5 and sm.remembered_maze_party().size() == 4 and sm.maze_exploration_state().region == "restaurant", "退出后读档保持收藏与四人队伍")
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.queue_free()
	await get_tree().process_frame
