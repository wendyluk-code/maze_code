extends "res://tools/tests/combat_02_flow.gd"
const B=preload("res://data/maze/salt_boss.gd")
const SR=preload("res://data/maze/salt_pool_roads.gd")
const Crystal=preload("res://scripts/maze/salt_crystals.gd")
func total_xp(id: String) -> int:
	var row:=Run.Progression.record(sm,id)
	var total: int=row.exp
	for level in range(1,int(row.level)): total+=Run.Progression.experience_required(level)
	return total
func mouse_at(point: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=maze.get_viewport().get_canvas_transform()*point
		event.pressed=pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
func calm() -> void:
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.action_left=0.0
	sm.data[Run.KEY].combat.axe_pending=false
func mine(p: Vector2,serial: int=-1) -> void:
	var c: Dictionary=sm.data[Run.KEY].combat
	c.cooldown=0.0
	c.action_left=0.0
	_check(Run.combat_command(sm,"select",2).success,"选择实际土角色铁山")
	_check(Run.combat_attack(sm,p,Vector2.UP).success,"真实土普攻释放")
	if serial>=0: sm.data[Run.KEY].combat.basic_serial=serial
	_check(Run.combat_tick(sm,p,0.2).success,"真实旋斧命中推进")
func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	calm()
	_check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"建立盐池及独立岩鬃兽")
	await _close_scene()
	maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	var flow=maze.capture_flow
	flow.set_process(false)
	flow.window_focused=true
	_check(flow.monsters.size()==7 and Run.valid(Run.snapshot(sm)),"真实盐池六普通怪一Boss合法")
	_check(B.allowed(B.HOME) and not SR.is_walkable(Vector2(1010,225),B.BODY),"校准大体型合法出生点")
	var base: Dictionary=sm.data.duplicate(true)
	# 真键盘选角及鼠标左键释放，使用现行场景输入链而非直接调用采矿。
	maze.player.position=Vector2(505,430)
	maze.camera.snap_to_target()
	sm.data[Run.KEY].combat.cooldown=0.0
	flow._process(0)
	await _send_key(KEY_2)
	_check(sm.data[Run.KEY].combat.selected==2,"真实数字键选择铁山")
	await mouse_at(Vector2(522,365))
	flow._process(0.25)
	_check(sm.data[Run.KEY].bag.get("rock_salt",0)==1,"真实鼠标土普攻击中盐晶")
	await _capture_image("00_actual_mining_input")
	await get_tree().create_timer(0.5).timeout
	maze.loot_modal.close_modal()
	await get_tree().process_frame
	sm.data[Run.KEY].combat.cooldown=0.0
	sm.data[Run.KEY].combat.action_left=0.0
	await _send_key(KEY_1)
	await mouse_at(Vector2(505,365))
	flow._process(0.35)
	_check(sm.data[Run.KEY].bag.get("rock_salt",0)==1 and flow.crystal_visual.dull_hint,"真实非土弹丸命中不采盐且首次钝响提示")
	_check(maze.toast_label.text=="土属性普攻可开采","复用现有短暂提示组件")
	sm.data=base.duplicate(true)
	# 实际玩家攻击击杀发经验，但不直接发肉。
	var old_xp:=total_xp("yaya")
	sm.data[Run.KEY].combat.attack=120
	sm.data[Run.KEY].combat.cooldown=0.0
	_check(Run.combat_attack(sm,B.HOME+Vector2(0,30),Vector2.UP).success,"实际Boss击杀普攻")
	for i in 10: Run.combat_tick(sm,B.HOME+Vector2(0,30),0.05)
	_check(sm.data[Run.KEY].combat.actors[B.ID].hp==0 and sm.data[Run.KEY].bag.is_empty(),"真实击败120生命且不直接发肉")
	_check(total_xp("yaya")==old_xp+150,"真实击杀恰好150经验")
	_check(sm.data[Run.KEY].monsters[B.ID].get("experience_generation",-1)==0,"150经验仅该生命代数一次回执")
	sm.data=base.duplicate(true)
	var r:=Run.snapshot(sm)
	var a: Dictionary=r.combat.actors[B.ID]
	a.mode="chase"
	a.rock_phase="active"
	var p:=B.HOME+Vector2(0,25)
	var hp: float=r.combat.hp
	Combat.Rock.advance(r,p,0.01)
	_check(a.rock_phase=="charge" and is_equal_approx(a.rock_left,1.1),"咆哮起手前摇1.1秒")
	Combat.Rock.advance(r,p,1.0)
	_check(r.combat.hp==hp and a.rock_phase=="charge","咆哮前摇结束前不伤害")
	Combat.Rock.advance(r,p,0.1)
	_check(r.combat.hp==hp-Combat.Skills.incoming_damage(r,8),"咆哮攻击8经队伍防御结算")
	_check(a.rock_phase=="rush" and is_equal_approx(r.combat.rock_shake_left,0.45),"咆哮释放并触发震屏")
	Combat.Rock.advance(r,p,0.1)
	_check(r.combat.hp==hp-Combat.Skills.incoming_damage(r,8),"同次咆哮持续阶段不重复伤害")
	# 各方向锁向、原地释放、伤害和休息；rush 是保留的存档阶段名。
	var directions_checked:=0
	for direction in 16:
		r=Run.snapshot(sm)
		a=r.combat.actors[B.ID]
		a.mode="chase"
		a.rock_phase="active"
		p=B.HOME+Vector2.RIGHT.rotated(direction*TAU/16)*40
		if not SR.is_walkable(p) or not Combat.Rock.roar_clear(B.HOME,p): continue
		directions_checked+=1
		Combat.Rock.advance(r,p,0.01)
		_check(a.rock_phase=="charge" and is_equal_approx(a.rock_left,1.1),"咆哮前摇1.1秒 "+str(direction))
		var aim: Array=a.rock_aim.duplicate()
		hp=r.combat.hp
		Combat.Rock.advance(r,p+Vector2(3,2),0.5)
		_check(a.rock_aim==aim and r.combat.hp==hp,"咆哮锁向不追踪且前摇无伤害")
		Combat.Rock.advance(r,p,0.5)
		Combat.Rock.advance(r,p,0.1)
		_check(a.rock_phase=="rush","前摇结束进入咆哮释放")
		_check(r.combat.hp==hp-Combat.Skills.incoming_damage(r,8),"正面咆哮恰好伤害一次")
		var release_hp: float=r.combat.hp
		for step in 10:
			if a.rock_phase!="rush": break
			Combat.Rock.advance(r,p,0.05)
			_check(Combat.vec(a.position).is_equal_approx(B.HOME),"咆哮释放原地不冲撞")
			_check(r.combat.hp==release_hp,"持续释放不重复扣血")
		_check(a.rock_phase=="rest" and is_equal_approx(a.rock_left,1.5),"咆哮结束休息1.5秒")
		_check(r.bag.is_empty() and not r.combat.has("salt_impacts"),"咆哮不产盐")
		# 同一锁向起手后移到侧面：不能仍按原命中点扣血。
		r=Run.snapshot(sm)
		a=r.combat.actors[B.ID]
		a.mode="chase"
		a.rock_phase="active"
		Combat.Rock.advance(r,p,0.01)
		hp=r.combat.hp
		var side:=B.HOME+(p-B.HOME).rotated(PI/2.0)
		Combat.Rock.advance(r,side,1.1)
		_check(a.rock_phase=="rush" and r.combat.hp==hp,"移出扇形可躲避咆哮")
	_check(directions_checked>0,"方向样例实际执行")
	# 实景比例、蓄力方向与动画资源。
	maze.player.position=B.HOME+Vector2(0,25)
	maze.camera.snap_to_target()
	flow._process(0)
	_check(flow.monsters[B.ID].action_sheets.size()==6,"六套逐帧动作")
	await _capture_image("01_boss_scale")
	sm.data[Run.KEY].combat.actors[B.ID].rock_phase="charge"
	sm.data[Run.KEY].combat.actors[B.ID].rock_left=0.8
	sm.data[Run.KEY].combat.actors[B.ID].rock_aim=[0.0,1.0]
	flow._process(0)
	await _capture_image("02_charge")
	sm.data=base.duplicate(true)
	# 真实普攻在两簇外围命中：不按攻击力倍增，不复制，不扣饱腹。
	var points: Array[Vector2]=[Vector2(505,430),Vector2(1140,380)]
	for index in 2:
		p=points[index]
		_check(SR.is_walkable(p),"采晶外围站位合法")
		var food: float=sm.data[Run.KEY].satiety
		var copies: int=sm.data[Run.KEY].yaya_counter
		var prior_salt: int=sm.data[Run.KEY].bag.get("rock_salt",0)
		for n in 4: mine(p)
		_check(sm.data[Run.KEY].bag.get("rock_salt",0)==prior_salt+3,"每簇四次实际命中只发三盐")
		_check(sm.data[Run.KEY].satiety==food and sm.data[Run.KEY].yaya_counter==copies,"盐不消耗饱腹不触发复制")
		maze.player.position=p
		maze.camera.snap_to_target()
		flow._process(0)
		await _capture_image("03_exhausted_"+str(index))
	var mined: Dictionary=sm.data.duplicate(true)
	_check(sm.save(),"采晶持久化")
	sm.load_data()
	mine(points[0])
	_check(sm.data[Run.KEY].bag.rock_salt==6,"同日重载不刷新次数")
	calm()
	_check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"带盐跨图")
	_check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"同日切回盐池")
	mine(points[0])
	_check(sm.data[Run.KEY].bag.rock_salt==6,"切图不刷新次数")
	# 保存失败必须连同命中去重和裂纹额度回滚，重试原挥动仅给一盐。
	sm.data=base.duplicate(true)
	p=points[0]
	sm.data[Run.KEY].combat.cooldown=0.0
	_check(Run.combat_command(sm,"select",2).success and Run.combat_attack(sm,p,Vector2.UP).success,"回滚实验建立真实待挥动")
	var path: String=sm._active_save_path
	var prior: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,p,0.2).success and sm.data==prior,"盐/次数/命中/裂纹同笔保存失败全部回滚")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,p,0.2).success and sm.data[Run.KEY].bag.get("rock_salt",0)==1,"重试同次挥动恰好一盐")
	var serial: int=sm.data[Run.KEY].combat.basic_serial
	Crystal.melee(sm.data[Run.KEY].combat,p,"earth",serial)
	_check(Run.combat_tick(sm,p,0.05).success and sm.data[Run.KEY].bag.rock_salt==1,"同普攻多段去重")
	Crystal.melee(sm.data[Run.KEY].combat,points[1],"earth",serial)
	_check(Run.combat_tick(sm,points[1],0.05).success and sm.data[Run.KEY].bag.rock_salt==1,"同次普攻不能采第二簇")
	var interleaved: Dictionary={"throws":3}
	Crystal.impact(interleaved,0,"earth",1)
	Crystal.impact(interleaved,1,"earth",2)
	Crystal.impact(interleaved,1,"earth",1)
	_check(interleaved.salt_impacts.size()==2,"并行多弹道乱序命中仍按整次普攻去重")
	# 非土实际玩家弹丸即使队伍有铁山也不采；技能/敌人不进入事件。
	sm.data=base.duplicate(true)
	p=points[0]
	sm.data[Run.KEY].combat.cooldown=0.0
	Run.combat_command(sm,"select",1)
	Run.combat_attack(sm,p,Vector2.UP)
	for i in 10: Run.combat_tick(sm,p,0.05)
	_check(sm.data[Run.KEY].bag.is_empty(),"队伍有土但草普攻命中不采")
	var probe: Dictionary=sm.data[Run.KEY].combat.duplicate(true)
	_check(not Crystal.projectile(probe,Vector2(505,365),{"basic":false,"element":"earth"}) and not probe.has("salt_impacts"),"土技能/敌方非普攻无效")
	# 日期用显式时间注入纯事务，生产时只在命中事务读取一次本机时间。
	_check(Crystal.day(1767283199)==Crystal.day(1767283200)-1,"北京时间零点边界")
	var state: Dictionary={}
	var run: Dictionary={"bag":{},"combat":{}}
	for date in [20000,20000,20000,19999,20001,20007]:
		run.combat.salt_impacts=[{"id":"left","element":"earth"}]
		var result:=Crystal.apply(state,run,date)
		_check(result.success,"日期事务有效")
	_check(run.bag.rock_salt==5 and state[Crystal.KEY].left.used==1,"同日三份/回拨不退/跨多日不累计")
	_check(Crystal.used(state[Crystal.KEY],"left",20008)==0,"在线新日覆盖清除")
	# 保底绑定/支付/失败回滚，使用独立首次标记。
	sm.data=base.duplicate(true)
	sm.data[Run.KEY].combat.actors[B.ID].hp=0
	sm.data[Run.KEY].monsters[B.ID].capture_roll=0.999
	sm.data[Run.KEY].monsters[B.ID].copy_roll=0.99
	prior=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.defeat(sm,B.ID,B.HOME).success and sm.data==prior,"绑定保底保存失败不消耗资格")
	sm._active_save_path=path
	_check(Run.defeat(sm,B.ID,B.HOME).success,"首次合格击败绑定这只")
	_check(sm.data.get(Run.ROCK_FIRST,false) and sm.data[Run.KEY].monsters[B.ID].guaranteed and sm.data[Run.KEY].first_used==base[Run.KEY].first_used,"岩鬃兽资格独立于首史莱姆")
	_check(Run.chance(Run.snapshot(sm),B.row())<100,"隐藏保底不假造显示概率")
	prior=sm.data.duplicate(true)
	sm.data[Run.Progression.FOOD_KEY].values={"yaya":0.0,"tieshan":0.0}
	sm.data[Run.KEY].satiety=0.0
	_check(not Run.start_capture(sm,B.ID).success,"零饱腹不能免费捕获")
	sm.data=prior
	_check(Run.start_capture(sm,B.ID).success,"首次捕获正常支付")
	var paid_food: float=sm.data[Run.KEY].satiety
	sm.load_data()
	_check(Run.start_capture(sm,B.ID).success and sm.data[Run.KEY].satiety==paid_food,"中断续接不重扣饱腹")
	_check(Run.finish_capture(sm,B.ID,false).success,"未操作也保存结论")
	prior=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.resolve(sm,B.ID,true).success and sm.data==prior,"首捕发肉保存失败整笔回滚")
	sm._active_save_path=path
	_check(Run.resolve(sm,B.ID,true).get("caught",false) and sm.data[Run.KEY].bag.get("rockmane_meat",0)==1,"首次绕过操作与概率失败获得肉")
	_check(not Run.resolve(sm,B.ID,true).success,"不能重复发肉")
	# 放弃本只和整趟都不退绑定；盐仍保留日额度。
	var captured: Dictionary=sm.data.duplicate(true)
	sm.data=prior.duplicate(true)
	sm.data[Run.KEY].monsters[B.ID].erase("attempt")
	_check(Run.resolve(sm,B.ID,false).success and sm.data[Run.ROCK_FIRST],"放弃本只不退首次资格")
	calm()
	_check(Run.finish(sm,false,SR.SPAWN).success and sm.data[Run.ROCK_FIRST],"放弃整趟不退首次资格")
	sm.data=mined.duplicate(true)
	calm()
	_check(Run.finish(sm,false,SR.SPAWN).success,"放弃含盐探索")
	_check(sm.data[Crystal.KEY]==mined[Crystal.KEY],"放弃丢袋但日额度不退")
	sm.data=captured
	# 真实UI无操作首捕与结算回餐厅另一个独立样例。
	sm.data=base.duplicate(true)
	sm.data[Run.KEY].combat.actors[B.ID].hp=0
	sm.data[Run.KEY].monsters[B.ID].capture_roll=0.999
	sm.data[Run.KEY].monsters[B.ID].copy_roll=0.99
	maze.player.position=B.HOME+Vector2(0,25)
	maze.camera.snap_to_target()
	flow._process(0)
	await get_tree().create_timer(0.8).timeout
	flow._process(0)
	await get_tree().create_timer(0.5).timeout
	_check(flow.dialog.visible,"真实倒地捕获入口")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	flow._process(0)
	_check(flow.attempt.name_label.text=="岩鬃兽" and flow.attempt.base_value.text.contains("50"),"真实捕获名称与基础50%")
	await _capture_image("04_capture_ready")
	await _click(flow.attempt.yes_button)
	await get_tree().create_timer(13.5).timeout
	_check(flow.reward.visible and sm.data[Run.KEY].bag.get("rockmane_meat",0)==1,"真实无按键首捕成功")
	await _capture_image("05_meat_reward")
	await _click(flow.reward._confirm_button)
	_check(not maze.player.input_locked,"关闭奖励恢复输入")
	calm()
	mine(points[0])
	var stock: Dictionary=sm.warehouse_snapshot()
	calm()
	_check(Run.finish(sm,true,SR.ENTRANCE).success,"肉盐实际探索结算入仓")
	_check(sm.warehouse_snapshot().get("rockmane_meat",0)==stock.get("rockmane_meat",0)+1 and sm.warehouse_snapshot().get("rock_salt",0)==stock.get("rock_salt",0)+1,"两原料均入餐厅仓库")
	await _close_scene()
	_check(sm.take_warehouse_items({"rockmane_meat":1,"rock_salt":1}).success,"真实仓库取出本次原料")
	maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	scene=maze
	await get_tree().create_timer(0.6).timeout
	var player=maze.get_node("Player")
	player.global_position=_stand(maze.get_node("InteractPoints/Cauldron"))
	player.last_valid=player.global_position
	await _send_key(KEY_E)
	var cooking=get_tree().get_first_node_in_group("cooking_modal")
	_check(cooking.visible and cooking.recipe_id=="salt_grilled_rockmane","真实餐厅E打开既有盐烤岩鬃肉")
	if cooking._lesson_paused: await _send_key(KEY_E)
	await _capture_image("06_cooking_ingredients")
	await _click(cooking._start_button)
	await get_tree().create_timer(5.9).timeout
	_check(sm.inventory_quantity("salt_grilled_rockmane")==1,"真实烹饪倒计时产出既有料理")
	_check(sm.inventory_quantity("rockmane_meat")==0 and sm.inventory_quantity("rock_salt")==0,"实际扣除本次两种原料")
	await _capture_image("07_cooked")
	for i in 4:
		if not cooking.visible: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	_check(not cooking.visible and not player.input_locked,"烹饪关闭恢复输入")
	await _close_scene()
