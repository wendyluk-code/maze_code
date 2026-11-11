extends "res://tools/tests/first_exploration.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离效果图，不修改正式游戏界面")
	if failures == 0:
		var background := TextureRect.new()
		background.texture = ImageTexture.create_from_image(Image.load_from_file("res://output/loot_groups_20261104/return_loot.png"))
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(background)
		var preview := preload("res://scripts/ui/components/restaurant_day_loot.gd").new()
		add_child(preview)
		sm.data["restaurant_day_v1"] = {}
		preview.show_loot({"brick_snail_meat":1,"slime_gel":1,"slime_shell":1,"sword_beetle_leg":1,"cooking_sake":3,"moondew_honey":3,"sour_vine_juice":3})
		preview._overlay.hide()
		for group in preview._grid.get_children():
			var empty := StyleBoxEmpty.new()
			empty.set_content_margin_all(10)
			group.add_theme_stylebox_override("panel", empty)
			var tint := Color("dceef4") if group.name == "CaptureGroup" else Color("e3efd8")
			var tiles: GridContainer = group.get_child(0).get_child(1)
			for tile in tiles.get_children():
				var icon_frame: PanelContainer = tile.get_child(0).get_child(0)
				var style := SproutTheme.thin_panel_style(tint)
				style.set_content_margin_all(8)
				icon_frame.add_theme_stylebox_override("panel", style)
		await get_tree().create_timer(0.3).timeout
		await _shot_gate("icon_tint_preview")
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
