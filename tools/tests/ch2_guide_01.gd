extends "res://tools/tests/maze_capture.gd"
const Guide := preload("res://scripts/ch2_exploration_guide.gd")
var shots: Array = []

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation() and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").to_lower()+"/"), "任何写档前验证隔离用户目录")
	if failures == 0:
		if OS.get_cmdline_user_args().has("--prepare-attempt"):
			_prepare_resume()
		elif OS.get_cmdline_user_args().has("--resume-attempt"):
			await _resume_paid()
		elif OS.get_cmdline_user_args().has("--adverse-guide"):
			await _adverse_guide()
		else:
			_transactions_new()
		if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--adverse-guide") and not OS.get_cmdline_user_args().has("--resume-attempt") and not OS.get_cmdline_user_args().has("--prepare-attempt"):
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _guide_flow()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"screenshots":shots,"user_dir":OS.get_user_data_dir()},"\t"))
	print("CH2_GUIDE_01 ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _transactions_new() -> void:
	_fresh()
	var id := "slime_1"
	_check(Run.defeat(sm,id,Catalog.find(id).position).success,"击败首只史莱姆")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Run.start_capture(sm,id).success and sm.data==before,"开始保存失败不扣费")
	sm._active_save_path = path
	_check(Run.start_capture(sm,id).success,"确认捕获成功持久扣费")
	var food: float = Run.snapshot(sm).satiety
	_check(Run.start_capture(sm,id).success and Run.snapshot(sm).satiety==food,"重复确认不重复扣费")
	sm.load_data()
	_check(Run.start_capture(sm,id).success and Run.snapshot(sm).satiety==food,"读档不二次扣费")
	_check(Run.finish_capture(sm,id,false).success,"零J操作结论保存")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.resolve(sm,id,true).success and sm.data==before,"发奖保存失败回滚")
	sm._active_save_path = path
	sm.load_data()
	var result := Run.resolve(sm,id,true)
	_check(result.success and result.caught and result.items=={"slime_shell":1,"slime_gel":1},"零J首次必成功且双食材各一")
	_check(not Run.resolve(sm,id,true).success,"重复发奖拒绝")
	sm.data[Guide.KEY] = {"step":"explore","seen":{},"banked":{}}
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.finish(sm,true,Vector2(116,724)).success and sm.data==before,"结算保存失败背包和检查点一起回滚")
	sm._active_save_path = path
	_check(Run.finish(sm,true,Vector2(116,724)).success,"石阵结束探索")
	_check(sm.warehouse_snapshot().get("slime_gel",0)==1 and sm.data[Guide.KEY].step=="warehouse","真实入仓与教程检查点同事务")
	_check(not Run.finish(sm,true,Vector2(116,724)).success,"重复结算拒绝")
	_check(Run.begin(sm,Roads.SPAWN).success,"再次探索")
	Run.defeat(sm,id,Catalog.find(id).position)
	_check(not Run.snapshot(sm).monsters[id].guaranteed,"后续探索无首次资格")
	sm.data[Run.KEY].monsters[id].capture_roll=0.0
	Run.start_capture(sm,id)
	Run.finish_capture(sm,id,false)
	_check(not Run.resolve(sm,id,true).caught,"普通捕获未达标即使概率命中也失败")
	Run.defeat(sm,"slime_2",Catalog.find("slime_2").position)
	sm.data[Run.KEY].monsters.slime_2.capture_roll=0.99
	Run.start_capture(sm,"slime_2")
	Run.finish_capture(sm,"slime_2",true)
	_check(not Run.resolve(sm,"slime_2",true).caught,"普通达标仍可能按概率失败")
	Run.finish(sm,false,Roads.SPAWN)
	_check(sm.data[Guide.KEY].step=="entrance" and sm.warehouse_snapshot().get("slime_gel",0)==1,"放弃不算教学成功且不动已入库库存")
	_completed()
	_check(sm.ensure_restaurant_customer().success,"生成章后真实顾客")
	var front: Dictionary = sm.restaurant_customers().front
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not sm.accept_restaurant_customer(front.id).success and sm.data==before,"接单失败不启动教程")
	sm._active_save_path = path
	_check(sm.accept_restaurant_customer(front.id).success and sm.data[Guide.KEY].step=="recipe","真实接单保存教程资格")

