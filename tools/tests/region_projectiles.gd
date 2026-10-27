extends "res://tools/tests/maze_capture.gd"
const FS=preload("res://data/maze/fenshui_roads.gd")
const SP=preload("res://data/maze/salt_pool_roads.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for region in ["fenshui","salt_pool"]:
			_fresh()
			var terrain=FS if region=="fenshui" else SP
			_check(Run.change_region(sm,region,terrain.SPAWN).success,"切换区域 "+region)
			var run:=Run.snapshot(sm)
			for monster in run.monsters.values(): monster.status="skipped"
			# 分水庭岸外、盐池水池：不可站立，但应允许空中弹道经过。
			var point:=Vector2(1550,550) if region=="fenshui" else Vector2(848,680)
			_check(not terrain.is_walkable(point),"复现点不属于人物可走面 "+region)
			_check(not Run.Combat.region_line(point-Vector2(12,0),point,region),"原行走遮罩会误拦弹道 "+region)
			for kind in ["hero","yaya"]:
				run.combat.shots=[{"origin":[point.x-12,point.y],"target":[point.x+90,point.y],"position":[point.x-12,point.y],"time":0.0,"flight":0.6,"kind":kind,"lives":Run.Combat.life_ids(run),"damage":3,"basic":true,"element":"grass","attack_serial":1}]
				Run.Combat.advance(run,terrain.SPAWN,0.1)
				_check(run.combat.shots.size()==1,"弹道穿过不可走地面而不消失 "+region+kind)
			_check(not Run.Combat.projectile_clear(Vector2(-1,100),region),"地图外仍销毁弹道 "+region)
			await _scene(region)
		_check(not Run.Combat.projectile_clear(Vector2(970,814),"fenshui"),"实体栅栏继续阻挡")
		_check(not Run.Combat.projectile_clear(Vector2(1233,367),"salt_pool"),"实体石块继续阻挡")
		_check(not Run.Combat.projectile_clear(Vector2(523,365),"salt_pool"),"盐晶实体继续阻挡")
		_check(not Run.Combat.projectile_clear(Vector2(600,1100)),"枯水渠栅栏规则保持")
		var crystal_combat: Dictionary={"region":"salt_pool","throws":1}
		_check(Run.Combat.Crystals.projectile(crystal_combat,Vector2(523,365),{"basic":true,"element":"grass","attack_serial":1}),"盐晶仍先执行真实命中处理")
	var f:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _scene(region: String) -> void:
	sm.data.ch2_guide_01={"revision":2,"step":"done","seen":{},"banked":{}}
	sm.set_yufeng_salia_state("done")
	for monster in sm.data[Run.KEY].monsters.values(): monster.status="skipped"
	sm.save()
	maze=load("res://scenes/maze_fenshui.tscn" if region=="fenshui" else "res://scenes/maze_salt_pool.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.5).timeout
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused=true
	var origin:=Vector2(1435,550) if region=="fenshui" else Vector2(780,680)
	_check(Run.Combat.terrain(region).is_walkable(origin),"实际发射站位合法 "+region)
	maze.player.position=origin
	maze.camera.snap_to_target()
	for slot in [0,1]:
		sm.data[Run.KEY].combat.action_left=0.0
		sm.data[Run.KEY].combat.cooldown=0.0
		sm.data[Run.KEY].combat.shots=[]
		Run.combat_command(sm,"select",slot)
		var attack:=Run.combat_attack(sm,origin,Vector2.RIGHT)
		_check(attack.success and Run.snapshot(sm).combat.shots.size()==1,"实际普攻发射 "+region+str(slot))
		_check(Run.combat_tick(sm,origin,0.25).success,"真实弹道事务推进")
		_check(Run.snapshot(sm).combat.shots.size()==1,"实景弹道越过岸边仍在飞行 "+region+str(slot))
		maze.capture_flow._process(0.0)
		await _capture_image(region+"_shot_"+str(slot))
	maze.queue_free()
	await get_tree().process_frame
