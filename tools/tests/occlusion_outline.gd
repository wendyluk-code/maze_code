extends "res://tools/tests/ch2_entry_state.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_completed()
		scene = RESTAURANT.instantiate()
		var authored := {}
		for key in ["Cauldron", "FoodCart", "Fridge", "BarCounter", "Register", "Store"]:
			authored[key] = scene.get_node("InteractPoints/" + key + "/OcclusionOutline").polygon.duplicate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.5).timeout
		for key in ["Cauldron", "FoodCart", "Fridge", "BarCounter", "Register", "Store"]:
			var prop = scene.get_node("InteractPoints/" + key)
			var outline = prop.get_node("OcclusionOutline")
			_check(outline.polygon == authored[key], key + "启动保留编辑器保存的轮廓")
			for entry in scene.get_node("PropForeground")._layers:
				if entry.target == prop:
					_check(entry.occlusion == prop.world_occlusion_polygon(), key + "遮挡缓存使用编辑后的轮廓")
			_check(not outline.visible, key + "运行时隐藏编辑轮廓")
			var old: PackedVector2Array = prop.world_occlusion_polygon()
			outline.position += Vector2(10,0)
			_check(prop.world_occlusion_polygon()[0] == old[0] + Vector2(10,0), key + "编辑坐标被运行接口读取")
			outline.position -= Vector2(10,0)
		var packed := PackedScene.new()
		_check(packed.pack(scene) == OK, "场景序列化")
		var path := _arg("--output-dir=") + "/edited.tscn"
		_check(ResourceSaver.save(packed, path) == OK, "保存编辑场景")
		var copy = load(path).instantiate()
		_check(copy.get_node("InteractPoints/BarCounter/OcclusionOutline").polygon == scene.get_node("InteractPoints/BarCounter/OcclusionOutline").polygon, "保存重开轮廓一致")
		copy.free()
		await RenderingServer.frame_post_draw
		_capture(_arg("--output-dir="), "runtime")
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
