extends "res://tools/tests/combat_skill_01.gd"
const DIR=Vector2(0.8203981667699868,-0.5717926616881727)
const CAST=Vector2(821.308421642903,354.5123121882797)
const Tide=preload("res://scripts/maze/xiluomei_net.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_c04_xiluomei_isolated","项目名与用户目录双重隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["xiluomei","dingdang","jiaopopo","ahong"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["xiluomei","dingdang","jiaopopo","ahong"]).success,"真实编队汐罗美出征")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	_rules()
	_controls()
	_collision_and_large()
	await _interface()
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
	run.combat=Combat.create(10,500,CAST,Catalog.all(Catalog.BALANCE_VERSION,run.get("layout",[])))
	Skills.ensure(run.combat)
	run.members[0].rank=rank
	run.combat.cooldown=0.0
	Skills.select(run,1)
	for id in run.monsters: run.monsters[id].status="skipped"
	run.monsters.slime_1.status="alive"
	var a: Dictionary=run.combat.actors.slime_1
	a.position=Combat.pack(CAST+DIR.normalized()*230)
	a.mode="windup"
	a.windup=0.45
	a.skill_reuse=3.0
	return run

func _net_step(run: Dictionary,dt: float) -> void:
	Tide.advance_controls(run,dt)
	for event in Tide.initial_hits(run): Skills.direct_damage(run,event.id,event.damage,false)
	for event in Tide.advance(run,dt): Skills.direct_damage(run,event.id,event.damage,false)

func _rules() -> void:
	for rank in range(1,7):
		var config:=Tide.rules(rank)
		var run:=_sample(rank)
		var a: Dictionary=run.combat.actors.slime_1
		var start:=Combat.vec(a.position)
		_check(Skills.attack(run,CAST,DIR),"首段可释放星级"+str(rank))
		_check(is_equal_approx(run.combat.cooldown,3.2),"首段开始原等级冷却")
		_net_step(run,0.01)
		_check(a.hp==14-roundi(10*float(config.first)),"首段伤害星级"+str(rank))
		_check(absf(Combat.vec(a.position).distance_to(start)-40)<0.01,"首段牵引40像素")
		_check(not a.has("hit_remaining"),"水网没有额外普通击退")
		var cooldown: float=run.combat.cooldown
		_check(Skills.attack(run,CAST,DIR),"冷却内允许外潮")
		_check(not Skills.attack(run,CAST,DIR),"外潮请求不重复")
		_net_step(run,0.01)
		_check(a.hp==maxi(0,14-roundi(10*float(config.first))-roundi(10*float(config.out))),"外潮伤害星级"+str(rank))
		_check(absf(Combat.vec(a.position).distance_to(start+DIR.normalized()*40)-float(config.push))<0.01,"外潮推距星级"+str(rank))
		_check(not run.combat.has("xiluomei_net") and run.combat.cooldown==cooldown,"外潮结束不重置冷却")
		var hits: int=run.combat.hits
		_net_step(run,2.0)
		_check(run.combat.hits==hits,"外潮后不再自动收网")
		for dt in [0.1,0.25,0.5,1.0/60]:
			run=_sample(rank)
			a=run.combat.actors.slime_1
			Skills.attack(run,CAST,DIR)
			for i in roundi(1.5/dt): _net_step(run,dt)
			_check(not run.combat.has("xiluomei_net") and run.combat.hits==2,"超时互斥与推进步长"+str(dt))
			_check(a.hp==maxi(0,14-roundi(10*float(config.first))-roundi(10*float(config.close))),"收网伤害星级"+str(rank))
			_check(Tide.speed(a)==(0.7 if a.hp>0 else 1.0) and Tide.rooted(a)==(rank>=6 and a.hp>0),"收网减速与六星束缚")
			_check(not Skills.attack(run,CAST,DIR),"边界后无法改成外潮")
			_net_step(run,1.0)
			_check(Tide.speed(a)==1 and not Tide.rooted(a),"控制到期清理")
	var run:=_sample()
	Skills.attack(run,CAST,DIR)
	_net_step(run,1.499)
	_check(Skills.attack(run,CAST,DIR),"1.499秒仍可选择外潮")
	_net_step(run,0.01)
	_check(run.combat.xiluomei_feedback.stage=="out","边界前请求在下一步优先结算外潮")
	run=_sample()
	Skills.attack(run,CAST,DIR)
	Skills.select(run,2)
	_net_step(run,1.5)
	_check(run.combat.selected==2 and run.combat.xiluomei_feedback.stage=="close","切换角色仍自动收网")
	run=_sample()
	Skills.apply_mark(run,"slime_1",6)
	Skills.attack(run,CAST,DIR)
	_net_step(run,0.01)
	_check(run.combat.actors.slime_1.hp==8 and not run.combat.actors.slime_1.has("lock_mark"),"首段直接命中消费25%锁印")
	Skills.apply_mark(run,"slime_1",1)
	Skills.attack(run,CAST,DIR)
	_net_step(run,0.01)
	_check(not run.combat.actors.slime_1.has("lock_mark"),"外潮直接命中消费锁印")
	for level in [1,15,30]:
		run=_sample()
		run.combat.skill_levels={"xiluomei":level}
		Skills.attack(run,CAST,DIR)
		var stats:=Skills.Growth.active_skill("xiluomei",level)
		_check(run.combat.xiluomei_net.damage==roundi(10*float(stats.multiplier)) and is_equal_approx(run.combat.cooldown,stats.interval),"等级倍率与冷却不改"+str(level))
	run=_sample()
	run.combat.actors.slime_1.hp=1
	var start:=Combat.vec(run.combat.actors.slime_1.position)
	Skills.attack(run,CAST,DIR)
	Skills.attack(run,CAST,DIR)
	_net_step(run,0.01)
	_check(run.combat.hits==1 and Combat.vec(run.combat.actors.slime_1.position).distance_to(start+DIR*40)<0.01,"同帧双击先结算首段，外潮不再移动已死目标")

func _controls() -> void:
	for row in Catalog.all():
		if row.kind!="lizard": continue
		var run:=_sample(6)
		run.monsters.slime_1.status="skipped"
		run.monsters[row.id].status="alive"
		var a: Dictionary=run.combat.actors[row.id]
		a.position=Combat.pack(Vector2(720,370)+Vector2(0.884,-0.467).normalized()*230)
		var start: Array=a.position.duplicate()
		Skills.attack(run,Vector2(720,370),Vector2(0.884,-0.467))
		_net_step(run,1.5)
		_check(a.position==start and a.hp==84-7-11 and not Tide.rooted(a) and Tide.speed(a)==0.7,"大型石化蜥蜴受伤减速但不位移束缚")
		break
	var run:=_sample(6)
	var a: Dictionary=run.combat.actors.slime_1
	a.position=Combat.pack(Vector2(720,370)+Vector2(0.884,-0.467).normalized()*100)
	a.mode="chase"
	a.tide_root=0.6
	a.tide_slow=1.0
	var start: Array=a.position.duplicate()
	Combat.advance(run,Vector2(720,370),0.5)
	_check(a.position==start and float(a.tide_root)>0,"束缚阻止追击移动")
	Combat.advance(run,Vector2(720,370),0.2)
	_check(a.position!=start and not Tide.rooted(a),"束缚结束恢复追击")
	run=_sample()
	a=run.combat.actors.slime_1
	a.tide_slow=1.0
	a.ahong_stun=0.4
	var old: Array=a.position.duplicate()
	Combat.advance(run,Vector2(720,370),0.2)
	_check(a.position==old and float(a.tide_slow)<1.0,"阿轰麻痹期间水减速仍计时")
	for bad in [null,[],12,"broken"]:
		run=_sample()
		run.combat.actors=bad
		_check(not Combat.valid(run.combat),"损坏怪物集合拒绝")
	run=_sample()
	Skills.attack(run,Vector2(720,370),Vector2(0.884,-0.467))
	run.combat.xiluomei_net.left=NAN
	_check(not Combat.valid(run.combat),"非有限网时间拒绝")

func _interface() -> void:
	_fixture()
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected==1,"数字键选择汐罗美")
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER-ALONG*180))
	var run:=Run.snapshot(sm)
	_check(run.combat.has("xiluomei_net") and Combat.vec(run.combat.xiluomei_net.position).distance_to(CENTER-ALONG.normalized()*280)<1,"真实鼠标方向固定280中心")
	_tick(0.1)
	maze.capture_flow.skill_visual._process(0)
	await _capture_image("c04_first_net")
	_check(maze.capture_flow.skill_bar.captions[1].text.begins_with("外潮"),"技能栏提示第二段窗口")
	var before:=Run.snapshot(sm)
	maze.capture_flow._focus_lost()
	maze.capture_flow._process(0.3)
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER))
	_check(Run.snapshot(sm)==before,"暂停冻结时钟并拦截攻击")
	maze.capture_flow.window_focused=true
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER-ALONG*180))
	_tick(0.01)
	_check(not Run.snapshot(sm).combat.has("xiluomei_net") and Run.snapshot(sm).combat.xiluomei_feedback.stage=="out","真实第二次鼠标外潮")
	await _capture_image("c04_outward")
	_fixture()
	await _mouse(MOUSE_BUTTON_LEFT,maze.capture_flow.skill_bar.buttons[1].get_global_rect().get_center())
	_check(Run.snapshot(sm).combat.selected==1 and Run.snapshot(sm).combat.throws==0,"技能按钮选择不穿透攻击")
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER-ALONG*180))
	await _send_key(KEY_2)
	for i in 3: _tick(0.5)
	_check(Run.snapshot(sm).combat.selected==2 and Run.snapshot(sm).combat.xiluomei_feedback.stage=="close","真实切换后超时收网")
	await _capture_image("c04_close")

