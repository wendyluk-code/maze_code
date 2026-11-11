extends Node2D
const Face := preload("res://scripts/ui/components/customer_expression.gd")
const Bubble := preload("res://scripts/ui/components/customer_feedback_bubble.gd")
const Mark := preload("res://scripts/ui/components/customer_emotion_mark.gd")
const ROWS := {
	"front_timeout":["怎么没人招呼……","sad","confusion"],
	"drink_timeout":["水还没好吗……","impatient","confusion"],
	"timeout":["等太久了！","angry","anger"],
	"wrong_dish":["这不是我点的！","angry","anger"],
	"bad_drink":["这杯水不太对……","impatient","confusion"],
	"spoiled_drink":["这杯水冰过头了！","angry","anger"],
	"question":["咦，我没点水呀？","confused","question"]
}
var remaining := 2.2
var actor: Sprite2D
var text_bubble: Node2D
static func show_on(target: Sprite2D, customer: String, reason: String) -> void:
	clear(target)
	if not ROWS.has(reason): return
	var node := new()
	node.name = "CustomerFeedback"
	node.actor = target
	target.add_child(node)
	node.scale = Vector2.ONE/target.scale
	var row: Array = ROWS[reason]
	Face.apply(target,customer,row[1])
	var anchor := Bubble.new()
	# 评价文字须盖住所有顾客的点单气泡，不受人物创建顺序影响。
	anchor.z_as_relative = false
	anchor.z_index = 20
	node.text_bubble = anchor
	anchor.message = row[0]
	node.add_child(anchor)
	node.position = preload("res://scripts/ui/components/customer_head_anchor.gd").local_point(target)
	var mark := Mark.new()
	mark.kind = row[2]
	mark.position = Vector2(22,23)
	node.add_child(mark)
	target.get_node("OrderBubble").hide()
	node._layout_text()
static func clear(target: Sprite2D) -> void:
	var old := target.get_node_or_null("CustomerFeedback")
	if old != null:
		target.remove_child(old)
		old.queue_free()
	Face.clear(target)
func _process(delta: float) -> void:
	_layout_text()
	remaining -= delta
	if remaining <= 0: clear(actor)

func _layout_text() -> void:
	if not is_instance_valid(text_bubble): return
	# 节点和尖角留在头顶，只偏移绘制主体；避免避让牌子时尖角跟着横移。
	position = preload("res://scripts/ui/components/customer_head_anchor.gd").local_point(actor)
	text_bubble.position = Vector2.ZERO
	var transform := text_bubble.get_global_transform_with_canvas()
	var local_body: Rect2 = text_bubble.body_rect()
	var rect := Rect2(transform * local_body.position, local_body.size*transform.x.length())
	var screen := get_viewport_rect().size
	var shift := Vector2(clampf(rect.position.x,8,screen.x-rect.size.x-8)-rect.position.x, maxf(0,8-rect.position.y))
	rect.position += shift
	var reserved_regions := [Rect2(10,0,342,64),Rect2(screen.x*0.5-105,0,300,80)]
	for reserved in reserved_regions:
		if not rect.intersects(reserved): continue
		var dx: float = reserved.end.x+8-rect.position.x
		if rect.get_center().x < reserved.get_center().x and reserved.position.x-rect.size.x-8 >= 8:
			dx = reserved.position.x-8-rect.end.x
		shift.x += dx
		rect.position.x += dx
	text_bubble.body_offset = get_global_transform_with_canvas().affine_inverse().basis_xform(shift)
	# 顶部空间不足时把主体放到头部侧上方，从侧边连接固定尖角，避免裁字或自交。
	if text_bubble.body_offset.y > 1:
		var room_right: bool = transform.origin.x+(local_body.size.x+18)*transform.x.length()<screen.x-8
		text_bubble.body_offset.x = (local_body.size.x*0.5+18)*(1.0 if room_right else -1.0)
		# 侧放后重新避让完整营业牌（含右侧结束按钮）。
		for reserved in reserved_regions:
			var body := Rect2(transform*(local_body.position+text_bubble.body_offset),local_body.size*transform.x.length())
			if not body.intersects(reserved): continue
			var dx: float = reserved.end.x+8-body.position.x
			if body.end.x+dx>screen.x-8: dx = reserved.position.x-8-body.end.x
			text_bubble.body_offset += get_global_transform_with_canvas().affine_inverse().basis_xform(Vector2(dx,0))
	text_bubble.queue_redraw()
