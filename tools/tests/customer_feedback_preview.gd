extends "res://tools/tests/first_exploration.gd"
const GuestCatalog := preload("res://scripts/restaurant/customer_catalog.gd")
const Bubble := preload("res://tools/tests/customer_feedback_bubble_preview.gd")
var sheet: Node2D
var marks: Array[Node2D] = []
func label_at(parent: Node, text: String, at: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font",SproutTheme.FONT_CN)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离预览")
	if failures == 0:
		var bg := ColorRect.new()
		bg.color = Color("f1e4c8")
		bg.size = Vector2(1280,720)
		add_child(bg)
		label_at(self,"顾客情绪反馈 · 六种状态",Vector2(34,18),26,SproutTheme.INK)
		label_at(self,"保留原始瞳孔 / 头顶情绪动效 / 气泡仅显示文案",Vector2(34,55),17,SproutTheme.INK_MUTED)
		sheet = Node2D.new()
		add_child(sheet)
		var names := ["候客超时 · 失落","甘露水超时 · 不耐烦","料理超时 · 生气","交错料理 · 复用生气","水不达标 · 复用不耐烦","未点水收到水 · 疑惑"]
		var phrases := ["怎么没人招呼……","水还没好吗……","等太久了！","这不是我点的！","这杯水不太对……","咦，我没点水呀？"]
		var kinds := [0,1,2,2,1,3]
		for i in 6:
			var tile := Node2D.new()
			tile.position = Vector2(30+(i%3)*416,100+(i/3)*296)
			sheet.add_child(tile)
			var map := TextureRect.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/maps/restaurant_map.png")
			atlas.region = Rect2(250,100,500,340)
			map.texture = atlas
			map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			map.size = Vector2(394,258)
			map.modulate = Color(0.87,0.87,0.87)
			tile.add_child(map)
			var config: Dictionary = GuestCatalog.CUSTOMERS[i%3]
			var actor := Sprite2D.new()
			var frame := AtlasTexture.new()
			frame.atlas = load(config.actions)
			frame.region = Rect2(0,384 if i > 0 else 0,384,384)
			actor.texture = frame
			actor.scale = Vector2.ONE*0.40
			actor.position = Vector2(197,208)
			actor.offset = Vector2(0,-192)
			actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tile.add_child(actor)
			_check(preload("res://scripts/ui/components/customer_expression.gd").apply(actor,config.id,["sad","impatient","angry","confused"][kinds[i]]),"人物表情挂接")
			var bubble := Bubble.new()
			bubble.message = phrases[i]
			bubble.emotion = kinds[i]
			var used := frame.get_image().get_used_rect()
			bubble.position = Vector2(197,208-153.6+used.position.y*0.4-6)
			tile.add_child(bubble)
			var mark := preload("res://scripts/ui/components/customer_emotion_mark.gd").new()
			mark.kind = "anger" if kinds[i] == 2 else ("question" if kinds[i] == 3 else "confusion")
			mark.position = bubble.position + Vector2(22,23)
			mark.animate = false
			tile.add_child(mark)
			marks.append(mark)
			var strip := ColorRect.new()
			strip.color = Color("fff0d5")
			strip.position = Vector2(0,226)
			strip.size = Vector2(394,32)
			tile.add_child(strip)
			label_at(tile,names[i],Vector2(12,231),17,SproutTheme.INK)
		await _shot_gate("six_states")
		for frame_index in 24:
			for mark in marks:
				mark.elapsed = frame_index/12.0
				mark.queue_redraw()
			await _shot_gate("motion_%02d" % frame_index)
		sheet.scale = Vector2(1.5,1.5)
		sheet.position = Vector2(-30,-100)
		await _shot_gate("detail")
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}))
	get_tree().quit()
