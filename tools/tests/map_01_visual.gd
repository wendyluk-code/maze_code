extends Node

const MazeScene := preload("res://scenes/maze_entry.tscn")
const Roads := preload("res://data/maze/entry_roads.gd")

var sm
var failures := 0
var checks := 0
var results: Array = []
var output_dir := ""

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		push_error("MAP_01 FAIL: " + label)

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with(prefix): return str(arg).substr(prefix.length())
	return ""

func _seed() -> void:
	sm = get_node("/root/SaveManager")
	sm.data = sm._defaults()
	sm._active_save_path = "user://map-01-visual.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.save(), "隔离存档初始化")
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success and sm.deliver_first_order().success, "首单事务完成")
	for expected in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(expected): continue
		if sm.departure_state().step == "ready_to_depart": break
		_check(sm.advance_departure(expected).success, "出发前置：" + expected)
	for expected in ["party", "home", "maze", "title"]:
		if sm.chapter_1_outro_state() == "done": break
		_check(sm.advance_chapter_1_outro(expected).success, "章节收尾：" + expected)

func _capture(label: String) -> void:
	if output_dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := get_viewport().get_texture().get_image()
	if image: image.save_png(output_dir.path_join(label + ".png"))

func _run() -> void:
	output_dir = _arg("--output-dir=")
	_seed()
	for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		var maze := MazeScene.instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().process_frame
		await get_tree().process_frame
		_check(maze._entry_ready and is_instance_valid(maze.map_ui), "地图场景就绪 %s" % resolution)
		_check(maze.map_ui.mini_button.position == Vector2(20, 20), "左上固定位置 %s" % resolution)
		maze.map_ui.refresh_resources()
		_check(maze.map_ui.visible_resources.size() < 9 and maze.map_ui.visible_resources.all(func(item): return item.position.x >= 0.0 and item.position.x <= 1672.0 and item.position.y >= 0.0 and item.position.y <= 941.0), "未揭示区域不泄露资源 %s" % resolution)
		_capture("mini_%dx%d" % [resolution.x, resolution.y])
		maze.map_ui.open_map()
		await get_tree().process_frame
		_check(maze.map_ui.expanded and maze.player.input_locked and not maze.player.is_physics_processing(), "展开锁定世界输入 %s" % resolution)
		_capture("full_%dx%d" % [resolution.x, resolution.y])
		maze.map_ui.deep_button.pressed.emit()
		await get_tree().process_frame
		_check(maze.map_ui.expanded and maze.map_ui.locked_toast.text == "深层暂未解锁", "深层保持浅层并提示 %s" % resolution)
		maze.map_ui.close_map()
		await get_tree().process_frame
		_check(not maze.map_ui.expanded and not maze.player.input_locked and maze.player.is_physics_processing(), "关闭恢复输入 %s" % resolution)
		maze.queue_free()
		await get_tree().process_frame
	var report := {"checks": checks, "failures": failures, "results": results}
	var report_path := _arg("--report=")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("MAP_01_VISUAL ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
