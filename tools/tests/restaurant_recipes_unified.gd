extends "res://tools/tests/maze_capture.gd"
const Gift := preload("res://scripts/restaurant/yufeng_ingredient_gift.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const PRICES := {"slime_candy":10,"cool_slime_jelly":15,"salt_grilled_rockmane":20,"brick_snail_sashimi":20,"salt_crust_silverfish":25,"frog_soup":25,"wind_frog_bread":25,"mimic_crab_gratin":30,"scorpion_lotus_fritters":30,"thunder_eel_roll":35,"lizard_tail_skewer":40}

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		for id in PRICES:
			_check(Recipes.order_gold(id) == PRICES[id] and not Recipes.get_recipe(id).has("exploration_category"), "统一料理与价格：" + id)
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			_completed()
			sm.cancel_maze_entry()
			sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
			_check(Run.begin(sm,Roads.SPAWN).success, "真实开始探索")
			sm.record_maze_location("fenshui",Vector2(1300,325))
			sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0})
			var prior: Dictionary = sm.data.duplicate(true)
			var path: String = sm._active_save_path
			sm._active_save_path = ""
			_check(not Gift.grant(sm).success and sm.data == prior, "赠礼保存失败库存解锁阶段全部回滚")
			sm._active_save_path = path
			var stock: Dictionary = sm.warehouse_snapshot()
			maze = load("res://scenes/maze_fenshui.tscn").instantiate()
			get_tree().root.add_child(maze)
			get_tree().current_scene = maze
			await get_tree().create_timer(0.7).timeout
			maze.capture_flow.window_focused = true
			var encounter = maze.yf_encounter
			_check(encounter.phase == "gift_reward" and encounter.gift_modal.visible, "真实御风食材赠礼弹窗")
			for id in Gift.ITEMS:
				_check(sm.warehouse_snapshot().get(id,0) == stock.get(id,0) + 2, "赠礼直接入仓：" + id)
			var granted: Dictionary = sm.data.duplicate(true)
			_check(Gift.grant(sm).success and sm.data == granted, "重复领取不增加物品")
			_check(maze.find_children("BentoEntry", "", true, false).is_empty(), "迷宫无便当入口")
			await _capture_image("ingredient_gift")
			await _click(encounter.gift_modal._confirm_button)
			_check(encounter.phase == "farewell", "收下食材直接进入告别")
			for i in 4:
				await _send_key(KEY_E)
				await get_tree().create_timer(0.15).timeout
			await get_tree().create_timer(0.9).timeout
			_check(sm.yufeng_salia_state() == "done" and not maze.player.input_locked, "告别结束恢复输入，无便当解锁阶段")
			maze.queue_free()
			await get_tree().process_frame
			sm.load_data()
			_check(sm.data.get(Gift.KEY,false) and not Gift.grant(sm).get("created",true), "重载不重复赠礼")
			var returned := Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE)
			_check(returned.success, "真实返回餐厅", returned)
			while not Day.pending_loot(sm).is_empty(): Day.acknowledge_loot(sm)
			sm.data.unlocked_recipe_ids = Recipes.recipe_ids()
			scene = RESTAURANT.instantiate()
			get_tree().root.add_child(scene)
			get_tree().current_scene = scene
			await get_tree().create_timer(0.7).timeout
			var hud = get_tree().get_first_node_in_group("restaurant_hud")
			for i in 16:
				if not hud.exploration_guide.reading: break
				await _send_key(KEY_E)
				await get_tree().create_timer(0.15).timeout
			_check(not hud.exploration_guide.reading, "完成保留的冰柜教学")
			_check(scene.find_children("BentoEntry", "", true, false).is_empty(), "餐厅无便当入口")
			hud.day_menu.open()
			for id in Gift.RECIPES:
				_check(hud.day_menu.list.has_node("Recipe_"+id) and Day.validate_menu(sm,{id:2}).success, "赠礼能上两份菜单："+id)
			await _capture_image("gift_menu")
			hud.day_menu.close()
			await _click(hud._recipe_entry)
			_check(hud._recipe_book.visible, "鼠标实际打开食谱")
			_check(hud._recipe_book.rows.size() == 11, "食谱展示全部十一道已解锁料理")
			await get_tree().process_frame
			hud._recipe_book.scroll.scroll_vertical = 380
			await get_tree().process_frame
			await _capture_image("unified_recipe_book")
			hud._recipe_book.close()
			scene.queue_free()
			await get_tree().process_frame
	var report := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
