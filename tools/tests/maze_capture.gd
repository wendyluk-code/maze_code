extends "res://tools/tests/ch2_entry_state.gd"
const Run := preload("res://scripts/maze/capture_run.gd")
const Catalog := preload("res://data/maze/capture_catalog.gd")
var maze: Node

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_state_checks()
		if DisplayServer.get_name()!="headless":
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				DisplayServer.window_set_size(resolution)
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _scene_checks()
			await _art_checks()
			await _route_checks()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("MAZE_CAPTURE ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _fresh() -> void:
	_completed()
	sm.cancel_maze_entry()
	_check(Run.begin(sm,Roads.SPAWN).success,"建立新探索")
	for monster in sm.data[Run.KEY].monsters.values(): monster.copy_roll = 0.99

func _state_checks() -> void:
	_fresh()
	_check(Catalog.all().size()==13,"固定13只魔物")
	for row in Catalog.all(): _check(Roads.is_walkable(row.position),"脚底处于道路："+row.id)
	var row := Catalog.find("slime_1")
	var before: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.defeat(sm,row.id,row.position).success and sm.data==before,"击败保存失败回滚吸收与保底")
	sm._active_save_path = "user://chapter-ending-test.json"
	_check(Run.defeat(sm,row.id,row.position).success,"首次击败史莱姆")
	_check(Run.snapshot(sm).absorbed==8 and Run.chance(Run.snapshot(sm),row)==100,"全额吸收与首次100%保底")
	_check(not Run.defeat(sm,row.id,row.position).success and Run.snapshot(sm).absorbed==8,"不能重复吸收")
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.resolve(sm,row.id,true).success and sm.data==before,"捕获保存失败不扣饱腹不领物")
	sm._active_save_path = "user://chapter-ending-test.json"
	var captured := Run.resolve(sm,row.id,true)
	_check(captured.success and captured.caught and captured.items=={"slime_shell":1,"slime_gel":1},"首次双产物各1份")
	_check(Run.snapshot(sm).satiety==69 and sm.inventory_snapshot().get("slime_gel",0)==0,"捕获扣1且只暂存")
	_check(not Run.resolve(sm,row.id,true).success,"重复确认无效")
	var stored := Run.snapshot(sm)
	sm.save()
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),stored),"读档保留吸收、暂存物和随机值",{"before":stored,"after":Run.snapshot(sm)})
	_check(Run.begin(sm,Roads.SPAWN).success and _same_saved(Run.snapshot(sm),stored),"恢复同一趟不重置魔物")
	_check(Run.finish(sm,true,Roads.EXIT).success,"出口结算")
	_check(sm.inventory_snapshot().get("slime_gel",0)==1 and sm.inventory_snapshot().get("slime_shell",0)==1,"双产物转入餐厅库存")
	_check(not Run.finish(sm,true,Roads.EXIT).success,"重复出口不重复入库")
	_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).absorbed==0,"新趟吸收清零")
	Run.defeat(sm,row.id,row.position)
	_check(Run.chance(Run.snapshot(sm),row)==80,"第二趟无首次保底且同系无加成")
	sm.data[Run.KEY].monsters[row.id].capture_roll = 0.99
	var failed := Run.resolve(sm,row.id,true)
	_check(failed.success and not failed.caught and Run.snapshot(sm).satiety==69,"失败同样扣1")
	_check(not Run.resolve(sm,row.id,true).success,"失败不能重试")
	row = Catalog.find("slime_2")
	Run.defeat(sm,row.id,row.position)
	sm.data[Run.KEY].satiety = 0
	before = sm.data.duplicate(true)
	_check(not Run.resolve(sm,row.id,true).success and sm.data==before,"零饱腹拒绝且不改变状态")
	_check(Run.resolve(sm,row.id,false).success and not Run.resolve(sm,row.id,true).success,"放弃不扣食物也不能重试")
	_check(Run.finish(sm,false,Roads.SPAWN).success and sm.inventory_snapshot().get("slime_gel",0)==1,"主动退出不影响既有库存")
	_fresh()
	sm.data[Run.KEY].base_power = 8
	row = Catalog.find("slime_1")
	before = sm.data.duplicate(true)
	_check(Run.defeat(sm,row.id,row.position).get("reason")=="weak" and sm.data==before,"战力相等失败且不扣资源")
	sm.data[Run.KEY].base_power = 7
	_check(Run.defeat(sm,row.id,row.position).get("reason")=="weak","不足失败")
	sm.data[Run.KEY].base_power = 9
	_check(Run.defeat(sm,row.id,row.position).success,"严格大于才击败")
	Run.resolve(sm,row.id,false)
	_check(Run.snapshot(sm).absorbed==8,"放弃捕获不撤回吸收")
	var run := Run.snapshot(sm)
	_check(Run.chance(run,Catalog.find("snail_1"))==80,"草克土+10，铁山同土无加成")
	_check(Run.team_power(100,[{"id":"tieshan","element":"earth","rank":6},{"id":"a","element":"earth"},{"id":"b","element":"earth"},{"id":"c","element":"earth"}])==128,"铁山六阶三同系+28%")
	_fresh()
	for member in sm.data[Run.KEY].members:
		if member.id=="yaya": member.rank=6
	for id in ["snail_1","snail_2","snail_3","snail_4"]:
		row = Catalog.find(id)
		_check(Run.defeat(sm,id,row.position).success,"可击败蜗牛："+id)
		sm.data[Run.KEY].monsters[id].capture_roll = 0.0
		sm.data[Run.KEY].monsters[id].extra_roll = 0.99
		var result := Run.resolve(sm,id,true)
		_check(result.items.brick_snail_meat==(1 if id=="snail_4" else 2),"芽芽六阶仅前三次克制捕获保底："+id)
	before = sm.data.duplicate(true)
	sm._active_save_path = ""
	_check(not Run.finish(sm,true,Roads.EXIT).success and sm.data==before,"出口保存失败不丢暂存不重复领")
	sm._active_save_path = "user://chapter-ending-test.json"
	Run.finish(sm,false,Roads.SPAWN)
	_check(sm.inventory_snapshot().get("brick_snail_meat",0)==0 and Run.snapshot(sm).bag.is_empty(),"放弃清空本趟捕获物")