func _shot_lesson(g: Node, expected: String) -> void:
	_check(await _wait_until(func(): return g.reading and g.lesson_id==expected,300),"出现教学："+expected+suffix)
	if not g.reading or g.lesson_id!=expected: return
	if expected == "13_bag":
		_check(await _wait_until(func(): return not g.bag_lesson_busy and g.guide.dialog.visible, 180), "石阵镜头完成后再确认背包教学")
	if expected == "07_capture": await get_tree().create_timer(1.3).timeout
	await get_tree().create_timer(0.12).timeout
	if not g.guide.dialog._lines.is_empty() and g.guide.dialog.dialog_text.text != str(g.guide.dialog._lines[0]): await _send_key(KEY_E)
	await get_tree().process_frame
	if g.guide.dialog._lines.is_empty():
		_check(false,"截图前对白仍保持阅读："+expected+suffix)
		return
	_check(g.guide.dialog.dialog_text.text == str(g.guide.dialog._lines[0]),"芽芽全文完整："+expected+suffix)
	var dialog_rect: Rect2 = g.guide.dialog.get_global_rect()
	_check(is_equal_approx(dialog_rect.end.y,get_viewport().get_visible_rect().size.y-30) and is_equal_approx(dialog_rect.size.y,124),"公共对白固定底部："+expected+suffix)
	_check(g.guide.external_cutouts.is_empty() and is_zero_approx(g.guide.dim.color.a),"仅放大展示无矩形亮区："+expected+suffix)
	_check(g.guide.dialog.dialog_text.text == Guide.LINES[expected],"准确文案："+expected+suffix)
	if expected == "11_suppress":
		var phase: float = g.maze.capture_flow.attempt.phase_time
		await get_tree().create_timer(0.5).timeout
		_check(g.maze.capture_flow.attempt.tutorial_paused and g.maze.capture_flow.attempt.phase_time==phase,"J出现时暂停计时")
	var camera_before: Dictionary = g.camera_state.duplicate()
	await _capture_image(expected)
	shots.append({"step":expected,"file":expected+suffix+".png","text":g.guide.dialog.dialog_text.text})
	await _send_key(KEY_E)
	if expected == "13_bag":
		_check(not camera_before.is_empty() and g.camera_state.is_empty() and g.camera.zoom==camera_before.zoom,"节点13恢复石阵聚焦前镜头")
	await get_tree().create_timer(0.12).timeout

func _tap(control: Control) -> void:
	await get_tree().create_timer(0.08).timeout
	var point: Vector2 = control.get_global_transform_with_canvas()* (control.size*0.5)
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var event := InputEventMouseButton.new()
	event.position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=false
	get_viewport().push_input(event)
	await get_tree().process_frame

