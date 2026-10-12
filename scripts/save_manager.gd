extends Node
## 存档管理器（Autoload: SaveManager）
## 全量 JSON 存档；旧 save.json 与独立档共用迁移和原子保存。

const SAVE_PATH := "user://save.json"
const SLOTS_DIR := "user://saves"
const SLOT_META_KEY := "_save_slot"
const MazeRoads := preload("res://data/maze/entry_roads.gd")
const MAZE_STATE_KEY := "maze_exploration"
const MAZE_SCENE := "res://scenes/maze_entry.tscn"
const RESTAURANT_SCENE := "res://scenes/restaurant_map_2d.tscn"
const ChestCatalog := preload("res://data/maze/entry_chests.gd")
const GOLD_KEY := "gold"
const CLAIMED_CHESTS_KEY := "claimed_chests"
const DigCatalog := preload("res://data/maze/entry_dig_sites.gd")
const CLAIMED_DIG_SITES_KEY := "claimed_dig_sites"
var _active_save_path := SAVE_PATH
var last_load_error := ""
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
const COOKING_GUIDE_KEY := "cooking_guide_seen"
const TUTORIAL_CHECKPOINT_KEY := "tutorial_checkpoint"
const PREPARED_DISHES_KEY := "prepared_dishes"
const UNLOCKED_RECIPES_KEY := "unlocked_recipe_ids"
const RecipeCatalog := preload("res://scripts/cooking/recipe_catalog.gd")
const QuestRegistry := preload("res://scripts/quests/quest_registry.gd")
const QUEST_JOURNAL_KEY := "quest_journal"
const SALT_POOL_QUEST_ID := "chapter_1_salt_pool"
const QUALITY_REPUTATION := {1: 60, 2: 80, 3: 100}
const LEGACY_QUALITY_REPUTATION := {1: 10, 2: 12, 3: 15}
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
const HomeCardArt := preload("res://scripts/ui/components/home_card_art.gd")
## 顺序是存档契约；已确认的对白逐句提交，重进从尚未确认的一句继续。
const WRAPUP_STEPS := ["relief", "meat", "yaya_past", "hero_past", "yaya_yes",
	"second_serving", "check_store", "warehouse_move", "warehouse_inspect", "yaya_empty",
	"hero_where", "salt_pool",
	"map_review", "introduction", "offer", "no", "memory", "cooking", "ingredients",
	"yaya_join", "stay_shallow", "agreement", "yaya_ready", "ready_to_depart"]
## 保留历史检查点用于校验旧档；删合对白后直接接续下一句，无额外按键。
const RETIRED_WRAPUP_STEPS := {"offer": "no", "memory": "cooking",
	"ingredients": "yaya_join", "stay_shallow": "agreement"}

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
		"warehouse_stock": {ROCKMAN_MEAT_ID: 1, ROCK_SALT_ID: 1},
		PREPARED_DISHES_KEY: {FIRST_ORDER_ITEM_ID: {"1": 0, "2": 0, "3": 0}},
		UNLOCKED_RECIPES_KEY: [],
		COOKING_STATE_KEY: {"status": "idle", "recipe_id": "", "quality": 0, "pointer": 0.0},
		COOKING_GUIDE_KEY: false,
		TUTORIAL_CHECKPOINT_KEY: _empty_tutorial_checkpoint(),
		FIRST_ORDER_PROGRESS_KEY: {"ingredients_claimed": false, "next_step": "accept_order"},
		FIRST_ORDER_SETTLEMENT_KEY: {},
		REPUTATION_KEY: 0,
		WRAPUP_KEY: _empty_departure(),
		QUEST_JOURNAL_KEY: QuestRegistry.empty_journal(),
		"chapter_1_intro": "not_started",
		MAZE_STATE_KEY: _empty_maze_state(),
		GOLD_KEY: 0,
		CLAIMED_CHESTS_KEY: [],
		CLAIMED_DIG_SITES_KEY: [],
	}

## 木材数量不静默归零；坏数据保留并阻止发奖，旧档缺字段等价于未领取。
func dig_reward_state_valid() -> bool:
	var inventory = _state.get(INVENTORY_KEY)
	if not inventory is Dictionary:
		return false
	var quantity = inventory.get(DigCatalog.ITEM_ID, 0)
	if typeof(quantity) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(quantity)) \
			or quantity < 0 or quantity > 9007199254740991 or quantity != floor(float(quantity)):
		return false
	var claims = _state.get(CLAIMED_DIG_SITES_KEY, [])
	if not claims is Array:
		return false
	for id in claims:
		if not id is String or id.is_empty():
			return false
	return true

func is_dig_site_claimed(id: String) -> bool:
	var claims = _state.get(CLAIMED_DIG_SITES_KEY, [])
	return claims is Array and id in claims

## 木材、一次性领取标记、站位同一事务落盘；失败完整回滚。
func claim_exploration_dig_site(id: String, point: Vector2) -> Dictionary:
	var site := DigCatalog.find(id)
	if site.is_empty() or not can_enter_maze() or maze_exploration_state().region != "maze_entry" \
			or not MazeRoads.is_walkable(point) or point.distance_to(site.position) > DigCatalog.INTERACT_RADIUS:
		return {"success": false, "reason": "invalid_site_or_location"}
	if not dig_reward_state_valid():
		return {"success": false, "reason": "invalid_reward_state"}
	var quantity := int(_state[INVENTORY_KEY].get(DigCatalog.ITEM_ID, 0))
	if quantity > 9007199254740991 - DigCatalog.REWARD:
		return {"success": false, "reason": "invalid_reward_state"}
	if is_dig_site_claimed(id):
		return {"success": false, "reason": "already_claimed"}
	var previous := _state.duplicate(true)
	var claims: Array = _state.get(CLAIMED_DIG_SITES_KEY, []).duplicate()
	claims.append(id)
	_state[INVENTORY_KEY][DigCatalog.ITEM_ID] = quantity + DigCatalog.REWARD
	_state[CLAIMED_DIG_SITES_KEY] = claims
	var location := maze_exploration_state()
	location.position = [point.x, point.y]
	_state[MAZE_STATE_KEY] = location
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "amount": DigCatalog.REWARD, "total": quantity + DigCatalog.REWARD}

