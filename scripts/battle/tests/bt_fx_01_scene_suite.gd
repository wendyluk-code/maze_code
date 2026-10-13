extends "res://scripts/battle/tests/tutorial_scene_suite.gd"
## 复用真实开始页、鼠标出牌与八回合流程；逐帧记录分裂显示。
var seen_deaths: Dictionary = {}
var split_frames: Array = []
var baseline := false

func _initialize() -> void:
	baseline = OS.get_cmdline_user_args().has("baseline")
	process_frame.connect(_observe_split)
	super._initialize()

func _observe_split() -> void:
	if not is_instance_valid(ui) or not ui.battle or ui.battle.turn == 0: return
	for id in ["slime_a", "slime_b"]:
		if ui.battle.characters[id].alive or seen_deaths.has(id): continue
		seen_deaths[id] = true
		var parent: Control = ui.role_nodes[id]
		var children_visible := false
		for suffix in ["1", "2"]:
			if ui.role_nodes.has(id + suffix): children_visible = children_visible or ui.role_nodes[id + suffix].visible
		var frame := {"parent": id, "turn": ui.battle.turn, "state": ui.state, "mother_visible": parent.get_node("Portrait").visible, "children_visible": children_visible}
		split_frames.append(frame)
		if not baseline:
			check(frame.mother_visible and not children_visible, "事务提交后母体仍可见、子体首次出现延后 " + id)
			_inspect_split(id)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/bt_fx_01/%d_%s.png" % [root.size.x, label])

func _inspect_split(id: String) -> void:
	while is_instance_valid(ui) and ui.split_phase == "waiting": await process_frame
	if not is_instance_valid(ui): return
	await create_timer(0.12).timeout
	# 在渲染帧末采样，确保同帧新建Tween已更新，避免首帧素材加载耗时造成采样抢先。
	await RenderingServer.frame_post_draw
	check(ui.split_phase == "dissolving", "母体退场具有连续可见时段 " + id)
	var portrait: Control = ui.role_nodes[id].get_node("Portrait")
	check(portrait.visible and portrait.scale.x < 1.0 and portrait.modulate.a > 0.0, "母体收缩、渐隐中间帧 %s scale=%s alpha=%s" % [id, portrait.scale, portrait.modulate.a])
	check(not ui.role_nodes[id + "1"].visible and not ui.role_nodes[id + "2"].visible, "退场时子体尚未出现 " + id)
	await _shot(id + "_dissolving")
	if id == "slime_a":
		var snapshot: Dictionary = ui.battle.duplicate(true)
		await click(ui.battle_menu.gear.position + Vector2(24, 24))
		check(paused and ui.battle_menu.is_open, "分裂演出期间打开菜单暂停")
		var scale_before := portrait.scale
		await create_timer(0.2).timeout
		check(portrait.scale == scale_before and ui.battle == snapshot, "菜单暂停动画与事务")
		var restart: Control = ui.battle_menu.restart_button
		await click(ui.board.get_global_transform_with_canvas().affine_inverse() * restart.get_global_rect().get_center())
		var cancel: Control = ui.battle_menu.confirmation.cancel_button
		await click(ui.board.get_global_transform_with_canvas().affine_inverse() * cancel.get_global_rect().get_center())
		check(not paused and ui.battle == snapshot, "分裂中取消重开恢复同一事务")
	while is_instance_valid(ui) and ui.split_phase == "dissolving": await process_frame
	if not is_instance_valid(ui): return
	await create_timer(0.16).timeout
	var child: Control = ui.role_nodes[id + "2"]
	check(ui.split_phase == "separating" and child.visible and child.modulate.a > 0.0, "子体连续分离中间帧 " + id)
	check(child.position.distance_to(ui._prepare_position(id + "2")) > 1.0 and child.scale.x > 0.32, "子体从母体位置向槽位移动并长大 " + id)
	var before_sync := child.position
	ui._sync()
	check(child.position == before_sync, "同步不抢写分离位置 " + id)
	await _shot(id + "_separating")
	var snapshot: Dictionary = ui.battle.duplicate(true)
	await click(ui.end_button.position + Vector2(35, 49))
	check(ui.battle == snapshot, "分离中重复业务输入不二次结算 " + id)
	while is_instance_valid(ui) and not ui.pending_splits.is_empty(): await process_frame
	if not is_instance_valid(ui): return
	check(child.position == ui._prepare_position(id + "2") and child.scale == Vector2.ONE, "动画后位置与尺寸恢复 " + id)
	check(not ui.role_nodes[id].get_node("Portrait").visible and not ui.split_tween and ui.fx.dissolves.is_empty(), "动画后母体让槽、临时动画清理 " + id)
	await _shot(id + "_settled")

func finish() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/bt_fx_01")
	var file := FileAccess.open("res://output/bt_fx_01/%s_split_%d.json" % ["baseline" if baseline else "animated", root.size.x], FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": split_frames, "user_data_dir": OS.get_user_data_dir()}, "\t"))
	file.close()
	var report := FileAccess.open("res://output/bt_fx_01/%s_scene_%d.json" % ["baseline" if baseline else "animated", root.size.x], FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "user_data_dir": OS.get_user_data_dir(), "elapsed_ms": Time.get_ticks_msec() - started}, "\t"))
	report.close()
	super.finish()
