extends Node

func _ready() -> void:
	var profile := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/"):
		get_tree().quit(2)
		return
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://output/order_gold/baseline_save_manager.gd")
	if script.reload() != OK:
		get_tree().quit(2)
		return
	var baseline = script.new()
	add_child(baseline)
	baseline.data = baseline._defaults()
	baseline._active_save_path = "user://baseline-order.json"
	var setup: bool = baseline.accept_first_order().success and baseline.claim_first_order_ingredients().success and baseline.cook_first_order().success
	var delivered: Dictionary = baseline.deliver_first_order()
	var reproduced: bool = setup and delivered.success and baseline.gold_balance() == 0 and not delivered.has("gold_awarded")
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":1,"failures":0 if reproduced else 1,"baseline_gold":baseline.gold_balance(),"reproduced_missing_gold":reproduced}, "\t"))
	get_tree().quit(0 if reproduced else 1)

func _arg(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.substr(prefix.length())
	return ""
