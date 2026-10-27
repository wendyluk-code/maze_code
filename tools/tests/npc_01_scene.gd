extends "res://tools/tests/day1_customers_scene.gd"

const EXPECTED := ["male_01", "female_05", "male_08"]

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/npc_01/" + label + "_%dx%d.png" % [get_viewport().size.x, get_viewport().size.y])

func assert_image(id: String, index: int, label: String) -> void:
	var actor: Sprite2D = flow.actors[id]
	check(actor.texture.atlas.resource_path.ends_with(EXPECTED[index] + "_actions.png"), label + "使用指定完整新人物")
	check(actor.texture.atlas.get_image().detect_alpha() != Image.ALPHA_NONE, label + "动作透明背景")

func reopen() -> void:
	if is_instance_valid(restaurant):
		restaurant.queue_free()
		await pause(0.15)
	sm.load_data()
	restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	await pause(0.5)
	flow = get_tree().get_first_node_in_group("restaurant_customers")
	player = restaurant.get_node("Player")

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	await reopen()
	check(flow.actors.size() == 1 and sm.restaurant_customers().queue.is_empty(), "当前单客候场规则不变")
	for index in 3:
		var id := "restaurant_%d" % (index + 1)
		check(sm.restaurant_customers().front.id == id, "前三位依次到店")
		assert_image(id, index, "候客")
		player.global_position = stand(restaurant.get_node("InteractPoints/Register"))
		player.last_valid = player.global_position
		await pause(0.3)
		await key(KEY_E)
		await pause(0.25)
		check(flow._dialog.visible and player.input_locked, "真实E接单对白锁定输入")
		check(flow._dialog.speaker_name.text == "冒险者", "接单姓名冒险者")
		check(flow._dialog.portrait_texture.texture.resource_path.ends_with(EXPECTED[index] + "_portrait.png"), "接单指定头像")
		check(flow._dialog._lines[0] == "请给我一份%s。" % sm.restaurant_customers().front.item_name, "点单原文与料理不变")
		await shot("order_%d" % index)
		for press in 2:
			if flow._dialog.visible: await key(KEY_E)
		await pause(0.85)
		check(sm.restaurant_customer_order(id).phase == "waiting", "淡入淡出后入座")
		assert_image(id, index, "入座")
		check(not player.input_locked, "接单后输入恢复")
	await shot("three_seated")
	await reopen()
	for index in 3: assert_image("restaurant_%d" % (index + 1), index, "读档三席")
	await calibration()
	player.global_position = stand(restaurant.get_node("InteractPoints/Register"))
	player.last_valid = player.global_position
	await pause(0.5)
	await shot("restored_seated")
	# 显式调用旧模板，证明旧角色配置和动作仍可复用；不参与生产存档。
	var legacy_names := ["萨莉亚", "叮当", "御风"]
	for index in 3:
		var config: Dictionary = flow.Catalog.LEGACY_CUSTOMERS[index]
		var old := Sprite2D.new()
		flow.add_child(old)
		flow._frame(old, config.id, 2, 0, true)
		check(flow.Catalog.legacy_customer(config.id).name == legacy_names[index] and old.texture.atlas.resource_path == "res://assets/characters/customers/%s.png" % config.id, "旧配置动作可调用")
		old.queue_free()
	var total_gold: int = sm.gold_balance()
	var total_rep: int = sm.reputation()
	for index in 3:
		var id := "restaurant_%d" % (index + 1)
		var order: Dictionary = sm.restaurant_customer_order(id)
		var recipe: Dictionary = sm.RecipeCatalog.get_recipe(order.item_id)
		for ingredient in recipe.ingredients: sm.data.warehouse_stock[ingredient] = 1
		check(sm.take_warehouse_items(recipe.ingredients).success, "真实仓库取料")
		check(sm.start_cooking(order.item_id).success and sm.finish_first_order_cooking(3).success, "真实烹饪事务")
		player.global_position = stand(restaurant.get_node("InteractPoints/BarCounter"))
		player.last_valid = player.global_position
		await pause(0.2)
		await key(KEY_E)
		check(sm.restaurant_customer_order(id).phase == "eating", "真实E上菜直接交付")
		assert_image(id, index, "进食")
		await shot("eating_%d" % index)
		if index == 0:
			await reopen()
			assert_image(id, index, "进食读档")
			player.global_position = stand(restaurant.get_node("InteractPoints/BarCounter"))
			player.last_valid = player.global_position
			await pause(0.3)
		await pause(2.0)
		check(flow._dialog.visible and flow._dialog.speaker_name.text == "冒险者", "餐后姓名冒险者")
		check(flow._dialog.portrait_texture.texture.resource_path.ends_with(EXPECTED[index] + "_portrait.png"), "餐后指定头像")
		await shot("farewell_%d" % index)
		for press in 2:
			if flow._dialog.visible: await key(KEY_E)
		await pause(0.12)
		assert_image(id, index, "离场")
		await shot("leaving_%d" % index)
		await pause(0.9)
		check(not flow.actors.has(id) and not player.input_locked, "离场完成并恢复输入")
	check(sm.gold_balance() == total_gold + 70 and sm.reputation() == total_rep + 300, "原三单金币70及三星声望300不变")
	var rewards := Vector2(sm.gold_balance(), sm.reputation())
	sm.load_data()
	check(Vector2(sm.gold_balance(), sm.reputation()) == rewards and not sm.deliver_restaurant_customer("restaurant_1").success, "读档不重复结算")
	check(sm.restaurant_customers().front.is_empty(), "三位完成后不循环生成第四客")
	await shot("fourth_customer")
	print("NPC_01_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
