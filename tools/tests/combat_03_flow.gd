extends "res://tools/tests/maze_capture.gd"
const Combat = preload("res://scripts/maze/combat_simulation.gd")
var diagnostics: Array = []

func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _scene_cycle()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"diagnostics":diagnostics,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _scene_cycle() -> void:
	_completed(); sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"建立生产随机新趟")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze); get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	var flow = maze.capture_flow
	flow.set_process(false)
	var run := Run.snapshot(sm)
	_check(flow.monsters.size()==10 and run.combat.actors.size()==10,"真实场景十节点十活体且无隐藏缺失")
	for id in flow.monsters: _check(run.monsters[id].status=="alive" and flow.monsters[id].visible,"新趟活体可见："+id)
	await _capture_image("random_entry")
	var id := "slime_1"
	# 场景隔离夹具只暂停其他九只的生命周期；目标保持生产满血/攻击/射击数值。
	for other in run.monsters:
		if other!=id:
			run.monsters[other].status="skipped"
			run.monsters[other].respawn_at=100000.0
	sm.data[Run.KEY]=run; sm.save()
	var old_home: Vector2 = Run.monster_for(run,id).position
	await _fight_and_capture(id,"first")
	if not flow.reward.visible:
		maze.queue_free(); await get_tree().process_frame; return
	flow.set_process(false)
	run=Run.snapshot(sm)
	var first_bag: Dictionary=run.bag.duplicate(true)
	var first_used: bool=run.first_used
	var cursor: int=run.food_cursor
	var yaya: int=run.yaya_counter
	var old_rolls: Array=[run.monsters[id].capture_roll,run.monsters[id].drop_roll,run.monsters[id].copy_roll,run.monsters[id].extra_roll]
	_check(run.monsters[id].respawn_at>=60.0,"死亡按运行时钟建立60秒冷却")
	await _click(flow.reward._confirm_button)
	await get_tree().process_frame
	_check(not flow.busy and not maze.player.input_locked,"收下奖励恢复输入")
	maze.player.position=Roads.SPAWN
	maze.camera.snap_to_target()
	await get_tree().process_frame
	await get_tree().process_frame
	run=Run.snapshot(sm)
	run.maze_elapsed=float(run.monsters[id].respawn_at)-0.1
	sm.data[Run.KEY]=run
	var before: Dictionary=sm.data.duplicate(true)
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05,flow.visible_world_rect()).success and Run.snapshot(sm).monsters[id].status=="captured","冷却结束前不刷新")
	# 把全图视作镜头：即使冷却到期且距离足够，也没有合法镜头外候选。
	_check(Run.combat_tick(sm,Roads.SPAWN,0.1,Rect2(Vector2.ZERO,Roads.SIZE)).success and Run.snapshot(sm).monsters[id].status=="captured","全图镜头内延后刷新")
	run=Run.snapshot(sm)
	var rng_before: String=run.spawn_rng_state
	_check(not Run.safe_spawn(run,id,old_home,old_home+Vector2(1,0),Rect2(-1000,-1000,10,10)),"260以内拒绝候选")
	_check(not Run.safe_spawn(run,id,old_home,Roads.SPAWN,Rect2(old_home-Vector2(20,20),Vector2(40,40))),"镜头内拒绝候选")
	# 保存失败必须连随机源与新位置一起回滚；修复保存后重试得到同一候选。
	var path: String=sm._active_save_path
	before=sm.data.duplicate(true)
	var expected: Dictionary=Run.snapshot(sm)
	expected.maze_elapsed+=0.05
	_check(Run.refresh_due(expected,Roads.SPAWN,flow.visible_world_rect()),"诊断：实际镜头外存在安全候选")
	sm._active_save_path=""
	var failed:=Run.combat_tick(sm,Roads.SPAWN,0.05,flow.visible_world_rect())
	_check(not failed.success and sm.data==before,"刷新保存失败全状态原子回滚")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05,flow.visible_world_rect()).success,"移开后安全刷新")
	run=Run.snapshot(sm)
	var home: Vector2=Run.monster_for(run,id).position
	diagnostics.append({"old_home":str(old_home),"new_home":str(home),"hero":str(Roads.SPAWN),"visible":str(flow.visible_world_rect()),"deadline":run.monsters[id].respawn_at,"elapsed":run.maze_elapsed})
	_check(run.monsters[id].status=="alive" and run.monsters[id].refresh_count==1,"同ID新生命且只刷新一次")
	_check(home!=old_home and Roads.is_walkable(home) and Run.safe_spawn(run,id,home,Roads.SPAWN,flow.visible_world_rect()),"普通怪重新选择安全道路出生点")
	_check(run.monsters[id]==expected.monsters[id] and run.layout==expected.layout and run.spawn_rng_state==expected.spawn_rng_state,"保存失败重试不重抽刷新位置或随机")
	_check(run.combat.actors[id].hp==14 and run.combat.actors[id].mode=="idle" and run.combat.actors[id].windup==0.0 and run.combat.actors[id].away==0.0 and run.combat.actors[id].velocity==[0.0,0.0],"新生命完整重置HP和AI")
	_check(not run.monsters[id].guaranteed and not run.monsters[id].has("attempt") and old_rolls!=[run.monsters[id].capture_roll,run.monsters[id].drop_roll,run.monsters[id].copy_roll,run.monsters[id].extra_roll],"新生命重置捕获保底付费及四随机")
	_check(run.first_used==first_used and run.food_cursor==cursor and run.yaya_counter==yaya and run.bag==first_bag and run.spawn_rng_state!=rng_before,"本趟保底付款游标芽芽次数奖励保留")
	# 受控返航残血样例，实际场景推进到本次新出生点并恢复满血。
	run.combat.actors[id].position=Combat.pack(Roads.move_on_road(home,Vector2(12,0)))
	run.combat.actors[id].mode="return"; run.combat.actors[id].hp=1
	sm.data[Run.KEY]=run; sm.save()
	flow.set_process(true)
	await get_tree().create_timer(0.5).timeout
	flow.set_process(false)
	run=Run.snapshot(sm)
	_check(Combat.vec(run.combat.actors[id].position).distance_to(home)<2 and run.combat.actors[id].hp==14,"实际返航回到新home并满血")
	# 第二生命只固定捕获抽样，击杀仍须满14HP、原伤害与真实弹道。
	sm.data[Run.KEY].monsters[id].capture_roll=0.0
	await _fight_and_capture(id,"second")
	run=Run.snapshot(sm)
	_check(run.monsters[id].status=="captured" and run.monsters[id].refresh_count==1,"第二生命可再次捕获")
	_check(run.satiety==1 and run.bag!=first_bag,"两生命分别付费并获得独立奖励")
	flow.set_process(false)
	if flow.reward.visible: await _click(flow.reward._confirm_button)
	_boss_checks()
	_migration_checks()
	maze.queue_free(); await get_tree().process_frame