func _guide_flow() -> void:
	_completed()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.8).timeout
	var hud: Node = get_tree().get_first_node_in_group("restaurant_hud")
	var player: Node = scene.get_node("Player")
	var g: Node = hud.exploration_guide
	# 当前版本先播放首次来客教学；用真实E完整关闭后，才能执行接单步骤。
	for press in range(6):
		if not hud.customer_flow._arrival_tutorial_busy: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	player.global_position = _stand(scene.get_node("InteractPoints/Register"))
	player.last_valid = player.global_position
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	await get_tree().create_timer(0.15).timeout
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _shot_lesson(g,"01_recipe")
	var entry_pos: Vector2 = hud._recipe_entry.position
	await _tap(hud._recipe_entry)
	_check(hud._recipe_book.visible and hud._recipe_entry.position==entry_pos,"食谱原位可点击无来源教学")
	await _tap(hud._recipe_book.close_button)
	# 使用现有真实入口确认；场景切换仍由餐厅业务发起。
	var entrance: Node
	for node in get_tree().get_nodes_in_group("interactable"):
		if str(node.get("display_name"))=="迷宫入口": entrance=node
	if not is_instance_valid(entrance):
		_check(false,"迷宫入口可发现")
		return
	player.global_position = _stand(entrance)
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	await get_tree().create_timer(0.25).timeout
	_check(hud.confirmation.visible,"真实E打开探索准备")
	# 夹具只预选已拥有队伍；正式确认通过鼠标入口事务。
	hud.confirmation.selected = ["yaya","tieshan"]
	if hud.confirmation.has_method("_refresh"): hud.confirmation._refresh()
	await _tap(hud.confirmation.confirm_button)
	_check(await _wait_until(func(): return is_instance_valid(get_tree().get_first_node_in_group("maze_entry")),500),"真实场景切换迷宫")
	maze=get_tree().get_first_node_in_group("maze_entry")
	if not is_instance_valid(maze): return
	g=maze.exploration_guide
	await _shot_lesson(g,"05_power")
	var flow: Node = maze.capture_flow
	_check(maze.player.is_physics_processing() and not maze.player.input_locked,"战力说明恢复移动")
	# 第一段沿真实道路输入靠近，不改战力和魔物。
	var deadline := Time.get_ticks_msec()+7000
	while not flow.busy and Time.get_ticks_msec()<deadline:
		var dir: Vector2=(Catalog.find("slime_1").position-maze.player.position).normalized()
		Input.action_press("ui_left",maxf(0,-dir.x))
		Input.action_press("ui_down",maxf(0,dir.y))
		await get_tree().process_frame
	Input.action_release("ui_left")
	Input.action_release("ui_down")
	await _shot_lesson(g,"06_absorb")
	await _tap(flow.dialog._cancel_button)
	_check(flow.dialog.visible and Run.snapshot(sm).monsters.slime_1.status=="pending","击败教学不能选择否")
	await _tap(flow.dialog._confirm_button)
	await _shot_lesson(g,"07_capture")
	await _tap(flow.attempt.no_button)
	await _send_key(KEY_ESCAPE)
	_check(flow.attempt.visible and flow.attempt.mode=="ready" and Run.snapshot(sm).monsters.slime_1.status=="pending","教学捕获仅是可用")
	_check(flow.attempt.target_chance==80 and not flow.attempt.skills.text.contains("保底"),"显示80%且不泄露首次保底")
	var food: float=Run.snapshot(sm).satiety
	await _tap(flow.attempt.yes_button)
	_check(flow.attempt.mode=="throw" and Run.snapshot(sm).satiety==food-1,"实际确认扣一次饱腹")
	await get_tree().create_timer(2.8).timeout
	await _shot_lesson(g,"11_suppress")
	await get_tree().create_timer(11.0).timeout
	_check(flow.reward.visible and not flow.dialog.visible,"完全零J显示真实成功奖励窗")
	_check(Run.snapshot(sm).bag.get("slime_shell",0)>=1 and Run.snapshot(sm).bag.get("slime_gel",0)>=1,"真实成功窗双食材")
	await _capture_image("12_success")
	await _tap(flow.reward._confirm_button)
	await _shot_lesson(g,"13_bag")
	_check(not maze.player.input_locked,"石阵镜头说明恢复移动")
	# 完整道路验收将在本流程后段行走至石阵。
	await _route_to_exit(g)
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.queue_free()
		await get_tree().process_frame

