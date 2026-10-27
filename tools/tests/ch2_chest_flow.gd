extends "res://tools/tests/ch2_entry_flow.gd"
const Chests := preload("res://data/maze/entry_chests.gd")
var opened := 0

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await get_tree().process_frame
			await _chest_walkthrough()
			if failures > 0: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trajectory":trajectory,"display":DisplayServer.get_name()},"\t"))
	print("CH2_CHEST_FLOW ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _enter_from_restaurant() -> void:
	await _restaurant_to_entrance()
	await _send_key(KEY_E)
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.confirmation.visible and not Transition.is_active(get_tree()), "餐厅一次E打开迷宫二次确认")
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")) and not Transition.is_active(get_tree()),240), "确认进入迷宫并完成转场")
	maze = get_tree().get_first_node_in_group("maze_entry")
	scene = maze
	await RenderingServer.frame_post_draw
	_check(not maze.toast_label.visible, "首次及再次进入迷宫不弹进图Toast")

func _chest_walkthrough() -> void:
	opened = 0
	captured_encounters.clear()
	_completed()
	sm._active_save_path = "user://save.json"
	_check(sm.save(), "建立本分辨率全新隔离旧槽")
	await _open_scene()
	await _enter_from_restaurant()
	if failures: return
	_check(maze.chests.size() == 5 and _prompt_count() == 0, "石门出生五箱存在且远处E隐藏")
	_check(maze.entrance_prompt.visible and maze.entrance_prompt.button.get_node("Content/ActionLabel").text == "前往餐厅", "石门E原样保留")
	await _shot("stone_gate_original_e")
	var trunk: PackedVector2Array = Roads.roads()[0].points
	var ring: PackedVector2Array = Roads.roads()[1].points
	await _route(trunk.slice(1,8), "corridor_to_north_chest")
	await _move_to(Vector2(750,352), "north_chest_side")
	await _collect("entry_corridor_north", true)
	if failures: return
	await _route(trunk.slice(8), "corridor_to_ring")
	await _route(ring.slice(1,8), "west_chest")
	await _collect("entry_west_fork")
	if failures: return
	await _route(ring.slice(8,16), "inner_junction")
	await _route(Roads.roads()[3].points.slice(1), "inner_dead_end_chest")
	await _move_to(Vector2(773,658), "inner_chest_side")
	await _collect("entry_inner_end")
	if failures: return
	await _route(_reversed(Roads.roads()[3].points), "inner_return")
	await _route(ring.slice(16,21), "south_chest")
	await _move_to(Vector2(834,1192), "south_chest_side")
	await _collect("entry_south_rim")
	if failures: return
	await _route(ring.slice(21,35), "east_chest")
	await _move_to(Vector2(1048,630), "east_chest_side")
	await _collect("entry_east_rim")
	if failures: return
	_check(sm.gold_balance() == 500 and sm.data.claimed_chests.size() == 5 and _visible_chests() == 0, "沿合法路面收集五箱总额500，全部消失")
	await _shot("all_five_claimed")
	# 主界面已取消标题按钮；用夹具重新启动标题，再通过真实选档界面读盘。
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("start_screen")),240), "夹具重启标题，随后验证真实选档读盘")
	var start = get_tree().get_first_node_in_group("start_screen")
	await _click(start.continue_button)
	await get_tree().process_frame
	var slot: Button = start.save_modal._rows.get("user://save.json")
	_check(slot != null, "标题列表存在当前测试档")
	if slot == null: return
	await _click(slot)
	await _click(start.save_modal._confirm_button)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")),240), "真实选档继续迷宫")
	maze = get_tree().get_first_node_in_group("maze_entry")
	scene = maze
	_check(sm.gold_balance() == 500 and maze.chests.is_empty(), "读档金币500且五箱不刷新")
	await _shot("continue_no_respawn")
	await _route(ring.slice(35), "return_north_arc")
	await _route(_reversed(trunk.slice(1)), "return_stone_gate")
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and maze.player.input_locked, "原石门E打开目的地确认")
	await _send_key(KEY_ESCAPE)
	_check(not maze.confirmation.visible and not maze.player.input_locked, "取消目的地确认恢复移动")
	await _send_key(KEY_E)
	_check(maze.confirmation.visible, "再次确认返回餐厅")
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")) and not Transition.is_active(get_tree()),240), "原石门E返回餐厅并完成转场")
	scene = get_tree().current_scene
	maze = null
	_check(sm.gold_balance() == 500, "餐厅金币保持500")
	await _enter_from_restaurant()
	_check(sm.gold_balance() == 500 and maze.chests.is_empty(), "餐厅再次进入不重生、不重复发奖")
	await _shot("reenter_no_respawn")
	await _close_scene()
	maze = null