## 金币使用 JSON 可精确往返的非负整数。异常字段保留原值，禁止继续发奖。
func chest_reward_state_valid() -> bool:
	var amount = _state.get(GOLD_KEY, 0)
	if typeof(amount) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(amount)) \
			or amount < 0 or amount > 9007199254740991 or amount != floor(float(amount)):
		_diagnose("金币字段无效，保留原值并暂停宝箱领取")
		return false
	var claims = _state.get(CLAIMED_CHESTS_KEY, [])
	if not claims is Array:
		_diagnose("宝箱领取记录无效，保留原值并暂停领取")
		return false
	for id in claims:
		if not id is String or id.is_empty():
			_diagnose("宝箱领取 ID 无效，保留原记录并暂停领取")
			return false
	return true

func gold_balance() -> int:
	return int(_state.get(GOLD_KEY, 0)) if chest_reward_state_valid() else 0

## 已领取凭证保留首次获币资格，余额归零不收起；旧档只读兼容，不修复坏数据。
func is_gold_display_unlocked() -> bool:
	if not chest_reward_state_valid():
		return false
	return int(_state.get(GOLD_KEY, 0)) > 0 or not _state.get(CLAIMED_CHESTS_KEY, []).is_empty()

func is_chest_claimed(id: String) -> bool:
	var claims = _state.get(CLAIMED_CHESTS_KEY, [])
	return claims is Array and id in claims

## 探索物件事务；不是游戏任务，不产生声望、任务或其他奖励。
func claim_exploration_chest(id: String, point: Vector2) -> Dictionary:
	var chest := ChestCatalog.find(id)
	if chest.is_empty() or not can_enter_maze() or maze_exploration_state().region != "maze_entry" \
			or not MazeRoads.is_walkable(point) or point.distance_to(chest.position) > ChestCatalog.INTERACT_RADIUS:
		return {"success": false, "reason": "invalid_chest_or_location"}
	if not chest_reward_state_valid() or gold_balance() > 9007199254740991 - ChestCatalog.REWARD:
		return {"success": false, "reason": "invalid_reward_state"}
	if is_chest_claimed(id):
		return {"success": false, "reason": "already_claimed"}
	var previous := _state.duplicate(true)
	var claims: Array = _state.get(CLAIMED_CHESTS_KEY, []).duplicate()
	claims.append(id)
	_state[GOLD_KEY] = gold_balance() + ChestCatalog.REWARD
	_state[CLAIMED_CHESTS_KEY] = claims
	var location := maze_exploration_state()
	location.position = [point.x, point.y]
	_state[MAZE_STATE_KEY] = location
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "amount": ChestCatalog.REWARD, "total": gold_balance()}

func _empty_maze_state() -> Dictionary:
	return {"version": 1, "region": "restaurant", "position": [MazeRoads.SPAWN.x, MazeRoads.SPAWN.y], "chapter_2_started": false}

func can_enter_maze() -> bool:
	return is_chapter_1_complete() and chapter_1_outro_state() == "done" and not _replaying

## 纯读迁移；老档不假定到过迷宫，坏坐标只恢复石门安全站位。
func maze_exploration_state() -> Dictionary:
	var saved = _state.get(MAZE_STATE_KEY, _empty_maze_state())
	if not saved is Dictionary or saved.get("version") != 1 \
			or saved.get("region") not in ["restaurant", "maze_entry"] \
			or not saved.get("chapter_2_started") is bool:
		_diagnose("迷宫探索记录无效，回退餐厅")
		return _empty_maze_state()
	if not can_enter_maze():
		return _empty_maze_state()
	var result: Dictionary = saved.duplicate(true)
	if result.region == "maze_entry" and not result.chapter_2_started:
		_diagnose("迷宫区域缺少第二章开始记录，回退餐厅")
		return _empty_maze_state()
	var coordinates = result.get("position")
	var valid: bool = coordinates is Array and coordinates.size() == 2
	if valid:
		valid = typeof(coordinates[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(coordinates[1]) in [TYPE_INT, TYPE_FLOAT]
	if valid:
		valid = MazeRoads.is_walkable(Vector2(coordinates[0], coordinates[1]))
	if not valid:
		_diagnose("迷宫站位无效，恢复石门安全点")
		result.position = [MazeRoads.SPAWN.x, MazeRoads.SPAWN.y]
	return result

func resume_scene_path() -> String:
	return MAZE_SCENE if maze_exploration_state().region == "maze_entry" else RESTAURANT_SCENE

## 由成功就绪的迷宫场景提交；保存失败同时回滚区域与开始标记。
func record_maze_location(region: String, point: Vector2) -> Dictionary:
	if not can_enter_maze() or region not in ["restaurant", "maze_entry"] or not MazeRoads.is_walkable(point):
		return {"success": false, "reason": "invalid_location", "created": false}
	var state := maze_exploration_state()
	var created: bool = region == "maze_entry" and not state.chapter_2_started
	var next := {"version": 1, "region": region, "position": [point.x, point.y], "chapter_2_started": state.chapter_2_started or region == "maze_entry"}
	if _state.get(MAZE_STATE_KEY) == next:
		return {"success": true, "reason": "unchanged", "created": false}
	var previous := _state.duplicate(true)
	_state[MAZE_STATE_KEY] = next
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed", "created": false}
	return {"success": true, "reason": "saved", "created": created}

func _empty_order() -> Dictionary:
	return {
		"id": "",
		"item_id": "",
		"item_name": "",
		"quantity": 0,
		"status": ORDER_STATUS_NONE,
	}

func _empty_tutorial_checkpoint() -> Dictionary:
	return {"chapter": 1, "next_index": 0, "step_key": "", "line_index": 0}

func _normalize_tutorial_checkpoint(value) -> Dictionary:
	var checkpoint := _empty_tutorial_checkpoint()
	if not value is Dictionary:
		_diagnose("tutorial_checkpoint 类型错误，回退教程起点")
		return checkpoint
	var chapter = value.get("chapter", 1)
	var next_index = value.get("next_index", 0)
	var step_key = value.get("step_key", "")
	var line_index = value.get("line_index", 0)
	if typeof(chapter) not in [TYPE_INT, TYPE_FLOAT] or chapter != 1:
		_diagnose("tutorial_checkpoint.chapter 无效，回退教程起点")
		return checkpoint
	if typeof(next_index) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(next_index)) or next_index < 0 or next_index > 2147483647 or next_index != floor(float(next_index)):
		_diagnose("tutorial_checkpoint.next_index 无效，回退教程起点")
		return checkpoint
	if not step_key is String:
		_diagnose("tutorial_checkpoint.step_key 类型错误，回退教程起点")
		return checkpoint
	if typeof(line_index) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(line_index)) or line_index < 0 or line_index > 2147483647 or line_index != floor(float(line_index)):
		_diagnose("tutorial_checkpoint.line_index 无效，回退教程起点")
		return checkpoint
	checkpoint.next_index = int(next_index)
	checkpoint.step_key = step_key
	checkpoint.line_index = int(line_index)
	return checkpoint

