extends "res://tools/tests/combat_02_flow.gd"
const F = preload("res://data/maze/salt_pool_encounters.gd")
const FS = preload("res://data/maze/salt_pool_roads.gd")

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	var original := Run.snapshot(sm)
	_check(Run.change_region(sm,"salt_pool",FS.SPAWN).success,"切入盐池建立六怪")
	await _close_scene()
	maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	_check(maze._entry_ready and maze.capture_flow.monsters.size()==7,"真实盐池生成3蟹3蝎及独立岩鬃兽")
	_check(Run.valid(Run.snapshot(sm)),"区域扩展存档合法")
	for id in original.monsters:
		_check(sm.data[Run.KEY].monsters[id]==original.monsters[id],"首区状态保留"+id)
	for row in F.all():
		_check(F.ground(row.position),"出生主体完整处于合法岸线"+row.id)
		for d in 32:
			var end := F.move(row.position,Vector2.RIGHT.rotated(d*TAU/32.0)*350,row.position)
			_check(F.allowed(end,row.position),"大步长不能跨岸或进入剧情/Boss区"+row.id+str(d))
		var sprite=maze.capture_flow.monsters[row.id]
		_check(sprite.action_sheets.size()==4,"四套真实动作资源"+row.id)
		for direction in 4:
			sprite._set_direction(direction)
			for action in ["idle","swim","attack","defeated"]:
				sprite.action=action
				sprite.action_time=0.3
				sprite._draw_frame(sprite.frame_index())
				_check(sprite.body.region_rect.size==Vector2(128,128),"固定画布四向动作"+row.id+str(direction)+action)
	# 直接推进正式模拟，验证追击、击退与回位全程保留本分区。
	for row in F.all():
		var probe: Dictionary=Run.snapshot(sm)
		var actor: Dictionary=probe.combat.actors[row.id]
		actor.mode="chase"
		Combat.hit(actor,row.position,row.position-Vector2(20,0),12.0)
		for step in 80:
			var target: Vector2=row.position+Vector2.RIGHT.rotated(step*0.16)*140
			if not FS.is_walkable(target): target=row.position
			Combat.advance(probe,target,0.05)
			_check(F.allowed(Combat.vec(actor.position),row.position),"真实追击/击退不跨岸线边界"+row.id+str(step))
		actor.mode="chase"
		var position: Array=actor.position.duplicate()
		Combat.advance(probe,FS.SPAWN,0.05)
		_check(actor.mode in ["idle","return"],"入口保护区立即脱战"+row.id)
		for step in 120: Combat.advance(probe,FS.SPAWN,0.05)
		_check(Combat.vec(actor.position).distance_to(row.position)<=2.0 and actor.mode=="idle","绕岸追击后能够回家"+row.id)
	var corrupt: Dictionary=Run.snapshot(sm)
	corrupt.monsters.erase(F.all()[0].id)
	_check(not Run.valid(corrupt),"已建立的区域缺失记录不能重建刷奖励")
	var crab := F.all()[0]
	var scorpion := F.all()[4]
	maze.player.position=crab.position+Vector2(0,45)
	maze.camera.snap_to_target()
	maze.capture_flow._process(0.0)
	await _capture_image("01_mimic_crab_scene")
	var before: Dictionary=sm.data[Run.KEY].duplicate(true)
	var trial: Dictionary=before.duplicate(true)
	var a: Dictionary=trial.combat.actors[crab.id]
	a.mode="windup"
	a.windup=0.65
	var hp: float=trial.combat.hp
	Combat.advance(trial,crab.position+Vector2(0,25),0.5)
	_check(trial.combat.hp==hp,"蟹攻击前摇不提前伤害")
	Combat.advance(trial,crab.position+Vector2(0,25),0.15)
	_check(trial.combat.hp==hp-Combat.Skills.incoming_damage(trial,5),"蟹0.65秒后单次碰撞伤害")
	trial=before.duplicate(true)
	a=trial.combat.actors[scorpion.id]
	a.mode="windup"
	a.windup=0.6
	a["attack_aim"]=[0.0,-1.0]
	hp=trial.combat.hp
	Combat.advance(trial,scorpion.position+Vector2(0,-25),0.5)
	_check(trial.combat.hp==hp,"盲水蝎前摇前不伤害")
	Combat.advance(trial,scorpion.position+Vector2(0,-25),0.1)
	_check(trial.combat.hp==hp-Combat.Skills.incoming_damage(trial,4),"盲水蝎42像素内锁向单次尾刺")
	var after_hp: float=trial.combat.hp
	Combat.advance(trial,scorpion.position+Vector2(0,-25),0.1)
	_check(trial.combat.hp==after_hp,"尾刺不连续重复命中")
	maze.player.position=scorpion.position+Vector2(0,-25)
	maze.camera.snap_to_target()
	sm.data[Run.KEY].combat.actors[scorpion.id].mode="windup"
	sm.data[Run.KEY].combat.actors[scorpion.id].windup=0.35
	maze.capture_flow._process(0.0)
	await _capture_image("02_scorpion_windup")
	sm.data[Run.KEY]=before
	# 真实攻击事务与模拟击杀；隔离夹具固定随机数使成功分支可重复。
	maze.player.position=crab.position+Vector2(0,45)
	var run: Dictionary=sm.data[Run.KEY]
	run.combat.attack=35
	run.combat.cooldown=0.0
	run.monsters[crab.id].capture_roll=0.0
	run.monsters[crab.id].copy_roll=0.99
	_check(Run.combat_attack(sm,maze.player.position,Vector2.UP).success,"玩家普攻提交")
	for i in 10:
		_check(Run.combat_tick(sm,maze.player.position,0.05).success,"区域战斗推进")
	_check(sm.data[Run.KEY].combat.actors[crab.id].hp==0,"投射物击败真实区域怪物")
	_check(sm.data[Run.KEY].bag.is_empty(),"击败不直接发材料")
	maze.capture_flow._process(0.0)
	await get_tree().create_timer(0.8).timeout
	maze.capture_flow._process(0.0)
	_check(maze.capture_flow.dialog.visible,"倒地后进入既有捕获弹窗")
	await get_tree().create_timer(0.5).timeout
	await _capture_image("03_capture_dialog")
	await _click(maze.capture_flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	_check(maze.capture_flow.attempt.visible and maze.capture_flow.attempt.name_label.text=="拟态宝箱蟹","真实按钮打开蟹捕获操作窗")
	maze.capture_flow._process(0.0)
	_check(not maze.capture_flow.skill_bar.visible,"捕获弹窗隐藏战斗栏防止遮挡按钮")
	await get_tree().create_timer(0.9).timeout
	await _capture_image("04_capture_attempt")
	var satiety: float=sm.data[Run.KEY].satiety
	await _click(maze.capture_flow.attempt.yes_button)
	_check(sm.data[Run.KEY].monsters[crab.id].has("attempt"),"捕获按钮先保存扣费")
	maze.capture_flow.attempt.set_process(false)
	_check(sm.data[Run.KEY].satiety==satiety-1,"仅扣一次饱腹")
	_check(Run.start_capture(sm,crab.id).success and sm.data[Run.KEY].satiety==satiety-1,"重试不重复扣费")
	sm.load_data()
	_check(sm.data[Run.KEY].monsters[crab.id].has("attempt") and sm.data[Run.KEY].satiety==satiety-1,"付费捕获读档恢复且不重扣")
	_check(Run.finish_capture(sm,crab.id,true).success,"保存操作成功")
	var saved_path: String=sm._active_save_path
	var prior: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.resolve(sm,crab.id,true).success and sm.data==prior,"发奖写盘失败完整回滚")
	sm._active_save_path=saved_path
	_check(Run.resolve(sm,crab.id,true).get("caught",false),"成功捕获拟态宝箱蟹")
	_check(sm.data[Run.KEY].bag.get("mimic_crab_meat",0)==1,"材料进入暂存袋")
	_check(not Run.resolve(sm,crab.id,true).success,"重复结算拒绝")
	maze.capture_flow.dialog.hide()
	maze.capture_flow.attempt.close()
	maze.capture_flow._unlock()
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.action_left=0.0
	var region_states: Dictionary=sm.data[Run.KEY].monsters.duplicate(true)
	_check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"返回枯水渠")
	for row in F.all():
		_check(sm.data[Run.KEY].monsters[row.id]==region_states[row.id],"首区清场不误清盐池"+row.id)
	_check(Run.change_region(sm,"salt_pool",FS.SPAWN).success,"同趟重进盐池")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)) and sm.data[Run.KEY].monsters[crab.id].status=="captured","读档不复活")
	_check(sm.data[Run.KEY].bag.get("mimic_crab_meat",0)==1,"读档不重复发奖")
	# 盲水蝎使用相同真实捕获路径，单独确认材料身份。
	sm.data[Run.KEY].combat.actors[scorpion.id].hp=0
	sm.data[Run.KEY].monsters[scorpion.id].capture_roll=0.0
	sm.data[Run.KEY].monsters[scorpion.id].copy_roll=0.99
	_check(Run.defeat(sm,scorpion.id,FS.SPAWN).success,"盲水蝎进入待捕获")
	_check(Run.start_capture(sm,scorpion.id).success and Run.finish_capture(sm,scorpion.id,true).success,"盲水蝎扣费并保存操作结论")
	_check(Run.resolve(sm,scorpion.id,true).get("caught",false),"捕获盲水蝎得到独立材料")
	_check(sm.data[Run.KEY].bag.get("blind_scorpion_tail",0)==1,"盲水蝎尾肉暂存")
	var frozen: Dictionary=sm.data[Run.KEY].monsters.duplicate(true)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.action_left=0.0
	_check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").SPAWN).success,"切入分水庭")
	_check(Run.combat_tick(sm,preload("res://data/maze/fenshui_roads.gd").SPAWN,0.05).success,"其他区域独立推进")
	for row in F.all(): _check(sm.data[Run.KEY].monsters[row.id]==frozen[row.id],"盐池跨图不结算重抽"+row.id)
	_check(Run.change_region(sm,"salt_pool",FS.SPAWN).success,"返回盐池")
	for row in F.all(): _check(sm.data[Run.KEY].monsters[row.id]==frozen[row.id],"往返不复活"+row.id)
	_check(Run.finish(sm,true,FS.ENTRANCE).success,"返回餐厅结算入库")
	_check(sm.maze_exploration_state().region=="restaurant","结算返回餐厅")
	_check(sm.warehouse_snapshot().get("mimic_crab_meat",0)==1 and sm.warehouse_snapshot().get("blind_scorpion_tail",0)==1,"两种材料实际入仓库")
	await _close_scene()
	await _additional()

