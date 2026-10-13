extends "res://tools/tests/chapter_ending_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			_seed()
			sm.advance_chapter_1_outro("party")
			await _open_scene()
			_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and not tm._chapter_outro._busy,240), "真实home阶段就绪")
			if not is_instance_valid(tm._chapter_outro):
				await _close_scene()
				break
			for label in ["home", "maze"]:
				var outro = tm._chapter_outro
				var glow = outro._entrance_highlight
				_check(is_instance_valid(glow) and glow.visible, "真实入口高亮：" + label)
				_check(glow.transform.is_equal_approx(scene.get_node("BG").get_global_transform_with_canvas()), "背景投影一致：" + label)
				glow.set_process(false)
				_check(glow.motes.size() == 4, "四颗稀疏门槛点：" + label)
				await get_tree().create_timer(1.2).timeout
				for sample in [{"name":"middle", "t":0.9}, {"name":"low", "t":1.8}]:
					glow.elapsed = sample.t
					glow._process(0.0)
					_check(absf(glow.strength - (0.5 if sample.name == "middle" else 0.0)) < 0.01, "呼吸采样强度：" + label + sample.name)
					await _shot(label + "_" + sample.name)
				glow.set_process(true)
				await _dialog_finish()
				_check(await _wait_until(func(): return outro.phase == ("maze" if label == "home" else "title") and not outro._busy,240), "继续切换：" + label)
				_check(not is_instance_valid(glow) or not glow.visible, "切换无旧光效：" + label)
			# 等待组件原生就绪契约，兼容原版与顺序渐显标题，不以固定时长抢先输入。
			_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro._ending._ready_for_input,600), "章末原生渐显完成后允许输入")
			await _send_key(KEY_E)
			_check(await _wait_until(func(): return not tm.active,120), "真实继续结束收尾")
			for path in ["InteractPoints/AdventurerHomeDoor", "DepartureEntrance"]:
				var player = scene.get_node("Player")
				if path.ends_with("AdventurerHomeDoor") and not ResourceLoader.exists("res://assets/ui/home_collection/header_leaf.png"):
					continue
				player.global_position = _stand(scene.get_node(path))
				player.last_valid = player.global_position
				await get_tree().process_frame
				await _send_key(KEY_E)
				var hud = get_tree().get_first_node_in_group("restaurant_hud")
				if path.ends_with("AdventurerHomeDoor"):
					_check(is_instance_valid(get_tree().get_first_node_in_group("adventurer_home")) or hud.confirmation.visible, "结束后冒险者之家通行恢复（直开或既有确认）")
				else:
					_check(hud.confirmation.visible and player.input_locked, "结束后入口通行确认恢复：" + path)
				await _send_key(KEY_ESCAPE)
				_check(not hud.confirmation.visible and not is_instance_valid(get_tree().get_first_node_in_group("adventurer_home")) and not player.input_locked, "通行返回或取消恢复：" + path)
			await _close_scene()
			for label in ["home", "maze"]:
				_seed()
				sm.advance_chapter_1_outro("party")
				if label == "maze": sm.advance_chapter_1_outro("home")
				await _open_scene()
				_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and not tm._chapter_outro._busy,240), "取消前就绪：" + label)
				if not is_instance_valid(tm._chapter_outro):
					await _close_scene()
					break
				var glow = tm._chapter_outro._entrance_highlight
				tm._cancel_current_run()
				_check(not is_instance_valid(glow) or not glow.visible, "取消无残留：" + label)
				_check(not scene.get_node("Player").input_locked and not scene.get_node("Camera").paused, "取消恢复移动镜头：" + label)
				var player = scene.get_node("Player")
				player.global_position = _stand(scene.get_node("InteractPoints/Store"))
				player.last_valid = player.global_position
				var before: Vector2 = player.global_position
				Input.action_press("ui_right")
				await get_tree().create_timer(0.2).timeout
				Input.action_release("ui_right")
				_check(player.global_position.distance_to(before) > 1.0, "取消后真实移动：" + label)
				await _shot(label + "_cancel")
				await _close_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":ProjectSettings.globalize_path("user://"), "home_transit_missing_assets":not ResourceLoader.exists("res://assets/ui/home_collection/header_leaf.png")}, "\t"))
	get_tree().quit(1 if failures else 0)



func _shot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _capture(evidence, label + suffix)
