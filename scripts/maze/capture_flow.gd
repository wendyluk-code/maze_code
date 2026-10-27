extends Node
const Run := preload("res://scripts/maze/capture_run.gd")
const Catalog := preload("res://data/maze/capture_catalog.gd")
const Monster := preload("res://scripts/maze/capture_monster.gd")
const Dialog := preload("res://scripts/ui/components/capture_dialog.gd")
const Loot := preload("res://scripts/ui/components/loot_modal.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
var maze: Node2D
var monsters: Dictionary = {}
var dialog: Control
var reward: Control
var attempt: Control
var hud: Label
var power_label: Label
var health_bar: ProgressBar
var hp_label: Label
var sprint_bar: ProgressBar
var controls_hint: Control
var window_focused := true
var party_panel: Panel
var party_food: Label
var character_details: Control
var member_buttons: Dictionary = {}
var current := ""
var blocked_until_leave := {}
var busy := false
var resolving := false
var combat_time := 0.0
const HitFlash = preload("res://scripts/maze/hit_flash.gdshader")
var death_presented := false
var save_retry_delay := 0.0
var _old_locked := false
var _old_physics := true
var hero_flash_display_remaining := 0.0
var monster_flash_display := {}
var skill_bar: HBoxContainer
var crystal_visual: Node2D
var skill_visual: Node2D

func _flash_body(body: Sprite2D, remaining: float) -> void:
	if body == maze.player.body:
		remaining = maxf(remaining, hero_flash_display_remaining)
	else:
		remaining=maxf(remaining,float(monster_flash_display.get(body.get_instance_id(),0.0)))
	if body.material == null:
		body.material = ShaderMaterial.new()
		body.material.shader = HitFlash
	body.material.set_shader_parameter("flash", remaining > 0.00001)

func attach(owner_maze: Node2D) -> void:
	maze = owner_maze
	# 装饰计数原本忽略鼠标；仅迷宫实例拦截点击，避免穿透为战斗攻击。
	maze.gold_counter.mouse_filter=Control.MOUSE_FILTER_STOP
	maze._ui_root.get_node("StaminaCounter").mouse_filter=Control.MOUSE_FILTER_STOP
	window_focused=maze.get_window().has_focus()
	maze.get_window().focus_exited.connect(_focus_lost)
	maze.get_window().focus_entered.connect(func(): window_focused=true)
	for row in Run.monsters_for(Run.snapshot(SaveManager)):
		if row.get("region","maze_entry") != maze.region_id: continue
		var monster := Monster.new()
		monster.config = row
		maze.add_child(monster)
		monsters[row.id] = monster
	dialog = Dialog.new()
	dialog.entry_only = true
	maze._ui_root.add_child(dialog)
	dialog.toast = maze.show_toast
	dialog.choice.connect(_choose)
	dialog.dismissed.connect(_dismiss)
	reward = Loot.new()
	maze._ui_root.add_child(reward)
	reward.closed.connect(_unlock)
	attempt = preload("res://scripts/ui/components/capture_attempt_modal.gd").new()
	maze._ui_root.add_child(attempt)
	attempt.requested.connect(_start_attempt)
	attempt.cancelled.connect(_cancel_attempt)
	attempt.finished.connect(_finish_attempt)
	attempt.retry_requested.connect(_retry_attempt)
	hud = Label.new()
	hud.position = Vector2(24,85)
	hud.add_theme_font_size_override("font_size",20)
	hud.add_theme_color_override("font_color",SproutTheme.CREAM)
	hud.add_theme_color_override("font_outline_color",SproutTheme.INK)
	hud.add_theme_constant_override("outline_size",4)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	maze._ui_root.add_child(hud)
	_build_party_panel()
	character_details = preload("res://scripts/ui/components/character_details_modal.gd").new()
	maze._ui_root.add_child(character_details)
	character_details._close_button.tooltip_text = "返回迷宫"
	character_details.closed.connect(_close_character_details)
	# 提示必须绘制在模态窗之上，零饱腹点击反馈才可读。
	maze._ui_root.move_child(maze.toast_label.get_parent(),-1)
	maze.player.capture_flow = self
	power_label = Label.new()
	power_label.add_theme_font_override("font",Monster.STATS_FONT)
	power_label.add_theme_font_size_override("font_size",9)
	power_label.add_theme_color_override("font_color",SproutTheme.CREAM)
	power_label.add_theme_color_override("font_outline_color",SproutTheme.INK)
	power_label.add_theme_constant_override("outline_size",2)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_label.position = Vector2(-30,-113)
	power_label.size = Vector2(60,40)
	maze.player.add_child(power_label)
	hp_label=Monster.make_hp_label()
	power_label.add_child(hp_label)
	health_bar=Monster.make_health_bar()
	power_label.add_child(health_bar)
	sprint_bar=Monster.make_health_bar(Color("e6b943"),4.0)
	sprint_bar.position.y=35
	sprint_bar.max_value=1.0
	power_label.add_child(sprint_bar)
	controls_hint=preload("res://scripts/ui/components/combat_controls_hint.gd").new()
	maze._ui_root.add_child(controls_hint)
	controls_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	controls_hint.grow_horizontal=Control.GROW_DIRECTION_BOTH
	controls_hint.grow_vertical=Control.GROW_DIRECTION_BEGIN
	controls_hint.offset_top=-48
	controls_hint.offset_bottom=0
	controls_hint.offset_left=-174
	controls_hint.offset_right=174
	skill_bar=preload("res://scripts/ui/components/combat_skill_bar.gd").new()
	maze._ui_root.add_child(skill_bar)
	skill_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skill_bar.offset_left=-210
	skill_bar.offset_right=210
	skill_bar.offset_top=-132
	skill_bar.offset_bottom=-52
	skill_bar.selected.connect(_select_skill)
	skill_bar.details_requested.connect(_open_skill_details)
	skill_visual=preload("res://scripts/maze/team_attack_visual.gd").new()
	maze.add_child(skill_visual)
	skill_visual.flow=self
	if maze.region_id=="salt_pool":
		crystal_visual=preload("res://scripts/maze/salt_crystal_visual.gd").new()
		crystal_visual.flow=self
		maze.add_child(crystal_visual)
	if maze.region_id=="fenshui":
		var frog_visual := preload("res://scripts/maze/wind_frog_visual.gd").new()
		frog_visual.flow=self
		maze.add_child(frog_visual)

func _focus_lost() -> void:
	window_focused=false
	combat_time=0.0
	maze.player.clear_combat_input()

func combat_paused() -> bool:
	return not window_focused or not maze._entry_ready or busy or maze._busy or maze.player.input_locked or not maze.player.is_physics_processing() or maze.confirmation.visible or maze.map_ui.expanded or (is_instance_valid(maze.elder) and maze.elder.is_busy()) or save_retry_delay>0.0

func sparring() -> Node:
	if is_instance_valid(maze) and is_instance_valid(maze.yf_encounter) and maze.yf_encounter.phase=="battle": return maze.yf_encounter
	return null

func display_run() -> Dictionary:
	var event := sparring()
	return event.run if event!=null else Run.snapshot(SaveManager)

func sprint_charge() -> float:
	return float(display_run().get("combat",{}).get("sprint",1.0))

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(maze) or combat_paused(): return
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := -1
		if event.keycode==KEY_SPACE: slot=0
		elif event.keycode>=KEY_1 and event.keycode<=KEY_4: slot=int(event.keycode-KEY_1)+1
		elif event.keycode==KEY_TAB:
			var run := display_run()
			for offset in range(1,6):
				var candidate := (int(run.combat.get("selected",0))+offset)%5
				if not Run.Combat.Skills.kind(run,candidate).is_empty():
					slot=candidate
					break
		if slot>=0:
			get_viewport().set_input_as_handled()
			_select_skill(slot)
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	get_viewport().set_input_as_handled()
	var aim: Vector2=preload("res://scripts/maze/auto_aim.gd").direction(display_run(),maze.player.position,maze.player.facing,sparring()!=null)
	if aim.is_zero_approx(): aim=maze.player.facing
	if sparring()!=null:
		sparring().attack(aim)
		return
	var result := Run.combat_attack(SaveManager,maze.player.position,aim)
	if not result.success:
		save_retry_delay=1.0
		maze.show_toast("攻击保存失败，已恢复上次进度，请检查存档后重试")

func _select_skill(slot: int) -> void:
	if combat_paused(): return
	if sparring()!=null:
		Run.Combat.Skills.select(sparring().run,slot)
		return
	var result := Run.combat_command(SaveManager,"select",slot)
	if not result.success:
		save_retry_delay=1.0
		maze.show_toast("切换保存失败，已恢复上次进度")
	skill_bar.sync(display_run())

func _process(delta: float) -> void:
	if not is_instance_valid(maze) or not maze._entry_ready: return
	var run := display_run()
	if (sparring()==null and not Run.valid(run)) or not run.get("active",false) or not run.has("combat"): return
	var combat: Dictionary = run.combat
	# 补算可以在同一帧耗尽模拟白闪；显示计时只按渲染帧推进。
	if not combat_paused():
		hero_flash_display_remaining = maxf(0.0, hero_flash_display_remaining-delta)
		for key in monster_flash_display: monster_flash_display[key]=maxf(0.0,monster_flash_display[key]-delta)
	maze.camera.set_roar_shake(0.0 if combat_paused() else float(combat.get("rock_shake_left",0.0)))
	if combat.hp <= 0:
		hero_flash_display_remaining = 0.0
	_flash_body(maze.player.body, float(combat.get("flash_remaining", 0.0)))
	power_label.text = "ATK:%d" % combat.attack
	hp_label.text="HP:%d/%d" % [combat.hp,combat.max_hp]
	sprint_bar.value=float(combat.get("sprint",1.0))
	health_bar.max_value=combat.max_hp
	health_bar.value=combat.hp
	health_bar.tooltip_text="生命 %d/%d" % [combat.hp,combat.max_hp]
	party_food.text = "%d/%d" % [floori(float(run.satiety)), run.satiety_max]
	hud.hide()
	var target := "" if sparring()!=null else Run.Combat.select_target(run,maze.player.position)
	for id in monsters:
		if sparring()!=null:
			monsters[id].hide()
			continue
		var actor: Dictionary = combat.actors[id]
		_flash_body(monsters[id].body, float(actor.get("flash_remaining", 0.0)))
		monsters[id].position = Run.Combat.vec(actor.position)
		monsters[id].update_motion(Run.Combat.vec(actor.velocity))
		monsters[id].sync_action(actor)
		monsters[id].visible = run.monsters[id].status=="alive" or (monsters[id].config.has("animation_dir") and run.monsters[id].status=="pending")
		monsters[id].label.text = "ATK:%d" % Run.Combat.STATS[monsters[id].config.kind].attack
		monsters[id].hp_label.text="HP:%d/%d" % [actor.hp,Run.Combat.STATS[monsters[id].config.kind].hp]
		monsters[id].health_bar.max_value=Run.Combat.STATS[monsters[id].config.kind].hp
		monsters[id].health_bar.value=actor.hp
		monsters[id].health_bar.tooltip_text="生命 %d/%d" % [actor.hp,monsters[id].health_bar.max_value]
		monsters[id].label.visible = id==target and actor.get("frog_phase","")!="emerging"
		monsters[id].label.self_modulate = Color("ffaf70") if actor.mode=="windup" else Color.WHITE
	_layout_combat_labels()
	# 重试等待不推进战斗，也不保留输入；其计时仅在其他锁解除时推进。
	if save_retry_delay>0.0 and window_focused and not busy and not maze._busy:
		save_retry_delay=maxf(0.0,save_retry_delay-delta)
	var paused: bool = combat_paused()
	controls_hint.visible=not paused
	skill_bar.visible=not paused
	skill_bar.sync(run)
	for monster in monsters.values(): monster.set_process(not paused)
	if paused:
		combat_time=0.0
		maze.player.clear_combat_input()
		return
	if sparring()!=null: return
	if combat.hp<=0:
		death_presented=true
		_lock()
		dialog.present_exploration_failure(combat.last_attacker)
		return
	if not str(run.pending).is_empty():
		current = str(run.pending)
		_lock()
		_present(true)
		return
	for id in monsters:
		if run.monsters[id].status=="alive" and combat.actors[id].hp<=0:
			if monsters[id].config.has("animation_dir") and monsters[id].action_time<0.72: return
			_encounter(id)
			return
	if is_instance_valid(maze.exploration_guide) and maze.exploration_guide.before_combat(run):
		maze.player.clear_combat_input()
		combat_time = 0.0
		return
	combat_time = minf(0.2, combat_time + delta)
	while combat_time > 0.00001:
		var current_combat: Dictionary = Run.snapshot(SaveManager).combat
		var step := 0.05
		# 受击期间细分至10毫秒，让0.12秒位移不会被20Hz常规步长拉长。
		if maxf(float(current_combat.get("hit_remaining", 0.0)), float(current_combat.get("flash_remaining", 0.0))) > 0.00001: step = 0.01
		for actor in current_combat.actors.values():
			if maxf(float(actor.get("hit_remaining", 0.0)), float(actor.get("flash_remaining", 0.0))) > 0.00001: step = 0.01
		if combat_time + 0.000001 < step: break
		combat_time = maxf(0.0, combat_time - step)
		var result := Run.combat_tick(SaveManager,maze.player.position,step,visible_world_rect(),maze.player.sprinting)
		if result.success:
			if is_instance_valid(crystal_visual): crystal_visual.feedback(result.get("mining_feedback",[]))
			var updated: Dictionary = Run.snapshot(SaveManager).combat
			if updated.hp > 0 and updated.hp < current_combat.hp:
				hero_flash_display_remaining = Run.Combat.FLASH_DURATION
			maze.player.position=Run.Combat.vec(updated.hero)
			_flash_body(maze.player.body, float(updated.get("flash_remaining", 0.0)))
			for id in monsters:
				if updated.actors[id].hp<current_combat.actors[id].hp:
					monster_flash_display[monsters[id].body.get_instance_id()]=Run.Combat.FLASH_DURATION
				monsters[id].position = Run.Combat.vec(updated.actors[id].position)
				monsters[id].update_motion(Run.Combat.vec(updated.actors[id].velocity))
				_flash_body(monsters[id].body, float(updated.actors[id].get("flash_remaining", 0.0)))
			if updated.hp <= 0 or maze._busy: break
			if is_instance_valid(maze.exploration_guide) and maze.exploration_guide.before_combat(Run.snapshot(SaveManager)):
				maze.player.clear_combat_input()
				combat_time = 0.0
				break
			var killed := false
			for id in monsters:
				if run.monsters[id].status == "alive" and updated.actors[id].hp <= 0: killed = true
			if killed: break
		else:
			maze.player.position=Run.Combat.vec(current_combat.hero)
			save_retry_delay=1.0
			maze.show_toast("战斗保存失败，已恢复上次进度，请检查存档后重试")
			break

func visible_world_rect() -> Rect2:
	var inverse := maze.get_viewport().get_canvas_transform().affine_inverse()
	var viewport := maze.get_viewport_rect()
	return Rect2(inverse * viewport.position, Vector2.ZERO).expand(inverse * viewport.end)

func _layout_combat_labels() -> void:
	# 单目标标签始终位于角色正上方，不再为了避让横向漂移。
	for monster in monsters.values():
		monster.combat_label_offset=0.0
		var height: float=monster.body.region_rect.size.y*0.65 if monster.config.has("animation_dir") else monster.body.texture.get_height()
		monster.label.position=Vector2(-30,-height*monster.body.scale.y-38)

func _build_party_panel() -> void:
	# 复用体力同款资源计数器，保持字号、图标和垂直对齐一致。
	var stamina := get_tree().get_first_node_in_group("stamina_counter") as Control
	var food := preload("res://scripts/ui/components/resource_counter.gd").new()
	food.name = "SatietyCounter"
	food.configure(preload("res://assets/ui/character_details/satiety.png"))
	var host := Node2D.new()
	host.name = "SatietyHost"
	stamina.add_child(host)
	host.add_child(food)
	party_food = food.value_label
	var layout := func():
		food.size = Vector2(food.get_combined_minimum_size().x, stamina.size.y)
		food.position = Vector2(-food.size.x - 24.0, 0)
	food.minimum_size_changed.connect(layout)
	stamina.resized.connect(layout)
	layout.call()

func _open_skill_details(slot: int) -> void:
	var members: Array = display_run().get("members", [])
	var id: String = str(members[slot - 1].id) if slot > 0 and slot <= members.size() else ""
	if id.is_empty() or id == "hero": return
	_open_character_details(id)

func _open_character_details(id: String) -> void:
	if busy or maze._busy or maze.player.input_locked or not skill_bar.is_visible_in_tree(): return
	_lock()
	# 角色详情覆盖迷宫界面时隐藏右上角小地图，避免圆形地图与关闭叉号重叠。
	if is_instance_valid(maze.map_ui) and is_instance_valid(maze.map_ui.mini_button):
		maze.map_ui.mini_button.hide()
	character_details.present(id)
	maze._sync_task_access()

func _close_character_details() -> void:
	if is_instance_valid(maze.map_ui) and is_instance_valid(maze.map_ui.mini_button) and not maze.map_ui.expanded:
		maze.map_ui.mini_button.show()
	_unlock()
	maze._sync_task_access()

func _bag_count(bag: Dictionary) -> int:
	var total := 0
	for value in bag.values(): total += int(value)
	return total

func movement_allowed(_from: Vector2, _to: Vector2) -> bool:
	return true

func _encounter(id: String) -> void:
	current = id
	blocked_until_leave[id] = true
	var result := Run.defeat(SaveManager,id,maze.player.position)
	if not result.success:
		save_retry_delay=1.0
		maze.show_toast("战斗进度保存失败，请稍后重试")
		return
	_lock()
	_present(result.success)

func _present(won: bool) -> void:
	var run := Run.snapshot(SaveManager)
	var row := Run.monster_for(run, current)
	if won and run.monsters[current].has("attempt"):
		_open_attempt()
		if run.monsters[current].attempt.finished:
			attempt.start()
			attempt.result_passed = run.monsters[current].attempt.passed
			_finish_attempt(attempt.result_passed)
		else:
			attempt.start(maxf(0,Time.get_unix_time_from_system()-float(run.monsters[current].attempt.started_at)))
		return
	dialog.present(won,row.kind,Run.payer_index(SaveManager, run)>=0,int(run.base_power)+int(run.absorbed),int(row.power),Run.capture_count(SaveManager,run))

func _lock() -> void:
	maze.player.clear_combat_input()
	combat_time=0.0
	_old_locked = maze.player.input_locked
	_old_physics = maze.player.is_physics_processing()
	busy = true
	maze._busy = true
	maze.player.input_locked = true
	maze.player.set_physics_process(false)
	maze.toast_label.dismiss()

func _choose(capture: bool) -> void:
	if resolving: return
	if capture:
		resolving = true
		await dialog.flip_out()
		if not is_instance_valid(maze): return
		_open_attempt()
		resolving = false
		return
	resolving = true
	var result := Run.resolve(SaveManager,current,capture)
	if not result.success:
		resolving = false
		maze.show_toast("饱腹度不足，无法捕获" if result.reason=="hungry" else "捕获进度保存失败，请重试")
		return
	await dialog.flip_out()
	if not is_instance_valid(maze): return
	_unlock()
	resolving = false

func _open_attempt() -> void:
	var run := Run.snapshot(SaveManager)
	attempt.present(Run.monster_for(run,current),run,Run.payer_index(SaveManager,run)>=0,Run.capture_count(SaveManager,run))

func _start_attempt() -> void:
	if resolving or attempt.mode != "ready": return
	resolving = true
	var result := Run.start_capture(SaveManager,current)
	if result.success:
		attempt.start()
	else:
		maze.show_toast("饱腹度不足，无法捕获" if result.reason=="hungry" else "捕获进度保存失败，请重试")
	resolving = false

func _cancel_attempt() -> void:
	if resolving or attempt.mode != "ready": return
	var result := Run.resolve(SaveManager,current,false)
	if not result.success:
		maze.show_toast("捕获进度保存失败，请重试")
		return
	attempt.close()
	_unlock()

func _retry_attempt() -> void:
	_finish_attempt(attempt.result_passed)

func _finish_attempt(passed: bool) -> void:
	if resolving: return
	resolving = true
	attempt.mode = "settling"
	var result := Run.finish_capture(SaveManager,current,passed)
	if result.success: result = Run.resolve(SaveManager,current,true)
	if not result.success:
		attempt.settlement_error()
		maze.show_toast("捕获进度保存失败，请重试")
		resolving = false
		return
	attempt.close()
	if result.caught:
		var items: Array[Dictionary] = []
		for id in result.items:
			items.append({"name":Recipes.get_ingredient(id).get("name",id),"quantity":result.items[id],"icon":Recipes.item_texture(id)})
		reward.show_items(items)
		reward._title_label.text = "捕获成功"
		reward._body_label.text = ""
		reward._body_label.hide()
	else:
		dialog.present_capture_failure(Run.monster_for(Run.snapshot(SaveManager),current).get("kind","slime"))
	resolving = false

func _dismiss() -> void:
	if resolving: return
	if death_presented:
		dialog.hide()
		_unlock()
		maze.return_to_restaurant(false)
		death_presented=false
		return
	dialog.hide()
	_unlock()

func _unlock() -> void:
	busy = false
	maze._busy = false
	maze.player.input_locked = _old_locked
	maze.player.set_physics_process(_old_physics)
	maze._interact_armed = not Input.is_action_pressed("interact")
	current = ""
	get_viewport().gui_release_focus()
