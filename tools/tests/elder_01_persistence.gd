extends "res://tools/tests/elder_01_state.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	_check(_isolation(), "独立进程用户目录隔离")
	var stage := _arg("--stage=")
	if failures == 0:
		if _arg("--phase=") == "prepare":
			_seed(0)
			_check(sm.accept_elder_firewood(NEAR).success, "独立进程接取提交")
			if stage == "partial":
				var site: Dictionary = sm.DigCatalog.all()[0]
				_check(sm.claim_exploration_dig_site(site.id, _site_approach(site)).success, "实际挖掘事务获得部分木材")
			elif stage == "delivered":
				for site in sm.DigCatalog.all():
					_check(sm.claim_exploration_dig_site(site.id, _site_approach(site)).success, "实际挖掘木材：" + site.id)
				_check(sm.inventory_quantity("wood") == 12 and sm.deliver_elder_firewood(NEAR).success, "四处各3交付闭环")
		else:
			sm._active_save_path = "user://elder-state.json"
			var bytes := FileAccess.get_file_as_bytes(sm._active_save_path)
			sm.load_data()
			var state: Dictionary = sm.elder_firewood_state()
			_check(state.valid and state.status == ("archived" if stage == "delivered" else "active"), "新进程恢复实例：" + stage)
			_check(state.wood == (3 if stage == "partial" else 0), "新进程恢复木材：" + stage)
			_check(sm.elder_backpack_unlocked() == (stage == "delivered"), "新进程恢复一次性背包凭证")
			for id in ["moondew_honey", "cooking_sake", "sour_vine_juice"]:
				_check(int(sm.warehouse_snapshot().get(id, 0)) == (3 if stage == "delivered" else 0), "新进程恢复仓库食材数量："+id)
			_check(state.unread == (stage != "delivered"), "新进程未读/归档恢复")
			_check(FileAccess.get_file_as_bytes(sm._active_save_path) == bytes, "独立恢复纯读不写文件")
	_finish()

