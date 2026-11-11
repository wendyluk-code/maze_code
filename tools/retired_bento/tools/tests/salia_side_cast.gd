extends "res://tools/tests/yf04_flow.gd"

func encounter_flow() -> void:
	setup_trip(18.0)
	await open_map()
	var e=maze.yf_encounter
	e.set_process(false)
	maze.capture_flow.set_process(false)
	maze.player.position=Sim.POSITIONS.yufeng+Vector2(60,0)
	_check(e._commit("battle"),"建立正式切磋存档")
	e._start_battle()
	var actor: Dictionary=e.run.combat.actors.salia
	var foot:=Sim.Skills.vec(actor.position)
	var scale_before:=Vector2.ZERO
	for side in [-1,1]:
		maze.player.position=foot+Vector2(side*100,0)
		maze.camera.snap_to_target()
		for frame in 6:
			actor.cast=0.48-float(frame)*0.08-0.001
			e._sync_visuals()
			var body: Sprite2D=e.actors.salia
			_check(body.texture.resource_path.ends_with("03_salia_cast_side/frame_%02d.png"%frame),"实际施法选择侧身帧")
			_check(body.flip_h==(side<0),"施法朝向主角左右位置")
			_check(body.position==foot,"六帧角色脚底不漂移")
			if scale_before==Vector2.ZERO: scale_before=body.scale
			_check(body.scale==scale_before,"六帧统一比例不忽大忽小")
			var image:=body.texture.get_image()
			_check(image.get_pixel(0,0).a==0 and image.get_pixel(511,511).a==0,"切片保留透明背景")
			await _capture_image("cast_"+("left" if side<0 else "right")+"_"+str(frame))
	actor.cast=0
	actor.moving=false
	e._sync_visuals()
	_check(e.actors.salia.texture.resource_path.contains("salia_idle"),"施法结束恢复侧身待机")
	_check(e._commit("post"),"切磋接入战后阶段")
	e._show_line()
	e._sync_visuals()
	for id in ["yufeng","salia"]:
		_check(e.actors[id].flip_h==(maze.player.position.x<e.actors[id].position.x),"战后两人仍面向主角")
	await _capture_image("post_facing")
	await _close_scene_for_cast()

func _close_scene_for_cast() -> void:
	maze.queue_free()
	await get_tree().process_frame

func _bento_flow() -> void:
	pass

func legacy_phases() -> void:
	pass
