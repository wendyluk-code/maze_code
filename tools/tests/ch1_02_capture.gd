extends Node

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	var save_manager := get_tree().root.get_node("SaveManager")
	save_manager.data = {"tutorial_done": false, "chapter_1_done": false}
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	restaurant.get_node("Player").spawn_ready = true
	var tutorial = restaurant.get_node("UIOverlay/TutorialGuide")
	get_tree().root.get_node("TutorialManager").start()
	await get_tree().process_frame
	await get_tree().process_frame
	var output := argument("--output=")
	if output.is_empty():
		push_error("--output is required")
		get_tree().quit(1)
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("CH1_02 visual capture requires a non-headless rendering viewport")
		get_tree().quit(2)
		return
	var image := viewport_texture.get_image()
	var err := image.save_png(output)
	print("CH1_02 capture=", output, " size=", image.get_size(),
		" title=", tutorial.chapter_title.text,
		" stage=", tutorial.chapter_stage.text,
		" dialog=", tutorial.dialog.speaker_name.text, ":", tutorial.dialog.dialog_text.text,
		" error=", err)
	get_tree().quit(0 if err == OK else 1)

func argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