func _fight_and_capture(id: String, label: String) -> void:
	var flow=maze.capture_flow
	flow.set_process(false)
	var run:=Run.snapshot(sm)
	var home: Vector2=Run.monster_for(run,id).position
	maze.player.position=Roads.move_on_road(home,Vector2(12,0))
	maze.camera.snap_to_target()
	_check(run.combat.actors[id].hp==14,"满血开始真实自动战斗："+label)
	var hits: int=run.combat.hits
	flow.set_process(true)
	var started:=Time.get_ticks_msec()
	while not flow.dialog.visible and Time.get_ticks_msec()-started<15000:
		await get_tree().create_timer(0.1).timeout
	run=Run.snapshot(sm)
	_check(flow.dialog.visible and flow.dialog.victory and run.pending==id and run.combat.hits>=hits+5,"至少五次真实弹道命中击杀："+label)
	if not flow.dialog.visible: return
	await _capture_image(label+"_victory")
	var frozen:=Run.snapshot(sm)
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm)==frozen,"待捕获窗口冻结运行时钟与生命："+label)
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.8).timeout
	_check(flow.attempt.visible and flow.attempt.mode=="ready","新版捕获详情："+label)
	await _capture_image(label+"_capture_ready")
	var food: float=Run.snapshot(sm).satiety
	await _click(flow.attempt.yes_button)
	await get_tree().create_timer(0.2).timeout
	_check(Run.snapshot(sm).satiety==food-1 and Run.snapshot(sm).monsters[id].has("attempt"),"确认捕获只扣一次饱腹："+label)
	await get_tree().create_timer(2.6).timeout
	for i in 80:
		await _send_key(KEY_J)
		await get_tree().create_timer(0.07).timeout
		if i==20: await _capture_image(label+"_j_operation")
		if flow.reward.visible: break
	await get_tree().create_timer(0.8).timeout
	_check(flow.reward.visible and Run.snapshot(sm).monsters[id].status=="captured","真实J操作与奖励结算："+label)
	await _capture_image(label+"_reward")
	frozen=Run.snapshot(sm)
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm)==frozen,"奖励未收下不得刷新或计时："+label)
	_check(not Run.resolve(sm,id,true).success and Run.snapshot(sm)==frozen,"同生命奖励最多一次："+label)

