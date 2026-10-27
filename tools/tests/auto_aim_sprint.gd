extends "res://tools/tests/combat_02_flow.gd"
const Aim=preload("res://scripts/maze/auto_aim.gd")
const Sim=preload("res://scripts/maze/yf_sparring.gd")

func click_at(point: Vector2) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=point
	maze.capture_flow._unhandled_input(event)

func _combat_scene() -> void:
	await _new_scene()
	await get_tree().create_timer(0.6).timeout
	var flow=maze.capture_flow
	flow.set_process(false)
	flow.window_focused=true
	var run: Dictionary=sm.data[Run.KEY]
	for actor in run.combat.actors.values(): actor.mode="return"
	var id: String=Catalog.all()[0].id
	run.combat.actors[id].mode="idle"
	var enemy:=Combat.vec(run.combat.actors[id].position)
	maze.player.position=enemy+Vector2(40,-25)
	maze.player.facing=Vector2.RIGHT
	maze.camera.snap_to_target()
	run.combat.selected=0
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	_check(Roads.is_walkable(maze.player.position),"实际攻击站位在合法道路")
	_check(Aim.target(run,maze.player.position)==id,"最近存活目标进入自动瞄准")
	print("AIM READY ",flow.combat_paused()," point=",maze.player.position," enemy=",enemy," kind=",Combat.Skills.kind(run,0))
	click_at(Vector2(1100,50))
	_check(not sm.data[Run.KEY].combat.shots.is_empty(),"实际左键生成弹道")
	if sm.data[Run.KEY].combat.shots.is_empty(): await _close_scene(); return
	var shot: Dictionary=sm.data[Run.KEY].combat.shots.back()
	_check(Combat.vec(shot.target).x<maze.player.position.x,"点击右侧仍向左侧魔物发射")
	await _capture_image("auto_aim_left")
	var hp: float=sm.data[Run.KEY].combat.actors[id].hp
	for i in 12: Run.combat_tick(sm,maze.player.position,0.05)
	_check(sm.data[Run.KEY].combat.actors[id].hp<hp,"自动瞄准弹道实际命中扣血")
	var nearest_sample:=Run.snapshot(sm)
	for actor in nearest_sample.combat.actors.values(): actor.mode="return"
	var second: String=Catalog.all()[1].id
	nearest_sample.combat.selected=0
	nearest_sample.combat.actors[id].mode="idle"
	nearest_sample.combat.actors[id].hp=10
	nearest_sample.combat.actors[id].position=Combat.pack(maze.player.position+Vector2(-60,0))
	nearest_sample.combat.actors[second].mode="idle"
	nearest_sample.combat.actors[second].hp=10
	nearest_sample.combat.actors[second].position=Combat.pack(maze.player.position+Vector2(30,0))
	_check(Aim.target(nearest_sample,maze.player.position)==second,"多个有效目标选择最近者")
	nearest_sample.combat.actors[second].hp=0
	_check(Aim.target(nearest_sample,maze.player.position)==id,"最近目标死亡立即切换下一个")
	var sample:=Run.snapshot(sm)
	for actor in sample.combat.actors.values(): actor.mode="return"
	sample.combat.actors[id].hp=0
	_check(Aim.target(sample,maze.player.position).is_empty(),"死亡目标不选中")
	_check(Aim.direction(sample,maze.player.position,Vector2.UP)==Vector2.UP,"无目标沿角色朝向")
	sample=Run.snapshot(sm)
	for actor in sample.combat.actors.values(): actor.mode="return"
	sample.combat.actors[id].mode="return"
	_check(Aim.target(sample,maze.player.position).is_empty(),"回位目标不选中")
	sample.combat.actors[id].mode="idle"
	sample.combat.selected=2
	_check(Aim.target(sample,enemy+Vector2(100,0)).is_empty(),"铁山不锁定近战范围外目标")
	sample.combat.actors[id].position=Combat.pack(enemy)
	sample.combat.selected=1
	_check(Aim.target(sample,enemy+Vector2(-250,0))==id,"芽芽采用自己的远程范围")
	# 真实移动输入；先步行，再按住Shift，最后释放。
	maze.player.position=Vector2(860,295)
	maze.player.clear_combat_input()
	maze.player.facing=Vector2.LEFT
	Input.action_press("ui_left")
	await get_tree().create_timer(0.1).timeout
	_check(not maze.player.sprinting and maze.player.body.rotation==0,"普通步行无奔跑倾斜")
	await _capture_image("walking")
	maze.player.position=Vector2(860,295)
	flow.window_focused=true
	var key:=InputEventKey.new()
	key.keycode=KEY_SHIFT
	key.pressed=true
	get_viewport().push_input(key)
	await get_tree().create_timer(0.08).timeout
	print("SPRINT ",maze.player.position," paused=",flow.combat_paused()," held=",maze.player.sprint_held," moving=",maze.player._walking," rotation=",maze.player.body.rotation)
	_check(maze.player.sprinting and maze.player.body.rotation<0,"Shift实际移动启动加速动画")
	var time_before: float=maze.player._appearance._elapsed
	maze.player._appearance._elapsed=0
	maze.player._update_animation(0.02)
	_check(is_equal_approx(maze.player._appearance._elapsed,0.03),"加速步频为普通1.5倍")
	maze.player._appearance._elapsed=time_before
	await _capture_image("sprinting")
	sm.data[Run.KEY].combat.sprint=0.0
	await get_tree().create_timer(0.05).timeout
	_check(not maze.player.sprinting and maze.player.body.rotation==0,"体力耗尽恢复普通步行动画")
	key=InputEventKey.new()
	key.keycode=KEY_SHIFT
	key.pressed=false
	get_viewport().push_input(key)
	await get_tree().create_timer(0.05).timeout
	_check(not maze.player.sprinting and maze.player.body.rotation==0,"松开Shift恢复普通步行")
	Input.action_release("ui_left")
	await get_tree().create_timer(0.05).timeout
	_check(str(maze.player.animation_name).ends_with("_idle"),"停止移动恢复待机")
	await _close_scene()
	# 正式切磋场景也通过同一个左键入口自动瞄准。
	Run.change_region(sm,"fenshui",Sim.Terrain.SPAWN)
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	var e=maze.yf_encounter
	e.set_process(false)
	maze.player.position=Sim.POSITIONS.yufeng+Vector2(45,0)
	_check(e._commit("battle"),"建立正式切磋阶段")
	e._start_battle()
	e.run.combat.selected=1
	e.run.combat.cooldown=0.0
	var target:=Aim.target(e.run,maze.player.position,true)
	_check(not target.is_empty(),"切磋自动选择最近对手")
	click_at(Vector2.ZERO)
	var direction: Vector2=maze.player.position.direction_to(Combat.vec(e.run.combat.actors[target].position))
	_check(Combat.vec(e.run.combat.aim).dot(direction)>0.999,"切磋左键方向来自对手而非鼠标")
	e._sync_visuals()
	await _capture_image("sparring_auto_aim")
	e.run.combat.lock_left=0
	_check(Aim.target(e.run,maze.player.position,true).is_empty(),"切磋结束停止选敌")
	await _close_scene()
