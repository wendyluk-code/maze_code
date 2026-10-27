extends "res://tools/tests/elder_01_state.gd"
const MazeScene := preload("res://scenes/maze_entry.tscn")
const Transition := preload("res://scripts/ui/components/scene_transition.gd")
var maze: Node2D
var evidence := ""
var suffix := ""
var held_keys: Array = []

func _run() -> void:
	sm = get_node("/root/SaveManager")
	evidence = _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(evidence)
	_check(_isolation(), "实际用户目录隔离")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await get_tree().process_frame
			await _walkthrough()
			if failures: break
	_finish()

func _open_maze(wood := 15) -> void:
	_seed(wood)
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.12).timeout
	_check(maze._entry_ready and not maze.player.input_locked, "实际迷宫就绪")
	_check(not maze.backpack_entry.visible, "未获得背包时隐藏入口")
	maze.camera.snap_to_target()

func _close_maze() -> void:
	if is_instance_valid(maze):
		maze.queue_free()
		await get_tree().process_frame
	maze = null

func _key_event(key: int, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _key(key: int) -> void:
	_key_event(key, true)
	await get_tree().process_frame
	_key_event(key, false)
	await get_tree().process_frame

func _click(control: Control) -> void:
	await RenderingServer.frame_post_draw
	await _click_point(control.get_global_rect().get_center())

func _click_point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(evidence.path_join(name+suffix+".png")) == OK, "实际渲染截图：" + name + suffix)

func _dialog_lines() -> void:
	var elder = maze.elder
	var limit := 0
	while elder.dialog.visible and limit < 8:
		await _key(KEY_E)
		limit += 1
	_check(limit < 8, "逐句对白有限结束")

func _interact() -> void:
	await _key(KEY_E)
	await get_tree().create_timer(0.48).timeout

func _restored() -> void:
	await get_tree().create_timer(0.5).timeout
	_check(maze.elder.phase == "idle" and not maze.player.input_locked and maze.player.is_physics_processing() and maze.camera.is_processing(), "恢复原移动与相机跟随")

