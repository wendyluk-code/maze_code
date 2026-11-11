extends "res://tools/tests/restaurant_rest05a.gd"
const Portions := preload("res://scripts/restaurant/menu_portions.gd")
const Review := preload("res://scripts/ui/components/restaurant_day_settlement.gd")
const Recipe := preload("res://scripts/cooking/recipe_catalog.gd")
const A := "salt_grilled_rockmane"
const B := "slime_candy"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_replenish()
		_wrong_dish()
		_same_recipe_orders()
		_sources()
		_atomic_and_legacy()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			for sold in [0,1,2]: await _real_business(sold)
			await _existing_menu_ui()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _fresh() -> void:
	_seed_cycle()
	sm.data.erase(Day.KEY)
	sm.data[Lesson.KEY] = {"phase":"done"}
	sm.data.unlocked_recipe_ids = Recipe.recipe_ids()
	for item in Recipe.INGREDIENTS: sm.data.warehouse_stock[item] = 20

func _open(menu: Dictionary) -> void:
	_check(Cycle.open_with_menu(sm,menu).success,"新营业建立完整份额账本")
	_check(Portions.managed(sm.data),"新日具有逐份归属")

func _cook(recipe: String, finish := true) -> void:
	_check(sm.take_warehouse_items(Recipe.get_recipe(recipe).ingredients).success,"逐单仓库选料仍可用")
	_check(sm.start_cooking(recipe).success,"起锅扣料及份额同事务")
	if finish: _check(sm.finish_first_order_cooking(3).success,"完成料理登记手持归属")

func _order(accept := true) -> Dictionary:
	sm.data[Day.KEY].arrival_left = 0.0
	var result := Cycle.arrive(sm)
	_check(result.get("created",false),"有未消耗额度时生成顾客")
	if not result.get("created",false): return {}
	var id: String = result.order.id
	_check(sm.advance_restaurant_customer(id,"arriving","front").success,"顾客渐显到前台")
	if accept:
		_check(sm.accept_restaurant_customer(id).success,"实际接单绑定不消耗份额")
		_check(sm.advance_restaurant_customer(id,"seating","waiting").success,"入座完成")
		_stage(id,"food",100)
	return sm.restaurant_customer_order(id)

func _depart(id: String) -> void:
	var phase: String = sm.restaurant_customer_order(id).get("phase","")
	if phase=="eating":
		sm.advance_restaurant_customer(id,"eating","farewell")
		sm.advance_restaurant_customer(id,"farewell","leaving")
	_check(sm.advance_restaurant_customer(id,"leaving","departed").success,"释放离场订单")

func _replenish() -> void:
	_fresh()
	_open({A:1})
	var first := _order(false)
	sm.data.restaurant_customers.front.remaining = 0.01
	_check(Cycle.tick(sm,0.02).success,"候客超时原罚额事务")
	_check(sm.gold_balance()==99 and sm.reputation()==99 and not Portions.complete(sm.data),"未接超时只扣原惩罚不消耗菜单")
	_depart(first.id)
	var second := _order()
	_check(second.item_id==A and Day.snapshot(sm).arrived==2,"超出菜单数仍补同菜顾客")
	_cook(A)
	_check(sm.deliver_restaurant_customer(second.id).success,"补客正确交付计售出")
	_check(Portions.complete(sm.data),"售出才消耗唯一份额")
	_depart(second.id)
	Cycle.arrive(sm)
	_check(Day.snapshot(sm).status=="closing" and Day.snapshot(sm).settlement.menu_sold==1,"售完不补客并正常打烊")
	_check(Review.review_text(Day.snapshot(sm).settlement).contains("全部售出"),"全售出评价")
	for stage in ["food","drink"]:
		_fresh()
		_open({A:1})
		var order := _order()
		_stage(order.id,stage,0.01)
		Cycle.tick(sm,0.02)
		_depart(order.id)
		_check(_order(false).get("item_id")==A,"等餐或等水超时释放额度 "+stage)

