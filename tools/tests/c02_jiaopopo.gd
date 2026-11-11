extends "res://tools/tests/combat_skill_01.gd"
const Smoke=preload("res://scripts/maze/jiaopopo_smoke.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_c02_jiaopopo_isolated","项目与用户目录双重隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["jiaopopo","dingdang","tieshan","yaya"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["jiaopopo","dingdang","tieshan","yaya"]).success,"真实编队椒婆婆出征")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	var original=load("res://c02_baseline_team_attack.gd")
	_check(not original.select(Run.snapshot(sm),1),"基线复现：椒婆婆不能选择")
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected==1,"数字键选择椒婆婆")
	await _click(maze.capture_flow.skill_bar.buttons[0])
	await _click(maze.capture_flow.skill_bar.buttons[1])
	_check(Run.snapshot(sm).combat.selected==1,"真实鼠标技能栏选择")
	maze.player.facing=-ALONG
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER-ALONG*200))
	_check(Run.snapshot(sm).combat.shots[0].kind=="jiaopopo","真实鼠标投罐")
	_tick(0.15)
	await _capture_image("c02_throw")
	_tick(0.3)
	_tick(0.15)
	_check(Run.snapshot(sm).combat.has("jiaopopo_smoke"),"投罐落地生成烟区")
	await _send_key(KEY_2)
	_check(Run.snapshot(sm).combat.has("jiaopopo_smoke"),"切换保留烟区")
	await _visual_checks()
	_rules()
	_simulation()
	_transactions()
	maze.queue_free()
	await get_tree().process_frame
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _visual_checks() -> void:
	var run: Dictionary=sm.data[Run.KEY]
	var center:=Combat.vec(run.combat.jiaopopo_smoke.position)
	maze.player.position=CENTER-ALONG*130
	run.combat.hero=Combat.pack(maze.player.position)
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(center)
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=10.0
	run.combat.actors.slime_1.skill_reuse=3.0
	maze.capture_flow._process(0)
	await RenderingServer.frame_post_draw
	var visual=maze.capture_flow.skill_visual
	_check(visual.textures.has("jiaopopo") and visual.smoke_sprite.texture!=null,"正式香料罐与烟素材已加载")
	_check(visual.smoke_sprite.visible and is_equal_approx(visual.smoke_radius,65.0),"一星烟区真实半径65可见")
	await _capture_image("c02_smoke65_enemy")
	for frame in range(8):
		_tick(0.125)
		await get_tree().process_frame
		_check(visual.smoke_sprite.frame==int(float(Run.snapshot(sm).combat.jiaopopo_smoke.elapsed)*8)%8,"烟动画逐帧取样："+str(frame))
	Smoke.land(sm.data[Run.KEY].combat,center,3,1)
	maze.capture_flow._process(0)
	await get_tree().process_frame
	_check(is_equal_approx(visual.smoke_radius,80.0),"三星烟区真实半径80可见")
	await _capture_image("c02_smoke80_enemy")
	var image: Image=load("res://assets/combat/jiaopopo/smoke.png").get_image()
	_check(image.get_size()==Vector2i(1024,512) and image.detect_alpha()!=Image.ALPHA_NONE,"烟图8帧尺寸与透明通道")
	Smoke.clear(sm.data[Run.KEY].combat)
	maze.capture_flow._process(0)
	await RenderingServer.frame_post_draw
	_check(not visual.smoke_sprite.visible and visual.smoke_radius==0,"烟区清除后图像和范围同步隐藏")
	_check(visual.smoke_layer.get_index()==1 and visual.smoke_layer.get_parent()==maze,"烟层在背景上、怪物和血条下")

func _sample() -> Dictionary:
	var run:=Run.snapshot(sm)
	run.combat=Combat.create(10,500,CENTER,Run.monsters_for(run))
	run.combat.cooldown=0.0
	Skills.ensure(run.combat)
	for id in run.monsters: run.monsters[id].status="skipped"
	run.monsters.slime_1.status="alive"
	var a: Dictionary=run.combat.actors.slime_1
	a.position=Combat.pack(CENTER)
	a.hp=100
	a.mode="idle"
	a.skill_reuse=3.0
	return run

