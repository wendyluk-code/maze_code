extends "res://tools/tests/local_debug.gd"

const RunTools = preload("res://scripts/maze/capture_run.gd")
const TransitionTools = preload("res://scripts/ui/components/scene_transition.gd")

func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离用户存档")
	var debug = get_node("/root/LocalDebug")
	_check(is_instance_valid(debug.panel.find_child("MapJump",true,false)), "调试面板具备地图跳转操作")
	if failures == 0:
		_seed()
		for step in ["party","home","maze","title"]: sm.advance_chapter_1_outro(step)
		sm.data["ch2_guide_01"] = {"step":"done","recipe":"","seen":{},"banked":{},"revision":2}
		sm.data[sm.YUFENG_SALIA_KEY] = {"version":2,"phase":"done","line":0}
		sm.save()
		await _open_scene()
		for size in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = size
			suffix = "_%dx%d" % [size.x,size.y]
			await _type_code()
			_check(debug.panel.visible and get_tree().paused, "暗号打开调试工具并暂停")
			debug.tabs.current_tab = 1
			await get_tree().process_frame
			await _shot("debug_map_menu")
			var original: Dictionary = sm.data.duplicate(true)
			var original_path: String = sm._active_save_path
			var bytes := FileAccess.get_file_as_bytes(original_path)
			for i in 5:
				debug.region_select.select(i)
				debug.region_select.item_selected.emit(i)
				await _click(debug.panel.find_child("MapJump",true,false))
				var wait_started := Time.get_ticks_msec()
				var arrived := await _wait_for_transition(debug)
				var overlay = get_tree().get_first_node_in_group(TransitionTools.GROUP)
				_check(arrived, "地图转场完成", {"wait_ms":Time.get_ticks_msec()-wait_started,"phase":overlay.phase if is_instance_valid(overlay) else "none","panel_visible":debug.panel.visible,"status":debug.status.text})
				if not arrived:
					FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
					get_tree().quit(1)
					return
				scene = get_tree().current_scene
				_check(is_instance_valid(scene) and scene.has_method("travel_region"), "目标是真实地图场景")
				_check(sm.maze_exploration_state().region == debug.map_session.regions()[i].id, "所选地图与保存位置一致")
				_check(sm._active_save_path != original_path and FileAccess.get_file_as_bytes(original_path) == bytes, "跳图保持原档文件不变")
				await _shot("debug_map_"+str(i))
				await _type_code()
				debug.tabs.current_tab = 1
			var hp: int = RunTools.snapshot(sm).combat.max_hp
			sm.data[RunTools.KEY].combat.hp = 1
			await _tools_key(KEY_0)
			_check(RunTools.snapshot(sm).combat.hp == hp, "打开调试面板时Ctrl加0也可满血")
			await _click(debug.panel.find_child("MapReload",true,false))
			_check(await _wait_for_transition(debug), "重载当前地图完成并关闭面板")
			scene = get_tree().current_scene
			_check(RunTools.snapshot(sm).combat.hp == hp, "重载不重开本趟生命")
			await _type_code()
			debug.tabs.current_tab = 0
			sm.data[RunTools.KEY].combat.hp = 1
			await get_tree().process_frame
			await _click(debug.panel.find_child("HealParty",true,false))
			_check(RunTools.snapshot(sm).combat.hp == hp, "实际点击回血按钮恢复生命")
			await _send_key(KEY_ESCAPE)
			await get_tree().process_frame
			_check(scene.capture_flow.hp_label.text == "HP:%d/%d" % [hp,hp], "关闭调试面板后生命显示同步")
			sm.data[RunTools.KEY].combat.hp = 1
			await _tools_key(KEY_0)
			await get_tree().process_frame
			_check(RunTools.snapshot(sm).combat.hp == hp and scene.capture_flow.health_bar.value == hp, "地图正常操作时Ctrl加0恢复生命和血条")
			await _type_code()
			debug.tabs.current_tab = 1
			debug.region_select.select(1)
			debug.region_select.item_selected.emit(1)
			debug.point_select.select(1)
			await _click(debug.panel.find_child("MapJump",true,false))
			_check(await _wait_for_transition(debug), "指定观察点转场完成")
			scene = get_tree().current_scene
			_check(sm.maze_exploration_state().region == "fenshui" and scene.player.position.distance_to(Vector2(1065,450)) < 2.0, "实际进入分水庭鱼鳗观察点")
			await _type_code()
			debug.tabs.current_tab = 1
			debug.region_select.select(2)
			debug.region_select.item_selected.emit(2)
			sm.data[RunTools.KEY].combat.hp = 1
			sm.data[RunTools.KEY].bag = {"cool_whisker_herb":2}
			await _click(debug.panel.find_child("MapRestart",true,false))
			_check(await _wait_for_transition(debug), "重开试玩实际转场完成")
			scene = get_tree().current_scene
			var restarted: Dictionary = RunTools.snapshot(sm)
			_check(sm.maze_exploration_state().region == "fenshui" and restarted.bag.is_empty() and restarted.combat.hp == restarted.combat.max_hp, "重开当前地图并重置本趟状态，不受跳图下拉框影响")
			_check(FileAccess.get_file_as_bytes(original_path) == bytes, "重开试玩仍保留原档文件")
			await _shot("debug_map_restarted")
			await _type_code()
			debug.tabs.current_tab = 1
			await _click(debug.panel.find_child("MapLeave",true,false))
			_check(await _wait_for_transition(debug), "退出试玩完成")
			scene = get_tree().current_scene
			_check(sm._active_save_path == original_path and sm.data == original, "退出试玩回到原档完整状态")
			_check(not get_tree().paused, "地图切换结束无暂停残留")
			await _type_code()
			await _send_key(KEY_ESCAPE)
			_check(not debug.panel.visible and not get_tree().paused, "关闭新面板恢复输入")
		await _active_exploration_return(debug)
		await _close_scene()
	FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"pictures":evidence},"\t"))
	get_tree().quit(1 if failures else 0)

