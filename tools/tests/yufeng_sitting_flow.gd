extends "res://tools/tests/maze_capture.gd"
const Story = preload("res://scripts/maze/yufeng_salia_story.gd")
const Gift = preload("res://scripts/restaurant/yufeng_ingredient_gift.gd")

func _verify_isolation() -> bool:
	var actual := ProjectSettings.globalize_path("user://").replace("\\","/").to_lower()
	return actual.begins_with(_arg("--isolation-root=").replace("\\","/").to_lower()+"/")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"只使用隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _story_flow()
			if failures > 0: break
		await _edge_checks()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("YUFENG_SITTING ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _prepare_trip() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"建立实际探索")
	_check(Run.change_region(sm,"fenshui",Story.Frog.Roads.SPAWN).success,"进入分水庭")
	# 等价战斗样例：屏蔽无关普通怪，攻击力48；巨蛙仍为完整96生命，真实鼠标攻击与结算。
	for id in sm.data[Run.KEY].monsters:
		if id != Story.Frog.ID:
			sm.data[Run.KEY].monsters[id].status = "skipped"
			sm.data[Run.KEY].monsters[id].respawn_at = 1.0e20
	sm.data[Run.KEY].combat.attack = 48
	sm.save()

func _open_map() -> void:
	maze = load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.35).timeout
	maze.capture_flow.window_focused = true
	await get_tree().process_frame

func _close_map() -> void:
	maze.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _read_phase(expected: String) -> void:
	if expected == "clue" and maze.yf_encounter.clue_modal.visible:
		await _click(maze.yf_encounter.clue_modal._confirm_button)
		return
	for i in 20:
		if maze.yf_encounter.phase != expected: return
		await _send_key(KEY_E)
		await get_tree().create_timer(0.04).timeout
	_check(false,"对白在有界按键内结束："+expected)

func _checkpoint(label: String) -> void:
	_check(sm.save(),"保存独立进程检查点："+label)
	var result := DirAccess.copy_absolute(ProjectSettings.globalize_path(sm._active_save_path),ProjectSettings.globalize_path("user://yf-checkpoint-"+label+".json"))
	_check(result == OK,"复制真实存档检查点："+label)

func _place(point: Vector2) -> void:
	_check(Story.Frog.Roads.is_walkable(point),"测试站位可行走："+str(point))
	maze.player.position = point
	maze.camera.snap_to_target()
	await get_tree().create_timer(0.2).timeout

func _attack_mouse() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(580,360)
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(580,360)
	get_viewport().push_input(event)

