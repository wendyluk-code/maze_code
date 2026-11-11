extends "res://tools/tests/ch2_entry_state.gd"

const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Run := preload("res://scripts/maze/capture_run.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_completed()
		_check(Day.snapshot(sm).is_empty() and Day.pending_loot(sm).is_empty(), "旧档缺少准备状态时无虚构收获")
		_check(Run.begin(sm, Roads.SPAWN).success, "真实探索开始")
		sm.data[Run.KEY].bag = {"slime_gel": 3, "rock_salt": 4}
		var previous: Dictionary = sm.data.duplicate(true)
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		var exit_point: Vector2 = preload("res://data/maze/settlement_exit.gd").FRONT
		var failed_return := Run.finish(sm, true, exit_point)
		_check(failed_return.get("reason") == "save_failed" and sm.data == previous, "返店保存失败回滚快照和库存", failed_return)
		sm._active_save_path = path
		var returned := Run.finish(sm, true, exit_point)
		_check(returned.success, "真实返店入库", returned)
		_check(Day.pending_loot(sm).size() == 1, "本趟快照保存")
		_check(not Run.finish(sm, true, exit_point).success and Day.pending_loot(sm).size() == 1, "重复返店幂等")
		sm.data.unlocked_recipe_ids = ["salt_grilled_rockmane", "mimic_crab_gratin", "scorpion_lotus_fritters", "slime_candy", "brick_snail_sashimi", "lizard_tail_skewer"]
		sm.data.warehouse_stock.rockmane_meat = 5
		sm.data.warehouse_stock.rock_salt = 5
		sm.data[Day.KEY]["protection"] = {"rock_salt": 5}
		_check(Day.validate_menu(sm, {"salt_grilled_rockmane": 5}).success, "旧保护数量不再限制菜单")
		_check(not Day.validate_menu(sm, {"salt_grilled_rockmane": 6}).success, "实际库存仍限制菜单")
		_check(not Day.validate_menu(sm, {"salt_grilled_rockmane": 11}).success, "份数上限")
		_check(not Day.validate_menu(sm, {"salt_grilled_rockmane": 0}).success, "份数下限")
		_check(not Day.validate_menu(sm, {"a": 1, "b": 1, "c": 1, "d": 1, "e": 1, "f": 1}).success, "料理种类上限")
		_check(not Day.validate_requirements({"shared": 3}, {"first": {"shared": 1}, "second": {"shared": 1}}, {"first": 2, "second": 2}).success, "共享食材不能超卖")
		previous = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check(not Day.save_menu(sm, {"salt_grilled_rockmane": 2}).success and sm.data == previous, "菜单保存失败回滚")
		sm._active_save_path = path
		_check(Day.save_menu(sm, {"salt_grilled_rockmane": 2}).success, "菜单快照保存")
		previous = sm.data.duplicate(true)
		_check(Day.save_menu(sm, {"salt_grilled_rockmane": 2}).get("reason") == "already_prepared" and sm.data == previous, "菜单只确认一次")
		_check(sm.warehouse_snapshot().rock_salt == 5, "保存菜单不扣料")
		sm.load_data()
		_check(Day.snapshot(sm).get("menu", {}).get("salt_grilled_rockmane", 0) == 2, "重新读档恢复菜单")
		if DisplayServer.get_name() != "headless":
			await _gui_checks()
	var report := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	if report: report.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("RESTAURANT_DAY_R1 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _gui_checks() -> void:
	for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		await get_tree().process_frame
		if Day.pending_loot(sm).is_empty():
			_check(Run.begin(sm, Roads.SPAWN).success, "再次真实进入探索")
			_check(Run.finish(sm, true, preload("res://data/maze/settlement_exit.gd").FRONT).success, "空包真实返店")
			_check(Day.pending_loot(sm).size() == 1 and Day.pending_loot(sm)[0].is_empty(), "空包快照同样入队")
		scene = RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(1.0).timeout
		var hud := get_tree().get_first_node_in_group("restaurant_hud")
		var player := scene.get_node("Player")
		_check(is_instance_valid(hud), "真实餐厅营业界面")
		if is_instance_valid(hud):
			if hud.exploration_guide.reading:
				_check(not hud.day_loot.visible, "教程对白优先于收获")
				for press in 4:
					if hud.exploration_guide.reading:
						await _send_key(KEY_E)
						await get_tree().create_timer(0.2).timeout
				await get_tree().create_timer(0.5).timeout
			_check(hud.day_loot.visible and player.input_locked, "返店显示收获并锁定输入")
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "loot_%dx%d" % [resolution.x, resolution.y])
			await _send_key(KEY_ENTER)
			_check(not hud.day_loot.visible and not player.input_locked, "收下后恢复输入")
			var sign: Control = hud.find_child("RestaurantDaySign",true,false)
			_check(sign.get_child(0).size == Vector2(44, 40) and sign.get_child(0).position == Vector2(126, 12), "播放按钮独立44×40命中区")
			_check(sign.get_child(1).text == "准备中" and sign.get_child(1).get_theme_font_size("font_size") == 22, "牌子准备文字22号")
			await _click(sign.get_child(0))
			await get_tree().process_frame
			_check(hud.day_menu.visible and player.input_locked, "打开菜单锁定输入")
			var row: Node = hud.day_menu.list.get_node("Recipe_salt_grilled_rockmane")
			_check(hud.day_menu.day_label.text == "第 1 天", "菜单日期与准备状态一致")
			_check(row.get_node("RecipeRow/Price/Coin").texture == preload("res://scripts/ui/components/resource_counter.gd").GOLD and row.get_node("RecipeRow/Price/Amount").text == "20", "售价显示金币图标与数字")
			_check(hud.day_menu.confirm_button.get_theme_stylebox("normal").modulate_color == SproutTheme.selected_style().modulate_color, "开始营业使用选中绿色")
			await _click(row.get_node("RecipeRow/Increase"))
			_check(int(hud.day_menu.draft.get("salt_grilled_rockmane", 0)) == 3, "真实鼠标增加份数")
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "menu_%dx%d" % [resolution.x, resolution.y])
			# 上限与滚动布局使用足量库存；低库存限制由 restaurant_menu_stock 验收。
			for recipe_id in sm.unlocked_recipe_ids():
				for ingredient in hud.day_menu.Recipes.get_recipe(recipe_id).ingredients:
					sm.data.warehouse_stock[ingredient] = 20
			hud.day_menu._rebuild()
			for press in 7:
				row = hud.day_menu.list.get_node("Recipe_salt_grilled_rockmane")
				await _click(row.get_node("RecipeRow/Increase"))
			row = hud.day_menu.list.get_node("Recipe_salt_grilled_rockmane")
			_check(int(hud.day_menu.draft.salt_grilled_rockmane) == 10 and row.get_node("RecipeRow/Increase").disabled, "鼠标加至十份后禁用增加")
			for press in 9:
				row = hud.day_menu.list.get_node("Recipe_salt_grilled_rockmane")
				await _click(row.get_node("RecipeRow/Decrease"))
			row = hud.day_menu.list.get_node("Recipe_salt_grilled_rockmane")
			_check(int(hud.day_menu.draft.salt_grilled_rockmane) == 1 and row.get_node("RecipeRow/Decrease").disabled, "鼠标减至一份后禁用减少")
			_check(hud.day_menu.scroll.get_v_scroll_bar().max_value > hud.day_menu.scroll.get_v_scroll_bar().page, "多料理菜单可滚动")
			hud.day_menu.scroll.scroll_vertical = 9999
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "menu_bottom_%dx%d" % [resolution.x, resolution.y])
			hud.day_menu._add_row("three_ingredient_test", {"name": "三食材布局测试", "ingredients": {"rock_salt": 1, "slime_gel": 1, "rockmane_meat": 1}})
			await get_tree().process_frame
			hud.day_menu.scroll.scroll_vertical = 9999
			await get_tree().process_frame
			var test_row: Control = hud.day_menu.list.get_node("Recipe_three_ingredient_test")
			var ingredients: Node = test_row.get_node("RecipeRow").get_child(3)
			var contained := true
			for item_id in ["rock_salt", "slime_gel", "rockmane_meat"]:
				var holder: Control = ingredients.get_node("Ingredient_" + item_id)
				contained = contained and test_row.get_global_rect().encloses(holder.get_global_rect())
			_check(contained, "三食材图标留在料理行内")
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "menu_three_fixture_%dx%d" % [resolution.x, resolution.y])
			await _send_key(KEY_ESCAPE)
			_check(not hud.day_menu.visible and not player.input_locked, "取消菜单恢复输入")
			_check(int(Day.snapshot(sm).get("menu", {}).get("salt_grilled_rockmane", 0)) == 2, "取消不保存草稿")
			sign.get_child(0).grab_focus()
			await _send_key(KEY_ENTER)
			_check(hud.day_menu.visible and player.input_locked, "键盘打开菜单")
			await _send_key(KEY_ESCAPE)
			_check(not hud.day_menu.visible and not player.input_locked, "键盘关闭后恢复输入")
			var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
			warehouse.open_stock()
			await get_tree().process_frame
			_check(warehouse.find_children("*", "Button", true, false).all(func(button): return button.text != "材料保护"), "仓库移除材料保护入口")
			await RenderingServer.frame_post_draw
			_capture(_arg("--output-dir="), "warehouse_%dx%d" % [resolution.x, resolution.y])
			warehouse.close_modal()

		scene.queue_free()
		await get_tree().process_frame