func _rules() -> void:
	for rank in range(1,7):
		for step in [1.0/30,1.0/60,1.0/120,0.25]:
			var run:=_sample()
			var a: Dictionary=run.combat.actors.slime_1
			Smoke.land(run.combat,CENTER,rank,20)
			Skills.apply_mark(run,"slime_1",3)
			var ticks:=0
			for i in range(int(round(float(Smoke.rules(rank).duration)/step))):
				for event in Smoke.advance(run,step):
					ticks+=1
					Skills.damage(run,event.id,event.damage,false)
			_check(ticks==(4 if rank>=5 else 3),"每秒结算与到期末跳 rank="+str(rank)+" dt="+str(step))
			_check(a.hp==100-ticks*(8 if rank>=2 else 7),"星级持续伤害")
			_check(a.has("lock_mark") and not a.has("hit_remaining"),"烟伤不消费锁印、不产生通用击退")
			_check(not run.combat.has("jiaopopo_smoke"),"到期清理")
		var run:=_sample()
		Smoke.land(run.combat,CENTER,rank,20)
		_check(is_equal_approx(Smoke.speed(run.combat,CENTER),0.7 if rank>=4 else 0.8),"星级减速")
		_check(Smoke.speed(run.combat,CENTER+Vector2(81,0))==1.0,"离开立即解除减速")
		_check(Smoke.contains(run.combat,CENTER+Vector2(70,0))==(rank>=3),"星级半径")
		Smoke.land(run.combat,CENTER+Vector2(200,0),rank,20)
		_check(not Smoke.contains(run.combat,CENTER),"新烟区替换旧烟区")
	var run:=_sample()
	Smoke.land(run.combat,CENTER,6,20)
	Smoke.advance(run,1.0)
	run.combat.actors.slime_1.position=Combat.pack(CENTER+Vector2(200,0))
	Smoke.advance(run,0.1)
	run.combat.actors.slime_1.position=Combat.pack(CENTER)
	Smoke.advance(run,1.0)
	_check(not Smoke.retreating(run.combat,"slime_1"),"离烟重置连续停留")
	Smoke.advance(run,1.0)
	_check(Smoke.retreating(run.combat,"slime_1"),"连续2秒触发退避")
	var distance:=Smoke.retreat_step(run.combat,"slime_1",0.6,85).length()
	_check(is_equal_approx(distance,51.0) and not Smoke.retreating(run.combat,"slime_1"),"基础速度退避0.6秒")
	Smoke.advance(run,0.2)
	_check(not Smoke.retreating(run.combat,"slime_1"),"每目标每片烟仅一次")
	run.combat.hp=0
	Smoke.advance(run,0.1)
	_check(not run.combat.has("jiaopopo_smoke"),"死亡清理")

func _transactions() -> void:
	_fixture()
	var run: Dictionary=sm.data[Run.KEY]
	Smoke.land(run.combat,CENTER,3,1)
	_check(Run.valid(run),"烟区可保存状态通过校验")
	var before: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.combat_command(sm,"select",1).success and sm.data==before,"选择保存失败完整回滚烟区")
	sm._active_save_path=path
	run=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(CENTER)
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.45
	run.combat.jiaopopo_smoke.elapsed=0.9
	run.combat.jiaopopo_smoke.ticks=0
	before=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.1).success and sm.data==before,"烟伤保存失败回滚HP、计时与次数")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,CENTER,0.1).success,"烟伤保存恢复后可重试")
	run=sm.data[Run.KEY]
	Skills.select(run,1)
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	Skills.attack(run,CENTER,ALONG)
	_check(sm.save(),"烟区检查点保存")
	sm.load_data()
	_check(sm.data[Run.KEY].combat.has("jiaopopo_smoke"),"读取状态保留待重入清理烟区")
	_check(Run.begin(sm,CENTER).success and not Run.snapshot(sm).combat.has("jiaopopo_smoke"),"重新进入清理烟区")
	_check(Run.snapshot(sm).combat.shots.is_empty(),"重新进入移除未落地香料罐")
	Smoke.land(sm.data[Run.KEY].combat,CENTER,3,1)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	before=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and sm.data==before,"跨区失败回滚烟区")
	sm._active_save_path=path
	_check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and not Run.snapshot(sm).combat.has("jiaopopo_smoke"),"跨区成功清理烟区")

