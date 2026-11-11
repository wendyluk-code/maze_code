@tool
extends EditorPlugin
const MixerPanel = preload("res://addons/audio_mixer/mixer_panel.gd")
var panel: Control

func _enter_tree() -> void:
	panel = MixerPanel.new()
	panel.source_requested.connect(_open_source)
	add_control_to_bottom_panel(panel, "音效管理")
	add_tool_menu_item("打开音效管理", _show_panel)

func _show_panel() -> void:
	make_bottom_panel_item_visible(panel)

func _open_source(path: String) -> void:
	var resource := load(path)
	if resource is Script:
		EditorInterface.edit_script(resource)
		EditorInterface.set_main_screen_editor("Script")
	elif path.ends_with(".tscn"):
		EditorInterface.open_scene_from_path(path)
	else:
		EditorInterface.get_file_system_dock().navigate_to_path(path)

func _exit_tree() -> void:
	remove_tool_menu_item("打开音效管理")
	if is_instance_valid(panel):
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
