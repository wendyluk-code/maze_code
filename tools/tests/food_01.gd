extends "res://tools/tests/maze_capture.gd"
const Progression := preload("res://scripts/characters/character_progression.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0 and OS.get_cmdline_user_args().has("--resume-food"):
		_restart_checks()
	elif failures == 0:
		_food_state()
		_legacy_food()
		if DisplayServer.get_name() != "headless":
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _food_scene()
			await _exit_scenes()
			await _legacy_exit_scenes()
		_prepare_restart()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path,"pid":OS.get_process_id()}, "\t"))
	print("FOOD_01 ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _new_run() -> void:
	_completed()
	sm.cancel_maze_entry()
	_check(Run.begin(sm, Roads.SPAWN).success, "建立真实新探索")

func _resolve(id: String, roll: float = 0.99) -> Dictionary:
	var row := Catalog.find(id)
	_check(Run.defeat(sm, id, row.position).success, "击败进入捕获选择：" + id)
	sm.data[Run.KEY].monsters[id].capture_roll = roll
	return Run.resolve(sm, id, true)

func _food_state() -> void:
	_new_run()
	var initial := Progression.satiety_snapshot(sm)
	_check(initial.values == {"yaya":2.0,"tieshan":1.0}, "角色初始真实余额")
	_check(_resolve("slime_1").caught, "首次保底成功")
	var food := Progression.satiety_snapshot(sm)
	_check(food.values.yaya == 1.0 and food.values.tieshan == 1.0 and Run.snapshot(sm).food_cursor == 1, "第一次扣芽芽，轮到铁山")
	_check(sm.save(), "保存轮转游标")
	sm.load_data()
	_check(Run.snapshot(sm).food_cursor == 1 and Progression.satiety_snapshot(sm).values.yaya == 1.0, "读档保留个人余额和游标")
	_check(not _resolve("slime_2").caught, "强制捕获失败")
	_check(Progression.satiety_snapshot(sm).values == {"yaya":1.0,"tieshan":0.0}, "失败扣铁山且不退款")
	var row := Catalog.find("snail_1")
	_check(Run.defeat(sm, row.id, row.position).success, "第三只进入待选择")
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.resolve(sm,row.id,true).success and sm.data == before, "保存失败回滚余额、游标、掉落和随机状态")
	sm._active_save_path = "user://chapter-ending-test.json"
	_check(Run.resolve(sm,row.id,false).success and Progression.satiety_snapshot(sm).values.yaya == 1.0, "不捕获不扣费不推进游标")
	for bank in [false,true]:
		if not Run.snapshot(sm).active: Run.begin(sm,Roads.SPAWN)
		var saved_food: Dictionary = Progression.satiety_snapshot(sm).values.duplicate(true)
		before = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check(not Run.finish(sm,bank,Roads.EXIT).success and sm.data == before, "两种离场保存失败完整回滚")
		sm._active_save_path = "user://chapter-ending-test.json"
		_check(Run.finish(sm,bank,Roads.EXIT).success, "离场成功："+str(bank))
		_check(sm.data[Progression.FOOD_KEY].values == saved_food, "离场不补扣不返还")
		_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).satiety < 1.01, "再次进场不回满")
		_check(Run.snapshot(sm).food_cursor == 0, "新趟从首位开始")
	# 按真实时钟锚点计算，但测试注入now，避免等待83分钟。
	Run.finish(sm,false,Roads.SPAWN)
	sm.data[Progression.FOOD_KEY] = {"values":{"yaya":0.0,"tieshan":0.0},"at":1000.0,"paused":false}
	food = Progression.satiety_snapshot(sm,3500.0)
	_check(is_equal_approx(food.values.yaya,1.0) and is_equal_approx(food.values.tieshan,0.25), "每人按自身效率恢复2500秒")
	_check(Progression.satiety_snapshot(sm,6000.0).values.yaya == 2.0, "芽芽5000秒回满")
	_check(Progression.satiety_snapshot(sm,1000000.0).values == {"yaya":2.0,"tieshan":1.0}, "长离线恢复封顶")
	_check(Progression.satiety_snapshot(sm,999.0).values.yaya == 0.0, "时钟回拨不负恢复")
	_check(sm.save(), "保存离线恢复锚点")
	sm.load_data()
	_check(is_equal_approx(Progression.satiety_snapshot(sm,3500.0).values.yaya,1.0), "重载离线与在线计算一致")
	_new_run()
	sm.data[Progression.FOOD_KEY].values = {"yaya":0.6,"tieshan":0.6}
	sm.data[Run.KEY].satiety = 1.2
	_check(Run.capture_count(sm,Run.snapshot(sm)) == 0 and Run.payer_index(sm,Run.snapshot(sm)) == -1, "总和1.2但全员不足1不能拼点")
	row = Catalog.find("slime_1")
	Run.defeat(sm,row.id,row.position)
	before = sm.data.duplicate(true)
	_check(Run.resolve(sm,row.id,true).get("reason") == "hungry" and sm.data == before, "不足拒绝无任何状态变化")
	food = Progression.satiety_snapshot(sm,Time.get_unix_time_from_system()+999999)
	_check(food.values == {"yaya":0.6,"tieshan":0.6}, "迷宫内长时间及离线不恢复")
	sm.data[Progression.FOOD_KEY].values.tieshan = 1.0
	sm.data[Run.KEY].satiety = 1.6
	_check(Run.payer_index(sm,Run.snapshot(sm)) == 1 and Run.resolve(sm,row.id,true).success, "跳过不足芽芽由铁山承担1点")
	_check(Progression.satiety_snapshot(sm).values == {"yaya":0.6,"tieshan":0.0} and Run.snapshot(sm).food_cursor == 0, "仅扣足额成员并移到其下一位")
	# 技能与付款人无关：铁山付款，芽芽六阶对土克制仍复制。
	_new_run()
	sm.data[Run.KEY].base_power = 100
	sm.data[Run.KEY].food_cursor = 1
	for member in sm.data[Run.KEY].members:
		if member.id == "yaya": member.rank = 6
	var skill := _resolve("snail_1",0.0)
	_check(skill.success and skill.copies >= 1 and Progression.satiety_snapshot(sm).values.tieshan == 0.0, "铁山付款不限制芽芽技能")
	_check(Progression.food_text(0.9999) == "0.99", "显示不把不足1四舍五入成1")
	_new_run()
	sm.data.erase(Progression.FOOD_KEY)
	sm.data[Run.KEY].erase("food_version")
	sm.data[Run.KEY].erase("food_cursor")
	sm.data[Run.KEY].satiety = 1
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.begin(sm,Roads.SPAWN).success and sm.data == before, "旧3点迁移保存失败完整回滚")
	sm._active_save_path = "user://chapter-ending-test.json"
	_check(Run.begin(sm,Roads.SPAWN).success, "旧3点进行中存档迁移")
	_check(Progression.satiety_snapshot(sm).values == {"yaya":1.0,"tieshan":0.0}, "按历史2次消耗轮转重建")
	before = sm.data.duplicate(true)
	_check(Run.begin(sm,Roads.SPAWN).success and sm.data == before, "重复恢复不再次补扣")

