extends "res://tools/tests/maze_capture.gd"
const Combat = preload("res://scripts/maze/combat_simulation.gd")
var timings: Array = []

func _key_state(key: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode=key
	event.physical_keycode=key
	event.pressed=pressed
	event.echo=echo
	Input.parse_input_event(event)
	await get_tree().process_frame


func _mouse_state(pressed: bool, point := Vector2(600,420)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position=point
	event.pressed=pressed
	get_viewport().push_input(event)
	await get_tree().process_frame

func _attack_click() -> void:
	await _mouse_state(true)
	await _mouse_state(false)

func _manual_checks() -> void:
	var flow=maze.capture_flow
	await _send_key(KEY_J)
	_check(Run.snapshot(sm).combat.throws==0,"J不再战斗攻击")
	await _mouse_state(true)
	var count: int=Run.snapshot(sm).combat.throws
	_check(count==1,"单击一次只发一枚")
	for i in 8:
		await get_tree().process_frame
		await get_tree().create_timer(0.14).timeout
	_check(Run.snapshot(sm).combat.throws==count,"长按超过冷却不重复发射")
	await _mouse_state(false)
	await _attack_click()
	_check(Run.snapshot(sm).combat.throws==count+1,"松开重按再次发射")
	await _attack_click()
	_check(Run.snapshot(sm).combat.throws==count+1,"冷却中连按无效且不排队")
	await get_tree().create_timer(1.0).timeout
	_check(Run.snapshot(sm).combat.throws==count+1,"冷却结束不补发")
	flow._focus_lost()
	var frozen: Dictionary=Run.snapshot(sm).combat
	await _attack_click()
	await get_tree().create_timer(0.15).timeout
	_check(Run.snapshot(sm).combat==frozen,"失焦冻结战斗并丢弃单击")
	flow.window_focused=true
	await get_tree().create_timer(0.15).timeout
	_check(Run.snapshot(sm).combat.throws==count+1,"回焦无积攒攻击")

func _sprint_checks() -> void:
	var flow=maze.capture_flow
	flow.set_process(false)
	# 隔离运动测量；真实按键与实际道路移动，怪物时钟暂不推进。
	maze.player.position=Vector2(790,326)
	Input.action_press("ui_right")
	var origin: Vector2=maze.player.position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var normal: float=maze.player.position.distance_to(origin)
	maze.player.position=origin
	await _key_state(KEY_SHIFT,true)
	origin=maze.player.position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fast: float=maze.player.position.distance_to(origin)
	_check(absf(fast/normal-1.5)<0.05,"Shift实际道路速度1.5倍",{"normal":normal,"fast":fast})
	Input.action_release("ui_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not maze.player.sprinting,"Shift按住静止不加速")
	await _key_state(KEY_SHIFT,false)
	maze.player.position=Roads.SPAWN
	var run: Dictionary=Run.snapshot(sm)
	for id in run.monsters: run.monsters[id].status="skipped"
	var food: float=run.satiety
	for i in 100: Combat.advance(run,Roads.SPAWN,0.05,true)
	_check(float(run.combat.sprint)<0.00001,"满条持续5秒耗尽")
	for i in 20: Combat.advance(run,Roads.SPAWN,0.05,false)
	_check(float(run.combat.sprint)<0.00001,"停止加速1秒内不恢复")
	for i in 80: Combat.advance(run,Roads.SPAWN,0.05,false)
	_check(absf(run.combat.sprint-0.5)<0.001,"恢复4秒回半条")
	for i in 80: Combat.advance(run,Roads.SPAWN,0.05,false)
	_check(absf(run.combat.sprint-1.0)<0.001 and run.satiety==food,"恢复8秒回满且饱腹不变")
	sm.data[Run.KEY].combat.sprint=0.0
	await _key_state(KEY_SHIFT,true)
	Input.action_press("ui_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not maze.player.sprinting,"空条退回普通移动")
	Input.action_release("ui_left")
	await _key_state(KEY_SHIFT,false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	sm.data[Run.KEY].combat.sprint=0.5
	await _key_state(KEY_SHIFT,true)
	Input.action_press("ui_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(maze.player.sprinting,"恢复后新按Shift可再次加速")
	maze._open_backpack()
	flow._process(0.0)
	_check(not maze.player.sprint_held and not maze.player.sprinting,"弹窗清除加速按住状态")
	await _send_key(KEY_ESCAPE)
	Input.action_release("ui_left")
	await _key_state(KEY_SHIFT,false)
	maze.player.position=Roads.SPAWN
	flow.set_process(true)
	await get_tree().create_timer(0.1).timeout
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _combat_scene()
	var report := {"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path,"timings":timings}
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	get_tree().quit(1 if failures else 0)

func _new_scene() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"新趟初始化")
	# COMBAT-02 的近出生点场景明确使用固定布局夹具；生产新趟仍为随机布局。
	var run: Dictionary = sm.data[Run.KEY]
	run.layout = []
	run.monsters = {}
	for row in Catalog.all():
		run.layout.append({"kind":row.kind,"position":Combat.pack(row.position)})
		run.monsters[row.id] = {"status":"alive","capture_roll":0.0,"drop_roll":0.0,"copy_roll":0.99,"extra_roll":0.99,"guaranteed":false,"respawn_at":0.0,"spawn_position":Combat.pack(row.position),"refresh_count":0}
	run.combat = Combat.create(3,36,Roads.SPAWN,Catalog.all())
	_check(sm.save(),"显式固定布局夹具保存")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.toast_label.dismiss()

func _close_scene() -> void:
	if is_instance_valid(maze): maze.queue_free()
	elif is_instance_valid(get_tree().current_scene): get_tree().current_scene.queue_free()
	await get_tree().process_frame

func _combat_scene() -> void:
	await _new_scene()
	var flow=maze.capture_flow
	_check(maze._entry_ready and flow.monsters.size()==10,"真实迷宫当前固定10怪")
	_check(Run.snapshot(sm).combat.attack==3 and Run.snapshot(sm).combat.max_hp==36,"两位1级角色冻结攻击3生命36")
	_check(flow.power_label.visible and flow.power_label.text.contains("ATK:") and flow.hp_label.text.contains("HP:"),"主角攻血常显")
	await _capture_image("entry")
	var before: Vector2=maze.player.position
	Input.action_press("ui_left")
	await get_tree().create_timer(0.4).timeout
	Input.action_release("ui_left")
	_check(maze.player.position.distance_to(before)>20,"真实移动输入不被自动战斗阻塞")
	await get_tree().create_timer(0.7).timeout
	_check(Run.snapshot(sm).combat.throws==0,"射程内不单击不出手")
	await _manual_checks()
	await _sprint_checks()
	await _attack_click()
	_check(Run.snapshot(sm).combat.throws>=1,"鼠标真实单击出手")
	await _capture_image("combat")
	maze._open_backpack()
	await get_tree().create_timer(0.2).timeout
	var frozen: Dictionary=Run.snapshot(sm).combat
	await get_tree().create_timer(0.4).timeout
	_check(Run.snapshot(sm).combat==frozen,"背包期间怪物弹道与时钟全部冻结")
	await _send_key(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm).combat.elapsed>frozen.elapsed,"关闭背包恢复推进")
	flow._open_character_details("yaya")
	await get_tree().create_timer(0.2).timeout
	frozen=Run.snapshot(sm).combat
	await get_tree().create_timer(0.2).timeout
	_check(Run.snapshot(sm).combat==frozen and not flow.party_panel.is_visible_in_tree(),"详情暂停与队伍遮罩隐藏")
	await _send_key(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	# 使用同一实际流程控制样例，让第一只怪只需一次命中；不替换模拟或事务。
	flow.set_process(false)
	sm.data[Run.KEY].combat=Combat.create(3,36,Roads.SPAWN)
	sm.data[Run.KEY].combat.actors.slime_1.hp=3
	maze.player.position=Roads.SPAWN
	sm.save()
	flow.set_process(true)
	await get_tree().create_timer(1.0).timeout
	await _attack_click()
	await get_tree().create_timer(0.6).timeout
	_check(flow.dialog.visible and flow.dialog.victory and Run.snapshot(sm).pending=="slime_1","真实弹道击杀打开现有胜利窗")
	_check(Run.snapshot(sm).absorbed==0,"击杀不再吸收战力")
	await _capture_image("victory")
	frozen=Run.snapshot(sm).combat
	await _attack_click()
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm).combat==frozen,"胜利窗暂停战斗")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.4).timeout
	_check(flow.attempt.visible and flow.attempt.mode=="ready","胜利进入当前捕获操作准备页")
	await _capture_image("capture_ready")
	await _click(flow.attempt.yes_button)
	await get_tree().create_timer(0.2).timeout
	var capture_throws: int=Run.snapshot(sm).combat.throws
	var food: float=Run.snapshot(sm).satiety
	_check(Run.snapshot(sm).monsters.slime_1.has("attempt") and food==2,"捕获确认原子扣1饱腹")
	await get_tree().create_timer(2.6).timeout
	for i in 65:
		await _send_key(KEY_J)
		await get_tree().create_timer(0.08).timeout
		if flow.reward.visible: break
	await get_tree().create_timer(0.8).timeout
	_check(Run.snapshot(sm).bag.size()>0 and flow.reward.visible,"新捕获操作结算临时袋并显示原奖励")
	_check(Run.snapshot(sm).combat.throws==capture_throws,"捕获J不穿透战斗")
	var bag: Dictionary=Run.snapshot(sm).bag
	_check(not Run.resolve(sm,"slime_1",true).success and Run.snapshot(sm).bag==bag,"重复结算不重复材料")
	flow.reward.hide()
	flow._unlock()
	flow.set_process(false)
	# 保存与重新加载使用真实文件，完整飞行/前摇状态必须相同。
	sm.data[Run.KEY].combat.hp=25
	sm.data[Run.KEY].combat.actors.slime_2.mode="windup"
	sm.data[Run.KEY].combat.actors.slime_2.windup=0.2
	sm.data[Run.KEY].combat.shots=[{"origin":[995,225],"target":[933,269],"position":[970,242],"time":0.14}]
	_check(sm.save(),"受伤与飞行状态写盘")
	var saved: Dictionary=Run.snapshot(sm)
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),saved),"真实重载保留生命前摇弹道与奖励")
	var original_path: String=sm._active_save_path
	var original: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	sm.data[Run.KEY].combat.checkpoint=0.5
	original=sm.data.duplicate(true)
	_check(not Run.combat_tick(sm,maze.player.position,0.05).success and sm.data==original,"战斗保存失败全状态回滚")
	sm._active_save_path=original_path
	# 正常出口入库，失败和重复出口不入库。
	var stock: Dictionary=sm.warehouse_snapshot()
	maze.player.position=Roads.EXIT
	maze.return_to_restaurant(true)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and not Run.snapshot(sm).active,"正常出口实际返回餐厅")
	for item in bag: _check(sm.warehouse_snapshot().get(item,0)==stock.get(item,0)+bag[item],"出口材料进入仓库："+item)
	_check(not Run.finish(sm,true,Roads.EXIT).success,"不能重复出口领材料")
	await _close_scene()
	await _death_scene()
	_simulation_checks()

