extends "res://scripts/battle/tests/bt_fx_01_scene_suite.gd"
## 真实入口及八回合继承原输入；每句检查挖空、指针、输入与事务隔离。
var lesson_evidence: Array = []
var observed_sentences: Dictionary = {}
var initial_checked := false
var pixels_checked := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/bt_guide_01")
	DirAccess.make_dir_recursive_absolute("res://output/bt_fx_01")
	super._initialize()

func guide_shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/bt_guide_01/%d_%s.png" % [root.size.x, label])

func verify_cutout_pixels() -> void:
	# 仅比较同一教学帧的遮罩开关，不跳句、不修改任何战斗状态。
	ui.guide.shade.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var original := root.get_texture().get_image()
	ui.guide.shade.show()
	await process_frame
	await RenderingServer.frame_post_draw
	var masked := root.get_texture().get_image()
	var hole: Rect2 = ui.guide.cutouts[0]
	var transform: Transform2D = ui.board.get_global_transform_with_canvas()
	var inside: Vector2i = Vector2i(transform * hole.get_center())
	var outside: Vector2i = Vector2i(transform * Vector2(300, 100))
	var lit: Color = original.get_pixelv(inside)
	var visible: Color = masked.get_pixelv(inside)
	check(absf(lit.r - visible.r) + absf(lit.g - visible.g) + absf(lit.b - visible.b) < 0.025, "真实渲染孔洞保持原亮度")
	var base: Color = original.get_pixelv(outside)
	var dark: Color = masked.get_pixelv(outside)
	check(base.get_luminance() - dark.get_luminance() > 0.1, "孔洞外实际压暗")

func read_guide() -> void:
	var guard := 0
	while is_instance_valid(ui) and ui.state == "guide_explain" and guard < 40:
		guard += 1
		var snapshot: Dictionary = ui.battle.duplicate(true)
		var sentence: int = ui.guide.sentence
		var text: String = ui.guide.sentences[sentence][0]
		var focus: String = ui.guide.focus
		check(ui.guide.explaining and ui.guide.dialog.visible, "短句对白代替常驻说明")
		check(ui.guide.cutouts.size() >= 2 and ui.guide.pointer.visible, "聚焦挖空与指示可见 " + focus)
		check(ui.guide.pointer.texture is AtlasTexture and ui.guide.pointer.texture.region == Rect2(451, 110, 352, 1016), "复用金色双尖原图区域")
		var dialog_rect: Rect2 = ui.guide.dialog.get_rect()
		for hole in ui.guide.cutouts:
			check(not dialog_rect.intersects(hole), "对白不遮挡聚焦对象 " + focus)
		var pointer_rect: Rect2 = ui.guide.pointer.get_transform() * Rect2(Vector2.ZERO, ui.guide.pointer.size)
		check(Rect2(Vector2.ZERO, ui.CANVAS).encloses(pointer_rect), "金色指针完整处于画布 " + focus)
		if focus in ["slimes", "ap", "health"]:
			for hole in ui.guide.cutouts:
				check(not pointer_rect.intersects(hole), "指针位于聚焦组外，不遮相邻对象")
		if not initial_checked:
			initial_checked = true
			if not pixels_checked:
				pixels_checked = true
				await verify_cutout_pixels()
			# 点击透明区域只能推进说明，不能执行背景业务。
			await click(ui.end_button.position + Vector2(35, 49))
			check(ui.battle == snapshot and ui.guide.sentence == sentence, "说明时背景点击不结束回合")
			await guide_key(false)
			await guide_key(true)
			# 已完成打字后的长按与重复按下也不越句。
			var after_first: int = ui.guide.sentence
			for i in range(4): await guide_key(true, true)
			await guide_key(true)
			check(ui.guide.sentence == after_first and ui.battle == snapshot, "长按、重复按下不穿透或推进业务")
			await guide_key(false)
			# 菜单暂停期间对白打字、步骤和规则状态均冻结。
			await click(ui.battle_menu.gear.position + Vector2(24, 24))
			check(paused and ui.battle_menu.is_open, "说明中可打开菜单")
			var shown: float = ui.guide.dialog._shown
			await create_timer(0.2).timeout
			check(ui.guide.dialog._shown == shown and ui.battle == snapshot, "菜单暂停对白及业务")
			await click(ui.board.get_global_transform_with_canvas().affine_inverse() * ui.battle_menu.restart_button.get_global_rect().get_center())
			await click(ui.board.get_global_transform_with_canvas().affine_inverse() * ui.battle_menu.confirmation.cancel_button.get_global_rect().get_center())
			check(not paused and ui.state == "guide_explain" and ui.battle == snapshot, "说明中取消重开恢复同句")
			# 上面的长按检查已推进一页；回到循环读取当前实际短句。
			continue
		# 第一按补全打字；若已自然打完，可能直接进入下一句。
		await guide_key(false)
		if ui.guide.dialog._shown < text.length():
			await guide_key(true)
			await guide_key(false)
		check(ui.battle == snapshot and ui.guide.sentence == sentence, "补全文字不代替操作")
		var id: String = ui.guide_key + ":" + str(sentence)
		if not observed_sentences.has(id):
			observed_sentences[id] = true
			lesson_evidence.append({"step": ui.guide_key, "sentence": sentence, "text": text, "focus": focus, "holes": ui.guide.cutouts.duplicate()})
			await guide_shot("lesson_" + id.replace(":", "_"))
		if sentence == ui.guide.sentences.size() - 1:
			await click(Vector2(40, 430))
		else:
			await guide_key(true)
			await guide_key(false)
		check(ui.battle == snapshot, "翻页不改变战斗事务 " + id)
	check(ui.state == "player_turn" and not ui.guide.explaining and ui.guide.hint_panel.visible, "对白结束开放操作，不自动出牌")
	await guide_shot("practice_" + ui.guide_key.replace(":", "_"))

func select_card(id: String) -> bool:
	var result: bool = await super.select_card(id)
	check(ui.guide.visible and not ui.guide.dialog.visible, "选牌时关闭说明，不遮完整卡面")
	if result:
		var preview_rect: Rect2 = ui._guide_rect(ui.preview, 3)
		check(ui.guide.cutouts.any(func(r: Rect2): return r.encloses(preview_rect)), "完整预览保持原亮度")
	return result

func finish() -> void:
	var file := FileAccess.open("res://output/bt_guide_01/guide_%d.json" % root.size.x, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "sentences": lesson_evidence, "user_data_dir": OS.get_user_data_dir()}, "\t"))
	file.close()
	super.finish()
