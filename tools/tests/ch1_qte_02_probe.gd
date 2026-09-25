extends SceneTree
## 最小缺陷复现；仅接受 runner 提供的隔离用户目录。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var isolated := OS.get_environment("MAZE_QTE02_PROFILE").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(isolated + "/"):
		quit(2)
		return
	var sm = root.get_node("SaveManager")
	var mode := OS.get_cmdline_user_args()[0]
	var ok := false
	if mode == "stale":
		sm.data = sm._defaults()
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		sm.start_first_order_cooking()
		sm.finish_first_order_cooking(3)
		sm.deliver_first_order()
		sm.data.inventory.salt_grilled_rockmane = 1
		sm.data.prepared_dishes.salt_grilled_rockmane = {"1": 1, "2": 0, "3": 0}
		ok = sm.cooked_quality() == 1
	elif mode == "progress":
		sm.data = sm._defaults()
		sm.accept_first_order()
		sm.claim_first_order_ingredients()
		sm.start_first_order_cooking()
		sm.data.first_order_progress = []
		sm.save()
		sm.load_data()
		ok = sm.data.first_order_progress is Dictionary and not sm.migration_diagnostics.is_empty()
	elif mode == "quality":
		sm.data = sm._defaults()
		sm.data.first_order_cooking.quality = []
		sm.save()
		sm.load_data()
		ok = sm.data.first_order_cooking.quality is int and not sm.migration_diagnostics.is_empty()
	print(JSON.stringify({"case": mode, "checks": 1, "failures": 0 if ok else 1}))
	quit(0 if ok else 1)