func _scene_checks() -> void:
	_completed()
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	_check(maze._entry_ready and maze.capture_flow.monsters.size()==13,"实际迷宫建立13只怪物")
	_check(maze.get_node_or_null("YufengSaliaEncounter")==null,"御风萨莉亚出场移除")
	_check(maze.get("first_slime_flow")==null,"旧卡牌战斗入口移除")
	var flow = maze.capture_flow
	# 从出生点沿长廊真实输入移动，靠近第一只自动触发。
	var start := Time.get_ticks_msec()
	while not flow.busy and Time.get_ticks_msec()-start<4500:
		var direction: Vector2 = (Vector2(995,225)-maze.player.position).normalized()
		Input.action_press("ui_left",maxf(0,-direction.x))
		Input.action_press("ui_down",maxf(0,direction.y))
		await get_tree().process_frame
	Input.action_release("ui_left")
	Input.action_release("ui_down")
	await get_tree().create_timer(0.35).timeout
	_check(flow.dialog.visible and flow.dialog.victory,"靠近自动触发胜利翻转弹窗")
	if not flow.dialog.visible:
		maze.queue_free(); await get_tree().process_frame; return
	_check(maze.player.input_locked and not maze.map_ui.mini_button.disabled==false,"胜利期间移动与地图锁定")
	await _capture_image("first_victory")
	_check(flow.dialog.illustration_key=="slime_win" and not flow.dialog._body_label.text.contains("捕获率"),"胜利插画匹配且移除数值文案")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.55).timeout
	_check(flow.reward.visible and flow.reward.item_views.size()==2,"点击捕获翻转显示双产物")
	await _capture_image("first_capture")
	await _click(flow.reward._confirm_button)
	await get_tree().process_frame
	_check(not maze.player.input_locked and not flow.busy,"收下恢复输入")
	_check(Run.snapshot(sm).satiety==69,"实际点击只扣一次")
	_check(not flow.monsters.slime_1.visible,"击败的魔物从地图消失")
	maze.player.position = Vector2(933,269)
	await get_tree().create_timer(0.1).timeout
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_dig_site_claimed("entry_dig_west_fork"),"捕获后原有挖掘交互正常")
	await _click(maze.loot_modal._confirm_button)
	maze.player.position = Vector2(750,352)
	await get_tree().create_timer(0.1).timeout
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_chest_claimed("entry_corridor_north"),"捕获后原有宝箱交互正常")
	await _click(maze.loot_modal._confirm_button)
	await _click(maze.map_ui.mini_button)
	_check(maze.map_ui.expanded and maze.player.input_locked,"捕获后地图可打开并锁定输入")
	await _click(maze.map_ui.close_button)
	_check(not maze.map_ui.expanded and not maze.player.input_locked,"地图关闭恢复探索")
	# 相等失败与零饱腹边界使用固定夹具，再由真实弹窗输入验证。
	maze.player.position = Vector2(1086,715)
	sm.data[Run.KEY].base_power = 40
	sm.data[Run.KEY].absorbed = 8
	await get_tree().create_timer(0.5).timeout
	_check(flow.dialog.visible and not flow.dialog.victory,"实际相等战力失败弹窗")
	await _capture_image("equal_power_failure")
	await _click(flow.dialog._confirm_button)
	await get_tree().process_frame
	_check(not flow.busy and not flow.movement_allowed(Vector2(1086,720),Vector2(1086,740)),"失败后解除输入但魔物仍阻路")
	maze.player.position = Vector2(860,255)
	sm.data[Run.KEY].satiety = 0
	await get_tree().create_timer(0.5).timeout
	_check(flow.dialog.visible and flow.dialog.victory and flow.dialog._confirm_button.modulate.r<1,"零饱腹是按钮呈灰态")
	await _click(flow.dialog._confirm_button)
	_check(maze.last_message=="饱腹度不足，无法捕获" and Run.snapshot(sm).satiety==0,"点击灰态显示准确提示且不扣费")
	await _capture_image("zero_satiety")
	await _click(flow.dialog._cancel_button)
	await get_tree().create_timer(0.3).timeout
	_check(not flow.busy and Run.snapshot(sm).monsters.slime_2.status=="skipped","否关闭且不能重试")
	maze.player.position = Vector2(650,408)
	sm.data[Run.KEY].satiety = 1
	sm.data[Run.KEY].monsters.slime_3.capture_roll = 1.0
	await get_tree().create_timer(0.5).timeout
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	_check(flow.dialog.visible and flow.dialog._title_label.text=="捕获失败" and Run.snapshot(sm).satiety==0,"实际捕获失败弹窗且扣1")
	await _capture_image("capture_failure")
	await _click(flow.dialog._confirm_button)
	_check(not flow.busy and Run.snapshot(sm).monsters.slime_3.status=="failed","捕获失败关闭恢复输入且无法重试")
	maze.player.position = Roads.EXIT
	await get_tree().process_frame
	await _click(maze.exit_prompt.button)
	_check(maze.confirmation.visible,"出口确认出现")
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and not Run.snapshot(sm).active,"出口真实返回餐厅")
	_check(sm.inventory_snapshot().get("slime_shell",0)>=1 and sm.inventory_snapshot().get("slime_gel",0)>=1,"实际出口双产物入库存")
	await _capture_image("restaurant_return")
	var restaurant = get_tree().get_first_node_in_group("restaurant_hud")
	_check(is_instance_valid(restaurant),"真实餐厅界面存在")
	if is_instance_valid(get_tree().current_scene):
		get_tree().current_scene.queue_free()
		await get_tree().process_frame

