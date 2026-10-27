extends "res://tools/tests/combat_08_mouse_regression.gd"

var sequences: Array = []
const CENTER := Vector2(933,269)
const ALONG := Vector2(0.924,-0.383)

func _fixture(point := CENTER, source := CENTER - ALONG * 20.0) -> void:
	maze.capture_flow.set_process(false)
	maze.player.position = point
	var run: Dictionary = sm.data[Run.KEY]
	run.pending = ""
	run.combat = Combat.create(3,36,point,Run.monsters_for(run))
	run.combat.layout = run.layout.duplicate(true)
	for id in run.monsters:
		run.monsters[id].status = "skipped"
		run.monsters[id].respawn_at = float(run.maze_elapsed) + 600.0
	run.monsters.slime_1.status = "alive"
	var actor: Dictionary = run.combat.actors.slime_1
	actor.position = Combat.pack(source)
	actor.mode = "windup"
	actor.windup = 0.01
	actor.cooldown = 1.8
	maze.capture_flow.combat_time = 0.0
	maze.capture_flow.save_retry_delay = 0.0

func _tick(dt: float) -> void:
	var result := Run.combat_tick(sm,maze.player.position,dt)
	_check(result.success,"真实战斗事务推进",result)
	maze.player.position = Combat.vec(Run.snapshot(sm).combat.hero)
	maze.capture_flow.combat_time = 0.0
	maze.capture_flow._process(0.0)

func _sequence(label: String, target: String, dt: float) -> void:
	var c: Dictionary = Run.snapshot(sm).combat
	var a: Dictionary = c if target == "hero" else c.actors[target]
	sequences.append({"case":label,"dt":dt,"position":c.hero if target == "hero" else a.position,"remaining":a.get("hit_remaining",0.0),"flash":a.get("flash_remaining",0.0)})

