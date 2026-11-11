extends "res://tools/tests/audio_interactions.gd"
const BossRun = preload("res://scripts/maze/capture_run.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	evidence=_arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures: get_tree().quit(1); return
	sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
	sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["yaya","tieshan"]).success,"准备探索")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.6).timeout
	maze.capture_flow.set_process(false)
	maze.player.set_physics_process(false)
	GameAudio.set_world_music(&"maze")
	var lizard_run: Dictionary=BossRun.snapshot(sm)
	var lizard_baseline: Dictionary=lizard_run.duplicate(true)
	var lizard: Dictionary=lizard_run.combat.actors.lizard_1
	lizard.mode="idle"
	sm.data[BossRun.KEY]=lizard_run
	maze.capture_flow._process(0)
	_check(not GameAudio.boss_music.playing,"石化蜥蜴未攻击不切换")
	var lizard_point: Vector2=BossRun.Combat.vec(lizard.position)
	maze.player.position=lizard_point+Vector2(8,0)
	maze.camera.snap_to_target()
	BossRun.Combat.advance(lizard_run,maze.player.position,0.05)
	sm.data[BossRun.KEY]=lizard_run
	maze.capture_flow._process(0)
	_check(lizard.mode=="windup" and GameAudio.boss_music.playing and GameAudio.maze_music.stream_paused,"石化蜥蜴实际攻击前摇切换Boss音乐", {"mode":lizard.mode,"region":lizard_run.combat.get("region","missing"),"playing":GameAudio.boss_music.playing})
	await get_tree().create_timer(0.3).timeout
	var lizard_music_pos: float=GameAudio.boss_music.get_playback_position()
	maze.capture_flow._process(0)
	await get_tree().create_timer(0.15).timeout
	_check(GameAudio.boss_music.get_playback_position()>lizard_music_pos,"石化蜥蜴持续攻击不重播")
	await _shot("boss_music_lizard")
	lizard.hp=0
	sm.data[BossRun.KEY]=lizard_run
	maze.capture_flow._process(0)
	_check(not GameAudio.boss_music.playing and not GameAudio.maze_music.stream_paused,"石化蜥蜴倒下恢复迷宫音乐")
	GameAudio.music_for_destination("res://scenes/restaurant_map_2d.tscn")
	GameAudio.update_boss_music(lizard_baseline)
	_check(GameAudio.restaurant_music.playing and not GameAudio.boss_music.playing,"离开蜥蜴地图后旧状态不覆盖目标音乐")
	maze.queue_free()
	await get_tree().process_frame
	sm.data[BossRun.KEY]=lizard_baseline
	for region in ["salt_pool","fenshui"]:
		var cfg = load("res://data/maze/salt_boss.gd" if region=="salt_pool" else "res://data/maze/fenshui_boss.gd")
		_check(BossRun.change_region(sm,region,cfg.Roads.SPAWN).success,"进入Boss地图："+region)
		maze=load("res://scenes/maze_"+region+".tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene=maze
		await get_tree().create_timer(0.5).timeout
		maze.capture_flow.set_process(false)
		maze.player.set_physics_process(false)
		GameAudio.set_world_music(&"maze")
		var run: Dictionary=BossRun.snapshot(sm)
		var baseline: Dictionary=run.duplicate(true)
		var a: Dictionary=run.combat.actors[cfg.ID]
		a.mode="idle"
		if region=="salt_pool": a.rock_phase="active"
		else: a.frog_phase="dormant"
		sm.data[BossRun.KEY]=run
		maze.capture_flow._process(0)
		_check(not GameAudio.boss_music.playing,"未攻击不播放："+region)
		await get_tree().create_timer(0.2).timeout
		var original_pos: float=GameAudio.maze_music.get_playback_position()
		var hero: Vector2=cfg.HOME+Vector2(0,30)
		run.combat.frog_unlocked=true
		if region=="salt_pool": BossRun.Combat.Rock.advance(run,hero,0.05)
		else: BossRun.Combat.Frog.advance(run,hero,0.05)
		sm.data[BossRun.KEY]=run
		maze.player.position=hero
		maze.camera.snap_to_target()
		maze.capture_flow._process(0)
		_check(GameAudio.boss_music.playing and GameAudio.maze_music.stream_paused,"实际Boss前摇经场景流程切换："+region)
		await get_tree().create_timer(0.3).timeout
		var pos: float=GameAudio.boss_music.get_playback_position()
		maze.capture_flow._process(0)
		await get_tree().create_timer(0.15).timeout
		_check(GameAudio.boss_music.get_playback_position()>pos,"重复状态不重播："+region)
		await _shot("boss_music_"+region)
		run.combat.actors[cfg.ID].hp=0
		sm.data[BossRun.KEY]=run
		maze.capture_flow._process(0)
		_check(not GameAudio.boss_music.playing and not GameAudio.maze_music.stream_paused and GameAudio.maze_music.playing,"Boss倒下恢复探索："+region)
		_check(GameAudio.maze_music.get_playback_position()>=original_pos-0.1,"探索音乐从暂停处继续："+region)
		a.hp=100
		run.combat.hp=100
		GameAudio.update_boss_music(run)
		run.combat.hp=0
		GameAudio.update_boss_music(run)
		_check(not GameAudio.boss_music.playing,"主角失败停止Boss音乐："+region)
		run.combat.hp=100
		GameAudio.update_boss_music(run)
		GameAudio.music_for_destination("res://scenes/restaurant_map_2d.tscn")
		GameAudio.update_boss_music(run)
		_check(GameAudio.restaurant_music.playing and not GameAudio.boss_music.playing,"返回确认后旧战斗不覆盖餐厅音乐："+region)
		maze.queue_free()
		await get_tree().process_frame
		sm.data[BossRun.KEY]=baseline
	_check(GameAudio.boss_music.stream.loop and absf(GameAudio.boss_music.stream.get_length()-180)<0.2,"三分钟原素材循环")
	_check(sm.audio_guard_blocked==0,"写盘仅隔离目录")
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
