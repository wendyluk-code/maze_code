extends "res://tools/tests/elder_01_flow.gd"
const Run = preload("res://scripts/maze/capture_run.gd")

func _walkthrough() -> void:
	_seed(0)
	sm.data[sm.MAZE_STATE_KEY] = sm._empty_maze_state()
	_check(Run.begin(sm, Roads.SPAWN).success, "建立实际探索")
	sm.data.ch2_guide_01 = {"revision":2,"step":"done","seen":{},"banked":{}}
	maze = MazeScene.instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.2).timeout
	var probes := [
		[Vector2(898,521),Vector2(956,582)],
		[Vector2(860,295),Vector2(790,326)],
		[Vector2(860,295),Vector2(933,269)],
		[Vector2(898,521),Vector2(839,503)]
	]
	for id in ["slime_1","snail_1","beetle_1","lizard_1"]:
		var monster: Node = maze.capture_flow.monsters[id]
		for direction in 4:
			var origin: Vector2 = probes[direction][0]
			var destination: Vector2 = probes[direction][1]
			_prepare_actor(id, origin, origin, destination, "idle")
			await get_tree().create_timer(0.22).timeout
			var actor: Dictionary = Run.snapshot(sm).combat.actors[id]
			_check(actor.mode == "chase" and Run.Combat.vec(actor.position).distance_to(origin) > 1, id+" 实际激怒追击 "+str(direction))
			_check(_row(monster) == direction and not monster.body.flip_h, id+" 追击朝向与运动一致 "+str(direction))
			await _shot(id+"_chase_"+str(direction))
			var frame_before: Rect2 = monster.body.texture.region
			await get_tree().create_timer(0.2).timeout
			_check(monster.body.texture.region != frame_before, id+" 动画持续换帧 "+str(direction))
			# 相同道路，返回出生点也必须使用移动方向而不是玩家方向。
			_prepare_actor(id, origin, destination, Roads.SPAWN, "return")
			await get_tree().create_timer(0.2).timeout
			_check(_row(monster) == direction and not monster.body.flip_h, id+" 返回出生点朝向正确 "+str(direction))
			_check(Run.Combat.vec(Run.snapshot(sm).combat.actors[id].position).distance_to(origin)>1, id+" 真实返回产生位移")
		# 停止时保留最后朝向；弹窗暂停也冻结帧动画。
		_prepare_actor(id, Vector2(898,521), Vector2(898,521), Roads.SPAWN, "idle")
		await get_tree().create_timer(0.1).timeout
		var last_row := _row(monster)
		await get_tree().create_timer(0.2).timeout
		_check(_row(monster) == last_row, id+" 待机保留朝向")
		maze.capture_flow._lock()
		await get_tree().process_frame
		var paused_frame: Rect2 = monster.body.texture.region
		await get_tree().create_timer(0.3).timeout
		_check(monster.body.texture.region == paused_frame, id+" 弹窗期间动画暂停")
		var scale_before: Vector2 = monster.body.scale
		for motion in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			monster.update_motion(motion)
			for frame in 4:
				monster._draw_frame(frame)
				_check(monster.body.scale.is_equal_approx(scale_before), id+" 四方向各帧缩放一致")
				if monster.config.kind in ["lizard","snail"]:
					var contact: Vector2 = monster.ground_contacts[frame]
					_check(monster.shadow.position.distance_to((monster.body.offset+contact)*monster.body.scale+Vector2(0,-2)) < 0.01, id+" 转向后阴影贴合脚底")
		maze.capture_flow._unlock()
	await _close_maze()

func _row(monster: Node) -> int:
	var texture: AtlasTexture = monster.body.texture
	return floori(texture.region.position.y / (texture.atlas.get_height()/4.0))

func _prepare_actor(id: String, origin: Vector2, home: Vector2, hero: Vector2, mode: String) -> void:
	var run: Dictionary = sm.data[Run.KEY]
	for key in run.monsters: run.monsters[key].status = "alive" if key == id else "skipped"
	var rows := Run.monsters_for(run)
	for index in rows.size():
		if rows[index].id == id: run.layout[index].position = Run.Combat.pack(home)
	run.combat.layout = run.layout.duplicate(true)
	run.combat.actors[id] = Run.Combat.fresh_actor(rows.filter(func(row): return row.id==id)[0].kind,origin)
	run.combat.actors[id].mode = mode
	run.combat.hp = run.combat.max_hp
	run.combat.hero = Run.Combat.pack(hero)
	run.combat.shots.clear()
	maze.player.position = hero
	maze.camera.snap_to_target()
	maze.capture_flow.window_focused = true
	_check(Run.valid(run) and Roads.is_walkable(hero), "有效道路与战斗样例 "+id)