func tutorial_checkpoint() -> Dictionary:
	return _normalize_tutorial_checkpoint(_state.get(TUTORIAL_CHECKPOINT_KEY)).duplicate(true)

## 对白或教程操作确认后提交下一步；重播只更新副本，不碰正式存档。
func save_tutorial_checkpoint(next_index: int, step_key: String, line_index := 0) -> bool:
	if _replaying:
		return true
	if next_index < 0 or line_index < 0 or (step_key.is_empty() and next_index > 0):
		return false
	var previous := _state.duplicate(true)
	_state[TUTORIAL_CHECKPOINT_KEY] = {"chapter": 1, "next_index": next_index, "step_key": step_key, "line_index": line_index}
	if save():
		return true
	_state = previous
	return false

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
		"characters": {"yaya": {"attack": 2, "max_hp": 4}, "tieshan": {"attack": 1, "max_hp": 5}}}

func departure_state() -> Dictionary:
	var saved = _state.get(WRAPUP_KEY)
	var problem := _departure_problem(saved)
	if not problem.is_empty():
		_diagnose("准备状态回退 relief：" + problem)
		return _empty_departure()
	var state: Dictionary = saved.duplicate(true)
	state.step = RETIRED_WRAPUP_STEPS.get(state.step, state.step)
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
	var ready: bool = value.step in ["yaya_ready", "ready_to_depart"]
	if value.party != (["yaya", "tieshan"] if ready else []) or value.objective != (DEPARTURE_OBJECTIVE if ready else "") or value.entrance_lit != ready:
		return "队伍、目标、入口与步骤矛盾"
	if value.empty_warehouse_checked != (index > WRAPUP_STEPS.find("warehouse_inspect")) or value.tieshan_name_revealed != (index > WRAPUP_STEPS.find("introduction")):
		return "仓库或姓名检查点与步骤矛盾"
	var finished: bool = _state.get(CHAPTER_1_DONE_KEY) is bool and _state.get(CHAPTER_1_DONE_KEY) == true and _state.get("tutorial_done") is bool and _state.get("tutorial_done") == true and value.step == "ready_to_depart" and has_first_order_settlement()
	if index > 0 and not finished and not can_start_departure():
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
				and typeof(yaya.get("max_hp")) in [TYPE_INT, TYPE_FLOAT] and yaya.max_hp == 4 \
				and typeof(tieshan.get("attack")) in [TYPE_INT, TYPE_FLOAT] and tieshan.attack == 1 \
				and typeof(tieshan.get("max_hp")) in [TYPE_INT, TYPE_FLOAT] and tieshan.max_hp == 5 \
				and cards.size() == 5:
			return ""
	return "cards schema 无效或卡牌列表不完整"

func cards_state() -> Dictionary:
	var cards = departure_state().get("cards", _pending_cards())
	return cards.duplicate(true)

## 原图收藏的数量快照。缺字段的旧档仅兼容已收录角色的已确认首批卡牌；
## 明确空表/零数量不会重新填满。只读，不因浏览自动解锁或写盘。
func owned_character_card_counts() -> Dictionary:
	if _state.has(HomeCardArt.COLLECTION_KEY):
		var stored = _state[HomeCardArt.COLLECTION_KEY]
		if HomeCardArt.valid_counts(stored):
			var counts := {}
			for id in stored: counts[id] = int(stored[id])
			return counts
		_diagnose("原图卡牌拥有数量无效，保留原始记录并显示空列表。")
		return {}
	return HomeCardArt.initial_counts(departure_state().get("party", []))

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

## 收尾表现检查点与既有出发契约分离。旧已完成档不强制重播。
func chapter_1_outro_state() -> String:
	var saved = _state.get("chapter_1_outro", "")
	if is_chapter_1_complete():
		return "title" if saved == "title" else "done"
	if not is_ready_to_depart():
		return ""
	return str(saved) if saved in ["party", "home", "maze"] else "party"

func has_pending_chapter_1_outro() -> bool:
	return chapter_1_outro_state() in ["party", "home", "maze", "title"]