func _collision_and_large() -> void:
	for region in ["fenshui","salt_pool"]:
		var run:=_sample(6)
		Run.ensure_region(run,region)
		for id in run.monsters: run.monsters[id].status="skipped"
		var rows: Array=Catalog.Fenshui.all() if region=="fenshui" else Catalog.Salt.all()
		for row in rows:
			run.monsters[row.id].status="alive"
			var a: Dictionary=run.combat.actors[row.id]
			for angle in 8:
				var start: Vector2=row.position
				var finish:=Tide.displace(run,row,start,Vector2.RIGHT.rotated(angle*TAU/8)*100)
				_check(Catalog.Fenshui.allowed(finish,row.position) if region=="fenshui" else Catalog.Salt.allowed(finish,row.position),"强制位移保持活动区 "+str(row.id)+" "+str(angle))
				if region=="fenshui": _check(Combat.WaterSpacing.line_clear(run,row.id,start,finish),"不穿水怪身体与巨蛙落点")
			run.monsters[row.id].status="skipped"
		var id: String=Catalog.Frog.ID if region=="fenshui" else Catalog.Rock.ID
		run.monsters[id].status="alive"
		var a: Dictionary=run.combat.actors[id]
		a.mode="chase"
		if region=="fenshui": a.frog_phase="active"
		var start: Array=a.position.duplicate()
		var hp: int=a.hp
		Tide.open(run,Combat.vec(a.position),6,10,Vector2.RIGHT)
		_net_step(run,0.01)
		_check(a.position==start and a.hp==hp-7 and not a.has("hit_remaining"),"大型首段只伤害 "+region)
		run.combat.xiluomei_net.outward=true
		_net_step(run,0.01)
		_check(a.position==start and a.hp==hp-16,"大型外潮不位移且不免伤 "+region)
		Tide.open(run,Combat.vec(a.position),6,10,Vector2.RIGHT)
		_net_step(run,1.5)
		_check(a.position==start and Tide.speed(a)==0.7 and not Tide.rooted(a),"大型收网减速但不束缚 "+region)
	var run:=_sample(6)
	var row: Dictionary=Catalog.find("slime_1",Catalog.BALANCE_VERSION,run.get("layout",[]))
	var blocked:=Tide.displace(run,row,Vector2(1010,223),Vector2(0,100))
	_check(blocked.distance_to(Vector2(1010,223))<100 and Roads.is_walkable(blocked) and Catalog.clear_of_props(blocked),"路边截断位移")
	_check(Tide.center_for(Vector2(700,1090),Vector2.LEFT,"maze_entry").x>=684,"网中心不穿既有栅栏")
	_check(Tide.center_for(Vector2(1200,200),Vector2.RIGHT,"maze_entry").x<=Roads.SIZE.x,"网中心不出地图边界")
	# 椒婆婆退避与束缚共存：退避时间照常消耗，不能移动或延长控制。
	var a: Dictionary=run.combat.actors.slime_1
	a.position=[1010.0,223.0]
	a.mode="chase"
	a.tide_root=0.6
	Skills.Smoke.land(run.combat,Vector2(1010,223),6,1)
	run.combat.jiaopopo_smoke.retreats.slime_1={"left":0.6,"direction":[1.0,0.0]}
	var start: Array=a.position.duplicate()
	Combat.advance(run,CAST,0.3)
	_check(a.position==start and float(run.combat.jiaopopo_smoke.retreats.slime_1.left)<0.31,"束缚阻挡烟区退避且退避计时正常")

