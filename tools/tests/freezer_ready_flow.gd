extends "res://tools/tests/ice_binary_flow.gd"
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	_seed_cycle()
	scene = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(.5).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var view = hud.ganlu.freezer_view
	hud.ganlu.set_process(false)
	var player = scene.get_node("Player")
	player.position = _stand(view.get_parent())
	player.last_valid = player.position
	await get_tree().create_timer(.2).timeout
	var selected: int = view.nearest_slot()
	_check(view.prompt.visible and view.prompt.get_node("Content/ActionLabel").text=="冰镇","复用道具组件与冰镇文案")
	_check(player.label.text.is_empty(),"底部旧冰柜提示已清除")
	_check(view.find_children("*","SproutButton",true,false).is_empty(),"没有料理保鲜按钮")
	await _shot_gate("freezer_prompt_ready")
	Drink.begin(sm)
	Drink.finish(sm,.65)
	await _click(view.prompt)
	await get_tree().create_timer(.2).timeout
	_check(not Drink.snapshot(sm).slots[selected].is_empty(),"点击新按钮放入水杯")
	_check(view.buttons[selected].disabled and view.prompt.modulate!=Color.WHITE,"冰镇中置灰")
	var before: Dictionary = Drink.snapshot(sm).duplicate(true)
	await _click(view.prompt)
	_check(Drink.snapshot(sm)==before,"置灰提示点击不取出")
	await _shot_gate("freezer_prompt_disabled")
	Drink.tick(sm,3)
	await get_tree().create_timer(.15).timeout
	await _click(view.prompt)
	_check(not Drink.snapshot(sm).held.is_empty(),"完成后新按钮允许取出")
	player.input_locked = true
	await get_tree().create_timer(.15).timeout
	_check(not view.prompt.visible,"输入锁定隐藏")
	player.input_locked = false
	player.position = Vector2(850,600)
	player.last_valid = player.position
	await get_tree().create_timer(.2).timeout
	_check(not view.prompt.visible,"远离隐藏")
	var state := Drink.snapshot(sm)
	state.held = {}
	for i in range(3):
		state.slots[i] = {"amount":.65,"phase":"ready","cold":3.0,"chill_revision":3}
	Drink.commit(sm,state)
	await get_tree().create_timer(.2).timeout
	for i in range(3):
		_check(view.prompts[i].visible and view.prompts[i].get_node("Content/ActionLabel").text=="拿取","远处常驻拿取"+str(i))
	before = Drink.snapshot(sm).duplicate(true)
	await _click(view.prompts[0])
	_check(Drink.snapshot(sm)==before,"常驻按钮不能远程取杯")
	await _shot_gate("three_ready")
	player.position = _stand(view.get_parent())
	player.last_valid = player.position
	await get_tree().create_timer(.2).timeout
	await _shot_gate("full_green_border")
	await get_tree().create_timer(.3).timeout
	await _shot_gate("full_green_border_pulse")
	Drink.tick(sm,5)
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==1,"完整5秒窗口")
	Drink.tick(sm,.01)
	await get_tree().create_timer(.2).timeout
	_check(Drink.grade(Drink.snapshot(sm).slots[0])==4,"超过窗口仍损坏")
	for i in range(3):
		_check(view.prompts[i].visible and view.prompts[i].get_node("Content/ActionLabel").text=="拿取","损坏杯保持拿取"+str(i))
	await _shot_gate("spoiled_red_border")
	await _click(view.prompts[view.nearest_slot()])
	_check(not Drink.snapshot(sm).held.is_empty(),"靠近可取损坏杯")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)

