extends "res://tools/tests/maze_capture.gd"
const Gate := preload("res://scripts/maze/first_exploration.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	if failures==0:
		_completed()
		sm.complete_chapter_1()
		tm.active = false
		_check(Gate.departure(sm),"首章结束必须先探索")
		_check(not sm.freezer_unlocked(),"首次探索完成前冰柜保持锁定")
		var restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(restaurant)
		get_tree().current_scene = restaurant
		await get_tree().create_timer(0.6).timeout
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		var sign = restaurant.find_child("RestaurantDaySign",true,false)
		_check(not sign.is_visible_in_tree(),"首次探索完成前营业牌整体隐藏")
		# 战败返回仍是active标记；在同一餐厅验证显示条件不被已探索字段绕过。
		var before_sign: Dictionary = sm.data.duplicate(true)
		sm.data[Gate.KEY] = "active"
		sm.data[Run.SEEN] = true
		sign._process(0)
		_check(not sign.visible,"战败返回的未完成教学仍隐藏营业牌")
		sm.data = before_sign
		_check(hud.exploration_guide.guide.hint_label.text=="前往迷宫探索","仅显示确认后的常驻文案")
		_check(not hud.exploration_guide.allows_world_interaction("冰柜") and hud.exploration_guide.allows_world_interaction("迷宫入口"),"只开放迷宫入口")
		hud._open_day_menu()
		_check(not hud.day_menu.visible,"提前开业被拦截")
		var tracker = get_tree().get_first_node_in_group("order_tracking")
		await _click(tracker._task_button)
		_check(tracker._expanded and tracker._panel.is_visible_in_tree(),"前往迷宫提示期间鼠标可展开当前任务")
		await _click(tracker._task_button)
		_check(not tracker._expanded,"再次点击当前任务可收起")
		await _shot_gate("departure")
		restaurant.queue_free()
		await get_tree().process_frame
		_check(Run.begin(sm,Roads.SPAWN).success,"首次进入")
		_check(Gate.pending(sm),"首次标记写入")
		sm.save()
		sm.load_data()
		_check(Gate.pending(sm),"退出重进不绕过")
		var before_death: Dictionary = sm.data.duplicate(true)
		sm.data[Run.KEY].combat.hp = 0
		_check(Run.finish(sm,false,Roads.SPAWN).success and Gate.pending(sm),"战败可按原规则返回但教学未完成")
		_check(not sm.freezer_unlocked(),"首次战败返程不解锁冰柜")
		_check(Run.begin(sm,Roads.SPAWN).success and Gate.pending(sm),"战败重进仍保留首次限制")
		sm.data = before_death
		_check(not Run.finish(sm,false,Roads.SPAWN).success,"禁止放弃返回")
		_check(not Run.finish(sm,true,Vector2(116,724)).success,"未接任务禁止结束")
		for id in ["slime_1","snail_1","beetle_1"]:
			var run: Dictionary = sm.data[Run.KEY]
			run.monsters[id].capture_roll = 0.999
			run.combat.actors[id].hp = 0
			_check(Run.defeat(sm,id,Run.monster_for(run,id).position).success,"真实击败事务"+id)
			_check(Run.start_capture(sm,id).success,"支付捕获消耗"+id)
			Run.finish_capture(sm,id,false)
			_check(Run.resolve(sm,id,true).get("caught",false),"未按J且概率未命中仍成功"+id)
		# 地图实际入口检查；关闭已验证过的其他探索教学以聚焦本次门禁。
		sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"revision":2}
		maze = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.7).timeout
		maze._open_confirmation("餐厅")
		_check(not maze.confirmation.visible,"地图返回按钮不打开返回确认")
		maze.player.position = Vector2(116,724)
		for actor in sm.data[Run.KEY].combat.actors.values():
			actor.mode = "idle"
		sm.data[Run.KEY].combat.shots = []
		sm.data[Run.KEY].combat.enemy_shots = []
		await get_tree().process_frame
		maze._open_confirmation("下一区域")
		_check(maze.confirmation.visible and maze.confirmation.confirm_button.disabled,"下一地区按钮置灰",{"ready":maze._entry_ready,"locked":maze.player.input_locked,"near":maze._near_destination(),"region":sm.maze_exploration_state()})
		await _shot_gate("next_disabled")
		maze._close_confirmation()
		var elder_point := Vector2(839,503)
		var accepted: Dictionary = sm.accept_elder_firewood(elder_point)
		_check(accepted.success,"原白虎任务可接取",accepted)
		sm.data[sm.INVENTORY_KEY]["wood"] = 12
		_check(not Run.finish(sm,true,Vector2(116,724)).success,"完成采集未交任务仍拦截")
		_check(sm.deliver_elder_firewood(elder_point).success,"原交付与奖励事务不变")
		_check(sm.data.get("exploration_task_loot",{}).get("moondew_honey",0)==3,"任务奖励记录本趟结算回执")
		maze.queue_free()
		await get_tree().process_frame
		_check(Gate.return_message(sm,true).is_empty(),"领奖后允许结束")
		var before: Dictionary = sm.data.duplicate(true)
		var save_path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not Run.finish(sm,true,Vector2(116,724)).success and sm.data==before,"结算失败不解除门禁不重复入仓")
		sm._active_save_path = save_path
		_check(Run.finish(sm,true,Vector2(116,724)).success,"成功结算返程")
		_check(not Gate.pending(sm) and sm.data.first_business_intro_pending,"入仓后解除首次门禁并排队经营教学")
		_check(sm.yufeng_salia_state()!="done" and sm.freezer_unlocked(),"未完成御风剧情也在首次成功返程解锁冰柜")
		_check(sm.warehouse_snapshot().get("slime_shell",0)>0 and sm.warehouse_snapshot().get("moondew_honey",0)>=3,"真实捕获与任务奖励组成可经营配方")
		var returned: Dictionary = preload("res://scripts/restaurant/restaurant_day.gd").pending_loot(sm)[0]
		_check(returned.get("slime_shell",0)>0 and returned.get("moondew_honey",0)==3 and returned.get("cooking_sake",0)==3 and returned.get("sour_vine_juice",0)==3,"结算同时包含捕获和三种任务食材")
		_check(sm.data.get("exploration_task_loot",{}).is_empty(),"已结算任务回执清空")
		sm.save()
		sm.load_data()
		var restored: Dictionary = preload("res://scripts/restaurant/restaurant_day.gd").pending_loot(sm)[0]
		var same_items := restored.size()==returned.size()
		for id in returned: same_items = same_items and int(restored.get(id,-1))==int(returned[id])
		_check(same_items,"退出重进保留未确认结算",{"before":returned,"after":restored})
		restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(restaurant)
		get_tree().current_scene = restaurant
		await get_tree().create_timer(0.7).timeout
		hud = get_tree().get_first_node_in_group("restaurant_hud")
		_check(is_instance_valid(hud.return_loot) and hud.return_loot.visible,"返店先显示带回食材结算")
		_check(hud.return_loot._confirm_button.text=="确认","结算底部统一确认按钮")
		var two_group_height: float = hud.return_loot._panel.size.y
		_check(hud.return_loot._grid.get_child_count()==2 and hud.return_loot._grid.get_child(0).name=="CaptureGroup" and hud.return_loot._grid.get_child(1).name=="TaskGroup","捕获在上任务在下分组展示")
		var categories: Dictionary = preload("res://scripts/restaurant/restaurant_day.gd").loot_groups(sm,restored)
		_check(categories.capture.get("slime_shell",0)>0 and categories.task.get("moondew_honey",0)==3 and not categories.capture.has("moondew_honey"),"读档后保留真实食材来源")
		_check(not hud.exploration_guide.reading and not hud.day_menu.visible,"结算确认前不抢先显示教学或菜单")
		var stock_before: Dictionary = sm.warehouse_snapshot()
		await _shot_gate("return_loot")
		sm._active_save_path = ""
		hud.return_loot.close_modal()
		_check(hud.return_loot.visible and preload("res://scripts/restaurant/restaurant_day.gd").pending_loot(sm).size()==1,"确认保存失败保留结算可重试")
		sm._active_save_path = save_path
		await _click(hud.return_loot._confirm_button)
		await get_tree().create_timer(0.3).timeout
		_check(sm.warehouse_snapshot()==stock_before,"确认结算不重复发放材料")
		_check(hud.exploration_guide.reading and hud.exploration_guide.lesson_id=="first_business_intro","返程自动出现经营教学")
		_check(restaurant.find_child("RestaurantDaySign",true,false).is_visible_in_tree(),"首次成功结算返程后显示营业牌")
		await _shot_gate("business_intro")
		hud.exploration_guide._read_done()
		await get_tree().create_timer(0.2).timeout
		_check(hud.day_menu.visible,"确认经营提示后进入菜单")
		_check(hud.ganlu.freezer_view.visible,"首次经营地图显示新三格冰镇UI")
		var Ganlu := preload("res://scripts/restaurant/ganlu_service.gd")
		_check(Ganlu.begin(sm).success and Ganlu.finish(sm,0.8).success and Ganlu.slot(sm,0).success,"无御风剧情可倒水并放入冰柜")
		Ganlu.tick(sm,3.0)
		_check(Ganlu.grade(Ganlu.snapshot(sm).slots[0])==1 and Ganlu.slot(sm,0).success,"新解锁冰柜能冰镇并取出")
		Ganlu.discard(sm)
		_check(sm.freezer_action("invalid").get("reason")!="story_locked","料理冷藏不再有御风剧情锁")
		sm.acknowledge_freezer_notice()
		_check(hud.day_menu.list.get_child_count()>0 and preload("res://scripts/restaurant/restaurant_day.gd").validate_menu(sm,{"slime_candy":1}).success,"首次奖励和捕获食材能形成可开业菜单")
		await _shot_gate("cookable_menu")
		_check(is_instance_valid(hud.day_menu.list.get_node_or_null("Recipe_slime_candy")),"真实菜单存在史莱姆冻行")
		hud.day_menu.draft = {"slime_candy":1}
		hud.day_menu._rebuild()
		await _click(hud.day_menu.confirm_button)
		_check(preload("res://scripts/restaurant/restaurant_day.gd").snapshot(sm).get("status")=="open","真实开始营业按钮可开启第一天")
		_check(not Gate.departure(sm) and Gate.return_message(sm,false).is_empty(),"完成后恢复普通入口")
		restaurant.queue_free()
		await get_tree().process_frame
		# 旧档修复只重建展示回执，不从仓库余额推算、不补发。
		var Day := preload("res://scripts/restaurant/restaurant_day.gd")
		sm.data.erase("return_loot_version")
		sm.data[Day.KEY] = {"day":1,"status":"planning","loot_queue":[]}
		sm.data.ch2_guide_01.banked = returned.duplicate(true)
		for item in ["moondew_honey","cooking_sake","sour_vine_juice"]: sm.data.ch2_guide_01.banked.erase(item)
		var legacy_stock: Dictionary = sm.warehouse_snapshot()
		_check(Day.repair_first_return(sm),"旧首次返店档修复成功")
		_check(Day.pending_loot(sm)[0].get("moondew_honey",0)==3 and sm.warehouse_snapshot()==legacy_stock,"旧档补任务结算但不补库存")
		_check(Day.repair_first_return(sm) and Day.pending_loot(sm).size()==1,"旧档修复幂等")
		# 回到首次任务领奖后战败的检查点：只结算任务奖励，不推进经营教学。
		sm.data = before.duplicate(true)
		sm.data[Run.KEY].combat.hp = 0
		var defeated_stock: Dictionary = sm.warehouse_snapshot()
		_check(Run.finish(sm,false,Roads.SPAWN).success,"领奖后战败仍能返程")
		var defeated_items: Dictionary = Day.pending_loot(sm)[0]
		_check(defeated_items.get("moondew_honey",0)==3 and not defeated_items.has("slime_shell"),"战败只展示保留的任务食材")
		_check(sm.warehouse_snapshot()==defeated_stock and Gate.pending(sm) and not sm.data.get("first_business_intro_pending",false),"战败不重复入仓且不触发经营教学")
		_check(not Run.finish(sm,false,Roads.SPAWN).success and Day.pending_loot(sm).size()==1,"重复返程不重复结算")
		# 普通经营的教学已结束，结算仍须由HUD自动调度。
		sm.data["freezer_unlock_notice_seen"] = true
		sm.data[Gate.KEY] = "done"
		sm.data.ch2_guide_01.step = "done"
		restaurant = load("res://scenes/restaurant_map_2d.tscn").instantiate()
		get_tree().root.add_child(restaurant)
		get_tree().current_scene = restaurant
		await get_tree().create_timer(0.5).timeout
		hud = get_tree().get_first_node_in_group("restaurant_hud")
		_check(is_instance_valid(hud.return_loot) and hud.return_loot.visible,"教学结束后普通返程仍自动显示结算")
		_check(hud.return_loot._grid.get_child_count()==1 and hud.return_loot._grid.get_child(0).name=="TaskGroup","仅任务食材时隐藏空捕获区域")
		var single_height: float = hud.return_loot._panel.size.y
		_check(single_height < two_group_height,"单类食材高度小于双类")
		await _shot_gate("task_only_adaptive")
		await _click(hud.return_loot._confirm_button)
		await get_tree().create_timer(0.2).timeout
		_check(not hud._player.input_locked and hud._player.is_physics_processing() and not hud.exploration_guide.reading,"普通结算确认后恢复操作不重播教学")
		sm.data = before.duplicate(true)
		sm.data[Gate.KEY] = "done"
		sm.data.ch2_guide_01.step = "done"
		sm.data[Run.KEY].combat.hp = 0
		sm.data["exploration_task_loot"] = {}
		sm.data[Day.KEY] = {}
		_check(Run.finish(sm,false,Roads.SPAWN).success and Day.pending_loot(sm).size()==1 and Day.pending_loot(sm)[0].is_empty(),"零食材返程仍排队结算")
		sm.load_data()
		await get_tree().create_timer(0.3).timeout
		_check(hud.return_loot.visible and is_instance_valid(hud.return_loot._grid.get_node_or_null("EmptyMessage")),"空结算读档后自动显示缺省提示")
		_check(hud.return_loot._panel.size.y < single_height,"空状态使用更紧凑高度")
		await _shot_gate("empty_adaptive")
		await _click(hud.return_loot._confirm_button)
		await get_tree().create_timer(0.2).timeout
		_check(hud.exploration_guide.reading and hud.exploration_guide.lesson_id=="freezer_unlock","未确认的冰柜说明等待结算确认后再显示")
		hud.exploration_guide._read_done()
		await get_tree().create_timer(0.2).timeout
		_check(Day.pending_loot(sm).is_empty() and not hud._player.input_locked,"空结算及解锁说明确认后恢复输入")
		var many := {}
		for id in preload("res://scripts/cooking/recipe_catalog.gd").INGREDIENTS:
			many[id] = 1
			if many.size()==16: break
		Day.enqueue_loot(sm.data,many,many,{})
		await get_tree().create_timer(0.3).timeout
		_check(hud.return_loot._scroll.get_v_scroll_bar().visible and hud.return_loot._panel.size.y<get_viewport().get_visible_rect().size.y,"多食材限制高度并显示滚动条")
		hud.return_loot._scroll.scroll_vertical = 10000
		await get_tree().process_frame
		_check(hud.return_loot._scroll.scroll_vertical>0 and hud.return_loot._confirm_button.get_global_rect().end.y<get_viewport().get_visible_rect().size.y,"滚动到末尾时确认按钮仍在屏幕内")
		await _shot_gate("scroll_adaptive")
		await _click(hud.return_loot._confirm_button)
		restaurant.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _shot_gate(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_arg("--output-dir=").path_join(label+".png"))
