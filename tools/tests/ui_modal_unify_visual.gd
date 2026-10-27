extends "res://tools/tests/ch1_qte_03_input.gd"
## 实际餐厅中的样式样例；注入原生键鼠，截图覆盖无独立运行器的弹窗。
const Style := preload("res://scripts/ui/components/modal_style.gd")
var capture_panel: Control
var capture_close: Button

func _capture(output_dir: String, label: String) -> void:
	# 展示接口只更新节点状态；等待布局与实际绘制后再读取纹理。
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if is_instance_valid(capture_panel):
		_check(capture_panel.is_visible_in_tree() and capture_close.is_visible_in_tree(), label + "捕获时目标面板与关闭按钮可见")
		var rendered := get_viewport().get_texture().get_image()
		var panel_rect := capture_panel.get_global_rect()
		var sample := Vector2i(panel_rect.position + Vector2(24,100))
		var pixel := rendered.get_pixelv(sample)
		_check(pixel.r > 0.85 and pixel.g > 0.75 and pixel.b > 0.55, label + "已绘制目标浅色面板而非上一帧餐厅", {"sample":str(sample), "rgba":str(pixel)})
		var close_rect := capture_close.get_global_rect()
		var gold_pixels := 0
		for y in range(int(close_rect.position.y),int(close_rect.end.y)):
			for x in range(int(close_rect.position.x),int(close_rect.end.x)):
				var ink := rendered.get_pixel(x,y)
				if ink.r > 0.7 and ink.g > 0.5 and ink.b < 0.5 and ink.r - ink.b > 0.3:
					gold_pixels += 1
		_check(gold_pixels >= 10, label + "关闭命中区实际绘制金色×", {"gold_pixels":gold_pixels})
	await super._capture(output_dir, label)
	capture_panel = null
	capture_close = null

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离目录")
	var output := _arg("--output-dir=")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			await get_tree().process_frame
			sm.data = sm._defaults()
			sm.data.prologue_done = true
			sm.data.chapter_1_intro = "guest_arrived"
			sm.save()
			scene = RESTAURANT.instantiate()
			get_tree().root.add_child(scene)
			get_tree().current_scene = scene
			await get_tree().process_frame
			await get_tree().process_frame
			tm._cancel_current_run()
			var layer := CanvasLayer.new()
			layer.layer = 120
			scene.add_child(layer)
			var warehouse = get_tree().get_first_node_in_group("warehouse_modal")
			warehouse.open_empty_stock()
			await _capture(output, "warehouse_%dx%d" % [resolution.x,resolution.y])
			_check(warehouse._overlay.color == Style.BACKDROP, "仓库共用蒙层")
			await _click(warehouse._cancel_button)
			_check(not warehouse.visible, "仓库鼠标取消恢复关闭")
			var modal := SproutModal.new()
			layer.add_child(modal)
			modal.show_modal("通用弹窗", "统一关闭按钮与蒙层", "确认")
			await _capture(output, "generic_%dx%d" % [resolution.x,resolution.y])
			modal._close_button.grab_focus()
			await _send_key(KEY_ENTER)
			_check(not modal.visible, "原生Enter激活关闭按钮")
			modal.show_modal("通用弹窗", "空格也可关闭", "确认")
			modal._close_button.grab_focus()
			await _send_key(KEY_SPACE)
			_check(not modal.visible, "原生Space激活关闭按钮")
			modal.queue_free()
			var cards = load("res://scripts/ui/components/character_cards_modal.gd").new()
			layer.add_child(cards)
			cards.present("yaya", sm.data)
			capture_panel = cards.design.get_child(0)
			capture_close = cards._close_button
			await _capture(output, "character_cards_%dx%d" % [resolution.x,resolution.y])
			await _click(cards._close_button)
			_check(not cards.visible, "旧角色牌组件鼠标关闭")
			cards.queue_free()
			var party = load("res://scripts/ui/party_cards_overlay.gd").new()
			layer.add_child(party)
			party.continue_requested.connect(party.cancel)
			party.present()
			await get_tree().create_timer(1.5).timeout
			await _capture(output, "party_%dx%d" % [resolution.x,resolution.y])
			_check(party._veil.color == Style.BACKDROP, "入队弹窗共用蒙层")
			await _send_key(KEY_E)
			_check(not party.visible, "入队原E继续关闭")
			party.queue_free()
			var loot = load("res://scripts/ui/components/loot_modal.gd").new()
			layer.add_child(loot)
			loot.show_reward(100,100)
			await _capture(output, "loot_%dx%d" % [resolution.x,resolution.y])
			await _click(loot._confirm_button)
			_check(not loot.visible, "获得物品原收下按钮关闭")
			loot.queue_free()
			_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "料理台真实接单取料前置")
			sm.acknowledge_cooking_guide()
			var cooking = scene.get_node("HUD/CookingModal")
			cooking.open_for_order()
			capture_panel = cooking._panel
			capture_close = cooking._cancel_button
			await _capture(output, "cooking_%dx%d" % [resolution.x,resolution.y])
			await _click(cooking._cancel_button)
			_check(not cooking.visible, "料理台共用关闭按钮鼠标关闭")
			# 真实经营事务建立旧盐池地图前置，再打开餐厅既有地图组件。
			_check(sm.cook_first_order().success and sm.deliver_first_order().success, "地图样例真实首单前置")
			for step in sm.WRAPUP_STEPS:
				if sm.RETIRED_WRAPUP_STEPS.has(step): continue
				if sm.departure_state().step == "ready_to_depart": break
				sm.advance_departure(step)
			var departure = get_tree().get_first_node_in_group("departure_panel")
			departure.open_map()
			await get_tree().create_timer(0.8).timeout
			_check(departure._open and departure._modal.color == Style.BACKDROP, "餐厅地图共用蒙层")
			await _capture(output, "departure_%dx%d" % [resolution.x,resolution.y])
			await _send_key(KEY_ESCAPE)
			_check(not departure._open, "餐厅地图Esc恢复输入")
			layer.queue_free()
			scene.queue_free()
			await get_tree().process_frame
	var report := {"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name(),"user_dir":ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	get_tree().quit(1 if failures else 0)
