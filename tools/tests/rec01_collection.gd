extends "res://tools/tests/rec01_flow.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_seed()
		for checkpoint in ["party","home","maze","title"]: sm.advance_chapter_1_outro(checkpoint)
		await _open_scene()
		HomePage.open_page(get_tree())
		await get_tree().process_frame
		var page = get_tree().get_first_node_in_group("adventurer_home")
		_check(page.character_buttons.size() == 2 and page.slots[2].disabled, "原角色和未收录卡保留")
		await _shot("collection_original_pair")
		sm.data.gold = 100000
		for id in Growth.CHARACTERS:
			if not sm.owned_characters().has(id): _draw_ids([id])
		page._refresh_collection()
		await get_tree().process_frame
		_check(page.character_buttons.size() == Growth.CHARACTERS.size(), "所有配置新角色保留")
		for id in page.character_buttons:
			var slot: Button = page.character_buttons[id]
			var clip: Control = slot.get_node("PortraitClip")
			var base: TextureRect = slot.get_node("NameTieshan" if id == "tieshan" else "NameYaya")
			var supplied: bool = id in ["yufeng", "jiaopopo", "ahong", "xiluomei", "chengyan", "lanjiao"]
			var expected_size := Vector2(200,168) if supplied else Vector2(200,200)
			var expected_position := Vector2.ZERO if supplied else Vector2(0,-12)
			_check(slot.custom_minimum_size == Vector2(216,216) and clip.size == Vector2(200,168) and clip.get_child(0).size == expected_size and clip.get_child(0).position == expected_position, "用户裁图或原方卡构图:"+id)
			if supplied:
				_check(clip.get_child(0).texture.resource_path == "res://assets/ui/home_collection/portrait_"+id+".png", "使用用户头像:"+id)
			_check(base.position == Vector2(8,177) and base.size == Vector2(200,31), "原姓名底板:"+id)
			_check(not slot.has_node("RankBadge"), "角色簿不显示星级:"+id)
			page.collection_scroll.ensure_control_visible(slot)
			await get_tree().process_frame
			await _shot("collection_"+id)
			await _click(slot)
			_check(page.cards_modal.visible and page.cards_modal.character_id == id, "角色详情可打开:"+id)
			await _send_key(KEY_ESCAPE)
			_check(not page.cards_modal.visible and not page.back_button.disabled, "详情返回恢复:"+id)
		page.collection_scroll.scroll_vertical = int(page.collection_scroll.get_v_scroll_bar().max_value)
		await _shot("collection_scrolled")
		await _click(page.back_button)
		_check(not scene.get_node("Player").input_locked, "关闭恢复输入")
		await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
