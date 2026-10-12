extends Node
## 使用真实场景、鼠标输入和实际渲染验收，不调用出牌或回合业务函数。
const Battle = preload("res://scenes/battle/yaya_battle_demo.tscn")
var battle: Control
var failures := 0
var results: Array[Dictionary] = []
var suffix := ""
var output := "res://output/battle_initiative"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_cmdline_user_args().has("--navigation-only"):
		_navigation.call_deferred()
	else:
		_run.call_deferred()

func _navigation() -> void:
	# 验收控制器留在根节点，真实 current_scene 仍由原生切场景接口管理。
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	await _pause(0.8)
	var menu := get_tree().current_scene
	var entry: Button = menu.battle_button
	var entry_position := entry.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = entry_position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
	await _pause(0.3)
	battle = get_tree().current_scene
	_check(battle.scene_file_path.ends_with("yaya_battle_demo.tscn"), "主菜单真实按钮进入战斗")
	if failures == 0 and await _until("draft"):
		await _click(Vector2(640, 638))
		if await _until("player_turn"):
			for i in range(8):
				if battle.state == "result": break
				await _click(Vector2(1242, 342))
				await _pause(4.2)
			_check(battle.state == "result", "真实主场景自然失败")
			await _pause(1.2)
			await _fresh_continue()
			await _pause(0.3)
			_check(get_tree().current_scene.scene_file_path.ends_with("start_screen.tscn"), "自然失败新按E返回主菜单")
			var returned := get_tree().current_scene
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.position = returned.battle_button.get_global_rect().get_center()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				get_viewport().push_input(event)
				await get_tree().process_frame
			await _pause(0.3)
			battle = get_tree().current_scene
			if await _until("draft"):
				await _click(Vector2(640, 638))
				if await _until("player_turn"):
					await _click(battle.battle_menu.gear.get_rect().get_center())
					await _key(KEY_DOWN)
					await _key(KEY_ENTER)
					await _key(KEY_TAB)
					await _key(KEY_ENTER)
					await _pause(3.1)
					_check(get_tree().current_scene == battle and battle.state == "result", "齿轮结束确认后失败结算等待E")
					await _fresh_continue()
					await _pause(0.3)
					_check(get_tree().current_scene.scene_file_path.ends_with("start_screen.tscn"), "主动结束新按E返回主菜单")
	var file := FileAccess.open(output + "/navigation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": results.size(), "failures": failures, "results": results}, "\t"))
	print("YAYA_NAVIGATION ", results.size(), " checks / ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await _tutorial_first()
	for resolution in [Vector2i(1280, 720), Vector2i(1152, 648)]:
		DisplayServer.window_set_size(resolution)
		get_viewport().size = resolution
		suffix = "_%dx%d" % [resolution.x, resolution.y]
		await _game(1, false)
		if failures > 0: break
	if failures == 0: await _game(2, true)
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "checks": results.size(), "results": results, "display": DisplayServer.get_name()}, "\t"))
	print("YAYA_BATTLE_ACCEPTANCE ", results.size(), " checks / ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _check(condition: bool, description: String) -> void:
	results.append({"check": description + suffix, "passed": condition})
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _until(expected: String, limit := 8.0) -> bool:
	var started := Time.get_ticks_msec()
	while battle.state != expected and Time.get_ticks_msec() - started < limit * 1000:
		await get_tree().process_frame
	var okay: bool = battle.state == expected
	_check(okay, "到达状态 " + expected)
	if okay and expected == "player_turn":
		_check(battle.player_hud.hp_label.text == str(maxi(0, battle.player_hp)) and battle.enemy_hud.hp_label.text == str(maxi(0, battle.enemy_hp)), "头像血量与当前伤害或治疗结果一致")
		_check(battle.player_hud.points == battle.action_point and battle.enemy_hud.points == battle.enemy_action_point and battle.player_hud.active and not battle.enemy_hud.active, "双方水滴与剩余行动点和回合归属一致")
	return okay

func _pause(seconds := 0.2) -> void:
	await get_tree().create_timer(seconds).timeout

func _screen(point: Vector2) -> Vector2:
	return battle.board.get_global_transform_with_canvas() * point

func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _screen(point)
	get_viewport().push_input(motion)
	await get_tree().process_frame

func _mouse(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = _screen(point)
	event.button_index = button
	event.pressed = down
	get_viewport().push_input(event)
	await get_tree().process_frame

func _click(point: Vector2) -> void:
	await _move(point)
	await _mouse(point, true)
	await _mouse(point, false)
	await _pause(0.05)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame

func _card_point(index: int) -> Vector2:
	# 重叠手牌取左侧露出部分，并使用实际旋转后的坐标。
	return battle.hand_nodes[index].get_transform() * Vector2(24, 40)

func _role_point(for_player: bool) -> Vector2:
	var role: Control = battle.player_field if for_player else battle.enemy_field
	return role.position + Vector2(role.size.x * 0.5, 18)

func _attack_gesture() -> void:
	await _move(Vector2(1050, 440))
	await _pause()
	var at := _role_point(true)
	await _move(at)
	await _mouse(at, true)
	await _move(at + Vector2(0, -30))
	await _mouse(at + Vector2(0, -30), false)

func _check_symmetry(in_battle: bool) -> void:
	var p: Vector2 = battle.player_field.position + battle.player_field.size * 0.5
	var e: Vector2 = battle.enemy_field.position + battle.enemy_field.size * 0.5
	var aligned := p.lerp(e, 0.5).is_equal_approx(Vector2(638,342)) if in_battle else is_equal_approx(p.x,e.x) and is_equal_approx(p.y+e.y,684)
	_check(aligned, "围绕荷叶中心上下镜像：" + ("战斗区" if in_battle else "准备区"))
	if in_battle:
		# 完整卡面约有6像素透明边缘；两张原图边缘在中线相接。
		_check(absf((battle.enemy_field.position.y + battle.enemy_field.size.y - 7) - (battle.player_field.position.y + 7)) < 5, "双方战斗区卡牌紧邻中线")

func _attack_cancel_checks() -> void:
	var at := _role_point(true)
	var origin: Vector2 = battle.player_field.position
	var ap: int = battle.action_point
	await _move(at)
	await _mouse(at, true)
	_check(battle.fx.aim_visible and battle.attack_selected and battle.target_highlight.visible, "按下角色立即显示出击箭头和战斗区")
	await _shot("attack_arrow")
	await _mouse(at, false)
	_check(battle.action_point == ap and not battle.player_in_battle and not battle.fx.aim_visible, "原地松手不出击")
	for offset in [Vector2(0,-15), Vector2(45,0), Vector2(0,35)]:
		await _mouse(at, true)
		await _move(at + offset)
		await _mouse(at + offset, false)
		_check(battle.player_field.position == origin and battle.action_point == ap and not battle.player_in_battle, "不足距离/横拖/下拖取消 " + str(offset))
	await _mouse(at, true)
	await _move(at + Vector2(0,-35))
	_check(battle.fx.aim_valid, "上拖35像素已经可松手")
	await _move(at)
	await _mouse(at, false)
	_check(battle.player_field.position == origin and battle.action_point == ap and not battle.player_in_battle, "越过阈值后拖回取消")
	await _mouse(at, true)
	await _move(at + Vector2(0,-35))
	await _key(KEY_ESCAPE)
	await _mouse(at + Vector2(0,-35), false)
	_check(battle.player_field.position == origin and battle.action_point == ap and not battle.fx.aim_visible, "角色拖动中Esc恢复位置且松手不提交")
	await _mouse(at, true)
	await _move(at + Vector2(0,-35))
	await _mouse(at + Vector2(0,-35), true, MOUSE_BUTTON_RIGHT)
	await _mouse(at + Vector2(0,-35), false, MOUSE_BUTTON_RIGHT)
	await _mouse(at + Vector2(0,-35), false)
	_check(battle.player_field.position == origin and battle.action_point == ap and not battle.player_in_battle and not battle.fx.aim_visible, "出击右键取消后松手不提交")

func _choose(id: String) -> void:
	await _move(Vector2(1040, 470))
	await _pause()
	var index: int = battle.hand_cards.find(id)
	_check(index >= 0, "手牌存在 " + id)
	if index < 0: return
	await _move(_card_point(index))
	await _pause()
	await _click(_card_point(index))
	await _pause(0.15)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(output + "/" + name + suffix + ".png")

func _game(first: int, teaching: bool) -> void:
	battle = Battle.instantiate()
	battle.tutorial_battle = false
	battle.player_starting_health = 10
	battle.enemy_starting_health = 5
	battle.initiative_override = first
	battle.tutorial_fixed = teaching
	add_child(battle)
	await _pause(0.55)
	await _shot("initiative_backs")
	await _pause(0.95)
	await _shot("initiative")
	for for_player in [false, true]:
		var seal: Control = battle.board.get_node("InitiativePlayer" if for_player else "InitiativeEnemy")
		var should_be_first: bool = (first == 1) == for_player
		var face: TextureRect = seal.get_node("Face")
		_check(face.texture.resource_path.ends_with("/first.png" if should_be_first else "/second.png"), "翻面牌面与真实先后手一致：" + ("我方" if for_player else "敌方"))
	if not await _until("draft"): return
	await _pause(0.5)
	_check(battle.initiative_player_first == (first == 1), "先手在换牌前确定")
	_check(battle.replace_buttons.all(func(b): return not b.visible), "未选牌不显示调整按钮")
	_check(battle.draft.find_children("*", "CheckButton", true, false).is_empty(), "无教学开关按钮")
	await _shot("draft")
	if teaching:
		var original: Array = battle.hand_cards.duplicate()
		await _click(Vector2(1034, 532))
		_check(battle.hand_cards == original and battle.replace_count == 0, "教学固定起手不可替换")
	else:
		await _click(battle.draft_cards[0].get_rect().get_center())
		_check(battle.replace_buttons[0].visible and not battle.draft_cards[0].get_node("Glow").visible and battle.draft_cards[0].scale.x > 1.0, "点击卡片放大且不显示选中框")
		await _click(battle.draft_cards[4].get_rect().get_center())
		_check(battle.replace_buttons.filter(func(b): return b.visible).size() == 1 and battle.replace_buttons[4].visible, "切换卡片仅当前按钮可见")
		_check(not battle.draft_cards[0].get_node("Glow").visible and not battle.draft_cards[4].get_node("Glow").visible and battle.draft_cards[4].scale.x > 1.0, "切换卡片只放大当前牌且无选中框")
		await _shot("draft_selected")
		var old: String = battle.hand_cards[4]
		await _click(Vector2(1034, 532))
		if not await _until("draft"): return
		_check(battle.replace_count == 1 and battle.hand_cards[4] != old, "原位换牌且计数增加")
		await _click(battle.draft_cards[0].get_rect().get_center())
		_check(not battle.draft_cards[4].get_node("Glow").visible and not battle.replace_buttons[4].visible, "换牌后改选不会遗留选中框或按钮")
		await _click(battle.draft_cards[4].get_rect().get_center())
		for i in range(2):
			await _click(Vector2(1034, 532))
			if not await _until("draft"): return
		var fixed: Array = battle.hand_cards.duplicate()
		await _click(Vector2(1034, 532))
		_check(battle.replace_count == 3 and battle.hand_cards == fixed, "换牌三次后拒绝第四次")
		_check(battle.replace_buttons.all(func(b): return not b.visible), "次数用完后隐藏调整按钮")
	await _click(Vector2(640, 638))
	await _pause(0.25)
	await _shot("gather")
	if not await _until("player_turn"): return
	_check(battle.hand_cards.size() == 5 and not battle.hand_cards.has("芽芽"), "五张能力牌入手，角色不重复入手")
	_check(not battle.end_button.disabled, "我方回合可结束")
	await _pause(0.3)
	var player_corner: Rect2 = battle.player_hud.get_rect()
	var enemy_corner: Rect2 = battle.enemy_hud.get_rect()
	_check(player_corner.position.x == enemy_corner.position.x and is_equal_approx(player_corner.get_center().y + enemy_corner.get_center().y, 720), "左上左下头像面板对称")
	_check(enemy_corner.end.y < battle.preview.position.y and player_corner.position.y > battle.preview.position.y + battle.preview.size.y, "头像区域不遮挡大图预览")
	_check(battle.player_hud.get_node("Avatar").size == Vector2(84,84) and battle.enemy_hud.get_node("Avatar").size == Vector2(84,84), "头像实际绘制尺寸受控，不使用源图最小尺寸撑破角落")
	_check(battle.player_hud.fill == [1.0, 1.0] and battle.player_hud.hp_label.text == "10", "开局两枚水滴充满且头像生命为10")
	_check_symmetry(false)
	_check(not battle.player_in_battle and not battle.enemy_in_battle, "开场角色位于准备区，战斗区为空")
	for role in [battle.player_field, battle.enemy_field]:
		var art: TextureRect = role.get_node("Portrait")
		_check(not art.texture is AtlasTexture and art.texture.resource_path.ends_with("yaya.png") or teaching and role == battle.enemy_field and art.texture.resource_path.ends_with("small_spoon_person.png"), "角色使用完整源纹理，不裁剪头像")
	await _shot("board")
	if teaching:
		_check(battle.enemy_step == 1 and battle.enemy_form == "小小掌勺人", "敌方先手自动出牌后交还输入")
		var ap: int = battle.action_point
		await _choose("热锅协作")
		_check(battle.hand_expanded and battle.selected >= 0 and battle.action_point == ap and battle.toast.visible, "缺少协作条件仍可展开读牌且不消耗")
		await _choose("战地小厨")
		await _click(_role_point(true))
		if not await _until("player_turn"): return
		await _click(Vector2(1242, 342))
		if not await _until("player_turn"): return
		_check(battle.player_form == "战地小厨" and not battle.player_in_battle and battle.cook_count == 0, "战地小厨留在准备区，回合结束不烹饪")
		await _attack_gesture()
		if not await _until("player_turn"): return
		var after_attack_hp: int = battle.enemy_hp
		await _attack_gesture()
		_check(battle.player_in_battle and battle.action_point == 1 and battle.enemy_hp == after_attack_hp and battle.cook_count == 1, "仍有行动点时重复出击不再扣点或伤害")
		await _click(Vector2(1242, 342))
		if not await _until("player_turn"): return
		_check(battle.cook_count == 2 and battle.player_in_battle, "战地小厨出击留场后，回合结束烹饪一次")
		# 不行动直至自然失败，检查结算不会被下一回合覆盖。
		for i in range(5):
			if battle.state == "result": break
			await _click(Vector2(1242, 342))
			await _pause(4.2)
		_check(battle.state == "result" and battle.player_hp <= 0, "自然失败进入结算")
		await _pause(1)
		await _shot("defeat")
	else:
		await _attack_cancel_checks()
		await _choose("温火照料")
		_check(battle.selected >= 0 and battle.hand_expanded and not battle.preview.visible and not battle.target_highlight.visible, "点击手牌展开并放大当前牌，不叠预览或选框")
		await _shot("selected")
		var hand_count: int = battle.hand_cards.size()
		var ap: int = battle.action_point
		await _key(KEY_ESCAPE)
		_check(battle.selected == -1 and battle.action_point == ap, "Esc取消不消耗")
		await _choose("温火照料")
		await _click(_role_point(false))
		_check(battle.hand_cards.size() == hand_count and battle.action_point == ap, "治疗不能提交给敌方")
		await _mouse(Vector2(1020, 280), true, MOUSE_BUTTON_RIGHT)
		_check(battle.selected == -1 and not battle.target_highlight.visible, "右键取消目标")
		await _choose("温火照料")
		var source := _card_point(battle.selected)
		await _mouse(source, true)
		await _move(Vector2(1020, 280))
		await _mouse(Vector2(1020, 280), false)
		await _pause()
		_check(battle.selected == -1 and battle.hand_cards.size() == hand_count and battle.action_point == ap, "非法拖放回弹且不扣牌/行动点")
		await _choose("小小掌勺人")
		source = _card_point(battle.selected)
		await _mouse(source, true)
		await _move(_role_point(true))
		await _shot("drag")
		await _mouse(_role_point(true), false)
		if not await _until("player_turn"): return
		_check(battle.player_form == "小小掌勺人" and battle.action_point == 1 and battle.hand_cards.size() == hand_count - 1, "拖放形态牌直接生效一次")
		_check(battle.player_hp == 10 and battle.player_max_hp == 10 and battle.player_hud.points == 1, "角色变形不改牌手生命并消耗一滴水")
		_check(not battle.player_in_battle and battle.player_field.get_node("Portrait").texture.resource_path.ends_with("small_spoon_person.png"), "准备区变形仍在原区且显示完整形态卡")
		await _attack_gesture()
		if not await _until("player_turn"): return
		_check(battle.enemy_hp == 3 and battle.action_point == 0 and battle.cook_count == 1, "短距离上拖出击，敌方5降到3，扣一点且烹饪一次")
		_check(battle.player_in_battle and battle.player_field.position == battle._role_position(true, true), "角色出击后留在战斗区")
		await _shot("deployed")
		await _choose("温火照料")
		_check(battle.hand_expanded and battle.hand_cards.size() == hand_count - 1 and battle.action_point == 0, "无行动点仍可展开读牌但不会自动出牌")
		await _click(Vector2(1242, 342))
		await _pause(0.15)
		_check(battle.enemy_hud.active and not battle.player_hud.active and battle.enemy_hud.points == 2, "敌方回合开始补满两滴并切换头像高亮")
		await _shot("enemy_turn")
		await _click(Vector2(1242, 342))
		if not await _until("player_turn"): return
		_check(battle.enemy_step == 1 and battle.round_number == 2 and battle.action_point == 2, "结束回合连点不会重复敌方行动")
		_check(battle.enemy_hud.points == 1 and battle.enemy_hud.hp_label.text == "3", "敌方形态牌扣除一滴且头像显示受伤后的形态生命")
		_check(battle.deck.size() == 4 and battle.hand_cards.size() == hand_count, "新回合抽牌并重排")
		# 点选后直接结束，验证不再被选中状态卡住。
		await _choose("温火照料")
		await _click(Vector2(1242, 342))
		if not await _until("player_turn"): return
		_check(battle.player_hp == 8 and battle.selected == -1 and not battle.hand_expanded, "有选牌仍可结束，敌方攻击后清除选择与展开")
		_check(battle.enemy_in_battle and battle.player_in_battle, "敌方自动出击也进入战斗区")
		_check_symmetry(true)
		await _shot("opposed")
		await _choose("温火照料")
		await _click(_role_point(true))
		if not await _until("player_turn"): return
		_check(battle.player_hp == 10 and battle.action_point == 1 and not battle.hand_expanded, "治疗恢复2生命并收起手牌")
		await _attack_gesture()
		if not await _until("player_turn"): return
		await _click(Vector2(1242, 342))
		if not await _until("player_turn"): return
		await _attack_gesture()
		if not await _until("player_turn"): return
		await _click(Vector2(1242, 342))
		if not await _until("player_turn"): return
		await _attack_gesture()
		if not await _until("result"): return
		await _pause(1.4)
		_check(battle.enemy_hp <= 0 and battle.board.has_node("Result"), "自然胜利且出现结算蒙层")
		await _shot("victory")
	battle.queue_free()
	await get_tree().process_frame

func _tutorial_first() -> void:
	for override in [0, 2]:
		battle = Battle.instantiate()
		battle.initiative_override = override
		add_child(battle)
		if not await _until("draft"): return
		_check(battle.tutorial_battle and battle.initiative_player_first, "默认教学玩家先手且不受敌方覆盖值影响")
		_check(not battle.tutorial_fixed, "教学先手不锁定起手调整")
		await _click(battle.draft_cards[1].get_rect().get_center())
		_check(battle.replace_buttons[1].visible, "教学关支持选牌调整")
		await _click(Vector2(640, 638))
		if not await _until("player_turn"): return
		_check(battle.enemy_step == 0, "教学确认后玩家先行动")
		battle.queue_free()
		await get_tree().process_frame

func _fresh_continue() -> void:
	for down in [false, true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.pressed = down
		get_viewport().push_input(event)
		await get_tree().process_frame
