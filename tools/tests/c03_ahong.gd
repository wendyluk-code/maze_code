extends "res://tools/tests/combat_skill_01.gd"
const Trail=preload("res://scripts/maze/ahong_trail.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_c03_ahong_isolated","项目名和用户目录双重隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["ahong","dingdang","jiaopopo","yaya"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["ahong","dingdang","jiaopopo","yaya"]).success,"真实编队阿轰出征")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	_rules()
	_controls()
	_water()
	await _interface()
	await _keyboard_passive()
	_transactions()
	await _water_scene()
	maze.queue_free()
	await get_tree().process_frame
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _sample(rank: int=1) -> Dictionary:
	var run:=Run.snapshot(sm)
	run.combat=Combat.create(10,500,CENTER,Catalog.all(Catalog.BALANCE_VERSION,run.get("layout",[])))
	Skills.ensure(run.combat)
	run.members[0].rank=rank
	for id in run.monsters: run.monsters[id].status="skipped"
	run.monsters.slime_1.status="alive"
	var a: Dictionary=run.combat.actors.slime_1
	a.position=Combat.pack(CENTER+ALONG*100)
	a.mode="windup"
	a.windup=0.45
	a.skill_reuse=3.0
	return run

func _passive_step(run: Dictionary,p: Vector2,dt: float) -> void:
	Trail.begin_step(run,p,dt)
	run.combat.hero=Combat.pack(p)
	Trail.end_step(run,dt)

func _seed_trail(run: Dictionary,point: Vector2=CENTER) -> void:
	Trail.begin_step(run,point,0.01)
	var config:=Trail.rules(int(run.members[0].rank))
	run.combat.ahong_trail.marks=[{"position":Combat.pack(point),"left":float(config.duration),"water":0}]

func _rules() -> void:
	for rank in range(1,7):
		var config:=Trail.rules(rank)
		_check(config.duration==(4.0 if rank>=2 else 3.0) and config.radius==(30.0 if rank>=3 else 24.0),"星级地面持续与半径 "+str(rank))
		_check(config.limit==(8 if rank>=5 else 6) and config.stun==(0.5 if rank>=4 else 0.4) and config.water==(2.0 if rank>=6 else 1.0),"星级麻痹上限水时长 "+str(rank))
		for step in [1.0/30,1.0/60,1.0/120,0.1]:
			var run:=_sample(rank)
			for i in range(roundi(0.6/step)):
				_passive_step(run,CENTER+ALONG.normalized()*48.0*float(i+1)*step/0.6,step)
			_check(run.combat.ahong_trail.marks.size()==1,"双门槛帧率一致 rank="+str(rank)+" dt="+str(step))
			_check(run.combat.throws==0 and run.combat.hits==0 and run.combat.hp==500,"不攻击不伤害")
		var run:=_sample(rank)
		_passive_step(run,CENTER+Vector2(60,0),0.3)
		_check(run.combat.ahong_trail.marks.is_empty(),"距离足够时间不足不生成")
		_passive_step(run,CENTER+Vector2(60,0),0.3)
		_check(run.combat.ahong_trail.marks.is_empty(),"原地不补发雷印")
		_passive_step(run,CENTER+Vector2(61,0),0.01)
		_check(run.combat.ahong_trail.marks.size()==1,"继续移动满足双门槛")
		var a: Dictionary=run.combat.actors.slime_1
		a.position=Combat.pack(CENTER+Vector2(61+float(config.radius),0))
		Skills.apply_mark(run,"slime_1",1)
		var hp: int=a.hp
		Trail.begin_step(run,Combat.vec(run.combat.hero),0.01)
		_check(Trail.paralyzed(a) and is_equal_approx(a.ahong_stun,float(config.stun)),"边界触碰麻痹")
		_check(a.hp==hp and a.has("lock_mark") and run.combat.hits==0,"麻痹不伤害不消费锁印")
		Trail.end_step(run,float(config.stun))
		_check(not Trail.paralyzed(a),"麻痹到期恢复")
		Trail.begin_step(run,Combat.vec(run.combat.hero),2.9)
		_check(not Trail.paralyzed(a),"同目标三秒内不重复")
		_seed_trail(run,Combat.vec(a.position))
		Trail.begin_step(run,Combat.vec(run.combat.hero),0.1)
		_check(Trail.paralyzed(a),"三秒到期重新触碰")
		# 上限需要高速持续移动，地面持续短于八次0.6秒，直接注入仍有效旧印记检验淘汰。
		run=_sample(rank)
		_seed_trail(run)
		var s: Dictionary=run.combat.ahong_trail
		s.marks.clear()
		for i in range(int(config.limit)): s.marks.append({"position":[float(i),0.0],"left":float(config.duration),"water":0})
		s.clock=0.6
		s.distance=48.0
		Trail.begin_step(run,CENTER+Vector2(1,0),0.01)
		_check(s.marks.size()==int(config.limit) and s.marks[0].position[0]==1.0,"超上限淘汰最旧印记")
		Trail.begin_step(run,CENTER+Vector2(1,0),float(config.duration))
		_check(s.marks.is_empty(),"印记到期清理")
	var run:=_sample()
	run.combat.actors.slime_1.mode="idle"
	_passive_step(run,CENTER+ALONG*100,0.5)
	_check(not run.combat.has("ahong_trail"),"非战斗移动不留印")
	run=_sample()
	run.members=[]
	_passive_step(run,CENTER+ALONG*100,0.5)
	_check(not run.combat.has("ahong_trail"),"未编队阿轰不触发")

func _controls() -> void:
	var run:=_sample()
	var a: Dictionary=run.combat.actors.slime_1
	a.position=Combat.pack(CENTER)
	_seed_trail(run)
	a.cast=0.4
	a.cast_aim=[1.0,0.0]
	run.combat.enemy_shots=[{"position":Combat.pack(CENTER-ALONG*50),"direction":Combat.pack(-ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
	Combat.advance(run,CENTER+ALONG*80,0.1)
	_check(is_equal_approx(a.windup,0.45) and is_equal_approx(a.cast,0.4) and Combat.vec(a.position)==CENTER,"普通怪物移动蓄力暂停")
	_check(run.combat.enemy_shots[0].distance>0,"已发射普通弹丸继续飞行")
	for i in 4: Combat.advance(run,Combat.vec(run.combat.hero),0.1)
	_check(a.cast<0.4,"解除后续接蓄力")
	for region in ["maze_entry","fenshui","salt_pool"]:
		var specimen:=_sample()
		Run.ensure_region(specimen,region)
		for row in Catalog.rows(specimen.combat):
			if row.kind in ["wind_frog","rockmane"]: continue
			var sample:=specimen.duplicate(true)
			for id in sample.monsters: sample.monsters[id].status="skipped"
			sample.monsters[row.id].status="alive"
			var actor: Dictionary=sample.combat.actors[row.id]
			actor.mode="windup"
			actor.windup=0.3
			actor.cooldown=0.5
			var p:=Combat.vec(actor.position)
			sample.combat.hero=Combat.pack(p)
			_seed_trail(sample,p)
			Combat.advance(sample,p,0.1)
			_check(Trail.paralyzed(actor) and Combat.vec(actor.position)==p and is_equal_approx(actor.windup,0.3) and is_equal_approx(actor.cooldown,0.5),"全种类移动攻击时钟暂停："+str(row.kind))
	for kind in ["frog","rock"]:
		run=_sample()
		Run.ensure_region(run,"fenshui" if kind=="frog" else "salt_pool")
		var id: String=Catalog.Frog.ID if kind=="frog" else Catalog.Rock.ID
		for key in run.monsters: run.monsters[key].status="skipped"
		run.monsters[id].status="alive"
		a=run.combat.actors[id]
		a.mode="chase"
		var p:=Combat.vec(a.position)
		run.combat.hero=Combat.pack(p)
		if kind=="frog":
			a.frog_phase="airborne"
			a.frog_origin=a.position.duplicate()
			a.frog_target=Combat.pack(p+Vector2(20,0))
			a.frog_left=0.35
			a.frog_shots=[{"position":Combat.pack(p+Vector2(50,0)),"direction":[1.0,0.0],"distance":0.0}]
		else:
			a.rock_phase="charge"
			a.rock_left=1.0
		_seed_trail(run,p)
		Combat.advance(run,p,0.1)
		_check(Trail.paralyzed(a) and Combat.vec(a.position)==p,"大型无麻痹免疫 "+kind)
		_check(is_equal_approx(a.frog_left,0.35) if kind=="frog" else is_equal_approx(a.rock_left,1.0),"大型动作计时冻结 "+kind)
		if kind=="frog": _check(not a.frog_shots.is_empty() and a.frog_shots[0].distance>0,"巨蛙腾空冻结时水团继续")
		for i in 4: Combat.advance(run,p,0.1)
		_check(a.frog_left<0.35 if kind=="frog" else a.rock_left<1.0,"大型解除后续接 "+kind)

func _water() -> void:
	Trail.Water.prepare()
	var large: Array=[]
	for id in Trail.Water.cells:
		if Trail.Water.cells[id].size()>200: large.append(id)
	_check(large.size()>1,"实际地形有独立连通水域")
	if large.size()<2: return
	var p:=Vector2(950,400)
	var q:=Vector2(1100,600)
	var other:=Vector2(500,600)
	_check(Trail.Water.water(p,"fenshui") and Trail.Water.water(q,"fenshui") and Trail.Water.water(other,"fenshui"),"独立指定的三个实际水面点")
	_check(Trail.Water.component(p,"fenshui")==Trail.Water.component(q,"fenshui"),"绕岛同连通水域")
	_check(Trail.Water.component(p,"fenshui")!=Trail.Water.component(other,"fenshui"),"实际异水域隔离")
	_check(Trail.Water.component(preload("res://data/maze/fenshui_roads.gd").ENTRANCE,"fenshui")==0 and Trail.Water.component(p,"salt_pool")==0,"干路与非浅水区域不导电")
	for rank in [1,6]:
		var run:=_sample(rank)
		Run.ensure_region(run,"fenshui")
		for id in run.monsters: run.monsters[id].status="skipped"
		var rows: Array=Catalog.Fenshui.all()
		var a: Dictionary=run.combat.actors[rows[0].id]
		var b: Dictionary=run.combat.actors[rows[1].id]
		for row in rows.slice(0,2):
			run.monsters[row.id].status="alive"
			run.combat.actors[row.id].mode="chase"
		a.position=Combat.pack(q)
		b.position=Combat.pack(other)
		run.combat.hero=Combat.pack(p)
		Trail.begin_step(run,p,0.01)
		run.combat.ahong_trail.clock=0.6
		run.combat.ahong_trail.distance=48.0
		run.combat.ahong_trail.position=Combat.pack(p-Vector2(1,0))
		Trail.begin_step(run,p,0.01)
		_check(Trail.paralyzed(a) and not Trail.paralyzed(b),"实际传导只控制同水域 rank="+str(rank))
		_check(run.combat.ahong_trail.marks[0].left==(2.0 if rank==6 else 1.0),"水域带电星级时长")
		Trail.begin_step(run,p,2.0 if rank==6 else 1.0)
		_check(run.combat.ahong_trail.marks.is_empty(),"水域带电到期")

func _interface() -> void:
	_fixture()
	maze.capture_flow.skill_bar.sync(Run.snapshot(sm))
	_check(maze.capture_flow.skill_bar.key_labels[1].text=="被动","技能栏明确显示被动")
	await _click(maze.capture_flow.skill_bar.buttons[1])
	_check(maze.capture_flow.character_details.visible,"点击被动槽打开既有详情")
	_check(maze.capture_flow.character_details.active_damage.text=="不造成伤害","详情不伪报攻击倍率")
	await _capture_image("c03_passive_details")
	await _send_key(KEY_ESCAPE)
	_check(not maze.capture_flow.character_details.visible and not maze.player.input_locked,"关闭详情恢复输入")
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected==0,"被动键不改变主动技能")
	await _send_key(KEY_2)
	_check(Run.snapshot(sm).combat.selected==2,"其他角色数字键不变")
	await _send_key(KEY_SPACE)
	var run: Dictionary=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.45
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*100)
	# 使用真实事务和角色位置，动作由真实编队被动生成。
	for i in 7:
		maze.player.position=CENTER+ALONG.normalized()*float(i+1)*8
		_tick(0.1)
	_check(not Run.snapshot(sm).combat.ahong_trail.marks.is_empty(),"真实编队战斗移动自动留印")
	maze.capture_flow.skill_visual._process(0)
	await _capture_image("c03_ground_marks")
	run=sm.data[Run.KEY]
	run.combat.actors.slime_1.position=run.combat.ahong_trail.marks[0].position.duplicate()
	_tick(0.01)
	var monster=maze.capture_flow.monsters.slime_1
	var clock: float=monster.elapsed
	monster._process(0.2)
	_check(monster.ahong_paralyzed and monster.elapsed==clock,"实际怪物麻痹动画计时冻结")
	await _capture_image("c03_paralyzed")
	var before:=Run.snapshot(sm)
	maze.capture_flow._focus_lost()
	maze.capture_flow._process(0.3)
	_check(Run.snapshot(sm)==before,"暂停不推进雷印与麻痹时钟")
	maze.capture_flow.window_focused=true
	await _sprint_checks()

func _transactions() -> void:
	_fixture()
	var run: Dictionary=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.45
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*100)
	_seed_trail(run)
	_check(Run.valid(run),"雷印状态有效")
	var previous: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER+ALONG*10,0.1).success and sm.data==previous,"保存失败完整回滚雷印位置时间与状态")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,CENTER+ALONG*10,0.1).success,"恢复保存后可重试")
	_check(sm.save(),"隔离存档保存")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)),"雷印序列化往返校验")
	_check(Run.begin(sm,CENTER).success and not Run.snapshot(sm).combat.has("ahong_trail"),"重入立即清理")
	run=sm.data[Run.KEY]
	run.combat.actors.slime_1.mode="chase"
	_seed_trail(run)
	for a in run.combat.actors.values(): a.mode="idle"
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and sm.data==previous,"跨区失败回滚雷印")
	sm._active_save_path=path
	_check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and not Run.snapshot(sm).combat.has("ahong_trail"),"跨区成功清理")
	run=_sample()
	_seed_trail(run)
	run.combat.actors.slime_1.mode="idle"
	Trail.end_step(run,0.1)
	_check(not run.combat.has("ahong_trail"),"退出战斗立即清理")
	run=_sample()
	_seed_trail(run)
	run.combat.hp=0
	Trail.begin_step(run,CENTER,0.1)
	_check(not run.combat.has("ahong_trail"),"主角死亡清理")
	run=_sample()
	_seed_trail(run)
	run.combat.ahong_trail.marks[0].left=NAN
	_check(not Run.valid(run),"损坏非有限雷印拒绝进入事务")
	for bad in [null,[],12,"broken"]:
		var malformed:=_sample()
		malformed.combat.actors=bad
		_check(not Combat.valid(malformed.combat),"损坏怪物集合安全拒绝")
	var malformed:=_sample()
	malformed.combat.actors.slime_1=null
	_check(not Combat.valid(malformed.combat),"损坏单个怪物安全拒绝")