func _transactions() -> void:
	_fixture()
	var run: Dictionary=sm.data[Run.KEY]
	Skills.select(run,1)
	var previous: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.combat_attack(sm,CENTER,ALONG).success and sm.data==previous,"首段保存失败回滚")
	sm._active_save_path=path
	_check(Run.combat_attack(sm,CENTER,ALONG).success,"恢复保存可重试首段")
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_attack(sm,CENTER,ALONG).success and sm.data==previous,"外潮请求保存失败回滚")
	_check(not Run.combat_tick(sm,CENTER,0.1).success and sm.data==previous,"网推进保存失败回滚")
	sm._active_save_path=path
	_check(sm.save(),"隔离存档保存")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)),"水网序列化往返")
	_check(Run.begin(sm,CENTER).success and not Run.snapshot(sm).combat.has("xiluomei_net"),"重入清理不重放伤害")
	# 实际结算步失败时，伤害、位移、命中次数与击杀经验共同回滚。
	run=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=[1010.0,223.0]
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.45
	run.combat.actors.slime_1.hp=1
	Tide.open(run,Vector2(1010,223),6,10,Vector2.RIGHT)
	var exp_before: int=Skills.Growth.record(sm,"xiluomei").exp
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.01).success and sm.data==previous,"致死首段伤害位移与经验保存失败全部回滚")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,CENTER,0.01).success and Skills.Growth.record(sm,"xiluomei").exp==exp_before+20,"首段击杀只发一次原有经验")
	_check(Run.combat_tick(sm,CENTER,0.01).success and Skills.Growth.record(sm,"xiluomei").exp==exp_before+20,"后续推进不重复击杀经验")
	run=sm.data[Run.KEY]
	run.combat.xiluomei_net.left=0.01
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.01).success and sm.data==previous,"自动收网保存失败恢复选择窗口")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,CENTER,0.01).success and not Run.snapshot(sm).combat.has("xiluomei_net"),"自动收网保存恢复后重试")
	run=sm.data[Run.KEY]
	for key in run.monsters:
		run.monsters[key].status="skipped"
		run.combat.actors[key].mode="idle"
	run.pending=""
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	Skills.attack(run,CENTER,ALONG)
	run.combat.action_left=0.0
	previous=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and sm.data==previous,"跨区保存失败保留网")
	sm._active_save_path=path
	_check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and not Run.snapshot(sm).combat.has("xiluomei_net"),"跨区清理水网")
	run=_sample()
	Skills.attack(run,CENTER,ALONG)
	run.combat.hp=0
	_net_step(run,0.1)
	_check(not run.combat.has("xiluomei_net") and run.combat.hits==0,"死亡清理无延迟伤害")

