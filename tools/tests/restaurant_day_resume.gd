extends Node

const Day := preload("res://scripts/restaurant/restaurant_day.gd")

func _ready() -> void:
	var expected := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/").trim_suffix("/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	var manager := get_node("/root/SaveManager")
	manager._active_save_path = "user://chapter-ending-test.json"
	manager.load_data()
	var day := Day.snapshot(manager)
	var passed := not expected.is_empty() and actual.begins_with(expected + "/") and int(day.get("menu", {}).get("salt_grilled_rockmane", 0)) == 2 and Day.pending_loot(manager).is_empty()
	print("RESTAURANT_DAY_RESUME ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