func _water_scene() -> void:
	maze.queue_free()
	await get_tree().process_frame
	var story=preload("res://scripts/maze/yufeng_salia_story.gd")
	sm.data[story.KEY]=story.fresh("done")
	_check(sm.record_maze_location("fenshui",preload("res://data/maze/fenshui_roads.gd").SPAWN).success,"实景水域入口保存")
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	maze.capture_flow.set_process(false)
	var run: Dictionary=sm.data[Run.KEY]
	for id in run.monsters: run.monsters[id].status="skipped"
	var id: String=Catalog.Fenshui.all()[0].id
	run.monsters[id].status="alive"
	var a: Dictionary=run.combat.actors[id]
	a.position=[1050.0,430.0]
	a.mode="chase"
	maze.player.position=Vector2(950,400)
	run.combat.hero=Combat.pack(maze.player.position)
	Trail.begin_step(run,maze.player.position,0.01)
	run.combat.ahong_trail.clock=0.6
	run.combat.ahong_trail.distance=48.0
	run.combat.ahong_trail.position=[949.0,400.0]
	Trail.begin_step(run,maze.player.position,0.01)
	maze.capture_flow._process(0)
	maze.capture_flow.skill_visual._process(0)
	maze.camera.position=maze.player.position
	await get_tree().process_frame
	_check(Trail.paralyzed(a) and maze.capture_flow.skill_visual.trail_layer.state.marks[0].water>0,"实际分水庭显示带电水域并麻痹鱼")
	await _capture_image("c03_water_conduction")
	var frog: Dictionary=run.combat.actors[Catalog.Frog.ID]
	run.monsters[Catalog.Frog.ID].status="alive"
	frog.position=[1050.0,430.0]
	frog.mode="chase"
	frog.frog_phase="airborne"
	frog.frog_origin=[1030.0,430.0]
	frog.frog_target=[1070.0,430.0]
	frog.frog_left=0.175
	frog.frog_shots=[{"position":[1090.0,440.0],"direction":[1.0,0.0],"distance":0.0}]
	run.monsters[id].status="skipped"
	maze.capture_flow._process(0)
	Trail.begin_step(run,maze.player.position,0.01)
	maze.capture_flow._process(0)
	maze.capture_flow.skill_visual._process(0)
	await _capture_image("c03_frog_air_stun")
	_check(Trail.paralyzed(frog),"真实巨蛙场景受到水域麻痹")
	Trail.clear(run.combat)
	maze.capture_flow.skill_visual._process(0)
	_check(maze.capture_flow.skill_visual.trail_layer.state.is_empty(),"清理后水域特效消失")

