extends "res://tools/tests/ch2_entry_state.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_completed()
		var catalog = sm.RecipeCatalog
		_check(catalog.can_cook("slime_candy", {"slime_shell":1,"moondew_honey":1}), "新配方可制作")
		_check(not catalog.can_cook("slime_candy", {"slime_gel":1,"moondew_honey":1}), "旧原料不能新开锅")
		sm.data[sm.UNLOCKED_RECIPES_KEY] = ["salt_grilled_rockmane","slime_candy"]
		sm.data.inventory["slime_gel"] = 0
		sm.data.inventory["moondew_honey"] = 0
		sm.data[sm.COOKING_STATE_KEY] = {"status":"active","recipe_id":"slime_candy","quality":0,"pointer":0.0,"ingredients_consumed":{"slime_gel":1,"moondew_honey":1},"ingredient_balances":{"slime_gel":0,"moondew_honey":0}}
		_check(sm.save(), "保存旧烹饪中断记录")
		sm.load_data()
		_check(sm.inventory_quantity("slime_candy") == 1, "旧配方读档恢复成品")
		sm.load_data()
		_check(sm.inventory_quantity("slime_candy") == 1, "再次读档不重复成品")
		await _open_scene()
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var rows: Array = hud._recipe_data()
		var row: Dictionary = rows.filter(func(r): return r.id == "slime_candy")[0]
		_check(row.name == "弹跳史莱姆冻" and row.ingredients[0].name == "史莱姆核", "真实食谱名称和原料")
		_check(row.icon != null and row.gold == 10, "正式素材加载与售价")
		hud._recipe_book.set_recipes(rows)
		hud._recipe_book.show()
		await get_tree().create_timer(0.3).timeout
		await _shot("pudding_recipe")
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
