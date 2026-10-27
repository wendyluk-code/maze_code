extends "res://tools/tests/combat_02_flow.gd"
var frame_samples: Array=[]
var sampling := false
func _process(delta: float) -> void:
	if sampling: frame_samples.append(delta*1000.0)
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _edge_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	frame_samples.sort()
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"frame_p95_ms":frame_samples[int(frame_samples.size()*0.95)] if not frame_samples.is_empty() else 0},"\t"))
	get_tree().quit(1 if failures else 0)

func _edge_scene() -> void:
	await _new_scene()
	var flow=maze.capture_flow
	flow.set_process(false)
	var c: Dictionary=sm.data[Run.KEY].combat
	c.actors.slime_1.position=[995,225]
	c.actors.slime_2.position=[1010,215]
	c.actors.slime_2.mode="chase"
	c.cooldown=0.05
	maze.player.position=Roads.SPAWN
	sm.save()
	flow.set_process(true)
	await get_tree().create_timer(0.16).timeout
	_check(flow.shot_sprites.size()==1,"实际场景生成唯一投射物")
	if flow.shot_sprites.size()==1:
		var sprite: Sprite2D=flow.shot_sprites[0]
		_check(is_equal_approx(maxf(sprite.texture.get_width(),sprite.texture.get_height())*sprite.scale.x,32.0),"锅铲按alpha主体等比32像素")
	await _capture_image("projectile")
	sampling=true
	await get_tree().create_timer(1.0).timeout
	sampling=false
	_check(flow.monsters.slime_1.label.visible and flow.monsters.slime_2.label.visible,"真实场景两怪同时激活显示攻血")
	await _capture_image("multiple")
	await _click(maze.map_ui.mini_button)
	await get_tree().create_timer(0.1).timeout
	var frozen: Dictionary=Run.snapshot(sm).combat
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm).combat==frozen,"地图蒙层暂停全部战斗")
	await _send_key(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	_check(Run.snapshot(sm).combat.elapsed>frozen.elapsed,"地图关闭恢复")
	# 保留新教学原入口、对白与镜头恢复，只将说明替换为自动战斗。
	flow.set_process(false)
	sm.data.ch2_guide_01={"step":"explore","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data[Run.KEY].combat.actors.slime_1.hp=0
	flow.set_process(true)
	await get_tree().create_timer(1.2).timeout
	_check(maze.exploration_guide.reading and maze.exploration_guide.lesson_id=="05_power","首次击杀沿用教学入口")
	frozen=Run.snapshot(sm).combat
	await get_tree().create_timer(0.2).timeout
	_check(Run.snapshot(sm).combat==frozen,"教学对白暂停战斗")
	await _capture_image("lesson")
	for i in 8:
		await _send_key(KEY_E)
		await get_tree().create_timer(0.25).timeout
		if flow.dialog.visible: break
	_check(flow.dialog.visible,"教学结束继续真实击杀结算")
	# 结束后只允许原捕获步骤；本样例转为已完成教学，以检查失败退出重试。
	maze.exploration_guide._clear()
	sm.data.ch2_guide_01.step="done"
	flow.dialog.tutorial_only_yes=false
	await get_tree().create_timer(0.5).timeout
	await _click(flow.dialog._cancel_button)
	await get_tree().create_timer(0.4).timeout
	flow.set_process(false)
	sm.data[Run.KEY].combat.hp=0
	sm.data[Run.KEY].bag={"slime_gel":2}
	sm.save()
	flow.set_process(true)
	await get_tree().create_timer(0.5).timeout
	var save_path: String=sm._active_save_path
	sm._active_save_path=""
	var before: Dictionary=sm.data.duplicate(true)
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	_check(sm.data==before and flow.dialog.visible and flow.death_presented,"失败返回保存失败仍保留原袋并可重试")
	_check(not Run.finish(sm,true,Roads.EXIT).success,"零生命禁止正常出口带回")
	sm._active_save_path=save_path
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and Run.snapshot(sm).bag.is_empty(),"恢复保存后失败返回重试成功")
	await _close_scene()
	# 当前等级参与本趟冻结；下一趟才生效。
	_completed()
	sm.cancel_maze_entry()
	sm.data[Run.Progression.KEY]={"yaya":{"level":3,"exp":0,"rank":1,"breakthroughs":0},"tieshan":{"level":4,"exp":0,"rank":1,"breakthroughs":0}}
	_check(Run.begin(sm,Roads.SPAWN).success,"高于1级队伍建立新趟")
	_check(Run.snapshot(sm).combat.attack==11 and Run.snapshot(sm).combat.max_hp==52,"角色等级汇总攻击和生命公式")
	sm.data[Run.Progression.KEY].yaya.level=4
	_check(Run.snapshot(sm).combat.attack==11 and Run.snapshot(sm).combat.max_hp==52,"本趟属性不随中途角色记录变化")
