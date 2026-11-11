extends "res://tools/tests/ganlu_service.gd"
const Layout := preload("res://scripts/restaurant/six_seat_layout.gd")
var interacted_count := 0

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _map_flow()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _map_flow() -> void:
	_prepare_drink()
	var customers: Dictionary = sm.restaurant_customers()
	customers.serial = 6
	customers.seated.clear()
	for i in range(6):
		customers.seated.append({"id":"map_%d"%i,"customer_id":["mage","dingdang","half_elf"][i%3],"item_id":"slime_candy","item_name":"弹跳史莱姆冻","quantity":1,"phase":"waiting","seat":i,"drink_ice":i%4,"drink_done":false,"food_done":false})
	_check(sm._customers_valid(customers),"六席订单均为有效座位")
	sm.data.restaurant_customers = customers
	_check(sm.save(),"六席可保存")
	sm.load_data()
	_check(sm.restaurant_customers().seated.size()==6,"读档恢复六席")
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.7).timeout
	var player = scene.get_node("Player")
	var zone = scene.get_node("WalkZone")
	var camera = scene.get_node("Camera")
	var bar = scene.get_node("InteractPoints/BarCounter")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var flow = hud.customer_flow
	var patch = scene.get_node("SixSeatBarArt")
	_check(scene.get_node("BG").texture.get_size()==Vector2(1448,1086) and patch.texture.get_size()==Vector2(1448,1086),"画布尺寸与原图均为1448×1086")
	_check(scene.get_node("BG").texture.resource_path=="res://assets/maps/restaurant_map.png" and scene.get_node("BG").scale==Vector2.ONE,"原始底图保留且不缩放")
	_check(patch.polygon==Layout.PATCH and patch.uv==Layout.PATCH,"局部图使用原坐标裁切，无拉伸")
	var baseline: Node = load("res://output/restaurant_six_seat_integration/baseline/restaurant_map_2d.tscn").instantiate()
	for prop_name in ["Cauldron","FoodCart","Fridge","Store","TrashBin","AdventurerHomeDoor"]:
		var original = baseline.get_node("InteractPoints/"+prop_name)
		var actual = scene.get_node("InteractPoints/"+prop_name)
		_check(original.position==actual.position and original.scale==actual.scale,prop_name+"位置与比例保持")
		for property in ["interaction_polygon","foreground_polygon","occlusion_polygon","ui_offset"]:
			_check(original.get(property)==actual.get(property),prop_name+"保留"+property)
		_check(not Geometry2D.is_point_in_polygon(actual.position,patch.polygon),prop_name+"未被新吧台图覆盖")
	baseline.free()
	_check(scene.get_node("SeatAnchors").get_child_count()==6 and flow.actors.size()==6,"六个座位与六位顾客实际显示")
	_check(not scene.get_node("InteractPoints/Register").is_in_group("interactable"),"章后不显示独立前台接单入口")
	player.interacted.connect(func(_target): interacted_count+=1)
	for i in range(6):
		_check(scene.get_node("SeatAnchors/Seat%d"%i).position==Layout.SEATS[i],"座位%d对齐地图"%i)
		_check(flow.actors["map_%d"%i].position==Layout.SEATS[i]+Vector2(0,24),"顾客%d坐姿定位"%i)
		var point := Layout.service_point(i)
		_check(player.is_walkable_footprint(point),"座位%d内侧可站立"%i,{"point":str(point)})
		player.position=point
		player.last_valid=point
		_check(player.nearest_interactable()==bar,"座位%d可触达长吧台"%i)
		var count_before := interacted_count
		await _send_key(KEY_E)
		_check(interacted_count==count_before+1,"座位%d真实E交互"%i)
		_check(not player.is_walkable_footprint(point-Vector2(0,65)),"座位%d台面不能穿过"%i)
	var before_move: Vector2 = Layout.service_point(3)
	player.position=before_move
	player.last_valid=before_move
	await _key_hold(KEY_W,true)
	await get_tree().create_timer(0.35).timeout
	await _key_hold(KEY_W,false)
	_check(player.is_walkable_footprint(player.position) and not Geometry2D.is_point_in_polygon(player.position,Layout.BODY),"真实移动不能穿入新吧台")
	camera.set_process(false)
	camera.position=Vector2(724,543)
	camera.zoom=Vector2(0.58,0.58)
	camera.reset_smoothing()
	hud.toast_label.dismiss()
	await _capture_image("whole_map")
	camera.position=Vector2(724,320)
	camera.zoom=Vector2(0.95,0.95)
	camera.reset_smoothing()
	await _capture_image("six_seated")
	# 原有道具的实际交互仍使用原距离与输入。
	player.position=_stand(scene.get_node("InteractPoints/FoodCart"))
	await _send_key(KEY_E)
	_check(hud.ganlu.modal.visible,"小餐车仍可实际打开")
	await _send_key(KEY_ESCAPE)
	_check(not player.input_locked,"关闭倒水恢复移动")
	player.position=_stand(scene.get_node("InteractPoints/Fridge"))
	_check(hud.ganlu.can_use_freezer(),"冰柜原交互范围可用")
	# 空位自动入座，不再需要旧前台E。
	customers = sm.restaurant_customers()
	customers.seated.remove_at(5)
	customers.front={"id":"map_auto","customer_id":"mage","item_id":"slime_candy","item_name":"弹跳史莱姆冻","quantity":1,"phase":"front","seat":-1}
	sm.data.restaurant_customers=customers
	sm.save()
	await get_tree().create_timer(1.2).timeout
	_check(sm.restaurant_customer_order("map_auto").get("phase")=="waiting" and sm.restaurant_customer_order("map_auto").get("seat")==5,"第六席自动入座并显示需求")
	_check(not player.input_locked and not flow.busy,"自动入座不弹接单对白或锁输入")
	scene.queue_free()
	await get_tree().process_frame
