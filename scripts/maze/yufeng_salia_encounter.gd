extends Node2D
## 分水庭双人事件；赠礼先提交，演出逐阶段持久化。
const Bento = preload("res://scripts/restaurant/bento_store.gd")
const FAREWELL := [["御风","放你便当盒了，自己看看怎么用。……走了。"],["萨莉亚","抱歉小可爱，就当是他的赔礼吧~ 以后有机会再见哟。"]]
const Sim = preload("res://scripts/maze/yf_sparring.gd")
const Run = preload("res://scripts/maze/capture_run.gd")
const DialogScene = preload("res://scenes/ui/dialog_box.tscn")
const Monster = preload("res://scripts/maze/capture_monster.gd")
const INTRO := [
 ["萨莉亚","……不管怎样，先去西边小屋调查……"],
 ["御风","嘘，有人来了——谁？"],
 ["主角","……我只是路过。"],
 ["御风","你都听到了什么？"],
 ["主角","没有。请问盐池怎么走？"],
 ["御风","（警觉）盐池？你去盐池干什么？"],
 ["萨莉亚","御风，别激动，他们可能不是……"],
 ["御风","不能放过任何一丝线索。想去盐池，先让我看看你的本事！"]]
const POST := [["御风","等等，你连回复料理都没带？"],["主角","料理还能这么用？"],["御风","……啧。算了，这些给你。"]]
var gift_modal: Control
var unlock_modal: Control
var _presented := ""
var _gift_invalid := false
var maze: Node2D
var phase := "unseen"
var record: Dictionary
var run: Dictionary={}
var dialog: Control
var idle: AnimatedSprite2D
var actors: Dictionary={}
var bars: Dictionary={}
var shots: Array[Sprite2D]=[]
var hit_sprite: Sprite2D
var curtain: ColorRect
var clock := 0.0
var retry := 0.0
var armed := true
var _locked := false
var _prior_lock := false
var _old_physics := true
var textures: Dictionary={}
var bounds: Dictionary={}
var attention := Vector2.ZERO

func attach(owner_maze: Node2D) -> void:
	maze=owner_maze
	bounds=JSON.parse_string(FileAccess.get_file_as_string("res://data/maze/yf_sprite_layout.json"))
	process_priority=10
	record=SaveManager.yufeng_salia_record()
	phase=record.phase
	_gift_invalid=not Bento.presentation_valid(SaveManager,phase) if phase in ["gift_pending","gift_reward","bento_unlock","bento_fly","farewell","fade"] else false
	for directory in ["01_yufeng_sword","02_wind_blade","03_salia_cast","04_lightning_orb","05_lightning_chain","06_lightning_hit"]:
		var frames: Array=[]
		for i in (6 if directory in ["01_yufeng_sword","03_salia_cast"] else 4):
			var source_directory: String="03_salia_cast_side" if directory=="03_salia_cast" else directory
			frames.append(load("res://assets/characters/yf02/%s/frame_%02d.png" % [source_directory,i]))
		textures[directory]=frames
	idle=AnimatedSprite2D.new()
	var sequence := SpriteFrames.new()
	for i in 6: sequence.add_frame("default",load("res://assets/characters/yf02/idle/style_v5_frame_%02d.png" % i))
	sequence.set_animation_speed("default",3)
	idle.sprite_frames=sequence
	idle.position=Sim.Site.CHAT_FOOT
	idle.scale=Vector2.ONE*(88.0/481.0)
	idle.offset=Vector2(0,-256)
	idle.z_index=4
	add_child(idle)
	idle.stop()
	for id in Sim.POSITIONS:
		var body := Sprite2D.new()
		body.position=Sim.POSITIONS[id]
		body.offset=Vector2(0,-208)
		body.scale=Vector2.ONE*0.38/maze.camera.zoom.y
		body.z_index=4
		body.texture=textures["01_yufeng_sword" if id=="yufeng" else "03_salia_cast"][0]
		add_child(body)
		actors[id]=body
		var label := Label.new()
		label.text="御风" if id=="yufeng" else "萨莉亚"
		label.add_theme_font_size_override("font_size",12)
		label.add_theme_color_override("font_color",SproutTheme.CREAM)
		label.add_theme_color_override("font_outline_color",SproutTheme.INK)
		label.add_theme_constant_override("outline_size",2)
		label.position=Sim.POSITIONS[id]+Vector2(-20 if id=="yufeng" else -65,-100)
		label.z_index=5
		add_child(label)
		var bar := Monster.make_health_bar(Color("d96b60"))
		bar.position=Vector2(0,21)
		label.add_child(bar)
		bars[id]=bar
	hit_sprite=Sprite2D.new()
	hit_sprite.z_index=7
	hit_sprite.scale=Vector2.ONE*0.18
	add_child(hit_sprite)
	dialog=DialogScene.instantiate()
	maze._ui_root.add_child(dialog)
	dialog.hide_box()
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dialog.finished.connect(_next)
	curtain=ColorRect.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color=Color(0.025,0.035,0.04,0)
	curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	maze._ui_root.add_child(curtain)
	gift_modal=preload("res://scripts/ui/components/loot_modal.gd").new()
	gift_modal.item_row_height=106
	maze._ui_root.add_child(gift_modal)
	gift_modal.closed.connect(_reward_closed)
	attention=maze.player.position
	if phase in ["eat","question"]:
		_lock()
		if _commit("battle"): _start_battle()
	elif phase=="battle": _start_battle()
	elif phase in ["intro","question","post","farewell"] and not _gift_invalid:
		_lock()
		_show_line()
	elif phase in ["eat","gift_pending","gift_reward","bento_unlock","bento_fly","fade"]: _lock()
	if _gift_invalid:
		_lock()
		maze.show_toast("赠礼记录异常，已停止演出，请检查存档")
	_sync_visuals()

