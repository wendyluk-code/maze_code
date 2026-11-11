@tool
extends RefCounted
## 仅管理音量；不启动、停止播放器，不读取玩家存档。
const Catalog = preload("res://scripts/audio/audio_catalog.gd")
const SAVE_PATH := "res://data/audio/mix.json"
const PREVIEW_PATH := "res://.godot/audio_mix_preview.json"
const GROUPS := ["总音量", "音乐", "音效", "对白"]
const MIN_DB := -60.0
const MAX_DB := 6.0
var entries: Dictionary = {}
var settings: Dictionary = {"version":1, "cues":{}, "groups":{}}
var saved_settings: Dictionary = {"version":1, "cues":{}, "groups":{}}
var save_path := SAVE_PATH
var preview_path := PREVIEW_PATH
var allow_preview := OS.has_feature("editor") and not Engine.is_editor_hint()
var last_error := ""
var preview_active := false
var _saved_text := ""
var _bindings: Array[Dictionary] = []

func _init() -> void:
	for entry in Catalog.entries(): entries[entry.id] = entry

func load_saved() -> bool:
	if not FileAccess.file_exists(save_path):
		saved_settings = {"version":1, "cues":{}, "groups":{}}
		_saved_text = ""
		last_error = ""
		return true
	var content := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = parse_json(content)
	if not valid(parsed):
		_saved_text = content
		last_error = "音量配置无效，保留上次有效设置：" + save_path
		return false
	saved_settings = parsed
	_saved_text = content
	last_error = ""
	return true

func refresh() -> void:
	var content := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	if content != _saved_text: load_saved()
	var next := saved_settings
	preview_active = false
	if allow_preview and FileAccess.file_exists(preview_path):
		var preview: Variant = parse_json(FileAccess.get_file_as_string(preview_path))
		if preview is Dictionary and (preview.get("expires", 0) is float or preview.get("expires", 0) is int):
			if float(preview.get("expires", 0)) > Time.get_unix_time_from_system() and valid(preview.get("mix")):
				next = preview.mix
				preview_active = true
	if settings != next:
		settings = next.duplicate(true)
		apply_all()

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	if not value.get("cues") is Dictionary or not value.get("groups") is Dictionary: return false
	for section in ["cues", "groups"]:
		for key in value[section]:
			if section == "cues" and not entries.has(key): return false
			if section == "groups" and not GROUPS.has(key): return false
			var db: Variant = value[section][key]
			if not (db is float or db is int): return false
			if not is_finite(float(db)) or db < MIN_DB or db > MAX_DB: return false
	return true

func cue_db(id: String) -> float:
	return float(settings.cues.get(id, entries.get(id, {}).get("db", -6.0)))

func group_db(group: String) -> float:
	return float(settings.groups.get(group, 0.0))

func effective_db(id: String) -> float:
	var category: String = entries.get(id, {}).get("category", "音效")
	return cue_db(id) + group_db(category) + group_db("总音量")

func bind_player(player: AudioStreamPlayer, id: String) -> void:
	if not entries.has(id):
		push_error("未知音频用途："+id)
		return
	for binding in _bindings:
		if binding.player.get_ref() == player:
			binding.id = id
			player.volume_db = effective_db(id)
			return
	_bindings.append({"player":weakref(player), "id":id})
	player.volume_db = effective_db(id)

func apply_all() -> void:
	for i in range(_bindings.size()-1, -1, -1):
		var player: AudioStreamPlayer = _bindings[i].player.get_ref()
		if not is_instance_valid(player):
			_bindings.remove_at(i)
		else:
			player.volume_db = effective_db(_bindings[i].id)

func set_cue_db(id: String, db: float) -> void:
	settings.cues[id] = clampf(db, MIN_DB, MAX_DB)
	apply_all()

func set_group_db(group: String, db: float) -> void:
	settings.groups[group] = clampf(db, MIN_DB, MAX_DB)
	apply_all()

func save() -> Error:
	if not valid(settings): return ERR_INVALID_DATA
	var err := write_json(save_path, settings)
	if err == OK:
		saved_settings = settings.duplicate(true)
		_saved_text = FileAccess.get_file_as_string(save_path)
	return err

static func parse_json(content: String) -> Variant:
	# 显式处理损坏文件；避免每次轮询向调试器刷出解析错误。
	var parser := JSON.new()
	return parser.data if parser.parse(content) == OK else null

static func write_json(path: String, value: Dictionary) -> Error:
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if dir_err != OK: return dir_err
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK: return err
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
