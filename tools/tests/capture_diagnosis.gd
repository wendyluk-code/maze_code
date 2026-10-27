extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_prop_checks()
		if OS.get_cmdline_user_args().has("--mode=props"):
			await _prop_scene()
			var report := FileAccess.open(_arg("--report="),FileAccess.WRITE)
			report.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
			get_tree().quit(1 if failures else 0)
			return
		_fresh()
		var ui = load("res://scripts/ui/components/capture_attempt_modal.gd").new()
		add_child(ui)
		ui.set_process(false)
		for rate in [3,4,5,8,10]:
			ui.present(Catalog.find("snail_1"), Run.snapshot(sm), true, 3)
			ui.start(2.6)
			var longest := 0.0
			for frame in 600:
				if frame % (60 / rate) == 0:
					var key := InputEventKey.new()
					key.keycode = KEY_J
					key.pressed = true
					get_viewport().push_input(key)
					key = InputEventKey.new()
					key.keycode = KEY_J
					get_viewport().push_input(key)
				ui._process(1.0/60)
				longest = maxf(longest,ui.hold_time)
			_check(ui.hold_qualified == (rate>=4), "蜗牛每秒%d次实际输入资格" % rate, {"longest":longest,"qualified":ui.hold_qualified,"pressure":ui.pressure})
		ui.queue_free()
		await _live_capture()
		await _prop_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _prop_checks() -> void:
	for seed_value in 100:
		var layout := Catalog.random_layout(seed_value)
		_check(layout.size()==10 and layout.all(func(row): return Catalog.clear_of_props(Vector2(row.position[0],row.position[1]))), "随机出生避开物件 %d" % seed_value)
	_fresh()
	var run: Dictionary = sm.data[Run.KEY]
	var prop := Vector2(988,565)
	run.layout[0].position = [988,565]
	run.combat.layout = run.layout.duplicate(true)
	run.combat.actors.slime_1.position = [988,565]
	var roll: float = run.monsters.slime_1.capture_roll
	_check(Run.ensure_layout(run) and Run.valid(run), "旧探索重叠位置迁移保持合法")
	_check(Catalog.clear_of_props(Run.Combat.vec(run.combat.actors.slime_1.position)) and run.monsters.slime_1.capture_roll==roll,"迁移避开挖掘点且不重抽概率")
	for config in preload("res://data/maze/entry_chests.gd").all()+preload("res://data/maze/entry_dig_sites.gd").all():
		var start := Catalog.nearest_clear_point(config.position)
		var moving := start
		for step in 120:
			moving = Run.Combat.move_monster(moving,config.position,2.0)
		_check(Catalog.clear_of_props(moving), "追击避开物件 " + config.id)
	_check(not Catalog.clear_of_props(prop),"截图中的挖掘点拒绝重叠")

func _live_capture() -> void:
	_fresh()
	sm.data[preload("res://scripts/ch2_exploration_guide.gd").KEY] = {"revision":2,"step":"done","seen":{},"banked":{}}
	sm.save()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.6).timeout
	for kind in ["snail","slime","beetle","lizard"]:
		var id: String = kind + "_1"
		var run: Dictionary = sm.data[Run.KEY]
		run.monsters[id].capture_roll = 0.01
		run.first_eligible = false
		run.combat.actors[id].hp = 0
		sm.data[Run.Progression.FOOD_KEY].values = {"yaya":2.0,"tieshan":1.0}
		var flow = maze.capture_flow
		flow._encounter(id)
		await get_tree().create_timer(0.6).timeout
		await _click(flow.dialog._confirm_button)
		await get_tree().create_timer(0.4).timeout
		var ui = flow.attempt
		await _click(ui.yes_button)
		await get_tree().create_timer(2.7).timeout
		var longest := 0.0
		var deadline := Time.get_ticks_msec()+12000
		while ui.mode == "suppress" and Time.get_ticks_msec()<deadline:
			if ui.pressure < 0.98: await _send_key(KEY_J)
			longest = maxf(longest,ui.hold_time)
			await get_tree().process_frame
		await get_tree().create_timer(0.8).timeout
		_check(flow.reward.visible and Run.snapshot(sm).monsters[id].status == "captured",kind+"真实输入→操作→结算→食材",{"longest":longest,"qualified":ui.hold_qualified,"status":Run.snapshot(sm).monsters[id].status})
		_check(Run.snapshot(sm).monsters[id].capture_result.reason == "captured" and Run.snapshot(sm).monsters[id].capture_result.operation_passed,kind+"保存实际结算依据")
		await _capture_image(kind+"_capture")
		if flow.reward.visible: await _click(flow.reward._confirm_button)
		elif flow.dialog.visible: flow._dismiss()
	maze.queue_free()
	await get_tree().process_frame

func _prop_scene() -> void:
	_fresh()
	sm.data[preload("res://scripts/ch2_exploration_guide.gd").KEY] = {"revision":2,"step":"done","seen":{},"banked":{}}
	var run: Dictionary = sm.data[Run.KEY]
	var index := 0
	for row in Run.monsters_for(run):
		if row.id == "snail_1": break
		index += 1
	run.layout[index].position = [988,565]
	run.combat.layout = run.layout.duplicate(true)
	run.combat.actors.snail_1.position = [988,565]
	sm.save()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	maze.player.position = Vector2(981.5,596)
	sm.data[Run.KEY].combat.hero = [981.5,596]
	_check(Roads.is_walkable(maze.player.position),"验证站位在道路内且靠近挖掘点")
	var health: int = Run.snapshot(sm).combat.hp
	await get_tree().create_timer(5).timeout
	var current_run := Run.snapshot(sm)
	_check(Catalog.clear_of_props(Run.Combat.vec(current_run.combat.actors.snail_1.position)),"实际场景蜗牛与挖掘点分离")
	_check(current_run.combat.hp < health,"站在挖掘点仍会受到攻击",{"hero":current_run.combat.hero,"actor":current_run.combat.actors.snail_1,"health":health,"after":current_run.combat.hp})
	await _capture_image("prop_clearance")
	sm.save()
	sm.load_data()
	_check(Catalog.clear_of_props(Run.Combat.vec(Run.snapshot(sm).combat.actors.snail_1.position)),"重载保存后的物件避让位置")
	maze.queue_free()
	await get_tree().process_frame
