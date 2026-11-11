extends "res://tools/tests/yf03_lifecycle.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"食谱目录展示隔离")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		suffix="_%dx%d"%[resolution.x,resolution.y]
		_setup("done")
		_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"赠礼后回餐厅查看食谱")
		maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene=maze
		await get_tree().create_timer(0.4).timeout
		var hud=get_tree().get_first_node_in_group("restaurant_hud")
		await _click(hud._recipe_entry)
		var book=hud._recipe_book
		_check(book.visible and book.rows.size()==4,"真实食谱入口显示原配方及三份解锁")
		for index in range(1,book.rows.size()):
			var line=book.rows[index].get_child(0)
			_check(line.get_child(line.get_child_count()-1) is Label and line.get_child(line.get_child_count()-1).text.begins_with("探索 · "),"探索料理只显示维度无虚构售价")
		for slot in Bento.GIFTS:
			var recipe: Dictionary=Bento.Catalog.get_recipe(Bento.GIFTS[slot])
			_check(recipe.ingredients.size()==2 and recipe.ingredients.values().all(func(n): return n==1),"已确认配方两材料各1")
			for id in recipe.ingredients: _check(Bento.Catalog.is_ingredient(id),"材料目录存在："+str(id))
		book.scroll.scroll_vertical=200
		await get_tree().process_frame
		await _capture_image("unlocked_exploration_recipes")
		await _click(book.close_button)
		_check(not hud._player.input_locked,"食谱关闭恢复输入")
		maze.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
