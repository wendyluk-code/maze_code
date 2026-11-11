extends "res://tools/tests/yufeng_sitting_flow.gd"

func _read_phase(expected: String) -> void:
	if expected != "clue":
		await super._read_phase(expected)
		return
	var e = maze.yf_encounter
	_check(e.clue_modal.visible and maze.player.input_locked,"调查直接显示说明弹窗")
	_check(e.clue_modal._title_label.text == "发现线索" and "\n" not in e.clue_modal._body_label.text,"发现线索标题，正文不分段")
	_check(get_viewport().get_visible_rect().encloses(e.clue_modal._panel.get_global_rect()),"说明完整位于视口内")
	_check(sm.warehouse_snapshot().get("insulating_leaf",0) == 0 and not sm.data.has("pool_clue_reward_granted_v1"),"调查不发绝缘叶，不建立奖励凭证")
	_check(not sm.data.has("story_notebook_v1"),"新调查不创建记录本状态")
	_check(maze.find_child("StoryNotebookEntry",true,false) == null,"迷宫没有记录本入口")
	_check(not e.clue_glow.visible,"调查后隐藏光点")
	_check("奖励" not in e.clue_modal._body_label.text and "绝缘叶" not in e.clue_modal._body_label.text,"说明弹窗没有奖励文案")
	await _capture_image("clue_without_notebook")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _click(e.clue_modal._confirm_button)
	await get_tree().process_frame
	_check(e.phase == "clue" and e.clue_modal.visible and sm.data == before,"确认保存失败停留说明，不丢进度")
	sm._active_save_path = path
	await _click(e.clue_modal._confirm_button)
	_check(e.phase == "report" and not maze.player.input_locked,"确认说明后直接进入回报，无解锁演出")

func _edge_checks() -> void:
	await super._edge_checks()
	for stage in ["clue","unlock","reward"]:
		_prepare_trip()
		sm.data[Story.KEY] = Story.fresh("clue")
		sm.data[Story.KEY].frog_defeated = true
		sm.data["story_notebook_v1"] = {"version":1,"clues":["pool_light"],"presentation":stage}
		sm.data.warehouse_stock["insulating_leaf"] = 3
		sm.save()
		sm.load_data()
		await _open_map()
		var e = maze.yf_encounter
		_check(e.clue_modal.visible and maze.find_child("StoryNotebookEntry",true,false) == null,"旧中断存档直接恢复说明："+stage)
		await _click(e.clue_modal._confirm_button)
		_check(e.phase == "report" and sm.warehouse_snapshot().get("insulating_leaf",0) == 3,"旧中断存档继续且不重复奖励："+stage)
		_check(not sm.data.has("pool_clue_reward_granted_v1"),"旧存档不创建调查奖励凭证："+stage)
		await _close_map()
	# 生产餐厅没有入口或记录本控制器，现有菜谱保持。
	sm.data[sm.MAZE_STATE_KEY].region = "restaurant"
	sm.data[Run.KEY].active = false
	sm.data["first_business_intro_pending"] = false
	var restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	await get_tree().create_timer(0.5).timeout
	_check(restaurant.find_child("StoryNotebookEntry",true,false) == null,"餐厅没有记录本入口")
	_check(restaurant.find_child("RecipeEntry",true,false) != null,"餐厅原有菜谱入口保留")
	await _capture_image("restaurant_without_notebook")
	restaurant.queue_free()
	await get_tree().create_timer(1.3).timeout
	_prepare_trip()
	sm.data[Story.KEY] = Story.fresh("investigate")
	sm.data[Story.KEY].frog_defeated = true
	sm.save()
	await _open_map()
	var encounter = maze.yf_encounter
	encounter._clue_visible = false
	encounter._sync_visuals()
	_check(encounter.clue_glow.visible and is_zero_approx(encounter.clue_glow.modulate.a),"光点首次显示从透明开始")
	await get_tree().create_timer(0.2).timeout
	_check(encounter.clue_glow.modulate.a > 0.0 and encounter.clue_glow.modulate.a < 0.5,"光点渐入中间帧")
	await get_tree().create_timer(0.7).timeout
	_check(encounter.clue_glow.modulate.a > 0.6,"渐入结束恢复微动亮度")
	_check(encounter.clue_prompt.world_anchor == Story.Frog.HOME+Vector2(0,4),"调查提示下移至光点上方")
	await _close_map()
