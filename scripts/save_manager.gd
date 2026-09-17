extends Node
## 存档管理器（Autoload: SaveManager）
## 全量 JSON 存档，路径 user://save.json；维护教程兼容标记与章节完成状态

const SAVE_PATH := "user://save.json"
const CHAPTER_1_DONE_KEY := "chapter_1_done"

var data: Dictionary = _defaults()

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"tutorial_done": false,
		CHAPTER_1_DONE_KEY: false,
	}

func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				# 旧存档可能只有 tutorial_done；合并默认值而不是丢弃未知字段，
				# 这样旧存档能继续使用，同时缺少第一章标记时会进入第一章。
				data = _defaults()
				for key in parsed:
					data[key] = parsed[key]
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

func is_chapter_1_done() -> bool:
	return bool(data.get(CHAPTER_1_DONE_KEY, false))

func mark_chapter_1_done() -> void:
	data[CHAPTER_1_DONE_KEY] = true
