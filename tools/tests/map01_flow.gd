extends "res://tools/tests/combat_02_flow.gd"
const F = preload("res://data/maze/fenshui_encounters.gd")
const FS = preload("res://data/maze/fenshui_roads.gd")

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	var original := Run.snapshot(sm)
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"切入分水庭建立六怪")
	_check(sm.set_yufeng_salia_state("done").success,"普通怪专项使用御风剧情已完成前置")
	await _close_scene()
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	_check(maze._entry_ready and maze.capture_flow.monsters.size()==7 and maze.capture_flow.monsters[Catalog.Frog.ID].visible,"真实分水庭生成4鱼2鳗，中央巨蛙初始可见")
	_check(maze.yf_encounter.phase=="done" and not maze.yf_encounter.idle.visible,"已完成剧情不重复聊天")
	_check(Run.valid(Run.snapshot(sm)),"区域扩展存档合法")
	for id in original.monsters:
		_check(sm.data[Run.KEY].monsters[id]==original.monsters[id],"首区状态保留"+id)
	for row in F.all():
		_check(F.water(row.position),"出生主体完整处于合法浅水"+row.id)
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
			_check(F.allowed(Combat.vec(actor.position),row.position),"真实追击/击退不跨浅水边界"+row.id+str(step))
		actor.mode="chase"
		var position: Array=actor.position.duplicate()
		Combat.advance(probe,preload("res://data/maze/yf_encounter_site.gd").CHAT_FOOT,0.05)
		_check(actor.mode in ["idle","return"],"御风保护区立即脱战"+row.id)
	var corrupt: Dictionary=Run.snapshot(sm)
	corrupt.monsters.erase(F.all()[0].id)
	_check(not Run.valid(corrupt),"已建立的区域缺失记录不能重建刷奖励")
	var fish := F.all()[2]
	var eel := F.all()[5]
	maze.player.position=fish.position+Vector2(0,45)
	maze.camera.snap_to_target()
	maze.capture_flow._process(0.0)
	await _capture_image("01_silverfish_scene")
	var before: Dictionary=sm.data[Run.KEY].duplicate(true)
	var trial: Dictionary=before.duplicate(true)
	var a: Dictionary=trial.combat.actors[fish.id]
	a.mode="windup"
	a.windup=0.55
	var hp: float=trial.combat.hp
	Combat.advance(trial,fish.position+Vector2(0,25),0.5)
	_check(trial.combat.hp==hp,"鱼攻击前摇不提前伤害")
	Combat.advance(trial,fish.position+Vector2(0,25),0.05)
	_check(trial.combat.hp==hp-Combat.Skills.incoming_damage(trial,4),"鱼0.55秒后单次碰撞伤害")
	trial=before.duplicate(true)
	a=trial.combat.actors[eel.id]
	a.mode="windup"
	a.windup=0.8
	hp=trial.combat.hp
	Combat.advance(trial,eel.position+Vector2(0,-55),0.5)
	_check(trial.combat.hp==hp,"雷鳗前摇前不伤害")
	Combat.advance(trial,eel.position+Vector2(0,-55),0.3)
	_check(trial.combat.hp==hp-Combat.Skills.incoming_damage(trial,5),"雷鳗70像素范围单次放电")
	var after_hp: float=trial.combat.hp
	Combat.advance(trial,eel.position+Vector2(0,-55),0.1)
	_check(trial.combat.hp==after_hp,"放电不连续重复命中")
	maze.player.position=eel.position+Vector2(0,-55)
	maze.camera.snap_to_target()
	sm.data[Run.KEY].combat.actors[eel.id].mode="windup"
	sm.data[Run.KEY].combat.actors[eel.id].windup=0.35
	maze.capture_flow._process(0.0)
	await _capture_image("02_eel_windup")
	sm.data[Run.KEY]=before
	# 真实攻击事务与模拟击杀；隔离夹具固定随机数使成功分支可重复。
	maze.player.position=fish.position+Vector2(0,45)
	var run: Dictionary=sm.data[Run.KEY]
	run.combat.attack=25
	run.combat.cooldown=0.0
	run.monsters[fish.id].capture_roll=0.0
	run.monsters[fish.id].copy_roll=0.99
	_check(Run.combat_attack(sm,maze.player.position,Vector2.UP).success,"玩家普攻提交")
	for i in 10:
		_check(Run.combat_tick(sm,maze.player.position,0.05).success,"区域战斗推进")
	_check(sm.data[Run.KEY].combat.actors[fish.id].hp==0,"投射物击败真实区域怪物")
	_check(sm.data[Run.KEY].bag.is_empty(),"击败不直接发材料")
	maze.capture_flow._process(0.0)
	await get_tree().create_timer(0.8).timeout
	maze.capture_flow._process(0.0)
	_check(maze.capture_flow.dialog.visible,"倒地后进入既有捕获弹窗")
	await get_tree().create_timer(0.5).timeout
	await _capture_image("03_capture_dialog")
	await _click(maze.capture_flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	_check(maze.capture_flow.attempt.visible and maze.capture_flow.attempt.name_label.text=="银鳞鱼","真实按钮打开鱼捕获操作窗")
	maze.capture_flow._process(0.0)
	_check(not maze.capture_flow.skill_bar.visible,"捕获弹窗隐藏战斗栏防止遮挡按钮")
	await get_tree().create_timer(0.9).timeout
	await _capture_image("04_capture_attempt")
	var satiety: float=sm.data[Run.KEY].satiety
	await _click(maze.capture_flow.attempt.yes_button)
	_check(sm.data[Run.KEY].monsters[fish.id].has("attempt"),"捕获按钮先保存扣费")
	maze.capture_flow.attempt.set_process(false)
	_check(sm.data[Run.KEY].satiety==satiety-1,"仅扣一次饱腹")
	_check(Run.start_capture(sm,fish.id).success and sm.data[Run.KEY].satiety==satiety-1,"重试不重复扣费")
	sm.load_data()
	_check(sm.data[Run.KEY].monsters[fish.id].has("attempt") and sm.data[Run.KEY].satiety==satiety-1,"付费捕获读档恢复且不重扣")
	_check(Run.finish_capture(sm,fish.id,true).success,"保存操作成功")
	var saved_path: String=sm._active_save_path
	var prior: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.resolve(sm,fish.id,true).success and sm.data==prior,"发奖写盘失败完整回滚")
	sm._active_save_path=saved_path
	_check(Run.resolve(sm,fish.id,true).get("caught",false),"成功捕获银鳞鱼")
	_check(sm.data[Run.KEY].bag.get("silverfish_meat",0)==1,"材料进入暂存袋")
	_check(not Run.resolve(sm,fish.id,true).success,"重复结算拒绝")
	maze.capture_flow.dialog.hide()
	maze.capture_flow.attempt.close()
	maze.capture_flow._unlock()
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.action_left=0.0
	var region_states: Dictionary=sm.data[Run.KEY].monsters.duplicate(true)
	_check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"返回枯水渠")
	for row in F.all():
		_check(sm.data[Run.KEY].monsters[row.id]==region_states[row.id],"首区清场不误清分水庭"+row.id)
	for row in Catalog.all(): _check(sm.data[Run.KEY].monsters[row.id].status=="skipped","保留既有返程首区清场"+row.id)
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"同趟重进分水庭")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)) and sm.data[Run.KEY].monsters[fish.id].status=="captured","读档不复活")
	_check(sm.data[Run.KEY].bag.get("silverfish_meat",0)==1,"读档不重复发奖")
	# 雷鳗使用相同真实捕获路径，单独确认材料身份。
	sm.data[Run.KEY].combat.actors[eel.id].hp=0
	sm.data[Run.KEY].monsters[eel.id].capture_roll=0.0
	sm.data[Run.KEY].monsters[eel.id].copy_roll=0.99
	_check(Run.defeat(sm,eel.id,FS.SPAWN).success,"雷鳗进入待捕获")
	_check(Run.start_capture(sm,eel.id).success and Run.finish_capture(sm,eel.id,true).success,"雷鳗扣费并保存操作结论")
	_check(Run.resolve(sm,eel.id,true).get("caught",false),"捕获雷鳗得到独立材料")
	_check(sm.data[Run.KEY].bag.get("thunder_eel_belly",0)==1,"雷鳗腹肉暂存")
	var frozen: Dictionary=sm.data[Run.KEY].monsters.duplicate(true)
	_check(Run.change_region(sm,"salt_pool",preload("res://data/maze/salt_pool_roads.gd").SPAWN).success,"切入盐池不串怪")
	_check(Run.combat_tick(sm,preload("res://data/maze/salt_pool_roads.gd").SPAWN,0.5).success,"盐池保留静区技能计时")
	_check(frozen.keys().all(func(id): return sm.data[Run.KEY].monsters[id]==frozen[id]),"盐池不结算其他区域怪物")
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"盐池返回分水庭")
	_check(frozen.keys().all(func(id): return sm.data[Run.KEY].monsters[id]==frozen[id]),"往返不重掷捕获随机数或恢复生命")
	_check(Run.finish(sm,true,FS.ENTRANCE).success,"返回餐厅结算入库")
	_check(sm.maze_exploration_state().region=="restaurant","结算返回餐厅")
	_check(sm.warehouse_snapshot().get("silverfish_meat",0)==1 and sm.warehouse_snapshot().get("thunder_eel_belly",0)==1,"两种材料实际入仓库")
	await _close_scene()