func _food_scene() -> void:
	_new_run()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	var flow = maze.capture_flow

	maze.player.position = Vector2(995,225)
	await get_tree().create_timer(0.6).timeout
	_check(flow.dialog.visible and flow.dialog.victory, "真实迷宫击败弹窗")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.6).timeout
	_check(flow.reward.visible and Progression.satiety_snapshot(sm).values.yaya == 1.0, "真实点击捕获扣角色")
	await _capture_image("food_capture_success")
	await _click(flow.reward._confirm_button)
	await get_tree().create_timer(0.3).timeout
	_check(not maze.player.input_locked, "领取后输入恢复")
	sm.data[Progression.FOOD_KEY].values = {"yaya":0.6,"tieshan":0.6}
	sm.data[Run.KEY].satiety = 1.2
	maze.player.position = Catalog.find("slime_2").position
	await get_tree().create_timer(0.6).timeout
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.15).timeout
	_check(flow.party_attempts.text == "可捕获 0 次" and maze.last_message == "饱腹度不足，无法捕获", "真实小数总量显示与不足提示一致")
	await _capture_image("food_fraction_unavailable")
	await _click(flow.dialog._cancel_button)
	await get_tree().create_timer(0.3).timeout
	_check(not maze.player.input_locked and not flow.busy, "取消恢复输入")
	sm.data[Progression.FOOD_KEY].values.tieshan = 1.0
	sm.data[Run.KEY].satiety = 1.6
	sm.data[Run.KEY].base_power = 100
	sm.data[Run.KEY].monsters.snail_1.capture_roll = 0.99
	maze.player.position = Catalog.find("snail_1").position
	await get_tree().create_timer(0.5).timeout
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.6).timeout
	_check(flow.dialog.visible and flow.dialog._title_label.text == "魔物溜走了" and Progression.satiety_snapshot(sm).values.tieshan == 0.0, "真实失败弹窗也扣足额成员1点")
	await _capture_image("food_capture_failure")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.2).timeout
	_check(not flow.resolving and not flow.busy and not maze.player.input_locked, "失败关闭后流程复位与输入恢复")
	maze.queue_free()
	await get_tree().process_frame
