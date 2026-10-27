extends "res://tools/tests/combat_02_flow.gd"
const B = preload("res://data/maze/fenshui_boss.gd")
const FS = preload("res://data/maze/fenshui_roads.gd")
const AI = preload("res://scripts/maze/wind_frog_combat.gd")

func _actor() -> Dictionary:
	return sm.data[Run.KEY].combat.actors[B.ID]

func _ticks(n: int, point: Vector2) -> void:
	for i in n:
		_check(Run.combat_tick(sm,point,0.05).success,"实际Boss事务推进"+str(i))

func _open_fenshui() -> void:
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.35).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"建立分水庭六怪和独立巨蛙")
	_check(B.allowed(B.HOME),"巨蛙中心完整身体在合法浅水")
	_check(Run.valid(Run.snapshot(sm)),"含巨蛙存档合法")
	_check(_actor().frog_phase=="dormant","未踏水前不出现")
	_check(Run.combat_tick(sm,B.HOME,0.05).success and _actor().frog_phase=="dormant","御风未完成不能出场")
	_check(sm.set_yufeng_salia_state("done").success,"御风事件完成夹具")
	var fish: String=Catalog.Fenshui.all()[0].id
	sm.data[Run.KEY].combat.actors[fish].mode="chase"
	_check(Run.combat_tick(sm,B.HOME,0.05).success and _actor().frog_phase=="dormant","普通战斗期间延后出场")
	_check(Run.combat_tick(sm,B.HOME,0.05).success and _actor().frog_phase=="emerging","普通战斗结束后有效踏水触发")
	var hp: float=sm.data[Run.KEY].combat.hp
	_ticks(8,B.HOME)
	_check(sm.data[Run.KEY].combat.hp==hp and _actor().frog_phase=="emerging","冒泡1秒内没有接触伤害")
	var saved: Dictionary=Run.snapshot(sm)
	await _close_scene()
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),saved),"出场中退出读档保留阶段剩余时间")
	await _open_fenshui()
	_check(maze.capture_flow.monsters.size()==7,"真实场景含六普通怪及巨蛙")
	maze.player.position=B.HOME+Vector2(50,0)
	maze.camera.snap_to_target()
	maze.capture_flow._process(0.0)
	_check(not maze.player.input_locked,"出场不冻结玩家")
	await _capture_image("01_emerging")
	_ticks(12,maze.player.position)
	_check(_actor().frog_phase=="active","恢复后出场完成且不重播")
	var sprite=maze.capture_flow.monsters[B.ID]
	for facing in 4:
		sprite._set_direction(facing)
		for act in ["idle","swim","attack","defeated"]:
			sprite.action=act
			sprite._draw_frame(2)
			_check(sprite.body.region_rect.size==Vector2(192,192),"统一动画画布"+act+str(facing))
	maze.capture_flow._process(0.0)
	await _capture_image("02_same_screen")
	var active: Dictionary=sm.data.duplicate(true)
	_state_cases(active)
	sm.data=active.duplicate(true)
	_actor().frog_jump=0.0
	_actor().cooldown=1.0
	_actor().mode="chase"
	_ticks(1,maze.player.position)
	maze.capture_flow._process(0.0)
	await _capture_image("03_locked_warning")
	_ticks(20,maze.player.position)
	_ticks(3,maze.player.position)
	maze.capture_flow._process(0.0)
	await _capture_image("04_airborne")
	_ticks(4,maze.player.position)
	maze.capture_flow._process(0.0)
	await _capture_image("05_landed")
	sm.data=active.duplicate(true)
	_actor().frog_jump=6.0
	_actor().cooldown=0.0
	_actor().mode="chase"
	_ticks(1,maze.player.position)
	_ticks(10,maze.player.position)
	maze.capture_flow._process(0.0)
	await _capture_image("06_spit_windup")
	_ticks(6,maze.player.position)
	maze.capture_flow._process(0.0)
	await _capture_image("07_water_projectile")
	# 实际玩家攻击击杀，经验由正式事务发放，击败不直接给胃囊。
	sm.data=active.duplicate(true)
	maze.player.position=B.HOME+Vector2(50,0)
	sm.data[Run.KEY].combat.attack=120
	sm.data[Run.KEY].combat.cooldown=0.0
	sm.data[Run.KEY].combat.action_left=0.0
	sm.data[Run.KEY].monsters[B.ID].capture_roll=0.0
	sm.data[Run.KEY].monsters[B.ID].copy_roll=0.99
	var xp_before := Run.Progression.record(sm,"yaya")
	_check(Run.combat_attack(sm,maze.player.position,Vector2.LEFT).success,"真实攻击巨蛙")
	_ticks(10,maze.player.position)
	_check(_actor().hp==0 and sm.data[Run.KEY].bag.is_empty(),"真实击杀不直接发肉")
	_check(sm.data[Run.KEY].monsters[B.ID].get("experience_generation",-1)==0,"击败经验事务仅登记一次")
	var xp_after := Run.Progression.record(sm,"yaya")
	var gained: int=xp_after.exp-xp_before.exp
	for level in range(xp_before.level,xp_after.level): gained+=Run.Progression.experience_required(level)
	_check(gained==120,"巨蛙击败实际经验120")
	_check(_actor().frog_shots.is_empty(),"击败立即清理巨蛙水团")
	maze.capture_flow._process(0.0)
	await get_tree().create_timer(0.8).timeout
	maze.capture_flow._process(0.0)
	_check(maze.capture_flow.dialog.visible,"倒地后打开原胜利窗")
	await get_tree().create_timer(0.4).timeout
	await _capture_image("08_victory")
	await _click(maze.capture_flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	maze.capture_flow._process(0.0)
	_check(maze.capture_flow.attempt.visible and maze.capture_flow.attempt.name_label.text=="风袋巨蛙","鼠标打开巨蛙捕获操作窗")
	await get_tree().create_timer(0.5).timeout
	await _capture_image("09_capture")
	var food: float=sm.data[Run.KEY].satiety
	await _click(maze.capture_flow.attempt.yes_button)
	_check(sm.data[Run.KEY].satiety==food-1,"确认捕获扣一次饱腹")
	maze.capture_flow.attempt.set_process(false)
	saved=Run.snapshot(sm)
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),saved),"已付费捕获恢复不重抽")
	_check(Run.start_capture(sm,B.ID).success and sm.data[Run.KEY].satiety==food-1,"恢复付费不重扣")
	maze.capture_flow.attempt.set_process(true)
	await get_tree().create_timer(2.7).timeout
	for i in 180:
		await _send_key(KEY_J)
		await get_tree().create_timer(0.06).timeout
		if maze.capture_flow.reward.visible: break
	await get_tree().create_timer(0.7).timeout
	_check(sm.data[Run.KEY].bag.get("wind_frog_stomach",0)==1 and maze.capture_flow.reward.visible,"成功获得胃囊并显示原奖励窗")
	await _capture_image("10_reward")
	_check(not Run.resolve(sm,B.ID,true).success,"重复发奖拒绝")
	maze.capture_flow.reward.hide()
	maze.capture_flow._unlock()
	_check(not maze.player.input_locked,"奖励关闭恢复输入")
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.action_left=0.0
	_check(Run.change_region(sm,"salt_pool",preload("res://data/maze/salt_pool_roads.gd").SPAWN).success,"同趟可以离开")
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"同趟返回")
	_check(sm.data[Run.KEY].monsters[B.ID].status=="captured","同趟不复活")
	_check(Run.finish(sm,true,FS.ENTRANCE).success,"胃囊正常结算餐厅")
	_check(sm.warehouse_snapshot().get("wind_frog_stomach",0)==1,"胃囊实际入库")
	_check(Run.begin(sm,Roads.SPAWN).success,"下一趟建立")
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success and _actor().frog_phase=="dormant" and _actor().hp==96,"下一趟巨蛙重建")
	await _close_scene()