func _wrong_dish() -> void:
	_fresh()
	_open({A:1,B:1})
	var a := _order()
	var b := _order()
	_cook(B)
	var stock: Dictionary = sm.warehouse_snapshot()
	_check(sm.deliver_restaurant_customer(a.id).outcome=="wrong_dish","点A交B按实际B损耗")
	_check(sm.warehouse_snapshot()==stock and Portions.units(sm.data)[0].phase=="warehouse" and Portions.units(sm.data)[1].phase=="lost","误送不重复扣料且A仍未消耗")
	_check(sm.restaurant_customer_order(b.id).phase=="leaving","B额度已损耗时解除另一B订单不再消费")
	_depart(a.id)
	_depart(b.id)
	var next := _order()
	_check(next.item_id==A,"误送后仅A可以继续分配")
	_cook(A)
	sm.deliver_restaurant_customer(next.id)
	_depart(next.id)
	Cycle.arrive(sm)
	var stats: Dictionary = Day.snapshot(sm).settlement
	_check(stats.menu_sold==1 and stats.menu_lost==1 and stats.losses=={B:1},"A售出B损耗各一次")
	_check(Review.review_text(stats).contains("部分料理损耗"),"部分损耗评价")
	_fresh()
	_open({A:1})
	var order := _order()
	_cook(B)
	sm.deliver_restaurant_customer(order.id)
	_check(Portions.units(sm.data)[0].phase=="warehouse" and Day.snapshot(sm).dish_losses=={B:1},"菜单外B只计实物损耗不扣A份额")
	_depart(order.id)
	_check(_order(false).get("item_id")==A,"菜单外误送后A继续来客")

func _sources() -> void:
	for phase in ["warehouse","carried","cooking","dish","stored"]:
		_fresh()
		_open({A:2})
		if phase=="carried": sm.take_warehouse_items(Recipe.get_recipe(A).ingredients)
		elif phase in ["cooking","dish","stored"]: _cook(A,phase!="cooking")
		if phase=="stored": _check(sm.freezer_action("store",0,A,3).success,"菜单成品冷藏保留批次归属")
		var outside: int = sm.inventory_quantity("wood")
		_check(Cycle.settle(sm,"manual").success,"结束清理来源 "+phase)
		_check(sm.warehouse_snapshot().rock_salt==18 and sm.warehouse_snapshot().rockmane_meat==18,"各来源只扣总共两份原料 "+phase)
		_check(sm.inventory_quantity(A)==0 and sm.carried_ingredients().is_empty() and sm.freezer_snapshot().stored.is_empty(),"结束后归属物品清空 "+phase)
		_check(sm.cooking_state().status!="active" and sm.inventory_quantity("wood")==outside,"进行中锅不能再次起锅且菜单外物品保留")
		_check(Day.snapshot(sm).settlement.menu_lost==2 and Review.review_text(Day.snapshot(sm).settlement).contains("料理都损耗"),"全损耗份额与评价")
		var after: Dictionary = sm.data.duplicate(true)
		Cycle.settle(sm,"time")
		_check(sm.data==after,"重复结束不重复扣料")
	# 开业前已有物品按真实来源匹配，无需再备一份仓库原料。
	for phase in ["carried","cooking","dish","stored"]:
		_fresh()
		if phase=="carried": sm.take_warehouse_items(Recipe.get_recipe(A).ingredients)
		else: _cook(A,phase!="cooking")
		if phase=="stored": sm.freezer_action("store",0,A,3)
		sm.data.warehouse_stock.rock_salt = 0
		sm.data.warehouse_stock.rockmane_meat = 0
		_check(Day.validate_menu(sm,{A:1}).success,"菜单UI校验接受已有来源 "+phase)
		_open({A:1})
		_check(Cycle.settle(sm,"manual").success and Day.snapshot(sm).settlement.menu_lost==1,"已有来源结束不二扣原料 "+phase)
	# 共享蟹肉的两种菜，菜单外选料不得抢走预留。
	_fresh()
	sm.data.warehouse_stock.mimic_crab_meat = 1
	_check(not Day.validate_menu(sm,{"bird_nest_crab":1,"mimic_crab_gratin":1}).success,"共享原料合计不足拒绝菜单")
	_open({"bird_nest_crab":1})
	var before: Dictionary = sm.data.duplicate(true)
	_check(not sm.take_warehouse_items(Recipe.get_recipe("mimic_crab_gratin").ingredients).success and sm.data==before,"菜单外不能抢用共享预留原料")
	# 一份菜单冷藏和额外同菜冷藏/异菜库存，结束只按具体批次清理。
	_fresh()
	_cook(A)
	sm.freezer_action("store",0,A,3)
	_cook(A)
	sm.freezer_action("store",0,A,3)
	_cook(B)
	sm.freezer_action("store",0,B,3)
	_open({A:1})
	_check(Cycle.settle(sm,"manual").success,"同菜多批次只销毁所绑定份额")
	_check(sm.freezer_snapshot().stored.size()==2 and sm.freezer_snapshot().stored[0].id==2 and sm.freezer_snapshot().stored[1].recipe_id==B,"额外同菜及菜单外成品完整保留")
	# 丢弃、冷藏丢弃、取出后交付沿同一账本。
	for phase in ["carried","dish","stored"]:
		_fresh()
		_open({A:1})
		if phase=="carried": sm.take_warehouse_items(Recipe.get_recipe(A).ingredients)
		else: _cook(A)
		if phase=="stored":
			sm.freezer_action("store",0,A,3)
			sm.freezer_action("discard",sm.freezer_snapshot().stored[0].id)
		else: sm.discard_carried_food(sm.discardable_carried_items())
		_check(Portions.complete(sm.data),"已丢弃原料/料理不再出售 "+phase)
		Cycle.settle(sm,"manual")
		_check(Day.snapshot(sm).settlement.losses=={A:1} and sm.warehouse_snapshot().rock_salt==19,"丢弃只计一次不再次扣料")

