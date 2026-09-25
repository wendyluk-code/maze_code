extends Node
## 存档管理器（Autoload: SaveManager）
## 全量 JSON 存档，路径 user://save.json；维护教程兼容标记、章节完成状态与首单

const SAVE_PATH := "user://save.json"
const PROLOGUE_DONE_KEY := "prologue_done"
const CHAPTER_1_DONE_KEY := "chapter_1_done"
const CURRENT_ORDER_KEY := "current_order"
const ORDER_STATUS_NONE := "none"
const ORDER_STATUS_IN_PROGRESS := "in_progress"
const ORDER_STATUS_COMPLETED := "completed"
const FIRST_ORDER_SETTLEMENT_KEY := "first_order_settlement"
const REPUTATION_KEY := "reputation"
const FIRST_ORDER_REPUTATION := 10
const COOKING_STATE_KEY := "first_order_cooking"
const PREPARED_DISHES_KEY := "prepared_dishes"
const QUALITY_REPUTATION := {1: 10, 2: 12, 3: 15}
const FIRST_ORDER_ID := "chapter_1_first_order"
const FIRST_ORDER_ITEM_ID := "salt_grilled_rockmane"
const FIRST_ORDER_ITEM_NAME := "盐烤岩鬃肉"
const FIRST_ORDER_QUANTITY := 1
const INVENTORY_KEY := "inventory"
const FIRST_ORDER_PROGRESS_KEY := "first_order_progress"
const ROCKMAN_MEAT_ID := "rockmane_meat"
const ROCK_SALT_ID := "rock_salt"
const WRAPUP_KEY := "chapter_1_departure"
const DEPARTURE_OBJECTIVE := "与芽芽、铁山一同进入迷宫浅层"
const CH1_CARD_IDS := ["yaya_01", "yaya_02", "yaya_03", "yaya_04", "yaya_05", "yaya_06", "yaya_07", "yaya_08", "tieshan_01", "tieshan_02", "tieshan_03", "tieshan_04", "tieshan_05", "tieshan_06", "tieshan_07", "tieshan_08"]
## 顺序是存档契约；已确认的对白逐句提交，重进从尚未确认的一句继续。
const WRAPUP_STEPS := ["relief", "meat", "yaya_past", "hero_past", "yaya_yes",
	"second_serving", "check_store", "warehouse_move", "warehouse_inspect", "salt_pool",
	"map_review", "introduction", "offer", "no", "memory", "cooking", "ingredients",
	"yaya_join", "stay_shallow", "agreement", "ready_to_depart"]

var data: Dictionary = _defaults()
## 重播使用独立工作副本；公开 data 和正式文件在整个重播期间保持原样。
var _replay_data: Dictionary = {}
var _replaying := false
## 序章预览覆盖整个进程，避免进入餐厅或取消教程后意外恢复正式写入。
var _prologue_preview := false
var _state: Dictionary:
	get:
		return _replay_data if _replaying else data
	set(value):
		if _replaying:
			_replay_data = value
		else:
			data = value
## 只记录读取时补齐的字段，不在迁移时推断或补发奖励。
var migration_diagnostics: Array[String] = []

func _ready() -> void:
	_prologue_preview = "--replay-prologue" in OS.get_cmdline_user_args() or "--replay-prologue" in OS.get_cmdline_args()
	load_data()
	if _prologue_preview:
		begin_replay()

func _defaults() -> Dictionary:
	return {
		PROLOGUE_DONE_KEY: false,
		"tutorial_done": false,
		CHAPTER_1_DONE_KEY: false,
		CURRENT_ORDER_KEY: _empty_order(),
		INVENTORY_KEY: {ROCKMAN_MEAT_ID: 0, ROCK_SALT_ID: 0, FIRST_ORDER_ITEM_ID: 0},
		PREPARED_DISHES_KEY: {FIRST_ORDER_ITEM_ID: {"1": 0, "2": 0, "3": 0}},
		COOKING_STATE_KEY: {"status": "idle", "recipe_id": "", "quality": 0, "pointer": 0.0},
		FIRST_ORDER_PROGRESS_KEY: {"ingredients_claimed": false, "next_step": "accept_order"},
		FIRST_ORDER_SETTLEMENT_KEY: {},
		REPUTATION_KEY: 0,
		WRAPUP_KEY: _empty_departure(),
		"chapter_1_intro": "not_started",
	}

func _empty_order() -> Dictionary:
	return {
		"id": "",
		"item_id": "",
		"item_name": "",
		"quantity": 0,
		"status": ORDER_STATUS_NONE,
	}

func _empty_departure() -> Dictionary:
	return {"step": "relief", "empty_warehouse_checked": false, "tieshan_name_revealed": false,
		"map": {"unlocked_floors": [], "visible_regions": [], "other_regions": "fog"},
		"party": [], "objective": "", "entrance_lit": false,
		"cards": _pending_cards()}

func _pending_cards() -> Dictionary:
	# 保留 CH1-09 的精确 pending schema；正式解锁后才扩展为完整卡组 schema。
	return {"status": "pending_content", "unlocked": false, "card_ids": []}

