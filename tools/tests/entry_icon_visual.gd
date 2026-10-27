extends "res://tools/tests/bento01_flow.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d"%[resolution.x,resolution.y]
			_restaurant()
			sm.data.freezer_unlock_notice_seen=true
			sm.save()
			scene=RESTAURANT.instantiate()
			get_tree().root.add_child(scene)
			get_tree().current_scene=scene
			await get_tree().create_timer(0.8).timeout
			var hud=get_tree().get_first_node_in_group("restaurant_hud")
			_check(hud.bento_entry.visible and hud._recipe_entry.visible,"餐厅入口可见")
			_check(hud.bento_entry.icon.get_image().has_mipmaps(),"便当缩小纹理包含多级采样")
			_check(hud._recipe_entry.get_node("RecipeShadow").get_global_rect().get_center().distance_to(hud._recipe_entry.get_global_rect().get_center())<0.1,"食谱投影居中")
			await _capture_image("restaurant")
			await _click(hud.bento_entry)
			_check(hud.bento_modal.visible,"投影不拦截便当点击")
			await _send_key(KEY_ESCAPE)
			_check(not hud._player.input_locked,"关闭便当恢复输入")
			scene.queue_free()
			await get_tree().process_frame
			_check(Run.begin(sm,Roads.SPAWN).success,"进入迷宫")
			maze=load("res://scenes/maze_entry.tscn").instantiate()
			get_tree().root.add_child(maze)
			get_tree().current_scene=maze
			await get_tree().create_timer(0.7).timeout
			_check(maze.bento_entry.visible and maze.backpack_entry.visible,"迷宫入口可见")
			_check(maze.bento_entry.get_node("BentoShadow").get_global_rect().get_center().distance_to(maze.bento_entry.get_global_rect().get_center())<0.1,"迷宫便当投影居中")
			await _capture_image("maze")
			await _click(maze.bento_entry)
			_check(maze.bento_modal.visible,"迷宫便当可点击")
			await _send_key(KEY_ESCAPE)
			_check(not maze.player.input_locked,"迷宫关闭恢复输入")
			maze.queue_free()
			await get_tree().process_frame
	_report()
