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
	var slot = layout.get_node("Slot1")
	var before: Vector2 = view.slot_position(0)
	slot.position += Vector2(7,9)
	_check(view.slot_position(0).is_equal_approx(before+Vector2(7,9)),"杯位读取编辑坐标")
	var anchor = slot.get_node("Thermometer")
	anchor.position += Vector2(4,2)
	_check(view.anchor_position(0,"Thermometer").is_equal_approx(view.to_local(anchor.global_position)),"温度计读取编辑坐标")
	await get_tree().create_timer(.1).timeout
	_check(view.buttons[0].position.is_equal_approx(view.slot_position(0)-Vector2(25,48)),"点击区域跟随杯位")
	slot.position -= Vector2(7,9)
	anchor.position -= Vector2(4,2)
	_check(not slot.get_node("Selection").visible,"辅助面运行时隐藏")
	var player = scene.get_node("Player")
	player.position = _stand(layout.get_parent())
	player.last_valid = player.position
	await get_tree().create_timer(.3).timeout
	await _shot_gate("editable_freezer")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit()

