extends "res://scripts/ui/components/restaurant_arrival_lesson.gd"
const DRINK_KEY := "ganlu_lessons_v1"
const LINES := {
	"warm":"点了甘露水的顾客会带来额外声望，快去小餐车倒甘露水给他吧！",
	"iced":"有的顾客喜欢喝加冰的甘露水，记得倒完甘露水后去冰柜冰镇一下再给他哦。",
	"ready":"甘露水冰镇好了，抓紧时间取出吧。",
	"spoiled":"甘露水冰过头了，顾客喝了会拉肚子。交给顾客会扣金币和声望，还是扔掉吧。"}
var kind := ""
var target: Node2D
var freezer_slot := -1

func begin_lesson(owner_flow: Node, lesson_kind: String, subject: Node2D, slot := -1) -> void:
	flow = owner_flow
	kind = lesson_kind
	if kind in ["warm","iced"]:
		(dim.material as ShaderMaterial).shader = preload("res://scripts/ui/ganlu_bubble_cutout.gdshader")
	target = subject
	freezer_slot = slot
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
	var point := target.global_position
	if kind=="ready": point = target.to_global(target.slot_position(slot))
	_focus(point)

func _show_line() -> void:
	dialog.start("芽芽",[LINES[kind]],preload("res://assets/characters/yaya_portrait.png"))

func _read_done() -> void:
	if moving or not active: return
	var before: Dictionary = SaveManager._state.duplicate(true)
	var flags: Dictionary = SaveManager._state.get(DRINK_KEY,{}).duplicate()
	flags[kind] = true
	SaveManager._state[DRINK_KEY] = flags
	if not SaveManager.save():
		SaveManager._state = before
		dialog.start("芽芽",["教学进度未保存，请重试。"],preload("res://assets/characters/yaya_portrait.png"))
		return
	moving = true
	dialog.hide_box()
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(camera,"global_position",camera_before.position,0.65)
	motion.tween_property(camera,"zoom",camera_before.zoom,0.65)
	await motion.finished
	release()
	queue_free()

func _process(_delta: float) -> void:
	if not active or not is_instance_valid(target): return
	flow.hud.toast_label.dismiss()
	var rect := Rect2()
	var extra := Rect2()
	if kind in ["warm","iced"]:
		var bubble = target.get_node("OrderBubble")
		rect = bubble.get_global_transform_with_canvas()*Rect2(-42,-90,84,89)
		var bubble_mask := dim.material as ShaderMaterial
		bubble_mask.set_shader_parameter("overlay_size",dim.size)
		bubble_mask.set_shader_parameter("bubble_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
		return
	elif kind=="ready":
		var local := Rect2(target.slot_position(freezer_slot)-Vector2(22,52),Vector2(44,58))
		local = local.merge(target.thermometer_rect(freezer_slot))
		rect = target.get_global_transform_with_canvas()*local
		extra = target.prompts[freezer_slot].get_global_rect()
	else:
		rect = target.get_global_transform_with_canvas()*Rect2(-60,-115,120,130)
		# 道具原按钮在输入锁下隐藏；教学使用相同组件展示E，不接受点击。
		if not has_meta("trash_prompt"):
			var prompt := preload("res://scenes/ui/interact_button.tscn").instantiate()
			get_child(0).add_child(prompt)
			prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			set_meta("trash_prompt",prompt)
		var prompt: Control = get_meta("trash_prompt")
		prompt.position = Vector2(rect.get_center().x-70,rect.position.y-46)
		prompt.get_node("Content/ActionLabel").text = "丢弃"
		extra = prompt.get_global_rect()
	var mask := dim.material as ShaderMaterial
	mask.set_shader_parameter("overlay_size",dim.size)
	mask.set_shader_parameter("ingredients_rect",Vector4(rect.position.x-6,rect.position.y-6,rect.size.x+12,rect.size.y+12))
	mask.set_shader_parameter("cooking_rect",Vector4(extra.position.x,extra.position.y,extra.size.x,extra.size.y))