func _death_scene() -> void:
	await _new_scene()
	var flow=maze.capture_flow
	flow.set_process(false)
	var c: Dictionary=sm.data[Run.KEY].combat
	c.hp=1
	c.actors.slime_1.position=Combat.pack(Roads.SPAWN+Vector2(-10,5))
	c.actors.slime_1.mode="windup"
	c.actors.slime_1.windup=0.05
	sm.data[Run.KEY].bag={"slime_gel":2}
	var capture_throws: int=Run.snapshot(sm).combat.throws
	var food: float=Run.snapshot(sm).satiety
	var stock: Dictionary=sm.warehouse_snapshot()
	sm.save()
	flow.set_process(true)
	await get_tree().create_timer(0.3).timeout
	_check(flow.dialog.visible and flow.dialog._title_label.text=="探索失败","最后一击后显示失败布局")
	_check(flow.dialog.illustration_key=="slime_lose" and flow.dialog._confirm_button.text=="返回餐厅","失败使用最后一击魔物插画")
	await _capture_image("death")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and not Run.snapshot(sm).active,"失败按钮真实返回餐厅")
	_check(Run.snapshot(sm).bag.is_empty() and sm.warehouse_snapshot()==stock and Run.snapshot(sm).satiety==food,"死亡丢袋不返饱腹不入库")
	if is_instance_valid(get_tree().current_scene): get_tree().current_scene.queue_free()
	await get_tree().process_frame

