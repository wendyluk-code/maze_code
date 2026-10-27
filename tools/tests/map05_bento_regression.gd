extends "res://tools/tests/bento01_flow.gd"
func _restaurant() -> void:
	super._restaurant()
	# 当前基线的首次冰柜对白另有专项；装配夹具从已读前置开始。
	sm.data.freezer_unlock_notice_seen=true
