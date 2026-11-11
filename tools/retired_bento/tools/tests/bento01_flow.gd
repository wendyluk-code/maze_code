extends "res://tools/tests/yf03_lifecycle.gd"
var mouse_evidence: Array=[]
const Freezer = preload("res://scripts/restaurant/freezer_store.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"便当验收隔离正式档")
	if failures==0:
		if OS.get_environment("BENTO01_PHASE") in ["seed","restore"]:
			_restart(OS.get_environment("BENTO01_PHASE"))
			_report()
			return
		if OS.get_environment("BENTO01_PHASE")=="concurrent":
			await _concurrent()
			_report()
			return
		_edges()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d"%[resolution.x,resolution.y]
			await _assembly_flow()
		await _concurrent()
	_report()

func _report() -> void:
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":ProjectSettings.globalize_path("user://"),"mouse_events":mouse_evidence},"\t"))
	get_tree().quit(1 if failures else 0)

func _restaurant() -> void:
	_setup("done")
	_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"赠礼后真实返回餐厅")
	for slot in Bento.GIFTS: _check(Bento.discard(sm,slot).success,"清理初始赠礼用于备餐："+slot)

func _unit(id: String, quality: int, remaining: int = 600000) -> Dictionary:
	var p: Dictionary=sm.prepared_dishes_snapshot()
	sm.data.inventory[id]=sm.inventory_quantity(id)+1
	p[id][str(quality)]+=1
	sm.data.prepared_dishes=p
	_check(sm.freezer_action("store",0,id,quality).success,"夹具成品经真实入柜："+id)
	var ledger: Dictionary=sm.data[Freezer.KEY]
	ledger.stored[-1].expires_at=int(Time.get_unix_time_from_system())+remaining
	return ledger.stored[-1].duplicate(true)

func _reject(choices: Dictionary, reason: String) -> void:
	var before: Dictionary=sm.data.duplicate(true)
	var result: Dictionary=Bento.assemble(sm,choices)
	_check(not result.success and sm.data==before,reason+"：整个库存/便当/计时不变")

func _edges() -> void:
	_restaurant()
	var a:=_unit("thunder_eel_roll",1)
	var h:=_unit("cool_slime_jelly",2)
	var d:=_unit("salt_crust_silverfish",3)
	var order:=_unit(sm.FIRST_ORDER_ITEM_ID,3)
	_reject({"attack":order.id},"订单菜不能装配")
	_reject({"attack":h.id},"维度不匹配")
	_reject({"attack":a.id,"health":a.id},"同份不可重复")
	_reject({"attack":a.id,"health":99999},"第二份消失时不能先扣第一份")
	_reject({"attack":1.5},"非整数编号")
	var original_run: Variant=sm.data.get(Bento.RUN_KEY,{})
	for invalid in [false,42,[],null]:
		sm.data[Bento.RUN_KEY]=invalid
		_reject({"attack":a.id},"坏探索记录安全拒绝")
	sm.data[Bento.RUN_KEY]=original_run
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_reject({"attack":a.id,"health":h.id},"写盘失败原子回滚")
	sm._active_save_path=path
	sm.data[Freezer.KEY].stored[1].expires_at=int(Time.get_unix_time_from_system())
	_reject({"attack":a.id,"health":h.id},"到期瞬间保存整批拒绝")
	_check(sm.freezer_snapshot().stored.size()==4,"腐坏保留在冰柜")
	sm.data[Freezer.KEY].stored[1].expires_at=h.expires_at
	sm.data[Bento.KEY].unlocked=false
	_reject({"attack":a.id},"未解锁拒绝")
	sm.data[Bento.KEY].unlocked=true
	_check(Run.begin(sm,Roads.SPAWN).success,"出发阻止装配")
	_reject({"attack":a.id},"迷宫不得装配")
	_check(Run.finish(sm,false,Roads.SPAWN).success,"放弃探索返回")
	var inv: Dictionary=sm.inventory_snapshot()
	_check(Bento.assemble(sm,{"attack":a.id,"health":h.id,"defense":d.id}).success,"三维度一次真实装配")
	_check(sm.inventory_snapshot()==inv and sm.freezer_snapshot().stored.size()==1,"直接扣stored不经过携带库存")
	_check(Bento.snapshot(sm).slots.attack.stars==1 and Bento.snapshot(sm).slots.health.stars==2 and Bento.snapshot(sm).slots.defense.stars==3,"不同星级准确保存")
	_reject({"attack":order.id},"保存格不能换选")
	_check(not Bento.eat(sm).success,"餐厅不能食用")
	sm.load_data()
	_check(Bento.snapshot(sm).slots.size()==3 and sm.freezer_snapshot().stored.size()==1,"持久恢复不重复扣柜")

