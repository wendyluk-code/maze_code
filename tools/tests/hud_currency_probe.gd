extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	_check(sm.has_method("is_gold_display_unlocked"), "提供持久金币显示资格查询")
	_completed()
	await _open_scene()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.get("reputation_counter") != null, "餐厅声望由图标与数值呈现")
	await _close_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