func _walkthrough() -> void:
	await _open_maze()
	var elder = maze.elder
	maze.player.position = Roads.SPAWN
	maze.camera.snap_to_target()
	await get_tree().create_timer(0.05).timeout
	_check(not elder.prompt.visible, "远距提示隐藏")
	elder.interact()
	_check(elder.phase == "idle", "鼠标处理重查距离拒绝远处")
	# 从石门按实际方向键沿已存在道路到红圈，不能用NPC脚底代替玩家可走站位。
	for point in [Vector2(1061,188),Vector2(995,225),Vector2(933,269),Vector2(860,295),Vector2(790,326),Vector2(725,369),Vector2(688,396),Vector2(741,414),Vector2(755,448),Vector2(786,481),NEAR]:
		await _move_to(point)
	await get_tree().create_timer(0.12).timeout
	_check(elder.prompt.visible and elder.position == Elder.POSITION and Roads.is_walkable(maze.player.position), "红圈路边可达且靠近显示E")
	_check(elder.sprite.sprite_frames.get_frame_count("sit") == 8 and elder.sprite.is_playing(), "8帧坐姿动画真实播放")
	var duration := 0.0
	for i in 8: duration += elder.sprite.sprite_frames.get_frame_duration("sit", i)
	_check(is_equal_approx(duration,2.0), "批准2秒循环时长")
	var frame: int = elder.sprite.frame
	await _shot("elder_near_frame_a")
	await get_tree().create_timer(0.38).timeout
	_check(elder.sprite.frame != frame, "动画帧实际变化")
	await _shot("elder_near_frame_b")
	# 地图模态消费E，老者不能抢走地图或解锁它。
	await _click(maze.map_ui.mini_button)
	await RenderingServer.frame_post_draw
	_check(maze.map_ui.expanded and not elder.prompt.visible, "地图打开隐藏老者提示")
	await _key(KEY_E)
	_check(maze.map_ui.expanded and elder.phase == "idle" and maze.player.input_locked, "地图E不得触发老者")
	await _key(KEY_ESCAPE)
	_check(not maze.map_ui.expanded and not maze.player.input_locked, "地图取消恢复输入")
	# 聚焦中取消，旧Tween回调不得重新打开对白。
	await _key(KEY_E)
	await _key(KEY_ESCAPE)
	await _restored()
	_check(not elder.dialog.visible and sm.elder_firewood_state().status == "inactive", "聚焦取消隔离旧回调")
	await _interact()
	await _key(KEY_ESCAPE)
	await _restored()
	_check(not elder.dialog.visible and sm.elder_firewood_state().status == "inactive", "首句对白Esc取消不写任务且可重开")
	# 按住E进入与echo不能跳过对白，须松键再新按。
	_key_event(KEY_E,true)
	await get_tree().create_timer(0.5).timeout
	_key_event(KEY_E,true,true)
	await get_tree().process_frame
	_check(elder.phase == "intro" and elder.dialog._line_idx == 0 and not elder.choice.visible, "长按与重复事件不跳过对白")
	_key_event(KEY_E,false)
	await get_tree().process_frame
	await _key(KEY_E)
	_check(elder.dialog.dialog_text.text == Elder.INTRO[0] and elder.dialog.speaker_name.text == "白虎爷爷", "首句准确对白与头像")
	_check(not maze.camera.is_processing() and maze.player.input_locked and not maze.player.is_physics_processing(), "聚焦停用跟随与移动")
	var focused: Vector2 = maze.camera.global_position
	await get_tree().create_timer(0.15).timeout
	_check(maze.camera.global_position.distance_to(focused) < 0.01, "镜头不与跟随竞争")
	await _shot("intro_line_1")
	await _key(KEY_E)
	await _key(KEY_E)
	_check(elder.dialog.dialog_text.text == Elder.INTRO[1], "第二句准确对白")
	await _shot("intro_line_2")
	await _key(KEY_E)
	_check(elder.phase == "accept_choice" and elder.choice.visible and not elder.dialog.visible, "两句后才出现确认")
	_check(elder.choice.confirm_button.text == "好的", "接取按钮文案好的")
	await _shot("accept_choice")
	var before := JSON.stringify(sm.data)
	await _click_point(Vector2(10,620))
	_check(elder.phase == "accept_choice" and JSON.stringify(sm.data) == before, "鼠标蒙层不透传不接取")
	await _click(elder.choice.cancel_button)
	await _restored()
	_check(JSON.stringify(sm.data) == before, "暂时不了不写任务")
	# 重开；接受按钮只有单一连接，失败后仍可重试。
	await _click(elder.prompt.button)
	await get_tree().create_timer(0.5).timeout
	await _dialog_lines()
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _click(elder.choice.confirm_button)
	_check(elder.phase == "accept_choice" and sm.elder_firewood_state().status == "inactive", "接取保存失败保留确认且不接任务")
	sm._active_save_path = path
	await _click(elder.choice.confirm_button)
	_check(elder.phase == "restoring" and sm.elder_firewood_state().status == "active" and sm.elder_firewood_state().unread, "好的直接接取且不弹主角回复")
	_check(not elder.dialog.visible, "接取后对白框关闭")
	await _restored()
	_check(sm.elder_firewood_state().unread, "自动显示和对白结束不清未读")
	var tracker = maze.task_tracker
	await get_tree().create_timer(0.3).timeout
	await _click(tracker._task_button)
	await get_tree().create_timer(0.3).timeout
	_check(tracker._collection_task.visible and tracker._exploration_task.visible and tracker._collection_status.text == "15/12", "收集与探索独立显示且接前库存计入")
	_check(not sm.elder_firewood_state().unread, "主动展开清未读")
	_check(tracker._collection_name.text == "木材" and tracker._collection_task.find_child("woodIcon", true, false) != null, "收集行复用木材图标与名称布局")
	await _shot("current_tasks_15")
	sm.data.inventory.wood = 0
	_check(sm.save(), "活动收集任务零木材准备")
	await get_tree().create_timer(0.3).timeout
	_check(tracker._collection_status.text == "0/12", "零库存进度刷新")
	await _shot("current_tasks_0")
	maze.player.position = _site_approach(sm.DigCatalog.all()[0])
	maze.camera.snap_to_target()
	await get_tree().create_timer(0.05).timeout
	await _key(KEY_E)
	_check(sm.elder_firewood_state().wood == 3 and maze.loot_modal.visible, "实际挖掘后活动任务增加3木材")
	await _key(KEY_ENTER)
	maze.player.position = NEAR
	maze.camera.snap_to_target()
	await get_tree().create_timer(0.3).timeout
	await _click(tracker._task_button)
	await get_tree().create_timer(0.3).timeout
	_check(tracker._collection_status.text == "3/12" and tracker._collection_task.visible, "实际采集事务后实时任务进度")
	await _shot("current_tasks_collected_3")
	sm.data.inventory.wood = 11
	_check(sm.save(), "状态边界11落盘")
	await get_tree().create_timer(0.3).timeout
	_check(tracker._collection_status.text == "11/12", "木材变化实时刷新")
	await _shot("current_tasks_11")
	await _interact()
	await _dialog_lines()
	_check(elder.choice.question.text == "是否交付12个木材？" and elder.choice.confirm_button.text == "交付", "交付确认文案准确")
	before = JSON.stringify(sm.data)
	await _key(KEY_E)
	_check(elder.phase == "delivery_choice" and JSON.stringify(sm.data) == before and not sm.elder_backpack_unlocked(), "11个E交付拒绝全量不变")
	await _shot("delivery_insufficient")
	sm.data.inventory.wood = 15
	_check(sm.save(), "木材15准备交付")
	before = JSON.stringify(sm.data)
	sm._active_save_path = ""
	await _click(elder.choice.confirm_button)
	_check(elder.phase == "delivery_choice" and JSON.stringify(sm.data) == before, "交付保存失败不扣材不解锁不归档")
	sm._active_save_path = path
	_check(not elder.backpack_reward.visible and not maze.backpack_entry.visible, "保存失败不显示背包奖励与入口")
	await _shot("delivery_save_failed")
	await _key(KEY_E)
	_check(elder.phase == "reward" and sm.elder_firewood_state().wood == 3 and sm.elder_backpack_unlocked(), "E交付扣12留3并解锁背包")
	_key_event(KEY_E,true,true)
	await get_tree().process_frame
	_check(elder.dialog._line_idx == 0, "交付后echo不跳奖励")
	var expected := [
		["白虎爷爷", "谢谢你，这下能生火做饭了。"],
		["白虎爷爷", "等等，你是那个餐厅的经营者？"],
		["主角", "你认识我？"],
		["白虎爷爷", "呵呵，看来你又忘了啊。没事，这些调味的食材送给你，你会用得上的。"],
	]
	for i in expected.size():
		if elder.dialog.dialog_text.text != expected[i][1]:
			await _key(KEY_E)
		_check(elder.dialog.speaker_name.text == expected[i][0] and elder.dialog.dialog_text.text == expected[i][1], "交付食材前对白顺序：%d" % i)
		_check(elder.dialog.portrait_texture.texture == (elder.HeroPortrait if expected[i][0] == "主角" else elder.Portrait), "对白头像匹配说话人：%d" % i)
		await _shot("ingredient_dialog_%d" % i)
		await _key(KEY_E)
	_check(elder.phase == "ingredient_reward" and elder.ingredient_reward.visible and maze.player.input_locked, "食材获得蒙层衔接且保持操作锁")
	_check(elder.ingredient_reward.item_views.size() == 3, "食材获得蒙层三种物品")
	for id in ["lantern_berry", "insulating_leaf", "sour_vine_juice"]:
		_check(sm.inventory_quantity(id) == 3, "交付实际获得3个食材：" + id)
	await _shot("ingredient_reward")
	await _click_point(Vector2(30,30))
	_key_event(KEY_E, true, true)
	await get_tree().process_frame
	_check(elder.phase == "ingredient_reward", "食材弹窗空白鼠标与echo不跳过")
	_check(elder.ingredient_reward._title_label.text == "获得物品" and elder.ingredient_reward._confirm_button.text == "收下", "食材复用宝箱标题与收下按钮")
	_check(elder.ingredient_reward._grid.columns == 3, "食材弹窗横排三列")
	for view in elder.ingredient_reward.item_views:
		_check(view.quantity.text == "×3" and view.icon.texture != null, "食材弹窗图标与数量")
	var received_before := JSON.stringify(sm.data)
	if suffix == "_1152x648":
		await _click(elder.ingredient_reward._confirm_button)
	else:
		await _key(KEY_ENTER)
	_check(elder.phase == "reward" and not elder.ingredient_reward.visible and maze.player.input_locked and JSON.stringify(sm.data) == received_before, "收下继续归还背包对白且不重复发奖")
	expected = [
		["白虎爷爷", "对了，上次你还留下个背包在我这，跟你的仓库连通很方便，一并还给你。"],
		["主角", "上次？"],
		["白虎爷爷", "呵呵，打开看看吧。继续加油，年轻人。"],
	]
	for i in expected.size():
		if elder.dialog.dialog_text.text != expected[i][1]:
			await _key(KEY_E)
		_check(elder.dialog.speaker_name.text == expected[i][0] and elder.dialog.dialog_text.text == expected[i][1], "食材后背包前对白顺序：%d" % i)
		await _shot("backpack_dialog_%d" % i)
		await _key(KEY_E)
	_check(elder.phase == "backpack_reward" and elder.backpack_reward.visible and maze.player.input_locked and not maze.backpack_entry.visible, "奖励蒙层显示且E继续前入口隐藏")
	var reward_prompt: Control = elder.backpack_reward.get_node("ContinuePrompt")
	var reward_prompt_rect := reward_prompt.get_global_rect()
	_check(is_equal_approx(reward_prompt_rect.position.y, get_viewport().get_visible_rect().size.y-84) and is_equal_approx(reward_prompt_rect.end.y, get_viewport().get_visible_rect().size.y-40), "获得蒙层E提示复用页面底部位置")
	_check(elder.backpack_reward.title.get_parsed_text() == "解锁【背包】" and "#e8ba62" in elder.backpack_reward.title.text, "解锁背包标题及章末黄色")
	await _shot("backpack_reward")
	_key_event(KEY_E, true, true)
	await get_tree().process_frame
	await _key(KEY_ESCAPE)
	await _click_point(Vector2(30, 30))
	_check(elder.phase == "backpack_reward", "背包蒙层长按Esc鼠标不能提前关闭")
	await _key(KEY_E)
	_check(elder.phase == "backpack_collect" and maze.player.input_locked, "E开始收录动画且保持锁定")
	await get_tree().create_timer(0.2).timeout
	_check(elder.backpack_reward._flying_icon != null and elder.backpack_reward._flying_icon.size.x < elder.backpack_reward.item_icon.size.x and elder.backpack_reward.self_modulate.a < 1, "图标缩小移动与蒙层渐隐")
	await _shot("backpack_collect_mid")
	await _key(KEY_E)
	await _key(KEY_ESCAPE)
	_check(elder.phase == "backpack_collect", "收录期间重复E与Esc不打断")
	await get_tree().create_timer(0.32).timeout
	await _restored()
	_check(maze.backpack_entry.visible and not elder.backpack_reward.visible and maze.backpack_entry.icon != null, "E继续后显示带图标背包入口")
	var entry_rect: Rect2 = maze.backpack_entry.get_global_rect()
	_check(is_equal_approx(entry_rect.position.x,16) and is_equal_approx(entry_rect.end.y, get_viewport().get_visible_rect().size.y-16), "背包入口固定左下安全边距")
	_check(maze.backpack_entry.text == "" and maze.backpack_entry.get_theme_stylebox("normal") is StyleBoxEmpty, "入口只显示背包图标无底框文字")
	await _shot("backpack_entry")
	sm.data.inventory.rockmane_meat = 2
	sm.data.inventory.rock_salt = 1
	sm.data.warehouse_stock = {"rockmane_meat": 4, "rock_salt": 3}
	_check(sm.save(), "实际食材与餐厅仓库准备")
	before = JSON.stringify(sm.data)
	await _click(maze.backpack_entry)
	var warehouse = maze.backpack_warehouse
	_check(warehouse.visible and warehouse._backpack_view and maze.player.input_locked and not maze.player.is_physics_processing(), "点击纯图标打开仓库并锁定迷宫")
	_check(warehouse._slot_by_id.wood._quantity == 3 and not warehouse._claim_button.visible and not warehouse._selection_area.visible, "仓库显示木材余量且只读")
	_check(warehouse._slot_by_id.rock_salt._quantity == sm.inventory_quantity("rock_salt") + int(sm.warehouse_snapshot().get("rock_salt",0)), "背包与餐厅共用食材数量")
	_check(warehouse._slot_by_id.rockmane_meat._quantity == 6 and warehouse._slot_by_id.rock_salt._quantity == 4, "已获得和仓库食材汇总不复制库存")
	var saw_empty := false
	for child in warehouse._slots_grid.get_children():
		if not child is SproutItemSlot: continue
		if child._quantity == 0: saw_empty = true
		elif saw_empty: _check(false, "背包有库存物品连续排在前面")
	_check(true, "背包物品自动压缩到前排")
	for id in ["lantern_berry", "insulating_leaf", "sour_vine_juice"]:
		_check(warehouse._slot_by_id.has(id) and warehouse._slot_by_id[id]._quantity == 3, "背包可见新食材数量："+id)
	await _shot("backpack_warehouse")
	await _click(warehouse._slot_by_id.wood._icon_button)
	await _key(KEY_E)
	await _key(KEY_D)
	_check(JSON.stringify(sm.data) == before and warehouse._selected.is_empty() and warehouse.visible, "浏览点击和E移动键不取材不改库存")
	await _key(KEY_ESCAPE)
	_check(not warehouse.visible and not maze.player.input_locked and maze.player.is_physics_processing(), "Esc关闭仓库恢复迷宫")
	await get_tree().process_frame
	await _click(maze.backpack_entry)
	await _click(warehouse._cancel_button)
	_check(not warehouse.visible and not maze.player.input_locked and JSON.stringify(sm.data) == before, "鼠标关闭仓库不改状态")
	await get_tree().create_timer(0.3).timeout
	await _click(tracker._task_button)
	await get_tree().create_timer(0.3).timeout
	_check(not tracker._collection_task.visible and tracker._exploration_task.visible, "归档移除收集任务并保留探索")
	await _shot("archived_remaining_exploration")
	before = JSON.stringify(sm.data)
	await _interact()
	await _key(KEY_E)
	_check(elder.dialog.dialog_text.text == "加油啊，年轻人。", "完成后再次交谈文案")
	await _shot("elder_completed_farewell")
	await _dialog_lines()
	await _restored()
	_check(JSON.stringify(sm.data) == before and sm.elder_firewood_state().wood == 3, "归档重复交谈无奖励")
	# 真实输入移动在对白后恢复。
	var old: Vector2 = maze.player.position
	_key_event(KEY_A,true)
	await get_tree().create_timer(0.08).timeout
	_key_event(KEY_A,false)
	_check(maze.player.position.distance_to(old) > 0.1, "对白后实际按键移动恢复")
	maze.player.position = NEAR
	maze.camera.snap_to_target()
	# 非默认相机处理和物理开关也按进入前原样恢复。
	maze.camera.set_process(false)
	maze.camera.zoom = Vector2.ONE * 2.0
	maze.player.set_physics_process(false)
	await _interact()
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.5).timeout
	_check(not maze.camera.is_processing() and maze.camera.zoom == Vector2.ONE * 2.0 and not maze.player.is_physics_processing() and not maze.player.input_locked, "恢复进入前非默认处理开关")
	maze.camera.set_process(true)
	maze.player.set_physics_process(true)
	# 场景离开使用真实旧节点退出；回调和输入锁必须同步释放。
	await _interact()
	var player = maze.player
	var camera = maze.camera
	maze.remove_child(elder)
	_check(not player.input_locked and player.is_physics_processing() and camera.is_processing(), "退出节点立即恢复旧相机输入")
	elder.queue_free()
	maze.elder = null
	await get_tree().create_timer(0.55).timeout
	_check(not player.input_locked, "场景退出旧异步不继续")
	await _close_maze()
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.2).timeout
	_check(maze.backpack_entry.visible and not maze.elder.backpack_reward.visible, "重进迷宫保留背包入口不重复播放获得")
	await _regression()
	await _close_maze()