func _unlocked_cards() -> Dictionary:
	return {"status": "unlocked", "unlocked": true, "card_ids": CH1_CARD_IDS.duplicate(),
		"deck_ids": CH1_CARD_IDS.duplicate(),
		"characters": {"yaya": {"attack": 2, "max_hp": 5}, "tieshan": {"attack": 1, "max_hp": 6}}}

func departure_state() -> Dictionary:
	var saved = _state.get(WRAPUP_KEY)
	var problem := _departure_problem(saved)
	if not problem.is_empty():
		_diagnose("准备状态回退 relief：" + problem)
		return _empty_departure()
	var state: Dictionary = saved.duplicate(true)
	if not state.map.unlocked_floors.is_empty():
		state.map.unlocked_floors = [1]
	return state

func _diagnose(message: String) -> void:
	if not migration_diagnostics.has(message):
		migration_diagnostics.append(message)
		print("SaveManager: ", message)

## 检查点只接受与已执行步骤一致的结构，缺字段不能由默认值拼成完成态。
func _departure_problem(value) -> String:
	if not value is Dictionary:
		return "departure 必须是字典"
	for key in _empty_departure():
		if not value.has(key):
			return "departure 缺少 " + key
	if not value.step is String or not value.step in WRAPUP_STEPS:
		return "departure.step 无效"
	var index: int = WRAPUP_STEPS.find(value.step)
	for key in ["empty_warehouse_checked", "tieshan_name_revealed", "entrance_lit"]:
		if not value[key] is bool:
			return key + " 必须是布尔值"
	if not value.map is Dictionary:
		return "map 必须是字典"
	var map: Dictionary = value.map
	if not map.get("unlocked_floors") is Array or not map.get("visible_regions") is Array or not map.get("other_regions") is String or map.other_regions != "fog":
		return "map 楼层、区域或迷雾无效"
	var unlocked := index > WRAPUP_STEPS.find("salt_pool")
	if unlocked:
		if map.unlocked_floors.size() != 1 or typeof(map.unlocked_floors[0]) not in [TYPE_INT, TYPE_FLOAT] or map.unlocked_floors[0] != 1 or map.visible_regions != ["old_salt_pool"]:
			return "map 旧盐池解锁与步骤矛盾"
	elif not map.unlocked_floors.is_empty() or not map.visible_regions.is_empty():
		return "map 提前解锁"
	if not value.party is Array or not value.objective is String or not value.cards is Dictionary:
		return "party、objective 或 cards 类型错误"
	if not _cards_problem(value.cards).is_empty():
		return _cards_problem(value.cards)
	var ready: bool = value.step == "ready_to_depart"
	if value.party != (["yaya", "tieshan"] if ready else []) or value.objective != (DEPARTURE_OBJECTIVE if ready else "") or value.entrance_lit != ready:
		return "队伍、目标、入口与步骤矛盾"
	if value.empty_warehouse_checked != (index > WRAPUP_STEPS.find("warehouse_inspect")) or value.tieshan_name_revealed != (index > WRAPUP_STEPS.find("introduction")):
		return "仓库或姓名检查点与步骤矛盾"
	if index > 0 and not can_start_departure():
		return "准备步骤缺少真实首单结算或库存未清空"
	return ""

func _cards_problem(cards) -> String:
	if not cards is Dictionary:
		return "cards 必须是字典"
	if str(cards.get("status", "")) == "pending_content" and cards.get("unlocked", null) is bool and cards.unlocked == false \
			and cards.get("card_ids", []) is Array and cards.card_ids.is_empty() and cards.size() == 3:
		return ""
	if str(cards.get("status", "")) == "unlocked" and cards.get("unlocked", null) is bool and cards.unlocked == true \
			and cards.get("card_ids", []) is Array and cards.get("deck_ids", []) is Array \
			and Array(cards.card_ids) == CH1_CARD_IDS and Array(cards.deck_ids) == CH1_CARD_IDS:
		var chars = cards.get("characters", {})
		var yaya = chars.get("yaya", {}) if chars is Dictionary else {}
		var tieshan = chars.get("tieshan", {}) if chars is Dictionary else {}
		if chars is Dictionary and chars.size() == 2 \
				and yaya is Dictionary and tieshan is Dictionary \
				and typeof(yaya.get("attack")) in [TYPE_INT, TYPE_FLOAT] and yaya.attack == 2 \
				and typeof(yaya.get("max_hp")) in [TYPE_INT, TYPE_FLOAT] and yaya.max_hp == 5 \
				and typeof(tieshan.get("attack")) in [TYPE_INT, TYPE_FLOAT] and tieshan.attack == 1 \
				and typeof(tieshan.get("max_hp")) in [TYPE_INT, TYPE_FLOAT] and tieshan.max_hp == 6 \
				and cards.size() == 5:
			return ""
	return "cards schema 无效或卡牌列表不完整"

func cards_state() -> Dictionary:
	var cards = departure_state().get("cards", _pending_cards())
	return cards.duplicate(true)

func cards_unlocked() -> bool:
	return bool(cards_state().get("unlocked", false))

