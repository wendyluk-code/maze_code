extends "res://tools/tests/combat_skill_01.gd"
var samples: Array=[]

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_b01_defense_isolated","项目名和用户目录隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["yaya","tieshan","yufeng","salia"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["yaya","tieshan","yufeng","salia"]).success,"真实四人编队出发")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	_matrix()
	_edges()
	await _scene_damage()
	maze.queue_free()
	await get_tree().process_frame
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _sample(ids: Array,level: int) -> Dictionary:
	var run:=Run.snapshot(sm)
	run.members=[]
	for id in ids: run.members.append({"id":id,"level":level,"rank":1,"element":Skills.Growth.element(id)})
	run.combat=Combat.create(10,500,CENTER,Run.monsters_for(run))
	Skills.ensure(run.combat)
	for id in run.monsters: run.monsters[id].status="skipped"
	return run

func _matrix() -> void:
	var teams: Array=[["yaya","tieshan","yufeng","salia"],["yaya","dingdang","ahong","lanjiao"],["tieshan","dingdang","ahong","yaya"]]
	for ids in teams:
		for level in [1,2,3,5,10,15,30]:
			var run:=_sample(ids,level)
			var armor:=Skills.defense(run)
			var expected3:=maxi(1,ceili(3.0*maxf(0.25,20.0/(20.0+armor))))
			var expected6:=maxi(1,ceili(6.0*maxf(0.25,20.0/(20.0+armor))))
			var expected8:=maxi(1,ceili(8.0*maxf(0.25,20.0/(20.0+armor))))
			run.monsters.slime_1.status="alive"
			var a: Dictionary=run.combat.actors.slime_1
			a.position=Combat.pack(CENTER+ALONG*20)
			a.mode="windup"
			a.windup=0.001
			a.skill_reuse=3.0
			Combat.advance(run,CENTER,0.01)
			_check(run.combat.hp==500-expected3,"普通近战实际扣血 "+str(ids)+" L"+str(level),{"hp":run.combat.hp,"expected":500-expected3})
			run=_sample(ids,level)
			run.combat.enemy_shots=[{"position":Combat.pack(CENTER+ALONG*22),"direction":Combat.pack(-ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
			Skills.advance(run,CENTER,0.05)
			_check(run.combat.hp==500-expected3 and run.combat.enemy_shots.is_empty(),"弹丸实际扣血 L"+str(level))
			run=_sample(ids,level)
			Combat.Frog.hurt(run,CENTER,CENTER+ALONG*20)
			_check(run.combat.hp==500-expected6,"巨蛙实际扣血 L"+str(level))
			run=_sample(ids,level)
			Combat.Rock.hurt(run,CENTER,CENTER+ALONG*20)
			_check(run.combat.hp==500-expected8,"岩鬃兽实际扣血 L"+str(level))
			samples.append({"team":ids,"level":level,"defense":armor,"slime":expected3,"frog":expected6,"rock":expected8})

func _edges() -> void:
	for armor in [0,1,20,59,60,75,150,100000]:
		var run:=_sample([],1)
		run.bento={"defense":armor}
		for power in [0,1,3,6,8,100]:
			var want:=0 if power==0 else maxi(1,ceili(float(power)*maxf(0.25,20.0/(20.0+armor))))
			_check(Skills.incoming_damage(run,power)==want,"防御端点 D="+str(armor)+" A="+str(power))
	var run:=_sample(["yaya"],1)
	run.combat.guard_left=1.0
	run.combat.blocks=9
	Skills.ensure(run.combat)
	_check(not run.combat.has("guard_left") and not run.combat.has("blocks"),"不恢复已移除的旧格挡状态")
	_check(Skills.incoming_damage(run,-1)==0,"非正攻击不凭空造成伤害")

func _scene_damage() -> void:
	_fixture()
	var run: Dictionary=sm.data[Run.KEY]
	run.combat.hp=64
	run.combat.max_hp=64
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*20)
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.001
	run.combat.actors.slime_1.skill_reuse=3.0
	run.monsters.slime_1.status="alive"
	await _capture_image("b01_before")
	_check(Run.valid(run),"受击夹具符合生产状态校验")
	var before: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.01).success and sm.data==before,"受击保存失败回滚状态")
	sm._active_save_path="user://chapter-ending-test.json"
	var applied:=Run.combat_tick(sm,CENTER,0.01)
	_check(applied.success,"真实受击事务成功",applied)
	_check(Run.snapshot(sm).combat.hp==61,"实际场景四人1级队受击64到61")
	maze.capture_flow._process(0)
	await _capture_image("b01_after")
	_check(sm.save(),"受击状态可保存")
	sm.load_data()
	_check(Run.snapshot(sm).combat.hp==61,"读档保留真实扣血")
