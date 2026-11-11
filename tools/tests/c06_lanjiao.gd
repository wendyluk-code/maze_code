extends "res://tools/tests/combat_skill_01.gd"
const Charge=preload("res://scripts/maze/lanjiao_charge.gd")
const START=Vector2(1061,188)
const AIM=Vector2(-0.8203981667699868,0.5717926616881727)
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_c06_lanjiao_isolated","双重隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["lanjiao","dingdang"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["lanjiao","dingdang"]).success,"真实编队")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	_rules()
	_collision()
	await _inputs()
	# 生命周期用例结束旧探索会生成新布局，不能再让旧场景读取新一趟怪物表。
	maze.set_process(false)
	maze.capture_flow.skill_visual.set_process(false)
	_transactions()
	maze.queue_free()
	await get_tree().process_frame
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
func _sample(rank: int=1) -> Dictionary:
	var run:=Run.snapshot(sm)
	run.combat=Combat.create(10,500,START,Run.monsters_for(run))
	# 读档后的JSON小数不可经Vector2单精度重建后参与严格布局相等校验。
	run.combat.layout=run.layout.duplicate(true)
	Skills.ensure(run.combat)
	run.members[0].rank=rank
	run.combat.cooldown=0
	for id in run.monsters: run.monsters[id].status="skipped"
	Skills.select(run,1)
	return run
func _step(run: Dictionary,dt: float) -> void:
	for event in Charge.advance(run,dt):
		Skills.direct_damage(run,event.id,event.damage,false)
		if event.wall>0 and run.combat.actors[event.id].hp>0: Skills.damage(run,event.id,event.wall,false)
func _rules() -> void:
	for rank in range(1,7):
		for dt in [0.01,0.05,0.25,0.5]:
			var run:=_sample(rank)
			_check(Skills.attack(run,START,AIM),"释放"+str(rank))
			_check(is_equal_approx(run.combat.cooldown,1.8),"蓄势开始冷却")
			_check(not Skills.select(run,0) and not Skills.attack(run,START,Vector2.RIGHT),"蓄势拒绝切换与重复攻击")
			_step(run,0.2)
			_check(Combat.vec(run.combat.hero)==START,"蓄势原地")
			var left:=0.25
			while left>0.0000001:
				var used:=minf(dt,left)
				_step(run,used)
				left-=used
			_check(not Charge.active(run.combat),"冲撞按时结束")
			_check(absf(Combat.vec(run.combat.hero).distance_to(START)-float(Charge.rules(rank).distance))<0.01,"冲撞距离与步长一致",{"position":run.combat.hero})
			_check(is_equal_approx(Charge.speed(run.combat),1.15 if rank>=5 else 1),"五星加速")
			_step(run,1)
			_check(Charge.speed(run.combat)==1,"加速到期")
		var run:=_sample(rank)
		run.monsters.slime_1.status="alive"
		var a: Dictionary=run.combat.actors.slime_1
		a.position=Combat.pack(START+AIM*45)
		a.hp=100
		var before:=Combat.vec(a.position)
		Skills.attack(run,START,AIM)
		_step(run,0.45)
		_check(a.hp==100-roundi(10*float(Charge.rules(rank).damage)),"每目标仅基础伤害一次")
		_check(absf(Combat.vec(a.position).distance_to(before)-30)<0.01,"小怪推30")
		_check(not a.has("hit_remaining"),"不叠加普通击退")
	var marked:=_sample()
	marked.monsters.slime_1.status="alive"
	marked.combat.actors.slime_1.position=Combat.pack(START+AIM*40)
	Skills.apply_mark(marked,"slime_1",1)
	Skills.attack(marked,START,AIM)
	_step(marked,0.45)
	_check(not marked.combat.actors.slime_1.has("lock_mark"),"基础主动消费锁印")
	var sprint:=_sample()
	Skills.attack(sprint,START,AIM)
	Combat.advance(sprint,START,0.45,true)
	_check(is_equal_approx(sprint.combat.sprint,1),"冲撞不耗冲刺条")
	_check(not Charge.active(sprint.combat),"生产模拟完成冲撞")
	var hurt:=_sample()
	Skills.attack(hurt,START,AIM)
	Combat.Rock.hurt(hurt,START,START-AIM*10)
	_check(hurt.combat.hp<500 and Charge.active(hurt.combat),"实际受伤不免疫也不中断")
	Combat.advance(hurt,START,0.45)
	_check(not Charge.active(hurt.combat) and Combat.vec(hurt.combat.hero).distance_to(START)>90,"受伤后沿锁定方向冲完")
	var dead:=_sample()
	Skills.attack(dead,START,AIM)
	dead.combat.hp=0
	Combat.advance(dead,START,0.1)
	_check(not Charge.active(dead.combat),"死亡立即清理")
	for invalid in [-1,INF,NAN,2]:
		var broken:=_sample()
		Skills.attack(broken,START,AIM)
		broken.combat.lanjiao_charge.left=invalid
		_check(not Charge.valid(broken.combat),"非法时间拒绝")
