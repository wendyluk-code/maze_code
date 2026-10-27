extends "res://tools/tests/adventurer_home_input.gd"
const Recruit = preload("res://scripts/characters/recruitment.gd")
const Growth = preload("res://scripts/characters/character_progression.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_seed()
		for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
		_service_checks()
		for resolution in [Vector2i(1152,648), Vector2i(1280,720), Vector2i(1920,1080)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await get_tree().process_frame
			await _flow_recruit()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("REC01 ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _service_checks() -> void:
	var baseline: Dictionary = sm.data.duplicate(true)
	_check(sm.owned_characters() == ["yaya", "tieshan"] and not sm.data.has(Recruit.OWNED_KEY), "旧档只读迁移，不修改章节队伍")
	var pools := _pools()
	for edge in [[0.0,"SSR"],[0.099999,"SSR"],[0.1,"SR"],[0.399999,"SR"],[0.4,"R"],[0.999999,"R"]]:
		_check(Growth.CHARACTERS[Recruit.pick(edge[0],0.0)].rarity == edge[1], "稀有度概率边界:"+str(edge[0]))
	var rarity_rolls := {"SSR":0.05,"SR":0.2,"R":0.7}
	for rarity in pools:
		var pool: Array = pools[rarity]
		for i in pool.size():
			var lower := float(i)/pool.size()
			var upper := float(i+1)/pool.size()
			_check(Recruit.pick(rarity_rolls[rarity],lower+0.000001) == pool[i] and Recruit.pick(rarity_rolls[rarity],upper-0.000001) == pool[i], "池内均匀区间:"+pool[i])
			if i > 0:
				_check(Recruit.pick(rarity_rolls[rarity],lower-0.000001) == pool[i-1], "池内相邻边界:"+pool[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var counts: Dictionary = {}
	for id in Growth.CHARACTERS: counts[id] = 0
	for i in 100000: counts[Recruit.pick(rng.randf(), rng.randf())] += 1
	var weights := {"SSR":0.1,"SR":0.3,"R":0.6}
	for id in counts:
		var rarity: String = Growth.CHARACTERS[id].rarity
		var expected: float = 100000.0 * weights[rarity] / pools[rarity].size()
		_check(abs(counts[id] - expected) < 900, "10万次分布:" + id, counts)
	sm.data.gold = 999
	var before: Dictionary = sm.data.duplicate(true)
	_check(sm.recruit(1).reason == "insufficient_gold" and sm.data == before, "999金币拒绝且无状态变化")
	sm.data.gold = 8999
	before = sm.data.duplicate(true)
	_check(sm.recruit(10).reason == "insufficient_gold" and sm.data == before, "8999金币拒绝十连")
	sm.data.gold = 1000
	var first: Dictionary = _draw_ids(["salia"])
	_check(first.success and first.results[0].kind == "new" and first.results[0].rank == 1 and sm.gold_balance() == 0, "1000金币首次SSR1星")
	_check(sm.departure_state().party == ["yaya", "tieshan"] and sm.owned_characters().has("salia"), "通用拥有与剧情队伍分离")
	sm.data.gold = 9000
	var batch: Dictionary = _draw_ids(["salia","salia","salia","salia","salia","salia","salia","salia","salia","salia"])
	_check(batch.success and sm.gold_balance() == 0 and sm.stardust_balance() == 500, "十连一次扣9000，同批满星重复转尘")
	for i in 10:
		_check(batch.results[i].rank == mini(6, i + 2) and batch.results[i].stardust == (100 if i >= 5 else 0), "第%d张时点星级/5升6不转尘" % (i+1))
	sm.load_data()
	_check(Growth.record(sm, "salia").rank == 6 and sm.stardust_balance() == 500 and sm.data[Recruit.KEY].last_results.size() == 10, "重载保持金币星级星尘和全部结果")
	sm.data.gold = 9000
	var guaranteed: Dictionary = _draw_ids(["yaya","yaya","yaya","yaya","yaya","yaya","yaya","yaya","yaya","yaya"])
	_check(guaranteed.success and Growth.CHARACTERS[guaranteed.results[9].id].rarity == "SSR", "无SSR末张替换保底")
	for i in 9: _check(guaranteed.results[i].id == "yaya", "保底保留前九张")
	sm.data.gold = 9000
	var ids: Array = ["salia"]
	for i in 9: ids.append("dingdang")
	var existing_ssr: Dictionary = _draw_ids(ids)
	_check(existing_ssr.success and existing_ssr.results[0].id == "salia" and existing_ssr.results[9].id == "dingdang", "已有SSR不强换最后一张")
	sm.data.gold = 9000
	before = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(sm.recruit(10).reason == "save_failed" and sm.data == before, "保存失败完整回滚金币/收藏/结果/星尘")
	sm._active_save_path = path
	sm._recruit_busy = true
	_check(sm.recruit(1).reason == "busy" and sm.data == before, "事务重入拒绝")
	sm._recruit_busy = false
	for bad in [null, {}, ["unknown"], ["yaya", "yaya"]]:
		sm.data[Recruit.OWNED_KEY] = bad
		var corrupt: Dictionary = sm.data.duplicate(true)
		_check(sm.recruit(1).reason == "invalid_record" and sm.data == corrupt, "坏拥有记录不回退授奖")
		sm.data = before.duplicate(true)
	for bad in [null, [], {"salia": {"rank": 7}}]:
		sm.data[Growth.KEY] = bad
		var corrupt: Dictionary = sm.data.duplicate(true)
		_check(sm.recruit(1).reason == "invalid_record" and sm.data == corrupt, "坏成长记录不授奖")
		sm.data = before.duplicate(true)
	sm.data[Recruit.KEY] = {"stardust": -1}
	_check(sm.recruit(1).reason == "invalid_record", "负星尘拒绝")
	_seed("agreement")
	sm.data.gold = 10000
	for i in 3: _draw_ids(["yaya"])
	_check(Growth.record(sm, "yaya").rank == 3, "章节入队前招募已有角色")
	_check(sm.advance_departure("agreement").success and Growth.record(sm, "yaya").rank == 3 and sm.owned_characters().has("tieshan"), "章节入队只补缺角色，不给已有角色额外升星")
	sm.data = baseline.duplicate(true)
	sm.data.gold = 100000
	for id in Growth.CHARACTERS:
		if not sm.owned_characters().has(id): _draw_ids([id])
	_check(sm.owned_characters().size() == Growth.CHARACTERS.size() and sm.valid_exploration_party(["salia", "yufeng", "dingdang", "yaya"]) and not sm.valid_exploration_party(sm.owned_characters()), "完整收藏最多四人出征")
	for id in ["salia", "yufeng", "dingdang"]:
		var record := Growth.record(sm, id)
		_check(record.valid and record.defense == 1 and record.level == 1, "新角色成长可读:"+id)
	var original_growth: Dictionary = sm.data[Growth.KEY].duplicate(true)
	for entry in [["salia",91,68,8,0.0295,0.8], ["yufeng",61,105,8,0.0295,0.6], ["dingdang",31,107,9,0.049,0.5]]:
		var id: String = entry[0]
		sm.data[Growth.KEY][id] = {"level":30,"exp":0,"rank":6,"breakthroughs":5}
		var record := Growth.record(sm, id)
		var active := Growth.active_skill(id, 30)
		_check(record.valid and record.attack == entry[1] and record.health == entry[2] and record.defense == 30 and record.satiety_max == entry[3] and is_equal_approx(record.recovery_percent, entry[4]) and is_equal_approx(active.interval, entry[5]) and is_equal_approx(active.multiplier, 1.5), "30级完整成长与主动显示:" + id)
	sm.data[Growth.KEY] = original_growth
	sm.save()

func _flow_recruit() -> void:
	sm.data.gold = 100000
	sm.save()
	await _open_scene()
	var player = scene.get_node("Player")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().physics_frame
	await get_tree().process_frame
	var ui = get_tree().get_first_node_in_group("ui_layer")
	await _click(ui._buttons[target])
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(is_instance_valid(page) and page.character_buttons.size() == Growth.CHARACTERS.size(), "真实入口完整配置角色簿")
	await _shot("collection")
	for id in ["salia", "yufeng", "dingdang", "yaya", "tieshan"]:
		page.collection_scroll.ensure_control_visible(page.character_buttons[id])
		await get_tree().process_frame
		await _click(page.character_buttons[id])
		_check(page.cards_modal.visible and page.cards_modal.character_id == id, "真实角色详情:"+id)
		_check(page.cards_modal.active_description.get_theme_font_size("font_size") == 21, "主动描述保持原21字号:"+id)
		await _shot(id+"_details")
		if page.cards_modal.active_rules_button.visible:
			await _click(page.cards_modal.active_rules_button)
			var rules = page.cards_modal.active_rules_modal
			_check(rules.visible and rules._body_label.get_theme_font_size("font_size") == 26, "完整说明使用可读字号:"+id)
			_check(rules._body_label.get_line_count() == rules._body_label.get_visible_line_count(), "完整说明全部行可见:"+id)
			var bounds: Rect2 = rules._panel.get_global_rect()
			_check(get_viewport().get_visible_rect().encloses(bounds), "完整说明面板在视口内:"+id)
			if id == "dingdang":
				for phrase in ["同一目标仅保留一个锁印", "钥匙本身不引爆，只刷新锁印", "雷电传导不触发锁印", "锁印不会转移", "240像素", "15%", "并消耗锁印"]:
					_check(rules._body_label.text.contains(phrase), "锁印完整机制:"+phrase)
			await _shot(id+"_full_rules")
			await _send_key(KEY_ESCAPE)
			_check(not rules.visible and page.cards_modal.visible, "Esc只关完整说明:"+id)
		await _click(page.cards_modal.tabs[1])
		await _shot(id+"_skills")
		await _send_key(KEY_ESCAPE)
		_check(not page.cards_modal.visible and not page.back_button.disabled, "详情返回输入恢复:"+id)
	await _click(page.tabs[1])
	_check(page.summon_panel.rarity_badges.size() == 3, "招募主视觉三个稀有度字标")
	for entry in [["salia", "SSR", "SaliaName"], ["yufeng", "SR", "YufengName"], ["dingdang", "R", "DingdangName"]]:
		var badge = page.summon_panel.rarity_badges[entry[0]]
		_check(badge.is_visible_in_tree() and badge.texture.resource_path.ends_with("/"+entry[1]+".png"), "招募主视觉字标正确:"+entry[0])
		_check(page.summon_panel.get_node(entry[2]).get_global_rect().encloses(badge.get_global_rect()) and not badge.get_global_rect().intersects(page.summon_panel.single_button.get_global_rect()) and not badge.get_global_rect().intersects(page.summon_panel.ten_button.get_global_rect()), "字标融合姓名牌且避开按钮:"+entry[0])
	await _shot("summon")
	var original_path: String = sm._active_save_path
	var before_failure: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	await _click(page.summon_panel.single_button)
	_check(sm.data == before_failure and not page.recruit_results.visible and not page._summoning, "真实按钮保存失败不演出且整体回滚")
	_check(page.summon_toast.visible and page.summon_toast.text.contains("保存失败"), "真实失败显示错误提示")
	await _shot("save_failed")
	sm._active_save_path = original_path
	var gold: int = sm.gold_balance()
	await _click(page.summon_panel.single_button)
	_check(page.recruit_results.visible and sm.gold_balance() == gold - 1000, "真实单抽按钮一次扣费")
	_check(not page.summon_toast.visible and page.summon_toast._remaining == 0.0, "保存失败后成功抽取清除旧错误提示")
	page._on_summon_requested(1, 1000)
	_check(sm.gold_balance() == gold - 1000, "结果播放中重复激活不扣费")
	await _shot("single_result")
	await _send_key(KEY_ESCAPE)
	await _click(page.recruit_results.next_button)
	_check(not page.recruit_results.visible and not page._summoning, "跳过结果完成后恢复输入")
	gold = sm.gold_balance()
	await _click(page.summon_panel.ten_button)
	_check(page.recruit_results.results.size() == 10 and sm.gold_balance() == gold - 9000, "真实十连按钮保存完整结果")
	await _shot("ten_first")
	await _click(page.recruit_results.skip_button)
	await _shot("ten_overview")
	var saved: Dictionary = sm.data.duplicate(true)
	await _click(page.recruit_results.next_button)
	_check(sm.data == saved, "跳过和完成不重复授奖")
	# 每人使用真实招募事务：原始卡面与满星翻转均留存三分辨率证据。
	for entry in [["salia", 0.0], ["yufeng", 0.2], ["dingdang", 0.4]]:
		var id: String = entry[0]
		var portrait: Texture2D = load(Growth.portrait_path(id))
		sm.data.gold = 10000
		sm.data[Growth.KEY][id].rank = 6
		var dust: Dictionary = _draw_ids([id])
		_check(dust.success and dust.results[0].id == id and dust.results[0].stardust == 100, "真实指定满星招募:"+id)
		page.recruit_results.present(dust.results)
		var face: Control = page.recruit_results.current_face
		var shown: TextureRect = null
		for child in face.get_children():
			if child is TextureRect and child.texture == portrait: shown = child
		_check(is_instance_valid(shown) and portrait.get_width() > 0 and portrait.get_height() > 0 and shown.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and not shown.clip_contents and not face.clip_contents and Rect2(Vector2.ZERO, face.size).encloses(Rect2(shown.position, shown.size)) and get_viewport().get_visible_rect().encloses(shown.get_global_rect()), "正式完整立绘:"+id)
		await get_tree().create_timer(0.8).timeout
		await _shot(id+"_six_star_before_flip")
		await get_tree().create_timer(0.8).timeout
		_check(page.recruit_results.dust_shown, "6星卡翻转星尘:"+id)
		await _shot(id+"_stardust_after_flip")
		await _click(page.recruit_results.loot._confirm_button)
		await _click(page.recruit_results.next_button)
	await get_tree().process_frame
	_check(page.dust_counter.position.x >= page.gold_counter.position.x + page.gold_counter.size.x, "星尘余额在金币右侧")
	await _shot("home_stardust_balance")
	await _click(page.back_button)
	await get_tree().process_frame
	_check(player.can_process() and not player.input_locked, "返回餐厅恢复玩家输入")
	var start_position: Vector2 = player.position
	for direction in [{"key": KEY_D, "delta": Vector2(20,0)}, {"key": KEY_A, "delta": Vector2(-20,0)}, {"key": KEY_S, "delta": Vector2(0,20)}]:
		if player.is_walkable_footprint(start_position + direction.delta):
			await _key_held(direction.key, 0.06)
			break
	_check(player.position.distance_to(start_position) > 1.0, "返回后实际方向键移动")
	sm.load_data()
	_check(sm.owned_characters().size() == Growth.CHARACTERS.size(), "真实页面关闭后重载收藏")
	await _close_scene()

# 测试独立推导池区间，不依赖被测pick的结果来生成期望。
func _pools() -> Dictionary:
	var pools := {"SSR":[],"SR":[],"R":[]}
	for id in Growth.CHARACTERS:
		pools[Growth.CHARACTERS[id].rarity].append(id)
	return pools

func _draw_ids(ids: Array) -> Dictionary:
	var pools := _pools()
	var rolls: Array = []
	var rarity_rolls := {"SSR":0.05,"SR":0.2,"R":0.7}
	for id in ids:
		var rarity: String = Growth.CHARACTERS[id].rarity
		var pool: Array = pools[rarity]
		rolls.append_array([rarity_rolls[rarity], (pool.find(id)+0.5)/pool.size()])
	# 十连无SSR时另一次成员roll选择保底池首人。
	rolls.append(0.0)
	return sm.recruit(ids.size(), func(): return rolls.pop_front())
