extends CanvasLayer
var hud: Node
var dim: ColorRect
var dialog: Control

func _ready() -> void:
	layer = 115
	add_to_group("preparation_lesson")
	hud._lock_player()
	hud.toast_label.dismiss()
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
	dialog.finished.connect(_finish)
	dialog.start("芽芽",["当完成一天的营业后，会进入第二天的准备时间。在倒计时结束前，努力探索迷宫带回更多料理吧！"],preload("res://assets/characters/yaya_portrait.png"))

func _process(_delta: float) -> void:
	var sign = hud.find_child("RestaurantDaySign",true,false)
	if not is_instance_valid(sign): return
	var rect: Rect2 = sign.details_label.get_global_rect().grow(6)
	dim.material.set_shader_parameter("overlay_size",dim.size)
	dim.material.set_shader_parameter("ingredients_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))

func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if dialog._is_advance_event(event): dialog._advance()

func _finish() -> void:
	var before: Dictionary = SaveManager._state.duplicate(true)
	SaveManager._state["preparation_lesson_seen"] = true
	SaveManager._state["restaurant_day_v1"].erase("preparation_lesson_pending")
	if not SaveManager.save():
		SaveManager._state = before
		dialog.start("芽芽",["教学进度保存失败，请重试。"],preload("res://assets/characters/yaya_portrait.png"))
		return
	hud._unlock_player()
	queue_free()
