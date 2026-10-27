extends "res://tools/tests/chapter_ending_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_data_cases()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _reputation_reveal()
			await _interactions()
		await _reputation_outro_layers()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	print("POST_CHAPTER ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _completed() -> void:
	_seed()
	for checkpoint in ["party","home","maze","title"]:
		_check(sm.advance_chapter_1_outro(checkpoint).success,"完章前置："+checkpoint)

func _data_cases() -> void:
	for quality in [1,2,3]:
		sm.data = sm._defaults()
		sm._active_save_path = "user://post-chapter.json"
		_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success,"首单接单取货")
		_check(sm.start_first_order_cooking().success and sm.finish_first_order_cooking(quality).success,"制作实际星级")
		sm.data.reputation = 123
		var before: Dictionary = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check(not sm.deliver_first_order().success and sm.data == before,"上菜写盘失败完整回滚")
		sm._active_save_path = "user://post-chapter.json"
		var reward: int = {1:60,2:80,3:100}[quality]
		_check(sm.deliver_first_order().success and sm.reputation() == 123 + reward,"实际星级奖励累计：%d" % quality)
		_check(not sm.deliver_first_order().success and sm.reputation() == 123 + reward,"重复上菜不重奖")
		sm.load_data()
		_check(sm.has_first_order_settlement() and sm.reputation() == 123 + reward,"JSON重载保留星级凭证")
		sm.data.first_order_settlement.reputation_awarded = {1:10,2:12,3:15}[quality]
		sm.data.reputation = {1:10,2:12,3:15}[quality]
		_check(sm.save(),"保存旧星级凭证")
		sm.load_data()
		_check(sm.has_first_order_settlement() and sm.reputation() == int({1:10,2:12,3:15}[quality]),"旧星级凭证不补发：%d" % quality)
	_completed()
	sm.data.erase("warehouse_stock")
	sm.data.first_order_settlement.reputation_awarded = 10
	sm.data.reputation = 10
	_check(sm.save(),"写入历史旧奖励/无仓库字段样例")
	sm.load_data()
	_check(sm.warehouse_snapshot().rockmane_meat == 0 and sm.warehouse_snapshot().rock_salt == 0,"已取货旧档不凭空补货")
	_check(sm.has_first_order_settlement() and sm.reputation() == 10 and sm.is_chapter_1_complete(),"旧奖励凭证不失效不补奖")
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.register_customer_order("fail",sm.FIRST_ORDER_ITEM_ID).success and sm.data == before,"顾客登记失败回滚")
	sm._active_save_path = "user://post-chapter.json"
	sm.data.waiting_customer_orders = [null,{"id":7},{"id":"bad","item_id":sm.FIRST_ORDER_ITEM_ID}]
	_check(sm.waiting_customer_orders().is_empty(),"损坏候单记录不接受")
	sm.data.warehouse_stock = {"rockmane_meat":3,"rock_salt":4}
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.take_warehouse_items({"rockmane_meat":2}).success and sm.data == before,"取货写盘失败完整回滚")
	sm._active_save_path = "user://post-chapter.json"
	_check(not sm.take_warehouse_items({"rockmane_meat":4}).success,"超库存取货拒绝")
	_check(sm.take_warehouse_items({"rockmane_meat":2,"rock_salt":2}).success,"多种多份转移成功")
	sm.load_data()
	_check(sm.warehouse_snapshot().rockmane_meat == 1 and sm.inventory_quantity("rockmane_meat") == 2 and sm.is_chapter_1_complete(),"转移持久化且完章不倒退")
	_check(sm.register_customer_order("follow-1",sm.FIRST_ORDER_ITEM_ID).success and sm.accept_waiting_customer_order().success,"真实候单登记与接受")
	_check(not sm.register_customer_order("follow-1",sm.FIRST_ORDER_ITEM_ID).success,"订单ID不重复登记")
	_check(sm.quest_snapshot().active.any(func(q): return q.id == "customer_order:follow-1" and q.unread),"后续订单任务与红点")
	_check(sm.start_cooking(sm.FIRST_ORDER_ITEM_ID).success,"后续订单烹饪可开始")
	sm.load_data()
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1 and sm.cooking_state().quality == 1,"中断烹饪恢复一份一星成品")
	_check(sm.first_order_progress().next_step == "chapter_wrap_up", "后续烹饪恢复不覆盖首章完成进度")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.deliver_customer_order().success and sm.data == before,"后续交付写盘失败全量回滚")
	sm._active_save_path = "user://post-chapter.json"
	_check(sm.deliver_customer_order().success and sm.reputation() == 70,"后续上菜累计声望")
	_check(not sm.deliver_customer_order().success and sm.reputation() == 70,"后续重复上菜不重奖")
	sm.load_data()
	_check(sm.is_chapter_1_complete() and sm.chapter_1_outro_state() == "done", "新订单读档不重播第一章")
	_check(sm.quest_snapshot().archived.any(func(q): return q.id == "customer_order:follow-1"),"后续任务只本地归档")
	_check(sm.register_customer_order("follow-2",sm.FIRST_ORDER_ITEM_ID).success,"第二位顾客登记")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.accept_waiting_customer_order().success and sm.data == before,"后续接单失败不丢候单")
	sm._active_save_path = "user://post-chapter.json"
	_check(sm.accept_waiting_customer_order().success,"接单失败可重试")