func _lock() -> void:
	armed=true
	if _locked: return
	_prior_lock=maze.player.input_locked
	_old_physics=maze.player.is_physics_processing()
	_locked=true
	maze.player.input_locked=true
	maze.player.set_physics_process(false)
	maze.player.clear_combat_input()

func _unlock() -> void:
	if not _locked: return
	maze.player.input_locked=_prior_lock
	maze.player.set_physics_process(_old_physics)
	_locked=false

func _commit(next: String, line: int = 0) -> bool:
	var candidate := record.duplicate(true)
	candidate.phase=next
	candidate.line=line
	if next=="battle":
		candidate.start_run=Run.snapshot(SaveManager)
		candidate.start_position=Sim.Skills.pack(maze.player.position)
	if next in ["post","gift_pending"]: candidate.erase("start_run")
	if not SaveManager.set_yufeng_salia_record(candidate).success:
		maze.show_toast("剧情保存失败，已保留当前进度，请重试")
		retry=1.0
		return false
	record=candidate
	phase=next
	clock=0.0
	return true

func _show_line() -> void:
	var row: Array=INTRO[mini(int(record.line),INTRO.size()-1)] if phase=="intro" else (POST[mini(int(record.line),POST.size()-1)] if phase=="post" else FAREWELL[mini(int(record.line),1)])
	if phase=="farewell": row=FAREWELL[mini(int(record.line),1)]
	var id: String={"御风":"yufeng","萨莉亚":"salia"}.get(row[0],"")
	var path := "res://assets/characters/player_portrait.png" if id.is_empty() else "res://assets/characters/%s/%s_portrait.png" % [id,id]
	var portrait: Texture2D=load(path)
	var portrait_style: StyleBoxFlat=dialog.portrait.get_theme_stylebox("panel").duplicate()
	portrait_style.bg_color=SproutTheme.CREAM
	dialog.portrait.add_theme_stylebox_override("panel",portrait_style)
	dialog.start(row[0],[row[1]],portrait)

func _next() -> void:
	var next := phase
	var line := int(record.line)+1
	if phase=="intro" and line>=INTRO.size():
		next="battle"
		line=0
	elif phase=="question":
		next="battle"
		line=0
	elif phase=="post" and line>=POST.size():
		next="gift_pending"
		line=0
	elif phase=="farewell" and line>=2:
		next="fade"
		line=0
	if not _commit(next,line):
		_show_line()
		return
	if phase in ["intro","post","farewell"]: _show_line()
	elif phase=="battle": _start_battle()
	elif phase=="gift_pending": _lock()

func _start_battle() -> void:
	var source: Dictionary=record.get("start_run",Run.snapshot(SaveManager))
	run=Sim.create(source)
	Sim.Skills.sync_levels(run,SaveManager)
	maze.player.position=Sim.Skills.vec(record.start_position)
	_unlock()
	dialog.hide_box()

