extends "res://tools/tests/home_character_details.gd"

const Face = preload("res://scripts/ui/components/party_character_face.gd")

func _details_flow() -> void:
	await super._details_flow()
	sm.data["owned_characters_v1"] = ["yaya", "tieshan", "salia", "dingdang", "yufeng"]
	for id in ["salia", "dingdang", "yufeng"]: _put(id, 1, 1)
	sm.save()
	await _open_scene()
	var player = scene.get_node("Player")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().physics_frame
	await get_tree().process_frame
	await _click(ui._buttons[target])
	var page = get_tree().get_first_node_in_group("adventurer_home")
	for id in ["salia", "dingdang", "yufeng"]:
		var button: Control = page.character_buttons[id]
		var parent: Node = button.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			await get_tree().process_frame
			await get_tree().process_frame
		await _click(page.character_buttons[id])
		_check(page.cards_modal.visible and page.cards_modal.character_id == id, id + "实际入口显示详情")
		await _shot(id + "_attributes")
		await _send_key(KEY_ESCAPE)
	await _click(page.back_button)
	await get_tree().process_frame
	_check(player.can_process(), "三位角色详情退出后恢复输入")
	await _close_scene()
	if suffix != "_1280x720": return
	for id in ["yaya", "tieshan", "salia", "dingdang", "yufeng"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(470, 720)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var face := Face.new()
		viewport.add_child(face)
		face.configure(id, 1)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(viewport.get_texture().get_image().save_png(evidence.path_join(id + "_card.png")) == OK, id + "全身卡面导出")
		viewport.queue_free()
