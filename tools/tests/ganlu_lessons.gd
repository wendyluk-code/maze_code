extends "res://tools/tests/restaurant_rest05b.gd"
const Water := preload("res://scripts/restaurant/ganlu_service.gd")

func seated() -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var result := Cycle.arrive(sm)
	_check(result.get("created",false),"普通顾客到达")
	var id: String = result.order.id
	sm.advance_restaurant_customer(id,"arriving","front")
	sm.accept_restaurant_customer(id)
	sm.advance_restaurant_customer(id,"seating","waiting")
	return sm.restaurant_customer_order(id)

func finish_lesson(hud: Node, kind: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var lesson = hud.customer_flow.arrival_lesson
	_check(is_instance_valid(lesson) and lesson.kind==kind,"实际触发教学："+kind)
	if not is_instance_valid(lesson): return
	if kind in ["warm","iced"]:
		var bubble = lesson.target.get_node("OrderBubble")
		_check(bubble.is_visible_in_tree() and bubble.drink,"教学挖空内真实甘露水气泡可见："+kind)
	var clock: float = Day.snapshot(sm).remaining
	var cups := Water.snapshot(sm)
	await get_tree().create_timer(0.3).timeout
	_check(Day.snapshot(sm).remaining==clock and Water.snapshot(sm)==cups,"阅读冻结营业与冰镇计时："+kind)
	if lesson.dialog._shown < str(lesson.dialog._lines[0]).length(): lesson.dialog._advance()
	await _shot("lesson_"+kind)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	lesson._read_done()
	_check(not sm.data.get("ganlu_lessons_v1",{}).get(kind,false) and lesson.active,"教学保存失败保留并可重试")
	sm._active_save_path = path
	lesson._read_done()
	await get_tree().create_timer(0.8).timeout
	_check(sm.data.ganlu_lessons_v1.get(kind,false) and not hud._player.input_locked,"完成持久化并恢复输入："+kind)

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_fresh()
	_open({B:1})
	seated()
	Cycle.settle(sm,"manual")
	Cycle.acknowledge_settlement(sm)
	sm.data[Day.KEY].erase("preparation_lesson_pending")
	_open({B:3})
	sm.data[Day.KEY].arrival_left = 0.0
	var warm_arrival := Cycle.arrive(sm)
	var warm_id: String = warm_arrival.order.id
	sm.advance_restaurant_customer(warm_id,"arriving","front")
	sm.accept_restaurant_customer(warm_id)
	var hud = await _open_restaurant()
	await get_tree().create_timer(1.5).timeout
	var warm: Dictionary = sm.restaurant_customer_order(warm_id)
	await finish_lesson(hud,"warm")
	sm.data[Day.KEY].arrival_left = 0.0
	var arrival := Cycle.arrive(sm)
	var iced_id: String = arrival.order.id
	sm.advance_restaurant_customer(iced_id,"arriving","front")
	sm.accept_restaurant_customer(iced_id)
	hud.customer_flow._sync()
	await get_tree().create_timer(1.5).timeout
	var iced: Dictionary = sm.restaurant_customer_order(iced_id)
	_check(warm.drink_ice==0 and iced.drink_ice==1 and warm.stage=="drink" and iced.stage=="drink","全局第2、3位跨天固定常温/加冰")
	await finish_lesson(hud,"iced")
	var before_rep: int = sm.reputation()
	Water.begin(sm)
	Water.finish(sm,0.65)
	_check(Water.deliver(sm,warm.id).success and sm.reputation()==before_rep+5,"合格甘露水额外声望5")
	_check(not Water.deliver(sm,warm.id).success and sm.reputation()==before_rep+5,"重复交付不重复声望")
	Water.begin(sm)
	Water.finish(sm,0.65)
	Water.slot(sm,0)
	Water.tick(sm,3.0)
	await finish_lesson(hud,"ready")
	Water.tick(sm,9)
	Water.slot(sm,0)
	await finish_lesson(hud,"spoiled")
	var balance := Vector2i(sm.gold_balance(),sm.reputation())
	var result := Water.deliver(sm,iced.id)
	_check(result.success and result.angry and sm.gold_balance()==balance.x-2 and sm.reputation()==balance.y-1,"过冰可交付并扣款扣声望")
	_check(sm.restaurant_customer_order(iced.id).phase=="leaving","过冰顾客生气离场")
	await _close_restaurant()
	sm.save()
	sm.load_data()
	_check(sm.data.ganlu_lessons_v1.size()==4,"四段教学存档恢复")
	hud = await _open_restaurant()
	await get_tree().create_timer(0.3).timeout
	_check(not hud.customer_flow._arrival_tutorial_busy,"读档不重复已读教学")
	await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)