func _use(node_path: String) -> void:
	var target: Node2D = scene.get_node(node_path)
	var player: Node2D = scene.get_node("Player")
	player.global_position = _stand(target)
	await get_tree().physics_frame
	_check(player.nearest_interactable() == target, "最近交互目标："+node_path)
	await _send_key(KEY_E)
	await get_tree().process_frame

func _reputation_reveal() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://reputation-reveal.json"
	_check(sm.save(), "声望展示初始化隔离存档")
	await _open_scene()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.reputation_label.visible, "第一章苏醒时隐藏声望")
	await _shot("reputation_hidden_opening")
	sm.data.reputation = 123
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not hud.reputation_label.visible, "未给铁山上菜即使有声望也不展示")
	await _close_scene()
	sm.data.reputation = 0
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success, "准备真实首单待上菜")
	await _open_scene()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.reputation_label.visible, "料理完成未上菜仍隐藏声望")
	sm._active_save_path = ""
	await _use("InteractPoints/BarCounter")
	_check(not hud.reputation_label.visible and not sm.has_first_order_settlement(), "上菜保存失败不会提前显示声望")
	sm._active_save_path = "user://reputation-reveal.json"
	await _use("InteractPoints/BarCounter")
	await get_tree().process_frame
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	_check(sm.has_first_order_settlement() and hud.reputation_label.is_visible_in_tree() and hud.reputation_label.text == "声望：60" and guide.dialog.visible and guide.toast.is_visible_in_tree(), "首次上菜结算Toast与对白期间同步显示声望")
	_check_shared_hud("首次上菜对白")
	await _verify_mask_dimming(guide.dim, "上菜对白")
	var notice = guide.toast_panel.get_node("Content/NoticeIcon")
	_check(not notice.get_global_rect().intersects(guide.toast.get_global_rect()) and notice.get_global_rect().end.x + 10 <= guide.toast.get_global_rect().position.x, "上菜长文案与提示图标独立占位且留有间隔")
	await _shot("reputation_first_served")
	var tracker = scene.get_node("UIOverlay/OrderTracking")
	tracker.collapse_details()
	# 从未写完的当前对白开始，点击任务入口所在位置应仅补全对白。
	guide.dialog._shown = 0.0
	await _click(tracker._task_button)
	_check(not tracker._expanded and guide.dialog.visible and guide.dialog._shown >= str(guide.dialog._lines[guide.dialog._line_idx]).length(), "对白蒙层拦截任务入口点击且保留点击继续")
	await _close_scene()
	sm.load_data()
	await _open_scene()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.reputation_label.is_visible_in_tree() and hud.reputation_label.text == "声望：60", "上菜后读档恢复对白时同步显示声望")
	_check_shared_hud("读档恢复上菜对白")
	await _close_scene()

