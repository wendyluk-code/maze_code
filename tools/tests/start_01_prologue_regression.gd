extends "res://tools/tests/pro_01_suite.gd"
## 唯一更新的旧断言：正式入口已从序章改为封面；其余序章断言原样执行。

func _check(ok: bool, label: String, details: Dictionary = {}) -> void:
	if label == "主场景为序章入口":
		super._check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/start_screen.tscn", "正式入口为封面，序章保持独立入口", details)
	else:
		super._check(ok, label, details)
