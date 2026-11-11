extends "res://tools/tests/yufeng_sitting_flow.gd"
const Growth = preload("res://scripts/characters/character_progression.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_completed()
		sm.data["owned_characters_v1"]=Growth.CHARACTERS.keys()
		var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(restaurant)
		get_tree().current_scene=restaurant
		await get_tree().create_timer(0.5).timeout
		var layer:=CanvasLayer.new()
		layer.layer=200
		restaurant.add_child(layer)
		var modal=preload("res://scripts/ui/components/character_details_modal.gd").new()
		layer.add_child(modal)
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await get_tree().process_frame
			for id in Growth.CHARACTERS:
				modal.present(id)
				await get_tree().process_frame
				_check(modal.visible and not modal.error_label.visible,"角色详情正常打开："+id)
				_check(not modal.find_children("*","Button",true,false).any(func(b):return b.text=="完整说明"),"无完整说明入口："+id)
				_check(not modal.active_description.text.is_empty(),"保留技能简介："+id)
				if id=="yufeng": await _capture_image("yufeng_attributes")
				await _click(modal.tabs[1])
				_check(modal.skills.visible,"技能页仍可切换："+id)
				await _send_key(KEY_ESCAPE)
				_check(not modal.visible,"Esc直接关闭角色详情："+id)
		restaurant.queue_free()
		await get_tree().create_timer(1.3).timeout
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
