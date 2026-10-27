extends "res://tools/tests/elder_01_state.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	_check(_isolation(), "隔离用户目录")
	if failures: return _finish()
	_seed(12)
	_check(sm.accept_elder_firewood(NEAR).success, "接取")
	_check(sm.deliver_elder_firewood(NEAR).success, "交付")
	for id in ["moondew_honey", "cooking_sake", "sour_vine_juice"]:
		_check(sm.warehouse_snapshot().get(id, 0) == 3 and sm.inventory_quantity(id) == 0, "直接入库 " + id)
	_check(not sm.deliver_elder_firewood(NEAR).success, "重复交付拒绝")
	sm.load_data()
	_check(sm.warehouse_snapshot().get("moondew_honey") == 3, "新奖励读档不重复")
	for location in ["inventory", "warehouse_stock"]:
		sm.data.erase("elder_ingredients_version")
		sm.data.inventory = {"wood":0}
		sm.data.warehouse_stock = {"moondew_honey":1,"cooking_sake":2}
		sm.data[location].merge({"lantern_berry":3,"insulating_leaf":3,"sour_vine_juice":3},true)
		sm.data["capture_run_v1"] = {"bag":{"slime_gel":2}}
		_check(sm.save(), "旧档落盘 " + location)
		sm.load_data()
		var stock: Dictionary = sm.warehouse_snapshot()
		_check(stock.get("moondew_honey") == 4 and stock.get("cooking_sake") == 5 and stock.get("sour_vine_juice") == 3, "旧奖励转换且保留已有新食材 " + location)
		_check(sm.inventory_quantity("lantern_berry") == 0 and stock.get("lantern_berry",0) == 0, "旧食材移除 " + location)
		_check(sm.data.capture_run_v1.bag.slime_gel == 2, "捕获暂存不变")
		_check(sm.save(), "保存迁移版本")
		sm.load_data()
		_check(sm.warehouse_snapshot() == stock, "重新加载不重复替换")
	var modal = preload("res://scripts/ui/warehouse_modal.gd").new()
	add_child(modal)
	modal.open_stock()
	await get_tree().process_frame
	_check(modal._slot_by_id.has("moondew_honey") and modal._slot_by_id.has("cooking_sake"), "真实仓库有新食材格")
	var reward = preload("res://scripts/ui/components/elder_ingredient_reward.gd").new()
	add_child(reward)
	reward.present()
	await get_tree().process_frame
	_check(Elder.REWARD_ITEMS[0].name == "月露蜜" and Elder.REWARD_ITEMS[1].name == "烧酒", "奖励弹窗共用正确名称")
	for item in Elder.REWARD_ITEMS:
		_check(Elder.reward_texture(item) != null, "奖励图标 " + item.name)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_arg("--output-dir=").get_base_dir().path_join("reward.png"))
	_finish()