func _exit_scenes() -> void:
	for bank in [false,true]:
		_new_run()
		_resolve("slime_1")
		maze = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.4).timeout
		maze.player.position = Roads.EXIT if bank else Roads.ENTRANCE
		await get_tree().create_timer(0.1).timeout
		await _send_key(KEY_E)
		_check(maze.confirmation.visible, "实际离场确认窗："+str(bank))
		await _capture_image("food_exit_confirmation_"+str(bank))
		await _click(maze.confirmation.cancel_button)
		await get_tree().process_frame
		_check(not maze.player.input_locked, "离场取消恢复输入")
		await _send_key(KEY_E)
		await _click(maze.confirmation.confirm_button)
		await get_tree().create_timer(1.2).timeout
		_check(sm.maze_exploration_state().region == "restaurant" and not Run.snapshot(sm).active, "实际离场返回餐厅："+str(bank))
		_check(sm.data[Progression.FOOD_KEY].values == {"yaya":1.0,"tieshan":1.0}, "实际离场不返还不额外扣")
		var details = load("res://scripts/ui/components/character_details_modal.gd").new()
		var details_layer := CanvasLayer.new()
		details_layer.layer = 100
		get_tree().current_scene.add_child(details_layer)
		details_layer.add_child(details)
		details.present("yaya")
		await get_tree().create_timer(0.2).timeout
		_check(details.attribute_values[1].text.begins_with("1 / 2"), "角色详情展示当前值与上限")
		await _capture_image("food_restaurant_details_"+str(bank))
		details.queue_free()
		get_tree().current_scene.queue_free()
		await get_tree().process_frame
func _prepare_restart() -> void:
	_new_run()
	_resolve("slime_1")
	sm._active_save_path = "user://food-maze-restart.json"
	sm.data[Progression.FOOD_KEY].at = Time.get_unix_time_from_system() - 10000.0
	_check(sm.save(), "写入跨进程迷宫存档")
	sm._active_save_path = "user://food-outside-restart.json"
	Run.finish(sm,false,Roads.SPAWN)
	sm.data[Progression.FOOD_KEY] = {"values":{"yaya":0.0,"tieshan":0.0},"at":Time.get_unix_time_from_system()-2500.0,"paused":false}
	_check(sm.save(), "写入跨进程离线恢复存档")

func _restart_checks() -> void:
	sm._active_save_path = "user://food-maze-restart.json"
	sm.load_data()
	_check(Run.snapshot(sm).get("active",false) and Run.snapshot(sm).get("food_cursor") == 1, "新进程恢复进行中探索与轮转游标")
	_check(Progression.satiety_snapshot(sm).values == {"yaya":1.0,"tieshan":1.0}, "新进程迷宫离线10000秒也不恢复")
	_check(Run.begin(sm,Roads.SPAWN).success and Progression.satiety_snapshot(sm).values.yaya == 1.0, "新进程重进不重复扣或回满")
	sm._active_save_path = "user://food-outside-restart.json"
	sm.load_data()
	var food := Progression.satiety_snapshot(sm)
	_check(food.values.yaya >= 1.0 and food.values.yaya < 1.05 and food.values.tieshan >= 0.25 and food.values.tieshan < 0.27, "新进程按离线锚点和个人效率恢复")
