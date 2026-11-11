extends "res://tools/tests/maze_capture.gd"
const Gift := preload("res://scripts/restaurant/yufeng_ingredient_gift.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Customer := preload("res://scripts/restaurant/customer_catalog.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _royal_flow()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _royal_flow() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"进入探索")
	sm.record_maze_location("fenshui",Vector2(1300,325))
	sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0})
	var prior: Dictionary = sm.data.duplicate(true)
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Gift.grant(sm).success and sm.data == prior,"赠礼保存失败原子回滚")
	sm._active_save_path = save_path
	maze = load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(1.0).timeout
	var encounter = maze.yf_encounter
	_check(encounter.phase == "gift_reward" and encounter.gift_modal.visible,"实际剧情显示稀有食材赠礼")
	for id in Gift.ITEMS:
		_check(sm.warehouse_snapshot().get(id,0) == 3,"稀有食材入仓："+id)
	var granted: Dictionary = sm.data.duplicate(true)
	_check(Gift.grant(sm).success and sm.data == granted,"赠礼幂等")
	await _capture_image("01_gift")
	await _click(encounter.gift_modal._confirm_button)
	_check(encounter.phase == "farewell","赠礼后直接告别")
	for i in 4:
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	await get_tree().create_timer(0.9).timeout
	_check(sm.yufeng_salia_state() == "done","告别完成")
	maze.queue_free()
	await get_tree().process_frame
	_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"返回餐厅")
	while not Day.pending_loot(sm).is_empty(): Day.acknowledge_loot(sm)
	# 测试样例补充迷宫主食材，不改变正式赠礼内容。
	for id in ["sword_beetle_leg","silverfish_meat","mimic_crab_meat"]: sm.data.warehouse_stock[id] = 3
	sm.data.freezer_unlock_notice_seen = true
	sm.save()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(1.0).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	for i in 20:
		if not hud.exploration_guide.reading: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.1).timeout
	await _click(hud._recipe_entry)
	_check(hud._recipe_book.visible,"实际食谱入口打开")
	for button in hud._recipe_book.dish_targets:
		_check(button.get_theme_constant("icon_max_width") == 88,"食谱料理沿用88像素宽度")
	await _capture_image("02_recipes")
	hud._recipe_book.scroll.scroll_vertical = 150
	await get_tree().process_frame
	await _capture_image("02b_recipes_royal")
	hud._recipe_book.close()
	var warehouse = get_tree().get_first_node_in_group("warehouse_modal")
	warehouse.open_stock()
	for id in Gift.ITEMS:
		var slot = warehouse._slot_by_id[id]
		_check(slot._grid_icon_size == Vector2(40,40) and slot._icon_view.texture != null,"仓库40像素图标："+id)
	await _capture_image("03_warehouse")
	warehouse.close_modal()
	hud.day_menu.open()
	for id in Gift.RECIPES:
		_check(hud.day_menu.list.has_node("Recipe_"+id) and Day.validate_menu(sm,{id:3}).success,"实际库存可备售3份："+id)
	await _capture_image("04_menu")
	hud.day_menu.close()
	# 由隔离夹具提供待接订单，执行实际接单/入座接口；不修改正式来客策略。
	for i in Gift.RECIPES.size():
		var id: String = Gift.RECIPES[i]
		var customers: Dictionary = sm.restaurant_customers()
		customers.serial = 3
		customers.front = {"id":"royal_%d"%i,"customer_id":Customer.CUSTOMERS[i].id,"item_id":id,"item_name":Recipes.get_recipe(id).name,"quantity":1,"phase":"front","seat":-1}
		sm.data.restaurant_customers = customers
		_check(sm.accept_restaurant_customer("royal_%d"%i).success,"实际接新菜订单："+id)
		_check(sm.advance_restaurant_customer("royal_%d"%i,"seating","waiting").success,"入座等餐："+id)
	var invalid: Dictionary = sm.restaurant_customers()
	invalid.seated[0].item_id = "unknown_food"
	_check(not sm._customers_valid(invalid),"未登记料理仍拒绝订单")
	await get_tree().create_timer(0.8).timeout
	var flow = get_tree().get_first_node_in_group("restaurant_customers")
	# 移动测试主角到座位附近，镜头沿正式跟随逻辑移动，保留场景缩放和道具位置。
	hud._player.global_position = Vector2(620,400)
	await get_tree().create_timer(1.4).timeout
	for actor in flow.actors.values():
		var bubble = actor.get_node("OrderBubble")
		_check(bubble.visible and bubble.dish != null,"真实顾客料理气泡")
		_check(get_viewport().get_visible_rect().has_point(bubble.get_global_transform_with_canvas().origin + Vector2(0,-30)),"气泡在实际窗口内")
	await _capture_image("05_bubbles")
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	var audit_ids: Array = Recipes.INGREDIENTS.keys() + Recipes.RECIPES.keys()
	for item in audit_ids:
		var probe: TextureRect = tracker._make_item_icon(str(item))
		var pixels := probe.texture.get_image()
		var bounds := Rect2i()
		for y in pixels.get_height():
			for x in pixels.get_width():
				if pixels.get_pixel(x,y).a >= 0.1:
					var pixel := Rect2i(x,y,1,1)
					bounds = pixel if not bounds.has_area() else bounds.merge(pixel)
		var visible_side := float(maxi(bounds.size.x,bounds.size.y)) / float(maxi(pixels.get_width(),pixels.get_height())) * 28.0
		_check(visible_side >= 27.0,"任务可见主体占满原28像素格："+str(item),{"visible_side":visible_side})
		probe.free()
	await _click(tracker._task_button)
	await get_tree().create_timer(0.4).timeout
	for id in Gift.RECIPES:
		var icons = tracker.find_children(id+"Icon","TextureRect",true,false)
		_check(not icons.is_empty(),"任务列表显示新料理："+id)
		for icon in icons: _check(icon.custom_minimum_size == Vector2(28,28),"任务图标沿用28像素")
	await _capture_image("06_tasks")
	tracker.collapse_details()
	await get_tree().create_timer(0.3).timeout
	for i in Gift.RECIPES.size():
		var id: String = Gift.RECIPES[i]
		var required: Dictionary = Recipes.get_recipe(id).ingredients
		_check(sm.take_warehouse_items(required).success,"从仓库领取配方原料："+id)
		if i == 0:
			var cooking = get_tree().get_first_node_in_group("cooking_modal")
			cooking.open_for_order(id)
			await _capture_image("07_cooking")
			cooking.close_modal()
		_check(sm.start_cooking(id).success,"真实扣料制作："+id)
		_check(sm.finish_first_order_cooking(3).success,"制作完成入成品："+id)
		var result: Dictionary = sm.deliver_restaurant_customer("royal_%d"%i)
		_check(result.success and result.get("gold_awarded",0) == [35,40,45][i],"交付按35/40/45金币结算："+id)
	sm.load_data()
	_check(sm.data.get(Gift.KEY,false) and Gift.RECIPES.all(func(id): return id in sm.unlocked_recipe_ids()),"重载保留赠礼和食谱")
	scene.queue_free()
	await get_tree().process_frame