func _collision() -> void:
	var run:=_sample(5)
	Skills.attack(run,START,Vector2.UP)
	_step(run,0.45)
	_check(Combat.vec(run.combat.hero).distance_to(START)<100 and not Charge.active(run.combat),"路沿阻挡立即结束不滑动")
	_check(Charge.speed(run.combat)==1.15,"撞停也触发五星加速")
	var portal: Vector2=Charge.portals("maze_entry")[0]
	_check(not Charge.player_allowed(portal+Vector2(60,0),portal+Vector2(57,0),"maze_entry"),"入口阻挡")
	var outward:=false
	for x in range(-57,58):
		for y in range(-19,20):
			var p:=portal+Vector2(x,y)
			if Roads.is_walkable(p) and p!=portal and Charge.player_allowed(portal,p,"maze_entry"): outward=true
	_check(outward,"旧位置在入口内可向可走区走出")
	_check(not Charge.solid(Vector2(-1,0),"maze_entry"),"地图边界不是墙伤")
	_check(Charge.solid(Vector2(650,1090),"maze_entry"),"既有栅栏实体识别")
	_check(not Charge.solid(START,"maze_entry"),"普通道路不误报实体")
	var wall_start:=Vector2.INF
	for x in range(650,684,2):
		for y in range(1050,1078,2):
			var p:=Vector2(x,y)
			if Roads.is_walkable(p) and Catalog.clear_of_props(p) and Roads.is_walkable(p-Vector2(0,20)):
				var probe:=_sample()
				probe.combat.actors.slime_1.position=Combat.pack(p)
				var row: Dictionary={}
				for candidate in Catalog.rows(probe.combat):
					if candidate.id=="slime_1": row=candidate; break
				if not row.is_empty() and Charge.push(probe,row,Vector2.DOWN): wall_start=p; break
		if wall_start.is_finite(): break
	_check(wall_start.is_finite(),"找到合法实体撞墙路线",{"start":str(wall_start)})
	if wall_start.is_finite():
		for rank in [1,4,6]:
			var wall_run:=_sample(rank)
			var hero:=wall_start-Vector2(0,20)
			wall_run.combat.hero=Combat.pack(hero)
			wall_run.monsters.slime_1.status="alive"
			wall_run.combat.actors.slime_1.position=Combat.pack(wall_start)
			wall_run.combat.actors.slime_1.hp=100
			Skills.attack(wall_run,hero,Vector2.DOWN)
			_step(wall_run,0.45)
			var rules:=Charge.rules(rank)
			_check(wall_run.combat.actors.slime_1.hp==100-roundi(10*rules.damage)-roundi(10*rules.wall),"实体撞墙追加一次伤害"+str(rank))
	for kind in ["lizard","wind_frog","rockmane"]:
		var big:=_sample()
		if kind=="wind_frog": Run.ensure_region(big,"fenshui")
		if kind=="rockmane": Run.ensure_region(big,"salt_pool")
		var id: String=Catalog.Frog.ID if kind=="wind_frog" else (Catalog.Rock.ID if kind=="rockmane" else "lizard_1")
		if not big.combat.actors.has(id):
			for row in Catalog.all(Catalog.BALANCE_VERSION,big.get("layout",[])):
				if row.kind==kind: id=row.id; break
		_check(big.combat.actors.has(id),"大型夹具存在"+kind)
		if not big.combat.actors.has(id): continue
		var big_start:=START if kind=="lizard" else (Vector2(1060,580) if kind=="wind_frog" else Vector2(1000,470))
		big.combat.hero=Combat.pack(big_start)
		big.monsters[id].status="alive"
		big.combat.actors[id].position=Combat.pack(big_start+AIM*20)
		if kind=="wind_frog": big.combat.actors[id].frog_phase="idle"
		var old: Array=big.combat.actors[id].position.duplicate()
		var hp: float=big.combat.actors[id].hp
		Skills.attack(big,big_start,AIM)
		_step(big,0.45)
		_check(big.combat.actors[id].position==old,"大型不位移"+kind)
		_check(big.combat.actors[id].hp==hp-8,"大型仅基础伤害"+kind)