func _active_exploration_return(debug: Node) -> void:
	_check(RunTools.begin(sm,RunTools.Roads.SPAWN).success, "从正常存档建立原始探索")
	_check(RunTools.change_region(sm,"fenshui",Vector2(1065,450)).success, "记录原始探索的分水庭位置")
	await TransitionTools.change_scene(get_tree(),load("res://scenes/maze_fenshui.tscn"))
	scene = get_tree().current_scene
	await _type_code()
	var original: Dictionary = sm.data.duplicate(true)
	var original_path: String = sm._active_save_path
	var bytes := FileAccess.get_file_as_bytes(original_path)
	debug.tabs.current_tab = 1
	debug.region_select.select(4)
	debug.region_select.item_selected.emit(4)
	await _click(debug.panel.find_child("MapJump",true,false))
	_check(await _wait_for_transition(debug), "从原有探索进入其他地图试玩")
	await _type_code()
	debug.tabs.current_tab = 1
	await _click(debug.panel.find_child("MapLeave",true,false))
	_check(await _wait_for_transition(debug), "退出试玩回到原有探索场景")
	scene = get_tree().current_scene
	# 转场结束即暂停采样，避免正常战斗推进污染完整状态比较。
	get_tree().paused = true
	_check(scene.region_id == "fenshui" and scene.player.position.distance_to(Vector2(1065,450)) < 2.0, "恢复原地图和玩家位置")
	_check(sm._active_save_path == original_path and FileAccess.get_file_as_bytes(original_path) == bytes and RunTools.snapshot(sm).members == original[RunTools.KEY].members, "回到原探索时保留原档文件与队伍")
	await _shot("debug_original_exploration_restored")
	get_tree().paused = false

func _wait_for_transition(debug: Node) -> bool:
	# 转场按秒播放，按原300帧/60Hz对应的5秒预算等待，避免高刷新率缩短检查窗口。
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if not TransitionTools.is_active(get_tree()) and not debug.panel.visible: return true
		await get_tree().process_frame
	return not TransitionTools.is_active(get_tree()) and not debug.panel.visible

func _tools_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = true
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame
