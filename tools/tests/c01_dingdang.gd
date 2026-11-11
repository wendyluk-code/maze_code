extends "res://tools/tests/combat_skill_01.gd"
const Chest = preload("res://data/maze/entry_chests.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_c01_dingdang_isolated","独立项目名和用户目录双重隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["dingdang","tieshan","yufeng","salia","yaya"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["dingdang","tieshan","yufeng","salia"]).success,"实际编队叮当出征")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	var original_skills=load("res://c01_baseline_team_attack.gd")
	var original_run:=Run.snapshot(sm)
	_check(not original_skills.select(original_run,1),"原始基线实际复现：叮当不能选择")
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected==1,"真实数字键选择叮当")
	await _click(maze.capture_flow.skill_bar.buttons[0])
	await _click(maze.capture_flow.skill_bar.buttons[1])
	_check(Run.snapshot(sm).combat.selected==1,"真实鼠标技能栏选择叮当")
	var run: Dictionary=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*50)
	run.combat.actors.slime_1.skill_reuse=2.0
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*100))
	_check(run!=sm.data[Run.KEY],"鼠标攻击通过存档事务替换状态")
	_check(Run.snapshot(sm).combat.shots[0].kind=="dingdang","真实鼠标发射钥匙")
	await _capture_image("c01_key")
	_tick(0.14)
	run=Run.snapshot(sm)
	_check(run.combat.actors.slime_1.has("lock_mark"),"钥匙实际轨迹命中施印")
	await _capture_image("c01_mark")
	await _send_key(KEY_SPACE)
	sm.data[Run.KEY].combat.cooldown=0.0
	sm.data[Run.KEY].combat.action_left=0.0
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*100))
	_tick(0.2)
	_check(not Run.snapshot(sm).combat.actors.slime_1.has("lock_mark"),"实际锅铲命中消耗锁印")
	await _capture_image("c01_consumed")
	_fixture()
	var baseline: Dictionary=sm.data.duplicate(true)
	for rank in range(7):
		var rules:=Skills.dingdang_rules(rank)
		_check(rules.mark_seconds==(5 if rank>=3 else 3) and rules.mark_damage_bonus==(0.25 if rank>=5 else 0.15),"0–6星锁印配置："+str(rank))
		_check(rules.get("chest_gold_bonus",0.0)==[0.0,0.1,0.15,0.15,0.2,0.2,0.3][rank],"0–6星宝箱配置："+str(rank))
		if rank==0: continue # 存档中的可出征角色从1星起，0星仅配置基线。
		sm.data=baseline.duplicate(true)
		sm.data[Run.KEY].members[0].rank=rank
		_chest_checks(rank)
	sm.data=baseline.duplicate(true)
	_rules_checks()
	_attack_paths()
	_projectile_limits()
	_reload_checks()
	maze.queue_free()
	await get_tree().process_frame
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _chest_checks(rank: int) -> void:
	var position:=Vector2(725,369)
	var id: String=Chest.all()[0].id
	var before: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not sm.claim_exploration_chest(id,position).success and sm.data==before,"宝箱保存失败回滚："+str(rank))
	sm._active_save_path=path
	var result: Dictionary=sm.claim_exploration_chest(id,position)
	_check(result.success and result.amount==[100,110,115,115,120,120,130][rank],"实际出征星级金币："+str(rank))
	before=sm.data.duplicate(true)
	_check(not sm.claim_exploration_chest(id,position).success and sm.data==before,"重复领取无奖励："+str(rank))
	sm.load_data()
	_check(sm.is_chest_claimed(id) and sm.gold_balance()==before.gold,"宝箱重载一致："+str(rank))

