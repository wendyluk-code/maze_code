extends "res://scripts/ui/components/customer_order_bubble.gd"
## 普通营业专用，铁山继续使用原气泡。
var selected := false
var question := false
var remaining := 60.0
var total := 60.0
var ingredients: Dictionary = {}
var red := StyleBoxFlat.new()
var keycap := StyleBoxFlat.new()
var font: Font = preload("res://assets/ui/game_font.tres")
var order_visible := false
var _body_rects: Dictionary = {}
var front := false
var warning := false

func setup_order(order: Dictionary) -> void:
	setup(str(order.item_id))
	drink = order.get("stage") == "drink"
	front = order.get("stage") == "front"
	food = not drink and not front
	ice = int(order.get("drink_ice", 0))
	remaining = float(order.get("remaining", 60))
	total = 40.0 if drink or front else 100.0
	warning = remaining <= total * 0.2
	ingredients = Recipes.get_recipe(item_id).get("ingredients", {}) if food else {}
	queue_redraw()

func follow(actor: Sprite2D) -> void:
	super.follow(actor)
	position = preload("res://scripts/ui/components/customer_head_anchor.gd").local_point(actor)
	scale *= 0.72
	# 跟随真实头顶，不把屏外顾客的提示钳在屏幕上；隐藏时仍更新。
	var key: String = actor.texture.atlas.resource_path + str(actor.texture.region)
	if not _body_rects.has(key):
		var pixels := actor.texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		_body_rects[key] = Rect2(pixels.get_used_rect())
	var body: Rect2 = _body_rects[key]
	if actor.flip_h: body.position.x = actor.texture.get_width()-body.end.x
	if actor.flip_v: body.position.y = actor.texture.get_height()-body.end.y
	body.position += actor.get_rect().position
	visible = order_visible and actor.is_visible_in_tree() and actor.modulate.a>0.01 and get_viewport_rect().intersects(actor.get_global_transform_with_canvas()*body)

func _draw() -> void:
	panel.border_color = Color("cc5545") if warning else (Color("e2b34f") if selected else Color("a77d54"))
	panel.set_border_width_all(3 if selected else 2)
	# 主体、圆角与尖角共用闭合轮廓，警戒填色不会留下接缝横线。
	var outline := PackedVector2Array()
	for corner in [Vector3(34,-82,-90),Vector3(34,-20,0)]:
		for step in range(7):
			outline.append(Vector2(corner.x,corner.y)+Vector2.from_angle(deg_to_rad(corner.z+step*15))*8)
	outline.append_array(PackedVector2Array([Vector2(8,-12),Vector2(0,-1),Vector2(-8,-12)]))
	for corner in [Vector3(-34,-20,90),Vector3(-34,-82,180)]:
		for step in range(7):
			outline.append(Vector2(corner.x,corner.y)+Vector2.from_angle(deg_to_rad(corner.z+step*15))*8)
	var background := panel.bg_color.lerp(Color("dc7770"),0.65+sin(Time.get_ticks_msec()/180.0)*0.25) if warning else panel.bg_color
	draw_colored_polygon(outline,background)
	outline.append(outline[0])
	draw_polyline(outline,panel.border_color,3.0 if selected else 2.0,true)
	if question:
		draw_string(font,Vector2(-12,-35),"？",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("6d5139"))
	elif front:
		draw_string(font,Vector2(-11,-43),"…",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("6d5139"))
	elif drink:
		preload("res://scripts/ui/components/ganlu_cup_visual.gd").draw_cup(self,Rect2(-17,-74,34,46),1 if ice>0 else 0)
	elif dish:
		var extent := dish.get_size() * minf(44.0 / dish.get_width(), 38.0 / dish.get_height())
		draw_texture_rect(dish,Rect2(Vector2(0,-64)-extent*0.5,extent),false)
		var index := 0
		for id in ingredients:
			var x := -float(ingredients.size())*12 + index*24
			var icon := Icons.texture(Recipes.item_texture(id))
			if icon: draw_texture_rect(icon,Rect2(x,-40,20,20),false)
			draw_string(font,Vector2(x+13,-19),str(ingredients[id]),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("553c2c"))
			index += 1
	if selected:
		keycap.bg_color = Color("f5da93")
		keycap.set_corner_radius_all(5)
		keycap.draw(get_canvas_item(),Rect2(29,-100,23,23))
		draw_string(font,Vector2(35,-82),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("654c34"))
