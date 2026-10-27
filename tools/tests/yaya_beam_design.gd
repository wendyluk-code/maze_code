extends Node2D
var stage := 0
var background: Texture2D
var orb: Texture2D
func _ready() -> void:
	get_window().size=Vector2i(1280,720)
	background=ImageTexture.create_from_image(Image.load_from_file("res://output/projectile_angles/final/screenshots/slot_1_angle_0_1280x720.png"))
	orb=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load("res://assets/ui/combat_skills/yaya.png"))
	_run.call_deferred()
func _draw() -> void:
	if background==null: return
	draw_texture_rect(background,Rect2(0,0,1280,720),false)
	var t := float(stage)*0.05
	var start := Vector2(840,307)
	var travel := clampf((t-0.2)/0.6,0,1)
	var head := start+Vector2(300*travel,0)
	var alpha := 1.0 if t<0.8 else clampf(1-(t-0.8)/0.15,0,1)
	if t>=0.2 and t<0.95:
		var length := minf(140,300*travel)
		for i in 35:
			var u := float(i)/35
			var p := head-Vector2(length*(1-u),0)
			var q := p+Vector2(length/35,0)
			draw_line(p,q,Color(0.5,0.85,0.16,alpha*u*0.4),9*u,true)
			draw_line(p,q,Color(0.72,1,0.30,alpha*u),5*u,true)
			draw_line(p,q,Color(1,1,0.72,alpha*u),2.2*u,true)
		if t<0.8:
			draw_set_transform(head,PI/4)
			draw_texture_rect(orb,Rect2(-12,-12,24,24),false,Color(1,1,1,alpha))
			draw_set_transform(Vector2.ZERO)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/yaya_beam_design/frames")
	for i in 30:
		stage=i
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/yaya_beam_design/frames/%03d.png" % i)
	get_tree().quit()
