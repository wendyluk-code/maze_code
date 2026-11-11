extends "res://tools/tests/restaurant_service_cycle.gd"
var audio_cues: Array[StringName] = []

func _arrive() -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var result: Dictionary = sm.ensure_restaurant_customer()
	_check(result.get("created",false),"实际生成普通顾客")
	if not result.get("created",false): return {}
	var id: String = result.order.id
	_check(sm.advance_restaurant_customer(id,"arriving","front").success,"候客就绪")
	_check(sm.accept_restaurant_customer(id).success,"真实接单")
	_check(sm.advance_restaurant_customer(id,"seating","waiting").success,"接单后入座等待")
	return sm.restaurant_customer_order(id)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures: get_tree().quit(1); return
	sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
	sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
	GameAudio.cue_played.connect(func(cue: StringName): audio_cues.append(cue))
	if failures==0:
		_seed_cycle()
		sm.data.erase(Day.KEY)
		var scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.5).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var pour = hud.ganlu.modal
		hud.ganlu.cart()
		await get_tree().create_timer(0.2).timeout
		# 实际鼠标按住并松开，先验证不足水量进入结果而非携带。
		var button_point: Vector2 = pour.hold.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.position = button_point
		down.pressed = true
		get_viewport().push_input(down)
		await get_tree().create_timer(0.4).timeout
		_check(pour.pour_audio.playing,"按住倒水时播放附件音效")
		var up := down.duplicate()
		up.pressed = false
		get_viewport().push_input(up)
		await get_tree().create_timer(1.6).timeout
		_check(pour.finished and pour.result_popup.visible,"真实鼠标松手显示不足结算")
		_check(audio_cues.count(&"failure")==1,"水太少弹窗播放一次上错料理音效")
		_check(not pour.pour_audio.playing and audio_cues.count(&"cooking_complete")==0,"松手停倒水音且不足水量无成功音")
		await _click(pour.result_popup._confirm_button)
		_check(audio_cues.count(&"failure")==1,"重新倒水按钮不补播失败提示")
		for value in [0.2,1.1]:
			pour.start_pour()
			pour.amount = value
			pour.stop_pour()
			await get_tree().create_timer(1.6).timeout
			_check(pour.result_popup.visible and Drink.snapshot(sm).held.phase=="pouring","不合格仍不能端走")
			_check(audio_cues.count(&"cooking_complete")==0,"水太少或太满不响成功音")
			_check(audio_cues.count(&"failure")==2,"第二次不足重新响一次，过满不扩展失败音")
			_check(not Drink.finish(sm,value).success,"事务拒绝不合格水量")
			await _shot("too_low" if value<0.65 else "too_high")
			await _send_key(KEY_ESCAPE)
			_check(pour.visible and hud._player.input_locked,"Esc不能绕过重新倒水")
			await _click(pour.result_popup._confirm_button)
			_check(audio_cues.count(&"failure")==2,"结果停留和重倒不重复失败音")
			_check(pour.visible and not pour.started and Drink.snapshot(sm).held.is_empty(),"重倒清空杯子且不关闭窗口")
		await _key_hold(KEY_SPACE,true)
		await get_tree().create_timer(2.9).timeout
		await _key_hold(KEY_SPACE,false)
		await get_tree().create_timer(1.6).timeout
		_check(pour.finished and Drink.pour_factor(pour.amount)>0,"真实空格按住松开得到达标结果")
		_check(not pour.pour_audio.playing and audio_cues.count(&"cooking_complete")==1,"达标弹窗播放一次烹饪完成音")
		await _shot("ready")
		var old_path: String = sm._active_save_path
		sm._active_save_path = ""
		await _click(pour.result_popup._confirm_button)
		_check(pour.visible and not pour.committed and not pour.result_popup._confirm_button.disabled,"端起保存失败保留结果可重试")
		_check(audio_cues.count(&"cooking_complete")==1,"保存重试不重复播放结果音")
		sm._active_save_path = old_path
		await _click(pour.result_popup._confirm_button)
		_check(not pour.visible and not hud._player.input_locked and Drink.snapshot(sm).held.phase=="ready","达标端起恢复操作")
		hud.toast_label.dismiss()
		await get_tree().create_timer(3.0).timeout
		await _shot("carried_new_cup")
		sm.load_data()
		_check(Drink.snapshot(sm).held.phase=="ready","端起后重载保留水杯")
		_check(Drink.slot(sm,0).success,"新杯可以放入冰柜")
		Drink.tick(sm,3.0)
		_check(Drink.slot(sm,0).success,"冰镇达标后取回新杯")
		Day.save_menu(sm,{"salt_grilled_rockmane":10})
		Cycle.begin_day(sm)
		var customer := _arrive()
		_stage(customer.id,"drink",20)
		var served := Drink.deliver(sm,customer.id)
		_check(served.success and Drink.snapshot(sm).held.is_empty(),"新杯冰镇后可交付客人")
		Drink.discard(sm)
		hud.ganlu.cart()
		pour.start_pour()
		var departing_audio = pour.pour_audio
		scene.queue_free()
		await get_tree().process_frame
		_check(not is_instance_valid(departing_audio),"离场释放倒水播放器")
		sm.load_data()
		scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await get_tree().create_timer(0.5).timeout
		_check(Drink.snapshot(sm).held.is_empty(),"真实场景重进清除中断倒水")
		scene.queue_free()
		await get_tree().process_frame
	_check(sm.audio_guard_blocked==0,"存档写入仅限隔离目录")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
