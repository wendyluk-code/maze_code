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
var rock_status_visual: Node2D
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
const PlayerCombatRules=preload("res://scripts/maze/player_combat_rules.gd")
var death_presented := false
var save_retry_delay := 0.0
var _old_locked := false
var _old_physics := true
var hero_flash_display_remaining := 0.0
var monster_flash_display := {}
var skill_bar: HBoxContainer
var crystal_visual: Node2D
var skill_visual: Node2D
var axe_hitstop: RefCounted
var player_combat: Node
var locked_target_id: String:
	get: return player_combat.locked_target_id if is_instance_valid(player_combat) else ""
	set(value):
		if is_instance_valid(player_combat): player_combat.locked_target_id=value
var target_marker: Node2D
var player_hurt_visual: Node2D

func _flash_body(body: Sprite2D, remaining: float) -> void:
	# 已认可贴身水彩接管普通分水庭玩家白闪；原伤害与显示计时仍保留。
	if body==maze.player.body and is_instance_valid(player_hurt_visual) and character_combat_enabled():
		if body.material!=null: body.material.set_shader_parameter("flash",false)
		return
	# 已认可分水庭短促反馈替代该怪物的全身白闪，主角与其他地图沿原行为。
	if body.material!=null and body.material.shader==preload("res://scripts/maze/fenshui_hit_feedback.gdshader"):
		body.material.set_shader_parameter("flash",false)
		return
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
		if PlayerCombatRules.enabled(Run.snapshot(SaveManager).get("combat",{})): monster.enable_hit_feedback()
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
	# 共用提示组件统一位于业务弹窗与暗幕下方。
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
	if maze.region_id=="fenshui" and not Run.snapshot(SaveManager).combat.get("fs01_trial",false):
		power_label.z_index=4
		for monster in monsters.values():
			monster.label.z_index=4
			if monster.config.kind=="wind_frog": monster.combat_label_avoid=power_label
	hp_label=Monster.make_hp_label()
	if maze.region_id=="salt_pool":
		rock_status_visual=preload("res://scripts/maze/rock_status_visual.gd").new()
		rock_status_visual.z_index=5
		maze.add_child(rock_status_visual)
		for monster in monsters.values():
			if monster.config.kind=="rockmane":
				power_label.z_index=4
				monster.label.z_index=4
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
	controls_hint.set_target_lock_mode(target_lock_enabled())
	skill_bar=preload("res://scripts/ui/components/combat_skill_bar.gd").new()
	maze._ui_root.add_child(skill_bar)
	skill_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skill_bar.offset_left=-210
	skill_bar.offset_right=210
	skill_bar.offset_top=-132
	skill_bar.offset_bottom=-52
	skill_bar.selected.connect(_select_skill)
	skill_bar.details_requested.connect(_open_skill_details)
	player_combat=preload("res://scripts/maze/player_combat_controller.gd").new()
	maze.player.combat_controller=player_combat
	maze.player.add_child(player_combat)
	player_combat.install(self)
	controls_hint.set_target_lock_mode(target_lock_enabled())
	# 常驻战斗栏先绘制，所有后续业务弹窗与暗幕覆盖它们。
	maze._ui_root.move_child(controls_hint, 0)
	maze._ui_root.move_child(skill_bar, 0)
	if maze.region_id=="salt_pool":
		crystal_visual=preload("res://scripts/maze/salt_crystal_visual.gd").new()
		crystal_visual.flow=self
		maze.add_child(crystal_visual)
	if maze.region_id=="fenshui":
		var fish_warning:=preload("res://scripts/maze/silverfish_warning.gd").new()
		fish_warning.flow=self
		fish_warning.z_index=1
		maze.add_child(fish_warning)
		var frog_visual := preload("res://scripts/maze/wind_frog_visual.gd").new()
		frog_visual.flow=self
		maze.add_child(frog_visual)
		if not Run.snapshot(SaveManager).combat.get("fs01_trial",false):
			var frog: Node=monsters.get(preload("res://data/maze/fenshui_boss.gd").ID)
			if is_instance_valid(frog):
				if not frog.enable_frog_front24(): push_error("巨蛙双前向动作素材加载失败")
				var splash=preload("res://scripts/maze/frog_splash_aligned_visual.gd").new()
				splash.name="LandingSplashCandidate"
				splash.flow=self
				frog.add_child(splash)

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

