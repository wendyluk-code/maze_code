extends Node
## 存档管理器（Autoload: SaveManager）
## 全量 JSON 存档，路径 user://save.json；维护教程兼容标记、章节完成状态与首单

const SAVE_PATH := "user://save.json"
const CHAPTER_1_DONE_KEY := "chapter_1_done"
const CURRENT_ORDER_KEY := "current_order"
const ORDER_STATUS_NONE := "none"
const ORDER_STATUS_IN_PROGRESS := "in_progress"
const ORDER_STATUS_COMPLETED := "completed"
const FIRST_ORDER_SETTLEMENT_KEY := "first_order_settlement"
const REPUTATION_KEY := "reputation"
const FIRST_ORDER_REPUTATION := 20
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
## 顺序是存档契约；已确认的对白逐句提交，重进从尚未确认的一句继续。
const WRAPUP_STEPS := ["relief", "meat", "yaya_past", "hero_past", "yaya_yes",
	"second_serving", "check_store", "warehouse_move", "warehouse_inspect", "salt_pool",
	"map_review", "introduction", "offer", "no", "memory", "cooking", "ingredients",
	"yaya_join", "stay_shallow", "agreement", "ready_to_depart"]

var data: Dictionary = _defaults()
## 只记录读取时补齐的字段，不在迁移时推断或补发奖励。
var migration_diagnostics: Array[String] = []

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"tutorial_done": false,
		CHAPTER_1_DONE_KEY: false,
		CURRENT_ORDER_KEY: _empty_order(),
		INVENTORY_KEY: {ROCKMAN_MEAT_ID: 0, ROCK_SALT_ID: 0, FIRST_ORDER_ITEM_ID: 0},
		FIRST_ORDER_PROGRESS_KEY: {"ingredients_claimed": false, "next_step": "accept_order"},
		FIRST_ORDER_SETTLEMENT_KEY: {},
		REPUTATION_KEY: 0,
		WRAPUP_KEY: _empty_departure(),
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
		"cards": {"status": "pending_content", "unlocked": false, "card_ids": []}}

func departure_state() -> Dictionary:
	var state := _empty_departure()
	var saved = data.get(WRAPUP_KEY, {})
	if saved is Dictionary:
		for key in state:
			if saved.has(key):
				state[key] = saved[key]
	# JSON 将数字读为浮点；查询契约固定使用整数楼层，跨进程比较保持一致。
	state = state.duplicate(true)
	if state.map is Dictionary and state.map.get("unlocked_floors") is Array:
		var floors: Array = []
		for floor_number in state.map.unlocked_floors:
			floors.append(int(floor_number))
		state.map.unlocked_floors = floors
	return state.duplicate(true)

func is_ready_to_depart() -> bool:
	return departure_state().step == "ready_to_depart"

func can_start_departure() -> bool:
	return has_first_order_settlement() and current_order().get("status") == ORDER_STATUS_COMPLETED \
		and first_order_progress().next_step == "chapter_wrap_up" \
		and inventory_quantity(ROCKMAN_MEAT_ID) == 0 and inventory_quantity(ROCK_SALT_ID) == 0 \
		and inventory_quantity(FIRST_ORDER_ITEM_ID) == 0

## 完成一个阶段7步骤时原子提交下一检查点及对应解锁；失败时完整回滚。
func advance_departure(expected_step: String) -> Dictionary:
	if not can_start_departure():
		return {"success": false, "reason": "not_settled_or_not_empty"}
	var state := departure_state()
	var index := WRAPUP_STEPS.find(expected_step)
	if index < 0 or index >= WRAPUP_STEPS.size() - 1 or state.step != expected_step:
		return {"success": false, "reason": "wrong_step"}
	var previous := data.duplicate(true)
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
	data[WRAPUP_KEY] = state
	if not save():
		data = previous
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
	migration_diagnostics.clear()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for key in [FIRST_ORDER_SETTLEMENT_KEY, REPUTATION_KEY]:
					if not parsed.has(key):
						migration_diagnostics.append("旧存档补齐默认字段：" + key + "；未补发声望。")
				for diagnostic in migration_diagnostics:
					print("SaveManager: ", diagnostic)
				# 旧存档可能只有 tutorial_done；合并默认值而不是丢弃未知字段，
				# 这样旧存档能继续使用，同时缺少第一章标记时会进入第一章。
				data = _defaults()
				for key in parsed:
					data[key] = parsed[key]
				data[CURRENT_ORDER_KEY] = _normalize_order(data.get(CURRENT_ORDER_KEY))
				data[INVENTORY_KEY] = _normalize_inventory(data.get(INVENTORY_KEY))
				data[FIRST_ORDER_PROGRESS_KEY] = _normalize_progress(data.get(FIRST_ORDER_PROGRESS_KEY))
				return
	data = _defaults()