func _rules_checks() -> void:
	var base:=Run.snapshot(sm)
	for rank in range(1,7):
		for attacker in ["hero","yaya","tieshan","yufeng","salia"]:
			var run:=base.duplicate(true)
			var a: Dictionary=run.combat.actors.slime_1
			run.monsters.slime_1.status="alive"
			a.hp=100
			a.mode="idle"
			Skills.apply_mark(run,"slime_1",rank)
			Skills.damage(run,"slime_1",1)
			_check(a.has("lock_mark"),"间接伤害不消费："+str(rank)+attacker)
			Skills.apply_mark(run,"slime_1",rank)
			_check(a.lock_mark.left==(5.0 if rank>=3 else 3.0),"钥匙重复刷新单份计时")
			Skills.direct_damage(run,"slime_1",20)
			_check(a.hp==99-(25 if rank>=5 else 23) and not a.has("lock_mark"),"直接命中增伤一次："+str(rank)+attacker)
			var hp: int=a.hp
			Skills.direct_damage(run,"slime_1",20)
			_check(a.hp==hp-20,"第二次命中无增伤")
			Skills.apply_mark(run,"slime_1",rank)
			Skills.advance(run,CENTER,5.01)
			_check(not a.has("lock_mark"),"锁印过期")
	var run:=base.duplicate(true)
	run.monsters.slime_1.status="alive"
	Skills.apply_mark(run,"slime_1",1)
	run.combat.actors.slime_1.lock_mark.left=-1
	_check(not Skills.valid(run.combat),"拒绝损坏锁印计时")
	# 拥有和预览编队均不替代实际出征名单。
	sm.data[Run.KEY].members[0].id="yaya"
	sm._maze_entry_party=["dingdang"]
	var reward: Dictionary=sm.claim_exploration_chest(Chest.all()[0].id,Vector2(725,369))
	_check(reward.success and reward.amount==100,"拥有/预览叮当而未出征不加成")

func _reload_checks() -> void:
	var run: Dictionary=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.mode="idle"
	Skills.apply_mark(run,"slime_1",3)
	_check(sm.save(),"保存含锁印检查点")
	sm.load_data()
	var before: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.begin(sm,CENTER).success and sm.data==before,"重载清理保存失败时全量回滚")
	sm._active_save_path=path
	_check(Run.begin(sm,CENTER).success and not Run.snapshot(sm).combat.actors.slime_1.has("lock_mark"),"重载进入清理瞬态锁印")
	run=sm.data[Run.KEY]
	Skills.apply_mark(run,"slime_1",3)
	for actor in run.combat.actors.values(): actor.mode="idle"
	run.combat.shots=[]
	run.combat.action_left=0.0
	run.combat.axe_pending=false
	before=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success and sm.data==before,"跨区保存失败保留原锁印状态")
	sm._active_save_path=path
	_check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").ENTRANCE).success,"实际跨区事务")
	_check(not Run.snapshot(sm).combat.actors.slime_1.has("lock_mark"),"跨区清理锁印")

func _attack_paths() -> void:
	var base:=Run.snapshot(sm)
	for attacker in ["hero","yaya","tieshan","yufeng","salia","dingdang"]:
		for rank in [1,5]:
			var losses: Array[int]=[]
			for marked in [false,true]:
				var run:=base.duplicate(true)
				run.members[0].id=attacker if attacker!="hero" else "dingdang"
				run.members[0].rank=rank
				run.combat=Combat.create(4,100,CENTER,Run.monsters_for(run))
				Skills.ensure(run.combat)
				for key in run.monsters: run.monsters[key].status="skipped"
				run.monsters.slime_1.status="alive"
				var actor: Dictionary=run.combat.actors.slime_1
				actor.position=Combat.pack(CENTER+ALONG*40)
				actor.skill_reuse=2.0
				actor.mode="idle"
				if marked: Skills.apply_mark(run,"slime_1",rank)
				run.combat.cooldown=0.0
				Skills.select(run,0 if attacker=="hero" else 1)
				_check(Combat.attack(run,CENTER,ALONG),"真实攻击路径发射："+attacker)
				for tick in 5: Combat.advance(run,CENTER,0.05)
				losses.append(14-int(actor.hp))
				_check(losses.back()>0,"真实攻击路径命中："+attacker)
				_check(actor.has("lock_mark")== (attacker=="dingdang"),"命中后锁印消费/钥匙刷新："+attacker)
			_check(losses[1]==(losses[0] if attacker=="dingdang" else roundi(losses[0]*(1.25 if rank==5 else 1.15))),"实际主动路径增伤："+attacker+str(rank))
	var run:=base.duplicate(true)
	Run.ensure_region(run,"fenshui")
	var rows: Array=Catalog.Fenshui.all()
	var first: String=rows[0].id
	var second: String=rows[1].id
	for key in run.monsters: run.monsters[key].status="skipped"
	for id in [first,second]:
		run.monsters[id].status="alive"
		run.combat.actors[id].hp=20
		run.combat.actors[id].mode="idle"
	run.combat.actors[first].position=[1065.0,405.0]
	run.combat.actors[second].position=[1060.0,410.0]
	Skills.apply_mark(run,second,5)
	var shot: Dictionary={"kind":"salia","rank":1,"lives":Combat.life_ids(run)}
	Combat.lightning_chain(run,shot,first,10)
	_check(run.combat.actors[second].hp==14 and run.combat.actors[second].has("lock_mark"),"实际雷链不引爆锁印且伤害不增加")
	_check(not run.combat.actors[first].has("lock_mark"),"雷链不转移锁印")
	# 直接雷击的锁印加成不作为传导倍率输入。
	Skills.apply_mark(run,first,5)
	Skills.direct_damage(run,first,4)
	Combat.lightning_chain(run,shot,first,4)
	_check(run.combat.actors[first].hp==15 and run.combat.actors[second].hp==12,"直接雷击增伤而传导仍按原伤害")

func _projectile_limits() -> void:
	var run:=Run.snapshot(sm)
	run.members[0].id="dingdang"
	run.combat=Combat.create(3,100,CENTER,Run.monsters_for(run))
	Skills.ensure(run.combat)
	for key in run.monsters: run.monsters[key].status="skipped"
	for id in ["slime_1","slime_2"]:
		run.monsters[id].status="alive"
		run.combat.actors[id].position=Combat.pack(CENTER+ALONG*(40 if id=="slime_1" else 65))
		run.combat.actors[id].skill_reuse=2.0
	run.combat.cooldown=0.0
	Skills.select(run,1)
	Skills.attack(run,CENTER,ALONG)
	_check(is_equal_approx(Combat.vec(run.combat.shots[0].target).distance_to(CENTER),240.0),"钥匙直线射程240像素")
	for tick in 5: Combat.advance(run,CENTER,0.05)
	_check(run.combat.actors.slime_1.has("lock_mark") and not run.combat.actors.slime_2.has("lock_mark") and run.combat.shots.is_empty(),"钥匙只命中首个目标不穿透")
	var before_hp: int=run.combat.actors.slime_1.hp
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*40)
	Skills.attack(run,CENTER,ALONG)
	for tick in 5: Combat.advance(run,CENTER,0.05)
	_check(run.combat.actors.slime_1.hp==before_hp-3 and run.combat.actors.slime_1.has("lock_mark"),"实际重复钥匙只刷新、不引爆")
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	for key in run.monsters: run.monsters[key].status="skipped"
	Skills.attack(run,CENTER,ALONG)
	for tick in 14: Combat.advance(run,CENTER,0.05)
	_check(run.combat.shots.is_empty(),"钥匙到射程终点消散")
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.mode="return"
	Skills.apply_mark(run,"slime_1",3)
	Combat.advance(run,CENTER,0.05)
	_check(not run.combat.actors.slime_1.has("lock_mark"),"怪物脱战返航清理锁印")
	run.combat.actors.slime_1.mode="idle"
	Skills.apply_mark(run,"slime_1",3)
	run.combat.hp=0
	Combat.advance(run,CENTER,0.05)
	_check(not run.combat.actors.slime_1.has("lock_mark"),"主角死亡清理锁印")
