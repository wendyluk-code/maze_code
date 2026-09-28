extends Node

var checks: Array = []
var sm: Node
var report := ""
var mode := ""
var screen: Control
var capture_index := 0

func arg(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return ""

func check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "description": label})
	if not ok:
		push_error(label)

func write(path: String, value: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(value)
	f.close()

func disk(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var isolation := OS.get_environment("MAZE_START02_ROOT").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("拒绝运行：未隔离 user://")
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	mode = arg("--mode=")
	report = arg("--report=")
	if mode == "state":
		state_suite()
	elif mode == "restart":
		await restart_suite()
	elif mode == "gui":
		if sm.list_save_slots().slots.is_empty():
			var a: Dictionary = sm.create_new_game()
			sm.accept_first_order()
			sm.rename_save_slot(a.id, "冒险甲")
			var b: Dictionary = sm.create_new_game()
			sm.rename_save_slot(b.id, "冒险乙")
			write("user://saves/broken.json", "{broken")
		screen = load("res://scenes/start_screen.tscn").instantiate()
		add_child(screen)
		DisplayServer.window_set_title("START-02 隔离验收 " + arg("--label="))
		return
	finish()

func state_suite() -> void:
	check(not sm.has_method("missing_method"), "测试运行器启动")
	var a: Dictionary = sm.create_new_game()
	check(a.success and sm.accept_first_order().success, "真实创建 A 并接单")
	var b: Dictionary = sm.create_new_game()
	check(b.success and sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "真实创建 B 并取料")
	var active: String = sm.active_save_path()
	var before: Dictionary = sm.data.duplicate(true)
	var a_before: Dictionary = JSON.parse_string(disk(a.id))
	check(sm.rename_save_slot(a.id, "改名甲").success, "非活动档重命名成功")
	var after: Dictionary = JSON.parse_string(disk(a.id))
	after.erase(sm.SLOT_META_KEY)
	a_before.erase(sm.SLOT_META_KEY)
	check(after == a_before and sm.data == before and active == sm.active_save_path(), "仅改元数据且不切换活动档")
	check(sm.rename_save_slot(b.id, "改名乙").success and sm.data[sm.SLOT_META_KEY].name == "改名乙", "活动档名称同步")
	check(sm.save() and JSON.parse_string(disk(b.id))[sm.SLOT_META_KEY].name == "改名乙", "后续自动保存不撤销改名")
	var stable := disk(b.id)
	before = sm.data.duplicate(true)
	check(sm.rename_save_slot(b.id, "改名乙").success and disk(b.id) == stable, "重复同名不写盘")
	for name_value in [" ", "a\nb", "x".repeat(41)]:
		check(not sm.rename_save_slot(b.id, name_value).success and sm.data == before and disk(b.id) == stable, "非法名称不变更：" + str(name_value.length()))
	DirAccess.make_dir_absolute(b.id + ".tmp")
	check(not sm.rename_save_slot(b.id, "不会提交").success and sm.data == before and disk(b.id) == stable, "临时文件无法写入时完整回滚")
	DirAccess.remove_absolute(b.id + ".tmp")
	write("user://saves/broken.json", "{broken")
	check(not sm.rename_save_slot("user://saves/broken.json", "坏档").success and disk("user://saves/broken.json") == "{broken", "坏档重命名拒绝且原文保留")
	check(not sm.load_save_slot("user://saves/broken.json").success and sm.data == before and sm.active_save_path() == active, "坏档载入不切换活动档")
	check(sm.list_save_slots().slots.any(func(s): return s.id == "user://saves/broken.json" and not s.problem.is_empty()), "坏档列表仍有诊断条目")
	for path in ["user://saves/../save.json", "user://other.json", "user://saves/missing.json"]:
		check(not sm.rename_save_slot(path, "失败").success and not sm.delete_save_slot(path).success and not sm.load_save_slot(path).success and sm.data == before and sm.active_save_path() == active, "非法或缺失路径不变更：" + path)
	# 只读属性让 Windows 的替换和删除失败；由 runner 在锁定阶段构造真正的文件共享冲突。
	write("user://lock-target.txt", ProjectSettings.globalize_path(b.id))
	write("user://manifest.json", JSON.stringify({"a": a.id, "b": b.id}))
	check(sm.delete_save_slot(a.id).success and sm.data == before and sm.active_save_path() == active, "删除非活动档不改变当前进度")
	check(not sm.delete_save_slot(a.id).success and sm.data == before, "重复删除无额外效果")
	var c: Dictionary = sm.create_new_game()
	check(sm.delete_save_slot(c.id).success and sm.active_save_path().is_empty() and not sm.save() and not FileAccess.file_exists(c.id), "删除活动档解除绑定且不能自动复活")
	check(sm.load_save_slot(b.id).success and sm.lifecycle_stage() == "ingredients_collected", "删除活动档后显式载入 B 内容路径正确")
	sm.begin_replay()
	check(not sm.rename_save_slot(b.id, "重播").success and not sm.delete_save_slot(b.id).success, "重播禁止管理正式档")
	sm.end_replay()

func restart_suite() -> void:
	var manifest: Dictionary = JSON.parse_string(disk("user://manifest.json"))
	check(not FileAccess.file_exists(manifest.a), "新进程中已删除 A 不存在")
	check(sm.list_save_slots().slots.size() == 2, "新进程仅有 B 和坏档")
	check(sm.load_save_slot(manifest.b).success and sm.active_save_path() == manifest.b and sm.lifecycle_stage() == "ingredients_collected", "新进程载入 B 路径与内容一致")
	check(sm.data[sm.SLOT_META_KEY].name == "改名乙", "新进程名称持久化")
	var before: Dictionary = sm.data.duplicate(true)
	var bytes := disk(manifest.b)
	write("user://ready-for-lock", "ready")
	# runner 从进程外独占锁定文件，真实验证读写删除失败。
	await get_tree().create_timer(3).timeout
	if FileAccess.file_exists("user://locked"):
		check(not sm.rename_save_slot(manifest.b, "锁定失败").success and not sm.delete_save_slot(manifest.b).success and not sm.load_save_slot(manifest.b).success, "真实独占文件锁使读写删除全部失败")
		check(sm.data == before and sm.active_save_path() == manifest.b, "锁定失败后内存与活动路径不变")
		write("user://lock-done", "done")
		await get_tree().create_timer(2).timeout
		check(disk(manifest.b) == bytes, "释放文件锁后原档字节一致")
	else:
		check(false, "runner 未建立文件锁")

func finish() -> void:
	var failures := checks.filter(func(c): return not c.passed).size()
	write(report, JSON.stringify({"checks": checks, "failures": failures, "user_dir": ProjectSettings.globalize_path("user://"), "active_path": sm.active_save_path()}, "\t"))
	print("START02 checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _input(event: InputEvent) -> void:
	if mode == "gui" and ((event is InputEventMouseButton and not event.pressed) or (event is InputEventKey and not event.pressed)):
		capture.call_deferred()

func capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	capture_index += 1
	var prefix := report.trim_suffix(".json") + "-%03d" % capture_index
	get_viewport().get_texture().get_image().save_png(prefix + ".png")
	write(prefix + ".json", JSON.stringify({"active_path": sm.active_save_path(), "data": sm.data, "slots": sm.list_save_slots(), "modal_mode": screen.save_modal._mode, "selected": screen.save_modal._selected}, "\t"))
