extends CharacterBody3D

const SPEED := 5.0
const INTERACT_RANGE := 2.0

var facing := Vector3.FORWARD

@onready var hud_label: Label = %HintLabel

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	)

	var cam := get_viewport().get_camera_3d()
	var cam_basis := cam.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := (right * input_dir.x + forward * input_dir.y).normalized()
	if dir.length() > 0:
		facing = dir
	velocity = dir * SPEED
	move_and_slide()

func _process(_delta: float) -> void:
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var target := nearest_interactable()
		if target:
			interact(target)

func nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

func interact(target: Node3D) -> void:
	print("[interact] ", target.name)
	hud_label.text = "与「%s」交互（开发中）" % target.name

func _update_hud() -> void:
	var best := nearest_interactable()
	if best:
		hud_label.text = "【E】与「%s」交互" % best.name
	else:
		hud_label.text = ""