func charge_active() -> bool:
	return Run.Combat.Skills.Charge.active(display_run().get("combat",{}))

func charge_speed() -> float:
	return Run.Combat.Skills.Charge.speed(display_run().get("combat",{}))

func sprint_charge() -> float:
	return float(display_run().get("combat",{}).get("sprint",1.0))

func rock_movement_factor() -> float:
	return Run.Combat.Rock.slow_factor(display_run().get("combat",{}))

func player_recovering() -> bool:
	return character_combat_enabled() and Run.Combat.PlayerHurt.recovering(display_run().get("combat",{}))

func character_combat_enabled() -> bool:
	return is_instance_valid(player_combat) and player_combat.enabled()

func target_lock_enabled() -> bool:
	return character_combat_enabled()

func _lock_candidates(run: Dictionary) -> Array[String]:
	return player_combat.candidates(run) if is_instance_valid(player_combat) else []

func _sync_target_lock(run: Dictionary) -> void:
	if is_instance_valid(player_combat): player_combat.sync(run)

func _cycle_target_lock() -> void:
	if is_instance_valid(player_combat): player_combat.cycle()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(player_combat) and player_combat.handle_input(event): get_viewport().set_input_as_handled()

func _select_skill(slot: int) -> void:
	if combat_paused(): return
	var members: Array=display_run().get("members",[])
	if slot>0 and slot<=members.size() and members[slot-1].id in ["ahong","chengyan"]:
		maze.show_toast("阿轰为团队被动，战斗移动时自动留下雷印" if members[slot-1].id=="ahong" else "澄砚为团队被动，每趟首次致命伤自动保命")
		return
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
	if sparring() == null: GameAudio.update_boss_music(run)
	if (sparring()==null and not Run.valid(run)) or not run.get("active",false) or not run.has("combat"): return
	var combat: Dictionary = run.combat
	_sync_target_lock(run)
	# 补算可以在同一帧耗尽模拟白闪；显示计时只按渲染帧推进。
	if not combat_paused():
		hero_flash_display_remaining = maxf(0.0, hero_flash_display_remaining-delta)
		for key in monster_flash_display: monster_flash_display[key]=maxf(0.0,monster_flash_display[key]-delta)
	maze.camera.set_roar_shake(float(combat.get("rock_shake_left",0.0)),float(combat.get("elapsed",0.0)),combat_paused())
	maze.camera.set_combo_frame(combat,combat_paused())
	if combat.hp <= 0:
		hero_flash_display_remaining = 0.0
		if is_instance_valid(player_hurt_visual): player_hurt_visual.clear()
		for monster in monsters.values():
			if is_instance_valid(monster.hit_visual): monster.hit_visual.clear()
			if is_instance_valid(monster.heal_visual): monster.heal_visual.clear()
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
	if not locked_target_id.is_empty(): target=locked_target_id
	for id in monsters:
		if sparring()!=null:
			monsters[id].hide()
			continue
		var actor: Dictionary = combat.actors[id]
		monsters[id].action_paused=axe_hitstop!=null and axe_hitstop.paused(id)
		_flash_body(monsters[id].body, float(actor.get("flash_remaining", 0.0)))
		monsters[id].position = Run.Combat.vec(actor.position)
		monsters[id].update_motion(Run.Combat.vec(actor.velocity))
		monsters[id].sync_action(actor,combat)
		monsters[id].visible = run.monsters[id].status=="alive" or (monsters[id].config.has("animation_dir") and run.monsters[id].status=="pending")
		var kind: String=str(monsters[id].config.kind)
		monsters[id].label.text = "ATK:%d" % preload("res://scripts/maze/monster_editor.gd").attack(kind,int(Run.Combat.STATS[kind].attack))
		monsters[id].hp_label.text="HP:%d/%d" % [actor.hp,Run.Combat.STATS[monsters[id].config.kind].hp]
		monsters[id].health_bar.max_value=Run.Combat.STATS[monsters[id].config.kind].hp
		monsters[id].health_bar.value=actor.hp
		monsters[id].health_bar.tooltip_text="生命 %d/%d" % [actor.hp,monsters[id].health_bar.max_value]
		monsters[id].label.visible = id==target and actor.get("frog_phase","")!="emerging"
		monsters[id].label.self_modulate = Color("ffaf70") if actor.mode=="windup" else Color.WHITE
	_layout_combat_labels()
	if is_instance_valid(rock_status_visual): rock_status_visual.sync(self,run)
	if is_instance_valid(target_marker): target_marker.sync(self,delta)
	# 重试等待不推进战斗，也不保留输入；其计时仅在其他锁解除时推进。
	if save_retry_delay>0.0 and window_focused and not busy and not maze._busy:
		save_retry_delay=maxf(0.0,save_retry_delay-delta)
	var paused: bool = combat_paused()
	controls_hint.set_target_lock_mode(target_lock_enabled())
	controls_hint.visible=maze._entry_ready
	skill_bar.visible=maze._entry_ready
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
	var normal_fenshui: bool=maze.region_id=="fenshui" and not combat.get("fs01_trial",false)
	for id in monsters:
		if run.monsters[id].status=="alive" and combat.actors[id].hp<=0:
			# 正常分水庭只延后捕获窗，不让单只魔物的死亡动作冻结全场战斗。
			if normal_fenshui and monsters[id].config.has("animation_dir") and monsters[id].action_time<0.72: break
			if axe_hitstop!=null:
				axe_hitstop.advance_wait(delta)
				monsters[id].action_paused=axe_hitstop.paused(id)
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
		if axe_hitstop!=null and (current_combat.get("action","")=="tieshan" and float(current_combat.get("action_left",0.0))>0.0): step=0.01
		# 受击期间细分至10毫秒，让0.12秒位移不会被20Hz常规步长拉长。
		if maxf(float(current_combat.get("hit_remaining", 0.0)), float(current_combat.get("flash_remaining", 0.0))) > 0.00001: step = 0.01
		for actor in current_combat.actors.values():
			if maxf(float(actor.get("hit_remaining", 0.0)), float(actor.get("flash_remaining", 0.0))) > 0.00001: step = 0.01
		if combat_time + 0.000001 < step: break
		combat_time = maxf(0.0, combat_time - step)
		var result := Run.combat_tick(SaveManager,maze.player.position,step,visible_world_rect(),maze.player.sprinting,axe_hitstop,maze.player.facing)
		if result.success:
			GameAudio.update_boss_music(Run.snapshot(SaveManager))
			if is_instance_valid(crystal_visual): crystal_visual.feedback(result.get("mining_feedback",[]))
			var updated_run:=Run.snapshot(SaveManager)
			var updated: Dictionary = updated_run.combat
			_sync_target_lock(updated_run)
			if updated.hp < current_combat.hp:
				GameAudio.play_cue(&"hero_hurt")
			if updated.hp > 0 and updated.hp < current_combat.hp:
				hero_flash_display_remaining = Run.Combat.FLASH_DURATION
			maze.player.position=Run.Combat.vec(updated.hero)
			if is_instance_valid(player_hurt_visual) and updated.hp>0:
				for event in result.get("player_hurt_feedback",[]): player_hurt_visual.receive(event)
			_flash_body(maze.player.body, float(updated.get("flash_remaining", 0.0)))
			for id in monsters:
				monsters[id].action_paused=axe_hitstop!=null and axe_hitstop.paused(id)
				if updated.actors[id].hp<current_combat.actors[id].hp:
					GameAudio.play_hit()
					monster_flash_display[monsters[id].body.get_instance_id()]=Run.Combat.FLASH_DURATION
				monsters[id].position = Run.Combat.vec(updated.actors[id].position)
				monsters[id].update_motion(Run.Combat.vec(updated.actors[id].velocity))
				monsters[id].sync_action(updated.actors[id],updated)
				if is_instance_valid(monsters[id].heal_visual):
					monsters[id].heal_visual.sync(updated.actors[id].hp>current_combat.actors[id].hp and updated.actors[id].hp<Run.Combat.STATS[monsters[id].config.kind].hp and updated.hp>0)
				_flash_body(monsters[id].body, float(updated.actors[id].get("flash_remaining", 0.0)))
			for event in result.get("hit_feedback",[]):
				if updated.hp>0 and monsters.has(event.id) and updated.actors[event.id].hp>0 and is_instance_valid(monsters[event.id].hit_visual): monsters[event.id].hit_visual.receive(event)
			# 同一帧推进后再跟随新身体锚点，避免标记落后一个战斗步；死亡清理也立即消费。
			if is_instance_valid(target_marker): target_marker.sync(self,0.0)
			if updated.hp <= 0 or maze._busy: break
			if is_instance_valid(maze.exploration_guide) and maze.exploration_guide.before_combat(Run.snapshot(SaveManager)):
				maze.player.clear_combat_input()
				combat_time = 0.0
				break
			var killed := false
			for id in monsters:
				if run.monsters[id].status == "alive" and updated.actors[id].hp <= 0 and (not normal_fenshui or current_combat.actors[id].hp > 0): killed = true
			if killed: break
		else:
			maze.player.position=Run.Combat.vec(current_combat.hero)
			for monster in monsters.values():
				if is_instance_valid(monster.heal_visual): monster.heal_visual.clear()
			save_retry_delay=1.0
			maze.show_toast("战斗保存失败，已恢复上次进度，请检查存档后重试")
			break

