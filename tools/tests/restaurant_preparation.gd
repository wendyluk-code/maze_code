extends "res://tools/tests/restaurant_rest05b.gd"
const Prep := preload("res://scripts/restaurant/preparation.gd")

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_fresh()
	_open({B:1})
	Cycle.settle(sm,"time")
	_check(Cycle.acknowledge_settlement(sm).success,"明日准备事务成功")
	_check(Day.snapshot(sm).preparation_left==3600 and Day.snapshot(sm).day==2,"启动次日一小时")
	var hud = await _open_restaurant()
	await get_tree().create_timer(0.25).timeout
	var lesson = get_tree().get_first_node_in_group("preparation_lesson")
	_check(is_instance_valid(lesson),"首次明日准备显示芽芽教学")
	await _shot("preparation_lesson")
	lesson._finish()
	await get_tree().process_frame
	var remaining := float(Day.snapshot(sm).preparation_left)
	await get_tree().create_timer(1.2).timeout
	_check(float(Day.snapshot(sm).preparation_left)<remaining-0.8,"餐厅在线倒计时")
	await _shot("preparation_clock")
	for target in get_tree().get_nodes_in_group("interactable"):
		var title := str(target.get("display_name"))
		if title in ["前台","仓库","小餐车","冰柜","魔法汤锅","垃圾桶"]:
			scene.get_node("Player").global_position = target.global_position
			_check(scene.get_node("Player").nearest_interactable()!=target,"准备阶段不可选择："+title)
		_check(Prep.allowed(sm,title)==(title in ["迷宫入口","冒险者之家入口"]),"准备阶段交互白名单："+title)
	var gold: int = sm.gold_balance()
	var rep: int = sm.reputation()
	sm.save()
	var saved := float(Day.snapshot(sm).preparation_left)
	await _close_restaurant()
	sm.load_data()
	_check(is_equal_approx(float(Day.snapshot(sm).preparation_left),saved),"读档保留剩余秒数，不按离线时间扣减")
	# 等价迷宫场景：无餐厅HUD，自动加载计时器仍运行，到期不切场景。
	var maze := Node2D.new()
	maze.add_to_group("maze_entry")
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	sm._state[Day.KEY].preparation_left = 0.2
	await get_tree().create_timer(0.4).timeout
	_check(Prep.expired(sm) and get_tree().current_scene==maze,"迷宫持续计时且归零不强制离开")
	maze.queue_free()
	await get_tree().process_frame
	sm._state[Day.KEY]["loot_queue"] = [{"rock_salt":1}]
	hud = await _open_restaurant()
	await get_tree().create_timer(0.2).timeout
	_check(is_instance_valid(hud.return_loot) and hud.return_loot.visible and not hud.day_menu.visible,"返程先展示带回结算")
	await _shot("loot_before_menu")
	await get_tree().create_timer(0.4).timeout
	_check(not hud.return_loot._flipping and hud.return_loot._panel.scale.is_equal_approx(Vector2.ONE),"带回翻转完成后恢复确认")
	await _click(hud.return_loot._confirm_button)
	await get_tree().create_timer(0.2).timeout
	_check(hud.day_menu.visible and hud.day_menu.forced,"带回结算关闭后强制菜单")
	hud.day_menu.close()
	_check(hud.day_menu.visible,"到期菜单不可取消")
	_check(not hud.day_menu.cancel_button.visible,"有可做料理不可跳过")
	hud.day_menu.draft = {B:1}
	hud.day_menu._rebuild()
	await _click(hud.day_menu.confirm_button)
	_check(Day.snapshot(sm).status=="open","强制菜单可正常开始营业")
	await _close_restaurant()
	# 无食材的到期日，跳过不能扣任何余额/库存。
	sm._state[Day.KEY] = {"day":3,"status":"preparing","preparation_left":0.0}
	sm._state.warehouse_stock = {}
	sm._state.restaurant_customers.front = {}
	sm._state.restaurant_customers.seated = []
	hud = await _open_restaurant()
	await get_tree().create_timer(0.2).timeout
	_check(hud.day_menu.forced and hud.day_menu.cancel_button.text=="跳过今日","无料理显示跳过今日")
	await _shot("skip_day_menu")
	var stock: Dictionary = sm._state.warehouse_stock.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _click(hud.day_menu.cancel_button)
	_check(hud.day_menu.visible and Day.snapshot(sm).status=="preparing","跳过保存失败留在菜单")
	sm._active_save_path = path
	await _click(hud.day_menu.cancel_button)
	await get_tree().create_timer(0.65).timeout
	_check(Day.snapshot(sm).settlement.closed_day and hud.day_settlement.introducing,"跳过进入歇业展开动画")
	await _shot("closed_day_title")
	_check(sm.gold_balance()==gold and sm.reputation()==rep and sm._state.warehouse_stock==stock,"歇业不改金币声望库存")
	_check(Day.snapshot(sm).settlement.income==0 and Day.snapshot(sm).settlement.reputation==0,"歇业回执两项均零")
	await get_tree().create_timer(2.3).timeout
	await _shot("closed_day_settlement")
	await _click(hud.day_settlement._confirm_button)
	await get_tree().create_timer(0.15).timeout
	_check(Day.snapshot(sm).day==4 and float(Day.snapshot(sm).preparation_left)>3598,"歇业后正常进入下一天准备")
	_check(get_tree().get_first_node_in_group("preparation_lesson")==null,"准备教学不重复")
	await _close_restaurant()
	sm._state[Day.KEY] = {"day":2,"status":"preparing"}
	Prep.tick(sm,0)
	_check(Day.snapshot(sm).preparation_left==3600,"旧准备档补齐一小时")
	sm._state.chapter_1_done = false
	_check(Prep.allowed(sm,"前台"),"第一章不受准备阶段限制")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
