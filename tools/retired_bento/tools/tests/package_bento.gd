extends "res://tools/tests/bento01_flow.gd"
## 原便当流程早于新增冰柜教学；夹具明确已读，教学本身由 freezer_story_unlock 验证。
func _restaurant() -> void:
	super._restaurant()
	_check(sm.acknowledge_freezer_notice(), "便当独立场景前置：已确认新增冰柜教学")
