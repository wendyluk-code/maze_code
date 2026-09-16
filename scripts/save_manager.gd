extends Node
## 存档管理器（Autoload: SaveManager）
## 全量 JSON 存档，路径 user://save.json；当前只维护新手教学等核心标记

const SAVE_PATH := "user://save.json"

var data: Dictionary = { "tutorial_done": false }

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"tutorial_done": false,
	}

func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				data = parsed
				return
	data = _defaults()

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func is_tutorial_done() -> bool:
	return bool(data.get("tutorial_done", false))

func mark_tutorial_done() -> void:
	data["tutorial_done"] = true