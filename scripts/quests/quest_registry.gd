extends RefCounted
## 类型、触发和完成条件共用一份声明表；声明不能自行授予完成或奖励。
const CATALOG_PATH := "res://data/quests/catalog.json"
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
		if file == null:
			push_error("任务注册表无法读取：" + CATALOG_PATH)
			return {}
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not parsed.get("types") is Dictionary or not parsed.get("quests") is Dictionary:
			push_error("任务注册表结构无效")
			return {}
		_catalog = parsed
	return _catalog.duplicate(true)

static func definition(id: String) -> Dictionary:
	if id.begins_with("customer_order:"):
		id = "restaurant_customer_order"
	return catalog().get("quests", {}).get(id, {}).duplicate(true)

static func empty_journal() -> Dictionary:
	return {"version": 1, "instances": {}}

static func normalize_journal(value) -> Dictionary:
	var journal := empty_journal()
	if not value is Dictionary or not value.get("instances") is Dictionary:
		return journal
	for id in value.instances:
		var instance = value.instances[id]
		if not instance is Dictionary or instance.get("status") not in ["active", "archived"]:
			continue
		journal.instances[id] = {
			"status": instance.status,
			"unread": instance.get("unread", true) != false if instance.status == "active" else false,
		}
	return journal

static func ensure_instance(journal: Dictionary, id: String, completed: bool) -> void:
	if definition(id).is_empty():
		return
	if not journal.instances.has(id):
		journal.instances[id] = {"status": "active", "unread": true}
	# 归档是单向状态；旧业务字段或重复事件不复活任务。
	if completed or journal.instances[id].status == "archived":
		journal.instances[id] = {"status": "archived", "unread": false}

static func snapshot(journal: Dictionary) -> Dictionary:
	var result := {"active": [], "archived": []}
	var config := catalog()
	for id in journal.instances:
		var quest := definition(str(id))
		if quest.is_empty():
			continue # 未识别的实例仍留在存档中，避免旧客户端删除新任务。
		var instance: Dictionary = journal.instances[id]
		quest["id"] = id
		quest["type_name"] = config.types.get(quest.type, {}).get("name", quest.type)
		quest["status"] = instance.status
		quest["unread"] = instance.unread
		result[instance.status].append(quest)
	return result