## 在准备同行态查看卡组时幂等解锁；不会推进 ready_to_depart 或章节完成标记。
func unlock_ch1_cards() -> Dictionary:
	var state := departure_state()
	if state.step != "ready_to_depart":
		return {"success": false, "reason": "not_ready_to_depart", "cards": state.cards}
	if cards_unlocked():
		return {"success": true, "created": false, "cards": cards_state()}
	var previous := _state.duplicate(true)
	state.cards = _unlocked_cards()
	_state[WRAPUP_KEY] = state
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed", "cards": cards_state()}
	return {"success": true, "created": true, "cards": cards_state()}

func is_ready_to_depart() -> bool:
	return departure_state().step == "ready_to_depart" and can_start_departure()

## 第一章最终确认的原子提交。
## 只接受完整的 ready_to_depart 准备态；章节标记、兼容标记和其它经营/出发字段
## 在同一份存档中提交。重复完成返回幂等成功，不重复写盘或发放奖励。
func complete_chapter_1() -> Dictionary:
	if is_chapter_1_complete():
		return {"success": true, "created": false, "reason": "already_done", "state": completion_state()}
	if not is_ready_to_depart():
		return {"success": false, "created": false, "reason": "not_ready_to_depart", "state": completion_state()}
	var previous := _state.duplicate(true)
	_state[CHAPTER_1_DONE_KEY] = true
	_state["tutorial_done"] = true
	if not save():
		_state = previous
		_diagnose("第一章完成标记保存失败，保留 ready_to_depart 准备态")
		return {"success": false, "created": false, "reason": "save_failed", "state": completion_state()}
	return {"success": true, "created": true, "reason": "completed", "state": completion_state()}

## done 是最终生命周期阶段；出发状态本身仍保留地图、队伍、入口和卡组快照。
func is_chapter_1_complete() -> bool:
	return is_chapter_1_done() and is_tutorial_done() and departure_state().step == "ready_to_depart" and can_start_departure()

func completion_state() -> Dictionary:
	return {"stage": lifecycle_stage(), "chapter_1_done": is_chapter_1_done(),
		"tutorial_done": is_tutorial_done(), "departure": departure_state()}

func can_start_departure() -> bool:
	var order := current_order()
	var progress = _state.get(FIRST_ORDER_PROGRESS_KEY)
	var inventory = _state.get(INVENTORY_KEY)
	if not progress is Dictionary or not inventory is Dictionary:
		return false
	if not progress.get("next_step") is String or progress.next_step != "chapter_wrap_up" or not progress.get("ingredients_claimed") is bool or not progress.ingredients_claimed:
		return false
	for key in [ROCKMAN_MEAT_ID, ROCK_SALT_ID, FIRST_ORDER_ITEM_ID]:
		if typeof(inventory.get(key)) not in [TYPE_INT, TYPE_FLOAT] or inventory[key] != 0:
			return false
	if order.get("status") != ORDER_STATUS_COMPLETED:
		return false
	order.status = ORDER_STATUS_IN_PROGRESS
	return is_canonical_first_order(order) and has_first_order_settlement() \
		and typeof(_state.get(REPUTATION_KEY)) in [TYPE_INT, TYPE_FLOAT] \
		and _state[REPUTATION_KEY] >= FIRST_ORDER_REPUTATION

## 完成一个阶段7步骤时原子提交下一检查点及对应解锁；失败时完整回滚。
func advance_departure(expected_step: String) -> Dictionary:
	if not can_start_departure():
		return {"success": false, "reason": "not_settled_or_not_empty"}
	var state := departure_state()
	var index := WRAPUP_STEPS.find(expected_step)
	if index < 0 or index >= WRAPUP_STEPS.size() - 1 or state.step != expected_step:
		return {"success": false, "reason": "wrong_step"}
	var previous := _state.duplicate(true)
	state.step = WRAPUP_STEPS[index + 1]
	match expected_step:
		"warehouse_inspect":
			state.empty_warehouse_checked = true
		"salt_pool":
			state.map = {"unlocked_floors": [1], "visible_regions": ["old_salt_pool"], "other_regions": "fog"}
		"introduction":
			state.tieshan_name_revealed = true
		"agreement":
			state.party = ["yaya", "tieshan"]
			state.objective = DEPARTURE_OBJECTIVE
			state.entrance_lit = true
	_state[WRAPUP_KEY] = state
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "state": departure_state()}

func _normalize_order(value) -> Dictionary:
	if not value is Dictionary:
		return _empty_order()
	# 保留所有进行中订单字段，以便拒绝冲突订单；只有 canonical 首单
	# 才能在 accept_first_order() 中走幂等成功分支。
	if str(value.get("status", ORDER_STATUS_NONE)) not in [ORDER_STATUS_IN_PROGRESS, ORDER_STATUS_COMPLETED]:
		return _empty_order()
	return value.duplicate(true)