func _additional() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	_check(Run.change_region(sm,"salt_pool",FS.SPAWN).success,"额外场景进入盐池")
	await _close_scene()
	maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	maze.toast_label.dismiss()
	var base: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	for row in [F.all()[0],F.all()[4]]:
		var stats: Dictionary=Combat.STATS[row.kind]
		for direction in [Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
			var trial: Dictionary=base[Run.KEY].duplicate(true)
			var actor: Dictionary=trial.combat.actors[row.id]
			var target: Vector2=row.position+direction*25
			_check(FS.is_walkable(target),"四向站位合法"+row.kind+str(direction))
			Combat.advance(trial,target,0.05)
			_check(actor.mode=="windup" and actor.attack_aim==Combat.pack(direction),"实际接近触发锁向前摇"+row.kind+str(direction))
			var hp: float=trial.combat.hp
			Combat.advance(trial,target,0.5)
			_check(trial.combat.hp==hp,"前摇0.5秒尚未伤害"+row.kind)
			Combat.advance(trial,target,float(stats.windup)-0.5)
			_check(trial.combat.hp==hp-Combat.Skills.incoming_damage(trial,int(stats.attack)),"四向攻击实际命中一次"+row.kind)
			if row.kind=="blind_scorpion":
				trial=base[Run.KEY].duplicate(true)
				actor=trial.combat.actors[row.id]
				Combat.advance(trial,target,0.05)
				hp=trial.combat.hp
				var dodge: Vector2=row.position+direction.rotated(PI/2)*25
				Combat.advance(trial,dodge,0.5)
				Combat.advance(trial,dodge,0.1)
				_check(trial.combat.hp==hp,"蝎尾直线刺击可侧移躲开")
		for outcome in ["failed","operation_failed","skipped","copy"]:
			sm.data=base.duplicate(true)
			var run: Dictionary=sm.data[Run.KEY]
			run.combat.actors[row.id].hp=0
			run.monsters[row.id].capture_roll=0.99 if outcome=="failed" else 0.0
			run.monsters[row.id].copy_roll=0.0
			sm.data[Run.PITY_KEY]={"silverfish":2,"thunder_eel":1,"wind_frog":2,"slime":1}
			_check(Run.defeat(sm,row.id,row.position).success,"进入待捕获"+row.kind+outcome)
			_check(not sm.data[Run.KEY].monsters[row.id].guaranteed,"盐池普通怪无首次必成")
			var food: float=sm.data[Run.KEY].satiety
			if outcome!="skipped":
				_check(Run.start_capture(sm,row.id).success,"付费捕获"+outcome)
				_check(Run.finish_capture(sm,row.id,outcome!="operation_failed").success,"保存操作结果"+outcome)
			var previous: Dictionary=sm.data.duplicate(true)
			sm._active_save_path=""
			_check(not Run.resolve(sm,row.id,outcome!="skipped").success and sm.data==previous,"所有结算分支保存失败回滚")
			sm._active_save_path=path
			var result := Run.resolve(sm,row.id,outcome!="skipped")
			_check(result.success,"结算"+row.kind+outcome)
			if outcome=="copy": _check(result.caught and result.items.get(row.drops[0],0)==2,"芽芽复制正确原料")
			else: _check(sm.data[Run.KEY].bag.is_empty(),"失败放弃不发肉")
			_check(sm.data[Run.KEY].satiety==food-(0 if outcome=="skipped" else 1),"放弃免费捕获只扣一次")
			_check(Run.failure_streak(sm,"wind_frog")==2 and Run.failure_streak(sm,"silverfish")==2 and Run.failure_streak(sm,"slime")==1,"其他区域计数保留")
			_check(not Run.resolve(sm,row.id,true).success,"结算后不能重复发奖")
		# 真实事务击败经验，后续推进不重复发经验。
		sm.data=base.duplicate(true)
		sm.data[Run.KEY].combat.actors[row.id].hp=1
		sm.data[Run.KEY].combat.cooldown=0.0
		var xp_before := Run.Progression.record(sm,"yaya")
		var attack_point: Vector2=row.position+Vector2(0,25)
		_check(Run.combat_attack(sm,attack_point,Vector2.UP).success,"真实弹道击杀样例")
		for i in 10: _check(Run.combat_tick(sm,attack_point,0.05).success,"经验通过实际推进事务")
		var xp_after := Run.Progression.record(sm,"yaya")
		var gained: int=xp_after.exp-xp_before.exp
		for level in range(xp_before.level,xp_after.level): gained+=Run.Progression.experience_required(level)
		_check(gained==(35 if row.kind=="mimic_crab" else 30),"蟹35蝎30经验")
		_check(Run.combat_tick(sm,FS.SPAWN,0.05).success and Run.Progression.record(sm,"yaya")==xp_after,"经验不重复")
		# 同屏可辨识造型、四向动作与主角比例。
		sm.data=base.duplicate(true)
		maze.player.position=row.position+Vector2(50,0)
		_check(FS.is_walkable(maze.player.position),"同屏审阅玩家站在合法岸线")
		maze.camera.snap_to_target()
		maze.capture_flow._process(0.0)
		await _capture_image("05_"+row.kind+"_scale")
		var sprite=maze.capture_flow.monsters[row.id]
		sprite.set_process(false)
		for facing in 4:
			sprite._set_direction(facing)
			sprite.action="attack"
			sprite._draw_frame(2)
			await _capture_image("06_"+row.kind+"_attack_"+str(facing))
		sprite.set_process(true)
	var home: Vector2=F.POINTS[0]
	_check(FS.terrain_multiplier(home)==0.5 and is_equal_approx(F.move(home,Vector2(10,0),home).distance_to(home),5.0),"盐地追击速度按现有0.5倍率")
	for p in F.RESERVED+[FS.SPAWN,Vector2(1010,225)]: _check(F.protected(p),"采晶真宝箱入口Boss避让"+str(p))
	_check(not F.ground(Vector2(800,530)),"水元素不能走入池水")
	var axe: Dictionary=base[Run.KEY].duplicate(true)
	var crab := F.all()[0]
	axe.combat.cooldown=0.0
	_check(Combat.Skills.select(axe,2) and Combat.attack(axe,crab.position+Vector2(0,25),Vector2.UP),"铁山盐池攻击启动")
	Combat.advance(axe,crab.position+Vector2(0,25),0.2)
	_check(axe.combat.actors[crab.id].hp<28,"铁山范围攻击使用盐池地形命中")
	for row in Catalog.all(): _check(axe.combat.actors[row.id].hp==base[Run.KEY].combat.actors[row.id].hp,"盐池技能不伤首区怪"+row.id)
	_check(not Combat.region_line(Vector2(900,420),Vector2(900,620),"salt_pool"),"玩家投射物不可穿池")
	sm.data=base.duplicate(true)
	maze.player.position=home
	Input.action_press("ui_right")
	maze.player._physics_process(0.1)
	Input.action_release("ui_right")
	_check(is_equal_approx(maze.player.position.distance_to(home),6.5),"真实玩家盐地速度保持65每秒")
	# 蟹节点不是永久宝箱，不接E键交互。
	_check(not maze.capture_flow.monsters[F.all()[0].id].has_method("interact"),"拟态蟹无真宝箱E交互")
	sm.data=base.duplicate(true)
	_check(Run.finish(sm,false,FS.SPAWN).success,"结束本趟")
	_check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"salt_pool",FS.SPAWN).success,"次趟重建")
	for row in F.all(): _check(sm.data[Run.KEY].monsters[row.id].status=="alive" and sm.data[Run.KEY].combat.actors[row.id].hp==Combat.STATS[row.kind].hp,"次趟满血新机会"+row.id)
	await _close_scene()
