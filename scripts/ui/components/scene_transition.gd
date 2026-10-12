extends CanvasLayer
## 跨地图共用渐隐渐显：遮罩挂场景树根节点，旧场景释放后仍负责揭幕和恢复输入。
const GROUP := "scene_transition"
const FADE_OUT_SECONDS := 0.28
const FADE_IN_SECONDS := 0.34
var curtain: ColorRect
var phase := "fade_out"
var _locked_actors: Array[Dictionary] = []

static func is_active(tree: SceneTree) -> bool:
	return is_instance_valid(tree.get_first_node_in_group(GROUP))

static func change_scene(tree: SceneTree, destination: PackedScene) -> Error:
	if is_active(tree):
		return ERR_BUSY
	if destination == null:
		return ERR_INVALID_PARAMETER
	var overlay = load("res://scripts/ui/components/scene_transition.gd").new()
	tree.root.add_child(overlay)
	return await overlay._switch(destination)

func _ready() -> void:
	name = "SceneTransition"
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	curtain = ColorRect.new()
	curtain.name = "Curtain"
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color(0.025, 0.035, 0.04, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)

func _switch(destination: PackedScene) -> Error:
	_lock_players()
	await _fade_to(1.0, FADE_OUT_SECONDS)
	phase = "covered"
	# 先完整绘制一帧遮罩，再换图；包括无头模式也不依赖渲染信号。
	await get_tree().process_frame
	var error := get_tree().change_scene_to_packed(destination)
	if error == OK:
		await get_tree().scene_changed
		_lock_players()
		# 新图相机、人物动画、延迟注册的交互点先就绪，再揭幕。
		await get_tree().process_frame
	phase = "fade_in"
	await _fade_to(0.0, FADE_IN_SECONDS)
	phase = "finished"
	_restore_players()
	queue_free()
	return error

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(curtain, "color:a", alpha, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _lock_players() -> void:
	for group in ["player", "maze_player"]:
		for actor in get_tree().get_nodes_in_group(group):
			if _locked_actors.any(func(state): return is_instance_valid(state.actor) and state.actor == actor):
				continue
			_locked_actors.append({"actor": actor, "locked": actor.input_locked, "physics": actor.is_physics_processing()})
			actor.input_locked = true
			actor.set_physics_process(false)

func _restore_players() -> void:
	for state in _locked_actors:
		if is_instance_valid(state.actor):
			state.actor.input_locked = state.locked
			state.actor.set_physics_process(state.physics)
	_locked_actors.clear()

func _input(_event: InputEvent) -> void:
	# 键盘、鼠标和手柄均由遮罩消费，避免点击背后按钮或连按E二次转场。
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_restore_players()