func _route_to_exit(g: Node) -> void:
	var corridor: PackedVector2Array = Roads.roads()[0].points
	for i in range(3,corridor.size()):
		if not await _guide_walk(corridor[i],g): return
	var ring: PackedVector2Array = Roads.roads()[1].points
	for i in range(1,9):
		if not await _guide_walk(ring[i],g): return
	# 先遇出口强敌，验证真实不足判定，再原路返回。
	for point in [Vector2(330,691),Vector2(300,700)]:
		if not await _guide_walk(point,g,true): return
		break
	if not await _guide_walk(ring[8],g): return
	for i in range(7,-1,-1):
		if not await _guide_walk(ring[i],g): return
	# 反向走到史莱姆与剑甲虫，按真实战力依次吸收。
	for i in range(ring.size()-2,30,-1):
		if not await _guide_walk(ring[i],g): return
	for i in range(32,ring.size()):
		if not await _guide_walk(ring[i],g): return
	# 此时足以击败南侧蜗牛，继续累积至出口蜥蜴以上。
	for i in range(1,25):
		if not await _guide_walk(ring[i],g): return
	for i in range(23,7,-1):
		if not await _guide_walk(ring[i],g): return
	for i in range(1,5):
		if not await _guide_walk(Roads.roads()[2].points[i],g): return
	_check(int(Run.snapshot(sm).base_power)+int(Run.snapshot(sm).absorbed)>450,"原数值原路线吸收后可击败出口强敌")
	await _send_key(KEY_E)
	await get_tree().create_timer(0.2).timeout
	await _tap(maze.confirmation.cancel_button)
	_check(await _wait_until(func(): return sm.maze_exploration_state().region=="restaurant" and is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")),500),"石阵真实结束探索返回餐厅")
	scene=get_tree().current_scene
	var hud: Node = get_tree().get_first_node_in_group("restaurant_hud")
	if not is_instance_valid(hud): return
	g=hud.exploration_guide
	await _shot_lesson(g,"18_return")
	_check(sm.data[Guide.KEY].step=="done" and sm.warehouse_snapshot().get("slime_gel",0)>=1,"节点18完成且材料真实入库")
	_check(not scene.get_node("Player").input_locked,"结束恢复输入")

func _guide_walk(target: Vector2,g: Node, expect_strong:=false) -> bool:
	var deadline := Time.get_ticks_msec()+14000
	while maze.player.position.distance_to(target)>3 and Time.get_ticks_msec()<deadline:
		var flow: Node=maze.capture_flow
		if flow.busy:
			_release_movement()
			if flow.dialog.visible and not flow.dialog.flipping:
				if flow.dialog.victory: await _tap(flow.dialog._cancel_button)
				else:
					await _tap(flow.dialog._confirm_button)
					return expect_strong
			await get_tree().process_frame
			continue
		var dir: Vector2=(target-maze.player.position).normalized()
		Input.action_press("ui_left",maxf(0,-dir.x))
		Input.action_press("ui_right",maxf(0,dir.x))
		Input.action_press("ui_up",maxf(0,-dir.y))
		Input.action_press("ui_down",maxf(0,dir.y))
		await get_tree().process_frame
	_release_movement()
	var reached: bool=maze.player.position.distance_to(target)<=3
	_check(reached,"原道路实际行走 "+str(target),{"position":str(maze.player.position)})
	return reached

func _release_movement() -> void:
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)

func _prepare_resume() -> void:
	_fresh()
	sm.data[Guide.KEY] = {"step":"explore","recipe":"slime_candy","seen":{"05_power":true,"06_absorb":true,"06_food":true,"06_chance":true,"06_cost":true,"07_controls":true,"06_confirm":true},"banked":{}}
	_check(Run.defeat(sm,"slime_1",Catalog.find("slime_1").position).success,"跨进程准备击败")
	_check(Run.start_capture(sm,"slime_1").success,"跨进程准备付费")
	sm.data[Run.KEY].monsters.slime_1.attempt.started_at=Time.get_unix_time_from_system()-30
	_check(sm.save(),"跨进程准备写盘")

func _resume_paid() -> void:
	sm._active_save_path="user://chapter-ending-test.json"
	sm.load_data()
	var before: float=Run.snapshot(sm).satiety
	_check(Run.snapshot(sm).monsters.slime_1.has("attempt"),"新进程恢复付费标记")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(1.6).timeout
	var restored_guide: Node = maze.exploration_guide
	_check(restored_guide.reading and restored_guide.lesson_id=="11_suppress" and maze.capture_flow.attempt.tutorial_paused,"旧付费检查点恢复到J暂停说明")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await get_tree().create_timer(0.8).timeout
	_check(Run.snapshot(sm).monsters.slime_1.status=="captured","离线零J首次恢复成功")
	_check(maze.capture_flow.reward.visible and not maze.capture_flow.dialog.visible,"恢复显示成功窗")
	_check(Run.snapshot(sm).satiety==before,"恢复不二次扣费")
	_check(Run.snapshot(sm).bag=={"slime_shell":1,"slime_gel":1},"恢复只发双食材各一")
	_check(not Run.resolve(sm,"slime_1",true).success,"恢复重复奖励拒绝")
	_check(sm.data[Guide.KEY].seen.get("07_controls",false),"教程阅读检查点跨进程保留")
	maze.queue_free()
	await get_tree().process_frame

func _adverse_guide() -> void:
	get_window().size=Vector2i(1280,720)
	suffix="_adverse"
	_completed()
	sm.ensure_restaurant_customer()
	sm.accept_restaurant_customer(sm.restaurant_customers().front.id)
	scene=RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().create_timer(0.6).timeout
	var hud: Node=get_tree().get_first_node_in_group("restaurant_hud")
	var g: Node=hud.exploration_guide
	_check(g.reading and g.lesson_id=="01_recipe","读档真实订单恢复食谱说明")
	await _send_key(KEY_E)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	await _send_key(KEY_E)
	_check(g.pending_save.is_valid() and not g._seen("01_recipe") and hud._player.input_locked,"教学保存失败不误推进且保留输入保护")
	sm._active_save_path=path
	await _send_key(KEY_E)
	await get_tree().create_timer(0.15).timeout
	_check(g._seen("01_recipe") and not hud._player.input_locked,"保存重试成功才放行真实入口")
	_check(sm.data[Guide.KEY].step=="entrance","节点1成功后直接待出发")
	scene.queue_free()
	await get_tree().process_frame
	for legacy in ["source","source_close","entrance","warehouse","done"]:
		sm.data[Guide.KEY]={"step":legacy,"seen":{},"banked":{}}
		scene=RESTAURANT.instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene=scene
		await get_tree().create_timer(0.2).timeout
		hud=get_tree().get_first_node_in_group("restaurant_hud")
		g=hud.exploration_guide
		if legacy=="warehouse": await _shot_lesson(g,"18_return")
		_check(sm.data[Guide.KEY].step in ["entrance","done"],"旧检查点不滞留删除节点："+legacy)
		scene.queue_free()
		await get_tree().process_frame
	_fresh()
	Run.defeat(sm,"slime_1",Catalog.find("slime_1").position)
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.5).timeout
	var flow: Node=maze.capture_flow
	var food: float=Run.snapshot(sm).satiety
	await _tap(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	await _tap(flow.attempt.no_button)
	_check(Run.snapshot(sm).satiety==food and Run.snapshot(sm).bag.is_empty() and Run.snapshot(sm).monsters.slime_1.status=="skipped","真实捕获详情取消不扣费不发奖")
	_check(not flow.busy and not maze.player.input_locked and maze.player.is_physics_processing(),"取消恢复输入与物理处理")
	maze.queue_free()
	await get_tree().process_frame
	_fresh()
	Run.defeat(sm,"slime_1",Catalog.find("slime_1").position)
	sm.data[Run.KEY].monsters.slime_1.guaranteed=false
	sm.data[Run.KEY].monsters.slime_1.capture_roll=0.0
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.5).timeout
	flow=maze.capture_flow
	food=Run.snapshot(sm).satiety
	await _tap(flow.dialog._confirm_button)
	await get_tree().create_timer(0.3).timeout
	await _tap(flow.attempt.yes_button)
	await get_tree().create_timer(13.7).timeout
	_check(Run.snapshot(sm).monsters.slime_1.status=="failed" and flow.dialog.visible and not flow.reward.visible,"普通零J真实失败窗")
	_check(Run.snapshot(sm).satiety==food-1 and Run.snapshot(sm).bag.is_empty(),"普通失败实际扣费且无奖励")

	maze.queue_free()
	await get_tree().process_frame
	_fresh()
	Run.defeat(sm,"slime_1",Catalog.find("slime_1").position)
	Run.start_capture(sm,"slime_1")
	Run.finish_capture(sm,"slime_1",false)
	Run.resolve(sm,"slime_1",true)
	sm.data[Guide.KEY]={"step":"explore","seen":{"05_power":true,"08_bag":true,"08_items":true,"09_map":true},"banked":{}}
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.5).timeout
	maze.player.position=Roads.ENTRANCE
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and maze._destination=="餐厅","入口真实打开放弃确认")

	await _tap(maze.confirmation.confirm_button)
	_check(await _wait_until(func(): return sm.maze_exploration_state().region=="restaurant" and is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")),400),"放弃实际返回餐厅")
	_check(Run.snapshot(sm).bag.is_empty() and sm.warehouse_snapshot().get("slime_gel",0)==0 and sm.data[Guide.KEY].step=="entrance","放弃丢失暂存且不算教学成功")
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
