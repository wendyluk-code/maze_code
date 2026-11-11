extends "res://tools/tests/yf04_flow.gd"
## 新增返店教学优先于便当入口；按实际 E 读完后继续原有点击流程。
func _click(control: Control) -> void:
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	if is_instance_valid(hud):
		var guide = hud.exploration_guide
		if guide.reading and guide.lesson_id == guide.FREEZER_NOTICE:
			await _send_key(KEY_E)
			await _send_key(KEY_E)
			_check(not guide.reading, "实际E读完返店冰柜教学后使用便当入口")
	await super._click(control)