func _same_recipe_orders() -> void:
	_fresh()
	_open({A:2})
	var first := _order()
	var second := _order()
	_cook(A)
	_check(sm.deliver_restaurant_customer(second.id).success,"同菜后接订单先上菜")
	_check(sm.restaurant_customer_order(first.id).phase=="waiting" and Portions.units(sm.data)[0].phase=="warehouse" and Portions.units(sm.data)[1].phase=="sold","交换实际来源后只消耗后接订单配额")
	_cook(A)
	_check(sm.deliver_restaurant_customer(first.id).success and Portions.complete(sm.data),"先接顾客仍能正常上菜不无故离场")
	_fresh()
	_open({A:1,B:2})
	var a := _order()
	var b := _order()
	_cook(B)
	sm.deliver_restaurant_customer(a.id)
	_check(sm.restaurant_customer_order(b.id).phase=="waiting" and Portions.units(sm.data)[1].phase=="warehouse" and Portions.units(sm.data)[2].phase=="lost","误送优先备用B份额并保留已绑定B顾客")
	_cook(B)
	_check(sm.deliver_restaurant_customer(b.id).success,"误送后另一B订单仍能真实交付")

func _atomic_and_legacy() -> void:
	_fresh()
	_rollback(func(): return Cycle.open_with_menu(sm,{A:2}),"开业预留保存失败全量回滚")
	_open({A:2})
	_rollback(func(): return sm.take_warehouse_items(Recipe.get_recipe(A).ingredients),"取料归属保存失败回滚")
	sm.take_warehouse_items(Recipe.get_recipe(A).ingredients)
	_rollback(func(): return sm.start_cooking(A),"起锅归属保存失败回滚")
	sm.start_cooking(A)
	sm.save()
	sm.load_data()
	_check(Portions.units(sm.data)[0].phase=="dish" and sm.inventory_quantity(A)==1,"锅中读档恢复成品同步归属")
	_rollback(func(): return sm.freezer_action("store",0,A,1),"冷藏归属保存失败回滚")
	_rollback(func(): return Cycle.settle(sm,"time"),"结束销毁归属及账务保存失败回滚")
	_check(Cycle.settle(sm,"time").success and sm.warehouse_snapshot().rock_salt==18,"锅中读档结束仅扣两份")
	_fresh()
	_open({A:1})
	sm.data.warehouse_stock.rock_salt = 0
	var before: Dictionary = sm.data.duplicate(true)
	_check(Cycle.settle(sm,"manual").get("reason")=="portion_inventory_mismatch" and sm.data==before,"新账缺库存原子拒绝不造负数物品")
	_fresh()
	_open({A:1})
	sm.data[Day.KEY].erase("portions")
	sm.data[Day.KEY].erase("portions_revision")
	var stock: Dictionary = sm.warehouse_snapshot()
	_check(Cycle.settle(sm,"manual").success and sm.warehouse_snapshot()==stock,"旧档无归属证据不追加猜测扣料")
	_check(Review.review_text(Day.snapshot(sm).settlement).contains("旧存档"),"旧不完整回执明确兼容提示")
	for corrupt in ["duplicate","recipe","phase","quality","count","missing"]:
		_fresh()
		_open({A:2})
		match corrupt:
			"duplicate": sm.data[Day.KEY].portions[1].id = 1
			"recipe": sm.data[Day.KEY].portions[0].recipe = "unknown"
			"phase": sm.data[Day.KEY].portions[0].phase = "unknown"
			"quality": sm.data[Day.KEY].portions[0].quality = "bad"
			"count": sm.data[Day.KEY].menu[A] = 3
			"missing": sm.data[Day.KEY].portions[0].erase("freezer_id")
		before = sm.data.duplicate(true)
		_check(not Cycle.tick(sm,1).success and not Cycle.arrive(sm).success and not Cycle.settle(sm,"manual").success and sm.data==before,"损坏份额结构明确拒绝不崩溃 "+corrupt)

