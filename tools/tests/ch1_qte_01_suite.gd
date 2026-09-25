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
		_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0, "开始只扣材料一次")
		_check(sm.finish_first_order_cooking(quality, 0.0).success, "锁定品质 %d" % quality)
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
	print(JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures == 0 else 1)