func _boss_checks() -> void:
	var run:=Run.snapshot(sm)
	var boss: Dictionary=run.monsters.lizard_1
	boss.status="skipped"; boss.respawn_at=run.maze_elapsed
	run.combat.actors.lizard_1.hp=0
	sm.data[Run.KEY]=run
	var home:=Vector2(270,720)
	_check(Run.combat_tick(sm,home,0.05,Rect2(-1000,-1000,10,10)).success and Run.snapshot(sm).monsters.lizard_1.status=="skipped","首领260以内不刷")
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(100,500,500,400)).success and Run.snapshot(sm).monsters.lizard_1.status=="skipped","首领镜头内不刷")
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(850,0,370,300)).success,"首领安全刷新事务")
	run=Run.snapshot(sm)
	_check(run.monsters.lizard_1.status=="alive" and Run.monster_for(run,"lizard_1").position==home and run.combat.actors.lizard_1.hp==84,"首领固定原点满血刷新")
	_check(Run.respawn_delay("slime")==60 and Run.respawn_delay("snail")==90 and Run.respawn_delay("beetle")==90 and Run.respawn_delay("lizard")==180,"四类运行时间冷却")

func _migration_checks() -> void:
	var run:=Run.snapshot(sm)
	run.combat.actors.slime_2.hp=0
	run.monsters.slime_2.status="alive"
	sm.data[Run.KEY]=run
	_check(Run.defeat(sm,"slime_2",Roads.SPAWN).success,"迁移样例建立待捕获")
	_check(Run.start_capture(sm,"slime_2").success,"迁移样例保存已付费")
	sm.data[Run.KEY].erase("layout")
	sm.data[Run.KEY].erase("spawn_rng_state")
	run=Run.snapshot(sm)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	var previous: Dictionary=sm.data.duplicate(true)
	_check(not Run.begin(sm,Roads.SPAWN).success and sm.data==previous,"补布局保存失败回滚")
	sm._active_save_path=path
	_check(Run.begin(sm,Roads.SPAWN).success,"当前战斗档缺布局安全补存")
	var restored:=Run.snapshot(sm)
	_check(restored.layout==run.combat.layout and restored.combat==run.combat and restored.monsters==run.monsters and restored.bag==run.bag and restored.food_cursor==run.food_cursor and restored.pending==run.pending,"补布局不刷血不重抽不丢pending付款奖励")
	_check(Run.start_capture(sm,"slime_2").get("resumed",false) and Run.snapshot(sm).satiety==restored.satiety,"迁移后已支付不重复扣费")