func _normalize_inventory(value) -> Dictionary:
	var inventory := {ROCKMAN_MEAT_ID: 0, ROCK_SALT_ID: 0, FIRST_ORDER_ITEM_ID: 0}
	if not value is Dictionary:
		return inventory
	for key in [ROCKMAN_MEAT_ID, ROCK_SALT_ID, FIRST_ORDER_ITEM_ID]:
		var quantity := int(value.get(key, 0))
		inventory[key] = maxi(0, quantity)
	return inventory

func _normalize_progress(value) -> Dictionary:
	var progress := {"ingredients_claimed": false, "next_step": "accept_order"}
	if not value is Dictionary:
		return progress
	progress["ingredients_claimed"] = bool(value.get("ingredients_claimed", false))
	var next_step := str(value.get("next_step", "accept_order"))
	if next_step not in ["accept_order", "prepare_ingredients", "cook", "deliver", "chapter_wrap_up"]:
		next_step = "accept_order"
	progress["next_step"] = next_step
	return progress

func save() -> bool:
	# 先完整写入同目录临时文件，再替换正式存档；失败时保留上次提交。
	var temporary_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(temporary_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.flush()
		var write_error := f.get_error()
		f.close()
		if write_error == OK:
			return DirAccess.rename_absolute(temporary_path, SAVE_PATH) == OK
	return false

func is_tutorial_done() -> bool:
	return bool(data.get("tutorial_done", false))

func mark_tutorial_done() -> void:
	data["tutorial_done"] = true

func is_chapter_1_done() -> bool:
	return bool(data.get(CHAPTER_1_DONE_KEY, false))

func mark_chapter_1_done() -> void:
	data[CHAPTER_1_DONE_KEY] = true

func current_order() -> Dictionary:
	return _normalize_order(data.get(CURRENT_ORDER_KEY))

func has_active_order() -> bool:
	return str(current_order().get("status", ORDER_STATUS_NONE)) == ORDER_STATUS_IN_PROGRESS

func is_canonical_first_order(order) -> bool:
	if not order is Dictionary or order.size() != 5:
		return false
	return str(order.get("id", "")) == FIRST_ORDER_ID \
		and str(order.get("item_id", "")) == FIRST_ORDER_ITEM_ID \
		and str(order.get("item_name", "")) == FIRST_ORDER_ITEM_NAME \
		and int(order.get("quantity", 0)) == FIRST_ORDER_QUANTITY \
		and str(order.get("status", "")) == ORDER_STATUS_IN_PROGRESS

## 原子接受第一笔订单：相同有效订单重复调用保持幂等，不创建第二单。
## 返回 success=true 表示调用方可以继续教程；created 表示本次是否真的写入新订单。
func accept_first_order() -> Dictionary:
	if has_first_order_settlement() or str(current_order().get("status", "")) == ORDER_STATUS_COMPLETED:
		return {"success": false, "created": false, "reason": "already_completed", "order": current_order()}
	var raw_existing = data.get(CURRENT_ORDER_KEY)
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
	var previous_order = data.get(CURRENT_ORDER_KEY)
	var previous_progress := first_order_progress()
	data[CURRENT_ORDER_KEY] = next_order
	data[FIRST_ORDER_PROGRESS_KEY] = {"ingredients_claimed": false, "next_step": "prepare_ingredients"}
	if not save():
		if previous_order is Dictionary:
			data[CURRENT_ORDER_KEY] = previous_order
		else:
			data[CURRENT_ORDER_KEY] = _empty_order()
		data[FIRST_ORDER_PROGRESS_KEY] = previous_progress
		return {"success": false, "created": false, "reason": "save_failed", "order": current_order()}
	return {"success": true, "created": true, "reason": "created", "order": current_order()}

func inventory_snapshot() -> Dictionary:
	return _normalize_inventory(data.get(INVENTORY_KEY)).duplicate(true)

func inventory_quantity(item_id: String) -> int:
	return int(inventory_snapshot().get(item_id, 0))

func first_order_progress() -> Dictionary:
	return _normalize_progress(data.get(FIRST_ORDER_PROGRESS_KEY)).duplicate(true)

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
	data[INVENTORY_KEY] = next_inventory
	data[FIRST_ORDER_PROGRESS_KEY] = {"ingredients_claimed": true, "next_step": "cook"}
	if not save():
		data[INVENTORY_KEY] = before_inventory
		data[FIRST_ORDER_PROGRESS_KEY] = before_progress
		return {"success": false, "created": false, "reason": "save_failed", "inventory": before_inventory}
	return {"success": true, "created": true, "reason": "claimed", "inventory": inventory_snapshot(), "delta": {ROCKMAN_MEAT_ID: 1, ROCK_SALT_ID: 1}}

## 首单制作是一次提交：扣除两种材料、增加成品、保存交付进度。
## 只有成功写盘才能推进教程；重复制作失败且不改变库存或进度。
func cook_first_order() -> Dictionary:
	if not is_canonical_first_order(current_order()):
		return {"success": false, "reason": "no_canonical_order"}
	var progress := first_order_progress()
	if str(progress.get("next_step", "")) == "deliver":
		return {"success": false, "reason": "already_cooked"}
	if not bool(progress.get("ingredients_claimed", false)) or str(progress.get("next_step", "")) != "cook":
		return {"success": false, "reason": "ingredients_not_claimed"}
	var inventory := inventory_snapshot()
	if int(inventory[ROCKMAN_MEAT_ID]) < 1 or int(inventory[ROCK_SALT_ID]) < 1:
		return {"success": false, "reason": "insufficient_ingredients"}
	var previous := data.duplicate(true)
	inventory[ROCKMAN_MEAT_ID] -= 1
	inventory[ROCK_SALT_ID] -= 1
	inventory[FIRST_ORDER_ITEM_ID] += 1
	progress["next_step"] = "deliver"
	data[INVENTORY_KEY] = inventory
	data[FIRST_ORDER_PROGRESS_KEY] = progress
	if not save():
		data = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "cooked", "inventory": inventory_snapshot()}