func _capture_image(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder := _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder.path_join(label+suffix+".png"))

func _same_saved(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not _same_saved(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not _same_saved(a[i],b[i]): return false
		return true
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:
		return absf(float(a)-float(b))<0.000000000001
	return a==b

func _route_checks() -> void:
	_completed()
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	var corridor: PackedVector2Array = Roads.roads()[0].points
	for i in range(2,corridor.size()):
		if not await _walk_to(corridor[i]): return
	var ring: PackedVector2Array = Roads.roads()[1].points
	for i in range(1,9):
		if not await _walk_to(ring[i]): return
	# 先挑战出口强怪，战力不足后真实反向走回环路。
	await _walk_to(Vector2(373,693))
	await get_tree().create_timer(0.35).timeout
	_check(maze.capture_flow.dialog.visible and not maze.capture_flow.dialog.victory,"低战力出口强怪挡路")
	await _capture_image("lizard_blocks_exit")
	await _click(maze.capture_flow.dialog._confirm_button)
	await get_tree().process_frame
	if not await _walk_to(ring[8]): return
	for i in range(9,ring.size()):
		if not await _walk_to(ring[i]): return
	for i in range(1,9):
		if not await _walk_to(ring[i]): return
	for point in Roads.roads()[2].points:
		if not await _walk_to(Roads.EXIT if point.x==0 else point): return
	_check(Run.snapshot(sm).monsters.lizard_1.status=="skipped","环路积累后折返击败强怪")
	_check(Run.snapshot(sm).absorbed==392,"整条主路十一只小怪加出口强怪各吸收一次")
	await _capture_image("route_exit")
	await _click(maze.exit_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region=="restaurant","完整步行路线能从出口结算")
	get_tree().current_scene.queue_free()
	await get_tree().process_frame

func _walk_to(target: Vector2) -> bool:
	var start := Time.get_ticks_msec()
	while maze.player.position.distance_to(target)>3 and Time.get_ticks_msec()-start<12000:
		var flow = maze.capture_flow
		if flow.busy:
			for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
			if flow.dialog.visible and not flow.dialog.flipping:
				if not flow.dialog.victory: break
				if flow.current in ["snail_1","beetle_2","lizard_1"]: await _capture_image("route_"+flow.current)
				await _click(flow.dialog._cancel_button)
			await get_tree().process_frame
			continue
		var direction: Vector2 = (target-maze.player.position).normalized()
		Input.action_press("ui_left",maxf(0,-direction.x))
		Input.action_press("ui_right",maxf(0,direction.x))
		Input.action_press("ui_up",maxf(0,-direction.y))
		Input.action_press("ui_down",maxf(0,direction.y))
		await get_tree().process_frame
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
	if maze.capture_flow.dialog.visible and not maze.capture_flow.dialog.victory: return true
	var reached: bool = maze.player.position.distance_to(target)<=3
	_check(reached,"真实道路行走到 "+str(target),{"position":str(maze.player.position)})
	return reached

func _art_checks() -> void:
	_completed()
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.4).timeout
	var flow = maze.capture_flow
	maze.player.set_physics_process(false)
	for id in ["slime_1","snail_1","beetle_1","lizard_1"]:
		var row := Catalog.find(id)
		maze.player.position = row.position+Vector2(0,-40)
		sm.data[Run.KEY].base_power = row.power
		sm.data[Run.KEY].absorbed = 0
		flow.blocked_until_leave.clear()
		await get_tree().create_timer(0.5).timeout
		_check(flow.dialog.visible and flow.dialog.illustration_key==row.kind+"_lose","实际靠近匹配落败插画："+row.kind)
		_check(flow.monsters[id].label.text==str(row.power) and flow.monsters[id].label.get_theme_color("font_color")==Color("#ef7165"),"相等时纯数字标红："+row.kind)
		_check(flow.power_label.text==str(row.power),"主角头顶显示当前总战力："+row.kind)
		_check(not flow.dialog._body_label.text.contains("。") and flow.dialog.power_row.visible and flow.dialog.guidance.visible,"不足文案分组且无句号："+row.kind)
		var first: Texture2D = flow.dialog.illustration.texture
		await get_tree().create_timer(0.32).timeout
		_check(flow.dialog.illustration.texture!=first,"四帧动画实际播放："+row.kind)
		await _capture_image(row.kind+"_lose")
		await _click(flow.dialog._confirm_button)
		sm.data[Run.KEY].base_power = row.power+1
		flow.blocked_until_leave.clear()
		await get_tree().create_timer(0.5).timeout
		_check(flow.dialog.visible and flow.dialog.illustration_key==row.kind+"_win","实际靠近匹配胜利插画："+row.kind)
		_check(flow.power_label.text==str(row.power*2+1),"吸收后主角头顶实时更新："+row.kind)
		_check(not flow.dialog.power_row.visible and not flow.dialog.guidance.visible,"胜利窗无额外数值组："+row.kind)
		await _capture_image(row.kind+"_win")
		await _click(flow.dialog._cancel_button)
		await get_tree().create_timer(0.3).timeout
		_check(not flow.busy and not maze.player.input_locked,"关闭插画弹窗恢复输入："+row.kind)
	maze.player.position = Vector2(688,396)
	sm.data[Run.KEY].base_power = 24
	sm.data[Run.KEY].absorbed = 0
	await get_tree().create_timer(0.5).timeout
	await _capture_image("power_map")
	sm.data[Run.KEY].base_power = 25
	await get_tree().process_frame
	await get_tree().process_frame
	_check(flow.monsters.snail_2.label.get_theme_color("font_color")==SproutTheme.CREAM,"战力提高后剩余魔物红色实时解除")
	var slime = flow.monsters.slime_2
	_check(slime.body.texture.get_width()*slime.body.scale.x<=36.5,"史莱姆按批准尺寸缩小")
	maze.queue_free()
	await get_tree().process_frame
