extends "res://tools/tests/waterkeeper_flow.gd"
## 屋侧到菜畦间的真实通行，以及植物根部固定、错峰轻摇和靠近单次回弹。
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	_check(get_window().current_screen!=DisplayServer.get_primary_screen(),"园圃验收位于副屏")
	cottage=load("res://data/maze/waterkeeper_cottage_roads.gd")
	var path := [Vector2(620,344),Vector2(550,335),Vector2(500,350),Vector2(450,363),Vector2(400,380),Vector2(350,392)]
	for point in path: _check(cottage.is_walkable(point),"屋侧与菜畦间土路可走"+str(point))
	for i in range(path.size()-1): _check(cottage.move_on_road(path[i],path[i+1]-path[i]).distance_to(path[i+1])<0.2,"菜园道路连续可达"+str(i))
	for point in [Vector2(390,340),Vector2(480,395),Vector2(550,280),Vector2(660,250),Vector2(1100,440),Vector2(220,900)]:
		_check(not cottage.is_walkable(point),"菜畦柴堆房屋溪流和南出口继续阻挡"+str(point))
	_check(ResourceLoader.exists("res://scripts/maze/cottage_garden.gd"),"独立植物动画组件存在")
	if failures==0:
		if OS.get_environment("COTTAGE_GARDEN_RESTORE")=="1":
			await _garden_restore()
		else:
			for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
				get_window().size=resolution
				suffix="_%dx%d"%[resolution.x,resolution.y]
				await _garden_scene()
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"	"))
	get_tree().quit(1 if failures else 0)

func _walk_cottage_path(point: Vector2) -> void:
	# 园圃斜路不能按固定45度切角；按目标向量送入实际方向输入，仍由玩家与地形处理移动。
	for i in 360:
		maze.capture_flow.window_focused=true
		var delta: Vector2=point-maze.player.position
		if delta.length()<2.5: break
		var direction:=delta.normalized()
		for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
		Input.action_press("ui_right" if direction.x>0 else "ui_left",absf(direction.x))
		Input.action_press("ui_down" if direction.y>0 else "ui_up",absf(direction.y))
		await get_tree().physics_frame
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
	_check(maze.player.position.distance_to(point)<6,"实际方向输入沿土路抵达"+str(point),{"actual":str(maze.player.position)})

func _walk_keyboard(point: Vector2) -> void:
	var balance:=Vector2.ZERO
	var previous: Key=KEY_NONE
	for step in 420:
		maze.capture_flow.window_focused=true
		var delta: Vector2=point-maze.player.position
		if delta.length()<3: break
		var direction:=delta.normalized()
		balance+=Vector2(absf(direction.x),absf(direction.y))
		var horizontal:=balance.x>=balance.y
		var key: Key=(KEY_D if delta.x>0 else KEY_A) if horizontal else (KEY_S if delta.y>0 else KEY_W)
		if horizontal: balance.x-=1
		else: balance.y-=1
		if previous!=key:
			if previous!=KEY_NONE:
				var release:=InputEventKey.new()
				release.keycode=previous
				release.physical_keycode=previous
				Input.parse_input_event(release)
			var press:=InputEventKey.new()
			press.keycode=key
			press.physical_keycode=key
			press.pressed=true
			Input.parse_input_event(press)
			previous=key
		await get_tree().physics_frame
	if previous!=KEY_NONE:
		var release:=InputEventKey.new()
		release.keycode=previous
		release.physical_keycode=previous
		Input.parse_input_event(release)
	await get_tree().physics_frame
	_check(maze.player.position.distance_to(point)<6,"实际WASD键盘沿路抵达"+str(point),{"actual":str(maze.player.position)})

