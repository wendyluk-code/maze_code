extends "res://tools/tests/ice_binary_flow.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	_seed_cycle()
	scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(.5).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var view = hud.ganlu.freezer_view
	var layout = scene.get_node("InteractPoints/Fridge/FreezerLayout")
	_check(layout.visible and layout.get_node("Tray").texture != null,"原图接入实际场景")
	var player = scene.get_node("Player")
	player.set_physics_process(false)
	var fridge = layout.get_parent()
	var foreground = scene.get_node("PropForeground")
	var layer = foreground.get_node("FridgeForeground")
	player.position = fridge.position + Vector2(70,60)
	player.last_valid = player.position
	await get_tree().create_timer(.2).timeout
	_check(layer.visible,"复现站位启用冰柜前景")
	await _shot_gate("foreground_on")
	foreground.set_process(false)
	layer.hide()
	await _shot_gate("foreground_off")
	layer.show()
	_check(layer.material != null,"冰柜前景具有凹槽边界避让")
	foreground.set_process(true)
	player.position = fridge.position + Vector2(150,150)
	await get_tree().create_timer(.2).timeout
	_check(not layer.visible,"柜前仍不遮挡人物")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit()


