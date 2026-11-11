extends Node
const Run = preload("res://scripts/maze/capture_run.gd")
const Flow = preload("res://scripts/maze/capture_flow.gd")
const Boss = preload("res://data/maze/fenshui_boss.gd")
const Path = preload("res://scripts/maze/frog_water_path.gd")
const Area = preload("res://scripts/maze/fenshui_electric_area.gd")
const AreaReference = preload("res://tools/tests/fixtures/fenshui_performance/area_reference.gd")
const Counter = preload("res://tools/tests/fixtures/fenshui_performance/save_counter.gd")
const FIXTURE = "res://tools/tests/fixtures/fenshui_performance/real-state.json"
var sm: Node
var source: Dictionary
var results: Array = []
var trace: Array = []
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func arg(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	results.append({"passed":ok,"label":label,"detail":detail})
	if not ok: failures += 1
	print("FENSHUI_PERF ","通过 " if ok else "失败 ",label," ",JSON.stringify(detail))

func restore() -> void:
	sm.data = source.duplicate(true)
	sm.set("_active_save_path","user://fenshui-performance.json")
	sm.save_calls = 0
	sm.force_failure = false

func dormant() -> void:
	restore()
	var c: Dictionary = sm.data[Run.KEY].combat
	var a: Dictionary = c.actors[Boss.ID]
	a.position = [Boss.HOME.x,Boss.HOME.y]
	a.mode = "idle"
	Run.Combat.Frog.initialize(a)
	a.hit_remaining = 0.0
	a.flash_remaining = 0.0
	c.checkpoint = 0.0

func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("user://fenshui-performance.json"))

func _run() -> void:
	var actual := ProjectSettings.globalize_path("user://").replace(char(92),"/").to_lower()
	var expected := OS.get_environment("MAZE_QTE03_PROFILE").replace(char(92),"/").trim_suffix("/").to_lower()
	check(not expected.is_empty() and actual.begins_with(expected+"/"),"隔离用户存档")
	if failures: finish(); return
	sm = get_node("/root/SaveManager")
	sm.set_script(Counter)
	source = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	restore()
	check(Run.valid(Run.snapshot(sm)),"真实卡顿冻结档符合原探索规则")
	area_checks()
	step_checks()
	path_checks()
	save_checks()
	await scene_check()
	finish()

func area_checks() -> void:
	var center := Vector2(1232,448)
	Area._cache.clear()
	var started := Time.get_ticks_usec()
	var shape := Area.polygon(center,Boss.ID+"_slam")
	var cold_ms := (Time.get_ticks_usec()-started)/1000.0
	check(cold_ms<16.667,"真实首次范围生成小于一帧预算",{"cold_ms":cold_ms})
	check(shape==AreaReference.polygon(center,Area.radius(Boss.ID+"_slam")),"真实卡顿落点的128个顶点与原算法完全一致")
	var equal := true
	for point in [Vector2(980,440),Vector2(1100,440),Vector2(900,450),Vector2(1000,337),Vector2(1358,280),Vector2(956,778)]:
		if Area.polygon(point,"area-reference")!=AreaReference.polygon(point,Area.radius("area-reference")): equal = false
	check(equal,"鳗范围与小岛、保护区、浅滩样例保持原顶点和空区域")
	var sample_mismatches := 0
	var sample_count := 0
	for origin in [center,Vector2(980,440),Vector2(1100,440),Vector2(650,245),Vector2(956,778),Vector2(1358,280)]:
		var query := Area._query(origin,125.0)
		for i in 128:
			for step in range(64):
				var point: Vector2 = origin+Vector2.RIGHT.rotated(TAU*i/128.0)*minf(step*2.0,125.0)
				if Area._water(point,query)!=AreaReference.water(point): sample_mismatches += 1
				sample_count += 1
	check(sample_mismatches==0,"本地筛选后的每个原采样点仍与正式水域判定一致",{"samples":sample_count,"mismatches":sample_mismatches})
	var boundary_points := PackedVector2Array()
	for island in AreaReference.Roads.ISLANDS:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			for delta in [-0.0001,0.0,0.0001]: boundary_points.append(Vector2(island.x,island.y)+direction*(Vector2(island.z,island.w)+Vector2.ONE*delta))
	var circles: Array[Vector3] = [Vector3(1358,280,190)]
	for resource in preload("res://data/maze/region_resources.gd").POINTS.fenshui: circles.append(Vector3(resource[1],resource[2],42))
	for circle in circles:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			for delta in [-0.0001,0.0,0.0001]: boundary_points.append(Vector2(circle.x,circle.y)+direction*(circle.z+delta))
	for gate in AreaReference.Roads.Gates.GATES:
		var normal: Vector2 = (gate.b-gate.a).normalized().orthogonal()
		for delta in [-0.0001,0.0,0.0001]: boundary_points.append(AreaReference.Roads.Gates.center(gate)+normal*(5.0+delta))
	var boundary_mismatches := 0
	for point in boundary_points:
		if Area._water(point,Area._query(point,0.0))!=AreaReference.water(point): boundary_mismatches += 1
	check(boundary_mismatches==0,"岛体、资源保护圈与栅栏的临界内外保持原判定",{"samples":boundary_points.size(),"mismatches":boundary_mismatches})
	var tuning = preload("res://scripts/maze/combat_tuning.gd")
	var saved: Dictionary = tuning.values.duplicate(true)
	tuning.values = saved.duplicate(true)
	tuning.values["frog.skill"] = {"range":70.0}
	var small := Area.polygon(center,Boss.ID+"_slam")
	tuning.values["frog.skill"] = {"range":160.0}
	var large := Area.polygon(center,Boss.ID+"_slam")
	check(small!=large and small==AreaReference.polygon(center,70.0) and large==AreaReference.polygon(center,160.0),"同落点改范围仍刷新缓存并保持原几何")
	tuning.values = saved
	Area.polygon(Vector2(980,440),Boss.ID+"_slam")
	started = Time.get_ticks_usec()
	var again := Area.polygon(center,Boss.ID+"_slam")
	var revisit_ms := (Time.get_ticks_usec()-started)/1000.0
	check(again==shape and revisit_ms<16.667,"切换落点后重新计算仍不产生长帧",{"revisit_ms":revisit_ms})
	var mismatches := 0
	var points := PackedVector2Array()
	for y in range(0,918,19):
		for x in range(0,1716,19): points.append(Vector2(x,y))
	for polygon in AreaReference.Roads.WATER_EDGES:
		for point in polygon:
			for offset in [Vector2.ZERO,Vector2(0.0001,0),Vector2(-0.0001,0),Vector2(0,0.01),Vector2(0,-0.01)]: points.append(point+offset)
	for road in AreaReference.Roads.dry_paths():
		for point in road.points:
			for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				for delta in [-0.0001,0.0,0.0001]: points.append(point+direction*(road.width+delta))
	for point in points:
		if AreaReference.walkable(point)!=AreaReference.Roads.is_walkable(point,0.0) or AreaReference.terrain(point)!=AreaReference.Roads.terrain_multiplier(point): mismatches += 1
	check(mismatches==0,"全图及道路、水边边界的静态查询与旧算法相同",{"samples":points.size(),"mismatches":mismatches})
	trace.append({"area_cold_ms":cold_ms,"area_revisit_ms":revisit_ms})

func step_checks() -> void:
	var flow: Node = Flow.new()
	check(flow.has_method("combat_step"),"真实战斗循环有可复验的步长选择入口")
	if flow.has_method("combat_step"):
		var run: Dictionary = source[Run.KEY].duplicate(true)
		check(is_equal_approx(flow.combat_step(run),0.05),"死蜥蜴残留受击不使分水庭永久高频")
		var a: Dictionary = run.combat.actors.fenshui_silverfish_2
		a.hit_remaining = 0.12
		check(is_equal_approx(flow.combat_step(run),0.01),"当前地图活怪真实受击保留10毫秒细分")
		run.monsters.fenshui_silverfish_2.status = "skipped"
		check(is_equal_approx(flow.combat_step(run),0.05),"已处理捕获的怪物不参与细分")
		run.monsters.fenshui_silverfish_2.status = "alive"
		a.hp = 0.0
		check(is_equal_approx(flow.combat_step(run),0.05),"未弹捕获窗但生命归零的怪物不参与细分")
		run.combat.hit_remaining = 0.12
		check(is_equal_approx(flow.combat_step(run),0.01),"玩家真实受击仍细分")
		run.combat.hit_remaining = 0.0
		run.combat.actors.lizard_1.hp = 25.0
		run.monsters.lizard_1.status = "alive"
		check(is_equal_approx(flow.combat_step(run),0.05),"其他区域的活怪残留受击不参与本图细分")
	flow.free()

