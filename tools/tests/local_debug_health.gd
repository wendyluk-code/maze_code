extends "res://tools/tests/chapter_ending_input.gd"

const Run = preload("res://scripts/maze/capture_run.gd")
const Roads = preload("res://data/maze/entry_roads.gd")

func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离用户存档")
	var debug = get_node("/root/LocalDebug")
	_check(debug.has_method("heal_party"), "调试工具提供共享生命恢复入口")
	if failures == 0:
		_seed()
		for step in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(step)
		var before: Dictionary = sm.data.duplicate(true)
		_check(not debug.heal_party().success and sm.data == before, "没有探索时不改存档")
		_check(Run.begin(sm, Roads.SPAWN).success, "建立真实探索")
		sm.data[Run.KEY].combat.hp = 1
		sm.save()
		before = sm.data.duplicate(true)
		var expected: int = Run.snapshot(sm).combat.max_hp
		_check(debug.heal_party().success, "一键满血提交成功")
		_check(Run.snapshot(sm).combat.hp == expected, "共享生命恢复至当前上限")
		var after: Dictionary = sm.data.duplicate(true)
		after[Run.KEY].combat.hp = before[Run.KEY].combat.hp
		_check(after == before, "满血不改变物品饱腹怪物或其他状态")
		sm.load_data()
		_check(Run.snapshot(sm).combat.hp == expected, "读档保留恢复后的生命")
		sm.data[Run.KEY].combat.hp = 1
		before = sm.data.duplicate(true)
		var save_path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not debug.heal_party().success and sm.data == before, "满血保存失败完整回滚")
		sm._active_save_path = save_path
		sm.begin_replay()
		_check(not debug.heal_party().success, "重播不能用调试满血写档")
		sm.end_replay()
		await _heal_key(KEY_0,false)
		_check(Run.snapshot(sm).combat.hp == 1, "单独按0不恢复生命")
		await _heal_key(KEY_0,true)
		_check(Run.snapshot(sm).combat.hp == expected, "Ctrl加主键区0实际恢复生命")
		sm.data[Run.KEY].combat.hp = 1
		await _heal_key(KEY_0,true,true)
		_check(Run.snapshot(sm).combat.hp == 1, "长按重复事件不连续满血")
		await _heal_key(KEY_KP_0,true)
		_check(Run.snapshot(sm).combat.hp == expected, "Ctrl加小键盘0实际恢复生命")
		debug.open_panel()
		var heal_button: Button
		for button in debug.panel.find_children("*","Button",true,false):
			if button.text == "回满生命（Ctrl+0）": heal_button = button
		_check(is_instance_valid(heal_button), "调试面板提供回满生命按钮")
		debug.close_panel()
	FileAccess.open(_arg("--report="), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _heal_key(code: Key, control: bool, repeated := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = control
	event.pressed = true
	event.echo = repeated
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	get_viewport().push_input(event)
	await get_tree().process_frame