func _simulation_checks() -> void:
	var run: Dictionary={"combat":Combat.create(3,36,Roads.SPAWN),"monsters":{}}
	for row in Catalog.all(): run.monsters[row.id]={"status":"alive"}
	var point := Roads.SPAWN
	var c: Dictionary=run.combat
	# 范围外不射击；0.9秒首发，0.35秒命中。
	for a in c.actors.values(): a.position=[300,700]
	for i in 20: Combat.advance(run,point,0.05)
	_check(c.throws==0,"射程180之外不出手")
	c.actors.slime_1.position=[995,225]
	c.actors.slime_1.mode="idle"
	Combat.attack(run,point)
	_check(c.throws==1,"最近有效目标入射程按键出手")
	for i in 17: Combat.advance(run,point,0.05)
	_check(c.throws==1,"0.9秒间隔前不重复出手")
	Combat.advance(run,point,0.05)
	Combat.attack(run,point)
	_check(c.throws==2 and c.hits>=1,"手动间隔与单体命中")
	c.shots=[{"origin":[995,225],"target":[933,269],"position":[995,225],"time":0.0}]
	for a in c.actors.values(): a.position=[300,700]
	c.cooldown=10.0
	var hits: int=c.hits
	for i in 8: Combat.advance(run,point,0.05)
	_check(c.shots.is_empty() and c.hits==hits,"非追踪弹道可以落空")
	c.shots=[{"origin":[527,544],"target":[1086,755],"position":[527,544],"time":0.0}]
	Combat.advance(run,point,0.05)
	_check(c.shots.is_empty(),"穿过树丛的弹道被阻挡")
	# 两只同时前摇，移出近战后不受伤。
	c.actors.slime_1.position=Combat.pack(point+Vector2(-15,5))
	c.actors.slime_2.position=Combat.pack(point+Vector2(-20,7))
	for id in ["slime_1","slime_2"]:
		c.actors[id].mode="chase"
		c.actors[id].cooldown=0.0
	Combat.advance(run,point,0.05)
	_check(c.actors.slime_1.mode=="windup" and c.actors.slime_2.mode=="windup","多怪独立近战前摇")
	var health: int=c.hp
	for i in 10: Combat.advance(run,Vector2(995,225),0.05)
	_check(c.hp==health,"前摇结束重检距离可以躲避")
	c.actors.slime_1.position=[1020,211]
	c.actors.slime_1.mode="return"
	c.actors.slime_1.hp=1
	c.cooldown=0.0
	for i in 20: Combat.advance(run,Vector2(270,720),0.05)
	_check(c.actors.slime_1.mode=="idle" and c.actors.slime_1.hp==14,"返航到原点恢复满血")
	_check(Roads.is_walkable(Combat.vec(c.actors.slime_1.position)),"怪物保持道路脚底可走")
	# 超出玩家脱战距离持续1秒后返回；回程不受命中也不被自动选择。
	c.actors.slime_2.position=[613,421]
	c.actors.slime_2.mode="chase"
	c.actors.slime_2.away=0.0
	for i in 21: Combat.advance(run,Vector2(1104,153),0.05)
	_check(c.actors.slime_2.mode in ["return","idle"],"超出脱战距离1秒返回")
	# 同次推进主角死亡优先，已飞行锅铲不再产生击杀。
	c.hp=1
	c.actors.slime_1.position=[995,225]
	c.actors.slime_1.mode="windup"
	c.actors.slime_1.windup=0.05
	c.actors.slime_1.hp=1
	c.shots=[{"origin":[995,225],"target":[995,225],"position":[995,225],"time":0.0}]
	Combat.advance(run,Vector2(995,225),0.05)
	_check(c.hp==0 and c.actors.slime_1.hp==1 and c.shots.is_empty(),"同刻死亡优先失败且不击杀结算")
	c.hp=36
	var start := Time.get_ticks_usec()
	for i in 10: Combat.advance(run,Vector2(613,421),0.05)
	var average := (Time.get_ticks_usec()-start)/10000.0
	timings.append({"simulation_average_ms":average})
	_check(average<16.0,"多怪模拟均耗时低于16毫秒")