func load_data() -> void:
	if _replaying:
		return
	migration_diagnostics.clear()
	data = _defaults()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parser := JSON.new()
			var error := parser.parse(f.get_as_text())
			f.close()
			if error != OK:
				_diagnose("存档 JSON 损坏，回退默认状态：" + parser.get_error_message())
				return
			var parsed = parser.data
			if parsed is Dictionary:
				for key in _defaults():
					if not parsed.has(key):
						_diagnose("旧存档补齐默认字段：" + key + "；未补发声望。")
				# 旧存档可能只有 tutorial_done；合并默认值而不是丢弃未知字段，
				# 这样旧存档能继续使用，同时缺少第一章标记时会进入第一章。
				_state = _defaults()
				for key in parsed:
					_state[key] = parsed[key]
				_state[WRAPUP_KEY] = _normalize_departure_cards(_state.get(WRAPUP_KEY))
				# 先核对原始事务结构，不能把错误库存归零后误认作已就绪。
				_state[WRAPUP_KEY] = departure_state()
				_state[CURRENT_ORDER_KEY] = _normalize_order(_state.get(CURRENT_ORDER_KEY))
				_state[INVENTORY_KEY] = _normalize_inventory(_state.get(INVENTORY_KEY))
				_state[FIRST_ORDER_PROGRESS_KEY] = _normalize_progress(_state.get(FIRST_ORDER_PROGRESS_KEY))
				_state[PREPARED_DISHES_KEY] = prepared_dishes_snapshot()
				_state[COOKING_STATE_KEY] = _normalize_cooking_state(_state.get(COOKING_STATE_KEY))
				if _state[COOKING_STATE_KEY].status == "active":
					# 读取迁移不写盘；重复读取同一 active 档只恢复这一份料理。
					if _can_recover_cooking():
						_state[COOKING_STATE_KEY].status = "locked"
						_state[COOKING_STATE_KEY].quality = 1
						_state[COOKING_STATE_KEY].pointer = 0.0
						_state[INVENTORY_KEY][FIRST_ORDER_ITEM_ID] = 1
						_state[PREPARED_DISHES_KEY][FIRST_ORDER_ITEM_ID]["1"] = 1
						_state[FIRST_ORDER_PROGRESS_KEY]["next_step"] = "deliver"
						_diagnose("烹饪中断，按 1 星结果恢复")
					else:
						_diagnose("active 烹饪与订单、配方或库存矛盾，未增加成品")
				for key in ["tutorial_done", CHAPTER_1_DONE_KEY]:
					if not _state[key] is bool:
						_diagnose(key + " 类型错误，回退 false")
						_state[key] = false
				if not _state.chapter_1_intro is String or _state.chapter_1_intro not in ["not_started", "awakened", "guest_arrived"]:
					_diagnose("chapter_1_intro 无效，回退 not_started")
					_state.chapter_1_intro = "not_started"
				if not _prologue_preview:
					_migrate_prologue(parsed)
				return
			_diagnose("存档顶层必须是字典，回退默认状态")
		else:
			_diagnose("存档读取失败，回退默认状态：" + str(FileAccess.get_open_error()))
	_state = _defaults()

func _normalize_departure_cards(value):
	## 旧档只在 departure 是字典且缺少 cards 字段时补齐 pending；
	## 非法 cards 原样保留，交由 departure_state 诊断并回退，避免静默吞错。
	if not value is Dictionary:
		return value
	var result: Dictionary = value.duplicate(true)
	if not result.has("cards"):
		result["cards"] = _pending_cards()
		return result
	var cards = result.get("cards")
	if cards is Dictionary and cards == _pending_cards():
		result["cards"] = _pending_cards()
	elif cards is Dictionary and cards == _unlocked_cards():
		result["cards"] = _unlocked_cards()
	# 其他类型/字段组合保持原值，让 _departure_problem 给出诊断。
	return result

func begin_replay() -> void:
	_replay_data = _defaults()
	_replaying = true

func end_replay() -> void:
	if _prologue_preview:
		return
	_replaying = false
	_replay_data = {}

## 只在旧档缺字段或字段损坏时从稳定第一章状态推断；保留全部经营状态。
## 与既有迁移一致：读取不落盘，下一次正常原子保存时持久化补齐字段。
func _migrate_prologue(parsed: Dictionary) -> void:
	if parsed.get(PROLOGUE_DONE_KEY) is bool:
		return
	_state[PROLOGUE_DONE_KEY] = is_chapter_1_done() or lifecycle_stage() != "not_started"
	_diagnose("序章标记迁移：" + str(_state[PROLOGUE_DONE_KEY]) + "；第一章与经营进度保持不变")

func is_prologue_done() -> bool:
	return _state.get(PROLOGUE_DONE_KEY, false) == true

func is_prologue_preview() -> bool:
	return _prologue_preview

## 仅在餐厅成功入树后调用。原子保存失败时回滚，不伪造观看/章节完成。
func complete_prologue() -> bool:
	if is_prologue_done():
		return true
	var previous := _state.duplicate(true)
	_state[PROLOGUE_DONE_KEY] = true
	if save():
		return true
	_state = previous
	_diagnose("序章完成标记保存失败，保留上次存档；本次仍可进入第一章")
	return false

func record_intro(stage: String) -> bool:
	if stage not in ["awakened", "guest_arrived"]:
		return false
	var previous: String = _state.get("chapter_1_intro", "not_started")
	if previous == "guest_arrived" or previous == stage:
		return true
	_state.chapter_1_intro = stage
	if save():
		return true
	_state.chapter_1_intro = previous
	return false