func path_checks() -> void:
	var run: Dictionary = source[Run.KEY].duplicate(true)
	var origin := Run.Combat.vec(run.combat.actors[Boss.ID].position)
	var times: Array[float] = []
	var landing := Vector2.ZERO
	for i in 6:
		var started := Time.get_ticks_usec()
		landing = Path.landing(run,origin,Boss.HOME)
		if i>0: times.append((Time.get_ticks_usec()-started)/1000.0)
	times.sort()
	trace.append({"baseline_landing":[landing.x,landing.y],"warm_path_ms":times})
	check(landing.distance_to(Vector2(1232,448))<0.001,"落点与修复前冻结的真实卡点结果一致")
	check(landing.distance_to(origin)>0.01 and Boss.allowed(landing) and Boss.jump_line(origin,landing),"真实回位卡点仍选非零距离合法落点",{"landing":[landing.x,landing.y]})
	check(times[2]<16.667,"相同寻路样例预热后中位耗时小于一帧预算",{"median_ms":times[2]})
	var short_run: Dictionary = run.duplicate(true)
	short_run.combat.actors[Boss.ID].position = [Boss.HOME.x,Boss.HOME.y]
	var close := Vector2(880,490)
	check(Path.landing(short_run,Boss.HOME,close).distance_to(close)<0.001,"无阻挡直达仍选择玩家原落点")
	var equivalent := true
	for start in [origin,Boss.HOME,Vector2(880,490)]:
		for target in [Boss.HOME,Vector2(880,490),Vector2(1000,337),Vector2(1232,448),Vector2(1100,450),Vector2(956,778)]:
			if Boss.jump_line(start,target)!=legacy_jump_line(start,target): equivalent = false
	check(equivalent,"短路检测仍与原逐点射线判定一致，覆盖岛体和边界")

func legacy_jump_line(a: Vector2, b: Vector2) -> bool:
	if not Boss.allowed(a) or not Boss.allowed(b) or a.distance_to(b)>Boss.JUMP_RANGE+0.001: return false
	var steps := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(steps+1):
		if not Boss.air_allowed(a.lerp(b,float(i)/steps)): return false
	return true

func save_checks() -> void:
	dormant()
	var point := Run.Combat.vec(sm.data[Run.KEY].combat.hero)
	var ok := true
	for i in 20:
		if not Run.combat_tick(sm,point,0.05).success: ok = false; break
	check(ok,"待机完整推进1秒真实事务")
	check(sm.save_calls>=1 and sm.save_calls<=3,"纯计时沿用半秒检查点，不逐步存盘",{"calls":sm.save_calls})
	check(Run.valid(disk()[Run.KEY]),"周期检查点实际写盘且可重载")
	var latest := Run.snapshot(sm)
	check(sm.save(),"正常离开前可显式保存最新内存状态")
	sm.load_data()
	check(is_equal_approx(Run.snapshot(sm).combat.elapsed,latest.combat.elapsed),"读档恢复最新显式保存时钟，不回退半秒")
	dormant()
	var before: Dictionary = sm.data.duplicate(true)
	sm.force_failure = true
	var failed := Run.combat_tick(sm,Vector2(880,490),0.05)
	check(not failed.success and failed.reason=="save_failed" and sm.data==before,"进入追击的关键阶段保存失败，完整回滚")
	sm.force_failure = false
	sm.save_calls = 0
	var retry := Run.combat_tick(sm,Vector2(880,490),0.05)
	check(retry.success and sm.save_calls==1,"关键阶段可正常重试且立即写盘")
	check(disk()[Run.KEY].combat.actors[Boss.ID].frog_phase=="active","阶段切换写入真实磁盘，不仅更新显示")
	dormant()
	var a: Dictionary = sm.data[Run.KEY].combat.actors[Boss.ID]
	a.hp -= 1.0
	a.frog_heal_quiet = 2.0
	var old_hp := float(a.hp)
	var healed := Run.combat_tick(sm,point,0.05)
	var now: Dictionary = Run.snapshot(sm)
	check(healed.success and now.combat.actors[Boss.ID].hp>old_hp and sm.save_calls==1,"巨蛙实际回血仍立即保存")
	check(is_equal_approx(float(disk()[Run.KEY].combat.actors[Boss.ID].hp),float(now.combat.actors[Boss.ID].hp)),"回血写盘与内存生命一致")
	dormant()
	sm.data[Run.KEY].combat.hp = sm.data[Run.KEY].combat.max_hp
	a = sm.data[Run.KEY].combat.actors[Boss.ID]
	a.frog_phase = "airborne"
	a.mode = "chase"
	a.frog_target = [880.0,490.0]
	a.frog_air_duration = 0.8
	a.frog_left = 0.05
	a.position = Run.Combat.pack(Boss.HOME.lerp(Vector2(880,490),1.0-0.05/0.8))
	check(Run.valid(Run.snapshot(sm)),"真实落地伤害前的腾空状态有效")
	var old_hero_hp := float(sm.data[Run.KEY].combat.hp)
	var hit := Run.combat_tick(sm,Vector2(880,490),0.05)
	check(hit.success and Run.snapshot(sm).combat.hp<old_hero_hp and sm.save_calls==1,"巨蛙落地伤害仍立即保存")
	check(is_equal_approx(float(disk()[Run.KEY].combat.hp),float(Run.snapshot(sm).combat.hp)),"伤害后磁盘生命与内存一致")
	dormant()
	sm.data[Run.KEY].combat.checkpoint = 0.49
	before = sm.data.duplicate(true)
	sm.force_failure = true
	failed = Run.combat_tick(sm,point,0.05)
	check(not failed.success and failed.reason=="save_failed" and sm.data==before,"周期保存失败也回滚当前事务，不假报成功")
	dormant()
	a = sm.data[Run.KEY].combat.actors[Boss.ID]
	a.frog_phase = "active"
	a.mode = "windup"
	a.windup = 0.01
	a.frog_aim = [1.0,0.0]
	a.cooldown = 1.0
	check(Run.valid(Run.snapshot(sm)),"吐水前摇检查点合法")
	# 当前已保存的水团命中半径为80；站到射程外缘，避免把出生即命中误当水团未保存。
	var water_target := Vector2(1090,450)
	check(Boss.water(water_target) and water_target.distance_to(Boss.HOME)>Run.Combat.Frog.Tuning.effect("water","hit_radius",20.0)+20.0,"水团持久化样例不在出生即命中范围")
	var fired := Run.combat_tick(sm,water_target,0.05)
	now = Run.snapshot(sm)
	check(fired.success and now.combat.actors[Boss.ID].frog_shots.size()==1 and sm.save_calls==1,"水团释放立即保存，数量变化不延后",{"result":fired,"calls":sm.save_calls,"actor":now.combat.actors[Boss.ID]})
	check(disk()[Run.KEY].combat.actors[Boss.ID].frog_shots.size()==1,"真实磁盘保存新生水团")
	sm.save_calls = 0
	var moved := Run.combat_tick(sm,water_target,0.05)
	check(moved.success and sm.save_calls==0,"离体水团仅移动不重复同步存盘")

func scene_check() -> void:
	restore()
	var scene: Node = load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(scene)
	scene.capture_flow.set_process(false)
	scene.set_process(false)
	await get_tree().process_frame
	sm.data = source.duplicate(true)
	scene.player.position = Run.Combat.vec(source[Run.KEY].combat.hero)
	scene.capture_flow.window_focused = true
	scene.capture_flow.combat_time = 0.0
	sm.save_calls = 0
	check(not scene.capture_flow.combat_paused(),"真实场景处于未暂停战斗")
	scene.capture_flow._process(0.05)
	check(sm.save_calls<=1,"真实场景50毫秒不因死蜥蜴重复五次保存",{"calls":sm.save_calls})
	check(scene._save_position(),"真实场景正常退出前的保存入口可刷新最新状态")
	check(is_equal_approx(float(disk()[Run.KEY].combat.elapsed),float(Run.snapshot(sm).combat.elapsed)),"退出保存的实际文件包含最新战斗时钟")
	scene.queue_free()
	await get_tree().process_frame

func finish() -> void:
	var report := {"checks":results.size(),"failures":failures,"results":results,"trace":trace}
	FileAccess.open(arg("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FENSHUI_PERF ",results.size()," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)
