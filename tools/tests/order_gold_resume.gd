extends Node
func _ready() -> void:
	var profile := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/"):
		get_tree().quit(2)
		return
	var sm = get_node("/root/SaveManager")
	var disk := FileAccess.get_file_as_bytes("user://save.json")
	var ok: bool = sm.gold_balance() == 5 and sm.reputation() == 80 and sm.has_first_order_settlement() and not sm.deliver_customer_order().success and FileAccess.get_file_as_bytes("user://save.json") == disk
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			FileAccess.open(argument.substr(9), FileAccess.WRITE).store_string(JSON.stringify({"checks":1,"failures":0 if ok else 1,"independent_process_resume":ok}, "\t"))
	get_tree().quit(0 if ok else 1)
