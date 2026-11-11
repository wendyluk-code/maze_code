extends CanvasLayer
## 仓库首次快捷取料教学；保留仓库自身的输入锁。
const KEY := "warehouse_quick_lesson_seen"
const LINE := "可以通过“快速选择”，取出当前顾客点单所需的食材哦。"
var warehouse: Control
var dim: ColorRect
var dialog: Control
var flow: Node
var previous_busy := false

func _ready() -> void:
	layer = 115
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	if is_instance_valid(hud):
		flow = hud.customer_flow
		previous_busy = flow.busy
		flow.busy = true
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
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.finished.connect(_finish)
	dialog.start("芽芽",[LINE],preload("res://assets/characters/yaya_portrait.png"))

func _process(_delta: float) -> void:
	if not is_instance_valid(warehouse) or not warehouse.visible:
		queue_free()
		return
	var rect: Rect2 = warehouse._quick_panel.get_global_rect()
	dim.material.set_shader_parameter("overlay_size",dim.size)
	dim.material.set_shader_parameter("ingredients_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))

func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if dialog._is_advance_event(event): dialog._advance()

func _finish() -> void:
	var before: Dictionary = SaveManager._state.duplicate(true)
	SaveManager._state[KEY] = true
	if not SaveManager.save():
		SaveManager._state = before
		dialog.start("芽芽",["教学进度保存失败，请重试。"],preload("res://assets/characters/yaya_portrait.png"))
		return
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(flow): flow.busy = previous_busy
