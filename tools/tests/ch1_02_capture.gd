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
	var tutorial = restaurant.get_node("UIOverlay/TutorialGuide")
	get_tree().root.get_node("TutorialManager").start()
	await get_tree().process_frame
	await get_tree().process_frame
	var expected_line := "……你终于醒了。"
	var frames := 0
	while tutorial.dialog.dialog_text.text != expected_line and frames < 120:
		frames += 1
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
	var player := restaurant.get_node("Player")
	var zone := restaurant.get_node("WalkZone")
	var valid_entry: bool = tutorial.dialog.speaker_name.text == "芽芽" \
		and tutorial.dialog.dialog_text.text == expected_line \
		and player.spawn_ready and player.input_locked and not player.is_physics_processing() \
		and zone.is_circle_inside(player.global_position, player.collision_radius_world()) \
		and player.nearest_interactable() == null
	print("CH1_02 capture=", output, " size=", image.get_size(),
		" title=", tutorial.chapter_title.text,
		" stage=", tutorial.chapter_stage.text,
		" dialog=", tutorial.dialog.speaker_name.text, ":", tutorial.dialog.dialog_text.text,
		" spawn_ready=", player.spawn_ready,
		" spawn=", player.global_position,
		" spawn_safe=", zone.is_circle_inside(player.global_position, player.collision_radius_world()),
		" nearest=", player.nearest_interactable(),
		" valid_entry=", valid_entry,
		" error=", err)
	get_tree().quit(0 if err == OK and valid_entry else 1)

func argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