func _set_keys(keys: Array) -> void:
	for key in held_keys:
		if key not in keys: _key_event(key,false)
	for key in keys:
		if key not in held_keys: _key_event(key,true)
	held_keys = keys.duplicate()

func _move_to(point: Vector2) -> void:
	for frame in 360:
		var delta: Vector2 = point-maze.player.position
		if delta.length() <= 3.0:
			_set_keys([])
			_check(true, "实际方向输入沿道路到达：" + str(point))
			return
		var keys: Array = []
		if absf(delta.x)>2.0: keys.append(KEY_D if delta.x>0 else KEY_A)
		if absf(delta.y)>2.0: keys.append(KEY_S if delta.y>0 else KEY_W)
		_set_keys(keys)
		await get_tree().physics_frame
		if not Roads.is_walkable(maze.player.position): break
	_set_keys([])
	_check(false, "实际方向输入未到达："+str(point)+" 实际："+str(maze.player.position))

func _regression() -> void:
	# 实际场景原道具、地图、回餐厅接口回归；不改变原奖励或重复规则。
	maze.player.position = _site_approach(sm.DigCatalog.all()[1])
	maze.camera.snap_to_target()
	await get_tree().create_timer(0.05).timeout
	_check(is_instance_valid(maze.dig_target), "既有挖掘目标仍可用")
	var wood: int = sm.inventory_quantity("wood")
	await _key(KEY_E)
	_check(maze.loot_modal.visible and sm.inventory_quantity("wood") == wood+3, "既有挖掘实际输入仍给3木材")
	await _key(KEY_ENTER)
	await RenderingServer.frame_post_draw
	_check(not maze.loot_modal.visible and not maze.player.input_locked, "挖掘关闭恢复移动")
	maze.player.position = _site_approach(sm.ChestCatalog.all()[0])
	maze.camera.snap_to_target()
	await get_tree().create_timer(0.05).timeout
	_check(is_instance_valid(maze.chest_target), "既有宝箱目标仍可用")
	var gold: int = sm.gold_balance()
	await _key(KEY_E)
	_check(maze.loot_modal.visible and sm.gold_balance() == gold+100, "原宝箱实际输入奖励保持")
	await _key(KEY_ENTER)
	await _click(maze.map_ui.mini_button)
	_check(maze.map_ui.expanded, "小地图仍能打开")
	await _key(KEY_ESCAPE)
	_check(not maze.map_ui.expanded and not maze.player.input_locked, "地图关闭输入恢复")
	maze.player.position = Roads.ENTRANCE
	maze.camera.snap_to_target()
	await get_tree().process_frame
	await _key(KEY_E)
	_check(maze.confirmation.visible, "原回餐厅E确认仍有效")
	await _key(KEY_ESCAPE)
	_check(not maze.confirmation.visible and not maze.player.input_locked, "原目的地取消恢复")
	await _key(KEY_E)
	await _key(KEY_E)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region == "restaurant" and get_tree().current_scene.scene_file_path == sm.RESTAURANT_SCENE and not Transition.is_active(get_tree()), "实际返回餐厅与转场结束")
	# 当前餐厅已有用户独立接入的背包入口，不再沿用历史“无入口”断言；保留该实现。
	var restaurant_warehouse = get_tree().current_scene.get_node("UIOverlay/WarehouseModal")
	restaurant_warehouse.open_for_order()
	_check(not restaurant_warehouse._backpack_view and restaurant_warehouse._claim_button.visible and restaurant_warehouse._selection_area.visible, "餐厅原取料模式保留")
	await _click(restaurant_warehouse._meat_slot._icon_button)
	await _click(restaurant_warehouse._salt_slot._icon_button)
	_check(not restaurant_warehouse._claim_button.disabled and restaurant_warehouse._selected.size() == 2, "餐厅领取食材选择原行为保留")
	restaurant_warehouse.close_modal()
	maze = null
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