func _legacy_seed(remaining: int) -> void:
	_new_run()
	sm.data.erase(Progression.FOOD_KEY)
	sm.data[Run.KEY].erase("food_version")
	sm.data[Run.KEY].erase("food_cursor")
	sm.data[Run.KEY].satiety_max = 70
	sm.data[Run.KEY].satiety = remaining
	sm.data[Run.KEY].bag = {"slime_gel":2}

func _legacy_food() -> void:
	for bank in [true,false]:
		_legacy_seed(68)
		_check(sm.save(), "旧70点保存")
		sm.load_data()
		var original := Run.snapshot(sm)
		_check(Run.begin(sm,Roads.SPAWN).success and _same_saved(original,Run.snapshot(sm)), "旧70点重载保留原池与随机状态")
		_check(Progression.satiety_snapshot(sm,Time.get_unix_time_from_system()+10000).values == {"yaya":2.0,"tieshan":1.0} and Run.snapshot(sm).satiety == 68, "旧池迷宫离线不增长不提前补扣")
		var before: Dictionary = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check(not Run.finish(sm,bank,Roads.EXIT).success and sm.data == before, "旧70点离场失败回滚个人补扣、位置和奖励")
		sm._active_save_path = "user://chapter-ending-test.json"
		_check(Run.finish(sm,bank,Roads.EXIT).success, "旧70点两种离场成功："+str(bank))
		_check(sm.data[Progression.FOOD_KEY].values == {"yaya":1.0,"tieshan":0.0}, "历史耗2按顺序各补扣1")
		_check(sm.inventory_snapshot().get("slime_gel",0) == (2 if bank else 0), "旧池退出奖励规则保持")
		before = sm.data.duplicate(true)
		_check(not Run.finish(sm,bank,Roads.EXIT).success and sm.data == before, "重复旧池退出不再次补扣")
		sm.load_data()
		_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).food_version == 1 and Run.snapshot(sm).satiety < 1.01, "旧池离场读档下趟采用真实余额")
	_legacy_seed(0)
	_check(Run.finish(sm,false,Roads.SPAWN).success and sm.data[Progression.FOOD_KEY].values == {"yaya":0.0,"tieshan":0.0}, "历史70次消耗补扣最低0且无负数")
	_check(Progression.satiety_snapshot(sm,Time.get_unix_time_from_system()+100000).values == {"yaya":2.0,"tieshan":1.0}, "旧池离场后恢复封顶")
	_legacy_seed(69)
	_check(Run.finish(sm,true,Roads.EXIT).success and sm.data[Progression.FOOD_KEY].values == {"yaya":1.0,"tieshan":1.0}, "历史仅耗1只补扣首位")
func _legacy_exit_scenes() -> void:
	for bank in [true,false]:
		_legacy_seed(68)
		maze = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.4).timeout
		_check(Run.snapshot(sm).satiety == 68 and maze.capture_flow.party_attempts.text == "可捕获 68 次", "旧池真实场景保留本趟次数")
		maze.player.position = Roads.EXIT if bank else Roads.ENTRANCE
		await get_tree().create_timer(0.1).timeout
		await _send_key(KEY_E)
		_check(maze.confirmation.visible, "旧池实际离场确认："+str(bank))
		await _capture_image("food_legacy_exit_"+str(bank))
		await _click(maze.confirmation.confirm_button)
		await get_tree().create_timer(1.2).timeout
		_check(sm.maze_exploration_state().region == "restaurant" and sm.data[Progression.FOOD_KEY].values == {"yaya":1.0,"tieshan":0.0}, "旧池真实离场同事务补扣："+str(bank))
		_check(absf(float(sm.data[Progression.FOOD_KEY].at)-Time.get_unix_time_from_system()) < 3.0 and not sm.data[Progression.FOOD_KEY].paused, "恢复锚点为真实退出时刻")
		get_tree().current_scene.queue_free()
		await get_tree().process_frame