func _prompt_count() -> int:
	var count := 0
	for chest in maze.chests:
		if chest.prompt.is_visible_in_tree(): count += 1
	return count

func _visible_chests() -> int:
	var count := 0
	for chest in maze.chests:
		if chest.visible: count += 1
	return count

func _collect(id: String, probe_failure := false) -> void:
	await get_tree().process_frame
	_check(Roads.is_walkable(maze.player.position), "宝箱从合法路面靠近：" + id)
	_check(is_instance_valid(maze.chest_target) and maze.chest_target.chest_id == id and _prompt_count() == 1, "最近且唯一宝箱显示专用E：" + id)
	if not is_instance_valid(maze.chest_target): return
	var chest = maze.chest_target
	await get_tree().create_timer(0.5).timeout
	var first_frame: int = chest.sprite.frame
	await _shot(id + "_near_a")
	await get_tree().create_timer(0.18).timeout
	_check(chest.sprite.frame != first_frame and chest.sprite.is_playing(), "宝箱动画帧发生变化：" + id)
	await _shot(id + "_near_b")
	if probe_failure:
		# 仅此仲裁夹具临时放置第二个物件；五个正式箱的到达仍全部沿路输入。
		var adjacent = maze.chests[1]
		var original_position: Vector2 = adjacent.position
		adjacent.position = maze.player.position + Vector2(10,0)
		maze._update_chest_target()
		_check(maze.chest_target == adjacent and _prompt_count() == 1, "相邻两箱只提示最近有效目标")
		adjacent.hide()
		maze._update_chest_target()
		_check(maze.chest_target == chest and _prompt_count() == 1, "已隐藏箱不参与最近目标仲裁")
		adjacent.position = original_position
		adjacent.show()
		maze._update_chest_target()
		# 向来路后退，再沿同一合法路面靠近；验证离开半径隐藏。
		await _move_to(Vector2(790,326), "north_chest_far")
		await get_tree().process_frame
		_check(not chest.prompt.visible, "远离宝箱隐藏E")
		await _shot("north_chest_far")
		await _move_to(Vector2(750,352), "north_chest_reapproach")
		var snapshot: Dictionary = sm.data.duplicate(true)
		var path: String = sm.active_save_path()
		var original_bytes := FileAccess.get_file_as_bytes(path)
		DirAccess.make_dir_recursive_absolute(path + ".tmp")
		await _send_key(KEY_E)
		_check(chest.visible and not maze.loot_modal.visible and sm.data == snapshot and sm.gold_balance() == 0, "真实E遇文件写入失败：不消失、不加金币、不打开成功弹窗")
		_check(FileAccess.get_file_as_bytes(path) == original_bytes and not maze.player.input_locked and "保存失败" in maze.last_message, "失败保留原盘、恢复移动、可见重试反馈")
		await _shot("save_failure_retryable")
		DirAccess.remove_absolute(path + ".tmp")
	_movement_key(KEY_E, true)
	await get_tree().process_frame
	await get_tree().process_frame
	opened += 1
	_check(maze.loot_modal.visible and not chest.visible and sm.gold_balance() == opened*100 and sm.is_chest_claimed(id), "新按E原子领取100并显示弹窗：" + id)
	var before: Vector2 = maze.player.position
	var modal = maze.loot_modal
	var window := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_check(window.encloses(modal._panel.get_global_rect()), "完整奖励弹窗位于窗口内：" + id)
	_check(modal.item_views.size() == 1 and modal.item_views[0].name.text == "金币" and modal.item_views[0].quantity.text == "×100" and modal.item_views[0].icon.texture.atlas.resource_path.ends_with("gold_coin.png"), "弹窗准确金币图标和数量：" + id)
	_check(modal._body_label.text.is_empty() and not modal._body_label.visible and modal._title_label.text == "获得物品" and modal._confirm_button.text == "收下", "精简模板不显示余额与操作说明：" + id)
	_check(modal.item_views[0].icon.size == Vector2(43,43), "奖励图标与料理选择同为43像素：" + id)
	_check(modal._panel.get_theme_stylebox("panel") is StyleBoxFlat and modal._panel.get_theme_stylebox("panel").border_width_left == 2 and modal._panel.get_theme_stylebox("panel").corner_radius_top_left == 7 and modal._confirm_button.get_theme_stylebox("normal") is StyleBoxTexture, "仓库细边框和组件库按钮：" + id)
	await _shot(id + "_loot")
	if opened == 1:
		await _generic_loot_preview(modal)
	await _hold([KEY_W,KEY_D], 0.25)
	_check(maze.player.position == before and maze.player.input_locked and modal.visible, "弹窗隔离移动与长按E：" + id)
	var echo_event := InputEventKey.new()
	echo_event.keycode = KEY_E
	echo_event.pressed = true
	echo_event.echo = true
	Input.parse_input_event(echo_event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	_check(modal.visible and sm.gold_balance() == opened*100, "长按E回声不关闭不重复发奖：" + id)
	_movement_key(KEY_E, false)
	await _send_key(KEY_E)
	_check(modal.visible and sm.gold_balance() == opened*100, "弹窗内新按E也不穿透：" + id)
	await _click_loot_backdrop()
	_check(modal.visible and get_tree().current_scene == maze and not maze.confirmation.visible, "遮罩阻止鼠标触发下层交互：" + id)
	await _send_key(KEY_TAB)
	_check(modal._confirm_button.has_focus() and modal._close_button == null, "无关闭按钮，Tab焦点停留在收下：" + id)
	if opened == 1:
		# 鼠标关闭时E仍按住；后续回声不能触发第二次交互。
		_movement_key(KEY_E, true)
		await _click(modal._confirm_button)
		Input.parse_input_event(echo_event)
		Input.flush_buffered_events()
		await get_tree().process_frame
		_check(not maze._interact_armed, "持E鼠标关闭后仍须先松开")
		_movement_key(KEY_E, false)
	elif opened == 2:
		await _click(modal._confirm_button)
	else:
		await _send_key([KEY_ESCAPE, KEY_ENTER, KEY_SPACE][opened-3])
	_check(not modal.visible and not maze.player.input_locked and sm.gold_balance() == opened*100, "键鼠关闭仅恢复输入、不再次发奖：" + id)
	var saved := FileAccess.get_file_as_bytes(sm.active_save_path())
	# 新增挖掘点与部分箱邻近；松开再按允许领取另一物件，但不能再次发金币。
	maze._update_chest_target()
	var nearby_dig = maze.dig_target
	var wood_before: int = sm.inventory_quantity("wood")
	await _send_key(KEY_E)
	if is_instance_valid(nearby_dig):
		_check(modal.visible and sm.gold_balance() == opened*100 and sm.inventory_quantity("wood") == wood_before+3 and sm.is_dig_site_claimed(nearby_dig.site_id), "新按E可领取邻近挖掘点但不重复发金币：" + id)
		await _send_key(KEY_ESCAPE)
		await _send_key(KEY_E)
		_check(not modal.visible and sm.gold_balance() == opened*100 and sm.inventory_quantity("wood") == wood_before+3, "两物件已领后不重复发奖：" + id)
	else:
		_check(not modal.visible and sm.gold_balance() == opened*100 and FileAccess.get_file_as_bytes(sm.active_save_path()) == saved, "已领位置重复E不发奖不写盘：" + id)

func _generic_loot_preview(modal) -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var saved := FileAccess.get_file_as_bytes(sm.active_save_path())
	var sample: Array[Dictionary] = [
		{"name": "金币", "quantity": 100, "icon": modal.coin_texture()},
		{"name": "森林药草", "quantity": 3, "icon": SproutTheme.icon(0)},
		{"name": "古旧钥匙", "quantity": 1, "icon": SproutTheme.icon(1)},
	]
	modal.show_items(sample)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("template_multiple_items")
	_check(modal.item_views.size() == 3 and modal.item_views[1].name.text == "森林药草" and modal.item_views[1].quantity.text == "×3", "不同物品名称、图标和数量独立显示")
	var window := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_check(window.encloses(modal._panel.get_global_rect()), "多物品模板完整居中")
	for i in range(4):
		sample.append({"name": "带有古老铭文的遗迹碎片", "quantity": i + 1, "icon": SproutTheme.icon(2)})
	modal.show_items(sample)
	await get_tree().process_frame
	await get_tree().process_frame
	modal._scroll.scroll_vertical = 10000
	await get_tree().process_frame
	_check(modal._scroll.scroll_vertical > 0 and window.encloses(modal._panel.get_global_rect()), "多行长名称可滚动且弹窗不越界")
	await _shot("template_scroll_long_names")
	modal.show_reward(100, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(modal.item_views.size() == 1 and modal._scroll.scroll_vertical == 0, "模板复用时清理旧物品并回到顶部")
	_check(sm.data == before and FileAccess.get_file_as_bytes(sm.active_save_path()) == saved, "模板只展示，不修改领取事务或存档")

func _click_loot_backdrop() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = Vector2(16, 16)
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame
