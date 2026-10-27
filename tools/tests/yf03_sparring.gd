extends "res://tools/tests/maze_capture.gd"
const Sim = preload("res://scripts/maze/yf_sparring.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"正式存档隔离")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _flow_yf()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _flow_yf() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"真实队伍出征")
	sm.record_maze_location("fenshui",Vector2(1399,283))
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	var e=maze.yf_encounter
	maze.capture_flow.window_focused=true
	_check(e.phase=="unseen" and e.idle.visible and e.idle.modulate.a==1,"入图密谋常驻无渐显")
	_check(Sim.Terrain.is_walkable(Sim.POSITIONS.yufeng) and Sim.Terrain.is_walkable(Sim.POSITIONS.salia),"两人脚底可走")
	await _capture_image("idle")
	Input.action_press("ui_left")
	Input.action_press("ui_down",0.4)
	await get_tree().create_timer(0.8).timeout
	Input.action_release("ui_left")
	Input.action_release("ui_down")
	_check(e.phase=="intro" and maze.player.input_locked,"真实行走触发与输入锁")
	if e.phase!="intro":
		maze.player.position=Vector2(1300,325)
		await get_tree().create_timer(0.2).timeout
	await _capture_image("intro")
	var before: Dictionary=sm.yufeng_salia_record()
	var save_path: String=sm._active_save_path
	sm._active_save_path=""
	e.dialog._advance()
	e.dialog._advance()
	_check(sm.yufeng_salia_record()==before and e.dialog.visible,"对白保存失败不假推进")
	sm._active_save_path=save_path
	for i in 8:
		await _send_key(KEY_E)
		await _send_key(KEY_E)
	_check(e.phase=="eat","完整八句进入吃料理")
	await _capture_image("eat")
	await get_tree().create_timer(3.2).timeout
	_check(e.phase=="question","吃料理后疑问",{"phase":e.phase,"clock":e.clock,"retry":e.retry,"focus":maze.capture_flow.window_focused})
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	_check(e.phase=="battle" and not maze.player.input_locked,"双人切磋启动恢复移动")
	if e.phase!="battle":
		maze.queue_free()
		await get_tree().process_frame
		return
	var original: Dictionary=Run.snapshot(sm)
	_check(e.run.combat.attack==original.combat.attack and e.run.members==original.members,"保留真实队伍总攻击和技能成员")
	_check(e.bars.size()==2,"双人血条")
	await get_tree().process_frame
	_check(maze.capture_flow.skill_bar.visible and maze.capture_flow.controls_hint.visible,"真实技能栏与操作提示可见")
	await _capture_image("battle")
	await _send_key(KEY_TAB)
	_check(e.run.combat.selected==1,"Tab切换真实队伍技能")
	await _send_key(KEY_SPACE)
	_check(e.run.combat.selected==0,"空格切回锅铲")
	var mouse := InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.position=maze.get_global_transform_with_canvas()*Sim.POSITIONS.yufeng
	mouse.pressed=true
	get_viewport().push_input(mouse)
	await get_tree().process_frame
	mouse.pressed=false
	get_viewport().push_input(mouse)
	_check(e.run.combat.throws>original.combat.throws,"左键真实攻击")
	var elapsed: float=e.run.combat.elapsed
	maze.capture_flow._focus_lost()
	await get_tree().create_timer(0.2).timeout
	_check(e.run.combat.elapsed==elapsed,"失焦战斗计时暂停")
	maze.capture_flow.window_focused=true
	# 独立规则样例不修改真实事件，用于越阈值、控制及连锁边界。
	var sample: Dictionary=Sim.create(original)
	Sim.hurt(sample,"yufeng",10000)
	var locked: float=sample.combat.actors.salia.hp
	Sim.hurt(sample,"salia",10000)
	_check(sample.combat.actors.yufeng.hp==1 and sample.combat.actors.salia.hp==locked and sample.combat.lock_left==3,"越阈值同帧双人锁血防致死")
	sample=Sim.create(original)
	sample.combat.control_left=0.3
	sample.combat.control_direction=[1.0,0.0]
	_check(not Sim.attack(sample,Vector2(1230,350),Vector2.RIGHT),"风刃控制期间禁攻")
	var p:=Vector2(1230,350)
	for i in 30: p=Sim.advance(sample,p,0.01,false)
	_check(Sim.Terrain.is_walkable(p) and p.distance_to(Vector2(1230,350))<=36.01,"三段击退36像素且不穿障碍")
	_check(Sim.conduction(Vector2(1000,450),{"hero":Vector2(1000,450)},"hero").is_empty(),"唯一玩家不重复传导")
	# 正式集成验收：只通过真实左键与弹道击中，不注入对手生命或伤害。
	# 当前触发点隔着植被岛边缘，沿道路向左走到真实可直射位置。
	Input.action_press("ui_left")
	await get_tree().create_timer(0.5).timeout
	Input.action_release("ui_left")
	_check(Sim.clear_line(maze.player.position,Sim.POSITIONS.yufeng),"沿路移动后获得合法射线")
	var health_history: Array=[]
	var deadline := Time.get_ticks_msec()+15000
	while e.phase=="battle" and e.run.combat.lock_left<0 and Time.get_ticks_msec()<deadline:
		var before_hp: float=e.run.combat.actors.yufeng.hp
		mouse.position=maze.get_global_transform_with_canvas()*Sim.POSITIONS.yufeng
		mouse.pressed=true
		get_viewport().push_input(mouse)
		await get_tree().process_frame
		mouse.pressed=false
		get_viewport().push_input(mouse)
		await get_tree().create_timer(0.72).timeout
		health_history.append({"before":before_hp,"after":e.run.combat.actors.yufeng.hp,"throws":e.run.combat.throws,"player":str(maze.player.position),"aim":e.run.combat.aim})
	_check(e.phase=="battle" and e.run.combat.lock_left>=0 and e.run.combat.actors.yufeng.hp<=9,"真实左键弹道达到御风半血",{"history":health_history})
	if e.run.combat.lock_left<0:
		maze.queue_free()
		await get_tree().process_frame
		return
	var frozen_y: float=e.run.combat.actors.yufeng.hp
	var frozen_s: float=e.run.combat.actors.salia.hp
	await _capture_image("threshold")
	await get_tree().create_timer(1).timeout
	_check(e.phase=="battle" and e.run.combat.lock_left>0 and e.run.combat.actors.yufeng.hp==frozen_y and e.run.combat.actors.salia.hp==frozen_s,"实际命中阈值后双方锁血等待")
	var saw_black := false
	var fade_deadline := Time.get_ticks_msec()+5000
	while e.phase=="battle" and Time.get_ticks_msec()<fade_deadline:
		if e.curtain.color.a>0.95 and not saw_black:
			saw_black=true
			await _capture_image("blackout")
		await get_tree().process_frame
	_check(saw_black,"真实锁血结束绘制黑屏")
	await get_tree().create_timer(0.4).timeout
	_check(e.curtain.color.a==0,"战后揭幕恢复画面")
	_check(e.phase=="post" and e.dialog.visible,"三秒后黑屏进入战后")
	await _capture_image("post")
	for i in 3:
		await _send_key(KEY_E)
		await _send_key(KEY_E)
	_check(e.phase=="gift_reward" and sm.yufeng_salia_state()=="gift_reward","战后三句接真实赠礼持久阶段")
	_check(Run.snapshot(sm).combat.hp==original.combat.hp and Run.snapshot(sm).bag==original.bag,"恢复开战前生命且不丢物")
	_check(maze.player.input_locked,"战后赠礼接续输入锁")
	await _capture_image("gift_reward")
	maze.queue_free()
	await get_tree().process_frame
	sm.load_data()
	_check(sm.yufeng_salia_state()=="gift_reward","读档保留奖励展示不提前完成")
