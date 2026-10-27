extends "res://tools/tests/rec01_flow.gd"
const MAX_BALANCE := 9007199254740991

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_seed()
		sm.data.gold = 100000
		sm.recruit(1, func(): return 0.0)
		sm.data[Growth.KEY].salia.rank = 6
		var base: Dictionary = sm.data.duplicate(true)
		# 只改变初始星尘，抽取源、角色、金币和保存位置保持相同。
		for initial in [MAX_BALANCE - 100, MAX_BALANCE - 99, MAX_BALANCE]:
			sm.data = base.duplicate(true)
			sm.data[Recruit.KEY].stardust = initial
			sm.save()
			var previous: Dictionary = sm.data.duplicate(true)
			var previous_bytes := FileAccess.get_file_as_bytes(sm._active_save_path)
			var result: Dictionary = sm.recruit(1, func(): return 0.0)
			if initial == MAX_BALANCE - 100:
				_check(result.success and sm.stardust_balance() == MAX_BALANCE, "恰达上限完整发放100星尘")
			else:
				_check(not result.success and result.get("reason") == "stardust_limit" and sm.data == previous and FileAccess.get_file_as_bytes(sm._active_save_path) == previous_bytes and not sm._recruit_busy, "超过上限整体拒绝且内存/磁盘/金币/角色/锁不变:" + str(initial), {"result": result, "after_balance": sm.stardust_balance()})
		sm.data = base.duplicate(true)
		sm.data[Recruit.KEY].stardust = MAX_BALANCE - 100
		sm.save()
		var before_batch: Dictionary = sm.data.duplicate(true)
		var disk_before := FileAccess.get_file_as_bytes(sm._active_save_path)
		var batch: Dictionary = sm.recruit(10, func(): return 0.0)
		_check(not batch.success and batch.reason == "stardust_limit" and sm.data == before_batch and FileAccess.get_file_as_bytes(sm._active_save_path) == disk_before, "十连第二张越界回滚第一张和整批所有状态")
		sm.data[Recruit.KEY].stardust = MAX_BALANCE
		var fresh: Dictionary = sm.recruit(1, func(): return 0.2)
		_check(fresh.success and fresh.results[0].kind == "new" and sm.stardust_balance() == MAX_BALANCE, "不产星尘的新卡在余额上限仍可完整发放")
	var report := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
