extends Node
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")
const DISH := "salt_grilled_rockmane"
var sm
var checks := 0
var failures := 0
var results: Array = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		push_error(label)

func _prepare(stars: int, followup := false) -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://save.json"
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "真实接单取料")
	_check(sm.start_cooking(DISH).success and sm.finish_first_order_cooking(stars).success, "真实烹饪%d星" % stars)
	if followup:
		# 后续订单夹具沿用正式订单结构，不改首单教程。
		sm.data.current_order.id = "gold-test-followup"
		sm.data.chapter_1_done = true
		_check(sm.save(), "保存后续订单夹具")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	var profile := OS.get_environment("MAZE_QTE03_PROFILE").replace("\\", "/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/"):
		get_tree().quit(2)
		return
	_check(Catalog.order_gold(DISH) == 5, "盐烤岩鬃肉固定5金币")
	for quest_id in ["chapter_1_first_order", "restaurant_customer_order"]:
		var reward = sm.QuestRegistry.definition(quest_id).completion_condition.gold_reward
		_check(reward.amount == Catalog.order_gold(reward.recipe_id) and reward.min == 5 and reward.max == 20 and not reward.quality_scaled, "任务金币登记与实际配置一致")
	for value in [5, 6, 20, 5.0]:
		_check(Catalog.valid_order_gold(value), "允许范围内整数：%s" % str(value))
	for value in [null, "5", true, 4, 21, 5.5, INF, NAN]:
		_check(not Catalog.valid_order_gold(value), "拒绝非法金币配置：%s" % str(value))
	_check(Catalog.order_gold("unknown") == 0, "未知料理拒绝奖励")
	for followup in [false, true]:
		for stars in [1, 2, 3]:
			_prepare(stars, followup)
			sm.data.gold = 100
			_check(sm.save(), "保存交单前状态")
			var path: String = sm._active_save_path
			var before: Dictionary = sm.data.duplicate(true)
			var disk := FileAccess.get_file_as_bytes(path)
			# 实际写盘失败：临时文件路径的父目录不存在。
			sm._active_save_path = "user://missing-gold-directory/save.json"
			var failed: Dictionary = sm.deliver_customer_order()
			_check(not failed.success and failed.reason == "save_failed" and sm.data == before and FileAccess.get_file_as_bytes(path) == disk, "交单保存失败全状态与正式文件回滚")
			sm._active_save_path = path
			var result: Dictionary = sm.deliver_customer_order()
			_check(result.success and result.gold_awarded == 5 and sm.gold_balance() == 105 and sm.reputation() == {1:60,2:80,3:100}[stars], "%s%d星固定+5且保持星级声望" % ["后续" if followup else "首单", stars])
			_check(sm.inventory_quantity(DISH) == 0 and sm.cooked_quality() == 0, "只消耗一份对应料理")
			var receipt: Dictionary = sm.data.restaurant_order_receipts["gold-test-followup"] if followup else sm.data.first_order_settlement
			_check(receipt.gold_awarded == 5 and receipt.quality == stars, "同笔凭证记录金币与品质")
			var quest_id := "customer_order:gold-test-followup" if followup else "chapter_1_first_order"
			_check(sm.quest_snapshot().archived.any(func(quest): return quest.id == quest_id) and not sm.quest_snapshot().active.any(func(quest): return quest.id == quest_id), "同笔保存归档当前订单")
			before = sm.data.duplicate(true)
			disk = FileAccess.get_file_as_bytes(path)
			_check(not sm.deliver_customer_order().success and sm.data == before and FileAccess.get_file_as_bytes(path) == disk, "重复交单零奖励零写盘")
			sm.load_data()
			_check(sm.gold_balance() == 105 and sm.reputation() == {1:60,2:80,3:100}[stars] and sm.inventory_quantity(DISH) == 0, "重载金币声望消耗一致")
			_check(not sm.deliver_customer_order().success and sm.gold_balance() == 105, "重载后重复交单不发奖")
		# 未交单旧档也在下一次真实交付获得奖励。
		_prepare(1, followup)
		sm.data.erase("gold")
		_check(sm.save(), "保存无金币字段旧待交付档")
		sm.load_data()
		_check(sm.deliver_customer_order().success and sm.gold_balance() == 5, "旧待交付档首次真实交付奖励")
		# 旧已完成凭证没有金币字段，不得反推补发。
		sm.data.gold = 0
		if followup: sm.data.restaurant_order_receipts["gold-test-followup"].erase("gold_awarded")
		else: sm.data.first_order_settlement.erase("gold_awarded")
		sm.data.erase("gold")
		_check(sm.save(), "保存旧已完成凭证")
		var disk := FileAccess.get_file_as_bytes(sm._active_save_path)
		sm.load_data()
		_check(sm.gold_balance() == 0 and not sm.deliver_customer_order().success and FileAccess.get_file_as_bytes(sm._active_save_path) == disk, "旧已完成档读取与重交不补发不写盘")
		for amount in [-1, 0.5, "bad", 9007199254740991]:
			_prepare(1, followup)
			sm.data.gold = amount
			var before: Dictionary = sm.data.duplicate(true)
			_check(not sm.deliver_customer_order().success and sm.data == before, "坏余额或溢出拒绝交付并保持状态")
	for legacy_reward in [20, 10, 12, 15]:
		_prepare(1)
		_check(sm.deliver_first_order().success, "旧凭证夹具交付")
		sm.data.erase("gold")
		sm.data.first_order_settlement.erase("gold_awarded")
		sm.data.first_order_settlement.reputation_awarded = legacy_reward
		sm.data.reputation = legacy_reward
		if legacy_reward == 20: sm.data.first_order_settlement.erase("quality")
		else: sm.data.first_order_settlement.quality = {10:1,12:2,15:3}[legacy_reward]
		_check(sm.save(), "保存历史无星或旧星级凭证")
		var disk := FileAccess.get_file_as_bytes(sm._active_save_path)
		sm.load_data()
		_check(sm.has_first_order_settlement() and sm.gold_balance() == 0 and sm.is_gold_display_unlocked() and sm.reputation() == legacy_reward and not sm.deliver_first_order().success and FileAccess.get_file_as_bytes(sm._active_save_path) == disk, "历史凭证恢复显示0金币且不补发")
	_prepare(2)
	_check(sm.save(), "保存独立进程待交付档")
	sm.load_data()
	_check(sm.deliver_customer_order().success, "重载待交付档后可成功交付")
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _arg(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.substr(prefix.length())
	return ""
