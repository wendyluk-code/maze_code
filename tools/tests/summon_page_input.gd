extends "res://tools/tests/adventurer_home_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "召唤验收隔离用户存档")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(1280, 800)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await get_tree().create_timer(0.2).timeout
			await _walkthrough()
			await _summon_checks()
			if failures: break
	var report := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name()}, "\t"))
	print("SUMMON_PAGE: ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _summon_checks() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
	await _open_scene()
	HomePage.open_page(get_tree())
	await get_tree().process_frame
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(not page.summon_panel.visible and page.collection_scroll.visible, "默认角色簿，召唤内容隐藏")
	await _click(page.tabs[1])
	_check(page.selected_tab == 1 and page.summon_panel.visible and not page.collection_scroll.visible and not page.acquire_hint.visible, "点击召唤显示批准稿与两个按钮")
	var panel = page.summon_panel
	_check_layout(page)
	var saved := FileAccess.get_file_as_bytes(sm._active_save_path)
	for amount in [0, 999, 1000, 8999, 9000, 10000]:
		sm.data.gold = amount
		await get_tree().create_timer(0.25).timeout
		var before: Dictionary = sm.data.duplicate(true)
		_check(page.gold_counter.value_label.text == str(amount), "左上真实金币刷新 %d" % amount)
		_check(panel.single_button.disabled == (amount < 1000) and panel.ten_button.disabled == (amount < 9000), "实际页面两个按钮分别判断余额 %d" % amount)
		for item in [[panel.single_button, 1000], [panel.ten_button, 9000]]:
			page.summon_toast.dismiss()
			await _click(item[0])
			_check(page.summon_toast.visible == (amount >= item[1]), "真实鼠标只激活余额足够的按钮 %d/%d" % [amount, item[1]])
			if amount >= item[1]: _check(page.summon_toast.text == "召唤暂未开放", "点击只显示已确认占位提示")
			_check(sm.data == before and FileAccess.get_file_as_bytes(sm._active_save_path) == saved, "点击不扣金币、不发奖、不写存档")
		if amount in [0, 1000, 9000]:
			page.summon_toast.dismiss()
			get_viewport().warp_mouse(Vector2(8, 8))
			if get_viewport().gui_get_focus_owner(): get_viewport().gui_get_focus_owner().release_focus()
			await RenderingServer.frame_post_draw
			await _shot("summon_%d" % amount)
	panel.ten_button.grab_focus()
	page.summon_toast.dismiss()
	await _send_key(KEY_ENTER)
	_check(page.summon_toast.visible and sm.gold_balance() == 10000, "键盘Enter反馈且不扣金币")
	await _shot("summon_feedback")
	await _click(page.tabs[0])
	_check(not panel.visible and page.collection_scroll.visible and not page.summon_toast.visible, "切回角色簿清除反馈并恢复列表")
	await _click(page.character_buttons["yaya"])
	_check(page.cards_modal.visible and page.back_button.disabled, "原有角色详情仍可打开并禁用返回")
	await _shot("collection_details")
	await _send_key(KEY_ESCAPE)
	_check(not page.cards_modal.visible and not page.back_button.disabled, "Esc只关闭详情并恢复输入")
	await _click(page.tabs[1])
	_check(panel.visible and not panel.ten_button.disabled, "重新进入召唤恢复正确余额状态")
	await _send_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(not is_instance_valid(page) and scene.can_process(), "召唤页Esc返回同一餐厅，输入恢复")
	await _close_scene()

func _check_layout(page: CanvasLayer) -> void:
	# 设计坐标来自批准稿，不以按钮最小尺寸或其他运行时结果生成期望值。
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var fit := minf(viewport.x / 1280.0, viewport.y / 720.0)
	var offset := (viewport - Vector2(1280,720) * fit) * 0.5
	var source_scale := Vector2(1280.0/1672.0,720.0/941.0) * fit
	for item in [
		["ApprovedArtwork", Rect2(350,140,1030,454)],
		["DingdangName", Rect2(447,389,34,72)],
		["SaliaName", Rect2(980,267,34,106)],
		["YufengName", Rect2(1238,337,34,72)],
		["SingleDraw", Rect2(530,594,330,67)],
		["TenDraw", Rect2(888,594,331,67)],
		["SinglePrice", Rect2(523,668,344,31)],
		["TenPrice", Rect2(881,668,345,31)],
	]:
		var actual: Rect2 = page.summon_panel.get_node(item[0]).get_global_rect()
		var source_rect: Rect2 = item[1]
		var expected := Rect2(source_rect.position*source_scale+offset,source_rect.size*source_scale)
		_check(actual.position.distance_to(expected.position)<1 and actual.size.distance_to(expected.size)<1, "确认布局位置与尺寸 " + item[0], {"actual":str(actual),"expected":str(expected),"viewport":str(viewport)})

	_check(not page.summon_panel.get_children().any(func(child): return child is Line2D), "姓名没有连接线")
	for entry in [["DingdangName","叮\n当"],["SaliaName","萨\n莉\n亚"],["YufengName","御\n风"]]:
		var label = page.summon_panel.get_node(entry[0])
		_check(label is Label and label.text == entry[1] and label.get_child_count() == 0, "姓名原生竖排文字，无花纹子节点 " + entry[0])
	var fence: TextureRect = page.get_node("Page/ForegroundFence")
	for pair in [["DingdangName",Rect2(490,355,135,130)],["SaliaName",Rect2(730,245,160,105)],["YufengName",Rect2(1070,280,158,140)]]:
		var tag: Rect2 = page.summon_panel.get_node(pair[0]).get_global_rect().grow(4.0 * fit)
		var head: Rect2 = pair[1]
		var protected := Rect2(head.position*source_scale+offset,head.size*source_scale)
		_check(not tag.intersects(protected), "竖排姓名不遮挡角色面部 " + pair[0])
	var crystal := Rect2(Vector2(640,240)*source_scale+offset,Vector2(60,78)*source_scale)
	_check(not page.summon_panel.get_node("SaliaName").get_global_rect().intersects(crystal), "萨莉亚竖排姓名不遮挡法杖晶石")
	_check(fence.position == Vector2.ZERO and fence.size == viewport and fence.z_index == 0, "栅栏保持原位和原有适配")
	var mask: Image = fence.texture.get_image()
	for control in [page.summon_panel.single_button,page.summon_panel.ten_button,page.summon_panel.single_price,page.summon_panel.ten_price]:
		var bounds: Rect2 = control.get_global_rect()
		var left := floori((bounds.position.x-offset.x)/source_scale.x)
		var right := ceili((bounds.end.x-offset.x)/source_scale.x)
		var bottom := (bounds.end.y-offset.y)/source_scale.y
		var fence_top := float(mask.get_height())
		for x in range(left,right):
			for y in range(650,mask.get_height()):
				if mask.get_pixel(x,y).a > 0.05:
					fence_top = minf(fence_top,y)
					break
		var gap := (fence_top-bottom)*source_scale.y
		_check(gap >= 5.0*fit, "操作区与真实栅栏轮廓无重叠 " + control.name, {"clearance_pixels":gap,"viewport":str(viewport)})
