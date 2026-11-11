extends "res://tools/tests/first_exploration.gd"
const Cup := preload("res://tools/tests/ganlu_cup_preview.gd")
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离预览")
	if failures == 0:
		_completed()
		sm.complete_chapter_1()
		sm.data[Gate.KEY] = "done"
		sm.data["freezer_unlock_notice_seen"] = true
		sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"revision":2}
		tm.active = false
		var restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(restaurant)
		get_tree().current_scene = restaurant
		await get_tree().create_timer(0.5).timeout
		var layer := CanvasLayer.new()
		layer.layer = 120
		add_child(layer)
		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0,0,0,0.45)
		layer.add_child(shade)
		for state in ["retry","success","overflow"]:
			var ok: bool = state == "success"
			var popup := preload("res://scripts/ui/cooking_result_popup.gd").new()
			layer.add_child(popup)
			popup.present("甘露水准备好了" if ok else "水量不足",null,1)
			popup._stars.hide()
			popup._icon.hide()
			popup._dish_name.hide()
			var rows: VBoxContainer = popup._panel.get_child(0)
			rows.get_child(0).text = {"retry":"水太少了！","success":"甘露水准备好了","overflow":"水太满了！"}[state]
			rows.get_child(0).add_theme_color_override("font_color",Color("426044") if ok else Color("a15c43"))
			var center := CenterContainer.new()
			rows.add_child(center)
			rows.move_child(center,1)
			var cup := Cup.new()
			cup.custom_minimum_size = Vector2(86,120)
			cup.fill = 0.78 if ok else 0.28
			if state == "overflow":
				cup.fill = 1.15
				cup.overflow = true
			center.add_child(cup)
			popup._confirm_button.text = "端起" if ok else "重新倒水"
			await get_tree().create_timer(0.4).timeout
			await _shot_gate(state)
			popup.queue_free()
			await get_tree().process_frame
		shade.hide()
		var player = get_tree().get_first_node_in_group("player")
		var held := Cup.new()
		held.size = Vector2(19,26)
		held.backing = true
		held.position = player.get_global_transform_with_canvas().origin + Vector2(30,-75)
		layer.add_child(held)
		await get_tree().create_timer(0.2).timeout
		await _shot_gate("carried")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