func attack(aim: Vector2) -> void:
	Sim.attack(run,maze.player.position,aim)

func _process(delta: float) -> void:
	if not is_instance_valid(maze): return
	var focused: bool=maze.capture_flow.window_focused
	if not focused:
		idle.pause()
		dialog.set_process(false)
		return
	dialog.set_process(true)
	retry=maxf(0,retry-delta)
	if phase=="unseen":
		if maze._entry_ready and not maze.capture_flow.combat_paused() and Sim.Site.should_trigger(maze.player.position) and retry<=0:
			if _commit("intro"):
				attention=maze.player.position
				_lock()
				_show_line()
	elif phase in ["eat","question"] and retry<=0:
		if _commit("battle"): _start_battle()
	elif phase=="battle" and (run.combat.lock_left==0 or not maze.capture_flow.combat_paused()):
		if run.combat.lock_left==0: _lock()
		var remaining := minf(delta,0.1)
		while remaining>0:
			var step := minf(0.01,remaining)
			maze.player.position=Sim.advance(run,maze.player.position,step,maze.player.sprinting)
			remaining-=step
		if run.combat.lock_left==0:
			_lock()
			clock+=delta
			curtain.color.a=clampf(clock/0.28,0,1)
			if clock>=0.28 and retry<=0 and _commit("post"):
				_lock()
				_show_line()
	elif phase=="post":
		curtain.color.a=maxf(0,curtain.color.a-delta/0.34)
	_gift_process(delta)
	_sync_visuals()

func _sync_visuals() -> void:
	idle.visible=phase=="unseen"
	if idle.visible and maze.capture_flow.window_focused:
		if not idle.is_playing(): idle.play()
	else: idle.pause()
	for id in actors:
		var body: Sprite2D=actors[id]
		body.visible=phase not in ["unseen","done"]
		bars[id].get_parent().visible=phase=="battle"
		var at: Vector2=Sim.POSITIONS[id]
		var target: Vector2=Sim.POSITIONS["salia" if id=="yufeng" else "yufeng"] if phase=="unseen" else maze.player.position
		var texture: Texture2D=load("res://assets/characters/%s/%s_idle_0.png" % [id,id])
		if phase=="battle":
			var actor: Dictionary=run.combat.actors[id]
			at=Sim.Skills.vec(actor.position)
			target=maze.player.position
			bars[id].max_value=actor.max_hp
			bars[id].value=actor.hp
			if actor.cast>0:
				texture=textures["01_yufeng_sword" if id=="yufeng" else "03_salia_cast"][clampi(int((0.48-actor.cast)/0.08),0,5)]
			elif actor.get("moving",false):
				texture=load("res://assets/characters/%s/%s_walk_%d.png" % [id,id,int(run.combat.elapsed*6)%4])
			if body.material==null:
				body.material=ShaderMaterial.new()
				body.material.shader=preload("res://scripts/maze/hit_flash.gdshader")
			body.material.set_shader_parameter("flash",actor.get("flash",0)>0)
		elif body.material!=null: body.material.set_shader_parameter("flash",false)
		pose(body,texture,at,80.0 if id=="yufeng" else 88.0)
		body.flip_h=target.x<at.x
		body.modulate.a=maxf(0,1.0-clock/0.7) if phase=="fade" else 1.0
		# 呼吸幅度小于一个世界像素，脚底保持不动。
		if phase!="battle": body.scale.y*=1.0+sin(Time.get_ticks_msec()/750.0)*0.004
		bars[id].get_parent().position=at+Vector2(-24,-99 if id=="salia" else -91)
	hit_sprite.visible=phase=="battle" and not run.combat.lightning_hits.is_empty() if not run.is_empty() else false
	if hit_sprite.visible:
		var hit: Dictionary=run.combat.lightning_hits.back()
		hit_sprite.texture=textures["06_lightning_hit"][clampi(int((0.24-hit.left)/0.06),0,3)]
		hit_sprite.position=Sim.Skills.vec(hit.position)+Vector2(0,-30)
	var rows: Array=run.combat.enemy_shots if phase=="battle" else []
	while shots.size()<rows.size():
		var sprite := Sprite2D.new()
		sprite.z_index=6
		add_child(sprite)
		shots.append(sprite)
	for i in shots.size():
		shots[i].visible=i<rows.size()
		if i>=rows.size(): continue
		var row: Dictionary=rows[i]
		shots[i].texture=textures["02_wind_blade" if row.source=="yufeng" else "04_lightning_orb"][int(run.combat.elapsed*12)%4]
		shots[i].position=Sim.Skills.vec(row.position)+Vector2(0,-30)
		shots[i].scale=Vector2.ONE*0.15
		shots[i].rotation=Sim.Skills.vec(row.direction).angle()

