extends "res://tools/tests/maze_capture.gd"
const Bento=preload("res://scripts/restaurant/bento_store.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"生命周期与鼠标检查隔离")
	if failures==0:
		await _failed_stages()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d"%[resolution.x,resolution.y]
			await _discard_mouse()
		await _battle_healing()
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _setup(phase: String) -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"生命周期实际出征")
	sm.record_maze_location("fenshui",Vector2(1300,325))
	sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0})
	if phase!="gift_pending": _check(Bento.grant(sm).success,"准备真实赠礼凭证")
	if phase in ["bento_fly","farewell","fade","done"]:
		sm.set_yufeng_salia_record({"version":2,"phase":"bento_unlock","line":0})
		_check(Bento.reveal(sm).success,"准备真实解锁凭证")
	sm.set_yufeng_salia_record({"version":2,"phase":phase,"line":0})

func _spawn() -> void:
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().process_frame
	maze.capture_flow.window_focused=true
	await get_tree().create_timer(0.2).timeout

func _failed_stages() -> void:
	for phase in ["gift_pending","gift_reward","bento_unlock","bento_fly","farewell","fade"]:
		_setup(phase)
		var b: Dictionary=Bento.snapshot(sm)
		var path: String=sm._active_save_path
		sm._active_save_path="user://missing_yf03_directory/save.json"
		await _spawn()
		var e=maze.yf_encounter
		if phase=="gift_reward": await _click(e.gift_modal._confirm_button)
		if phase=="farewell":
			await _send_key(KEY_E)
			await _send_key(KEY_E)
		await get_tree().create_timer(1.25).timeout
		_check(e.phase==phase and sm.yufeng_salia_state()==phase,"真实保存失败不推进："+phase)
		_check(Bento.snapshot(sm)==b and maze.player.input_locked,"真实保存失败无重复奖或丢锁："+phase)
		sm._active_save_path=path
		if phase=="gift_reward":
			await get_tree().create_timer(1.1).timeout
			await _click(e.gift_modal._confirm_button)
		if phase=="farewell":
			await _send_key(KEY_E)
			await _send_key(KEY_E)
		await get_tree().create_timer(1.3).timeout
		_check(e.phase!=phase or (phase=="bento_unlock" and Bento.unlocked(sm)) or (phase=="farewell" and e.record.line==1),"恢复写入后可以继续："+phase)
		maze.queue_free()
		await get_tree().process_frame

func _discard_mouse() -> void:
	_setup("done")
	await _spawn()
	await _click(maze.bento_entry)
	var page=maze.bento_modal
	await _click(page.tiles.defense)
	await _click(page.details.get_node("DiscardButton"))
	_check(page.confirmation.visible,"真实鼠标丢弃弹二次确认")
	await _capture_image("discard_confirmation")
	await _click(page.confirmation.cancel_button)
	_check(Bento.snapshot(sm).slots.has("defense") and maze.player.input_locked and page.visible,"取消只关确认保留页面锁与料理")
	await _click(page.details.get_node("DiscardButton"))
	var path: String=sm._active_save_path
	sm._active_save_path="user://missing_yf03_directory/save.json"
	await _click(page.confirmation.confirm_button)
	_check(Bento.snapshot(sm).slots.has("defense") and page.visible,"真实鼠标确认但写失败保留料理")
	sm._active_save_path=path
	await _click(page.details.get_node("DiscardButton"))
	await _click(page.confirmation.confirm_button)
	_check(not Bento.snapshot(sm).slots.has("defense"),"真实鼠标确认永久丢弃")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked and maze.player.is_physics_processing(),"迷宫关闭恢复移动")
	maze.queue_free()
	await get_tree().process_frame
	_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"未食用实际带回餐厅")
	maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	await _click(hud.bento_entry)
	page=hud.bento_modal
	await _click(page.tiles.health)
	_check(page.details.get_node_or_null("EatButton")==null and not page.all_button.visible,"餐厅没有单吃/全吃按钮")
	await _capture_image("restaurant_saved_food")
	await _click(page.details.get_node("DiscardButton"))
	await _send_key(KEY_ESCAPE)
	_check(not page.confirmation.visible and page.visible and hud._player.input_locked,"Esc取消丢弃不穿透关闭主页面")
	await _click(page.details.get_node("DiscardButton"))
	await _click(page.confirmation.confirm_button)
	_check(not Bento.snapshot(sm).slots.has("health") and Bento.snapshot(sm).slots.has("attack"),"餐厅真实丢弃只删选中料理")
	await _send_key(KEY_ESCAPE)
	_check(not hud._player.input_locked,"餐厅关闭恢复原输入")
	maze.queue_free()
	await get_tree().process_frame

func _battle_healing() -> void:
	_setup("done")
	_check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"回血测试回第一迷宫")
	# 只保留一只原有史莱姆，使用正式追逐/近身攻击；不新造敌人。
	var run: Dictionary=Run.snapshot(sm)
	for monster in run.monsters.values(): monster.status="skipped"
	run.monsters.slime_1.status="alive"
	var point: Vector2=Run.monster_for(run,"slime_1").position
	run.combat.hero=Run.Combat.pack(point)
	run.combat.hp=1.0
	sm.data[Run.KEY]=run
	sm.data[sm.MAZE_STATE_KEY].position=Run.Combat.pack(point)
	_check(Bento.eat(sm,"health").success,"战前真实食用回血料理")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.window_focused=true
	var deadline := Time.get_ticks_msec()+30000
	while Run.snapshot(sm).bento.heal_elapsed<20.0 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var healed: Dictionary=Run.snapshot(sm)
	_check(Run.portal_combat_locked(sm),"正式史莱姆追逐/近身战斗保持中")
	_check(absf(healed.bento.heal_elapsed-20.0)<0.000001,"实战20秒有效时间回血走完")
	_check(absf(healed.combat.hp-(1.0+healed.combat.max_hp*0.3))<0.000001,"实战累计回血准确且不因战斗停表")
	_check(not Bento.eat(sm,"attack").success,"正在战斗拒绝新食用")
	await _capture_image("battle_healing_complete")
	maze.queue_free()
	await get_tree().process_frame
