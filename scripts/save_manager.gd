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

var data: Dictionary = _defaults()

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"tutorial_done": false,
		CHAPTER_1_DONE_KEY: false,
		CURRENT_ORDER_KEY: _empty_order(),
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
	var normalized := _empty_order()
	if value is Dictionary:
		for key in normalized:
			if value.has(key):
				normalized[key] = value[key]
	# 不完整/不支持的旧字段不能伪造一笔进行中的订单。
	if str(normalized.get("status", ORDER_STATUS_NONE)) != ORDER_STATUS_IN_PROGRESS:
		return _empty_order()
	if str(normalized.get("id", "")).is_empty() \
			or str(normalized.get("item_id", "")).is_empty() \
			or str(normalized.get("item_name", "")).is_empty() \
			or int(normalized.get("quantity", 0)) <= 0:
		return _empty_order()
	return normalized

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
				return
	data = _defaults()

func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		return true
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

## 原子接受第一笔订单：相同有效订单重复调用保持幂等，不创建第二单。
## 返回 success=true 表示调用方可以继续教程；created 表示本次是否真的写入新订单。
func accept_first_order() -> Dictionary:
	var existing := current_order()
	if str(existing.get("status", ORDER_STATUS_NONE)) == ORDER_STATUS_IN_PROGRESS:
		return {"success": true, "created": false, "reason": "already_active", "order": existing}

	var next_order := {
		"id": FIRST_ORDER_ID,
		"item_id": FIRST_ORDER_ITEM_ID,
		"item_name": FIRST_ORDER_ITEM_NAME,
		"quantity": FIRST_ORDER_QUANTITY,
		"status": ORDER_STATUS_IN_PROGRESS,
	}
	var previous_order = data.get(CURRENT_ORDER_KEY)
	data[CURRENT_ORDER_KEY] = next_order
	if not save():
		if previous_order is Dictionary:
			data[CURRENT_ORDER_KEY] = previous_order
		else:
			data[CURRENT_ORDER_KEY] = _empty_order()
		return {"success": false, "created": false, "reason": "save_failed", "order": current_order()}
	return {"success": true, "created": true, "reason": "created", "order": current_order()}
