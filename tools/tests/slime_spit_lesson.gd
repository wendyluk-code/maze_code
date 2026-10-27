extends "res://tools/tests/slime_lesson_timing.gd"

func _attack_target() -> void:
	var target := Run.Combat.vec(sm.data[Run.KEY].combat.actors.slime_1.position)
	maze.capture_flow.window_focused = true
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = maze.get_viewport().get_canvas_transform() * target
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame

func _wait_lesson(g: Node, id: String, seconds := 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if g.reading and g.lesson_id == id: return true
		await get_tree().process_frame
	return false

func _finish_lesson(g: Node) -> void:
	var id: String = g.lesson_id
	for i in 6:
		if not g.reading or g.lesson_id != id: return
		await _key(KEY_E)
		await get_tree().create_timer(0.08).timeout

func _walkthrough() -> void:
	_seed(0)
	sm.data[sm.MAZE_STATE_KEY] = sm._empty_maze_state()
	_check(Run.begin(sm, Roads.SPAWN).success, "建立喷射教学探索")
	var run: Dictionary = sm.data[Run.KEY]
	run.layout[0].position = [860.0,295.0]
	run.combat.layout = run.layout.duplicate(true)
	run.combat.actors.slime_1.position = [860.0,295.0]
	run.combat.hero = [1005.0,219.0]
	sm.data[sm.MAZE_STATE_KEY].position = run.combat.hero.duplicate()
	for id in run.monsters:
		if id != "slime_1": run.monsters[id].status = "skipped"
	sm.data.ch2_guide_01 = {"revision":2,"step":"explore","seen":{},"banked":{}}
	_check(Run.valid(run), "夹具符合正式战斗契约")
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	maze.capture_flow.window_focused = true
	var g = maze.exploration_guide
	_check(await _wait_lesson(g,"05_power"), "亮血条先播放第一句")
	await _finish_lesson(g)
	_check(g._seen("05_power"), "第一句已读落盘")
	await get_tree().create_timer(0.2).timeout
	_state_checks_lesson()
	# 空挥一次不会计入三次命中。
	var count: int = sm.data.ch2_guide_01.get("combat_hits",0)
	_check(Run.combat_attack(sm,maze.player.position,Vector2.UP).success,"实际攻击事务允许空挥")
	await get_tree().create_timer(0.75).timeout
	_check(int(sm.data.ch2_guide_01.get("combat_hits",0)) == count,"空挥不增加教学命中数")
	for hit_index in 3:
		if g.reading: break
		await _attack_target()
		await get_tree().create_timer(0.8).timeout
		if hit_index < 2: _check(not g.reading,"不足三次命中不插入切换说明")
	_check(await _wait_lesson(g,"05_switch"),"第三次命中后切换技能说明")
	if not g.reading:
		await _close_maze()
		return
	await _key(KEY_E)
	await _shot("switch_lesson")
	var frozen: Dictionary = Run.snapshot(sm).combat
	await get_tree().create_timer(0.25).timeout
	_check(Run.snapshot(sm).combat == frozen,"切换说明冻结战斗")
	_check(sm.save(),"切换说明途中保存")
	sm.load_data()
	_check(int(sm.data.ch2_guide_01.combat_hits)==3 and not g._seen("05_switch"),"读档保留三次命中且未确认不算已读")
	# 贴身仍必须开始首次喷射，不能困在近战或1血状态。
	var target := Run.Combat.vec(sm.data[Run.KEY].combat.actors.slime_1.position)
	maze.player.position = Roads.move_on_road(target,Vector2(20,0))
	await _finish_lesson(g)
	var cast_deadline := Time.get_ticks_msec()+3000
	while float(sm.data[Run.KEY].combat.actors.slime_1.get("cast",0)) <= 0 and Time.get_ticks_msec()<cast_deadline:
		await get_tree().process_frame
	_check(float(sm.data[Run.KEY].combat.actors.slime_1.get("cast",0))>0 and not g.reading,"切换说明结束后贴身自然蓄力，无格挡说明")
	# 模拟旧版本停在格挡说明前摇的存档；无格挡已读标记也应继续。
	maze.capture_flow.set_process(false)
	var legacy: Dictionary = sm.data[Run.KEY].combat
	legacy.actors.slime_1.cast = 0.65
	legacy.actors.slime_1.cast_aim = Run.Combat.pack(target.direction_to(maze.player.position))
	legacy.actors.slime_1.skill_reuse = 2.4
	legacy.slime_lesson["guard_pending"] = true
	legacy.slime_lesson["guard_read"] = false
	_check(sm.save(),"旧格挡教学前摇存档保存")
	await _close_maze()
	sm.load_data()
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	maze.capture_flow.window_focused = true
	g = maze.exploration_guide
	_check(not g.before_combat(Run.snapshot(sm)) and not g.reading,"旧格挡教学读档不再弹说明或锁输入")
	_check(not maze.player.input_locked,"旧格挡教学读档恢复移动")
	# 原状态事务处理：模拟高攻击仍只能扣到1，随后由真实帧播完动画。
	var c: Dictionary = sm.data[Run.KEY].combat
	c.attack = 100
	Run.Combat.Skills.damage(sm.data[Run.KEY],"slime_1")
	_check(c.actors.slime_1.hp==1,"前摇未结束致命攻击保留1血")
	var deadline := Time.get_ticks_msec()+3000
	while float(sm.data[Run.KEY].combat.actors.slime_1.get("spit_left",0)) <= 0 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	_check(float(sm.data[Run.KEY].combat.actors.slime_1.get("spit_left",0))>0,"实际进入喷射动画")
	_check(not g._seen("05_spit_complete"),"发射弹丸瞬间仍未解除保护")
	await _shot("spit_animation")
	while not g._seen("05_spit_complete") and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	_check(g._seen("05_spit_complete") and sm.data[Run.KEY].combat.actors.slime_1.spit_left<=0,"无需格挡教学在完整喷射后解除保护")
	_check(sm.data[Run.KEY].combat.get("blocks",0)==0,"教学期间没有格挡计数")
	_check(sm.save(),"喷射完成持久化")
	sm.load_data()
	_check(g._seen("05_spit_complete"),"读档不会重新开启保护")
	await get_tree().create_timer(0.8).timeout
	await _attack_target()
	_check(await _wait_lesson(g,"06_absorb",4.0),"喷完后可真实击败并进入转食材教学")
	await _shot("defeat_after_spit")
	await _finish_lesson(g)
	await _close_maze()

func _state_checks_lesson() -> void:
	var run := Run.snapshot(sm)
	var guide: Dictionary = sm.data.ch2_guide_01.duplicate(true)
	Run.Combat.Skills.sync_lesson(run,guide)
	run.combat.attack = 100
	Run.Combat.Skills.damage(run,"slime_1")
	_check(run.combat.actors.slime_1.hp==1,"任意高伤害不能跳过首次喷射")
	_check(run.combat.slime_lesson.hits==1,"实际伤害统一累计一次命中")
	Run.Combat.Skills.damage(run,"slime_2")
	_check(run.combat.actors.slime_2.hp==0,"其他史莱姆没有死亡保护")
	guide.seen["05_spit_complete"] = true
	Run.Combat.Skills.sync_lesson(run,guide)
	Run.Combat.Skills.damage(run,"slime_1")
	_check(run.combat.actors.slime_1.hp==0,"已完成喷射教学不保护")
	guide.seen.erase("05_spit_complete")
	guide.step = "done"
	Run.Combat.Skills.sync_lesson(run,guide)
	_check(not Run.Combat.Skills.protected_slime(run,"slime_1"),"已完成探索的旧存档不补强制教学")
	guide.step = "explore"
	guide.seen["05_switch"] = true
	Run.Combat.Skills.sync_lesson(run,guide)
	var a: Dictionary = run.combat.actors.slime_1
	a.hp = 1
	a.mode = "chase"
	a.cast = 0.0
	a.spit_left = 0.28
	a.skill_reuse = 2.0
	Run.Combat.Skills.advance(run,Run.Combat.vec(a.position)+Vector2(20,0),0.27)
	Run.Combat.Skills.damage(run,"slime_1")
	_check(a.hp==1 and not run.combat.slime_lesson.completed,"喷射动画最后一刻仍保留1血")
	Run.Combat.Skills.advance(run,Run.Combat.vec(a.position)+Vector2(20,0),0.02)
	Run.Combat.Skills.damage(run,"slime_1")
	_check(a.hp==0 and run.combat.slime_lesson.completed,"完整0.28秒后才允许致命伤害")
	# 使用正式存档单例，以覆盖新增区域和成长接口；只令保存路径失败。
	var saved_state: Dictionary = sm.data.duplicate(true)
	var saved_path: String = sm._active_save_path
	sm.data.ch2_guide_01 = guide.duplicate(true)
	var copy: Dictionary = sm.data[Run.KEY]
	copy.combat.actors.slime_1.spit_left = 0.01
	copy.combat.actors.slime_1.cast = 0.0
	copy.combat.actors.slime_1.skill_reuse = 2.0
	copy.combat.shots = []
	copy.combat.axe_pending = false
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	var result := Run.combat_tick(sm,Run.Combat.vec(copy.combat.hero),0.02)
	_check(not result.success and result.get("reason")=="save_failed" and sm.data==before,"喷射完成写盘失败回滚保护、动画和全量状态")
	sm._active_save_path = saved_path
	sm._state = saved_state
