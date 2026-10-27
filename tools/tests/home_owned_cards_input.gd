extends "res://tools/tests/adventurer_home_input.gd"
const Art := preload("res://scripts/ui/components/home_card_art.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离用户存档")
	if failures == 0:
		_persistence()
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _walkthrough()
			await _collection_ui()
			if failures: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name()}, "\t"))
	print("HOME_OWNED_CARD_ART ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _persistence() -> void:
	_seed()
	var key: String = Art.COLLECTION_KEY
	var counts: Dictionary = sm.owned_character_card_counts()
	_check(counts.size() == 6 and counts["yaya/warm_care"] == 2 and sm.data.has(key), "入队事务保存角色牌与已确认首批手牌数量")
	_check(sm.save(), "收藏数据保存成功")
	sm.load_data()
	_check(sm.owned_character_card_counts() == counts, "数量保存重读一致")
	sm.data[key] = {"yaya/yaya": 1, "yaya/warm_care": 3, "yaya/hotpot_collab": 0, "tieshan/tieshan": 1}
	_check(sm.save(), "保存部分拥有与零数量样例")
	sm.load_data()
	var partial: Array = Art.owned_for_character("yaya", sm.owned_character_card_counts(), sm.departure_state().party)
	_check(partial.size() == 2 and partial[1].id == "yaya/warm_care" and partial[1].quantity == 3, "读取实际拥有数量，未拥有与零数量不补齐")
	_check(Art.owned_for_character("tieshan", sm.owned_character_card_counts(), []).is_empty(), "未收录角色不暴露拥有列表")
	sm.data[key] = {}
	sm.save(); sm.load_data()
	_check(sm.owned_character_card_counts().is_empty(), "明确空收藏保存重读后不自动填满")
	sm.data[key] = {"yaya/warm_care": -1}
	sm.save(); sm.load_data()
	_check(sm.owned_character_card_counts().is_empty() and sm.data[key]["yaya/warm_care"] == -1, "坏数量不变成奖励，保留原数据可诊断")
	sm.data.erase(key)
	sm.save()
	var old_bytes := FileAccess.get_file_as_bytes(sm._active_save_path)
	sm.load_data()
	_check(sm.owned_character_card_counts() == counts and sm.data.has(key), "缺字段旧档只迁移已确认首批记录")
	_check(FileAccess.get_file_as_bytes(sm._active_save_path) == old_bytes, "旧档读取迁移不自动写盘")
	sm.load_data()
	_check(sm.owned_character_card_counts() == counts, "重复迁移不累加卡牌数量")
	_seed("agreement")
	var before: Dictionary = sm.data.duplicate(true)
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	var result: Dictionary = sm.advance_departure("agreement")
	_check(not result.success and sm.data == before and not sm.data.has(key), "入队保存失败回滚新增收藏字段")
	sm._active_save_path = save_path
	_check(sm.advance_departure("agreement").success and sm.owned_character_card_counts() == counts, "入队重试只记录一份首批卡牌")

func _collection_ui() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
	await _open_scene()
	var baseline: Dictionary = sm.data.duplicate(true)
	var saved := FileAccess.get_file_as_bytes(sm._active_save_path)
	HomePage.open_page(get_tree())
	await get_tree().process_frame
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(page.character_buttons.size() == 2 and get_tree().get_nodes_in_group("home_wanderer").is_empty() and get_tree().get_nodes_in_group("home_greeter").is_empty(), "仅静态立绘列表，无散步或打招呼角色")
	await get_tree().create_timer(1.6).timeout
	_check(page.selected_tab == 0 and page.tabs[0].selected and page.tabs[1].scale.x < page.tabs[0].scale.x, "默认角色簿选中，其余木牌缩小")
	_check(page.tabs[0].get_theme_color("font_color") == Color("#9a6b2f"), "选中木牌字体金色")
	_check(page.slots.size() == 16 and page.collection_grid.columns == 4, "列表4列共16格")
	_check(page.slots.slice(2).all(func(slot): return slot.disabled), "14个未收录缺省格不可点击")
	var row_two: Rect2 = page.slots[4].get_global_rect()
	var window: Rect2 = page.collection_scroll.get_global_rect()
	var second_row_visible := window.end.y - row_two.position.y
	_check(absf(second_row_visible / row_two.size.y - 0.5) < 0.01, "首屏完整1行加第2行一半")
	_check(is_equal_approx(row_two.size.x, row_two.size.y), "角色格为正方形")
	var fence: TextureRect = page.get_node("Page/ForegroundFence")
	var background: TextureRect = page.get_node("Page/Background")
	_check(fence.texture.resource_path.ends_with("home_collection/fence_foreground.png") and fence.stretch_mode == background.stretch_mode and fence.get_global_rect() == background.get_global_rect(), "透明栅栏与背景同尺寸同适配")
	_check(fence.get_index() > page.design.get_index() and page.cards_modal.get_canvas_layer_node().layer > page.layer, "栅栏覆盖主页面且详情使用更高的独立画布")
	_check(page.design.get_node("HeaderLeaf").texture.resource_path.ends_with("home_collection/header_leaf.png") and page.slots[2].get_node("CardMissing").texture.resource_path.ends_with("home_collection/card_missing.png"), "页眉与缺省卡使用设计稿真实切片")
	await _shot("collection_top")
	var wheel := InputEventMouseButton.new()
	wheel.position = window.get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	for index in 24: get_viewport().push_input(wheel)
	wheel = wheel.duplicate()
	wheel.pressed = false
	get_viewport().push_input(wheel)
	await get_tree().process_frame
	_check(page.collection_scroll.scroll_vertical > 0 and page.slots[15].get_global_rect().end.y <= window.end.y + 1, "鼠标滚轮可查看末行全部角色格")
	await _shot("collection_bottom")
	await _click(page.tabs[1])
	_check(page.selected_tab == 1 and page.acquire_hint.visible and not page.collection_scroll.visible, "召唤页签切换与未开放状态")
	await _click(page.tabs[0])
	page.collection_scroll.scroll_vertical = 0
	await get_tree().process_frame
	_check(page.collection_scroll.visible and page.tabs[0].selected, "返回角色簿列表")
	var yaya = page.character_buttons["yaya"]
	# 重现旧页面的前景层级，确保弹窗不依赖背景子节点全部为z=0。
	page.tabs[0].z_index = 3
	page.tabs[1].z_index = 3
	fence.z_index = 4
	await RenderingServer.frame_post_draw
	var undimmed := get_viewport().get_texture().get_image()
	await _click(yaya)
	var modal = page.cards_modal
	_check(modal.visible and modal.cards.size() == 5 and modal.hand_cards.size() == 4, "芽芽实际点击打开1角色牌加4种已获得手牌")
	_check(modal.role_card.texture.resource_path == "res://assets/ui/battle/cards/yaya/yaya.png", "固定角色牌直接引用完整原图")
	_check(modal.quantity_labels[1].text == "x2" and modal.strip.get_child_count() == 4, "温火照料重复数量显示x2，只占一格")
	_check(modal.previous_button.disabled and modal.next_button.disabled, "四种手牌一屏完整显示，无须滚动")
	await RenderingServer.frame_post_draw
	await _shot("yaya_five_cards")
	var dimmed := get_viewport().get_texture().get_image()
	for point in [Vector2(43, 206), Vector2(230, 665), Vector2(1100, 690), Vector2(5, 5)]:
		var pixel := Vector2i(page.design.get_global_transform() * point)
		var before_color := undimmed.get_pixelv(pixel)
		var after_color := dimmed.get_pixelv(pixel)
		_check(after_color.get_luminance() < before_color.get_luminance() * 0.65, "详情遮罩实际压暗页签/栅栏/角落 %s" % pixel)

	_check_cards(modal)
	var frozen: Rect2 = modal.role_card.get_global_rect()
	await _drag(modal, Vector2(-180, 0), false)
	_check(modal.card_index == 0 and modal.strip.position.x == 0 and modal.role_card.get_global_rect() == frozen, "一屏五张不滑出空白，角色牌始终冻结")
	await _click(page.back_button)
	_check(modal.visible and is_instance_valid(page), "蒙层拦截下层返回")
	await _send_key(KEY_ESCAPE)
	_check(not modal.visible and yaya.has_focus(), "Esc只关闭卡牌层并恢复角色焦点")
	await _click(page.character_buttons["tieshan"])
	_check(modal.cards.size() == 1 and modal.hand_cards.is_empty() and modal.role_card.visible, "铁山只有已获得角色牌，不虚构手牌")
	await _shot("tieshan_role_only")
	await _click(modal._close_button)
	_check(not modal.visible and not page.back_button.disabled, "关闭恢复下层输入")
	# 用实际拥有记录验证子集，随后恢复，样例不保存到用户存档。
	sm.data[Art.COLLECTION_KEY] = {"yaya/yaya": 1, "yaya/warm_care": 3, "yaya/hotpot_collab": 0}
	await _click(yaya)
	_check(modal.cards.size() == 2 and modal.hand_cards[0].id == "yaya/warm_care" and modal.quantity_labels[0].text == "x3", "页面读取拥有子集与真实数量，拒绝按目录全部展示")
	await _shot("owned_subset")
	await _click(modal._close_button)
	sm.data = baseline.duplicate(true)
	await _click(yaya)
	# 多于四种手牌只用明确测试样例，不加入正式目录或存档。
	var sample: Array[Dictionary] = Art.owned_for_character("yaya", sm.owned_character_card_counts(), ["yaya"])
	for index in 2:
		var item: Dictionary = sample[index + 1].duplicate(true)
		item.id = "test_only_%d" % index
		sample.append(item)
	modal.present("yaya", sample)
	frozen = modal.role_card.get_global_rect()
	await _drag(modal, Vector2(-180, 0), false)
	_check(modal.card_index == 1 and modal.role_card.get_global_rect() == frozen, "超过四种手牌鼠标左滑，角色牌不移动")
	await _drag(modal, Vector2(180, 0), true)
	_check(modal.card_index == 0 and modal.role_card.get_global_rect() == frozen, "触屏右滑还原，角色牌不移动")
	await _drag(modal, Vector2(15, 110), false)
	_check(modal.card_index == 0, "轻触竖拖不翻页")
	await _click(modal.next_button)
	_check(modal.card_index == 1, "右箭头翻页")
	for index in 5: await _send_key(KEY_RIGHT)
	_check(modal.card_index == 2 and modal.next_button.disabled, "末端只滚动到最后四格，没有尾部空白")
	await get_tree().create_timer(0.25).timeout
	_check(modal.role_card.get_global_rect() == frozen, "翻到底角色牌仍固定最左")
	await _shot("overflow_fixture")
	for index in 4:
		await _send_key(KEY_TAB)
		_check(modal.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Tab焦点不离开蒙层")
	var duplicate: Array[Dictionary] = [sample[0], sample[1], sample[1]]
	modal.present("yaya", duplicate)
	_check(modal.hand_cards.size() == 1 and modal.quantity_labels[0].text == "x2", "重复ID合并到一张图与数量")
	var empty_cards: Array[Dictionary] = []
	modal.present("yaya", empty_cards)
	_check(not modal.role_card.visible and modal.hand_cards.is_empty(), "空列表不残留上个角色卡图")
	modal.close_modal()
	_check(sm.data == baseline and FileAccess.get_file_as_bytes(sm._active_save_path) == saved, "查看与滚动不改变拥有数据或存档")
	await _click(page.back_button)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("home_greeter").is_empty() and scene.can_process(), "返回释放角色并恢复餐厅")
	await _close_scene()

func _check_cards(modal: Control) -> void:
	var right_edge: float = modal.viewport_area.get_global_rect().end.x
	_check(modal.role_card.get_global_rect().end.x < modal.viewport_area.get_global_rect().position.x, "冻结列与滚动列互不覆盖")
	for slot in modal.strip.get_children():
		var card: TextureRect = slot.get_child(0)
		_check(card.texture is Texture2D and not card.texture is AtlasTexture and card.get_child_count() == 0, "直接显示完整素材，不拼卡框或文字")
		_check(card.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and card.get_global_rect().end.x <= right_edge + 0.1, "原图等比，四格手牌同屏完整可见")

func _drag(modal: Control, delta: Vector2, touch: bool) -> void:
	var start: Vector2 = modal.viewport_area.get_global_transform_with_canvas() * Vector2(450, 170)
	var end: Vector2 = start + delta * modal.design.scale.x
	if touch:
		var down := InputEventScreenTouch.new()
		down.index = 0; down.position = start; down.pressed = true
		get_viewport().push_input(down)
		var motion := InputEventScreenDrag.new()
		motion.index = 0; motion.position = end; motion.relative = end - start
		get_viewport().push_input(motion)
		var up := InputEventScreenTouch.new()
		up.index = 0; up.position = end
		get_viewport().push_input(up)
	else:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = start
		get_viewport().push_input(down)
		var motion := InputEventMouseMotion.new()
		motion.position = end; motion.relative = end - start; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT; up.position = end
		get_viewport().push_input(up)
	await get_tree().create_timer(0.25).timeout