func reputation() -> int:
	return int(data.get(REPUTATION_KEY, 0))

func has_first_order_settlement() -> bool:
	var receipt = data.get(FIRST_ORDER_SETTLEMENT_KEY, {})
	return receipt is Dictionary and str(receipt.get("order_id", "")) == FIRST_ORDER_ID \
		and str(receipt.get("item_id", "")) == FIRST_ORDER_ITEM_ID \
		and int(receipt.get("quantity", 0)) == FIRST_ORDER_QUANTITY \
		and int(receipt.get("reputation_awarded", 0)) == FIRST_ORDER_REPUTATION

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
	var previous := data.duplicate(true)
	var order := current_order()
	inventory[FIRST_ORDER_ITEM_ID] -= FIRST_ORDER_QUANTITY
	order["status"] = ORDER_STATUS_COMPLETED
	progress["next_step"] = "chapter_wrap_up"
	data[INVENTORY_KEY] = inventory
	data[CURRENT_ORDER_KEY] = order
	data[FIRST_ORDER_PROGRESS_KEY] = progress
	data[REPUTATION_KEY] = reputation() + FIRST_ORDER_REPUTATION
	data[FIRST_ORDER_SETTLEMENT_KEY] = {
		"order_id": FIRST_ORDER_ID, "item_id": FIRST_ORDER_ITEM_ID,
		"quantity": FIRST_ORDER_QUANTITY, "reputation_awarded": FIRST_ORDER_REPUTATION,
	}
	if not save():
		data = previous
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "reason": "delivered", "order": current_order(), "reputation": reputation()}
