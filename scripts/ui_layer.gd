extends CanvasLayer
## 屏幕层 InteractionUI：每个可交互道具一个按钮（独立 Control）
## - 每个按钮绑定自己的 target_interactable（世界节点）
## - 每帧：target.global_position → 相机世界→屏幕投影 → 设置 Control.position
## - position 来源只有 target 与 Camera2D，绝不使用 Player 坐标
## - 按钮在 CanvasLayer，尺寸是屏幕像素（140×48 等），Camera2D.zoom 只影响位置投影、不影响尺寸与字体

const BUTTON_SCENE := preload("res://scenes/ui/interact_button.tscn")
const TOP_GAP := 8.0
const BUTTON_HEIGHT := 48.0

@export var interaction_distance: float = 95.0

## interactable 节点 -> 对应按钮 Control
var _buttons := {}
var _hiding := false
var player: Node2D = null

func _ready() -> void:
	add_to_group("ui_layer")
	var departure_panel := Control.new()
	departure_panel.name = "DeparturePanel"
	departure_panel.set_script(load("res://scripts/ui/departure_panel.gd"))
	add_child(departure_panel)
	player = get_tree().get_first_node_in_group("player") as Node2D
	call_deferred("_rebuild_buttons")

func _rebuild_buttons() -> void:
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node2D
		if node == null or _buttons.has(node):
			continue
		var btn: Control = BUTTON_SCENE.instantiate()
		btn.visible = false
		add_child(btn)   # CanvasLayer 下，屏幕空间
		var act := "交互"
		if node.has_method("get") and "display_name" in node:
			var v = node.get("display_name")
			if v is String and not v.is_empty():
				act = action_for(v)
		btn.get_node("Content/ActionLabel").text = act
		var content_w: float = btn.get_node("Content").get_combined_minimum_size().x
		btn.size = Vector2(maxf(140.0, content_w + 24.0), BUTTON_HEIGHT)
		btn.set_meta("target", node)
		_buttons[node] = btn

func _process(_delta: float) -> void:
	# 教学对话框/过场时隐藏；其余时刻按各自 target 的交互距离显示
	var tm := get_node_or_null("/root/TutorialManager")
	var hiding := false
	if tm and tm.active and tm.idx < tm.steps.size():
		var st: Dictionary = tm.steps[tm.idx]
		if st.get("type", "") == "dialog" or st.get("type", "") == "cutscene_guest":
			hiding = true
	if hiding != _hiding:
		_hiding = hiding
		for b in _buttons.values():
			if hiding and is_instance_valid(b):
				b.visible = false
	if hiding:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	# 每帧更新每个按钮位置：target 世界坐标 → 相机投影 → 屏幕
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var zone := get_tree().get_first_node_in_group("walk_zone")
	var vp := get_viewport().get_visible_rect().size
	var selected: Node2D = player.nearest_interactable() if is_instance_valid(player) else null
	var warehouse_modal := get_tree().get_first_node_in_group("warehouse_modal")
	var departure_panel := get_tree().get_first_node_in_group("departure_panel")
	if (is_instance_valid(warehouse_modal) and warehouse_modal.visible) or (is_instance_valid(departure_panel) and departure_panel._open):
		_hiding = true
		for b in _buttons.values():
			if is_instance_valid(b):
				b.visible = false
		return
	# Clear every button before enabling the one chosen by the same selector used by E.
	# This prevents a frame of overlap when the player crosses between targets.
	for node in _buttons.keys():
		var btn: Control = _buttons[node]
		if not is_instance_valid(btn) or not is_instance_valid(node):
			continue
		btn.visible = false
		if "display_name" in node:
			btn.get_node("Content/ActionLabel").text = action_for(str(node.display_name))
		_place_button(btn, node, cam, zone, vp)
	if is_instance_valid(selected):
		var selected_button: Control = _buttons.get(selected)
		if is_instance_valid(selected_button):
			selected_button.visible = true

func is_target_in_interaction_range(target: Node2D) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(target):
		return false
	if not player.has_method("interaction_distance_to"):
		return false
	return player.interaction_distance_to(target) <= interaction_distance

## 世界坐标 → 屏幕：仅用于定位，按钮尺寸始终为屏幕像素
func _place_button(btn: Control, node: Node2D, cam: Camera2D, zone: Node, vp: Vector2) -> void:
	var anchor: Vector2 = node.global_position
	if zone != null and zone.has_method("top_anchor_of"):
		var top: Vector2 = zone.top_anchor_of(anchor)
		if top != Vector2.ZERO:
			anchor = top
	if node.has_method("get") and "ui_offset" in node:
		var off = node.get("ui_offset")
		if off is Vector2:
			anchor += off
	var screen: Vector2 = get_viewport().get_canvas_transform() * anchor
	var extra_x := 0.0
	if node.has_method("get") and "display_name" in node:
		if node.get("display_name") == "魔法汤锅":
			extra_x = -70.0
	btn.position = screen + Vector2(-btn.size.x * 0.5 + extra_x, -TOP_GAP)

func action_for(display_name: String) -> String:
	match display_name:
		"魔法汤锅":
			return "烹饪"
		"小餐车":
			return "补货料理"
		"冰柜":
			return "存取食材"
		"吧台":
			return "上菜"
		"前台":
			var tm := get_node_or_null("/root/TutorialManager")
			if tm != null and tm.active and tm.current_stage == 6:
				return "交单上菜"
			return "点单"
		"仓库":
			if SaveManager.has_first_order_settlement():
				return "查看库存"
			return "取货"
		"迷宫入口":
			return "查看出发准备"
		_:
			return display_name
