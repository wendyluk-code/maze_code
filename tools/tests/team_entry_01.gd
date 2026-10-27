extends "res://tools/tests/maze_capture.gd"
const Team := preload("res://scripts/ui/components/team_entry_modal.gd")
var hud: Node
var modal: Control

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "正式存档隔离")
	if failures == 0 and OS.get_cmdline_user_args().has("--resume"):
		await _restart_checks()
	elif failures == 0:
		_transaction_checks()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _entry_scene()
		await _failure_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path}, "\t"))
	print("TEAM_ENTRY_01 ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _transaction_checks() -> void:
	_completed()
	sm.cancel_maze_entry()
	_check(sm.remembered_maze_party().is_empty(), "新旧档缺字段默认空队")
	sm.save()
	sm.load_data()
	_check(sm.remembered_maze_party().is_empty(), "旧档无记忆字段加载仍为空队")
	for party in [[], ["yaya","yaya"], ["unknown"]]:
		_check(not sm.request_maze_entry(party).success, "拒绝空队重复与未拥有："+str(party))
	var owned := ["a","b","c","d","e"]
	var draft: Array = []
	for id in owned.slice(0,4): _check(Team.update_selection(draft,id,true,owned), "隔离五角色夹具加入："+id)
	_check(not Team.update_selection(draft,"e",true,owned) and draft.size()==4, "隔离夹具拒绝第5人")
	_check(Team.update_selection(draft,"a",true,owned) and draft.size()==4, "隔离夹具重复选择无重复")
	_check(Team.update_selection(draft,"b",false,owned) and Team.update_selection(draft,"e",true,owned) and draft==["a","c","d","e"], "隔离夹具取消后按选择顺序补位")
	var before: Dictionary = sm.data.duplicate(true)
	_check(sm.request_maze_entry(["tieshan"]).success, "预留单人队伍")
	_check(not sm.request_maze_entry(["yaya"]).success and sm.data==before, "重复确认不写草稿不扣费")
	sm.cancel_maze_entry()
	_check(sm.data==before and sm._maze_entry_party.is_empty(), "转场取消清理待进入队伍")
	sm.request_maze_entry(["tieshan"])
	sm._active_save_path = ""
	_check(not Run.begin(sm,Roads.SPAWN).success and sm.data==before and not sm._maze_entry_pending and sm._maze_entry_party.is_empty(), "保存失败回滚探索体力记忆并清理队伍")
	sm._active_save_path = "user://chapter-ending-test.json"
	sm.request_maze_entry(["tieshan","yaya"])
	_check(Run.begin(sm,Roads.SPAWN).success and sm.stamina()==80 and sm.remembered_maze_party()==["tieshan","yaya"], "入场原子保存20体力与有序队伍记忆")
	_check(sm.departure_state().party==["yaya","tieshan"], "拥有名单不随探索队伍改变")
	sm.load_data()
	_check(sm.remembered_maze_party()==["tieshan","yaya"] and Run.snapshot(sm).members[0].id=="tieshan", "存档重载记忆与探索顺序")
	var run := Run.snapshot(sm)
	_check(Run.begin(sm,Roads.SPAWN).success and _same_saved(Run.snapshot(sm),run) and sm.stamina()==80, "活跃探索重进保持队伍不重复扣费")
	_check(not sm.request_maze_entry(["yaya"]).success, "活跃探索不能改队")
	sm.data[sm.TEAM_MEMORY_KEY] = ["bad"]
	_check(sm.remembered_maze_party().is_empty(), "非法旧记忆安全空队")
	sm.cancel_maze_entry()

func _restaurant() -> void:
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	modal = hud.confirmation
	var target: Node2D = scene.get_node("DepartureEntrance")
	var player := scene.get_node("Player")
	player.global_position = _stand(target)
	await get_tree().create_timer(0.1).timeout
	await _send_key(KEY_E)
	_check(modal.visible and modal.team_panel.visible and player.input_locked, "真实餐厅一次E直接打开组队并锁输入")

func _entry_scene() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data[Run.Progression.KEY] = {"yaya":{"level":4,"rank":3,"exp":0,"breakthroughs":0},"tieshan":{"level":3,"rank":1,"exp":0,"breakthroughs":0}}
	sm.data[Run.Progression.FOOD_KEY] = {"values":{"yaya":0.5,"tieshan":0.25},"at":Time.get_unix_time_from_system(),"paused":true}
	sm.save()
	await _restaurant()
	await _confirmation_modes()
	_check(modal.selected.is_empty() and modal.confirm_button.disabled, "首次四空槽且不能确认")
	_check(modal.slots.size()==4 and modal.slots.all(func(slot): return slot.text=="+"), "四槽一行初始加号")
	await _capture_image("empty")
	var player := scene.get_node("Player")
	var position_before: Vector2 = player.position
	Input.action_press("ui_down")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_down")
	_check(player.position==position_before, "组队期间餐厅背景不移动")
	await _click(modal.slots[0])
	_check(modal.selector.visible and modal.checks.size()==2, "加号展开已拥有角色列表")
	await _click(modal.cancel_button)
	_check(modal.selector.visible and modal.visible, "选择列表遮罩阻挡下层取消")
	for i in 9: await _send_key(KEY_TAB)
	_check(modal.selection_panel.is_ancestor_of(get_viewport().gui_get_focus_owner()), "列表Tab焦点不能越过当前层")
	await _capture_image("selector")
	await _click(modal.portrait_buttons.yaya)
	_check(modal.details.visible and modal.details.character_id=="yaya", "头像打开既有详情")
	await _click(modal.checks.tieshan)
	_check(modal.selected.is_empty() and modal.details.visible, "详情遮罩阻挡下层勾选")
	await _capture_image("detail")
	await _send_key(KEY_ESCAPE)
	_check(not modal.details.visible and modal.selector.visible, "Esc仅退详情")
	await _click(modal.name_buttons.tieshan)
	_check(modal.details.visible and modal.details.character_id=="tieshan", "姓名打开既有详情")
	await _click(modal.details._close_button)
	await _click(modal.checks.tieshan)
	await _click(modal.checks.yaya)
	_check(modal.selected==["tieshan","yaya"], "独立勾选多选并保留顺序")
	await _click(modal.checks.tieshan)
	_check(modal.selected==["yaya"], "列表取消已选角色")
	await _click(modal.checks.tieshan)
	await _send_key(KEY_ESCAPE)
	_check(not modal.selector.visible and modal.visible, "Esc仅退列表")
	_check(modal.power_value.text == "14" and modal.food_value.text == "0", "真实等级基础战力与当前饱腹向下取整")
	_check(modal.skills_text.text.contains("熟悉食材") and modal.skills_text.text.contains(Run.Progression.CHARACTERS.yaya.skills[2][1]) and not modal.skills_text.text.contains("满载而归"), "技能全文按阶位解锁")
	await _capture_image("selected")
	for slot in modal.slots.slice(0,2):
		_check(slot.get_child(1).size==Vector2(24,24), "已选槽派系图标24像素")
	sm.data[Run.Progression.KEY].yaya.rank = 6
	sm.data[Run.Progression.KEY].tieshan.rank = 6
	await get_tree().create_timer(0.25).timeout
	_check(modal.skills_text.text.contains("丰收拿手菜") and modal.skills_text.text.contains("众志成山"), "全部已解锁技能完整展示")
	modal.skills_scroll.get_v_scroll_bar().value = modal.skills_scroll.get_v_scroll_bar().max_value
	await get_tree().process_frame
	_check(modal.skills_scroll.get_v_scroll_bar().value>0, "长技能正文可以滚动到底")
	await _capture_image("skills_scrolled")
	_check(get_viewport().get_visible_rect().encloses(modal.team_panel.get_global_rect()), "组队面板位于视口内")
	_check(modal.slots[0].position.y==modal.slots[3].position.y and modal.skills_text.size.y>=145, "四槽横排与可滚动技能区")
	await _send_key(KEY_ESCAPE)
	_check(not modal.visible and not player.input_locked and player.is_physics_processing() and sm.remembered_maze_party().is_empty(), "取消草稿不记忆且恢复输入")
	position_before = player.position
	Input.action_press("ui_right")
	await get_tree().create_timer(0.12).timeout
	Input.action_release("ui_right")
	_check(player.position.distance_to(position_before)>0.1, "关闭后实际方向输入恢复移动")
	player.position = position_before
	await _send_key(KEY_E)
	_check(modal.selected.is_empty(), "取消后再次打开仍空队")
	await _click(modal.slots[0])
	await _click(modal.checks.tieshan)
	await _click(modal.selection_done)
	sm.data.stamina = {"value":19,"at":int(Time.get_unix_time_from_system())}
	await get_tree().create_timer(0.25).timeout
	_check(modal.confirm_button.disabled and modal._insufficient.text=="体力不足", "体力不足禁止确认")
	sm.data.stamina.value = 100
	sm.data[Run.Progression.FOOD_KEY].values.tieshan = 0.0
	await get_tree().create_timer(0.25).timeout
	_check(modal.warning.visible and modal.warning.text=="当前团队饱腹度为0，将无法捕获任何魔物食材" and not modal.confirm_button.disabled, "零饱腹红字精确且仍可进入")
	await _capture_image("zero_food")
	await _click(modal.confirm_button)
	hud._confirm_destination()
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(maze.is_in_group("maze_entry") and maze._entry_ready, "真实餐厅转入迷宫")
	_check(Run.snapshot(sm).members.size()==1 and Run.snapshot(sm).members[0].id=="tieshan" and maze.capture_flow.member_buttons.keys()==["tieshan"], "单人真实探索与缩略头像一致")
	_check(sm.stamina()==80 and sm.remembered_maze_party()==["tieshan"] and sm.departure_state().party==["yaya","tieshan"], "成功进入只扣一次且记忆不改拥有名单")
	await _capture_image("maze_one")
	var monster := Catalog.find("slime_1")
	_check(Run.defeat(sm,monster.id,monster.position).success, "所选铁山真实战力可击败首怪")
	var before: Dictionary = sm.data.duplicate(true)
	_check(Run.resolve(sm,monster.id,true).get("reason")=="hungry" and sm.data==before, "所选零饱腹队伍真实捕获拒绝")
	Run.resolve(sm,monster.id,false)
	_check(Run.finish(sm,false,Roads.SPAWN).success, "本趟结束返回状态")
	maze.queue_free()
	await get_tree().process_frame
	sm.load_data()
	await _restaurant()
	_check(modal.selected==["tieshan"], "返回餐厅重载后默认上次成功队伍")
	await _click(modal.slots[1])
	await _click(modal.checks.yaya)
	await _click(modal.selection_done)
	await _click(modal.confirm_button)
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(Run.snapshot(sm).members.map(func(member): return member.id)==["tieshan","yaya"] and maze.capture_flow.member_buttons.keys()==["tieshan","yaya"], "双人真实探索与头像顺序一致")
	await _capture_image("maze_two")
	maze.queue_free()
	await get_tree().process_frame

func _confirmation_modes() -> void:
	var events := {"confirmed":0, "cancelled":0}
	var on_confirm := func(): events.confirmed += 1
	var on_cancel := func(): events.cancelled += 1
	modal.confirmed.connect(on_confirm)
	modal.cancelled.connect(on_cancel)
	# 同一已锁定入口直接切普通模式，避免重复获取人物输入锁。
	hud._destination = "水轮工坊"
	modal.open_destination("水轮工坊")
	await get_tree().create_timer(0.25).timeout
	_check(not modal._team_mode and not modal.team_panel.visible and modal._original_center.visible and modal.confirm_button.is_visible_in_tree() and modal.cancel_button.is_visible_in_tree(), "探索切普通恢复原面板与操作按钮")
	_check(modal.question.text=="是否前往水轮工坊？" and not modal._cost_row.visible and not modal._insufficient.visible and not modal.confirm_button.disabled, "普通目的地恢复文案与可用性且不受空队刷新影响")
	await _capture_image("ordinary_confirmation")
	await _click(modal.cancel_button)
	_check(events.cancelled==1 and not modal.visible and not hud._player.input_locked, "普通目的地鼠标取消并恢复餐厅输入")
	hud._open_confirmation("水轮工坊")
	await _click(modal.confirm_button)
	_check(events.confirmed==1 and not modal.visible and not hud._player.input_locked, "普通目的地鼠标确认并恢复餐厅输入")
	hud._open_confirmation("水轮工坊")
	await _send_key(KEY_ENTER)
	_check(events.cancelled==2 and not modal.visible, "普通确认默认Enter沿用父类取消")
	hud._open_confirmation("水轮工坊")
	await _send_key(KEY_RIGHT)
	await _send_key(KEY_ENTER)
	_check(events.confirmed==2 and not modal.visible, "普通确认左右切换与Enter沿用父类")
	hud._open_confirmation("水轮工坊")
	await _send_key(KEY_E)
	_check(modal.visible and events.confirmed==2, "普通确认首次E松开前不确认")
	await _send_key(KEY_E)
	_check(not modal.visible and events.confirmed==3, "普通确认E松开后新按才确认")
	hud._open_confirmation("水轮工坊")
	await _send_key(KEY_ESCAPE)
	_check(events.cancelled==3 and not modal.visible, "普通确认Esc沿用父类取消")
	hud._open_confirmation("迷宫")
	await get_tree().process_frame
	_check(modal._team_mode and modal.team_panel.visible and not modal._original_center.visible and modal.confirm_button.is_visible_in_tree() and modal.confirm_button.disabled and modal._cost_row.is_visible_in_tree(), "探索普通探索切换重新挂载且恢复空队门禁")
	modal.open_exploration()
	await get_tree().process_frame
	_check(modal._cost_row.get_index()<modal._insufficient.get_index() and modal._insufficient.get_index()<modal.confirm_button.get_parent().get_index(), "重复打开探索保持消耗提示与按钮顺序")
	modal.confirmed.disconnect(on_confirm)
	modal.cancelled.disconnect(on_cancel)

func _failure_scene() -> void:
	_completed()
	sm.cancel_maze_entry()
	await _restaurant()
	await _click(modal.cancel_button)
	var before: Dictionary = sm.data.duplicate(true)
	sm.request_maze_entry(["yaya"])
	await hud._change_to_maze(null)
	_check(sm.data==before and not sm._maze_entry_pending and sm._maze_entry_party.is_empty() and get_tree().current_scene==scene, "真实转场接口拒绝空资源并清理队伍不扣费")
	await _send_key(KEY_E)
	await _click(modal.slots[0])
	await _click(modal.checks.yaya)
	await _click(modal.selection_done)
	sm._active_save_path = ""
	await _click(modal.confirm_button)
	await get_tree().create_timer(2.1).timeout
	_check(get_tree().current_scene.is_in_group("maze_entry")==false and not sm._maze_entry_pending and sm._maze_entry_party.is_empty() and sm.data==before, "实际到达保存失败回餐厅且完整回滚")
	await _capture_image("save_failure_return")
	sm._active_save_path = "user://chapter-ending-test.json"
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
	# 留下可供独立进程复验的双人探索存档。
	sm.request_maze_entry(["tieshan","yaya"])
	_check(Run.begin(sm,Roads.SPAWN).success, "写入独立进程重载检查点")

func _restart_checks() -> void:
	sm._active_save_path = "user://chapter-ending-test.json"
	sm.load_data()
	_check(sm.remembered_maze_party()==["tieshan","yaya"], "独立进程读取有序队伍记忆")
	var before := Run.snapshot(sm)
	var energy: int = sm.stamina()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.5).timeout
	_check(maze._entry_ready and _same_saved(Run.snapshot(sm),before) and sm.stamina()==energy, "独立进程实际恢复原趟队伍不扣费")
	_check(maze.capture_flow.member_buttons.keys()==["tieshan","yaya"], "独立进程缩略头像顺序保持")
	await _capture_image("restart")
