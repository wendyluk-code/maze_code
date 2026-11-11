extends Node2D
## 路边坐姿委托；对白、奖励、入队与离场接续已保存检查点。
const Story = preload("res://scripts/maze/yufeng_salia_story.gd")
const IngredientGift = preload("res://scripts/restaurant/yufeng_ingredient_gift.gd")
const Run = preload("res://scripts/maze/capture_run.gd")
const WorldPrompt = preload("res://scripts/ui/components/world_interaction_prompt.gd")
const DialogScene = preload("res://scenes/ui/dialog_box.tscn")
const FRAME_ORDER := [0,1,2,3,1,0]
const FRAME_DURATIONS := [0.85,0.35,0.16,0.35,0.35,0.45]
const EYE_ANCHORS := [
	[Vector2(268,205),Vector2(307,194)],
	[Vector2(270,200),Vector2(310,188)],
	[Vector2(270,218),Vector2(310,205)],
	[Vector2(272,217),Vector2(311,202)],
]
var maze: Node2D
var phase := "unseen"
var record: Dictionary
var run: Dictionary = {} # 保留探索显示接口；友好委托永不进入切磋。
var dialog: Control
var idle: AnimatedSprite2D
var ground_shadows: Node2D
var gift_modal: Control
var join_overlay: Control
var talk_prompt: Control
var clue_prompt: Control
var clue_modal: Control
var clue_glow: Sprite2D
var glow_clock := 0.0
var glow_reveal := 0.0
var clock := 0.0
var retry := 0.0
var armed := true
var _locked := false
var _prior_lock := false
var _old_physics := true
var _presented := ""
var _gift_invalid := false
var _clue_visible := false

func attach(owner_maze: Node2D) -> void:
	maze = owner_maze
	process_priority = 10
	record = SaveManager.yufeng_salia_record()
	phase = record.phase
	idle = AnimatedSprite2D.new()
	idle.name = "SittingMapAnimation"
	var sequence := SpriteFrames.new()
	sequence.set_animation_speed("default",1.0)
	sequence.set_animation_loop("default",true)
	for i in FRAME_ORDER.size():
		sequence.add_frame("default",load("res://assets/characters/yufeng_salia_sitting/frame_%02d.png" % FRAME_ORDER[i]),FRAME_DURATIONS[i])
	idle.sprite_frames = sequence
	var fixed_material := ShaderMaterial.new()
	fixed_material.shader = preload("res://scripts/maze/yufeng_sitting_fixed.gdshader")
	fixed_material.set_shader_parameter("fixed_pose",load("res://assets/characters/yufeng_salia_sitting/frame_00.png"))
	idle.material = fixed_material
	idle.frame_changed.connect(_align_idle_eyes)
	_align_idle_eyes()
	idle.position = Story.Site.CHAT_FOOT
	idle.offset = Vector2(0,-232)
	idle.scale = Vector2.ONE * 0.24
	ground_shadows = Node2D.new()
	ground_shadows.name = "PairGroundShadows"
	ground_shadows.position = Story.Site.CHAT_FOOT
	add_child(ground_shadows)
	for foot_x in [0.0]:
		var shadow := Sprite2D.new()
		shadow.texture = preload("res://scripts/characters/hero_animation.gd").SHADOW
		shadow.scale = Vector2(1.2,0.45)
		shadow.position = Vector2(foot_x,-3)
		ground_shadows.add_child(shadow)
	# 宿主在主角之前绘制，使主角覆盖两人而非被遮住。
	idle.z_index = 0
	add_child(idle)
	idle.play()
	talk_prompt = WorldPrompt.new()
	maze._ui_root.add_child(talk_prompt)
	talk_prompt.configure("与御风和萨莉亚交谈",Story.Site.CHAT_FOOT+Vector2(0,-112))
	talk_prompt.activated.connect(try_interact)
	clue_prompt = WorldPrompt.new()
	maze._ui_root.add_child(clue_prompt)
	clue_prompt.configure("调查",Story.Frog.HOME+Vector2(0,4))
	clue_glow = Sprite2D.new()
	clue_glow.name = "PoolClueGlow"
	clue_glow.texture = preload("res://assets/props/story_clue/yellow_glow.png")
	clue_glow.position = Story.Frog.HOME+Vector2(0,-4)
	clue_glow.scale = Vector2.ONE*(280.0/1.35/clue_glow.texture.get_width())
	clue_glow.z_index = 0
	add_child(clue_glow)
	clue_prompt.activated.connect(try_interact)
	clue_modal = preload("res://scripts/ui/components/story_clue_modal.gd").new()
	maze._ui_root.add_child(clue_modal)
	clue_modal.closed.connect(_clue_closed)
	dialog = DialogScene.instantiate()
	maze._ui_root.add_child(dialog)
	dialog.hide_box()
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.finished.connect(_next)
	gift_modal = preload("res://scripts/ui/components/loot_modal.gd").new()
	maze._ui_root.add_child(gift_modal)
	gift_modal.closed.connect(_reward_closed)
	_gift_invalid = not IngredientGift.presentation_valid(SaveManager,phase) if phase in ["gift_pending","gift_reward","farewell","joined","fade"] else false
	if _gift_invalid:
		_lock()
		maze.show_toast("赠礼记录异常，已停止演出，请检查存档")
	elif phase == "clue":
		_lock()
		_show_clue()
	elif phase in ["intro","post","farewell"]:
		_lock()
		_show_line()
	elif phase in ["gift_pending","gift_reward","joined","fade"]: _lock()
	_sync_visuals()

