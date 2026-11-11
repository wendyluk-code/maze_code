extends "res://tools/tests/first_exploration.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	_check(_verify_isolation(),"仅制作冰镇方案预览")
	var board := preload("res://tools/tests/ice_redesign_board.gd").new()
	add_child(board)
	for page in 2:
		board.page = page
		board.queue_redraw()
		await get_tree().create_timer(0.2).timeout
		await _shot_gate("freezer_states" if page==0 else "orders_and_carry")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit()
