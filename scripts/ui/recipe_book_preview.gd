extends Control
## 独立设计预览：只读素材清单，不读取或写入玩家经营状态。
const Book := preload("res://scripts/ui/components/recipe_book_panel.gd")
var book: Control
var checks: Array = []
var failures := 0
var evidence := "res://output/recipe_book_preview"

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/maps/restaurant_map.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reopen := SproutButton.new()
	reopen.configure("打开食谱预览").set_icon_visible(false)
	add_child(reopen)
	reopen.position = Vector2(24, 24)
	book = Book.new()
	add_child(book)
	reopen.pressed.connect(func(): book.show())
	book.closed.connect(func(): reopen.grab_focus())
	book.set_recipes(_data())
	if "--verify-recipe" in OS.get_cmdline_user_args(): _verify.call_deferred()

func _texture(id: String) -> Texture2D:
	return load("res://output/food_icons_20261015/icons/" + id + ".png")

func _data() -> Array:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://output/food_icons_20261015/manifest.json"))
	var combos: Array = JSON.parse_string(FileAccess.get_file_as_string("res://output/food_icons_20261015/recipe_indices.json"))
	var result: Array = []
	var effects := ["恢复少量体力，适合探索前食用。", "缓解燥热，让旅途更加轻松。", "增加饱腹感，帮助持续探索。"]
	for index in combos.size():
		var combo: Array = combos[index]
		var recipe: Dictionary = manifest[int(combo[2])]
		var ingredients: Array = []
		for i in 2:
			var item: Dictionary = manifest[int(combo[i])]
			ingredients.append({"id": item.id, "name": item.name, "quantity": 1, "icon": _texture(item.id), "source": "获取：迷宫探索 · 战斗掉落" if i == 0 else "获取：迷宫探索 · 野外采集"})
		if index == 0:
			ingredients.append({"id": "amber_sugar", "name": "琥珀糖", "quantity": 1, "icon": _texture("amber_sugar"), "source": "获取：商店购买"})
		result.append({"nature": Book.CATEGORIES[1 + index % 5], "name": recipe.name, "icon": _texture(recipe.id), "effect": effects[index % effects.size()], "gold": 5 + index, "ingredients": ingredients})
	return result

func _check(ok: bool, message: String) -> void:
	checks.append({"passed": ok, "name": message})
	if not ok: failures += 1

func _settle() -> void:
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw

func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(evidence.path_join(file + ".png"))

func _move(pos: Vector2) -> void:
	get_viewport().warp_mouse(pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	await _settle()

func _click(target: Control) -> void:
	var pos := target.get_global_rect().get_center()
	await _move(pos)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()

func _verify() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		get_window().size = resolution
		book.show()
		book.scroll.scroll_vertical = 0
		await _settle()
		await _move(Vector2(5,5))
		var suffix := "%dx%d" % [resolution.x, resolution.y]
		_check(book.rows.size() == 14, "14道占位料理 " + suffix)
		_check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(book.panel.get_global_rect()), "面板不越界 " + suffix)
		_check(is_equal_approx(book.rows[0].size.y, book.rows[1].size.y), "两种与三种食材等高 " + suffix)
		_check(is_equal_approx(book.ingredient_targets[0].global_position.y, book.ingredient_targets[2].global_position.y), "三食材横排 " + suffix)
		await _capture("page_" + suffix)
		await _move(book.dish_targets[0].get_global_rect().get_center())
		_check(not book.hint.visible, "料理不再弹出悬停说明 " + suffix)
		_check(book.rows[0].find_child("DishEffect", true, false).visible, "功效常驻显示 " + suffix)
		await _capture("effect_" + suffix)
		await _move(book.ingredient_targets[0].get_global_rect().get_center())
		_check(book.hint.visible and book.hint_text.text.contains("获取方式"), "真实悬停食材 " + suffix)
		await _capture("source_" + suffix)
		await _move(Vector2(5,5))
		_check(not book.hint.visible, "移开隐藏说明 " + suffix)
		book.scroll.scroll_vertical = 9999
		await _settle()
		_check(book.rows[-1].get_global_rect().end.y <= book.scroll.get_global_rect().end.y + 2, "末条食谱可浏览 " + suffix)
		await _capture("last_" + suffix)
		for category in range(1, 6):
			var tab_rect: Rect2 = book.tabs.get_tab_rect(category)
			var pos: Vector2 = book.tabs.global_position + tab_rect.get_center()
			await _move(pos)
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.position = pos
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				Input.parse_input_event(click)
				await get_tree().process_frame
			await _settle()
			_check(book.tabs.current_tab == category and book.rows.size() == (3 if category < 5 else 2), "筛选 " + Book.CATEGORIES[category] + suffix)
			await _capture("category_%d_" % category + suffix)
		book.tabs.current_tab = 0
		await _settle()
		_check(book.rows.size() == 14, "全部恢复14道 " + suffix)
		await _click(book.close_button)
		_check(not book.visible and not book.hint.visible, "鼠标关闭及清理 " + suffix)
		book.show()
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		Input.parse_input_event(key)
		await _settle()
		_check(not book.visible, "Esc关闭 " + suffix)
		key.pressed = false
		Input.parse_input_event(key)
	var report := FileAccess.open(evidence.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": failures, "checks": checks}, "\t"))
	print("RECIPE_PREVIEW: ", checks.size(), " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