func _assembly_flow() -> void:
	_restaurant()
	maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.5).timeout
	scene=maze
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	var player=maze.get_node("Player")
	for slot in ["health","defense","attack"]:
		var id: String=Bento.GIFTS[slot]
		var ingredients: Dictionary=Bento.Catalog.get_recipe(id).ingredients
		sm.data.warehouse_stock=ingredients.duplicate()
		_check(sm.take_warehouse_items(ingredients).success,"取出真实配方原料："+id)
		player.global_position=_stand(maze.get_node("InteractPoints/Cauldron"))
		player.last_valid=player.global_position
		await _send_key(KEY_E)
		var cooking=get_tree().get_first_node_in_group("cooking_modal")
		_check(cooking.visible and cooking.recipe_id==id,"真实料理台选择探索配方："+id)
		if id=="salt_crust_silverfish": await _capture_image("silverfish_ingredient_cooking")
		if cooking._lesson_paused: await _send_key(KEY_E)
		await _click(cooking._start_button)
		await get_tree().create_timer(5.9).timeout
		_check(sm.inventory_quantity(id)==1,"真实烹饪成品："+id)
		for ingredient in ingredients: _check(sm.inventory_quantity(ingredient)==0,"实际扣除原料："+ingredient)
		_check(sm.freezer_carried_options()[0].expires_at==0,"新成品尚未开始七天计时")
		for i in 4:
			if not cooking.visible: break
			await _send_key(KEY_E)
			await get_tree().create_timer(0.15).timeout
		player.global_position=_stand(maze.get_node("InteractPoints/Fridge"))
		player.last_valid=player.global_position
		await _send_key(KEY_E)
		_check(hud.freezer.visible,"真实冰柜入口打开")
		await _click(hud.freezer.held.get_node("StoreDish"))
		_check(sm.inventory_quantity(id)==0,"成品真实存柜："+id)
		await _capture_image("cooked_stored_"+slot)
		await _send_key(KEY_ESCAPE)
	for i in 8: _unit("cool_slime_jelly",i%3+1,3600*(i+1))
	sm.save()
	await _click(hud.bento_entry)
	var page=hud.bento_modal
	_check(page.visible and player.input_locked,"餐厅真实便当入口与输入锁")
	await _click(page.tiles.health)
	await _capture_image("prepare_top")
	_check(page.right_scroll.get_v_scroll_bar().visible,"具体份列表有可见滑块")
	var bar=page.right_scroll.get_v_scroll_bar()
	await _click(bar)
	await _scroll_bottom(page.right_scroll)
	await get_tree().process_frame
	_check(page.right_scroll.scroll_vertical>0,"右栏实际滚到末项")
	var scroll_before: int=page.right_scroll.scroll_vertical
	await get_tree().create_timer(1.2).timeout
	_check(page.right_scroll.scroll_vertical==scroll_before,"滚动后停留跨刷新节拍保持位置")
	var last=page.details.get_child(page.details.get_child_count()-1)
	var id: int=int(last.name.trim_prefix("Unit_"))
	await _click(last.find_child("SelectUnit",true,false))
	_check(page.draft.has("health") and int(page.draft.health.id)==id,"末项实际点击按具体份暂选")
	_check(sm.freezer_snapshot().stored.size()==11,"暂选不扣冰柜")
	await _capture_image("prepare_last_selected")
	await _click(page.tiles.health.get_node("CancelDraft"))
	_check(page.draft.is_empty() and sm.freezer_snapshot().stored.size()==11,"草稿叉号取消不扣柜")
	page.right_scroll.scroll_vertical=0
	await get_tree().process_frame
	await _click(page.details.find_child("SelectUnit",true,false))
	await _send_key(KEY_ESCAPE)
	_check(page.confirmation.visible and page.confirmation.question.text=="放弃本次未保存的选择？","关闭草稿显示准确确认")
	await _capture_image("discard_changes")
	await _click(page.confirmation.cancel_button)
	_check(page.draft.size()==1 and page.visible and player.input_locked,"继续装配保留草稿与锁")
	await _send_key(KEY_ESCAPE)
	await _send_key(KEY_ESCAPE)
	_check(not page.confirmation.visible and page.visible and page.draft.size()==1,"Esc按层返回不丢草稿")
	await _send_key(KEY_ESCAPE)
	await _click(page.confirmation.confirm_button)
	_check(not page.visible and page.draft.is_empty() and not player.input_locked and sm.freezer_snapshot().stored.size()==11,"放弃选择不扣料理并恢复输入")
	await _click(hud.bento_entry)
	for slot in ["attack","health","defense"]:
		await _click(page.tiles[slot])
		await _click(page.details.find_child("SelectUnit",true,false))
	_check(page.draft.size()==3,"三格本地草稿")
	var chosen: Dictionary=page.draft.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	await _click(page.assemble_button)
	_check(page.draft.size()==3 and sm.freezer_snapshot().stored.size()==11 and Bento.snapshot(sm).slots.is_empty(),"真实保存按钮写盘失败保留全部")
	sm._active_save_path=path
	await _click(page.assemble_button)
	_check(page.draft.is_empty() and Bento.snapshot(sm).slots.size()==3 and sm.freezer_snapshot().stored.size()==8,"真实保存按钮一次扣三份")
	for unit in chosen.values(): _check(sm.freezer_snapshot().stored.all(func(u): return int(u.id)!=int(unit.id)),"仅删除所选具体份")
	_check(page.tiles.attack.get_node_or_null("CancelDraft")==null,"保存格不能当草稿取消")
	await _capture_image("saved")
	await _click(page.tiles.defense.get_node("DiscardSaved"))
	await _click(page.confirmation.cancel_button)
	_check(Bento.snapshot(sm).slots.has("defense"),"已保存垃圾桶取消保留")
	await _click(page.tiles.defense.get_node("DiscardSaved"))
	await _click(page.confirmation.confirm_button)
	_check(not Bento.snapshot(sm).slots.has("defense") and sm.freezer_snapshot().stored.size()==8,"确认丢弃绝不退回冰柜")
	await _send_key(KEY_ESCAPE)
	maze.queue_free()
	await get_tree().process_frame
	_check(Run.begin(sm,Roads.SPAWN).success,"带装配便当真实出征")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	await _click(maze.bento_entry)
	page=maze.bento_modal
	_check(not page.assemble_button.visible and page.all_button.visible,"迷宫无添加装配")
	await _click(page.tiles.attack)
	await _click(page.details.get_node("EatButton"))
	_check(Bento.snapshot(sm).slots.attack.eaten and not Bento.snapshot(sm).slots.health.eaten,"实际吃一份保留未食")
	await _capture_image("maze_eaten_and_uneaten")
	await _send_key(KEY_ESCAPE)
	maze.queue_free()
	await get_tree().process_frame
	_check(Run.finish(sm,false,Roads.SPAWN).success,"实际返程")
	_check(Bento.snapshot(sm).slots.size()==1 and Bento.snapshot(sm).slots.has("health") and not Run.snapshot(sm).has("bento"),"返回清已食与效果、保留未食")
	sm.load_data()
	_check(Run.begin(sm,Roads.SPAWN).success and not Run.snapshot(sm).has("bento"),"再次出发不重复叠加")
	_check(Run.finish(sm,false,Roads.SPAWN).success,"再次返回保留未食")


