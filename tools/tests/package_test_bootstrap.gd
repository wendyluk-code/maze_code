extends Node
## 测试资源另装入临时 PCK，始终使用发行包内的游戏资源与脚本。
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ProjectSettings.load_resource_pack(OS.get_environment("MAZE_TEST_PCK")):
		push_error("测试资源包加载失败")
		get_tree().quit(2)
		return
	var path := OS.get_environment("MAZE_TEST_ENTRY")
	if path.ends_with(".tscn"):
		var error := get_tree().change_scene_to_file(path)
		if error != OK:
			push_error("验收场景加载失败：" + path)
			get_tree().quit(2)
	else:
		var script = load(path)
		if script == null:
			get_tree().quit(2)
			return
		get_tree().root.add_child(script.new())
