extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"独立预览隔离正式存档")
	_completed()
	sm.cancel_maze_entry()
	DisplayServer.window_set_size(Vector2i(1152,648))
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().process_frame
	maze.capture_flow.set_process(false)
	maze.capture_flow.hud.hide()
	maze.player.position = Vector2(688,396)
	maze.player.set_physics_process(false)
	maze.camera.snap_to_target()
	# 仅预览夹具：用24展示与蜗牛相等时的红色边界，不写角色数值。
	var power := 24
	for monster in maze.capture_flow.monsters.values():
		monster.set_process(false)
		monster.label.text = str(monster.config.power)
		monster.label.add_theme_color_override("font_color",Color("#ef7165") if monster.config.power>=power else SproutTheme.CREAM)
		monster.label.add_theme_constant_override("outline_size",2)
		if monster.config.kind=="slime": monster.body.scale *= 0.70
		var height: float = monster.body.texture.get_height()*monster.body.scale.y
		monster.label.position.y = -height-24
	var power_label := Label.new()
	power_label.text = str(power)
	power_label.add_theme_font_override("font",SproutTheme.FONT_CN)
	power_label.add_theme_font_size_override("font_size",16)
	power_label.add_theme_color_override("font_color",SproutTheme.CREAM)
	power_label.add_theme_color_override("font_outline_color",SproutTheme.INK)
	power_label.add_theme_constant_override("outline_size",2)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.position = Vector2(-40,-91)
	power_label.size = Vector2(80,24)
	maze.player.add_child(power_label)
	await get_tree().create_timer(0.4).timeout
	suffix = ""
	await _capture_image("01_map")
	var modal := _make_modal(true)
	maze._ui_root.add_child(modal)
	await get_tree().create_timer(0.25).timeout
	await _capture_image("02_victory")
	modal.queue_free()
	await get_tree().process_frame
	modal = _make_modal(false)
	maze._ui_root.add_child(modal)
	await get_tree().create_timer(0.25).timeout
	await _capture_image("03_insufficient")
	_check(modal.get_node("Panel").get_global_rect().end.x<1152,"预览面板未超出视口")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func _make_modal(won: bool) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = SproutTheme.make_theme()
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	root.add_child(overlay)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style())
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -157
	panel.offset_bottom = 157
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	column.add_child(_label("战斗胜利" if won else "战力不足",24,SproutTheme.INK))
	column.add_child(_label("击败它了！\n是否将它捕获变为食材？" if won else "当前战力不足，请先提升战力再来。",18,SproutTheme.INK))
	var info := VBoxContainer.new()
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation",10)
	column.add_child(info)
	if won:
		info.add_child(_label("已吸收战力 +8",20,Color("#69755b")))
		info.add_child(_label("捕获率 80%    ·    剩余饱腹度 69",16,SproutTheme.INK_MUTED))
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation",28)
		info.add_child(row)
		row.add_child(_label("当前战力 24",20,SproutTheme.INK))
		row.add_child(_label("魔物战力 24",20,Color("#b84b40")))
		info.add_child(_label("战力提升方式\n击败魔物、升级或更换角色",16,SproutTheme.INK_MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation",14)
	column.add_child(buttons)
	for caption in (["否","是（消耗饱腹度1）"] if won else ["知道了"]):
		var button := SproutButton.new()
		button.configure(caption)
		button.set_icon_visible(false)
		button.set_focus_visual(false)
		button.custom_minimum_size = Vector2(124 if caption=="否" else 190,40)
		buttons.add_child(button)
	return root
