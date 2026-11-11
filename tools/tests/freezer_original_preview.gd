extends "res://tools/tests/ice_binary_flow.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离预览")
	_seed_cycle()
	scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(.5).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var old = hud.ganlu.freezer_view
	var parent = old.get_parent()
	parent.remove_child(old)
	old.queue_free()
	var view := preload("res://tools/tests/freezer_original_preview_view.gd").new()
	view.controller = hud.ganlu
	hud.ganlu.freezer_view = view
	parent.add_child(view)
	hud.ganlu.set_process(false)
	var player = scene.get_node("Player")
	player.position = _stand(parent)
	player.last_valid = player.position
	await get_tree().create_timer(.4).timeout
	await _shot_gate("empty_slots")
	var state := Drink.snapshot(sm)
	state.slots[view.nearest_slot()] = {"amount":.65,"phase":"ready","cold":3.0,"chill_revision":3}
	Drink.commit(sm,state)
	await get_tree().create_timer(.3).timeout
	await _shot_gate("cup_in_slot")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit()
