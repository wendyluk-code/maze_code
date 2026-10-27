extends "res://tools/tests/combat_06_flow.gd"
## 只在此预览场景覆盖布局；不修改正式游戏组件或存档。
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _preview()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)

func _preview() -> void:
	await _new_scene()
	var flow=maze.capture_flow
	maze.player.position=Vector2(888,288)
	var c: Dictionary=sm.data[Run.KEY].combat
	c.hp=30
	c.sprint=0.6
	c.actors.slime_1.position=[790,326]
	c.actors.slime_1.mode="chase"
	c.actors.slime_1.hp=10
	maze.player.set_physics_process(false)
	await get_tree().process_frame
	flow.set_process(false)
	for monster in flow.monsters.values(): monster.set_process(false)
	flow.power_label.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	_restyle(flow.power_label,flow.hp_label,flow.health_bar)
	flow.power_label.position=Vector2(-30,-113)
	flow.sprint_bar.position=Vector2(0,35)
	flow.sprint_bar.size=Vector2(60,4)
	for monster in flow.monsters.values():
		_restyle(monster.label,monster.hp_label,monster.health_bar)
		monster.label.position=Vector2(-30,-monster.body.texture.get_height()*monster.body.scale.y-38)
	flow.controls_hint.hide()
	# 只在预览中摆放围攻样例，三个魔物仅最近目标显示数值。
	flow.power_label.text="ATK:3"
	flow.hp_label.text="HP:30/36"
	flow.health_bar.value=30
	flow.sprint_bar.value=0.6
	var positions := {"slime_1":Vector2(836,310),"slime_2":Vector2(939,332),"beetle_1":Vector2(961,283)}
	for id in flow.monsters:
		var monster=flow.monsters[id]
		monster.label.hide()
		if positions.has(id):
			monster.position=positions[id]
			monster.show()
	flow.monsters.slime_1.label.show()
	flow.monsters.slime_1.label.text="ATK:3"
	flow.monsters.slime_1.hp_label.text="HP:10/14"
	flow.monsters.slime_1.health_bar.value=10
	var hint=load("res://scenes/ui/interact_button.tscn").instantiate()
	maze._ui_root.add_child(hint)
	hint.size=Vector2(320,48)
	hint.position=Vector2(resolution_width()/2.0-160,get_viewport().get_visible_rect().size.y-56)
	var content=hint.get_node("Content")
	content.alignment=BoxContainer.ALIGNMENT_CENTER
	var first_key=content.get_node("KeyIcon")
	_preview_key(first_key,"Shift")
	content.get_node("ActionLabel").text="加速"
	var second_key=load("res://scenes/ui/key_button.tscn").instantiate()
	content.add_child(second_key)
	_preview_key(second_key,"单击")
	var attack=content.get_node("ActionLabel").duplicate()
	attack.text="攻击"
	content.add_child(attack)
	await get_tree().create_timer(0.3).timeout
	_check(flow.health_bar.size.x==60 and flow.sprint_bar.size.x==60,"短条宽度减半")
	_check(flow.hp_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT and flow.hp_label.position.x==flow.health_bar.position.x,"HP与血条左对齐")
	_check(is_equal_approx(flow.power_label.global_position.x+30,maze.player.global_position.x),"血条中心位于人物正上方")
	await _capture_image("short_bars_real_scene")
	await _close_scene()

func resolution_width() -> float: return get_viewport().get_visible_rect().size.x

func _restyle(atk: Label,hp: Label,bar: ProgressBar) -> void:
	atk.add_theme_font_size_override("font_size",9)
	atk.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	atk.size=Vector2(60,40)
	hp.add_theme_font_size_override("font_size",9)
	hp.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	hp.position=Vector2(0,12)
	hp.size=Vector2(60,12)
	bar.position=Vector2(0,26)
	bar.size=Vector2(60,6)

func _preview_key(key: Control, caption: String) -> void:
	key.custom_minimum_size=Vector2(76,48)
	key.get_node("KeyIcon").stretch_mode=TextureRect.STRETCH_SCALE
	var label=key.get_node("KeyIcon/KeyLabel")
	label.text=caption
	label.add_theme_font_override("font",ThemeDB.fallback_font if caption=="Shift" else SproutTheme.FONT_CN)
	label.add_theme_font_size_override("font_size",14)