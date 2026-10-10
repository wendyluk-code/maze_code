extends SceneTree

var sm
var checks := 0
var failures := 0
var results: Array = []
const DISH := "salt_grilled_rockmane"

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	results.append({"label": label, "passed": ok})
	if not ok:
		failures += 1
		push_error("COOKING V2: " + label)

func _fresh() -> void:
	sm.data = sm._defaults()
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "接单取料夹具")

func _reload() -> void:
	_check(sm.save(), "隔离夹具写盘")
	sm.load_data()

func _run() -> void:
	var profile := OS.get_environment("MAZE_COOKING_V2_PROFILE").replace("\\", "/")
	if profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(profile + "/"):
		push_error("需要隔离 APPDATA")
		quit(2)
		return
	sm = root.get_node("SaveManager")
	sm.data = sm._defaults()
	_check(sm.unlocked_recipe_ids().is_empty(), "默认无解锁")
	sm.data.inventory.rockmane_meat = 3
	sm.data.inventory.rock_salt = 3
	_check(sm.available_cooking_recipes().is_empty(), "足量但未解锁不匹配")
	var before: Dictionary = sm.data.duplicate(true)
	sm.carried_ingredients()
	sm.available_cooking_recipes()
	_check(sm.data == before, "读取原料及候选不改库存")
	_check(sm.accept_first_order().success and sm.unlocked_recipe_ids() == [DISH], "接单解锁")
	_reload()
	_check(sm.unlocked_recipe_ids() == [DISH], "解锁持久化")
	sm.accept_first_order()
	_check(sm.unlocked_recipe_ids() == [DISH], "重复接单不重复解锁")
	_fresh()
	sm.data.inventory[DISH] = 1
	sm.data.inventory.future_ingredient = 9
	_check(sm.carried_ingredients() == {"rockmane_meat": 1, "rock_salt": 1}, "成品及未知物品不当原料")
	before = sm.data.duplicate(true)
	_check(sm.start_cooking(DISH).reason == "already_cooked" and sm.data == before, "已有成品拒绝重煮且不扣料")
	sm.data.inventory[DISH] = 0
	sm.data.inventory.rock_salt = 0
	_check(sm.available_cooking_recipes().is_empty(), "缺少盐不匹配")
	before = sm.data.duplicate(true)
	_check(not sm.start_cooking(DISH).success and sm.data == before, "不足材料零消耗")
	_fresh()
	sm.data.unlocked_recipe_ids = []
	before = sm.data.duplicate(true)
	_check(sm.start_cooking(DISH).reason == "recipe_locked" and sm.data == before, "锁定菜谱不可烹饪")
	for stars in [1, 2, 3]:
		_fresh()
		sm.data.inventory.rockmane_meat = 4
		sm.data.inventory.rock_salt = 6
		_check(sm.available_cooking_recipes() == [DISH], "足量已解锁可匹配")
		_check(sm.start_cooking(DISH).success, "开始选择菜谱")
		_check(sm.inventory_quantity("rockmane_meat") == 3 and sm.inventory_quantity("rock_salt") == 5, "多带材料只扣配方一份")
		before = sm.data.duplicate(true)
		_check(not sm.start_cooking(DISH).success and sm.data == before, "连点不重扣")
		_check(sm.finish_first_order_cooking(stars, 0.0).success, "有剩余材料仍可起锅")
		_check(sm.cooked_quality() == stars, "品质保存")
		_check(sm.deliver_first_order().reputation_awarded == {1: 10, 2: 12, 3: 15}[stars], "原声望规则")
		_check(sm.inventory_quantity("rockmane_meat") == 3 and sm.inventory_quantity("rock_salt") == 5, "交付不扣剩余材料")
	# 旧档迁移不改变物品或奖励，新字段明确为空时不猜测解锁。
	for phase in ["accepted", "completed"]:
		_fresh()
		if phase == "completed":
			sm.start_cooking(DISH)
			sm.finish_first_order_cooking(3)
			sm.deliver_first_order()
		sm.data.erase("unlocked_recipe_ids")
		var inventory: Dictionary = sm.inventory_snapshot()
		var reputation: int = sm.reputation()
		_reload()
		_check(sm.unlocked_recipe_ids() == [DISH], "旧有效历史补解锁 " + phase)
		_check(sm.inventory_snapshot() == inventory and sm.reputation() == reputation, "迁移不发料奖励 " + phase)
	_fresh()
	sm.data.unlocked_recipe_ids = []
	_reload()
	_check(sm.unlocked_recipe_ids().is_empty(), "显式锁定字段读取不覆盖")
	# 读取恢复与同进程恢复均保留多余原料，且不会重复产物。
	for restart in [false, true]:
		_fresh()
		sm.data.inventory.rockmane_meat = 2
		sm.data.inventory.rock_salt = 4
		sm.start_cooking(DISH)
		if restart:
			_reload()
		else:
			_check(sm.recover_interrupted_cooking().success, "同进程中断恢复")
		_check(sm.cooked_quality() == 1 and sm.inventory_quantity(DISH) == 1, "中断恢复一份1星")
		_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 3, "恢复保留剩余原料")
		sm.recover_interrupted_cooking()
		_reload()
		_check(sm.inventory_quantity(DISH) == 1, "重复恢复不重复产物")
	_fresh()
	sm.start_cooking(DISH)
	sm.data.first_order_cooking.erase("ingredients_consumed")
	sm.data.first_order_cooking.erase("ingredient_balances")
	_reload()
	_check(sm.cooked_quality() == 1, "旧无明细active档兼容")
	_fresh()
	sm.data.inventory.rockmane_meat = 3
	sm.start_cooking(DISH)
	sm.data.first_order_cooking.ingredients_consumed.rockmane_meat = 0
	_check(not sm.finish_first_order_cooking(3).success, "损坏扣料凭据不发成品")
	# 真实写盘失败验证接单解锁与扣料事务全部回滚。
	for operation in ["accept", "start"]:
		sm.data = sm._defaults()
		if operation == "start":
			_fresh()
		before = sm.data.duplicate(true)
		var original_path: String = sm._active_save_path
		sm._active_save_path = "user://missing-directory/save.json"
		var response: Dictionary = sm.accept_first_order() if operation == "accept" else sm.start_cooking(DISH)
		_check(not response.success and response.reason == "save_failed" and sm.data == before, "保存失败完整回滚 " + operation)
		sm._active_save_path = original_path
	var report := {"checks": checks, "failures": failures, "results": results}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			FileAccess.open(argument.substr(9), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures == 0 else 1)