func _simulation() -> void:
	var movement: Array=[]
	var movement_start:=Catalog.nearest_clear_point(CENTER)
	var movement_target:=movement_start
	for direction in [ALONG,-ALONG,Vector2.DOWN,Vector2.UP]:
		var candidate: Vector2=movement_start+direction*75
		if Combat.move_monster(movement_start,candidate,8.5).distance_to(movement_start)>8:
			movement_target=candidate
			break
	for slowed in [false,true]:
		var sample:=_sample()
		var actor: Dictionary=sample.combat.actors.slime_1
		var start:=movement_start
		actor.position=Combat.pack(start)
		actor.mode="chase"
		if slowed: Smoke.land(sample.combat,start,4,0)
		Combat.advance(sample,movement_target,0.1)
		movement.append(start.distance_to(Combat.vec(actor.position)))
	_check(absf(float(movement[1])/float(movement[0])-0.7)<0.02,"实际追逐位移减速30%",{"movement":movement})
	for step in [1.0/30,1.0/60,1.0/120,0.25]:
		var run:=_sample()
		run.combat.actors.slime_1.hp=14
		run.combat.actors.slime_1.mode="windup"
		run.combat.actors.slime_1.windup=10.0
		Smoke.land(run.combat,CENTER,1,3)
		for i in range(int(round(3.0/step))): Combat.advance(run,CENTER,step)
		_check(run.combat.actors.slime_1.hp==11 and not run.combat.has("jiaopopo_smoke"),"实际模拟帧率一致 dt="+str(step))
	var run:=_sample()
	run.combat.actors.slime_1.hp=14
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*30)
	Skills.select(run,1)
	Skills.attack(run,CENTER,ALONG)
	for i in 72: Combat.advance(run,CENTER,1.0/120)
	_check(run.combat.has("jiaopopo_smoke") and run.combat.shots.is_empty(),"真实飞行落地")
	_check(run.combat.actors.slime_1.hp==14,"沿途敌人不截罐，无落地爆伤")
	_check(Combat.vec(run.combat.jiaopopo_smoke.position).distance_to(CENTER)<=260.001,"射程不超260")
	_check(Combat.projectile_clear(Combat.vec(run.combat.jiaopopo_smoke.position),"maze_entry"),"落点不进入障碍")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		run=_sample()
		for id in run.monsters: run.monsters[id].status="skipped"
		Skills.select(run,1)
		Skills.attack(run,CENTER,direction)
		for i in 72: Combat.advance(run,CENTER,1.0/120)
		var at:=Combat.vec(run.combat.jiaopopo_smoke.position)
		var clear:=true
		for i in 131:
			clear=clear and Combat.projectile_clear(CENTER.lerp(at,float(i)/130),"maze_entry")
		_check(clear,"投罐路径保持弹道通行："+str(direction))
	run=_sample()
	for id in run.monsters: run.monsters[id].status="skipped"
	Skills.select(run,1)
	var wall_start:=Vector2(700,1100)
	Skills.attack(run,wall_start,Vector2.LEFT)
	for i in 72: Combat.advance(run,wall_start,1.0/120)
	var wall_land:=Combat.vec(run.combat.jiaopopo_smoke.position)
	_check(wall_land.x>=684 and wall_land.x<=686,"实体栅栏前最后通行点落烟")
	# 同一片烟对同一生命仅退避一次；退避经过的每个小步必须可通行。
	run=_sample()
	run.combat.actors.slime_1.hp=14
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=10.0
	Smoke.land(run.combat,CENTER,6,0)
	for i in 240: Combat.advance(run,CENTER,1.0/120)
	_check(Smoke.retreating(run.combat,"slime_1"),"实际连续停留触发退避")
	for i in 72:
		var old:=Combat.vec(run.combat.actors.slime_1.position)
		Combat.advance(run,CENTER,1.0/120)
		_check(Combat.region_line(old,Combat.vec(run.combat.actors.slime_1.position),"maze_entry"),"退避逐步遵守道路碰撞")
	_check(not Smoke.retreating(run.combat,"slime_1"),"实际退避到0.6秒停止")
	run.combat.hp=0
	Combat.advance(run,CENTER,0.1)
	_check(not run.combat.has("jiaopopo_smoke") and run.combat.shots.is_empty(),"实际模拟死亡清除烟与投罐")
	for region in ["maze_entry","fenshui","salt_pool"]:
		run=_sample()
		Run.ensure_region(run,region)
		var id: String="lizard_1" if region=="maze_entry" else (Catalog.Frog.ID if region=="fenshui" else Catalog.Rock.ID)
		if not run.combat.actors.has(id):
			_check(false,"大型怪物夹具存在："+id)
			continue
		for key in run.monsters: run.monsters[key].status="skipped"
		run.monsters[id].status="alive"
		var a: Dictionary=run.combat.actors[id]
		a.mode="chase"
		if region=="fenshui": a.frog_phase="active"
		var at:=Combat.vec(a.position)
		Smoke.land(run.combat,at,6,3)
		var hp: int=a.hp
		for event in Smoke.advance(run,2.1): Skills.damage(run,event.id,event.damage,false)
		_check(not Smoke.retreating(run.combat,id) and a.hp==hp-2,"大型受烟伤、不退避："+id)
		_check(is_equal_approx(Smoke.speed(run.combat,at),0.7),"大型地面减速系数："+id)
	var rock_run:=_sample()
	Run.ensure_region(rock_run,"salt_pool")
	for id in rock_run.monsters: rock_run.monsters[id].status="skipped"
	rock_run.monsters[Catalog.Rock.ID].status="alive"
	var rock: Dictionary=rock_run.combat.actors[Catalog.Rock.ID]
	rock.mode="chase"
	var origin:=Combat.vec(rock.position)
	var target:=origin
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var candidate: Vector2=origin+direction*350
		if preload("res://scripts/maze/rockmane_path.gd").step(origin,candidate,7).distance_to(origin)>6:
			target=candidate
			break
	var distances: Array=[]
	for slowed in [false,true]:
		var sample: Dictionary=rock_run.duplicate(true)
		if slowed: Smoke.land(sample.combat,origin,4,0)
		Combat.Rock.advance(sample,target,0.1)
		distances.append(origin.distance_to(Combat.vec(sample.combat.actors[Catalog.Rock.ID].position)))
	_check(float(distances[0])>0 and absf(float(distances[1])/float(distances[0])-0.7)<0.02,"岩鬃兽实际地面追踪减速30%",{"distances":distances})
