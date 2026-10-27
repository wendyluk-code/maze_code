extends "res://tools/tests/ch2_chest_flow.gd"
var collected := 0

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
			await _dig_walkthrough()
			if failures: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trajectory":trajectory,"display":DisplayServer.get_name()}, "\t"))
	print("CH2_DIG_FLOW ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _dig_walkthrough() -> void:
	collected = 0
	captured_encounters.clear()
	_completed()
	sm._active_save_path = "user://save.json"
	_check(sm.save(), "本分辨率新隔离档")
	await _open_scene()
	await _enter_from_restaurant()
	if failures: return
	_check(maze.dig_sites.size() == 4 and _dig_prompt_count() == 0, "四处闪光存在且远处无E")
	var trunk: PackedVector2Array = Roads.roads()[0].points
	var ring: PackedVector2Array = Roads.roads()[1].points
	await _route(trunk.slice(1), "corridor")
	await _move_to(Vector2(933,269), "wood_1_black_circle")
	await _dig("entry_dig_west_fork", true)
	if failures: return
	await _route(trunk.slice(5), "wood1_to_ring")
	await _route(ring.slice(1,16), "inner_junction")
	await _route(Roads.roads()[3].points.slice(1,3), "inner_dig")
	await _dig("entry_dig_inner_path", false, true)
	if failures: return
	await _route(_reversed(Roads.roads()[3].points.slice(0,3)), "inner_back")
	await _route(ring.slice(16,21), "south_bend")
	await _move_to(Vector2(918,1208), "wood_4_black_circle")
	await _dig("entry_dig_south_bend")
	if failures: return
	await _route(ring.slice(21,36), "east_rim")
	await _move_to(Vector2(982,596), "northeast_dig")
	await _dig("entry_dig_northeast")
	if failures: return
	_check(sm.inventory_quantity("wood") == 12 and sm.data.claimed_dig_sites.size() == 4, "实际沿路四处共12木材")
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("start_screen")),240), "重启标题")
	var start = get_tree().get_first_node_in_group("start_screen")
	await _click(start.continue_button)
	await get_tree().process_frame
	var slot: Button = start.save_modal._rows.get("user://save.json")
	_check(slot != null, "标题存在测试档")
	if slot == null: return
	await _click(slot)
	await _click(start.save_modal._confirm_button)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")),240), "真实选档继续")
	maze = get_tree().get_first_node_in_group("maze_entry")
	scene = maze
	_check(sm.inventory_quantity("wood") == 12 and maze.dig_sites.is_empty(), "重载后12木材且闪光不再创建")
	await _shot("reload_no_twinkles")
	await _route(ring.slice(35), "return_north")
	await _route(_reversed(trunk.slice(1)), "return_gate")
	await _send_key(KEY_E)
	_check(maze.confirmation.visible, "入口仍使用原确认UI")
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")) and not Transition.is_active(get_tree()),240), "返回餐厅转场完成")
	scene = get_tree().current_scene
	maze = null
	_check(sm.inventory_quantity("wood") == 12, "回餐厅实际库存仍12")
	await _enter_from_restaurant()
	_check(sm.inventory_quantity("wood") == 12 and maze.dig_sites.is_empty(), "再次进入不刷新挖掘点")
	await _close_scene()
	maze = null

func _dig_prompt_count() -> int:
	var count := _prompt_count()
	for site in maze.dig_sites:
		if site.prompt.is_visible_in_tree(): count += 1
	return count

func _nearby_chest() -> void:
	await get_tree().process_frame
	_check(is_instance_valid(maze.chest_target) and not is_instance_valid(maze.dig_target) and _dig_prompt_count() == 1, "相邻宝箱与采集点只显示最近的宝箱E")
	if not is_instance_valid(maze.chest_target): return
	var before: int = sm.inventory_quantity("wood")
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.inventory_quantity("wood") == before, "开箱不同时领取木材")
	await _send_key(KEY_ESCAPE)

func _dig(id: String, probe_failure := false, mouse := false) -> void:
	await get_tree().process_frame
	_check(is_instance_valid(maze.dig_target) and maze.dig_target.site_id == id and _dig_prompt_count() == 1, "最近且唯一的采集E：" + id)
	if not is_instance_valid(maze.dig_target): return
	var site = maze.dig_target
	var frame: int = site.sprite.frame
	await get_tree().create_timer(0.18).timeout
	_check(site.sprite.frame != frame and site.sprite.is_playing(), "用户闪光动画在播放：" + id)
	await _shot(id + "_near")
	if probe_failure:
		var before: Dictionary = sm.data.duplicate(true)
		var bytes := FileAccess.get_file_as_bytes(sm.active_save_path())
		DirAccess.make_dir_recursive_absolute(sm.active_save_path() + ".tmp")
		await _send_key(KEY_E)
		_check(site.visible and not maze.loot_modal.visible and not maze.player.input_locked and sm.data == before, "保存失败保留闪光、恢复输入且不发木材")
		_check(FileAccess.get_file_as_bytes(sm.active_save_path()) == bytes and "保存失败" in maze.last_message, "保存失败有反馈且原档完整")
		DirAccess.remove_absolute(sm.active_save_path() + ".tmp")
	if mouse:
		var point: Vector2 = site.prompt.get_global_transform_with_canvas().origin
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = point
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await get_tree().process_frame
	else:
		await _send_key(KEY_E)
	collected += 1
	_check(maze.loot_modal.visible and not site.visible and sm.inventory_quantity("wood") == collected*3 and sm.is_dig_site_claimed(id), "交互领取×3并移除闪光：" + id)
	if not maze.loot_modal.visible: return
	var modal = maze.loot_modal
	_check(modal.item_views.size() == 1 and modal.item_views[0].name.text == "木材" and modal.item_views[0].quantity.text == "×3" and modal.item_views[0].icon.texture.atlas.resource_path.ends_with("wood_logs_pixel_256.png"), "复用宝箱弹窗显示指定木材图标和×3")
	_check(Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size).encloses(modal._panel.get_global_rect()), "奖励弹窗完整显示")
	await _shot(id + "_loot")
	var position_before: Vector2 = maze.player.position
	await _hold([KEY_D,KEY_E],0.2)
	_check(maze.player.position == position_before and modal.visible and sm.inventory_quantity("wood") == collected*3 and _dig_prompt_count() == 0, "模态锁移动、长按不连领且无底层E")
	await _click_loot_backdrop()
	_check(modal.visible, "蒙层不穿透点击")
	await _click(modal._confirm_button)
	_check(not maze.player.input_locked and not modal.visible, "收下恢复输入")
	await _send_key(KEY_E)
	_check(not modal.visible and sm.inventory_quantity("wood") == collected*3, "已领取点重复E不再发奖")