func _interactions() -> void:
	_completed()
	await _open_scene()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var player = scene.get_node("Player")
	var warehouse = scene.get_node("UIOverlay/WarehouseModal")
	var tracker = scene.get_node("UIOverlay/OrderTracking")
	_check(hud.reputation_label.get_parent() == tracker, "声望实际归属任务层并继承显隐")
	_check_shared_hud("常规任务栏")
	tracker.modulate.a = 0.35
	_check_shared_hud("任务栏淡入淡出中间态")
	tracker.modulate.a = 0.0
	_check_shared_hud("任务栏透明隐藏", false)
	tracker.modulate.a = 1.0
	tracker.hide()
	_check_shared_hud("任务栏直接隐藏", false)
	tracker.show()
	_check_shared_hud("任务栏恢复")
	_check(not tm.active,"完章后不重启教学")
	_check(hud.reputation_label.visible and hud.reputation_label.text == "声望：60","HUD显示实际累计值")
	var entry: Rect2 = tracker.entry_rect()
	var reputation: Rect2 = hud.reputation_label.get_global_rect()
	_check(entry.position.x < 30 and reputation.position.x > entry.end.x
		and reputation.position.y < 50 and not reputation.intersects(entry), "任务入口左上角，声望在右侧且不重叠")
	await _use("InteractPoints/Register")
	_check(hud.toast_label.visible and hud.toast_label.text == "当前暂无订单，请等待顾客上门","无顾客E点单反馈")
	_shot("no_order")
	await _use("InteractPoints/BarCounter")
	_check(hud.toast_label.text == "当前暂无用餐需求，请先接单","无需求E上菜反馈")
	await _use("InteractPoints/Store")
	_check(warehouse.visible and warehouse._message.text == "没有任何食物" and player.input_locked,"E打开空仓库且锁住移动")
	_check_shared_hud("仓库弹窗")
	await _verify_mask_dimming(warehouse._overlay, "仓库")
	await _click(tracker._task_button)
	_check(warehouse.visible and not tracker._expanded, "仓库蒙层拦截背景任务入口点击")
	_shot("empty_warehouse")
	await _click(warehouse._cancel_button)
	_check(not warehouse.visible and not player.input_locked,"空仓库确认释放输入")
	_check(hud.reputation_label.is_visible_in_tree(), "关闭仓库恢复声望")
	sm.data.warehouse_stock = {"rockmane_meat":4,"rock_salt":3}
	await _use("InteractPoints/Store")
	_check(warehouse._meat_slot._quantity == 4 and warehouse._salt_slot._quantity == 3,"真实仓库数量")
	_check_shared_hud("有货仓库弹窗")
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._meat_slot._icon_button)
	await _click(warehouse._salt_slot._icon_button)
	_shot("warehouse_selection")
	await _click(warehouse._claim_button)
	_check(sm.inventory_quantity("rockmane_meat") == 2 and sm.inventory_quantity("rock_salt") == 1 and sm.warehouse_snapshot().rockmane_meat == 2,"鼠标多种多份取货")
	_check(not player.input_locked,"取货完成释放输入")
	var card_panel = get_tree().get_first_node_in_group("departure_panel")
	card_panel.open_task_cards()
	_check(card_panel._cards_open(),"章后有携带物品仍可查看卡组")
	await get_tree().process_frame
	_check_shared_hud("卡组弹窗")
	card_panel._close_cards()
	await get_tree().process_frame
	_check(hud.reputation_label.is_visible_in_tree(), "关闭卡组恢复声望")
	for display in ["冰柜","小餐车"]:
		var target = get_tree().get_nodes_in_group("interactable").filter(func(n): return str(n.get("display_name")) == display)[0]
		var threshold: int = 2000 if display == "冰柜" else 5000
		sm.data.reputation = threshold - 1
		await _use(str(scene.get_path_to(target)))
		_check("暂未解锁" in hud.toast_label.text,"待设计功能门槛前仍锁定："+display)
		sm.data.reputation = threshold
		await _use(str(scene.get_path_to(target)))
		_check("暂未解锁" in hud.toast_label.text,"待设计功能达到旧门槛仍锁定："+display)
	sm.data.reputation = 60
	for dest in ["InteractPoints/AdventurerHomeDoor","DepartureEntrance"]:
		await _use(dest)
		if dest == "DepartureEntrance":
			_check(hud.confirmation.visible,"一次E先确认前往迷宫")
			await _send_key(KEY_E)
			_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")) and get_tree().get_first_node_in_group("scene_transition") == null, 240),"确认后进入正式迷宫并完成转场")
			var maze = get_tree().get_first_node_in_group("maze_entry")
			_check(maze != null and maze._entry_ready, "地图就绪后保存第二章开始")
			if maze != null:
				maze.return_to_restaurant()
				_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")) and get_tree().get_first_node_in_group("scene_transition") == null, 240), "迷宫返回餐厅并完成转场")
				scene = get_tree().current_scene
				hud = get_tree().get_first_node_in_group("restaurant_hud")
				player = scene.get_node("Player")
				warehouse = scene.get_node("UIOverlay/WarehouseModal")
				tracker = scene.get_node("UIOverlay/OrderTracking")
				await get_tree().process_frame
			var departure = get_tree().get_first_node_in_group("departure_panel")
			departure.open_map()
			_check(departure._open and player.input_locked,"独立地图预览打开且锁定")
			await get_tree().create_timer(0.5).timeout
			_check_shared_hud("地图展开", false)
			_check(departure._continue_prompt.is_visible_in_tree() and departure._continue_prompt.modulate.a == 1.0, "地图展开后显示继续提示")
			_check(departure._continue_prompt.get_node("ContinueKeyIcon").texture.atlas.resource_path == "res://assets/ui/continue_key_e.png", "地图使用指定E图标")
			_check(departure._map_panel.get_rect().end.y < departure._continue_prompt.position.y, "地图与底部提示不重叠")
			await _shot("map_without_reputation")
			await _send_key(KEY_E)
			_check(not departure._open, "地图提示对应E实际关闭")
			await get_tree().process_frame
			_check_shared_hud("关闭地图恢复任务栏")
		else:
			var home = get_tree().get_first_node_in_group("adventurer_home")
			_check(is_instance_valid(home) and not hud.confirmation.visible, "一次E直接打开冒险者之家正式页面")
			if is_instance_valid(home):
				await _click(home.back_button)
				await get_tree().process_frame
			_check(get_tree().get_nodes_in_group("adventurer_home").is_empty() and player.can_process() and not player.input_locked, "返回餐厅恢复原场景输入")
	_check(sm.register_customer_order("gui"+suffix,sm.FIRST_ORDER_ITEM_ID).success,"登记可接待顾客")
	await _use("InteractPoints/Register")
	_check(sm.has_active_order(),"真实E接受新订单")
	await _click(tracker._task_button)
	_check(tracker._order_main.visible and not sm.has_unread_quests(),"进行中订单可查看并清红点")
	await get_tree().create_timer(0.5).timeout
	_shot("active_order")
	await _use("InteractPoints/Cauldron")
	var cooking = scene.get_node("HUD/CookingModal")
	_check(cooking.visible and player.input_locked,"章后E开锅")
	_check_shared_hud("料理台弹窗")
	await _shot("cooking_shared_hud")
	await _click(cooking._start_button)
	_check(sm.cooking_state().status == "active","鼠标开始QTE扣料")
	await _click(cooking._finish_button)
	_check(sm.inventory_quantity(sm.FIRST_ORDER_ITEM_ID) == 1,"章后QTE生成料理")
	_check_shared_hud("料理评分弹窗")
	await _shot("cooking_result_shared_hud")
	await get_tree().create_timer(1.4).timeout
	await _send_key(KEY_E)
	_check(not player.input_locked,"料理结果确认恢复移动")
	_check(hud.reputation_label.is_visible_in_tree(), "确认料理结果恢复声望")
	var stars: int = sm.cooked_quality()
	await _use("InteractPoints/BarCounter")
	_check(sm.reputation() == 60 + int({1:60,2:80,3:100}[stars]),"真实E交付后累计")
	await get_tree().process_frame
	_check(hud.reputation_label.text == "声望：%d" % sm.reputation(),"HUD立即同步交付奖励")
	_shot("reputation_after_delivery")
	await _close_scene()