func _concurrent() -> void:
	_restaurant()
	var a:=_unit("thunder_eel_roll",2)
	var h:=_unit("cool_slime_jelly",3)
	var next:=_unit("cool_slime_jelly",1)
	maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	await _click(hud.bento_entry)
	var page=hud.bento_modal
	await _click(page.tiles.attack)
	await _click(page.details.find_child("SelectUnit",true,false))
	await _click(page.tiles.health)
	await _click(page.details.find_child("SelectUnit",true,false))
	var second=page.details.get_child(page.details.get_child_count()-1).find_child("SelectUnit",true,false)
	page.right_scroll.ensure_control_visible(second)
	await get_tree().process_frame
	await _click(second)
	_check(int(page.draft.health.id)==int(next.id) and page.draft.size()==2 and sm.freezer_snapshot().stored.size()==3,"同格不先取消也可换选且不扣库存")
	var first=page.details.find_child("SelectUnit",true,false)
	page.right_scroll.ensure_control_visible(first)
	await get_tree().process_frame
	await _click(first)
	_check(int(page.draft.health.id)==int(h.id),"草稿可换回原具体份")
	sm.data[Freezer.KEY].stored[1].expires_at=int(Time.get_unix_time_from_system())+1
	await get_tree().create_timer(1.2).timeout
	await _click(page.assemble_button)
	_check(sm.freezer_snapshot().stored.size()==3 and Bento.snapshot(sm).slots.is_empty() and page.draft.size()==2,"暂选期间真实时钟到期，整批保存安全拒绝")
	await _click(page.tiles.health.get_node("CancelDraft"))
	var cards=page.details.find_children("SelectUnit","Button",true,false)
	_check(cards[0].disabled,"过期卡不自动消失且不能再装")
	page.right_scroll.ensure_control_visible(cards[1])
	await get_tree().process_frame
	await _click(cards[1])
	_check(int(page.draft.health.id)==int(next.id),"过期后可重新选择另一份")
	_check(sm.freezer_action("withdraw",int(next.id)).success,"外部实际取出暂选份")
	await _click(page.assemble_button)
	_check(Bento.snapshot(sm).slots.is_empty() and page.draft.size()==2 and sm.inventory_quantity(next.recipe_id)==1,"暂选份被取出时整批拒绝")
	_check(sm.freezer_action("store",int(next.id),next.recipe_id,int(next.quality)).success,"外部原份再存回")
	_check(sm.freezer_snapshot().stored[-1].expires_at==next.expires_at,"并发取出再存原期限不变")
	_check(sm.freezer_action("discard",int(next.id)).success,"外部实际丢弃暂选份")
	await _click(page.assemble_button)
	_check(Bento.snapshot(sm).slots.is_empty() and sm.freezer_snapshot().stored.size()==2 and page.draft.has("attack"),"并发丢弃后不丢其他暂选份")
	await _click(page.tiles.health.get_node("CancelDraft"))
	await _click(page.assemble_button)
	_check(Bento.snapshot(sm).slots.attack.stars==2 and sm.freezer_snapshot().stored.size()==1,"取消失效份后剩余草稿可正常保存")
	await _capture_image("concurrent_recovered")
	await _send_key(KEY_ESCAPE)
	maze.queue_free()
	await get_tree().process_frame

