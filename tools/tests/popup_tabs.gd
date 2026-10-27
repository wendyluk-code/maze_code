extends "res://tools/tests/ch1_qte_03_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		sm.data = sm._defaults()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			for kind in ["freezer_modal", "team_entry_modal", "recipe_book_panel", "warehouse_modal"]:
				var path: String = "res://scripts/ui/" + ("" if kind == "warehouse_modal" else "components/") + kind + ".gd"
				var modal = load(path).new()
				add_child(modal)
				if kind == "warehouse_modal": modal.open_empty_stock()
				if kind == "freezer_modal": modal.open()
				if kind == "team_entry_modal":
					modal.cancelled.connect(modal.hide)
					modal.open_exploration()
					modal._open_selector()
				await get_tree().process_frame
				await get_tree().process_frame
				var bar: TabBar = modal._tabs if kind == "warehouse_modal" else modal.tabs
				for index in range(bar.tab_count):
					bar.current_tab = index
					var point := bar.global_position + bar.get_tab_rect(index).get_center()
					get_viewport().warp_mouse(point)
					var motion := InputEventMouseMotion.new()
					motion.position = point
					Input.parse_input_event(motion)
					bar.grab_focus()
					await get_tree().process_frame
					for state in ["font_hovered_color", "font_hovered_selected_color"]:
						_check(bar.get_theme_color(state) == SproutTheme.INK, kind + "悬停深色文字" + state)
					await RenderingServer.frame_post_draw
					await _capture(_arg("--output-dir="), "%s_%d_%d" % [kind,resolution.x,index])
				if kind == "freezer_modal":
					var table: Control = bar.get_parent().get_parent().get_parent()
					_check(bar.global_position.x >= table.global_position.x + 2 and bar.global_position.y >= table.global_position.y + 2, "冰柜页签位于边框以内")
					var empty: Label = modal.recipes.get_child(0)
					_check(empty.get_theme_font_size("font_size") == 16 and empty.get_theme_color("font_color") == SproutTheme.INK_MUTED, "冰柜空态与烹饪一致")
				await _send_key(KEY_ESCAPE)
				if kind == "team_entry_modal":
					_check(not modal.selector.visible and modal.visible, "Esc选人返回组队")
					await _send_key(KEY_ESCAPE)
				_check(not modal.visible, kind + "Esc关闭弹窗")
				modal.queue_free()
				await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
