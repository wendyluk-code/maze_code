extends "res://tools/tests/combat_02_flow.gd"
const F=preload("res://data/maze/fenshui_encounters.gd")
const B=preload("res://data/maze/fenshui_boss.gd")
const FS=preload("res://data/maze/fenshui_roads.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"真实进入分水庭")
	await _close_scene()
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	maze.capture_flow.window_focused=true
	maze.capture_flow.set_process(false)
	maze.capture_flow._process(0)
	var frog=maze.capture_flow.monsters[B.ID]
	_check(frog.visible and frog.action=="special","进图中央巨蛙已显示并跳动")
	var run: Dictionary=Run.snapshot(sm)
	var initial: Dictionary=run.combat.actors.duplicate(true)
	var boundary_ok:=true
	var spacing_ok:=true
	var max_travel:=0.0
	for step in 600:
		Combat.advance(run,FS.SPAWN,0.1)
		for row in F.all():
			var point:=Combat.vec(run.combat.actors[row.id].position)
			boundary_ok=boundary_ok and F.water(point)
			spacing_ok=spacing_ok and Spacing.clear(run,row.id,point)
			max_travel=maxf(max_travel,point.distance_to(row.position))
	_check(boundary_ok,"60秒巡游始终在合法水域")
	_check(spacing_ok,"60秒巡游身体间距无重叠，包含中央巨蛙")
	_check(max_travel>90.0,"自由巡游超出旧85像素出生点圈",{"max_travel":max_travel})
	for row in F.all(): _check(Combat.vec(run.combat.actors[row.id].position).distance_to(Combat.vec(initial[row.id].position))>5.0,"实际游动："+row.id)
	_check(Run.valid(run),"巡游字段与探索状态合法")
	sm.data[Run.KEY]=run
	_check(sm.save(),"保存巡游与原地跳动")
	var saved: Dictionary=run.duplicate(true)
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),JSON.parse_string(JSON.stringify(saved))),"读档恢复巡游位置/方向/跳动计时（实际JSON精度）")
	# 镜头只用于截图；主角仍在岸上，实际运行让尾波持续产生。
	maze.camera.target=null
	maze.camera.position=Vector2(900,450)
	for i in 15:
		_check(Run.combat_tick(sm,FS.SPAWN,0.1).success,"实际巡游事务")
		maze.capture_flow._process(0)
		await get_tree().create_timer(0.06).timeout
	var wakes:=0
	for row in F.all(): wakes+=maze.capture_flow.monsters[row.id].wake_rings.size()
	_check(wakes>0,"真实水怪节点产生游动尾波")
	await _capture_image("swimming_and_idle_frog")
	_check(sm.set_yufeng_salia_state("done").success,"剧情完成前置")
	maze.yf_encounter.phase="done"
	maze.yf_encounter._sync_visuals()
	# 离开旧中央矩形的浅水点也能触发，并逐跳接近。
	var hero:=Vector2(1088,432)
	_check(FS.is_walkable(hero) and FS.terrain_multiplier(hero)<1.0 and not B.AREA.has_point(hero),"旧触发区外的合法水面")
	maze.player.position=hero
	_check(Run.combat_tick(sm,hero,0.1).success,"入水触发事务")
	_check(sm.data[Run.KEY].combat.actors[B.ID].frog_phase=="warning","一入水立即启动跳跃攻击预警")
	var first_target: Array=sm.data[Run.KEY].combat.actors[B.ID].frog_target.duplicate()
	var before_distance:=B.HOME.distance_to(hero)
	var saw_air:=false
	var saw_land:=false
	var valid_land:=true
	var attack_spacing:=true
	var trial: Dictionary=Run.snapshot(sm)
	for step in 220:
		trial.combat.hp=trial.combat.max_hp
		Combat.advance(trial,hero,0.05)
		var a: Dictionary=trial.combat.actors[B.ID]
		saw_air=saw_air or a.frog_phase=="airborne"
		saw_land=saw_land or a.frog_phase=="landing"
		valid_land=valid_land and (B.air_allowed(Combat.vec(a.position)) if a.frog_phase=="airborne" else B.allowed(Combat.vec(a.position)))
		for row in F.all(): attack_spacing=attack_spacing and Spacing.clear(trial,row.id,Combat.vec(trial.combat.actors[row.id].position))
	_check(saw_air and saw_land,"巨蛙完整起跳落地")
	_check(valid_land,"空中通路合法，落地保持水域")
	_check(attack_spacing,"跳跃路径与落点避让鱼鳗")
	_check(Combat.vec(trial.combat.actors[B.ID].position).distance_to(hero)<before_distance-40,"巨蛙实际跳向水中的主角")
	_check(Run.valid(trial),"跳跃后的存档可验证")
	sm.data[Run.KEY]=trial
	# 精确落地状态供视觉验收，不重新结算伤害。
	for step in 80:
		if sm.data[Run.KEY].combat.actors[B.ID].frog_phase=="landing": break
		sm.data[Run.KEY].combat.hp=sm.data[Run.KEY].combat.max_hp
		Run.combat_tick(sm,hero,0.05)
	maze.capture_flow._process(0)
	await _capture_image("frog_landing_ripple")
	_check(frog.frog_state.frog_phase=="landing","落地波纹使用真实落地状态")
	_check(sm.save(),"跳跃中间状态保存")
	var after: Dictionary=Run.snapshot(sm)
	sm.load_data()
	_check(_same_saved(JSON.parse_string(JSON.stringify(after)),Run.snapshot(sm)),"跳跃状态读档一致，不重复伤害（实际JSON精度）")
	await _cross_bank()
	# 使用现有付费捕获事务，固定随机样例，不给正式档补发。
	sm.data[Run.KEY].combat.actors[B.ID].hp=0
	sm.data[Run.KEY].monsters[B.ID].capture_roll=0.0
	sm.data[Run.KEY].monsters[B.ID].copy_roll=0.99
	_check(Run.defeat(sm,B.ID,hero).success,"跳跃巨蛙击败进入捕获")
	_check(Run.start_capture(sm,B.ID).success and Run.finish_capture(sm,B.ID,true).success,"原饱腹付费捕获不变")
	_check(Run.resolve(sm,B.ID,true).get("caught",false),"成功捕获巨蛙")
	_check(sm.data[Run.KEY].bag.get("wind_frog_stomach",0)==1,"只在捕获成功后得到胃囊")
	sm.load_data()
	maze.capture_flow._process(0)
	_check(not frog.visible and sm.data[Run.KEY].monsters[B.ID].status=="captured","捕获后读档不重新出现")
	await _close_scene()

func _cross_bank() -> void:
	var original: Dictionary=Run.snapshot(sm)
	var run: Dictionary=original.duplicate(true)
	var origin:=Vector2(700,400)
	var target:=Vector2(820,400)
	_check(B.allowed(origin) and B.allowed(target) and not B.line(origin,target,B.BODY),"跨岸样例：两端水面，中间岸路")
	_check(B.jump_line(origin,target),"岸路可越过且起落点合法")
	var a: Dictionary=run.combat.actors[B.ID]
	a.position=Combat.pack(origin)
	a.frog_origin=Combat.pack(origin)
	a.frog_target=Combat.pack(origin)
	a.frog_phase="active"
	a.mode="chase"
	run.combat.frog_unlocked=true
	var destination:=preload("res://scripts/maze/frog_water_path.gd").landing(run,origin,target)
	_check(destination.distance_to(target)<1.0,"寻路选择岸路对面水面",{"landing":str(destination)})
	Combat.Frog.advance(run,target,0.05)
	Combat.Frog.advance(run,target,1.0)
	Combat.Frog.advance(run,target,0.175)
	_check(a.frog_phase=="airborne" and not B.water(Combat.vec(a.position)),"巨蛙实际腾空经过岸路")
	_check(Run.valid(run),"岸路上方腾空状态通过存档校验")
	var invalid: Dictionary=a.duplicate(true)
	invalid.position=[-100,-100]
	_check(not Combat.Frog.valid(invalid),"拒绝偏离合法跳跃轨迹的存档")
	sm.data[Run.KEY]=run
	_check(sm.save(),"跨岸腾空途中保存")
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),JSON.parse_string(JSON.stringify(run))),"跨岸腾空读档位置和计时不变")
	maze.player.position=target
	maze.camera.position=Vector2(760,400)
	maze.capture_flow._process(0)
	await _capture_image("frog_crossing_bank")
	var resumed: Dictionary=Run.snapshot(sm)
	Combat.Frog.advance(resumed,target,0.175)
	_check(resumed.combat.actors[B.ID].frog_phase=="landing" and B.allowed(Combat.vec(resumed.combat.actors[B.ID].position)),"跨岸读档后正常落入水面")
	_check(Run.valid(resumed),"跨岸落地状态合法")
	sm.data[Run.KEY]=original
	_check(sm.save(),"恢复隔离场景供捕获回归")

func _first_difference(a: Variant,b: Variant,path: String="") -> Dictionary:
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key): return {"path":path+"/"+str(key),"missing":true}
			var result:=_first_difference(a[key],b[key],path+"/"+str(key))
			if not result.is_empty(): return result
	elif a is Array and b is Array and a.size()==b.size():
		for i in a.size():
			var result:=_first_difference(a[i],b[i],path+"/"+str(i))
			if not result.is_empty(): return result
	elif not _same_saved(a,b): return {"path":path,"before":a,"after":b}
	return {}
