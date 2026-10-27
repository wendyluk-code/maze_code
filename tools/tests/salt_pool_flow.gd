extends "res://tools/tests/fenshui_flow.gd"
const Salt = preload("res://data/maze/salt_pool_roads.gd")
func _combat_scene() -> void:
 await _new_scene()
 maze.capture_flow.set_process(false)
 for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode = "idle"
 for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key] = []
 maze.travel_region("fenshui",Salt.FENSHUI_RETURN)
 await get_tree().create_timer(1.4).timeout
 maze = get_tree().current_scene
 _check(maze.region_id == "fenshui","抵达分水庭")
 maze.capture_flow.set_process(false)
 maze.camera.snap_to_target()
 maze._update_prompts()
 _check(maze.settlement_prompt.visible,"盐池紫色路标靠近提示")
 var stand: Vector2 = maze.player.position
 for gate in maze.FenshuiGates.GATES:
  maze.player.position = gate.front
  maze._update_prompts()
  _check(maze.fenshui_gate_prompts[gate.name].visible and not FS.is_walkable(maze.FenshuiGates.center(gate)),"保留栅栏提示与阻挡"+gate.name)
 maze.player.position = stand
 maze._update_prompts()
 await _capture_image("01_fenshui_salt_marker")
 await _send_key(KEY_E)
 _check(maze.confirmation.visible and maze.confirmation.question.text.contains("盐池"),"E打开盐池二次确认")
 await _capture_image("02_salt_confirm")
 await _send_key(KEY_ESCAPE)
 _check(not maze.confirmation.visible and not maze.player.input_locked,"取消恢复输入")
 var prior: Dictionary = sm.data.duplicate(true)
 await _click(maze.settlement_prompt.button)
 var save_path: String = sm._active_save_path
 sm._active_save_path = ""
 maze._confirm_destination()
 _check(maze.region_id == "fenshui" and sm.data == prior and not maze.player.input_locked,"切区保存失败回滚")
 sm._active_save_path = save_path
 await _click(maze.settlement_prompt.button)
 await _click(maze.confirmation.confirm_button)
 await get_tree().create_timer(1.5).timeout
 maze = get_tree().current_scene
 _check(maze.region_id == "salt_pool" and maze._entry_ready,"实际切入盐池")
 if maze.region_id != "salt_pool": return
 maze.capture_flow.set_process(false)
 maze.capture_flow.window_focused = true
 maze.camera.snap_to_target()
 _check(maze.player.position.distance_to(Salt.SPAWN)<0.1,"下方道路出生")
 _check(maze.has_node("SpawnPortal") and maze.entrance_prompt.visible,"出生后方绿色路标可返回")
 _check(maze.task_tracker.visible and is_instance_valid(maze.map_ui),"任务与地图UI保留")
 _check(maze.player.water_ripples == null,"盐地不误用浅水涟漪")
 for key in ["members","satiety","bag","monsters"]:
  _check(Run.snapshot(sm)[key] == prior[Run.KEY][key],"切区保留"+key)
 _check(sm.stamina_snapshot().value==prior.stamina.value,"换区不重复扣体力")
 await _capture_image("03_salt_spawn")
 await _verify_new_map()
 var normal := _measure(Vector2(70,390),Vector2.RIGHT,false)
 var salt := _measure(Vector2(850,430),Vector2.RIGHT,false)
 var restored := _measure(Vector2(70,390),Vector2.RIGHT,false)
 _check(normal>0 and absf(salt/normal-0.5)<0.01,"实际盐地速度50%",{"road":normal,"salt":salt})
 _check(absf(restored-normal)<0.01,"回到土路恢复正常")
 for p in [Vector2(10,10),Vector2(820,540),Vector2(1130,440),Vector2(1155,330)]:
  _check(not Salt.is_walkable(p),"外海水池晶石阻挡"+str(p))
 _check(Salt.is_walkable(Salt.SPAWN) and Salt.is_walkable(Salt.ENTRANCE),"出生返回点安全")
 maze.player.position = Vector2(850,430)
 maze.camera.snap_to_target()
 var effects = maze.get_node("SaltGroundEffects")
 effects.set_process(false)
 effects._process(0.01)
 maze.player._walking = true
 for i in 65:
  maze.player.position += Vector2(1,0)
  effects._process(0.01)
  effects._process(0.001)
 _check(effects.footprints.size()>0,"移动在盐地留下脚印")
 _check(effects.get_child_count()==0,"保持已移除周期白色蒙层")
 effects._process(0.1)
 await _capture_image("04_salt_footprints")
 effects._process(4.1)
 _check(effects.footprints.is_empty(),"脚印4秒后消失")

 await _capture_image("05_salt_clear")
 var projected: Vector2 = maze.map_ui._projection.project(maze.player.position)
 _check(projected.distance_to(maze.player.position/Salt.SIZE*Vector2(1672,941))<0.01,"小地图同源像素对应")
 maze.map_ui.open_map()
 await _capture_image("06_salt_map")
 maze.map_ui.close_map()
 _check(not maze.player.input_locked,"地图关闭恢复输入")
 var pos: Vector2 = maze.player.position
 _check(sm.record_maze_location("salt_pool",pos).success,"盐池位置保存")
 sm.load_data()
 _check(sm.resume_scene_path()=="res://scenes/maze_salt_pool.tscn" and Vector2(sm.maze_exploration_state().position[0],sm.maze_exploration_state().position[1]).distance_to(pos)<0.1,"读档恢复盐池场景位置")
 maze.player.position = Salt.SPAWN
 maze.camera.snap_to_target()
 maze._update_prompts()
 await get_tree().process_frame
 await _click(maze.entrance_prompt.button)
 _check(maze.confirmation.visible and maze.confirmation.question.text.contains("分水庭"),"绿色路标返回确认")
 await _click(maze.confirmation.confirm_button)
 await get_tree().create_timer(1.3).timeout
 maze = get_tree().current_scene
 _check(maze.region_id=="fenshui" and maze.player.position.distance_to(Salt.FENSHUI_RETURN)<0.1,"返回原紫色路标前方")
 maze.capture_flow.set_process(false)
 maze._update_prompts()
 await _click(maze.settlement_prompt.button)
 maze._finish_exploration_choice()
 await get_tree().create_timer(1.3).timeout
 _check(not Run.snapshot(sm).get("active",false),"紫色路标结束探索复用结算")
 await _close_scene()