## 经营阶段从事务结果派生，不另存一个可能与库存矛盾的阶段标记。
func lifecycle_stage() -> String:
	if is_chapter_1_complete():
		return "done"
	if is_ready_to_depart():
		return "ready_to_depart"
	if can_start_departure():
		return "order_served"
	var progress := first_order_progress()
	if is_canonical_first_order(current_order()):
		if progress.next_step == "deliver" and progress.ingredients_claimed and inventory_quantity(FIRST_ORDER_ITEM_ID) >= 1:
			return "dish_ready"
		if progress.next_step == "cook" and progress.ingredients_claimed and inventory_quantity(ROCKMAN_MEAT_ID) >= 1 and inventory_quantity(ROCK_SALT_ID) >= 1:
			return "ingredients_collected"
		if _can_recover_cooking():
			# 中断恢复写盘失败时仍可回到料理台重试，不能再次扣料或刷星。
			return "ingredients_collected"
		if progress.next_step == "prepare_ingredients" and not progress.ingredients_claimed:
			return "order_accepted"
		_diagnose("首单进度与库存矛盾，保留经营数据并回退接单引导")
		return "guest_arrived"
	return str(_state.get("chapter_1_intro", "not_started"))

func _normalize_inventory(value) -> Dictionary:
	var inventory := {ROCKMAN_MEAT_ID: 0, ROCK_SALT_ID: 0, FIRST_ORDER_ITEM_ID: 0}
	if not value is Dictionary:
		_diagnose("inventory 类型错误，使用空库存视图")
		return inventory
	inventory = value.duplicate(true)
	for key in [ROCKMAN_MEAT_ID, ROCK_SALT_ID, FIRST_ORDER_ITEM_ID]:
		if typeof(value.get(key, 0)) not in [TYPE_INT, TYPE_FLOAT]:
			_diagnose("inventory." + key + " 数量类型错误，使用 0")
			inventory[key] = 0
			continue
		var quantity := int(value.get(key, 0))
		inventory[key] = maxi(0, quantity)
	return inventory

func _normalize_prepared_dishes(value) -> Dictionary:
	var dishes := {FIRST_ORDER_ITEM_ID: {"1": 0, "2": 0, "3": 0}}
	if not value is Dictionary:
		_diagnose("prepared_dishes 类型错误，按无星库存回退")
		return dishes
	dishes = value.duplicate(true)
	var raw = value.get(FIRST_ORDER_ITEM_ID, {})
	dishes[FIRST_ORDER_ITEM_ID] = raw.duplicate(true) if raw is Dictionary else {}
	if raw is Dictionary:
		for quality in ["1", "2", "3"]:
			var quantity = raw.get(quality, 0)
			if _valid_count(quantity):
				dishes[FIRST_ORDER_ITEM_ID][quality] = int(quantity)
			else:
				dishes[FIRST_ORDER_ITEM_ID][quality] = 0
				_diagnose("prepared_dishes 星级数量无效，回退 0：" + quality)
	else:
		dishes[FIRST_ORDER_ITEM_ID] = {"1": 0, "2": 0, "3": 0}
		_diagnose("prepared_dishes 成品缺少有效星级，按无星库存迁移")
	# 旧档只有无星成品数量时，按兼容契约迁移为 1 星。
	var legacy := int(dishes[FIRST_ORDER_ITEM_ID].get("1", 0))
	if _valid_count(value.get(FIRST_ORDER_ITEM_ID, null)):
		legacy += maxi(0, int(value.get(FIRST_ORDER_ITEM_ID, 0)))
		dishes[FIRST_ORDER_ITEM_ID]["1"] = legacy
	return dishes

func prepared_dishes_snapshot() -> Dictionary:
	var prepared := _normalize_prepared_dishes(_state.get(PREPARED_DISHES_KEY))
	var counts: Dictionary = prepared[FIRST_ORDER_ITEM_ID]
	var total := inventory_quantity(FIRST_ORDER_ITEM_ID)
	var graded := int(counts["1"]) + int(counts["2"]) + int(counts["3"])
	if total != graded:
		_diagnose("成品总数与星级数不一致，缺失星级按 1 星恢复；超额星级回退")
		if graded < total:
			counts["1"] += total - graded
		else:
			counts["1"] = total
			counts["2"] = 0
			counts["3"] = 0
	return prepared

func _valid_count(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value == floor(float(value))

func _normalize_cooking_state(value) -> Dictionary:
	var state := {"status": "idle", "recipe_id": "", "quality": 0, "pointer": 0.0}
	if not value is Dictionary:
		_diagnose("first_order_cooking 类型错误，回退 idle")
		return state
	state = value.duplicate(true)
	var status = value.get("status", "idle")
	state.status = status if status is String and status in ["idle", "active", "locked"] else "idle"
	if not status is String or status not in ["idle", "active", "locked"]:
		_diagnose("first_order_cooking.status 无效，回退 idle")
	var recipe = value.get("recipe_id", "")
	state.recipe_id = recipe if recipe is String and recipe in ["", FIRST_ORDER_ITEM_ID] else ""
	if not recipe is String or recipe not in ["", FIRST_ORDER_ITEM_ID]:
		_diagnose("first_order_cooking.recipe_id 无效，回退空配方")
	var quality = value.get("quality", 0)
	state.quality = int(quality) if _valid_count(quality) and quality <= 3 else 0
	if not _valid_count(quality) or quality > 3:
		_diagnose("first_order_cooking.quality 无效，回退 0")
	var pointer = value.get("pointer", 0.0)
	if typeof(pointer) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(pointer)) and absf(float(pointer)) <= 1.0:
		state.pointer = float(pointer)
	else:
		state.pointer = 0.0
		_diagnose("first_order_cooking.pointer 无效，回退 0")
	return state

