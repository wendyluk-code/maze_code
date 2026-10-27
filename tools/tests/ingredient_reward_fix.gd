extends "res://tools/tests/maze_capture.gd"
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Loot := preload("res://scripts/ui/components/loot_modal.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _scene_checks()
			await _all_icons()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("INGREDIENT_REWARD ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _capture_image(label: String) -> void:
	if label == "first_capture":
		var reward = maze.capture_flow.reward
		_check(reward._title_label.text == "获得食材", "奖励标题无出口带回")
		_check(reward.item_views[0].name.text == "史莱姆核", "实际捕获显示史莱姆核")
		_check(reward.item_views[0].icon.texture != null, "实际捕获史莱姆核有图标")
	await super._capture_image(label)

func _all_icons() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var modal := Loot.new()
	layer.add_child(modal)
	var items: Array[Dictionary] = [{"name":"宝箱金币","quantity":100,"icon":Loot.coin_texture()}]
	var ids: Array[String] = []
	for row in Catalog.TYPES.values():
		for id in row.drops:
			if not ids.has(id): ids.append(id)
	for id in ids:
		items.append({"name":Recipes.get_ingredient(id).name,"quantity":1,"icon":Recipes.item_texture(id)})
	modal.show_items(items)
	modal._title_label.text = "金币与全部捕获食材图标对照"
	await get_tree().process_frame
	for item in modal.item_views:
		var texture: Texture2D = item.icon.texture
		_check(texture != null, "图标存在：" + item.name.text)
		if texture == null: continue
		var image := texture.get_image()
		var rect := image.get_used_rect()
		var ratio := maxf(float(rect.size.x),float(rect.size.y)) / maxf(float(image.get_width()),float(image.get_height()))
		_check(ratio >= 0.95 and item.icon.size == Vector2(43,43), "可见轮廓填满金币同尺寸区域：" + item.name.text)
	await RenderingServer.frame_post_draw
	await _capture(_arg("--output-dir="), "all_reward_icons" + suffix)
	modal.close_modal()
	layer.queue_free()
	await get_tree().process_frame