func _reputation_outro_layers() -> void:
	_seed()
	await _open_scene()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and not tm._chapter_outro._busy, 180), "入队蒙层就绪")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check_shared_hud("入队蒙层", false)
	var party = tm._chapter_outro._party
	_check(party._join_message.get_theme_font_size("font_size") > party._prompt.get_child(0).get_theme_font_size("font_size"), "入队标题与操作提示有字号层次")
	_check(party._join_message.get_rect().end.y < party._prompt.position.y, "入队标题与继续提示留出间距")
	_check(party._prompt.get_node("ContinueKeyIcon").texture.atlas.resource_path == "res://assets/ui/continue_key_e.png", "入队使用指定E图标")
	await _shot("party_without_reputation")
	await _click_screen(Vector2(20, 20))
	_check(await _wait_until(func(): return tm._chapter_outro.phase == "home" and not tm._chapter_outro._busy, 180), "入口教学就绪")
	_check_shared_hud("入口特写", false)
	await _dialog_finish()
	_check(await _wait_until(func(): return tm._chapter_outro.phase == "maze" and not tm._chapter_outro._busy, 180), "迷宫教学就绪")
	await _dialog_finish()
	_check(await _wait_until(func(): return tm._chapter_outro.phase == "title" and tm._chapter_outro._ending.visible, 180), "章节标题蒙层就绪")
	await get_tree().create_timer(1.5).timeout
	_check_shared_hud("章节标题蒙层", false)
	await _shot("chapter_end_without_reputation")
	await _click_screen(Vector2(20, 20))
	_check(await _wait_until(func(): return not tm.active, 180), "空白点击退出章节蒙层")
	await get_tree().process_frame
	_check_shared_hud("章节蒙层退出恢复任务栏")
	await _close_scene()