func _feedback_checks() -> void:
	_fixture()
	_tick(0.01)
	var c: Dictionary = Run.snapshot(sm).combat
	_check(c.hp == 33 and is_equal_approx(c.hit_remaining,0.12),"真实近战扣血触发主角反馈")
	_check(Combat.vec(c.hit_velocity).dot(ALONG)>149.0,"主角沿远离实际攻击来源方向")
	_sequence("主角","hero",0.0)
	_check(maze.player.body.material.get_shader_parameter("flash"),"主角身体闪白开启")
	_check(maze.player.get_node("GroundShadow").material == null and maze.capture_flow.health_bar.material == null and maze.capture_flow.hp_label.material == null,"阴影血条文字无白闪材质")
	await _capture_image("hero_white")
	var start: Vector2 = maze.player.position
	for dt in [0.05,0.05,0.02]:
		_tick(dt)
		_sequence("主角","hero",dt)
		if dt == 0.05 and is_equal_approx(Run.snapshot(sm).combat.hit_remaining,0.02):
			_check(not maze.player.body.material.get_shader_parameter("flash"),"主角0.1秒结束白闪")
	_check(absf(maze.player.position.distance_to(start)-18.0)<0.001,"主角0.12秒击退18像素")
	_check(float(Run.snapshot(sm).combat.hit_remaining)<0.00001,"主角击退计时清零")
	await _capture_image("hero_after")
	# 两只实际近战同帧命中，不能因首个反馈吞掉第二次伤害。
	_fixture()
	var run: Dictionary = sm.data[Run.KEY]
	run.monsters.slime_2.status = "alive"
	run.combat.actors.slime_2 = run.combat.actors.slime_1.duplicate(true)
	run.combat.actors.slime_2.position = Combat.pack(CENTER + ALONG * 20.0)
	_tick(0.01)
	c = Run.snapshot(sm).combat
	_check(c.hp == 30,"多怪同时命中每次扣3生命，无无敌期")
	_check(Combat.vec(c.hit_velocity).dot(ALONG)<-149.0,"同帧后命中来源更新方向")
	sm.data[Run.KEY].combat.actors.slime_1.mode="windup"
	sm.data[Run.KEY].combat.actors.slime_1.windup=0.01
	_tick(0.01)
	_check(Run.snapshot(sm).combat.hp == 27,"闪白期间连续真实命中仍扣血")
	# 实际鼠标经未处理事件发射，使用隔离位置但不直接设置命中/白闪。
	_fixture(CENTER,CENTER-ALONG*45.0)
	sm.data[Run.KEY].combat.actors.slime_1.mode="idle"
	sm.data[Run.KEY].combat.cooldown=0.0
	await _attack_click()
	_check(Run.snapshot(sm).combat.throws==1,"真实鼠标发射锅铲")
	var before_hit: Dictionary
	for i in 35:
		before_hit = sm.data.duplicate(true)
		_tick(0.01)
		if Run.snapshot(sm).combat.hits>0: break
	c=Run.snapshot(sm).combat
	_check(c.hits==1 and c.actors.slime_1.hp==11,"真实弹道单体命中扣血")
	var monster=maze.capture_flow.monsters.slime_1
	_check(monster.body.material.get_shader_parameter("flash") and monster.shadow.material==null and monster.label.material==null,"魔物只身体闪白")
	var actual_hit: Dictionary = sm.data.duplicate(true)
	await _capture_image("monster_white")
	start=Combat.vec(c.actors.slime_1.position)
	_sequence("魔物","slime_1",0.0)
	for dt in [0.05,0.05,0.02]:
		_tick(dt)
		_sequence("魔物","slime_1",dt)
	_check(absf(Combat.vec(Run.snapshot(sm).combat.actors.slime_1.position).distance_to(start)-12.0)<0.001,"魔物0.12秒击退12像素")
	_check(not monster.body.material.get_shader_parameter("flash"),"魔物闪白结束")
	await _capture_image("monster_after")
	# 重放已实际命中的那一步，仅切换写盘失败条件。
	var completed_hit: Dictionary = sm.data.duplicate(true)
	sm.data = before_hit.duplicate(true)
	var projectile_path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Run.combat_tick(sm,Combat.vec(before_hit[Run.KEY].combat.hero),0.01).success and sm.data==before_hit,"弹道命中保存失败还原伤害白闪击退与弹道")
	sm._active_save_path = projectile_path
	sm.data = completed_hit
	sm.data = actual_hit.duplicate(true)
	sm.data[Run.KEY].combat.actors.slime_1.mode = "return"
	_tick(0.01)
	_check(not Run.snapshot(sm).combat.actors.slime_1.has("hit_remaining") and not monster.body.material.get_shader_parameter("flash"),"返航取消真实命中的剩余反馈")
	# 路边由合法来源实际命中，沿射线截断而非沿墙滑动。
	var edge := Vector2(933,289)
	_fixture(edge,edge-Vector2(0,20))
	_tick(0.01)
	_tick(0.12)
	_check(Roads.is_walkable(maze.player.position) and maze.player.position.distance_to(edge)<18.0 and is_equal_approx(maze.player.position.x,edge.x),"道路边缘击退截断，不穿墙也不滑墙")
	var before_gate: Dictionary = sm.data.duplicate(true)
	_fixture(Vector2(653,1075),Vector2(653,1064))
	sm.data[Run.KEY].layout[0].position = [653,1064]
	sm.data[Run.KEY].combat.layout = sm.data[Run.KEY].layout.duplicate(true)
	_tick(0.01)
	_check(Run.snapshot(sm).combat.hp==33,"栅栏样例真实近战命中，未被返航门禁跳过")
	for i in 9: maze.capture_flow._process(0.01)
	_check(maze.player.body.material.get_shader_parameter("flash"),"撞墙截断后白闪在0.09秒仍在")
	maze.capture_flow._process(0.01)
	_check(not maze.player.body.material.get_shader_parameter("flash"),"撞墙截断后白闪仍于0.1秒结束")
	_check(maze.player.position.y<=1077.0 and maze.player.position.y>=1075.0 and Roads.is_walkable(maze.player.position),"栅栏实体前击退截断")
	sm.data = before_gate
	# 真实保存失败必须连同扣血、反馈和位置回滚。
	_fixture()
	var path: String=sm._active_save_path
	sm._active_save_path=""
	var original: Dictionary=sm.data.duplicate(true)
	_check(not Run.combat_tick(sm,CENTER,0.01).success and sm.data==original,"命中保存失败整体回滚且没有残留反馈")
	sm._active_save_path=path
	_tick(0.01)
	_tick(0.05)
	_check(sm.save(),"受击半途写盘")
	var saved: Dictionary=Run.snapshot(sm).combat
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm).combat,saved),"重载保持剩余反馈与位置，不重放")
	_tick(0.07)
	_check(maze.player.position.distance_to(CENTER+ALONG.normalized()*18.0)<0.001,"重载只补剩余击退")
	# 旧字段缺省以及非法数据验证。
	_fixture()
	_check(Run.valid(Run.snapshot(sm)),"旧档无受击字段仍有效")
	sm.data[Run.KEY].combat.hit_remaining=-1.0
	_check(not Run.valid(Run.snapshot(sm)),"非法受击时间拒绝")
	_fixture()
	sm.data[Run.KEY].combat.hp=3
	_tick(0.01)
	_check(Run.snapshot(sm).combat.hp==0 and not Run.snapshot(sm).combat.has("hit_remaining"),"致死命中清理反馈")
	_check(not maze.player.body.material.get_shader_parameter("flash"),"失败结算无白闪残留")

