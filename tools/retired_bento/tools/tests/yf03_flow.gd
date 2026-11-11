extends "res://tools/tests/maze_capture.gd"
const Bento = preload("res://scripts/restaurant/bento_store.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"正式存档隔离")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _bento_flow()
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _bento_flow() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"真实出征")
	sm.record_maze_location("fenshui",Vector2(1300,325))
	_check(sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0}).success,"接续YF02真实检查点")
	var inventory: Dictionary=sm.inventory_snapshot()
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.5).timeout
	maze.capture_flow.window_focused=true
	await get_tree().create_timer(0.2).timeout
	var e=maze.yf_encounter
	_check(e.phase=="gift_reward" and e.gift_modal.visible,"真实赠礼先提交再弹窗")
	_check(Bento.snapshot(sm).slots.size()==3 and not maze.bento_entry.visible,"三份装盒，解锁前无入口")
	_check(sm.inventory_snapshot()==inventory and Run.snapshot(sm).bag.is_empty(),"赠礼不进入背包库存")
	for id in Bento.GIFTS.values(): _check(sm.unlocked_recipe_ids().has(id),"真实解锁配方："+id)
	_check(e.gift_modal.item_views.all(func(v): return v.quantity.get_global_rect().end.y <= e.gift_modal._scroll.get_global_rect().end.y),"三份三星奖励数量不裁切")
	await _capture_image("gift_reward")
	await _click(e.gift_modal._confirm_button)
	await get_tree().create_timer(0.15).timeout
	_check(e.phase=="bento_unlock" and e.unlock_modal.visible and Bento.unlocked(sm),"奖励后解锁蒙层并持久入口资格")
	_check(not maze.bento_entry.is_visible_in_tree() and not maze.bento_entry.get_node("BentoShadow").is_visible_in_tree(),"解锁蒙层阶段隐藏便当入口及投影")
	await _capture_image("unlock")
	await _send_key(KEY_E)
	await get_tree().create_timer(0.2).timeout
	_check(e.phase=="bento_fly" and maze.player.input_locked,"飞入时仍锁输入")
	_check(maze.bento_entry.get_theme_stylebox("disabled") is StyleBoxEmpty,"飞入时禁用入口没有默认按钮底框")
	await _capture_image("flying")
	await get_tree().create_timer(0.6).timeout
	_check(e.phase=="farewell" and int(e.record.line)==0,"动画后第一句告别")
	await get_tree().create_timer(2.5).timeout
	await _capture_image("farewell_0")
	await _send_key(KEY_E)
	_check(e.phase=="farewell" and int(e.record.line)==1,"严格第二句告别")
	await get_tree().create_timer(2.5).timeout
	await _capture_image("farewell_1")
	await _send_key(KEY_E)
	await get_tree().create_timer(0.3).timeout
	_check(e.phase=="fade" and e.idle.modulate.a<1 and e.idle.modulate.a>0,"两人渐隐尚未done")
	await _capture_image("fade")
	await get_tree().create_timer(0.6).timeout
	_check(e.phase=="done" and not e.idle.visible and not maze.player.input_locked,"渐隐结束才done并释放锁")
	var before: Dictionary=Bento.snapshot(sm)
	_check(Bento.grant(sm).success and Bento.snapshot(sm)==before,"重复赠礼不重复奖励")
	await get_tree().process_frame
	_check(maze.bento_entry.visible and maze.bento_entry.get_global_rect().position.x>maze.backpack_entry.get_global_rect().end.x,"迷宫便当第二入口")
	var bag_shadow: StyleBoxFlat = maze.backpack_entry.get_node("BackpackShadow").get_theme_stylebox("panel")
	var bento_shadow: StyleBoxFlat = maze.bento_entry.get_node("BentoShadow").get_theme_stylebox("panel")
	_check(bag_shadow.shadow_color == bento_shadow.shadow_color and bag_shadow.shadow_size == bento_shadow.shadow_size and bag_shadow.shadow_offset == bento_shadow.shadow_offset, "便当与背包投影一致")
	await RenderingServer.frame_post_draw
	await _capture_image("matched_entries")
	await _click(maze.bento_entry)
	await get_tree().process_frame
	_check(maze.bento_modal.visible and maze.player.input_locked,"入口打开并锁输入")
	_check(maze.bento_modal.details.get_node("EatButton").get_global_rect().end.y <= maze.bento_modal.right_scroll.get_global_rect().end.y,"食用小按钮完整可见")
	await _capture_image("bento_full")
	var power: float=Run.snapshot(sm).combat.attack
	await _click(maze.bento_modal.details.get_node("EatButton"))
	_check(Bento.snapshot(sm).slots.attack.eaten and Run.snapshot(sm).combat.attack==power+3,"单份真实食用团队总攻击+3")
	_check(not Bento.eat(sm,"attack").success and not Bento.discard(sm,"attack").success,"已食格不能重吃或腾空")
	await _click(maze.bento_modal.all_button)
	_check(Bento.snapshot(sm).slots.values().all(func(r): return r.eaten),"全部食用提交剩余两份")
	_check(Run.snapshot(sm).bento.defense==2 and Run.snapshot(sm).bento.heal_total==Run.snapshot(sm).combat.max_hp*0.3,"三星实际效果")
	var elapsed: float=Run.snapshot(sm).bento.heal_elapsed
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm).bento.heal_elapsed==elapsed,"页面暂停回血")
	await _capture_image("bento_eaten")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked,"关闭恢复输入")
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm).bento.heal_elapsed>elapsed,"关闭后恢复有效时间回血")
	maze.capture_flow._focus_lost()
	elapsed=Run.snapshot(sm).bento.heal_elapsed
	await get_tree().create_timer(0.3).timeout
	_check(Run.snapshot(sm).bento.heal_elapsed==elapsed,"失焦暂停回血")
	maze.queue_free()
	await get_tree().process_frame
	sm.load_data()
	_check(sm.yufeng_salia_record().phase=="done" and Bento.snapshot(sm).slots.values().all(func(r): return r.eaten),"读档done与已食用保持")
	_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"真实结束探索")
	_check(Bento.snapshot(sm).slots.is_empty() and not Run.snapshot(sm).has("bento"),"结束清空已食格及本趟效果")
	maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	# 当前冻结基线新增冰柜解锁对白；先按真实输入完成它，才检验便当入口。
	if sm.freezer_notice_pending():
		await _send_key(KEY_E)
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
		_check(not sm.freezer_notice_pending(),"先完成既有冰柜解锁对白")
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.bento_entry.visible and hud.bento_entry.get_global_rect().position.x>hud._recipe_entry.get_global_rect().end.x,"餐厅菜谱右侧第二入口")
	await _click(hud.bento_entry)
	await get_tree().process_frame
	_check(hud.bento_modal.visible and not hud.bento_modal.all_button.visible,"餐厅页面不可食用")
	await _capture_image("restaurant_bento")
	hud.bento_modal.dismiss()
	_check(not hud._player.input_locked,"餐厅关闭恢复输入")
	maze.queue_free()
	await get_tree().process_frame
