extends Control
const Catalog = preload("res://scripts/cooking/recipe_catalog.gd")
func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#f4e3bf")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var visual := preload("res://scripts/cooking/cooking_visual.gd").new()
	visual.position = Vector2(140, 30)
	visual.size = Vector2(872, 580)
	add_child(visual)
	var title := Label.new()
	title.theme = SproutTheme.make_theme()
	title.position = Vector2(30, 20)
	add_child(title)
	var output := "res://output/cooking_icon_review"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	for id in Catalog.recipe_ids():
		title.text = Catalog.get_recipe(id).name
		visual.set_ingredients(Catalog.get_recipe(id).ingredients)
		if "--random-zones" in OS.get_cmdline_user_args():
			var zones = preload("res://scripts/cooking/qte_judgement.gd").random_zones()
			visual.perfect_width = zones.perfect
			visual.good_width = zones.good
			visual.zone_center = zones.center
		visual.set_running(true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output + "/" + id + ".png")
		for item in visual._icons:
			var size: Vector2 = visual._icons[item].get_size()
			print(item, " visible source=", size, " display=", size * minf(160.0/size.x,144.0/size.y))
	get_tree().quit()