func cooking_state() -> Dictionary:
	return _normalize_cooking_state(_state.get(COOKING_STATE_KEY)).duplicate(true)

## 只有已扣料且尚未产出这一份首单，才允许中断恢复。
func _can_recover_cooking() -> bool:
	var cooking := cooking_state()
	var progress := first_order_progress()
	return cooking.status == "active" and cooking.recipe_id == FIRST_ORDER_ITEM_ID \
		and is_canonical_first_order(current_order()) and not has_first_order_settlement() \
		and progress.ingredients_claimed and progress.next_step == "cook" \
		and inventory_quantity(ROCKMAN_MEAT_ID) == 0 and inventory_quantity(ROCK_SALT_ID) == 0 \
		and inventory_quantity(FIRST_ORDER_ITEM_ID) == 0

## 同进程跳过/离开场景使用同一原子起锅事务；写盘失败保留 active 可重试。
func recover_interrupted_cooking() -> Dictionary:
	if cooking_state().status != "active":
		return {"success": true, "created": false}
	if not _can_recover_cooking():
		_diagnose("中断烹饪状态矛盾，未增加成品")
		return {"success": false, "reason": "invalid_cooking_state"}
	return finish_first_order_cooking(1, 0.0)

func _normalize_progress(value) -> Dictionary:
	var progress := {"ingredients_claimed": false, "next_step": "accept_order"}
	if not value is Dictionary:
		_diagnose("first_order_progress 类型错误，回退接单引导")
		return progress
	progress = value.duplicate(true)
	var claimed = value.get("ingredients_claimed", false)
	if claimed is bool:
		progress["ingredients_claimed"] = claimed
	else:
		_diagnose("ingredients_claimed 类型错误，回退 false")
		progress["ingredients_claimed"] = false
	var next_step := str(value.get("next_step", "accept_order"))
	if next_step not in ["accept_order", "prepare_ingredients", "cook", "deliver", "chapter_wrap_up"]:
		_diagnose("first_order_progress.next_step 无效，回退接单引导")
		next_step = "accept_order"
	progress["next_step"] = next_step
	return progress

func save() -> bool:
	if _replaying:
		return true
	# 先完整写入同目录临时文件，再替换正式存档；失败时保留上次提交。
	var temporary_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(temporary_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_state, "\t"))
		f.flush()
		var write_error := f.get_error()
		f.close()
		if write_error == OK:
			return DirAccess.rename_absolute(temporary_path, SAVE_PATH) == OK
	return false

func is_tutorial_done() -> bool:
	return bool(_state.get("tutorial_done", false))

func mark_tutorial_done() -> void:
	_state["tutorial_done"] = true

func is_chapter_1_done() -> bool:
	return bool(_state.get(CHAPTER_1_DONE_KEY, false))

func mark_chapter_1_done() -> void:
	_state[CHAPTER_1_DONE_KEY] = true

func current_order() -> Dictionary:
	return _normalize_order(_state.get(CURRENT_ORDER_KEY))

func has_active_order() -> bool:
	return str(current_order().get("status", ORDER_STATUS_NONE)) == ORDER_STATUS_IN_PROGRESS

func is_canonical_first_order(order) -> bool:
	if not order is Dictionary or order.size() != 5:
		return false
	return str(order.get("id", "")) == FIRST_ORDER_ID \
		and str(order.get("item_id", "")) == FIRST_ORDER_ITEM_ID \
		and str(order.get("item_name", "")) == FIRST_ORDER_ITEM_NAME \
		and typeof(order.get("quantity")) in [TYPE_INT, TYPE_FLOAT] \
		and order.quantity == FIRST_ORDER_QUANTITY \
		and str(order.get("status", "")) == ORDER_STATUS_IN_PROGRESS