func _real_business(sold: int) -> void:
	_fresh()
	_open({A:2})
	var hud = await _open_restaurant()
	var player = hud._player
	var sign = hud.find_child("RestaurantDaySign",true,false)
	await get_tree().create_timer(0.8).timeout
	for n in sold:
		sm.data[Day.KEY].arrival_left = 0.0
		await _wait_until(func(): return sm.restaurant_customers().front.get("phase")=="front",150)
		var id: String = sm.restaurant_customers().front.get("id","")
		player.position = _stand(scene.get_node("InteractPoints/Register"))
		player.last_valid = player.position
		await _send_key(KEY_E)
		await _wait_until(func(): return sm.restaurant_customer_order(id).get("phase")=="waiting",150)
		_stage(id,"food",100)
		player.position = _stand(scene.get_node("InteractPoints/Store"))
		player.last_valid = player.position
		await _send_key(KEY_E)
		var warehouse = scene.get_node("UIOverlay/WarehouseModal")
		_check(warehouse.visible,"实际E打开仓库逐单选料")
		await _click(warehouse._slot_by_id["rockmane_meat"]._icon_button)
		await _click(warehouse._slot_by_id["rock_salt"]._icon_button)
		await _click(warehouse._claim_button)
		_check(not warehouse.visible and sm.carried_ingredients()==Recipe.get_recipe(A).ingredients,"仓库实际逐格选料确认与预留兼容")
		_check(sm.start_cooking(A).success and sm.finish_first_order_cooking(3).success,"实际料理事务扣料成品归属")
		player.position = Three.service_point(int(sm.restaurant_customer_order(id).seat))
		player.last_valid = player.position
		await _send_key(KEY_E)
		_check(sm.restaurant_customer_order(id).get("outcome")=="served","真实餐厅E上菜成功")
		await _wait_until(func(): return sm.restaurant_customer_order(id).is_empty(),240)
	if sold<2:
		var before: Dictionary = Day.snapshot(sm)
		await _click(sign.end_button)
		_check(sign.end_confirmation.visible and player.input_locked,"营业牌主动结束进入共用确认")
		await _shot("rest05b_manual_confirm_"+str(sold))
		await _click(sign.end_confirmation.cancel_button)
		_check(Day.snapshot(sm).status=="open" and not player.input_locked and Day.snapshot(sm).portions==before.portions,"取消结束不改变份额恢复输入")
		await _click(sign.end_button)
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		await _click(sign.end_confirmation.confirm_button)
		_check(sign.end_confirmation.visible and Day.snapshot(sm).status=="open","主动结束保存失败可重试")
		sm._active_save_path = path
		await _click(sign.end_confirmation.confirm_button)
	await _wait_until(func(): return is_instance_valid(hud.day_settlement) and hud.day_settlement.visible,180)
	var modal = hud.day_settlement
	_check(is_instance_valid(modal),"实际经营进入结算")
	if is_instance_valid(modal):
		await get_tree().create_timer(0.9).timeout
		_check(modal.review.text==Review.review_text(Day.snapshot(sm).settlement),"实际三分支评价 "+str(sold))
		await _shot("rest05b_result_sold_"+str(sold))
		await _click(modal._confirm_button)
		_check(Day.snapshot(sm).day==2 and not player.input_locked,"结算确认后进入下一天")
	await _close_restaurant()

func _existing_menu_ui() -> void:
	_fresh()
	_cook(A)
	sm.freezer_action("store",0,A,3)
	sm.data.warehouse_stock.rock_salt = 0
	sm.data.warehouse_stock.rockmane_meat = 0
	var hud = await _open_restaurant()
	await get_tree().create_timer(0.2).timeout
	hud._open_day_menu()
	var menu = hud.day_menu
	_check(menu.visible and menu.list.has_node("Recipe_"+A),"仓库零原料但有冷藏成品时菜单UI仍列该菜")
	var checkbox: Control = menu.list.get_node("Recipe_"+A+"/RecipeRow").get_child(0)
	# 新建容器先完成布局，再按真实控件位置滚动。
	await get_tree().process_frame
	await get_tree().process_frame
	menu.scroll.ensure_control_visible(checkbox)
	await get_tree().process_frame
	await get_tree().process_frame
	await _click(checkbox)
	_check(menu.draft.get(A,0)==1,"实际勾选现有冷藏料理菜单")
	await _shot("rest05b_existing_menu_selected")
	await _click(menu.confirm_button)
	_check(Day.snapshot(sm).get("status")=="open" and not Portions.units(sm.data).is_empty() and Portions.units(sm.data)[0].phase=="stored","真实菜单确认绑定现有冷藏成品")
	await _shot("rest05b_existing_menu")
	await _close_restaurant()