func _pause_checks() -> void:
	_fixture()
	_tick(0.01)
	var flow=maze.capture_flow
	flow.set_process(true)
	flow._focus_lost()
	var frozen: Dictionary=Run.snapshot(sm).combat
	await get_tree().create_timer(0.2).timeout
	_check(Run.snapshot(sm).combat==frozen,"失焦冻结受击位移与闪白时间")
	flow.window_focused=true
	maze.player.input_locked=true
	await get_tree().create_timer(0.15).timeout
	_check(Run.snapshot(sm).combat==frozen,"输入锁定冻结受击状态")
	maze.player.input_locked=false
	maze.player.set_physics_process(false)
	await get_tree().create_timer(0.15).timeout
	_check(Run.snapshot(sm).combat==frozen,"物理处理关闭冻结受击状态")
	maze.player.set_physics_process(true)
	maze._open_backpack()
	await get_tree().create_timer(0.15).timeout
	_check(Run.snapshot(sm).combat==frozen,"背包冻结受击状态")
	await _send_key(KEY_ESCAPE)
	await get_tree().create_timer(0.18).timeout
	_check(float(Run.snapshot(sm).combat.get("hit_remaining",0.0))<0.00001 and not maze.player.body.material.get_shader_parameter("flash"),"恢复后自然结束受击")
	_fixture()
	_tick(0.01)
	flow.set_process(true)
	Input.action_press("ui_right")
	await _key_state(KEY_SHIFT,true)
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_right")
	await _key_state(KEY_SHIFT,false)
	_check(maze.player.position.x>CENTER.x and Roads.is_walkable(maze.player.position),"移动及Shift叠加受击保持合法位置")
	flow.set_process(false)
	_tick(0.01)
	_check(Combat.vec(Run.snapshot(sm).combat.hero).distance_to(maze.player.position)<0.001 and Combat.vec(sm.data[sm.MAZE_STATE_KEY].position).distance_to(maze.player.position)<0.001,"移动击退模拟与存档位置一致，无回弹")

func _kill_feedback() -> void:
	_fixture(CENTER,CENTER-ALONG*45.0)
	sm.data[Run.KEY].combat.actors.slime_1.mode = "idle"
	sm.data[Run.KEY].combat.actors.slime_1.hp = 3
	sm.data[Run.KEY].combat.cooldown = 0.0
	await _attack_click()
	for i in 35:
		_tick(0.01)
		if Run.snapshot(sm).combat.actors.slime_1.hp == 0: break
	_check(Run.snapshot(sm).combat.actors.slime_1.hp==0 and maze.capture_flow.dialog.visible,"真实锅铲击杀进入原胜利结算")
	_check(not Run.snapshot(sm).combat.actors.slime_1.has("hit_remaining") and not maze.capture_flow.monsters.slime_1.body.material.get_shader_parameter("flash"),"击杀结算没有白闪击退残留")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		suffix="_%dx%d" % [resolution.x,resolution.y]
		await _new_scene()
		await _feedback_checks()
		# 致死测试锁定场景，重新建立场景测暂停与输入。
		await _close_scene()
		await _new_scene()
		await _pause_checks()
		await _close_scene()
		await _new_scene()
		await _kill_feedback()
		await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"sequences":sequences,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