func _water_scene() -> void:
	maze.queue_free()
	await get_tree().process_frame
	var story=preload("res://scripts/maze/yufeng_salia_story.gd")
	sm.data[story.KEY]=story.fresh("done")
	_check(sm.record_maze_location("fenshui",preload("res://data/maze/fenshui_roads.gd").SPAWN).success,"实际分水庭场景入口")
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	maze.capture_flow.set_process(false)
	var run: Dictionary=sm.data[Run.KEY]
	for id in run.monsters: run.monsters[id].status="skipped"
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	run.members[0].rank=6
	var id: String=Catalog.Fenshui.all()[0].id
	run.monsters[id].status="alive"
	var a: Dictionary=run.combat.actors[id]
	a.position=[1094.0,592.0]
	a.mode="windup"
	a.windup=0.45
	maze.player.position=Vector2(950,400)
	run.combat.hero=Combat.pack(maze.player.position)
	maze.camera.position=maze.player.position
	maze.capture_flow.window_focused=true
	maze.capture_flow.save_retry_delay=0
	maze.capture_flow.busy=false
	await _send_key(KEY_1)
	await _mouse(MOUSE_BUTTON_LEFT,_world(Vector2(1100,600)))
	_check(Run.snapshot(sm).combat.has("xiluomei_net"),"分水庭真实鼠标首段")
	_tick(0.01)
	_check(Run.snapshot(sm).combat.actors[id].hp<20,"分水庭水网首段实际伤害")
	maze.capture_flow.skill_visual._process(0)
	await _capture_image("c04_water_first")
	# 玩家沿水面接近固定网心，网心保持原地；怪物仍遵守既有追击边界。
	var center: Array=Run.snapshot(sm).combat.xiluomei_net.position.duplicate()
	maze.player.position=Vector2(1080,580)
	for dt in [0.5,0.5,0.49]: _tick(dt)
	run=Run.snapshot(sm)
	_check(not run.combat.has("xiluomei_net") and run.combat.xiluomei_feedback.position==center,"移动后收网仍在固定网心")
	_check(Tide.rooted(run.combat.actors[id]) and Tide.speed(run.combat.actors[id])==0.7,"分水庭六星实际收网束缚减速")
	maze.capture_flow.skill_visual._process(0)
	await _capture_image("c04_water_close_root")
	# 详情复用原模态框，关闭后恢复输入。
	maze.capture_flow.skill_bar.details_requested.emit(1)
	await get_tree().process_frame
	maze.capture_flow._process(0)
	await _assert_persistent_details("汐罗美详情")
	await _capture_image("c04_details")
	await _send_key(KEY_ESCAPE)
	maze.capture_flow._process(0)
	_check(not maze.capture_flow.character_details.visible and not maze.player.input_locked and maze.capture_flow.skill_bar.visible,"详情关闭恢复输入和技能栏")
	for cycle in 3:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=true
		event.double_click=true
		event.position=maze.capture_flow.skill_bar.buttons[1].get_global_rect().get_center()
		get_viewport().push_input(event)
		await get_tree().process_frame
		await _mouse_state(false,event.position)
		await _assert_persistent_details("真实双击第"+str(cycle+1)+"轮")
		var frozen:=Run.snapshot(sm)
		maze.capture_flow._process(0.2)
		_check(Run.snapshot(sm)==frozen and maze.capture_flow.combat_paused(),"详情可见时保持暂停 "+str(cycle))
		await _send_key(KEY_ESCAPE)
		maze.capture_flow._process(0)
		_check(not maze.capture_flow.character_details.visible and maze.capture_flow.skill_bar.visible and not maze.player.input_locked,"连续开关详情恢复 "+str(cycle))
	run=sm.data[Run.KEY]
	Tide.open(run,Vector2(1100,600),6,10,Vector2.RIGHT)
	var exit_result:=Run.finish(sm,false,Roads.SPAWN)
	_check(not exit_result.success and exit_result.get("reason","")=="first_exploration","水网不绕过原首探退出门禁",exit_result)
	sm.data["first_exploration_gate_v1"]="done"
	exit_result=Run.finish(sm,false,Roads.SPAWN)
	_check(exit_result.success and not Run.snapshot(sm).combat.has("xiluomei_net"),"退出探索清理网与控制",exit_result)


func _assert_persistent_details(label: String) -> void:
	var flow=maze.capture_flow
	flow._process(0)
	await get_tree().process_frame
	_check(flow.character_details.is_visible_in_tree() and flow.combat_paused(),label+"详情可见且战斗暂停")
	_check(flow.skill_bar.is_visible_in_tree() and flow.controls_hint.is_visible_in_tree() and maze.map_ui.mini_button.is_visible_in_tree(),label+"常驻技能栏提示和小地图保留")
	_check(flow.skill_bar.get_parent()==flow.character_details.get_parent() and flow.skill_bar.get_index()<flow.character_details.get_index() and flow.controls_hint.get_index()<flow.character_details.get_index(),label+"技能栏与提示绘制在详情暗幕下")
	var frozen:=Run.snapshot(sm)
	await _mouse(MOUSE_BUTTON_LEFT,flow.skill_bar.buttons[2].get_global_rect().get_center())
	await _mouse(MOUSE_BUTTON_LEFT,maze.map_ui.mini_button.get_global_rect().get_center()+Vector2(0,35))
	flow._process(0.2)
	_check(flow.character_details.visible and Run.snapshot(sm)==frozen and not maze.map_ui.expanded,label+"暗幕拦截底层选择攻击和小地图点击")