func advance_chapter_1_outro(expected: String) -> Dictionary:
	var sequence := ["party", "home", "maze", "title", "done"]
	var index := sequence.find(expected)
	if index < 0 or index >= sequence.size() - 1 or chapter_1_outro_state() != expected:
		return {"success": false, "created": false, "reason": "wrong_step"}
	var previous := _state.duplicate(true)
	var created := expected == "maze" and not is_chapter_1_complete()
	_state["chapter_1_outro"] = sequence[index + 1]
	if expected == "maze":
		# 最后一句对白结束即完成章节；蒙层留待玩家另按E关闭。
		_state[CHAPTER_1_DONE_KEY] = true
		_state["tutorial_done"] = true
	if not save():
		_state = previous
		return {"success": false, "created": false, "reason": "save_failed"}
	return {"success": true, "created": created, "reason": "advanced"}

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
	# 完章后的补货与后续订单不能使章节状态倒退。
	return is_chapter_1_done() and is_tutorial_done() and departure_state().step == "ready_to_depart"

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
	state.step = RETIRED_WRAPUP_STEPS.get(state.step, state.step)
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
			# 只在首次收录事务中记录首批卡牌；后续浏览不按素材目录补齐。
			if not _state.has(HomeCardArt.COLLECTION_KEY):
				_state[HomeCardArt.COLLECTION_KEY] = HomeCardArt.initial_counts(state.party)
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
	last_load_error = ""
	migration_diagnostics.clear()
	data = _defaults()
	if FileAccess.file_exists(_active_save_path):
		var f := FileAccess.open(_active_save_path, FileAccess.READ)
		if f:
			var parser := JSON.new()
			var error := parser.parse(f.get_as_text())
			f.close()
			if error != OK:
				last_load_error = "存档内容损坏：" + parser.get_error_message()
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
				if not parsed.has(HomeCardArt.COLLECTION_KEY) and not departure_state().party.is_empty():
					_state[HomeCardArt.COLLECTION_KEY] = owned_character_card_counts()
					_diagnose("旧档原图卡牌记录补齐已确认首批数量，未写盘。")
				_state[CURRENT_ORDER_KEY] = _normalize_order(_state.get(CURRENT_ORDER_KEY))
				_state[INVENTORY_KEY] = _normalize_inventory(_state.get(INVENTORY_KEY))
				_state[FIRST_ORDER_PROGRESS_KEY] = _normalize_progress(_state.get(FIRST_ORDER_PROGRESS_KEY))
				if not parsed.has("warehouse_stock"):
					# 必须移除合并时的默认库存，才能依据原有领取记录迁移。
					_state.erase("warehouse_stock")
					_state["warehouse_stock"] = warehouse_snapshot()
				_state[PREPARED_DISHES_KEY] = prepared_dishes_snapshot()
				_state[COOKING_STATE_KEY] = _normalize_cooking_state(_state.get(COOKING_STATE_KEY))
				# 仅旧档缺字段时从有效首单历史补解锁；不改变库存或奖励。
				if not parsed.has(UNLOCKED_RECIPES_KEY) and _has_first_recipe_history():
					_state[UNLOCKED_RECIPES_KEY] = [FIRST_ORDER_ITEM_ID]
				_state[UNLOCKED_RECIPES_KEY] = unlocked_recipe_ids()
				if _state[COOKING_STATE_KEY].status == "active":
					# 读取迁移不写盘；重复读取同一 active 档只恢复这一份料理。
					if _can_recover_cooking():
						_state[COOKING_STATE_KEY].status = "locked"
						_state[COOKING_STATE_KEY].quality = 1
						_state[COOKING_STATE_KEY].pointer = 0.0
						_state[INVENTORY_KEY][FIRST_ORDER_ITEM_ID] = 1
						_state[PREPARED_DISHES_KEY][FIRST_ORDER_ITEM_ID]["1"] = 1
						if not _has_followup_order():
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
				_state[TUTORIAL_CHECKPOINT_KEY] = _normalize_tutorial_checkpoint(_state.get(TUTORIAL_CHECKPOINT_KEY))
				_state[QUEST_JOURNAL_KEY] = _quest_journal()
				_state[MAZE_STATE_KEY] = maze_exploration_state()
				return
			last_load_error = "存档内容无效，顶层必须是字典"
			_diagnose("存档顶层必须是字典，回退默认状态")
		else:
			last_load_error = "存档读取失败：" + str(FileAccess.get_open_error())
			_diagnose("存档读取失败，回退默认状态：" + str(FileAccess.get_open_error()))
	else:
		last_load_error = "存档不存在或无法访问"
	_state = _defaults()

## 列表只读；坏档保留为可选条目，载入时报告错误，不当成新游戏。
func list_save_slots() -> Dictionary:
	var paths: Array[String] = []
	if FileAccess.file_exists(SAVE_PATH):
		paths.append(SAVE_PATH)
	if FileAccess.file_exists(SLOTS_DIR):
		return {"success": false, "message": "存档目录被同名文件占用，无法读取存档列表。", "slots": []}
	if DirAccess.dir_exists_absolute(SLOTS_DIR):
		var directory := DirAccess.open(SLOTS_DIR)
		if directory == null:
			return {"success": false, "message": "无法读取存档目录，请检查访问权限。", "slots": []}
		for filename in directory.get_files():
			if filename.ends_with(".json"):
				paths.append(SLOTS_DIR.path_join(filename))
	var slots: Array[Dictionary] = []
	paths.sort()
	for path in paths:
		var label := ""
		var modified := FileAccess.get_modified_time(path)
		var problem := ""
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			problem = "读取失败"
		else:
			var parser := JSON.new()
			var error := parser.parse(file.get_as_text())
			file.close()
			if error != OK or not parser.data is Dictionary:
				problem = "内容损坏"
			else:
				var metadata = parser.data.get(SLOT_META_KEY, {})
				if metadata is Dictionary and metadata.get("name") is String:
					label = metadata.name
					if not metadata.get("custom_name", false) and _is_legacy_slot_name(label, str(metadata.get("id", ""))):
						label = ""
		slots.append({"id": path, "name": label, "saved_at": modified,
			"time_text": save_date_text(modified), "problem": problem})
	# 先按固定路径分配旧档显示名，再按保存时间排序；读取不修改任何旧档。
	var used_names: Array[String] = []
	for slot in slots:
		if not slot.name.is_empty():
			used_names.append(slot.name)
	var number := 1
	for slot in slots:
		if slot.name.is_empty():
			while used_names.has("冒险%d" % number):
				number += 1
			slot.name = "冒险%d" % number
			used_names.append(slot.name)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return {"success": true, "message": "", "slots": slots}

