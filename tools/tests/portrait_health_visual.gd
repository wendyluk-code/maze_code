extends "res://tools/tests/combat_04_access.gd"
## 在真实餐厅背景检查共用对白头像与探索准备图标。
func _access() -> void:
	await super._access()
	scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.5).timeout
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	var dialog = load("res://scenes/ui/dialog_box.tscn").instantiate()
	layer.add_child(dialog)
	for customer in preload("res://scripts/restaurant/customer_catalog.gd").CUSTOMERS:
		dialog.start(customer.name, ["请给我一份料理。"], load(customer.portrait))
		dialog._advance()
		await get_tree().create_timer(0.2).timeout
		_check(dialog.portrait.get_theme_stylebox("panel").bg_color == Color.WHITE, "冒险者头像不透明白底：" + customer.id)
		await _capture_image("portrait_" + customer.id)
		dialog._advance()
		_check(not dialog.visible, "对白正常关闭：" + customer.id)
	layer.queue_free()
	var team = preload("res://scripts/ui/components/team_entry_modal.gd").new()
	get_tree().root.add_child(team)
	team.open_exploration()
	await get_tree().create_timer(0.3).timeout
	await _capture_image("team_health")
	team.queue_free()
	scene.queue_free()
	await get_tree().process_frame
