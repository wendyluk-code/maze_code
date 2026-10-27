extends "res://tools/tests/npc_01_scene.gd"

func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	# 布局专项从已有顾客记录启动，不触发首次来客教学。
	sm.ensure_restaurant_customer()
	await reopen()
	flow.set_process(false)
	player.global_position = stand(restaurant.get_node("InteractPoints/Register"))
	player.last_valid = player.global_position
	await pause(0.5)
	var entry: Control = flow.hud._recipe_entry
	var entry_before := entry.get_global_rect()
	for index in 3:
		var config: Dictionary = flow.Catalog.CUSTOMERS[index]
		for phase in ["order", "farewell"]:
			var line: String = "请给我一份%s。" % sm.RecipeCatalog.get_recipe(config.recipe).name if phase == "order" else "谢谢款待，下次再来！"
			flow._dialog.start(config.name, [line], load(config.portrait))
			await pause(1.5)
			check(flow._shade.visible, "每段对白均有蒙层")
			check(entry.get_global_rect() == entry_before, "对白不移动左下入口")
			check(is_equal_approx(flow._dialog.get_global_rect().position.x, 30.0), "对白左边距30")
			check(is_equal_approx(flow._dialog.size.x, get_viewport().get_visible_rect().size.x - 60.0), "对白保持左右边距")
			await shot("portrait_%s_%d" % [phase, index])
			check(flow._dialog.speaker_name.text == "冒险者", "头像对白姓名")
			flow._dialog.hide()
			check(not flow._shade.visible, "关闭对白恢复蒙层")
	print("PORTRAIT_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