func visible_world_rect() -> Rect2:
	var inverse := maze.get_viewport().get_canvas_transform().affine_inverse()
	var viewport := maze.get_viewport_rect()
	return Rect2(inverse * viewport.position, Vector2.ZERO).expand(inverse * viewport.end)

func _layout_combat_labels() -> void:
	# 巨蛙及岩鬃兽复用原短条避让，不改字体、尺寸和水平居中。
	power_label.position=Vector2(-30,-113)
	for candidate in monsters.values():
		if candidate.config.kind!="rockmane" or not candidate.is_visible_in_tree(): continue
		var view:=visible_world_rect()
		var top: float=view.position.y+110.0/maze.camera.zoom.y
		if power_label.global_position.y<top:
			power_label.position.x=35.0
			power_label.global_position.y=top
			if power_label.get_global_rect().end.x>view.end.x-6.0: power_label.position.x=-95.0
		break
	for monster in monsters.values():
		if monster.config.kind=="rockmane":
			monster.combat_label_avoid=power_label
		if is_instance_valid(monster.combat_label_avoid):
			monster.layout_frog_label()
			continue
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
	# 常驻小地图留在详情蒙层下方。
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

func movement_allowed(from: Vector2, to: Vector2) -> bool:
	if sparring()!=null: return true
	return preload("res://scripts/maze/fenshui_bodies.gd").step(display_run(),"hero",from,to)

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
			attempt.start(0.0, false)
			attempt.result_passed = run.monsters[current].attempt.passed
			_finish_attempt(attempt.result_passed)
		else:
			attempt.start(maxf(0,Time.get_unix_time_from_system()-float(run.monsters[current].attempt.started_at)), false)
		return
	var direction: int=preload("res://scripts/maze/wind_frog_counter.gd").facing(run.combat.actors[current]) if row.kind=="wind_frog" else 0
	var art: Array[Texture2D]=[]
	if won and row.kind=="wind_frog" and monsters.has(current) and monsters[current].frog_front24!=null:
		art=monsters[current].frog_front24.capture_frames(direction,true,monsters[current].frog_defeated_belly)
	dialog.present(won,row.kind,Run.payer_index(SaveManager, run)>=0,int(run.base_power)+int(run.absorbed),int(row.power),Run.capture_count(SaveManager,run),direction,art)

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
	var row: Dictionary=Run.monster_for(run,current).duplicate()
	if row.kind=="wind_frog": row.direction=preload("res://scripts/maze/wind_frog_counter.gd").facing(run.combat.actors[current])
	var art: Array[Texture2D]=[]
	if row.kind=="wind_frog" and monsters.has(current) and monsters[current].frog_front24!=null:
		art=monsters[current].frog_front24.capture_frames(int(row.direction))
	attempt.present(row,run,Run.payer_index(SaveManager,run)>=0,Run.capture_count(SaveManager,run),art)

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
		GameAudio.play_cue(&"capture_success")
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