func _input(event: InputEvent) -> void:
	if _gift_invalid: return
	if is_instance_valid(maze) and maze.capture_flow.window_focused and phase=="bento_unlock" and is_instance_valid(unlock_modal) and unlock_modal.visible:
		get_viewport().set_input_as_handled()
		var pressed: bool=(event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER]) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT)
		if pressed and Bento.unlocked(SaveManager) and _commit("bento_fly"):
			_presented="bento_fly"
			unlock_modal.collect_into(maze.bento_entry)
		return
	if not is_instance_valid(maze) or not maze.capture_flow.window_focused or phase not in ["intro","eat","question","post","farewell"]: return
	get_viewport().set_input_as_handled()
	if phase=="eat": return
	if event is InputEventKey:
		if not event.pressed:
			armed=true
		elif not event.echo and event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER] and armed:
			armed=false
			dialog._advance()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: dialog._advance()

func _exit_tree() -> void:
	if is_instance_valid(maze): _unlock()

func _reward_closed() -> void:
	if phase!="gift_reward": return
	if not _commit("bento_unlock"): _presented=""

func _make_unlock() -> void:
	if is_instance_valid(unlock_modal): unlock_modal.queue_free()
	unlock_modal=preload("res://scripts/ui/components/backpack_reward.gd").new()
	unlock_modal.custom_texture=preload("res://scripts/ui/components/bento_modal.gd").entry_texture()
	unlock_modal.custom_title="[center]解锁[color=#e8ba62]【便当盒】[/color][/center]"
	maze._ui_root.add_child(unlock_modal)
	unlock_modal.collected.connect(_fly_finished)
	unlock_modal.show()

func _fly_finished() -> void:
	if phase!="bento_fly": return
	if not _commit("farewell"):
		_presented=""
		return
	unlock_modal.hide()
	_show_line()

func _gift_process(delta: float) -> void:
	if _gift_invalid: return
	if retry>0: return
	if phase=="gift_pending":
		_lock()
		var result := Bento.grant(SaveManager)
		if not result.success:
			maze.show_toast("赠礼保存失败，尚未领取，请检查存档")
			retry=1.0
			return
		record=SaveManager.yufeng_salia_record()
		phase=record.phase
	if phase=="gift_reward" and _presented!=phase:
		_lock()
		var items: Array[Dictionary]=[]
		for slot in Bento.GIFTS:
			var id: String=Bento.GIFTS[slot]
			items.append({"name":Bento.Catalog.get_recipe(id).name,"quantity":1,"icon":Bento.Catalog.item_texture(id)})
		gift_modal.show_items(items)
		_presented=phase
	elif phase=="bento_unlock":
		_lock()
		if _presented!=phase:
			_make_unlock()
			_presented=phase
		# 蒙层已实际进入场景并显示，随后提交入口资格；失败不允许收取。
		if not Bento.unlocked(SaveManager):
			if not Bento.reveal(SaveManager).success:
				retry=1.0
				maze.show_toast("解锁保存失败，请检查存档")
	elif phase=="bento_fly" and _presented!=phase:
		_lock()
		_make_unlock()
		_presented=phase
		unlock_modal.collect_into(maze.bento_entry)
	elif phase=="fade":
		_lock()
		clock+=delta
		idle.modulate.a=maxf(0,1.0-clock/0.7)
		if clock>=0.7 and _commit("done"):
			_unlock()

func pose(body: Sprite2D, texture: Texture2D, foot: Vector2, height: float) -> void:
	var key := texture.resource_path
	var layout: Dictionary=bounds[key]
	var values: Array=layout.rect
	var rect := Rect2i(values[0],values[1],values[2],values[3])
	body.texture=texture
	body.region_enabled=true
	body.region_rect=Rect2(rect)
	body.centered=true
	body.offset=Vector2(0,-rect.size.y/2.0)
	if layout.has("foot"):
		body.offset=Vector2(rect.size)*0.5-Vector2(layout.foot[0],layout.foot[1])
	body.scale=Vector2.ONE*height/float(layout.height)
	body.position=foot
