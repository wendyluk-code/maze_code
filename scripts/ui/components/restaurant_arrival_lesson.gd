extends CanvasLayer
## 首日首客教学。只持久化阅读阶段，不改变订单、份数和经营账务。
const KEY := "restaurant_arrival_lesson_v1"
const FRONT_LINE := "前台有顾客来了，快去接单吧。"
const CLOCK_LINE := "每天营业时间有限，在倒计时结束前完成所有订单吧！"
var flow: Node
var dialog: Control
var dim: ColorRect
var customer: Sprite2D
var customer_rect := Rect2()
var camera: Camera2D
var camera_before := {}
var order_id := ""
var phase := ""
var active := false
var moving := false
var retry: Callable
var motion: Tween
var _locked := false

func _ready() -> void:
	layer = 115
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://scripts/ui/tutorial_task_cutout.gdshader")
	dim.material = mask
	root.add_child(dim)
	dialog = preload("res://scenes/ui/dialog_box.tscn").instantiate()
	root.add_child(dialog)
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.finished.connect(_read_done)
	dialog.hide()
	hide()

func begin(front: Dictionary, actor: Sprite2D) -> void:
	customer = actor
	customer_rect = customer.get_rect()
	if customer.texture != null:
		var used := Rect2(customer.texture.get_image().get_used_rect())
		if customer.flip_h: used.position.x = customer.texture.get_width() - used.end.x
		if customer.flip_v: used.position.y = customer.texture.get_height() - used.end.y
		customer_rect = Rect2(customer_rect.position + used.position, used.size)
	order_id = str(front.id)
	active = true
	flow._arrival_tutorial_busy = true
	flow.hud._lock_player()
	_locked = true
	camera = get_viewport().get_camera_2d()
	camera_before = {"position":camera.global_position,"zoom":camera.zoom,"process":camera.is_processing(),"physics":camera.is_physics_processing(),"smoothing":camera.position_smoothing_enabled}
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	show()
	var saved: Dictionary = SaveManager._state.get(KEY,{})
	phase = str(saved.get("phase",""))
	if phase == "return":
		_return_to_player()
	elif phase in ["front","clock"]:
		_focus(actor.global_position)
	else:
		_save_phase("front",func(): _focus(actor.global_position))

func _save_phase(next: String, after: Callable) -> void:
	var before: Dictionary = SaveManager._state.duplicate(true)
	SaveManager._state[KEY] = {"phase":next,"order_id":order_id}
	if not SaveManager.save():
		SaveManager._state = before
		retry = func(): _save_phase(next,after)
		dialog.start("芽芽",["教学进度未保存，请重试。"],preload("res://assets/characters/yaya_portrait.png"))
		return
	retry = Callable()
	dialog.hide_box()
	phase = next
	after.call()

func _focus(point: Vector2) -> void:
	moving = true
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(camera,"global_position",point+Vector2(0,60),0.65)
	motion.tween_property(camera,"zoom",camera_before.zoom*1.25,0.65)
	await motion.finished
	if not active: return
	moving = false
	_show_line()

func _show_line() -> void:
	dialog.start("芽芽",[FRONT_LINE if phase=="front" else CLOCK_LINE],preload("res://assets/characters/yaya_portrait.png"))

func _read_done() -> void:
	if phase=="front": _save_phase("clock",_show_line)
	elif phase=="clock": _save_phase("return",_return_to_player)

func _return_to_player() -> void:
	moving = true
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(camera,"global_position",camera_before.position,0.65)
	motion.tween_property(camera,"zoom",camera_before.zoom,0.65)
	await motion.finished
	if not active: return
	moving = false
	_save_phase("done",_finish)

func _finish() -> void:
	flow._first_arrival_tutorial_done = true
	release()
	queue_free()

func _process(_delta: float) -> void:
	if not active: return
	if is_instance_valid(flow.hud.toast_label): flow.hud.toast_label.dismiss()
	var rect := Rect2()
	if phase=="front" and is_instance_valid(customer):
		rect = _customer_cutout()
	elif phase=="clock":
		var sign = flow.hud.find_child("RestaurantDaySign",true,false)
		if is_instance_valid(sign): rect = sign.details_label.get_global_rect().grow(5)
	var mask := dim.material as ShaderMaterial
	mask.set_shader_parameter("overlay_size",dim.size)
	mask.set_shader_parameter("ingredients_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))

func _customer_cutout() -> Rect2:
	var transform := dim.get_global_transform_with_canvas().affine_inverse() * customer.get_global_transform_with_canvas()
	return (transform * customer_rect).grow(10)

func _input(event: InputEvent) -> void:
	if not active: return
	get_viewport().set_input_as_handled()
	if not dialog._is_advance_event(event) or moving: return
	if retry.is_valid():
		var callback := retry
		retry = Callable()
		callback.call()
	elif dialog.visible: dialog._advance()

func release() -> void:
	if not active: return
	active = false
	if motion != null and motion.is_valid(): motion.kill()
	if is_instance_valid(camera):
		camera.global_position = camera_before.position
		camera.zoom = camera_before.zoom
		camera.position_smoothing_enabled = camera_before.smoothing
		camera.set_process(camera_before.process)
		camera.set_physics_process(camera_before.physics)
		camera.reset_smoothing()
	if is_instance_valid(flow):
		flow._arrival_tutorial_busy = false
		flow._elapsed = 0.0
		if _locked and is_instance_valid(flow.hud): flow.hud._unlock_player()
	_locked = false
	hide()

func _exit_tree() -> void:
	release()
