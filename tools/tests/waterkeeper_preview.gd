extends Node
## 只加载专项验收留下的隔离存档，不建立剧情或发奖。
func _ready() -> void:
	var profile := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(profile):
		push_error("小屋预览必须使用隔离存档目录")
		get_tree().quit(1)
		return
	SaveManager._active_save_path="user://chapter-ending-test.json"
	get_window().title="料理迷宫 · 守水人小屋（隔离预览）"
	SaveManager.load_data()
	if SaveManager.maze_exploration_state().region!="waterkeeper_cottage":
		push_error("请先运行小屋流程验收，准备隔离预览档")
		get_tree().quit(1)
		return
	get_tree().change_scene_to_file.call_deferred(SaveManager.resume_scene_path())