func _click_screen(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame

# visible 只代表节点开关；地图/片尾使用父节点透明度，必须一起验收实际绘制状态。
func _effective_alpha(item: CanvasItem) -> float:
	if not item.is_visible_in_tree():
		return 0.0
	var alpha := item.self_modulate.a
	var cursor: Node = item
	while cursor is CanvasItem:
		alpha *= (cursor as CanvasItem).modulate.a
		cursor = cursor.get_parent()
	return alpha

func _check_shared_hud(context: String, expected_visible := true) -> void:
	_check_active_masks_above_hud(context)
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	var reputation: Label = hud.reputation_label
	var task: Button = tracker._task_button
	var task_alpha := _effective_alpha(task)
	var reputation_alpha := _effective_alpha(reputation)
	_check(reputation.get_parent() == task.get_parent()
		and reputation.get_canvas_layer_node() == task.get_canvas_layer_node()
		and reputation.z_index == task.z_index
		and reputation.z_as_relative == task.z_as_relative
		and not reputation.top_level and not task.top_level,
		context + "：任务入口与声望共用父级与绘制层级")
	_check(is_equal_approx(task_alpha, reputation_alpha)
		and (task_alpha > 0.0) == expected_visible,
		context + "：任务入口与声望同时显隐且透明度相同",
		{"task_alpha": task_alpha, "reputation_alpha": reputation_alpha})

func _canvas_layer_of(item: CanvasItem) -> int:
	var layer := item.get_canvas_layer_node()
	return layer.layer if is_instance_valid(layer) else 0

func _effective_z(item: CanvasItem) -> int:
	var result := item.z_index
	var cursor: CanvasItem = item
	while cursor.z_as_relative and cursor.get_parent() is CanvasItem:
		cursor = cursor.get_parent() as CanvasItem
		result += cursor.z_index
	return result

func _check_active_masks_above_hud(context: String) -> void:
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	for node in scene.find_children("*", "ColorRect", true, false):
		var mask := node as ColorRect
		if _effective_alpha(mask) <= 0.0 or mask.color.a <= 0.0:
			continue
		if not mask.get_global_rect().encloses(tracker._task_button.get_global_rect()) or not mask.get_global_rect().encloses(hud.reputation_label.get_global_rect()):
			continue
		var mask_layer := _canvas_layer_of(mask)
		var task_layer := _canvas_layer_of(tracker)
		_check(mask_layer > task_layer or (mask_layer == task_layer and _effective_z(mask) > _effective_z(tracker)),
			context + "：全屏蒙层在任务/声望上方 " + str(mask.get_path()),
			{"mask_layer":mask_layer,"task_layer":task_layer,"mask_z":_effective_z(mask),"task_z":_effective_z(tracker)})

func _hud_brightness(image: Image, control: Control) -> float:
	var rect := control.get_global_rect().intersection(Rect2(Vector2.ZERO, image.get_size()))
	var total := 0.0
	var count := 0
	for y in range(int(rect.position.y), int(rect.end.y), 2):
		for x in range(int(rect.position.x), int(rect.end.x), 2):
			var color := image.get_pixel(x,y)
			total += color.r + color.g + color.b
			count += 1
	return total / maxf(1.0, count)

func _verify_mask_dimming(mask: ColorRect, context: String) -> void:
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	await RenderingServer.frame_post_draw
	var dimmed := get_viewport().get_texture().get_image()
	var alpha := mask.self_modulate.a
	mask.self_modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var undimmed := get_viewport().get_texture().get_image()
	mask.self_modulate.a = alpha
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for item in [tracker._task_button, hud.reputation_label]:
		var dim_value := _hud_brightness(dimmed, item)
		var normal_value := _hud_brightness(undimmed, item)
		_check(dim_value < normal_value * 0.9, context + "：实际渲染被蒙层压暗 " + item.name,
			{"masked":dim_value,"unmasked":normal_value})