func _verify_new_map() -> void:
 var background = maze.get_child(0)
 _check(background.texture.get_size()==Salt.SIZE,"原图像素尺寸与世界尺寸相同")
 _check(background.texture.resource_path=="res://assets/maps/salt_pool.png","实际场景采用选定底图")
 for point in [Vector2(80,390),Vector2(410,350),Vector2(850,430),Vector2(975,460),Vector2(1100,160),Vector2(1340,440),Salt.SPAWN]:
  _check(Salt.is_walkable(point),"确认区域可站立"+str(point))
  maze.player.position=point
  maze.camera.snap_to_target()
  await get_tree().process_frame
  var uv: Vector2=maze.map_ui._projection.project(point)/Vector2(1672,941)
  _check(uv.distance_to(point/Salt.SIZE)<0.00001,"角色脚底与地图同源坐标"+str(point))
  await _capture_image("anchor_%d_%d" % [point.x,point.y])
 # 使用真实角色输入分步靠近池水，不能穿过岸线。
 maze.player.position=Vector2(850,430)
 maze.player.input_locked=false
 Input.action_press("ui_down")
 for step in 60: maze.player._physics_process(0.05)
 Input.action_release("ui_down")
 _check(Salt.is_walkable(maze.player.position) and maze.player.position.y<475,"实际按键持续向池水移动被阻挡")
 # 旧坐标落入新水池时复用存档安全点回退，不改正式存档。
 var original: Dictionary=sm.data[sm.MAZE_STATE_KEY].duplicate(true)
 sm.data[sm.MAZE_STATE_KEY].position=[820,540]
 var recovered: Dictionary=sm.maze_exploration_state()
 _check(Vector2(recovered.position[0],recovered.position[1])==Salt.SPAWN,"旧存档非法站位回退盐池安全出生点")
 sm.data[sm.MAZE_STATE_KEY]=original
 maze.player.position=Salt.SPAWN
 maze.camera.snap_to_target()