## 原子接受第一笔订单：相同有效订单重复调用保持幂等，不创建第二单。
## 返回 success=true 表示调用方可以继续教程；created 表示本次是否真的写入新订单。
func accept_first_order() -> Dictionary:
	if has_first_order_settlement() or str(current_order().get("status", "")) == ORDER_STATUS_COMPLETED:
		return {"success": false, "created": false, "reason": "already_completed", "order": current_order()}
	var raw_existing = _state.get(CURRENT_ORDER_KEY)
	if raw_existing is Dictionary \
			and str(raw_existing.get("status", ORDER_STATUS_NONE)) == ORDER_STATUS_IN_PROGRESS:
		var existing := current_order()
		if is_canonical_first_order(raw_existing):
			return {"success": true, "created": false, "reason": "already_active", "order": existing}
		return {"success": false, "created": false, "reason": "conflicting_order", "order": existing}

	var next_order := {
		"id": FIRST_ORDER_ID,
		"item_id": FIRST_ORDER_ITEM_ID,
		"item_name": FIRST_ORDER_ITEM_NAME,
		"quantity": FIRST_ORDER_QUANTITY,
		"status": ORDER_STATUS_IN_PROGRESS,
	}
	var previous_order = _state.get(CURRENT_ORDER_KEY)
	var previous_progress := first_order_progress()
	_state[CURRENT_ORDER_KEY] = next_order
	_state[FIRST_ORDER_PROGRESS_KEY] = {"ingredients_claimed": false, "next_step": "prepare_ingredients"}
	if not save():
		if previous_order is Dictionary:
			_state[CURRENT_ORDER_KEY] = previous_order
		else:
			_state[CURRENT_ORDER_KEY] = _empty_order()
		_state[FIRST_ORDER_PROGRESS_KEY] = previous_progress
		return {"success": false, "created": false, "reason": "save_failed", "order": current_order()}
	return {"success": true, "created": true, "reason": "created", "order": current_order()}

func inventory_snapshot() -> Dictionary:
	return _normalize_inventory(_state.get(INVENTORY_KEY)).duplicate(true)

func inventory_quantity(item_id: String) -> int:
	return int(inventory_snapshot().get(item_id, 0))

func first_order_progress() -> Dictionary:
	return _normalize_progress(_state.get(FIRST_ORDER_PROGRESS_KEY)).duplicate(true)

## 原子领取首单材料。只接受 canonical 首单；重复领取成功但不叠加。
func claim_first_order_ingredients() -> Dictionary:
	var order := current_order()
	if not is_canonical_first_order(order):
		return {"success": false, "created": false, "reason": "no_canonical_order", "inventory": inventory_snapshot()}
	var before_inventory := inventory_snapshot()
	var before_progress := first_order_progress()
	if bool(before_progress.get("ingredients_claimed", false)):
		return {"success": true, "created": false, "reason": "already_claimed", "inventory": before_inventory}
	var next_inventory := before_inventory.duplicate(true)
	next_inventory[ROCKMAN_MEAT_ID] = int(next_inventory.get(ROCKMAN_MEAT_ID, 0)) + 1
	next_inventory[ROCK_SALT_ID] = int(next_inventory.get(ROCK_SALT_ID, 0)) + 1
	_state[INVENTORY_KEY] = next_inventory
	_state[FIRST_ORDER_PROGRESS_KEY] = {"ingredients_claimed": true, "next_step": "cook"}
	if not save():
		_state[INVENTORY_KEY] = before_inventory
		_state[FIRST_ORDER_PROGRESS_KEY] = before_progress
		return {"success": false, "created": false, "reason": "save_failed", "inventory": before_inventory}
	return {"success": true, "created": true, "reason": "claimed", "inventory": inventory_snapshot(), "delta": {ROCKMAN_MEAT_ID: 1, ROCK_SALT_ID: 1}}

## 首单制作是一次提交：扣除两种材料、增加成品、保存交付进度。
## 只有成功写盘才能推进教程；重复制作失败且不改变库存或进度。
func cook_first_order() -> Dictionary:
	# 旧调用方兼容：直接制作等价于一次普通（1 星）起锅。
	var started := start_first_order_cooking()
	if not bool(started.get("success", false)) and str(started.get("reason", "")) != "already_started":
		return started
	return finish_first_order_cooking(1)

## 开始烹饪只扣材料一次，结果在 finish_first_order_cooking 中提交。
func start_first_order_cooking() -> Dictionary:
	if not is_canonical_first_order(current_order()):
		return {"success": false, "reason": "no_canonical_order"}
	var progress := first_order_progress()
	var cooking := cooking_state()
	if cooking.status in ["active", "locked"]:
		return {"success": false, "reason": "already_started", "cooking": cooking}
	if str(progress.get("next_step", "")) == "deliver":
		return {"success": false, "reason": "already_cooked"}
	if not bool(progress.get("ingredients_claimed", false)) or str(progress.get("next_step", "")) != "cook":
		return {"success": false, "reason": "ingredients_not_claimed"}
	var inventory := inventory_snapshot()
	if int(inventory[ROCKMAN_MEAT_ID]) < 1 or int(inventory[ROCK_SALT_ID]) < 1:
		return {"success": false, "reason": "insufficient_ingredients"}
	var previous := _state.duplicate(true)
	inventory[ROCKMAN_MEAT_ID] -= 1
	inventory[ROCK_SALT_ID] -= 1
	_state[INVENTORY_KEY] = inventory
	cooking.merge({"status": "active", "recipe_id": FIRST_ORDER_ITEM_ID, "quality": 0, "pointer": 0.0}, true)
	_state[COOKING_STATE_KEY] = cooking
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "started", "inventory": inventory_snapshot(), "cooking": cooking_state()}

