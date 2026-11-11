extends "res://tools/tests/combat_02_flow.gd"
const FB=preload("res://data/maze/fenshui_boss.gd")
const RB=preload("res://data/maze/salt_boss.gd")
const SR=preload("res://data/maze/salt_pool_roads.gd")
func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	_check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"进入盐池")
	var run:=Run.snapshot(sm)
	var a: Dictionary=run.combat.actors[RB.ID]
	var point:=Combat.vec(a.position)
	run.combat.hero=Combat.pack(point+Vector2(0,30))
	Combat.Skills.damage(run,RB.ID,1)
	_check(float(a.get("flash_remaining",0))>0,"统一伤害入口写入白闪")
	Combat.hit(a,point,point+Vector2(0,30),12)
	Combat.advance(run,point+Vector2(0,30),0.05)
	_check(Combat.vec(a.position).distance_to(point)>1,"Boss实际受击位移")
	_check(RB.HOME.distance_to(Vector2(850,425))<45,"岩鬃兽固定红框陆地出生")
	await _close_scene()
	maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	run=Run.snapshot(sm)
	a=run.combat.actors[RB.ID]
	_check(RB.allowed(RB.HOME),"红框出生点可站立")
	var original:=run.duplicate(true)
	maze.player.position=RB.HOME+Vector2(0,30)
	maze.camera.snap_to_target()
	run.combat.selected=2
	run.combat.action_left=0.31
	run.combat.axe_pending=true
	run.combat.axe_damage=3
	sm.data[Run.KEY]=run
	maze.capture_flow._process(0.2)
	var hit_actor: Dictionary=sm.data[Run.KEY].combat.actors[RB.ID]
	_check(hit_actor.hp<120 and Combat.vec(hit_actor.position).distance_to(RB.HOME)>1,"实际铁山范围攻击扣血并击退")
	_check(maze.capture_flow.monsters[RB.ID].body.material.get_shader_parameter("flash"),"同帧补算后实际怪物仍保留白闪")
	maze.capture_flow._process(0)
	await _capture_image("rockmane_hit_flash")
	var legacy:=original.duplicate(true)
	legacy.combat.actors[RB.ID].position=[1025,205]
	legacy.monsters[RB.ID].spawn_position=[1025,205]
	Run.ensure_layout(legacy)
	_check(legacy.combat.actors[RB.ID].position==Combat.pack(RB.HOME),"旧档未交战岩鬃兽迁到红框")
	run=original
	sm.data[Run.KEY]=run
	a=run.combat.actors[RB.ID]
	var hero:=RB.HOME+Vector2(130,0)
	var hp: float=run.combat.hp
	Combat.Rock.advance(run,hero,0.05)
	_check(a.rock_phase=="charge","远距离开始咆哮前摇")
	Combat.Rock.advance(run,hero,1.1)
	_check(run.combat.hp<hp and a.position==Combat.pack(RB.HOME),"咆哮远程命中且不再冲撞")
	_check(not Combat.Rock.roar_hits(RB.HOME,Vector2.RIGHT,RB.HOME+Vector2(0,130)),"扇形侧面可躲避")
	_check(float(run.combat.get("rock_shake_left",0))>0,"释放咆哮写入震动")
	sm.data[Run.KEY]=run
	_check(sm.save(),"咆哮阶段保存")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)),"咆哮阶段读档合法")
	maze.player.position=hero
	maze.camera.snap_to_target()
	maze.capture_flow._process(0)
	await get_tree().create_timer(0.1).timeout
	_check(maze.camera.offset.length()>0,"实际摄像机震动")
	_check(maze.capture_flow.monsters[RB.ID].config.width==120,"岩鬃兽放大25%")
	await _capture_image("rockmane_roar")
	var nav=preload("res://scripts/maze/rockmane_path.gd")
	for goal in [Vector2(1050,520),Vector2(650,690),Vector2(1190,650)]:
		var position:=RB.HOME
		var legal:=true
		for i in 1800:
			position=nav.step(position,goal,7)
			legal=legal and RB.allowed(position)
			if position.distance_to(goal)<20: break
		_check(legal and position.distance_to(goal)<25,"岩鬃兽跨盐池绕障追到目标",{"goal":str(goal),"position":str(position)})
	# 普通怪贴近时可完成一次攻击，而不是保护圈让攻击射线失效。
	for row in Catalog.rows(run.combat):
		if row.kind not in ["mimic_crab","blind_scorpion"]: continue
		var trial:=run.duplicate(true)
		var enemy: Dictionary=trial.combat.actors[row.id]
		enemy.mode="windup"
		enemy.windup=0.01
		enemy.attack_aim=[1.0,0.0]
		var nearby:=Combat.vec(enemy.position)+Vector2(0,8)
		var health: float=trial.combat.hp
		Combat.advance(trial,nearby,0.02)
		_check(trial.combat.hp<health,"贴近命中："+row.id)
	sm.data[Run.KEY]=original.duplicate(true)
	sm.data[Run.KEY].combat.actors[RB.ID].hp=0
	_check(Run.defeat(sm,RB.ID,RB.HOME+Vector2(0,30)).success,"咆哮Boss击败进入原捕获")
	_check(Run.start_capture(sm,RB.ID).success,"捕获仍正常支付饱腹")
	_check(Run.finish_capture(sm,RB.ID,true).success,"捕获操作完成")
	_check(Run.resolve(sm,RB.ID,true).get("caught",false),"首次岩鬃兽捕获保证保留")
	_check(sm.data[Run.KEY].bag.get("rockmane_meat",0)==1,"捕获后才获得岩鬃肉")
	await _close_scene()
	if OS.get_environment("BOSS_REPAIR_SCOPE")!="salt": await _frog_scene()

func _frog_scene() -> void:
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.hp=sm.data[Run.KEY].combat.max_hp
	_check(Run.change_region(sm,"fenshui",Vector2(1560,218)).success,"切换分水庭")
	_check(sm.set_yufeng_salia_state("done").success,"御风完成前置")
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	var base:=Run.snapshot(sm)
	for target in [Vector2(600,350),Vector2(1300,600),Vector2(1000,280),Vector2(1470,410)]:
		var trial:=base.duplicate(true)
		trial.combat.frog_unlocked=true
		var actor: Dictionary=trial.combat.actors[FB.ID]
		var attacked:=false
		Combat.Frog.advance(trial,target,0.05)
		_check(actor.frog_phase=="warning","远端入水立即激怒",{"target":str(target)})
		for i in 1800:
			trial.combat.hp=trial.combat.max_hp
			trial.combat.last_attacker="slime"
			Combat.advance(trial,target,0.05)
			attacked=attacked or (trial.combat.last_attacker=="wind_frog" and trial.combat.hp<trial.combat.max_hp)
			if attacked: break
		_check(attacked,"巨蛙持续跨岸追击并实际命中远端主角",{"target":str(target),"position":str(actor.position)})
	var node=maze.capture_flow.monsters[FB.ID]
	var actor: Dictionary=base.combat.actors[FB.ID]
	for phase in ["dormant","active","warning","airborne","landing"]:
		actor.frog_phase=phase
		actor.frog_left=0.2
		node.sync_action(actor)
		_check(node.action=="special","统一主体图集避免比例突变："+phase)
	maze.camera.target=null
	maze.camera.position=FB.HOME
	await _capture_image("frog_compact_marker")
	await _close_scene()
