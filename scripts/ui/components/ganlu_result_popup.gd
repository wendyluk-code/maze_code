extends "res://scripts/ui/cooking_result_popup.gd"
const Art := preload("res://scripts/ui/components/ganlu_art.gd")

func present_water(amount: float) -> void:
	scale = Vector2.ONE
	var good := preload("res://scripts/restaurant/ganlu_service.gd").pour_factor(amount)>0
	var kind := "success" if good else ("low" if amount<0.65 else "high")
	present("", Art.result_cup(kind), 1)
	_stars.hide()
	_dish_name.hide()
	var title: Label = _panel.get_child(0).get_child(0)
	title.text = {"low":"水太少了！","success":"甘露水准备好了","high":"水太满了！"}[kind]
	title.add_theme_color_override("font_color",Color("426044") if good else Color("a15c43"))
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_confirm_button.text = "端起" if good else "重新倒水"

func retry_save() -> void:
	_ready_for_input = true
	_confirm_button.disabled = false

func flip_in() -> void:
	if is_instance_valid(_tween): _tween.kill()
	pivot_offset = get_viewport_rect().size*0.5
	scale = Vector2(0.02,1)
	modulate.a = 1.0
	_ready_for_input = false
	_confirm_button.disabled = true
	_tween = create_tween()
	_tween.tween_property(self,"scale:x",1.0,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		_ready_for_input = true
		_confirm_button.disabled = false)
