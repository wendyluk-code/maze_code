extends "res://tools/tests/restaurant_rest04.gd"
## 已读首客教学的存档继续原真实接单、上菜、结算和顾客表情回归。
func _seed_cycle() -> void:
	super._seed_cycle()
	sm.data["restaurant_arrival_lesson_v1"] = {"phase":"done"}

func _tieshan_preserved() -> void:
	await super._tieshan_preserved()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