func _state_cases(base: Dictionary) -> void:
	var run: Dictionary=base[Run.KEY].duplicate(true)
	var a: Dictionary=run.combat.actors[B.ID]
	var point := B.HOME+Vector2(40,0)
	a.mode="chase"
	a.cooldown=1.0
	a.frog_jump=0.0
	AI.advance(run,point,0.05)
	_check(a.frog_phase=="warning" and a.frog_target==Combat.pack(point),"预警开始锁定合法浅水落点")
	for i in 19: AI.advance(run,B.HOME+Vector2(0,40),0.05)
	_check(a.frog_target==Combat.pack(point) and a.frog_phase=="warning","预警1秒内不追踪玩家")
	AI.advance(run,point,0.05)
	var hp: float=run.combat.hp
	for i in 7: AI.advance(run,point,0.05)
	_check(run.combat.hp==hp-Combat.Skills.incoming_damage(run,6) and a.frog_phase=="landing","一次落地仅一次伤害6含既有防御")
	var landed_hp: float=run.combat.hp
	for i in 20: AI.advance(run,point,0.05)
	_check(run.combat.hp==landed_hp and a.frog_phase=="landing","落地1.2秒停顿无重复伤害")
	for phase in ["active","warning","airborne","landing"]:
		sm.data=base.duplicate(true)
		_actor().frog_phase=phase
		_actor().frog_left=0.2
		_check(sm.save(),"保存阶段"+phase)
		var saved := Run.snapshot(sm)
		sm.load_data()
		_check(_same_saved(saved,Run.snapshot(sm)),"恢复阶段"+phase)
	for dir in 32:
		var end := B.move(B.HOME,Vector2.RIGHT.rotated(dir*TAU/32.0)*500.0)
		_check(B.allowed(end) and B.line(B.HOME,end,B.BODY),"全方向不跨岸不越栏"+str(dir))
	for p in [FS.SPAWN,Vector2(1268,347),Vector2(842,533),Vector2(1000,337)]:
		_check(not B.water(p),"出生剧情干路岛体安全"+str(p))
	# 保存失败、首次概率失败、放弃、芽芽复制和跨区域计数。
	for outcome in ["failed","skipped","copy"]:
		sm.data=base.duplicate(true)
		_actor().hp=0
		sm.data[Run.KEY].monsters[B.ID].capture_roll=0.99 if outcome=="failed" else 0.0
		sm.data[Run.KEY].monsters[B.ID].copy_roll=0.0
		sm.data[Run.PITY_KEY]={"silverfish":2,"thunder_eel":1,"slime":1}
		_check(Run.defeat(sm,B.ID,B.HOME).success,"待捕获"+outcome)
		_check(not sm.data[Run.KEY].monsters[B.ID].guaranteed,"巨蛙无首次必成")
		if outcome!="skipped":
			_check(Run.start_capture(sm,B.ID).success and Run.finish_capture(sm,B.ID,true).success,"捕获付费及操作结论"+outcome)
		var path: String=sm._active_save_path
		var before: Dictionary=sm.data.duplicate(true)
		sm._active_save_path=""
		_check(not Run.resolve(sm,B.ID,outcome!="skipped").success and sm.data==before,"结算失败全事务回滚"+outcome)
		sm._active_save_path=path
		var result := Run.resolve(sm,B.ID,outcome!="skipped")
		_check(result.success,"结算"+outcome)
		if outcome=="copy": _check(result.caught and result.items.get("wind_frog_stomach",0)==2,"芽芽沿既有规则复制胃囊")
		else: _check(sm.data[Run.KEY].bag.is_empty() and sm.data[Run.KEY].monsters[B.ID].status==outcome,"失败放弃不奖励且结束机会"+outcome)
		_check(Run.failure_streak(sm,"silverfish")==2 and Run.failure_streak(sm,"thunder_eel")==1,"其他区域失败计数不丢失"+outcome)
		_check(Run.failure_streak(sm,"wind_frog")== (1 if outcome=="failed" else 0),"巨蛙兼容通用失败计数"+outcome)
		_check(not Run.resolve(sm,B.ID,true).success,"结束后不能重试"+outcome)
	# 删除版本标记或已有演员都拒绝恢复，禁止重新抽随机数。
	sm.data=base.duplicate(true)
	sm.data[Run.KEY].combat.actors.erase(B.ID)
	_check(not Run.begin(sm,FS.SPAWN,"fenshui").success,"缺巨蛙演员拒绝恢复")
	sm.data=base.duplicate(true)
	sm.data[Run.KEY].combat.erase("frog_encounter")
	_check(not Run.begin(sm,FS.SPAWN,"fenshui").success,"缺巨蛙版本标记拒绝重建")
	sm.data=base.duplicate(true)
	sm.data[Run.KEY].combat.actors.erase(B.ID)
	sm.data[Run.KEY].monsters.erase(B.ID)
	sm.data[Run.KEY].combat.erase("frog_encounter")
	var old_monsters: Dictionary=sm.data[Run.KEY].monsters.duplicate(true)
	_check(Run.begin(sm,FS.SPAWN,"fenshui").success and _actor().frog_phase=="dormant","已有16怪旧档首次补入巨蛙")
	for id in old_monsters: _check(sm.data[Run.KEY].monsters[id]==old_monsters[id],"旧档迁移保留原怪物随机与结果"+str(id))
	# 吐水锁向、直线、岸边截断和无接触伤害。
	run=base[Run.KEY].duplicate(true)
	a=run.combat.actors[B.ID]
	a.mode="chase"
	a.cooldown=0.0
	a.frog_jump=6.0
	AI.advance(run,B.HOME+Vector2(70,0),0.05)
	var aim: Array=a.frog_aim.duplicate()
	for i in 15: AI.advance(run,B.HOME+Vector2(0,40),0.05)
	_check(a.frog_shots.is_empty() and a.frog_aim==aim,"0.8秒前摇锁方向且不提前发射")
	AI.advance(run,B.HOME+Vector2(0,40),0.05)
	_check(a.frog_shots.size()==1 and a.frog_shots[0].direction==aim,"只发一颗锁向水团")
	for i in 12: AI.advance(run,B.HOME+Vector2(0,40),0.05)
	_check(a.frog_shots.is_empty(),"水团在活动水域边界停止不穿岸")
	# 隔离事务证明出场转换写盘失败不会留半套状态。
	sm.data=base.duplicate(true)
	AI.initialize(_actor())
	var path: String=sm._active_save_path
	var before: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,B.HOME,0.05).success and sm.data==before,"出场写盘失败整体回滚")
	sm._active_save_path=path