func save_date_text(timestamp: int) -> String:
	# 存档时间固定北京时间，显示到秒，不跟随运行机器的时区。
	return Time.get_datetime_string_from_unix_time(timestamp + 8 * 3600).replace("T", " ")

func _is_legacy_slot_name(label: String, id: String) -> bool:
	if id.is_empty() or not label.ends_with(" · " + id.right(4).to_upper()):
		return false
	var pattern := RegEx.new()
	pattern.compile("^新冒险 [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} · [0-9A-F]{4}$")
	return pattern.search(label) != null

func active_save_path() -> String:
	return _active_save_path

func _valid_slot_path(path: String) -> bool:
	return path == SAVE_PATH or (path.get_base_dir() == SLOTS_DIR and path.ends_with(".json") and not path.contains("..") and not path.contains("\\"))

## 名称仅写入元数据，不改文件路径，不迁移或重写经营进度。
func rename_save_slot(path: String, requested_name: String) -> Dictionary:
	if _replaying or _prologue_preview or not _valid_slot_path(path):
		return {"success": false, "message": "当前不能管理此存档。"}
	var label := requested_name.strip_edges()
	if label.is_empty() or label.length() > 40 or label.contains("\n") or label.contains("\r") or label.contains("\t"):
		return {"success": false, "message": "名称须为 1–40 个字符，不能包含换行或制表符。"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "message": "存档读取失败，未更改名称。"}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {"success": false, "message": "存档内容损坏，无法重命名；原文件已保留。"}
	var snapshot: Dictionary = parser.data
	var metadata = snapshot.get(SLOT_META_KEY, {})
	metadata = metadata.duplicate(true) if metadata is Dictionary else {}
	if metadata.get("name") == label:
		return {"success": true, "changed": false}
	metadata["name"] = label
	metadata["custom_name"] = true
	snapshot[SLOT_META_KEY] = metadata
	if not _write_atomic(path, snapshot):
		return {"success": false, "message": "重命名保存失败，原存档和进度已保留。"}
	if path == _active_save_path:
		data[SLOT_META_KEY] = metadata.duplicate(true)
	return {"success": true, "changed": true}

## 删除成功才解除活动档绑定，避免后续自动保存复活已删除的文件。
## 不选择其他档案；重复删除返回失败但保持状态不变。
func delete_save_slot(path: String) -> Dictionary:
	if _replaying or _prologue_preview or not _valid_slot_path(path):
		return {"success": false, "message": "当前不能管理此存档。"}
	if not FileAccess.file_exists(path):
		return {"success": false, "message": "存档不存在或无法访问，请刷新列表。"}
	if DirAccess.remove_absolute(path) != OK:
		return {"success": false, "message": "删除失败，原存档和进度已保留，请检查访问权限。"}
	if path == _active_save_path:
		_active_save_path = ""
		data = _defaults()
		migration_diagnostics.clear()
		last_load_error = ""
	return {"success": true}

## 首次落盘成功才切换活动档；一份文件即一份档案，不依赖可失配的索引。
func create_new_game() -> Dictionary:
	if _replaying or _prologue_preview:
		return {"success": false, "message": "重播期间不能创建正式存档。"}
	if DirAccess.make_dir_recursive_absolute(SLOTS_DIR) != OK:
		return {"success": false, "message": "无法创建存档目录，请检查磁盘和访问权限。"}
	var id := str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var path := SLOTS_DIR.path_join(id + ".json")
	if FileAccess.file_exists(path):
		return {"success": false, "message": "存档名称冲突，请重试。"}
	var fresh := _defaults()
	var existing := list_save_slots()
	if not existing.success:
		return {"success": false, "message": existing.message}
	var names: Array[String] = []
	for slot in existing.slots:
		names.append(slot.name)
	var number := 1
	while names.has("冒险%d" % number):
		number += 1
	fresh[SLOT_META_KEY] = {"name": "冒险%d" % number, "id": id}
	if not _write_atomic(path, fresh):
		return {"success": false, "message": "新存档保存失败，原有进度已保留，请检查磁盘和访问权限。"}
	data = fresh
	_active_save_path = path
	migration_diagnostics.clear()
	last_load_error = ""
	return {"success": true, "id": path}

## 载入失败恢复内存、活动路径及迁移诊断；不会覆盖坏档或静默开新局。
func load_save_slot(path: String) -> Dictionary:
	if _replaying or _prologue_preview:
		return {"success": false, "message": "重播期间不能切换正式存档。"}
	if not _valid_slot_path(path):
		return {"success": false, "message": "存档路径无效。"}
	var previous := data.duplicate(true)
	var previous_path := _active_save_path
	var previous_diagnostics := migration_diagnostics.duplicate()
	_active_save_path = path
	load_data()
	if not last_load_error.is_empty():
		data = previous
		_active_save_path = previous_path
		migration_diagnostics = previous_diagnostics
		return {"success": false, "message": last_load_error + "。原有进度已保留，请选择其他存档。"}
	return {"success": true, "id": path}

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

func needs_cooking_guide() -> bool:
	return not is_chapter_1_done() and is_canonical_first_order(current_order()) \
		and _state.get(COOKING_GUIDE_KEY, false) != true

func acknowledge_cooking_guide() -> bool:
	var previous := _state.duplicate(true)
	_state[COOKING_GUIDE_KEY] = true
	if save():
		return true
	_state = previous
	return false

