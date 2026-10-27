extends "res://tools/tests/rec01_flow.gd"
@export var restore := false

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		if not restore:
			_seed()
			sm.data.gold = 9000
			var result: Dictionary = sm.recruit(10, func(): return 0.0)
			_check(result.success and sm.gold_balance() == 0 and sm.stardust_balance() == 400, "十连结果一次保存后直接退出进程")
			var expected := FileAccess.open("user://recruit_expected.json", FileAccess.WRITE)
			expected.store_string(JSON.stringify({"owned": sm.owned_characters(), "growth": sm.data[Growth.KEY], "recruitment": sm.data[Recruit.KEY], "gold": sm.gold_balance()}))
		else:
			sm._active_save_path = "user://chapter-ending-test.json"
			sm.load_data()
			var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://recruit_expected.json"))
			_check(sm.owned_characters() == expected.owned and sm.data[Growth.KEY] == expected.growth and sm.data[Recruit.KEY] == expected.recruitment and sm.gold_balance() == expected.gold, "新进程恢复完整收藏成长结果与余额")
			_check(sm.stardust_balance() == 400 and Growth.record(sm, "salia").rank == 6, "中断播放后不重复发放奖励")
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	get_tree().quit(1 if failures else 0)
