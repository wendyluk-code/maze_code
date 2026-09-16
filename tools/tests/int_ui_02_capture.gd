extends Node

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	get_tree().root.get_node("SaveManager").data["tutorial_done"] = true
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	var player := restaurant.get_node("Player")
	player.spawn_ready = true
	var camera := restaurant.get_node("Camera")
	var ui := restaurant.get_node("UIOverlay")
	var output_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output_dir = arg.substr("--output-dir=".length())
	if output_dir.is_empty():
		push_error("--output-dir is required")
		get_tree().quit(1)
		return
	var failures := 0
	for shot in [{"name": "store", "point": Vector2(1400, 630), "target": "Store"},
			{"name": "multi", "point": Vector2(900, 420), "target": "Cauldron"}]:
		player.global_position = shot["point"]
		player.last_valid = player.global_position
		camera.global_position = player.global_position
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var target := restaurant.get_node("InteractPoints/" + shot["target"])
		var button: Control = ui._buttons.get(target)
		var image := get_viewport().get_texture().get_image()
		var path := output_dir.path_join("INT-UI-02-" + shot["name"] + "-scene.png")
		var err := image.save_png(path)
		print("INT_UI_02 capture=", path, " size=", image.get_size(),
			" button_visible=", button.visible if button else false, " error=", err)
		if err != OK or button == null or not button.visible:
			failures += 1
	get_tree().quit(0 if failures == 0 else 1)