func _restart(phase: String) -> void:
	if phase=="seed":
		_restaurant()
		var a:=_unit("thunder_eel_roll",2)
		var h:=_unit("cool_slime_jelly",1)
		_unit("salt_crust_silverfish",3,1)
		_check(Bento.assemble(sm,{"attack":a.id,"health":h.id}).success,"跨进程装配保存")
		sm._active_save_path="user://bento01-cross.json"
		_check(sm.save(),"跨进程独立文件保存")
	else:
		sm._active_save_path="user://bento01-cross.json"
		sm.load_data()
		_check(Bento.snapshot(sm).slots.attack.stars==2 and Bento.snapshot(sm).slots.health.stars==1,"独立进程恢复真实装配星级")
		_check(sm.freezer_snapshot().stored.size()==1,"独立进程不重复扣库存")
		var unit: Dictionary=sm.freezer_snapshot().stored[0]
		_check(int(unit.expires_at)<=int(Time.get_unix_time_from_system()),"进程关闭期间绝对时钟仍到期")
		_reject({"defense":unit.id},"重进腐坏不得装配")
		_check(not sm.freezer_action("withdraw",int(unit.id)).success,"重进腐坏不得取出")
		_check(Run.begin(sm,Roads.SPAWN).success,"独立恢复后真实出征")
		_check(Bento.eat(sm,"attack").success and Run.snapshot(sm).bento.attack==2,"恢复后食用真实二星效果")
		_check(Run.finish(sm,false,Roads.SPAWN).success,"跨进程返程")
		_check(Bento.snapshot(sm).slots.size()==1 and Bento.snapshot(sm).slots.has("health"),"跨进程已食清理未食保留")


func _click(control: Control) -> void:
	mouse_evidence.append({"target":str(control.get_path()),"rect":str(control.get_global_rect()),"resolution":str(get_window().size)})
	await super._click(control)

func _scroll_bottom(scroll: ScrollContainer) -> void:
	var point := scroll.get_global_rect().get_center()
	get_viewport().warp_mouse(point)
	for i in 80:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_WHEEL_DOWN
		event.position=point
		event.pressed=true
		get_viewport().push_input(event)
		event=event.duplicate()
		event.pressed=false
		get_viewport().push_input(event)
		await get_tree().process_frame
		if scroll.scroll_vertical>=scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page-1: break
	mouse_evidence.append({"wheel_position":str(point),"scroll_vertical":scroll.scroll_vertical,"resolution":str(get_window().size)})