func _garden_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	maze.travel_region("waterkeeper_cottage",Vector2(700,350))
	await _settled()
	_check(maze.region_id=="waterkeeper_cottage" and maze._entry_ready,"真实小屋场景就绪")
	var garden=maze.get_node_or_null("CottageGarden")
	_check(garden!=null,"生产场景加载分层植物")
	if garden==null:
		await _close_scene()
		return
	var background: Sprite2D=maze.get_child(0)
	_check(background.texture.resource_path.ends_with("waterkeeper_cottage_soil.png"),"底图使用清除旧植株的局部补土版本")
	var source: Image=load("res://assets/maps/waterkeeper_cottage.png").get_image()
	var soil: Image=background.texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	soil.convert(Image.FORMAT_RGBA8)
	for rect in [Rect2i(0,0,1672,276),Rect2i(0,276,280,191),Rect2i(587,276,1085,191),Rect2i(0,467,1672,474),Rect2i(491,276,96,65),Rect2i(280,386,94,81)]:
		_check(source.get_region(rect).get_data()==soil.get_region(rect).get_data(),"补土范围外完整像素保护"+str(rect))
	for p in [Vector2i(650,250),Vector2i(700,350),Vector2i(1090,340),Vector2i(350,760)]:
		_check(source.get_pixelv(p)==soil.get_pixelv(p),"菜园外底图像素保持原样"+str(p))
	var roots: Array=[]
	for plant in garden.plants:
		roots.append(plant.global_position)
		var texture: Image=plant.get_child(0).texture.get_image()
		_check(texture.detect_alpha()!=Image.ALPHA_NONE and texture.get_pixel(0,0).a==0,"植物使用透明素材且留出摇动空间")
	for point in [Vector2(620,344),Vector2(550,335),Vector2(500,350),Vector2(450,363),Vector2(400,380),Vector2(350,392)]: await _walk_keyboard(point)
	_check(sm.record_maze_location("waterkeeper_cottage",maze.player.position).success,"新增土路站位可保存")
	sm.load_data()
	_check(sm.maze_exploration_state().region=="waterkeeper_cottage","新增土路位置读回仍合法")
	maze.camera.snap_to_target()
	await _capture_image("01_garden_aisle")
	garden.set_process(false)
	var reactions: Array=[]
	garden.plant_reacted.connect(func(index): reactions.append(index))
	garden.advance_motion(2.0,Vector2(1400,200),true)
	var before: Vector2=garden.plants[0].to_global(Vector2(0,-50))
	garden.advance_motion(0.8,Vector2(1400,200),true)
	_check(before.distance_to(garden.plants[0].to_global(Vector2(0,-50)))>0.1,"真实植物节点随时间轻摇")
	_check(absf(garden.plants[0].rotation-garden.plants[1].rotation)>0.0001,"不同植株错开摇动节奏")
	for i in garden.plants.size(): _check(garden.plants[i].global_position==roots[i],"摇动不移动植物根部"+str(i))
	var root: Vector2=garden.plants[0].position
	garden.advance_motion(0.02,root,false)
	_check(reactions.is_empty(),"输入锁定时不触发靠近回应")
	garden.advance_motion(0.02,root,true)
	_check(reactions.has(0),"靠近触发植物轻颤")
	var count:=reactions.count(0)
	for i in 40: garden.advance_motion(0.02,root,true)
	_check(reactions.count(0)==count,"站在附近不反复触发回弹")
	garden.advance_motion(0.02,Vector2(1400,200),true)
	garden.advance_motion(0.02,root,true)
	_check(reactions.count(0)==count+1,"离开再靠近可再次回应")
	for i in 200: garden.advance_motion(0.02,root,true)
	_check(absf(garden.plants[0].rotation)<0.05,"回弹衰减后保持轻柔幅度")
	for point in [Vector2(400,380),Vector2(450,363),Vector2(500,350),Vector2(550,335),Vector2(540,322),Vector2(460,285),Vector2(405,265)]: await _walk_cottage_path(point)
	maze.camera.snap_to_target()
	await _capture_image("02_house_side_path")
	for point in [Vector2(460,285),Vector2(540,322),Vector2(550,335),Vector2(500,350),Vector2(450,363)]: await _walk_cottage_path(point)
	await _hold_direction("ui_up",0.6)
	_check(cottage.is_walkable(maze.player.position) and maze.player.position.y>350,"真实输入不能穿过番茄菜畦")
	await _walk_cottage_path(Vector2(450,363))
	await _hold_direction("ui_down",0.6)
	_check(cottage.is_walkable(maze.player.position) and maze.player.position.y<390,"真实输入不能穿过大叶蔬菜菜畦")
	await _walk_cottage_path(Vector2(450,363))
	maze.camera.snap_to_target()
	for frame in 48:
		garden.advance_motion(1.0/24.0,maze.player.position,true)
		await RenderingServer.frame_post_draw
		var folder:=_arg("--output-dir=").path_join("motion"+suffix)
		DirAccess.make_dir_recursive_absolute(folder)
		get_viewport().get_texture().get_image().save_png(folder.path_join("frame_%03d.png"%frame))
	await _capture_image("03_garden_motion")
	_check(maze.chests.is_empty() and maze.dig_sites.is_empty() and maze.capture_flow.monsters.is_empty(),"植物动画不新增采集奖励或怪物")
	_check(maze._save_position(),"保留菜畦间合法站位供新进程恢复")
	await _close_scene()

func _garden_restore() -> void:
	sm._active_save_path="user://chapter-ending-test.json"
	sm.load_data()
	var state: Dictionary=sm.maze_exploration_state()
	_check(state.region=="waterkeeper_cottage","新进程恢复小屋区域")
	var point:=Vector2(state.position[0],state.position[1])
	_check(point.distance_to(Vector2(450,363))<6 and cottage.is_walkable(point),"新进程保留菜畦间土路位置")
	maze=load(sm.resume_scene_path()).instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await _settled()
	_check(maze._entry_ready and maze.player.position.distance_to(point)<0.1 and maze.has_node("CottageGarden"),"恢复后玩家与植物分层正常就绪")
	await _capture_image("04_garden_restart")
	await _close_scene()
