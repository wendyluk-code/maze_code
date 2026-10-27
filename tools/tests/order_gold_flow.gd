extends "res://tools/tests/hud_currency_flow.gd"
const HomePage := preload("res://scripts/ui/adventurer_home.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		if failures: break
		DisplayServer.window_set_size(resolution)
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		await get_tree().process_frame
		await _first_gold()
		await _other_pages()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name()}, "\t"))
	get_tree().quit(1 if failures else 0)

func _first_gold() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://save.json"
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success, "正式接单取料烹饪建立待交付状态")
	await _open_scene()
	await _settle()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.reputation_counter.visible and not hud.gold_counter.visible, "交付前声望金币同时隐藏")
	var player = scene.get_node("Player")
	player.global_position = _stand(scene.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.global_position
	await get_tree().physics_frame
	_check(await _wait_until(func(): return tm.steps[tm.idx].get("type", "") == "interact" and tm.current_stage == 6, 120), "真实吧台交单步骤就绪")
	var path: String = sm._active_save_path
	var before: Dictionary = sm.data.duplicate(true)
	var disk := FileAccess.get_file_as_bytes(path)
	sm._active_save_path = ""
	await _send_key(KEY_E)
	await _settle()
	_check(sm.data == before and FileAccess.get_file_as_bytes(path) == disk and not hud.gold_counter.visible and not hud.reputation_counter.visible, "真实E保存失败无奖励且两计数器不提前显示")
	sm._active_save_path = path
	await _send_key(KEY_E)
	await _settle()
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	_check(sm.has_first_order_settlement() and sm.gold_balance() == 5 and hud.gold_counter.is_visible_in_tree() and hud.reputation_counter.is_visible_in_tree() and guide.dialog.visible, "真实E首次交付对白期间金币声望同步显示")
	_counter(hud.gold_counter, 5, "gold.png")
	_counter(hud.reputation_counter, 60, "reputation.png")
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	_group(tracker, [hud.reputation_counter, hud.gold_counter])
	_check(hud.reputation_counter.get_global_rect().end.x < hud.gold_counter.get_global_rect().position.x, "声望金币无重叠")
	await _shot("first_delivery_both_counters")
	before = sm.data.duplicate(true)
	_check(not sm.deliver_first_order().success and sm.data == before, "首单对白期间重复交付不发奖")
	await _close_scene()
	sm.load_data()
	await _open_scene()
	await _settle()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.gold_counter.is_visible_in_tree() and hud.gold_counter.value_label.text == "5" and hud.reputation_counter.is_visible_in_tree(), "重进餐厅恢复金币5及声望")
	await _shot("first_delivery_reloaded")
	await _close_scene()

func _other_pages() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]:
		_check(sm.advance_chapter_1_outro(checkpoint).success, "完成首单后出发准备")
	await _open_scene()
	await _settle()
	await _home_check(5, true)
	HomePage.open_page(get_tree())
	await get_tree().process_frame
	var page = get_tree().get_first_node_in_group("adventurer_home")
	await _click(page.tabs[1])
	_check(page.gold_counter.value_label.text == "5" and page.summon_panel.single_button.disabled and page.summon_panel.ten_button.disabled, "召唤页读取交单余额5且不足价格禁用")
	await _shot("summon_order_balance")
	await _send_key(KEY_ESCAPE)
	await _settle()
	_check(not is_instance_valid(page) and scene.can_process(), "退出召唤恢复餐厅输入")
	await _enter_from_restaurant()
	_check(maze.gold_counter.is_visible_in_tree() and maze.gold_counter.value_label.text == "5", "真实转场迷宫显示交单余额5")
	await _shot("maze_order_balance")
	await _close_scene()
	maze = null
	await _followup_delivery()

func _followup_delivery() -> void:
	# 经营状态与奖励必须仍通过正式接单、烹饪、交付；只补充隔离测试食材。
	_check(sm.record_maze_location("restaurant", Roads.SPAWN).success, "后续订单返回餐厅位置")
	_check(sm.register_customer_order("gold-ui-followup", sm.FIRST_ORDER_ITEM_ID).success, "登记正式后续订单")
	await _open_scene()
	await _settle()
	var player = scene.get_node("Player")
	player.position = _stand(scene.get_node("InteractPoints/Register"))
	player.last_valid = player.position
	await get_tree().physics_frame
	await _send_key(KEY_E)
	_check(sm.current_order().id == "gold-ui-followup" and sm.has_active_order(), "真实E前台接受后续订单")
	sm.data.inventory.rockmane_meat = 1
	sm.data.inventory.rock_salt = 1
	_check(sm.start_cooking(sm.FIRST_ORDER_ITEM_ID).success and sm.finish_first_order_cooking(3).success, "后续订单真实烹饪3星")
	player.position = _stand(scene.get_node("InteractPoints/BarCounter"))
	player.last_valid = player.position
	await get_tree().physics_frame
	await _send_key(KEY_E)
	await _settle()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(sm.gold_balance() == 10 and hud.gold_counter.value_label.text == "10" and hud.toast_label.text == "上菜完成，声望 +100，金币 +5", "真实E后续交付同步奖励、HUD和反馈")
	await _shot("followup_delivery_gold10")
	await _send_key(KEY_E)
	await _settle()
	_check(sm.gold_balance() == 10, "真实E重复后续交付不再奖励")
	await _close_scene()