## 只有已扣料且尚未产出这一份首单，才允许中断恢复。
func _can_recover_cooking() -> bool:
	var cooking := cooking_state()
	var progress := first_order_progress()
	var valid_context: bool = cooking.status == "active" and cooking.recipe_id == FIRST_ORDER_ITEM_ID \
		and ((_has_followup_order()) or (is_canonical_first_order(current_order()) and not has_first_order_settlement() \
		and progress.ingredients_claimed and progress.next_step == "cook")) \
		and inventory_quantity(FIRST_ORDER_ITEM_ID) == 0
	if not valid_context:
		return false
	# 旧版本只允许首单一份原料，因此无事务明细的旧 active 档仍严格核对零余额。
	if not cooking.has("ingredients_consumed") and not cooking.has("ingredient_balances"):
		return inventory_quantity(ROCKMAN_MEAT_ID) == 0 and inventory_quantity(ROCK_SALT_ID) == 0
	var required: Dictionary = RecipeCatalog.get_recipe(cooking.recipe_id).get("ingredients", {})
	var consumed = cooking.get("ingredients_consumed")
	var balances = cooking.get("ingredient_balances")
	if not consumed is Dictionary or consumed.size() != required.size() or not balances is Dictionary or balances.size() != required.size():
		return false
	for item_id in required:
		# JSON 读取会把整数恢复为浮点数，按合法整数数量比较而非字典类型相等。
		if not _valid_count(consumed.get(item_id)) or int(consumed[item_id]) != int(required[item_id]):
			return false
		if not _valid_count(balances.get(item_id)) or inventory_quantity(item_id) != int(balances[item_id]):
			return false
	return true

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
	# 任务变化与原业务事务共用一次原子提交；失败不留下半份任务状态。
	var snapshot := _state.duplicate(true)
	snapshot[QUEST_JOURNAL_KEY] = _quest_journal()
	if _replaying:
		_state = snapshot
		return true
	if _active_save_path.is_empty():
		return false
	if not _write_atomic(_active_save_path, snapshot):
		return false
	_state = snapshot
	return true

## 纯读兼容旧档；根据真实订单/准备检查点派生，不会因为界面每帧刷新写盘。
func _quest_journal() -> Dictionary:
	var journal := QuestRegistry.normalize_journal(_state.get(QUEST_JOURNAL_KEY))
	var order := current_order()
	var completed := has_first_order_settlement()
	if order.get("status") == ORDER_STATUS_COMPLETED:
		var old_order := order.duplicate(true)
		old_order.status = ORDER_STATUS_IN_PROGRESS
		completed = completed or is_canonical_first_order(old_order)
	if completed or is_canonical_first_order(order):
		QuestRegistry.ensure_instance(journal, FIRST_ORDER_ID, completed)
	if str(order.get("id", "")) != FIRST_ORDER_ID and not str(order.get("id", "")).is_empty() and order.get("item_id") == FIRST_ORDER_ITEM_ID:
		QuestRegistry.ensure_instance(journal, "customer_order:" + str(order.id), order.status == ORDER_STATUS_COMPLETED)
	if is_ready_to_depart():
		QuestRegistry.ensure_instance(journal, SALT_POOL_QUEST_ID, false)
	return journal

func quest_snapshot() -> Dictionary:
	return QuestRegistry.snapshot(_quest_journal())

func has_unread_quests() -> bool:
	for quest in quest_snapshot().active:
		if quest.unread:
			return true
	return false

## 只供玩家主动打开“当前任务”调用。教学自动展开不能标记已读。
func mark_active_quests_read() -> Dictionary:
	var journal := _quest_journal()
	var changed := false
	for id in journal.instances:
		var instance: Dictionary = journal.instances[id]
		if instance.status == "active" and instance.unread:
			instance.unread = false
			changed = true
	if not changed:
		return {"success": true, "changed": false}
	var previous := _state.duplicate(true)
	_state[QUEST_JOURNAL_KEY] = journal
	if not save():
		_state = previous
		return {"success": false, "changed": false, "reason": "save_failed"}
	return {"success": true, "changed": true}

func _write_atomic(path: String, snapshot: Dictionary) -> bool:
	# 先完整写入同目录临时文件，再替换正式存档；失败时保留上次提交。
	var temporary_path := path + ".tmp"
	var f := FileAccess.open(temporary_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot, "\t"))
		f.flush()
		var write_error := f.get_error()
		f.close()
		if write_error == OK:
			return DirAccess.rename_absolute(temporary_path, path) == OK
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
			if FIRST_ORDER_ITEM_ID not in unlocked_recipe_ids():
				var before_unlock := _state.duplicate(true)
				_unlock_first_recipe()
				if not save():
					_state = before_unlock
					return {"success": false, "created": false, "reason": "save_failed", "order": existing}
			return {"success": true, "created": false, "reason": "already_active", "order": existing}
		return {"success": false, "created": false, "reason": "conflicting_order", "order": existing}

	var next_order := {
		"id": FIRST_ORDER_ID,
		"item_id": FIRST_ORDER_ITEM_ID,
		"item_name": FIRST_ORDER_ITEM_NAME,
		"quantity": FIRST_ORDER_QUANTITY,
		"status": ORDER_STATUS_IN_PROGRESS,
	}
	var previous := _state.duplicate(true)
	_state[CURRENT_ORDER_KEY] = next_order
	_state[FIRST_ORDER_PROGRESS_KEY] = {"ingredients_claimed": false, "next_step": "prepare_ingredients"}
	_unlock_first_recipe()
	if not save():
		_state = previous
		return {"success": false, "created": false, "reason": "save_failed", "order": current_order()}
	return {"success": true, "created": true, "reason": "created", "order": current_order()}

func inventory_snapshot() -> Dictionary:
	return _normalize_inventory(_state.get(INVENTORY_KEY)).duplicate(true)

func inventory_quantity(item_id: String) -> int:
	return int(inventory_snapshot().get(item_id, 0))