func _lock() -> void:
	if _locked: return
	_prior_lock = maze.player.input_locked
	_old_physics = maze.player.is_physics_processing()
	_locked = true
	maze.player.input_locked = true
	maze.player.set_physics_process(false)
	maze.player.clear_combat_input()

func _unlock() -> void:
	if not _locked: return
	maze.player.input_locked = _prior_lock
	maze.player.set_physics_process(_old_physics)
	maze._interact_armed = false
	_locked = false

func _commit(next: String, line := 0) -> bool:
	var result := Story.advance(SaveManager,next,line,maze.player.position)
	if not result.success:
		maze.show_toast("剧情保存失败，已保留当前进度，请重试")
		retry = 1.0
		return false
	record = SaveManager.yufeng_salia_record()
	phase = record.phase
	clock = 0.0
	return true

func _show_line() -> void:
	var rows: Array = {"intro":Story.INTRO,"clue":Story.CLUE,"post":Story.POST,"farewell":Story.FAREWELL}[phase]
	var row: Array = rows[int(record.line)]
	var id: String = {"御风":"yufeng","萨莉亚":"salia"}.get(row[0],"")
	var portrait: Texture2D = null
	if row[0] != "":
		portrait = load("res://assets/characters/player_portrait.png" if id.is_empty() else "res://assets/characters/%s/%s_portrait.png" % [id,id])
	var style: StyleBoxFlat = dialog.portrait.get_theme_stylebox("panel").duplicate()
	style.bg_color = SproutTheme.CREAM
	dialog.portrait.add_theme_stylebox_override("panel",style)
	dialog.start(row[0],[row[1]],portrait)

func _next() -> void:
	if phase not in ["intro","clue","post","farewell"]: return
	var count: int = {"intro":Story.INTRO.size(),"clue":Story.CLUE.size(),"post":Story.POST.size(),"farewell":Story.FAREWELL.size()}[phase]
	var line := int(record.line)+1
	var next := phase
	if line >= count:
		next = {"intro":"investigate","clue":"report","post":"gift_pending","farewell":"joined"}[phase]
		line = 0
	if not _commit(next,line):
		_show_line()
		return
	if phase in ["intro","clue","post","farewell"]: _show_line()
	else:
		dialog.hide_box()
		if phase in ["investigate","report"]:
			_unlock()
			maze.show_toast("击败巨蛙后，调查池中央" if phase == "investigate" else "已发现线索，返回向御风回报")

func _available() -> bool:
	return maze._entry_ready and not maze.capture_flow.combat_paused() and not Run.portal_combat_locked(SaveManager) and retry <= 0

func try_interact() -> bool:
	if not _available(): return false
	if phase == "unseen" and _near_pair():
		GameAudio.interaction()
		if _commit("intro"):
			_lock()
			_show_line()
		return true
	if Story.can_inspect(SaveManager,maze.player.position):
		GameAudio.interaction()
		if _commit("clue"):
			_lock()
			_show_clue()
		return true
	if Story.can_report(SaveManager,maze.player.position):
		GameAudio.interaction()
		if _commit("post"):
			_lock()
			_show_line()
		return true
	return false

func _align_idle_eyes() -> void:
	var anchors: Array = EYE_ANCHORS[FRAME_ORDER[idle.frame]]
	idle.material.set_shader_parameter("left_eye_source",anchors[0])
	idle.material.set_shader_parameter("right_eye_source",anchors[1])

