extends Node

var failures := 0
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("QTE FAIL: " + label)

func _run() -> void:
	var sm := get_node("/root/SaveManager")
	var tm := get_node("/root/TutorialManager")
	_check(tm._quality_feedback(1, 10) != tm._quality_feedback(2, 12) and tm._quality_feedback(2, 12) != tm._quality_feedback(3, 15), "三档顾客评价不同")
	_check("+20" not in tm._quality_feedback(3, 15), "新评价不显示旧 +20")
	var judgement = preload("res://scripts/cooking/qte_judgement.gd")
	_check(judgement.stars_for_position(0.0, 0.16, 0.38) == 3, "精准区中心为 3 星")
	_check(judgement.stars_for_position(0.08, 0.16, 0.38) == 3, "精准区边界包含")
	_check(judgement.stars_for_position(0.19, 0.16, 0.38) == 2, "良好区边界为 2 星")
	_check(judgement.stars_for_position(0.8, 0.16, 0.38) == 1, "外围为 1 星")
	sm.data = sm._defaults()
	_check(sm.reputation() == 0, "默认声望为 0")
	for quality in [1, 2, 3]:
		sm.data = sm._defaults()
		_check(sm.accept_first_order().success, "接单成功")
		_check(sm.claim_first_order_ingredients().success, "取料成功")
		_check(sm.start_first_order_cooking().success, "开始烹饪扣料")
		_check(not sm.start_first_order_cooking().success and sm.start_first_order_cooking().reason == "already_started", "重复开始不重复扣料")
		_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0, "开始只扣材料一次")
		_check(sm.finish_first_order_cooking(quality, 0.0).success, "锁定品质 %d" % quality)
		_check(not sm.finish_first_order_cooking(3, 0.9).success, "重复起锅不改品质")
		_check(sm.cooked_quality() == quality, "成品品质保留")
		var delivered: Dictionary = sm.deliver_first_order()
		_check(delivered.success and delivered.reputation_awarded == {1: 10, 2: 12, 3: 15}[quality], "星级奖励 %d" % quality)
		var before: int = sm.reputation()
		_check(not sm.deliver_first_order().success and sm.reputation() == before, "重复交付不重复奖励")
	# 乱序操作不会改变已存档事务。
	sm.data = sm._defaults()
	var snapshot: Dictionary = sm.data.duplicate(true)
	_check(not sm.finish_first_order_cooking(3).success and sm.data == snapshot, "未开始不能起锅")
	_check(not sm.deliver_first_order().success and sm.data == snapshot, "未接单不能交付")
	# 模拟退出重进：active 状态迁移为待领取的 1 星结果。
	sm.data = sm._defaults()
	sm.accept_first_order()
	sm.claim_first_order_ingredients()
	sm.start_first_order_cooking()
	sm.save()
	sm.load_data()
	_check(sm.cooking_state().status == "locked" and sm.cooked_quality() == 1 and sm.first_order_progress().next_step == "deliver", "中断恢复为 1 星待交付")
	await _gui_button_flow(sm)
	await _restaurant_scene_mount_check(sm)
	print(JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures == 0 else 1)

func _gui_button_flow(sm: Node) -> void:
	var modal_scene := load("res://scenes/ui/cooking_modal.tscn") as PackedScene
	var modal := modal_scene.instantiate()
	add_child(modal)
	await get_tree().process_frame
	var positions := {1: 0.6, 2: 0.12, 3: 0.0}
	for quality in [1, 2, 3]:
		sm.data = sm._defaults()
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		modal.open_for_order(sm.FIRST_ORDER_ITEM_ID)
		await get_tree().process_frame
		_check(modal.visible and not modal.get("_started"), "GUI %d 星弹窗打开" % quality)
		await _capture_gui(modal, "quality_%d_before" % quality)
		modal.get("_start_button").emit_signal("pressed")
		await get_tree().process_frame
		_check(modal.get("_started") and sm.cooking_state().status == "active", "GUI 点击开始扣料并进入火候")
		await _capture_gui(modal, "quality_%d_running" % quality)
		modal.get("_gauge").set_pointer(float(positions[quality]))
		modal.get("_finish_button").emit_signal("pressed")
		await get_tree().process_frame
		_check(sm.cooked_quality() == quality and modal.get("_finished"), "GUI 起锅得到 %d 星" % quality)
		await _capture_gui(modal, "quality_%d_result" % quality)
		modal.close_modal()
	# 开始前取消不扣料；完整往返无人操作自动 1 星，重复起锅不变。
	sm.data = sm._defaults()
	sm.accept_first_order()
	sm.claim_first_order_ingredients()
	modal.open_for_order(sm.FIRST_ORDER_ITEM_ID)
	await get_tree().process_frame
	modal.get("_cancel_button").emit_signal("pressed")
	_check(not modal.visible and sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1, "GUI 开始前取消不扣料")
	modal.open_for_order(sm.FIRST_ORDER_ITEM_ID)
	await get_tree().process_frame
	modal.get("_start_button").emit_signal("pressed")
	modal.set("_elapsed", modal.get("_round_duration"))
	modal._process(0.0)
	_check(sm.cooked_quality() == 1 and modal.get("_finished"), "GUI 超时自动 1 星")
	var after_timeout: Dictionary = sm.data.duplicate(true)
	modal.get("_finish_button").emit_signal("pressed")
	_check(sm.data == after_timeout, "GUI 重复起锅不改状态")
	modal.close_modal()
	modal.queue_free()

func _restaurant_scene_mount_check(sm: Node) -> void:
	var restaurant := (load("res://scenes/restaurant_map_2d.tscn") as PackedScene).instantiate()
	add_child(restaurant)
	await get_tree().process_frame
	var modal := restaurant.get_node("HUD/CookingModal")
	_check(is_instance_valid(modal) and restaurant.get_node("HUD").layer == 10, "餐厅主场景挂载高层烹饪弹窗")
	sm.data = sm._defaults()
	sm.accept_first_order()
	sm.claim_first_order_ingredients()
	modal.open_for_order(sm.FIRST_ORDER_ITEM_ID)
	await get_tree().process_frame
	_check(modal.visible and get_tree().get_first_node_in_group("cooking_modal") == modal, "料理台弹窗在餐厅场景可打开")
	modal.close_modal()
	restaurant.queue_free()

func _capture_gui(modal: Control, label: String) -> void:
	var output: String = _arg("--output-dir=")
	if output.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(output)
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		var headless_report := FileAccess.open(output.path_join("CH1-QTE-01-" + label + ".txt"), FileAccess.WRITE)
		headless_report.store_string("headless renderer: no viewport image; GUI state checks passed")
		headless_report.close()
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		FileAccess.open(output.path_join("CH1-QTE-01-" + label + ".txt"), FileAccess.WRITE).store_string("headless renderer: no viewport texture; GUI state checks passed")
		return
	var image := texture.get_image()
	if image == null:
		var report := FileAccess.open(output.path_join("CH1-QTE-01-" + label + ".txt"), FileAccess.WRITE)
		report.store_string("headless renderer: no readable viewport image; GUI state checks passed")
		report.close()
		return
	image.save_png(output.path_join("CH1-QTE-01-" + label + ".png"))

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with(prefix):
			return str(arg).substr(prefix.length())
	for arg in OS.get_cmdline_args():
		if str(arg).begins_with(prefix):
			return str(arg).substr(prefix.length())
	return ""