func _story_flow() -> void:
	_prepare_trip()
	await _open_map()
	var e = maze.yf_encounter
	_check(e.phase == "unseen" and e.idle.is_playing(),"初见前双人原地坐姿循环")
	_check(e.ground_shadows.get_child_count() == 1,"石头底部使用统一柔和投影")
	var anchor: Vector2 = e.idle.position
	var frames := {}
	for i in 16:
		frames[e.idle.frame] = true
		await get_tree().create_timer(0.18).timeout
		_check(e.idle.position == anchor,"动画脚底锚点不漂移")
	_check(frames.size() >= 4,"待机播放多个动作帧")
	await _capture_image("sitting_before")
	await _place(Vector2(1514,241))
	_check(e.phase == "unseen" and not e.dialog.visible and not e.talk_prompt.visible,"经过旧触发线不自动对话，远处无提示")
	await _place(Story.Site.CHAT_FOOT+Vector2(40,-5))
	_check(e.phase == "unseen" and e.talk_prompt.visible and not maze.player.input_locked,"靠近只显示交谈E提示")
	_check(e.talk_prompt.button.get_node("Content/ActionLabel").text == "与御风和萨莉亚交谈","交谈提示使用确认文案")
	_check(e.idle.z_index == maze.player.z_index and e.get_index() < maze.player.get_index(),"双人同层先画，主角后画在上")
	await _capture_image("near_pair_prompt")
	await _send_key(KEY_E)
	_check(e.phase == "intro" and e.idle.visible and maze.player.input_locked,"友好初遇仍保持坐姿")
	await get_tree().create_timer(1.6).timeout
	await _capture_image("intro")
	await _read_phase("intro")
	_check(e.phase == "investigate" and not maze.player.input_locked and maze.capture_flow.sparring() == null,"接下委托恢复操作且不进入切磋")
	_check(sm.quest_snapshot().active.any(func(q): return q.id == Story.QUEST and q.unread),"探索任务已接取且未读")
	_checkpoint("investigate")
	await _click(maze.task_tracker._task_button)
	await get_tree().create_timer(0.35).timeout
	_check(sm.quest_snapshot().active.any(func(q): return q.id == Story.QUEST and not q.unread),"主动展开任务后清除未读")
	await _capture_image("active_task")
	await _click(maze.task_tracker._task_button)
	_check(Story.frog_unlocked(sm),"接委托后巨蛙可战斗")
	_check(not Story.advance(sm,"post",0,Story.Site.CHAT_FOOT).success,"未调查不能回报")
	_check(not Story.can_inspect(sm,Story.Frog.HOME),"巨蛙未败不能调查")
	sm.save()
	await _close_map()
	sm.load_data()
	await _open_map()
	e = maze.yf_encounter
	_check(e.phase == "investigate" and e.idle.visible,"接委托读档保留两人待机")
	await _place(Vector2(900,510))
	var deadline := Time.get_ticks_msec()+14000
	while Run.snapshot(sm).combat.actors[Story.Frog.ID].hp > 0 and Time.get_ticks_msec() < deadline:
		await _attack_mouse()
		await get_tree().create_timer(0.55).timeout
	_check(Run.snapshot(sm).combat.actors[Story.Frog.ID].hp <= 0,"实际鼠标弹道击败完整生命巨蛙")
	_check(sm.yufeng_salia_record().frog_defeated,"击败与委托进度同事务保存")
	await get_tree().create_timer(1.0).timeout
	if maze.capture_flow.dialog.visible:
		await _click(maze.capture_flow.dialog._cancel_button)
		await get_tree().create_timer(0.4).timeout
	_check(not maze.player.input_locked,"放弃捕获不妨碍已击败调查")
	if failures > 0:
		await _capture_image("failure_after_frog")
		await _close_map()
		return
	await _place(Story.Frog.HOME+Vector2(0,35))
	_check(e.clue_prompt.visible,"靠近池中央显示调查按钮")
	await _capture_image("pool_prompt")
	await _send_key(KEY_E)
	_check(e.phase == "clue","真实E开始调查")
	await get_tree().create_timer(2.0).timeout
	await _capture_image("pool_clue")
	await _read_phase("clue")
	_check(e.phase == "report" and not maze.player.input_locked,"调查后等待返回回报")
	_checkpoint("report")
	sm.save()
	await _close_map()
	sm.load_data()
	await _open_map()
	e = maze.yf_encounter
	_check(e.phase == "report","调查结果读档保留")
	await _place(Story.Site.CHAT_FOOT+Vector2(40,-5))
	_check(e.talk_prompt.visible,"靠近路边两人可回报")
	var old_stock: Dictionary = sm.warehouse_snapshot()
	await _click(e.talk_prompt.button)
	_check(e.phase == "post","鼠标回报进入简短对白")
	await _read_phase("post")
	await get_tree().create_timer(0.2).timeout
	_check(e.phase == "gift_reward" and e.gift_modal.visible,"交付后展示宫廷食材")
	_checkpoint("gift_reward")
	for id in Gift.ITEMS:
		_check(sm.warehouse_snapshot().get(id,0) == old_stock.get(id,0)+Gift.ITEMS[id],"宫廷食材仅增加一次："+id)
	await _capture_image("royal_ingredients")
	await _click(e.gift_modal._confirm_button)
	_check(e.phase == "farewell","食材后播放用户确认的三句告别")
	await _read_phase("farewell")
	await get_tree().create_timer(1.3).timeout
	_check(e.phase == "joined" and e.join_overlay.visible,"双角色入队演出")
	_check(sm.owned_characters().has("yufeng") and sm.owned_characters().has("salia"),"两人已进入角色库")
	_check(e.join_overlay.cards[0].get_node("CharacterFace").character_id == "yufeng" and e.join_overlay.cards[1].get_node("CharacterFace").character_id == "salia","入队卡面为御风与萨莉亚")
	_check(sm.quest_snapshot().archived.any(func(q): return q.id == Story.QUEST),"完成委托归档")
	_checkpoint("joined")
	await _capture_image("party_joined")
	await _send_key(KEY_E)
	await get_tree().create_timer(0.2).timeout
	_check(e.phase == "fade" and e.idle.modulate.a < 1 and e.idle.modulate.a > 0,"确认入队后两人与地图一起渐隐")
	await _capture_image("farewell_fade")
	await get_tree().create_timer(0.7).timeout
	_check(e.phase == "done" and not e.idle.visible and not maze.player.input_locked,"结束后两人消失且输入恢复")
	_check(not e.talk_prompt.visible and not e.clue_prompt.visible,"完成后无残留交互")
	_checkpoint("done")
	var position_before: Vector2 = maze.player.position
	Input.action_press("ui_right")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_right")
	_check(maze.player.position.distance_to(position_before) > 1,"结束后真实方向输入可移动")
	_check(sm.maze_exploration_state().region == "fenshui","不跟随主角回餐厅")
	var final_stock: Dictionary = sm.warehouse_snapshot()
	_check(Gift.grant(sm).success and sm.warehouse_snapshot() == final_stock,"重复领取不增加食材")
	sm.save()
	await _close_map()
	sm.load_data()
	await _open_map()
	e = maze.yf_encounter
	_check(e.phase == "done" and not e.idle.visible,"完成读档后不再出现")
	_check(sm.owned_characters().has("yufeng") and sm.owned_characters().has("salia"),"完成读档仍可编队")
	await _capture_image("done_reloaded")
	await _close_map()

func _edge_checks() -> void:
	_prepare_trip()
	var original: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Story.advance(sm,"intro").success and sm.data == original,"初遇保存失败完全回滚")
	sm._active_save_path = path
	for legacy in ["unseen","intro","eat","question","post","gift_pending","gift_reward","farewell","fade","done"]:
		sm.data[Story.KEY] = {"version":2,"phase":legacy,"line":0}
		var before: Dictionary = sm.data.duplicate(true)
		var record: Dictionary = sm.yufeng_salia_record()
		_check(Story.valid(record) and record.phase != "battle" and sm.data == before,"旧阶段只读兼容："+legacy)
	sm.data[Story.KEY] = Story.fresh("farewell")
	sm.data[Story.KEY].line = 2
	var before_join: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Story.advance(sm,"joined").success and sm.data == before_join,"入队保存失败不授角色、不归档")
	sm._active_save_path = path
	sm.data.owned_characters_v1 = ["yaya","tieshan","yufeng"]
	sm.data.character_progression_v1 = {"yufeng":{"level":1,"exp":0,"rank":3,"breakthroughs":0}}
	_check(Story.advance(sm,"joined").success,"已持有御风仍可完成入队")
	_check(sm.owned_characters().count("yufeng") == 1,"已持有角色不重复入库")
	_check(sm.data.character_progression_v1.yufeng.rank == 3,"剧情入队不改变已有星阶")
