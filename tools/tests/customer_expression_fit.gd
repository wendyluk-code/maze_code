extends "res://tools/tests/first_exploration.gd"
const Guests := preload("res://scripts/restaurant/customer_catalog.gd")
const Face := preload("res://scripts/ui/components/customer_expression.gd")
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	var root := Node2D.new()
	add_child(root)
	var background := ColorRect.new()
	background.color = Color("eee0c3")
	background.size = Vector2(1280,720)
	root.add_child(background)
	var title := Label.new()
	title.position = Vector2(26,16)
	title.add_theme_font_override("font",SproutTheme.FONT_CN)
	title.add_theme_font_size_override("font_size",23)
	title.add_theme_color_override("font_color",SproutTheme.INK)
	root.add_child(title)
	var actors: Array = []
	for row in 2:
		title.text = ("站姿" if row == 0 else "坐姿") + " · 三位冒险者共用四套透明五官（放大检查）"
		for guest in 3:
			for emotion in 4:
				var actor := Sprite2D.new()
				var atlas := AtlasTexture.new()
				atlas.atlas = load(Guests.CUSTOMERS[guest].actions)
				atlas.region = Rect2(0,row*384,384,384)
				actor.texture = atlas
				actor.scale = Vector2.ONE*0.52
				actor.offset = Vector2(0,-192)
				actor.position = Vector2(155+emotion*320,260+guest*212)
				actor.flip_h = guest == 1
				root.add_child(actor)
				actors.append(actor)
				_check(Face.apply(actor,Guests.CUSTOMERS[guest].id,Face.NAMES[emotion]),"表情适配%d/%d/%d"%[row,guest,emotion])
				_check(actor.texture == atlas,"原始贴图保持")
				var first = actor.get_node("CustomerExpression")
				_check(first.features.get_image().get_pixel(0,0).a==0,"图集透明背景")
				Face.clear(actor)
				_check(actor.material==null and actor.get_node_or_null("CustomerExpression")==null,"移除后恢复")
				Face.apply(actor,Guests.CUSTOMERS[guest].id,Face.NAMES[emotion])
		await _shot_gate("standing_matrix" if row==0 else "seated_matrix")
		for actor in actors:
			var atlas: AtlasTexture = actor.texture
			atlas.region.position.y = 3*384
		await get_tree().process_frame
		await get_tree().process_frame
		for actor in actors:
			_check(actor.material == null and actor.get_node_or_null("CustomerExpression")==null,"动作切换撤下表情")
			_check(not Face.apply(actor,"mage","angry"),"侧身挥手不误贴")
		for actor in actors: actor.queue_free()
		actors.clear()
		await get_tree().process_frame
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit(1 if failures else 0)