## 仓库存量与携带物品分离；旧档按首单领取记录恢复剩余库存，不补发。
func warehouse_snapshot() -> Dictionary:
	var raw = _state.get("warehouse_stock")
	if not raw is Dictionary:
		return {ROCKMAN_MEAT_ID: 0 if first_order_progress().ingredients_claimed else 1,
			ROCK_SALT_ID: 0 if first_order_progress().ingredients_claimed else 1}
	var stock := {}
	for item_id in [ROCKMAN_MEAT_ID, ROCK_SALT_ID]:
		stock[item_id] = clampi(int(raw.get(item_id, 0)), 0, 999) if _valid_count(raw.get(item_id, 0)) else 0
	return stock

func take_warehouse_items(selection: Dictionary) -> Dictionary:
	if selection.is_empty():
		return {"success": false, "reason": "empty_selection"}
	var stock := warehouse_snapshot()
	var carried := inventory_snapshot()
	for item_id in selection:
		var quantity = selection[item_id]
		if not _valid_count(quantity) or quantity <= 0 or not stock.has(item_id) or quantity > stock[item_id] or int(carried.get(item_id, 0)) + quantity > 999:
			return {"success": false, "reason": "invalid_quantity"}
	var previous := _state.duplicate(true)
	for item_id in selection:
		stock[item_id] -= int(selection[item_id])
		carried[item_id] = int(carried.get(item_id, 0)) + int(selection[item_id])
	_state["warehouse_stock"] = stock
	_state[INVENTORY_KEY] = carried
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "claimed", "inventory": carried, "stock": stock}

func unlocked_recipe_ids() -> Array[String]:
	var result: Array[String] = []
	var saved = _state.get(UNLOCKED_RECIPES_KEY, [])
	if saved is Array:
		for recipe_id in saved:
			if recipe_id is String and RecipeCatalog.RECIPES.has(recipe_id) and recipe_id not in result:
				result.append(recipe_id)
	return result

func _unlock_first_recipe() -> void:
	var recipes := unlocked_recipe_ids()
	if FIRST_ORDER_ITEM_ID not in recipes:
		recipes.append(FIRST_ORDER_ITEM_ID)
	_state[UNLOCKED_RECIPES_KEY] = recipes

func _has_first_recipe_history() -> bool:
	var order := current_order()
	if is_canonical_first_order(order):
		return true
	if order.status == ORDER_STATUS_COMPLETED:
		order.status = ORDER_STATUS_IN_PROGRESS
		return is_canonical_first_order(order) and has_first_order_settlement()
	return false

func carried_ingredients() -> Dictionary:
	var result := {}
	var inventory := inventory_snapshot()
	for item_id in RecipeCatalog.INGREDIENTS:
		var quantity = inventory.get(item_id, 0)
		if _valid_count(quantity) and quantity > 0:
			result[item_id] = int(quantity)
	return result

func available_cooking_recipes() -> Array[String]:
	var result: Array[String] = []
	var ingredients := carried_ingredients()
	for recipe_id in unlocked_recipe_ids():
		if RecipeCatalog.can_cook(recipe_id, ingredients):
			result.append(recipe_id)
	return result

func first_order_progress() -> Dictionary:
	return _normalize_progress(_state.get(FIRST_ORDER_PROGRESS_KEY)).duplicate(true)

## 原子领取首单材料。只接受 canonical 首单；重复领取成功但不叠加。
func claim_first_order_ingredients() -> Dictionary:
	var order := current_order()
	if not is_canonical_first_order(order):
		return {"success": false, "created": false, "reason": "no_canonical_order", "inventory": inventory_snapshot()}
	var before_inventory := inventory_snapshot()
	var before_progress := first_order_progress()
	var before_stock_raw = _state.get("warehouse_stock", null)
	if bool(before_progress.get("ingredients_claimed", false)):
		return {"success": true, "created": false, "reason": "already_claimed", "inventory": before_inventory}
	var next_inventory := before_inventory.duplicate(true)
	var before_stock := warehouse_snapshot()
	if int(before_stock.get(ROCKMAN_MEAT_ID, 0)) < 1 or int(before_stock.get(ROCK_SALT_ID, 0)) < 1:
		return {"success": false, "created": false, "reason": "warehouse_empty", "inventory": before_inventory}
	next_inventory[ROCKMAN_MEAT_ID] = int(next_inventory.get(ROCKMAN_MEAT_ID, 0)) + 1
	next_inventory[ROCK_SALT_ID] = int(next_inventory.get(ROCK_SALT_ID, 0)) + 1
	before_stock[ROCKMAN_MEAT_ID] -= 1
	before_stock[ROCK_SALT_ID] -= 1
	_state[INVENTORY_KEY] = next_inventory
	_state["warehouse_stock"] = before_stock
	_state[FIRST_ORDER_PROGRESS_KEY] = {"ingredients_claimed": true, "next_step": "cook"}
	if not save():
		_state[INVENTORY_KEY] = before_inventory
		if before_stock_raw is Dictionary:
			_state["warehouse_stock"] = before_stock_raw.duplicate(true)
		else:
			_state.erase("warehouse_stock")
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
	return start_cooking(FIRST_ORDER_ITEM_ID)