func _near_pair() -> bool:
	return maze.player.position.distance_to(Story.Site.CHAT_FOOT) <= 95 and maze.player.terrain.is_walkable(maze.player.position)

func _process(delta: float) -> void:
	if not is_instance_valid(maze): return
	if not maze.capture_flow.window_focused:
		idle.pause()
		dialog.set_process(false)
		talk_prompt.hide()
		clue_prompt.hide()
		return
	dialog.set_process(true)
	retry = maxf(0,retry-delta)
	if _gift_invalid: return
	glow_clock += delta
	if _clue_visible: glow_reveal = minf(1.0, glow_reveal + delta / 0.8)
	_gift_process(delta)
	_sync_visuals()

func _sync_visuals() -> void:
	idle.visible = phase != "done"
	idle.modulate.a = clampf(1.0-clock/0.7,0,1) if phase == "fade" else 1.0
	ground_shadows.visible = idle.visible
	ground_shadows.modulate.a = idle.modulate.a
	if idle.visible and maze.capture_flow.window_focused:
		if not idle.is_playing(): idle.play()
	else: idle.pause()
	var available := _available()
	talk_prompt.visible = available and ((phase == "unseen" and _near_pair()) or Story.can_report(SaveManager,maze.player.position))
	clue_prompt.visible = available and Story.can_inspect(SaveManager,maze.player.position)
	var show_clue: bool = phase == "investigate" and SaveManager.yufeng_salia_record().get("frog_defeated",false)
	if show_clue != _clue_visible:
		glow_reveal = 0.0
		glow_clock = 0.0
	_clue_visible = show_clue
	clue_glow.visible = _clue_visible
	clue_glow.modulate.a = smoothstep(0.0,1.0,glow_reveal)*(0.80+0.16*sin(TAU*glow_clock/3.2))

func _input(event: InputEvent) -> void:
	if _gift_invalid or not is_instance_valid(maze) or not maze.capture_flow.window_focused or phase not in ["intro","post","farewell"]: return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if not event.pressed: armed = true
		elif not event.echo and event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER] and armed:
			armed = false
			dialog._advance()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: dialog._advance()

func _reward_closed() -> void:
	if phase != "gift_reward": return
	if _commit("farewell"): _show_line()
	else: _presented = ""

func _joined_closed() -> void:
	if phase != "joined": return
	if _commit("fade"): join_overlay.cancel()
	else: join_overlay.show_error("保存失败，请再次确认")

func _gift_process(delta: float) -> void:
	if retry > 0: return
	if phase == "gift_pending":
		_lock()
		if not IngredientGift.grant(SaveManager).success:
			maze.show_toast("赠礼保存失败，尚未领取，请检查存档")
			retry = 1.0
			return
		record = SaveManager.yufeng_salia_record()
		phase = record.phase
	if phase == "gift_reward" and _presented != phase:
		_lock()
		var items: Array[Dictionary] = []
		for id in IngredientGift.ITEMS:
			items.append({"name":IngredientGift.Catalog.get_ingredient(id).name,"quantity":IngredientGift.ITEMS[id],"icon":IngredientGift.Catalog.item_texture(id)})
		gift_modal.show_items(items)
		_presented = phase
	elif phase == "joined" and _presented != phase:
		_lock()
		join_overlay = preload("res://scripts/ui/party_cards_overlay.gd").new()
		join_overlay.character_ids.assign(["yufeng","salia"])
		join_overlay.join_message = "御风、萨莉亚加入队伍"
		maze._ui_root.add_child(join_overlay)
		join_overlay.continue_requested.connect(_joined_closed)
		join_overlay.present()
		GameAudio.play_cue(&"party_join")
		_presented = phase
	elif phase == "fade":
		_lock()
		clock += delta
		if clock >= 0.7 and _commit("done"): _unlock()

func _exit_tree() -> void:
	if is_instance_valid(join_overlay): join_overlay.cancel()
	if is_instance_valid(maze) and is_instance_valid(maze.player): _unlock()

func _show_clue() -> void:
	clue_modal.show_modal("发现线索",str(Story.CLUE[0][1])+str(Story.CLUE[1][1]),"确认")

func _clue_closed() -> void:
	if phase != "clue": return
	if _commit("report"):
		_unlock()
		maze.show_toast("已发现线索，返回向御风回报")
	else:
		_show_clue.call_deferred()