func _keyboard_passive() -> void:
	for sprint in [false,true]:
		_fixture()
		var run: Dictionary=sm.data[Run.KEY]
		run.monsters.slime_1.status="alive"
		run.combat.actors.slime_1.mode="chase"
		run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*130)
		maze.capture_flow.set_process(true)
		if sprint: await _key_state(KEY_SHIFT,true)
		Input.action_press("ui_left")
		Input.action_press("ui_down")
		await get_tree().create_timer(0.8).timeout
		Input.action_release("ui_left")
		Input.action_release("ui_down")
		if sprint: await _key_state(KEY_SHIFT,false)
		maze.capture_flow.set_process(false)
		var c: Dictionary=Run.snapshot(sm).combat
		_check(maze.player.position.distance_to(CENTER)>=48 and c.get("ahong_trail",{}).get("marks",[]).size()==1 and c.throws==0 and c.selected==0,"真实移动按键自动触发且冲刺遵守0.6秒："+str(sprint),{"moved":maze.player.position.distance_to(CENTER),"elapsed":c.elapsed,"trail":c.get("ahong_trail",{}),"actor":c.actors.slime_1,"paused":maze.capture_flow.combat_paused(),"selected":c.selected,"throws":c.throws})
		await _capture_image("c03_keyboard_sprint" if sprint else "c03_keyboard_walk")