func start_cooking(recipe_id: String) -> Dictionary:
	if not is_canonical_first_order(current_order()) and not _has_followup_order():
		return {"success": false, "reason": "no_canonical_order"}
	var progress := first_order_progress()
	var cooking := cooking_state()
	if cooking.status in ["active", "locked"]:
		return {"success": false, "reason": "already_started", "cooking": cooking}
	# 本轮只实现首单经营节奏，配方数据接口支持后续扩展。
	if recipe_id != FIRST_ORDER_ITEM_ID or RecipeCatalog.get_recipe(recipe_id).is_empty():
		return {"success": false, "reason": "unsupported_recipe"}
	if recipe_id not in unlocked_recipe_ids():
		return {"success": false, "reason": "recipe_locked"}
	if (not _has_followup_order() and str(progress.get("next_step", "")) == "deliver") or inventory_quantity(FIRST_ORDER_ITEM_ID) > 0:
		return {"success": false, "reason": "already_cooked"}
	if not _has_followup_order() and (not bool(progress.get("ingredients_claimed", false)) or str(progress.get("next_step", "")) != "cook"):
		return {"success": false, "reason": "ingredients_not_claimed"}
	var inventory := inventory_snapshot()
	if not RecipeCatalog.can_cook(recipe_id, carried_ingredients()):
		return {"success": false, "reason": "insufficient_ingredients"}
	var previous := _state.duplicate(true)
	var ingredients: Dictionary = RecipeCatalog.get_recipe(recipe_id).ingredients
	var balances := {}
	for item_id in ingredients:
		inventory[item_id] -= int(ingredients[item_id])
		balances[item_id] = inventory[item_id]
	_state[INVENTORY_KEY] = inventory
	cooking.merge({"status": "active", "recipe_id": recipe_id, "quality": 0, "pointer": 0.0,
		"ingredients_consumed": ingredients.duplicate(true), "ingredient_balances": balances}, true)
	_state[COOKING_STATE_KEY] = cooking
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "started", "inventory": inventory_snapshot(), "cooking": cooking_state()}

## 锁定品质并保存成品；同名料理按星级分别计数。
func finish_first_order_cooking(quality: int, pointer := 0.0) -> Dictionary:
	if not is_canonical_first_order(current_order()) and not _has_followup_order():
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
	if not _has_followup_order():
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
		and int(receipt.reputation_awarded) in [QUALITY_REPUTATION[int(quality)], LEGACY_QUALITY_REPUTATION[int(quality)]]

## 顾客系统以唯一订单 ID 登记需求；登记不等于接单或发放奖励。
func waiting_customer_orders() -> Array:
	var result: Array = []
	var pending = _state.get("waiting_customer_orders", [])
	if pending is Array:
		for entry in pending:
			if entry is Dictionary and entry.get("id") is String and not entry.id.strip_edges().is_empty() and entry.id != FIRST_ORDER_ID and entry.get("item_id") == FIRST_ORDER_ITEM_ID and _valid_count(entry.get("quantity")) and entry.quantity == 1:
				result.append({"id": entry.id, "item_id": FIRST_ORDER_ITEM_ID, "item_name": FIRST_ORDER_ITEM_NAME, "quantity": 1})
	return result

func register_customer_order(order_id: String, item_id: String) -> Dictionary:
	if not is_chapter_1_complete():
		return {"success": false, "reason": "chapter_locked"}
	if order_id.strip_edges().is_empty() or order_id == FIRST_ORDER_ID or item_id != FIRST_ORDER_ITEM_ID:
		return {"success": false, "reason": "invalid_order"}
	var pending := waiting_customer_orders()
	var receipts = _state.get("restaurant_order_receipts", {})
	if current_order().get("id") == order_id or (receipts is Dictionary and receipts.has(order_id)):
		return {"success": false, "reason": "already_registered"}
	for entry in pending:
		if entry.id == order_id:
			return {"success": false, "reason": "already_registered"}
	var previous := _state.duplicate(true)
	pending.append({"id": order_id, "item_id": item_id, "item_name": FIRST_ORDER_ITEM_NAME, "quantity": 1})
	_state["waiting_customer_orders"] = pending
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true}

func accept_waiting_customer_order() -> Dictionary:
	if not is_chapter_1_complete():
		return {"success": false, "reason": "chapter_locked"}
	if has_active_order():
		return {"success": false, "reason": "active_order"}
	var pending := waiting_customer_orders()
	if pending.is_empty():
		return {"success": false, "reason": "no_customer"}
	var previous := _state.duplicate(true)
	var order: Dictionary = pending.pop_front()
	order.status = ORDER_STATUS_IN_PROGRESS
	_state[CURRENT_ORDER_KEY] = order
	_state["waiting_customer_orders"] = pending
	_state[COOKING_STATE_KEY] = {"status": "idle", "recipe_id": "", "quality": 0, "pointer": 0.0}
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "order": order}

func has_waiting_diner() -> bool:
	var order := current_order()
	return has_active_order() and order.get("item_id") == FIRST_ORDER_ITEM_ID and order.get("quantity") == 1

func _has_followup_order() -> bool:
	return is_chapter_1_done() and has_waiting_diner() and str(current_order().get("id", "")) != FIRST_ORDER_ID

func deliver_customer_order() -> Dictionary:
	if is_canonical_first_order(current_order()):
		return deliver_first_order()
	if not has_waiting_diner():
		return {"success": false, "reason": "no_customer"}
	var order := current_order()
	var raw_receipts = _state.get("restaurant_order_receipts", {})
	var receipts: Dictionary = raw_receipts.duplicate(true) if raw_receipts is Dictionary else {}
	if receipts.has(str(order.id)):
		return {"success": false, "reason": "already_completed"}
	var quality := cooked_quality()
	if quality == 0:
		return {"success": false, "reason": "missing_dish"}
	var previous := _state.duplicate(true)
	var inventory := inventory_snapshot()
	var prepared := prepared_dishes_snapshot()
	inventory[FIRST_ORDER_ITEM_ID] -= 1
	prepared[FIRST_ORDER_ITEM_ID][str(quality)] -= 1
	var reward := int(QUALITY_REPUTATION[quality])
	order.status = ORDER_STATUS_COMPLETED
	receipts[str(order.id)] = {"quality": quality, "reputation_awarded": reward, "item_id": FIRST_ORDER_ITEM_ID}
	_state[CURRENT_ORDER_KEY] = order
	_state["restaurant_order_receipts"] = receipts
	_state[INVENTORY_KEY] = inventory
	_state[PREPARED_DISHES_KEY] = prepared
	_state[REPUTATION_KEY] = reputation() + reward
	if not save():
		_state = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "quality": quality, "reputation_awarded": reward}

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