func _transactions() -> void:
	var run:=_sample()
	sm.data[Run.KEY]=run
	maze.player.position=START
	var previous: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.combat_attack(sm,START,AIM).success and sm.data==previous,"起手失败回滚")
	sm._active_save_path=path
	_check(Run.combat_attack(sm,START,AIM).success,"真实事务起手")
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,START,0.3).success and sm.data==previous,"推进失败回滚位移状态")
	sm._active_save_path=path
	_check(sm.save(),"隔离保存")
	sm.load_data()
	_check(Charge.active(Run.snapshot(sm).combat) and Run.valid(Run.snapshot(sm)),"保存往返")
	_check(Run.begin(sm,START).success and not Charge.active(Run.snapshot(sm).combat),"重入清理不重放冲撞")
	run=_sample()
	sm.data[Run.KEY]=run
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(START+AIM*35)
	run.combat.actors.slime_1.hp=1
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.45
	Skills.attack(run,START,AIM)
	var exp_before: int=Skills.Growth.record(sm,"lanjiao").exp
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,START,0.3).success and sm.data==previous,"致死冲撞位移命中与经验回滚")
	sm._active_save_path=path
	var kill_result:=Run.combat_tick(sm,START,0.3)
	_check(kill_result.success and Skills.Growth.record(sm,"lanjiao").exp==exp_before+20,"恢复保存后致死只发一次经验",{"result":kill_result,"valid":Run.valid(Run.snapshot(sm)),"exp_before":exp_before,"growth":Skills.Growth.record(sm,"lanjiao"),"hp":Run.snapshot(sm).combat.actors.slime_1.hp})
	_check(Run.combat_tick(sm,Combat.vec(Run.snapshot(sm).combat.hero),0.15).success and Skills.Growth.record(sm,"lanjiao").exp==exp_before+20,"后续不重发经验")
	run=_sample()
	sm.data[Run.KEY]=run
	Skills.attack(run,START,AIM)
	run.combat.action_left=0
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.change_region(sm,"fenshui",Charge.Fenshui.SPAWN).success and sm.data==previous,"跨区失败保留冲撞")
	sm._active_save_path=path
	var region_result:=Run.change_region(sm,"fenshui",Charge.Fenshui.SPAWN)
	_check(region_result.success and not Charge.active(Run.snapshot(sm).combat),"跨区成功清理",region_result)
	_check(Run.change_region(sm,"maze_entry",START).success,"恢复首区")
	run=sm.data[Run.KEY]
	Skills.Charge.begin(run.combat,5,10,AIM)
	sm.data["first_exploration_gate_v1"]="done"
	_check(Run.finish(sm,false,START).success and not Charge.active(Run.snapshot(sm).combat),"返程清理冲撞")
	sm.request_maze_entry(["lanjiao","dingdang"])
	_check(Run.begin(sm,START).success,"下一趟可出发")
func _inputs() -> void:
	var run:=_sample(5)
	sm.data[Run.KEY]=run
	maze.player.position=START
	maze.capture_flow.window_focused=true
	maze.capture_flow.busy=false
	maze.capture_flow.save_retry_delay=0
	await _send_key(KEY_1)
	await _mouse(MOUSE_BUTTON_LEFT,_world(START+AIM*200))
	_check(Charge.active(Run.snapshot(sm).combat),"真实鼠标起手")
	if not Charge.active(Run.snapshot(sm).combat): return
	_check(Combat.vec(Run.snapshot(sm).combat.lanjiao_charge.aim).distance_to(AIM)<0.01,"鼠标方向锁定")
	await _send_key(KEY_SPACE)
	_check(Run.snapshot(sm).combat.selected==1,"真实按键冲撞期间拒绝切换")
	_tick(0.1)
	_check(maze.player.position.distance_to(START)<0.1,"真实蓄势原地")
	await _capture_image("c06_warmup")
	for i in 10:
		_tick(0.02)
		await get_tree().create_timer(0.02).timeout
	_check(maze.player.position.distance_to(START)>20,"真实推进产生位移")
	_check(maze.player.get_node("SprintWind").strength>0,"实际位移显示复用风线")
	await _capture_image("c06_charge")
	var before: Dictionary=Run.snapshot(sm).combat.duplicate(true)
	maze.capture_flow.busy=true
	maze.capture_flow._process(0.3)
	_check(Run.snapshot(sm).combat==before,"暂停冻结冲撞")
	maze.capture_flow.busy=false
	_tick(0.15)
	_check(not Charge.active(Run.snapshot(sm).combat),"真实冲撞完成")
	await _send_key(KEY_SPACE)
	_check(Run.snapshot(sm).combat.selected==0,"结束恢复切换")