## 锁定品质并保存成品；同名料理按星级分别计数。
func finish_first_order_cooking(quality: int, pointer := 0.0) -> Dictionary:
	if not is_canonical_first_order(current_order()):
		return {"success": false, "reason": "no_canonical_order"}
	var cooking := cooking_state()
	if cooking.status == "locked":
		return {"success": false, "reason": "already_cooked", "quality": cooking.quality}
	if cooking.status != "active":
		return {"success": false, "reason": "not_started"}
	if not _can_recover_cooking():
		return {"success": false, "reason": "invalid_cooking_state"}
	var stars := clampi(quality, 1, 3)
	var prepared := prepared_dishes_snapshot()
	prepared[FIRST_ORDER_ITEM_ID][str(stars)] = int(prepared[FIRST_ORDER_ITEM_ID].get(str(stars), 0)) + 1
	var inventory := inventory_snapshot()
	inventory[FIRST_ORDER_ITEM_ID] += 1
	var progress := first_order_progress()
	progress["next_step"] = "deliver"
	var previous := _state.duplicate(true)
	_state[INVENTORY_KEY] = inventory
	_state[PREPARED_DISHES_KEY] = prepared
	_state[FIRST_ORDER_PROGRESS_KEY] = progress
	cooking.merge({"status": "locked", "recipe_id": FIRST_ORDER_ITEM_ID, "quality": stars, "pointer": clampf(float(pointer), -1.0, 1.0)}, true)
	_state[COOKING_STATE_KEY] = cooking
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "cooked", "quality": stars, "inventory": inventory_snapshot(), "cooking": cooking_state()}

func reputation() -> int:
	return int(_state.get(REPUTATION_KEY, 0))

func has_first_order_settlement() -> bool:
	var receipt = _state.get(FIRST_ORDER_SETTLEMENT_KEY, {})
	var canonical: bool = receipt is Dictionary and str(receipt.get("order_id", "")) == FIRST_ORDER_ID \
		and str(receipt.get("item_id", "")) == FIRST_ORDER_ITEM_ID \
		and typeof(receipt.get("quantity")) in [TYPE_INT, TYPE_FLOAT] \
		and receipt.quantity == FIRST_ORDER_QUANTITY \
		and _valid_count(receipt.get("reputation_awarded"))
	if not canonical:
		return false
	if not receipt.has("quality"):
		return receipt.reputation_awarded == 20 # 历史无星凭证保持原奖励。
	var quality = receipt.quality
	return _valid_count(quality) and int(quality) in [1, 2, 3] \
		and receipt.reputation_awarded == QUALITY_REPUTATION[int(quality)]

func cooked_quality() -> int:
	var prepared: Dictionary = prepared_dishes_snapshot().get(FIRST_ORDER_ITEM_ID, {})
	for quality in [3, 2, 1]:
		if int(prepared.get(str(quality), 0)) > 0:
			return quality
	return 0

## 交付、订单完成、声望与凭证在同一存档提交；失败恢复完整内存快照。
## 地点与距离由 TutorialManager/Player 的同一交互选择器校验。
func deliver_first_order() -> Dictionary:
	if has_first_order_settlement() or str(current_order().get("status", "")) == ORDER_STATUS_COMPLETED:
		return {"success": false, "reason": "already_completed"}
	if not is_canonical_first_order(current_order()):
		return {"success": false, "reason": "no_canonical_order"}
	var progress := first_order_progress()
	if not bool(progress.get("ingredients_claimed", false)) or str(progress.get("next_step", "")) != "deliver":
		return {"success": false, "reason": "not_ready_to_deliver"}
	var inventory := inventory_snapshot()
	if int(inventory[FIRST_ORDER_ITEM_ID]) < FIRST_ORDER_QUANTITY:
		return {"success": false, "reason": "missing_dish"}
	var previous := _state.duplicate(true)
	var order := current_order()
	var quality := cooked_quality()
	if quality <= 0:
		quality = 1 # 旧无星成品兼容为普通品质
	var prepared := prepared_dishes_snapshot()
	inventory[FIRST_ORDER_ITEM_ID] -= FIRST_ORDER_QUANTITY
	prepared[FIRST_ORDER_ITEM_ID][str(quality)] = maxi(0, int(prepared[FIRST_ORDER_ITEM_ID].get(str(quality), 0)) - 1)
	order["status"] = ORDER_STATUS_COMPLETED
	progress["next_step"] = "chapter_wrap_up"
	_state[INVENTORY_KEY] = inventory
	_state[CURRENT_ORDER_KEY] = order
	_state[FIRST_ORDER_PROGRESS_KEY] = progress
	var reward := int(QUALITY_REPUTATION.get(quality, FIRST_ORDER_REPUTATION))
	_state[PREPARED_DISHES_KEY] = prepared
	_state[REPUTATION_KEY] = reputation() + reward
	_state[FIRST_ORDER_SETTLEMENT_KEY] = {
		"order_id": FIRST_ORDER_ID, "item_id": FIRST_ORDER_ITEM_ID,
		"quantity": FIRST_ORDER_QUANTITY, "quality": quality, "reputation_awarded": reward,
	}
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "delivered", "quality": quality, "reputation_awarded": reward, "order": current_order(), "reputation": reputation()}
