extends Node
## 存档管理器（Autoload: SaveManager）
## 全量 JSON 存档，路径 user://save.json；维护教程兼容标记、章节完成状态与首单

const SAVE_PATH := "user://save.json"
const CHAPTER_1_DONE_KEY := "chapter_1_done"
const CURRENT_ORDER_KEY := "current_order"
const ORDER_STATUS_NONE := "none"
const ORDER_STATUS_IN_PROGRESS := "in_progress"
const FIRST_ORDER_ID := "chapter_1_first_order"
const FIRST_ORDER_ITEM_ID := "salt_grilled_rockmane"
const FIRST_ORDER_ITEM_NAME := "盐烤岩鬃肉"
const FIRST_ORDER_QUANTITY := 1
const INVENTORY_KEY := "inventory"
const FIRST_ORDER_PROGRESS_KEY := "first_order_progress"
const ROCKMAN_MEAT_ID := "rockmane_meat"
const ROCK_SALT_ID := "rock_salt"

var data: Dictionary = _defaults()

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"tutorial_done": false,
		CHAPTER_1_DONE_KEY: false,
		CURRENT_ORDER_KEY: _empty_order(),
		INVENTORY_KEY: {ROCKMAN_MEAT_ID: 0, ROCK_SALT_ID: 0},
		FIRST_ORDER_PROGRESS_KEY: {"ingredients_claimed": false, "next_step": "accept_order"},
	}

func _empty_order() -> Dictionary:
	return {
		"id": "",
		"item_id": "",
		"item_name": "",
		"quantity": 0,
		"status": ORDER_STATUS_NONE,
	}

func _normalize_order(value) -> Dictionary:
	if not value is Dictionary:
		return _empty_order()
	# 保留所有进行中订单字段，以便拒绝冲突订单；只有 canonical 首单
	# 才能在 accept_first_order() 中走幂等成功分支。
	if str(value.get("status", ORDER_STATUS_NONE)) != ORDER_STATUS_IN_PROGRESS:
		return _empty_order()
	return value.duplicate(true)

func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
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
	var inventory := {ROCKMAN_MEAT_ID: 0, ROCK_SALT_ID: 0}
	if not value is Dictionary:
		return inventory
	for key in [ROCKMAN_MEAT_ID, ROCK_SALT_ID]:
		var quantity := int(value.get(key, 0))
		inventory[key] = maxi(0, quantity)
	return inventory

func _normalize_progress(value) -> Dictionary:
	var progress := {"ingredients_claimed": false, "next_step": "accept_order"}
	if not value is Dictionary:
		return progress
	progress["ingredients_claimed"] = bool(value.get("ingredients_claimed", false))
	var next_step := str(value.get("next_step", "accept_order"))
	if next_step not in ["accept_order", "prepare_ingredients", "cook"]:
		next_step = "accept_order"
	progress["next_step"] = next_step
	return progress

func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.flush()
		var write_error := f.get_error()
		f.close()
		return write_error == OK
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
