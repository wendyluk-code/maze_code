extends "res://tools/tests/ch2_entry_state.gd"
## 旧战斗移除回归：真实开始页、旧档恢复与保留显示资源。
const ArtCatalog := preload("res://scripts/ui/components/card_art_catalog.gd")
const OriginalArt := preload("res://scripts/ui/components/home_card_art.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_legacy_saves()
		await _shared_materials()
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _start_screen()
			await _original_collection()
		await _legacy_maze()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results}, "\t"))
	print("CARD_RETIREMENT ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _legacy_saves() -> void:
	_completed()
	_check(not sm._defaults().has("first_slime_encounter"), "新档不再创建旧战斗进度")
	_check(not sm.has_method("begin_first_slime") and not sm.has_method("settle_first_slime"), "旧战斗入口与奖励接口移除")
	_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success, "旧档合法迷宫位置")
	var inventory: Dictionary = sm.inventory_snapshot().duplicate(true)
	var reputation: int = sm.reputation()
	var gold: int = sm.gold_balance()
	var cards: Dictionary = sm.owned_character_card_counts().duplicate(true)
	for state in ["unseen", "battle", "rewarded", "after_dialog", "completed"]:
		sm.data["first_slime_encounter"] = {"status": state, "position": [953.0, 255.0]}
		_check(sm.save(), "写入旧战斗存档样例：" + state)
		sm.load_data()
		_check(sm.data.first_slime_encounter.status == state, "旧字段可读且原样保留：" + state)
		_check(sm.resume_scene_path() == sm.MAZE_SCENE, "旧档继续当前迷宫，不跳战斗：" + state)
		_check(sm.inventory_snapshot() == inventory and sm.reputation() == reputation and sm.gold_balance() == gold and sm.owned_character_card_counts() == cards, "恢复不补发奖励或改变收藏：" + state)

func _shared_materials() -> void:
	var records := ArtCatalog.display_records()
	_check(not records.is_empty(), "展示快照不依赖已删除Excel")
	for record in records:
		var path := ArtCatalog.path_for(str(record.id))
		_check(not path.is_empty() and load(path) is Texture2D, "展示插画可加载：" + str(record.id))
		var card := SproutCard.new()
		add_child(card)
		card.configure(SproutCardData.new(record))
		await get_tree().process_frame
		_check(card._material_base.texture != null and card._material_art.texture != null, "共享卡框和插画完整：" + str(record.id))
		card.queue_free()
		await get_tree().process_frame

func _start_screen() -> void:
	var start = load("res://scenes/start_screen.tscn").instantiate()
	get_tree().root.add_child(start)
	get_tree().current_scene = start
	await get_tree().process_frame
	await get_tree().process_frame
	_check(start.find_children("BattleDemo", "Button", true, false).is_empty() and not start.has_method("_battle_demo"), "开始界面无卡牌战斗按钮与跳转")
	_check(start.new_button.visible and start.continue_button.visible, "新游戏与继续游戏显示保留")
	await _capture(evidence, "start" + suffix)
	await _click(start.continue_button)
	_check(start.save_modal.visible and start.new_button.disabled, "真实点击继续打开存档并隔离输入")
	await _send_key(KEY_ESCAPE)
	_check(not start.save_modal.visible and not start.new_button.disabled and not start.continue_button.disabled, "取消存档恢复开始页输入")
	start.queue_free()
	await get_tree().process_frame

func _original_collection() -> void:
	_completed()
	var modal = load("res://scripts/ui/components/character_card_art_modal.gd").new()
	get_tree().root.add_child(modal)
	var counts: Dictionary = sm.owned_character_card_counts()
	var party: Array = sm.departure_state().party
	for id in ["yaya", "tieshan"]:
		modal.present(id, OriginalArt.owned_for_character(id, counts, party))
		await get_tree().process_frame
		_check(modal.visible and modal.role_card.texture != null and modal.role_nameplate.visible, "收藏原图保留：" + id)
		if id == "yaya":
			_check(modal.hand_cards.size() == 4 and modal.quantity_labels.any(func(label): return label.text == "x2"), "芽芽四种手牌与重复数量保留")
		await _capture(evidence, "collection_" + id + suffix)
		await _send_key(KEY_ESCAPE)
		_check(not modal.visible, "收藏关闭输入保留：" + id)
	_check(sm.owned_character_card_counts() == counts, "浏览不改变拥有数量")
	modal.queue_free()
	await get_tree().process_frame

func _legacy_maze() -> void:
	_completed()
	sm.data["first_slime_encounter"] = {"status": "battle", "position": [953.0, 255.0]}
	sm.record_maze_location("maze_entry", Roads.SPAWN)
	sm.save()
	sm.load_data()
	var maze = load(sm.resume_scene_path()).instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.4).timeout
	_check(get_tree().current_scene == maze and is_instance_valid(maze.capture_flow), "旧中断战斗档实际进入捕获迷宫")
	_check(maze.get("first_slime_flow") == null, "迷宫无旧战斗控制器")
	await _capture(evidence, "legacy_maze")
	maze.queue_free()
	await get_tree().process_frame
