extends Node
## 普通分水庭非模态对白；原战斗和探索事务继续推进。

const DialogScene = preload("res://scenes/ui/dialog_box.tscn")
const GuideScript = preload("res://scripts/maze/fenshui_guide_script.gd")
const Run = preload("res://scripts/maze/capture_run.gd")
const Fenshui = preload("res://data/maze/fenshui_roads.gd")
const Salt = preload("res://data/maze/salt_pool_roads.gd")
const Moss = preload("res://data/maze/moss_pool_roads.gd")
const SEEN_KEY := "fenshui_battle_guide_seen"
const KEY_COLOR := "ad4c16"
const ENTRY_RADIUS := 180.0

var maze: Node2D
var dialog: Control
var rich_text: RichTextLabel
var continue_label: Label
var lines: Array = GuideScript.lines()
var seen_key := SEEN_KEY
var dialog_name := "FenshuiGuideDialog"
var index := 0
var started := false
var completed := false
var armed := true

func attach(owner_maze: Node2D) -> void:
	maze = owner_maze
	process_priority = 20
	completed = SaveManager.get("_state").get(seen_key, false) == true
	dialog = DialogScene.instantiate()
	dialog.name = dialog_name
	maze._ui_root.add_child(dialog)
	dialog.hide_box()
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.anchor_left = 0.08
	dialog.anchor_right = 0.92
	dialog.anchor_top = 0.17
	dialog.anchor_bottom = 0.35
	dialog.offset_left = 0.0
	dialog.offset_right = 0.0
	dialog.offset_top = 0.0
	dialog.offset_bottom = 0.0
	var background := ColorRect.new()
	background.name = "GuideBackground"
	background.color = Color("f7e5c5")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 12.0
	background.offset_top = 12.0
	background.offset_right = -12.0
	background.offset_bottom = -12.0
	dialog.move_child(background, 0)
	dialog.next_icon.offset_left = -105.0
	dialog.next_icon.offset_right = -57.0
	continue_label = Label.new()
	continue_label.name = "GuideContinue"
	continue_label.text = "继续"
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_label.add_theme_font_override("font", preload("res://assets/ui/game_font.tres"))
	continue_label.add_theme_font_size_override("font_size", 16)
	continue_label.add_theme_color_override("font_color", Color("654622"))
	dialog.add_child(continue_label)
	continue_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	continue_label.offset_left = -54.0
	continue_label.offset_top = -55.0
	continue_label.offset_right = -15.0
	continue_label.offset_bottom = -25.0
	dialog.dialog_text.hide()
	rich_text = RichTextLabel.new()
	rich_text.name = "GuideRichText"
	rich_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich_text.bbcode_enabled = true
	rich_text.scroll_active = false
	rich_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_text.add_theme_font_override("normal_font", preload("res://assets/ui/game_font.tres"))
	rich_text.add_theme_font_size_override("normal_font_size", 19)
	rich_text.add_theme_color_override("default_color", Color(0.3, 0.19, 0.08))
	dialog.dialog_text.get_parent().add_child(rich_text)
	dialog.finished.connect(_next)
	armed = not Input.is_action_pressed("interact")

func _process(_delta: float) -> void:
	if not is_instance_valid(maze) or not is_instance_valid(dialog): return
	if completed:
		dialog.hide()
		return
	if not _safe_to_show():
		dialog.hide()
		return
	if not started:
		if not _near_entrance(maze.player.position): return
		started = true
		_show_line()
	elif not dialog.visible:
		dialog.show()
	if dialog.visible:
		rich_text.visible_characters = dialog.dialog_text.text.length()
		continue_label.visible = dialog.next_icon.visible

func _safe_to_show() -> bool:
	if not maze._entry_ready or not is_instance_valid(maze.capture_flow): return false
	if maze.capture_flow.combat_paused(): return false
	if is_instance_valid(maze.yf_encounter) and maze.yf_encounter.phase not in ["unseen", "done"]: return false
	var run: Dictionary = Run.snapshot(SaveManager)
	if not run.get("active", false) or run.get("combat", {}).get("fs01_trial", false): return false
	return not Run.portal_combat_locked(SaveManager)

func _near_entrance(point: Vector2) -> bool:
	for entry in [Fenshui.SPAWN, Salt.FENSHUI_RETURN, Moss.FENSHUI_RETURN]:
		if point.distance_to(entry) <= ENTRY_RADIUS: return true
	return false

func _show_line() -> void:
	var row: Dictionary = lines[index]
	var portrait: Texture2D = preload("res://assets/characters/yaya_portrait.png") if row.speaker == "芽芽" else preload("res://assets/characters/player_portrait.png")
	dialog.start(row.speaker, [row.text], portrait)
	rich_text.text = _highlighted(row.text, row.highlights)
	rich_text.visible_characters = 0

func _highlighted(text: String, words: Array) -> String:
	var result := ""
	var at := 0
	while at < text.length():
		var matched := ""
		for word in words:
			if not str(word).is_empty() and text.substr(at).begins_with(str(word)):
				matched = str(word)
				break
		if matched.is_empty():
			result += text.substr(at, 1)
			at += 1
		else:
			result += "[color=#" + KEY_COLOR + "]" + matched + "[/color]"
			at += matched.length()
	return result

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.keycode != KEY_E: return
	if not event.pressed:
		armed = true
		return
	if event.echo or not armed or not is_instance_valid(dialog) or not dialog.visible or not _safe_to_show(): return
	armed = false
	get_viewport().set_input_as_handled()
	dialog._advance()

func _next() -> void:
	if index < lines.size() - 1:
		index += 1
		_show_line()
		return
	var previous: Dictionary = SaveManager.get("_state").duplicate(true)
	SaveManager.get("_state")[seen_key] = true
	if SaveManager.save():
		completed = true
		dialog.hide_box()
	else:
		SaveManager.set("_state", previous)
		maze.show_toast("引导进度未保存，请按 E 重试")
		_show_line()

func _exit_tree() -> void:
	if is_instance_valid(dialog): dialog.queue_free()
