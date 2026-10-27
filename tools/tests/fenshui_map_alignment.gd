extends "res://tools/tests/fenshui_flow.gd"

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.position = maze.SettlementExit.FRONT
	maze.camera.snap_to_target()
	maze._update_prompts()
	await _capture_image("01_kushui_sign")
	await _click(maze.settlement_prompt.button)
	_check(maze.confirmation.visible,"枯水渠路标打开确认")
	await _capture_image("02_confirm")
	var prior: Dictionary = sm.data.duplicate(true)
	var saved_path: String = sm._active_save_path
	sm._active_save_path = ""
	maze._confirm_destination()
	_check(maze.region_id == "maze_entry" and sm.data == prior and not maze.player.input_locked,"切区保存失败回滚并恢复输入")
	sm._active_save_path = saved_path
	await _click(maze.settlement_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == "fenshui" and maze._entry_ready,"确认后实际切入分水庭")
	if maze.region_id != "fenshui": return
	maze.capture_flow.window_focused = true
	_check(maze.player.position.distance_to(FS.SPAWN)<0.1,"右上路面出生")
	_check(maze.capture_flow.monsters.is_empty() and maze.chests.is_empty() and maze.dig_sites.is_empty() and not is_instance_valid(maze.elder),"不携带枯水渠怪物宝箱采集或NPC")
	var now := Run.snapshot(sm)
	for key in ["members","satiety","bag","monsters"]:
		_check(now[key] == prior[Run.KEY][key],"换区保留"+key)
	_check(now.combat.hp == prior[Run.KEY].combat.hp,"换区保留生命")
	_check(sm.stamina_snapshot().value == prior.stamina.value,"切区不重新扣体力")

	maze.capture_flow.set_process(false)
	maze.player.set_physics_process(false)
	var projection := FSProjection.new()
	# 独立视觉标注的总图道路色彩，不用预期投影坐标作为唯一验收。
	var atlas: Image = load("res://assets/maps/shallow_floor.png").get_image()
	var samples := [Vector2(595,807),Vector2(670,795),Vector2(725,784),Vector2(780,760),Vector2(836,739),Vector2(1550,222),Vector2(1495,250),Vector2(1399,283)]
	for i in samples.size():
		maze.player.position = samples[i]
		maze.player.facing = Vector2.RIGHT
		maze.camera.snap_to_target()
		maze.map_ui._process(0.2)
		var target: Vector2 = projection.project(samples[i])
		var color: Color = atlas.get_pixelv(Vector2i(target))
		_check(color.r > 0.48 and color.g > 0.44 and color.r > color.b*1.12,"总图实际道路像素 "+str(i),{"world":str(samples[i]),"atlas":str(target),"color":str(color)})
		await _capture_image("map_road_"+str(i))
		if i == 4:
			maze.map_ui.open_map()
			await _capture_image("map_junction_full")
			maze.map_ui.close_map()
	await _close_scene()
