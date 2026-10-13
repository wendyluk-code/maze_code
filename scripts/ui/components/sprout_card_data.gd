class_name SproutCardData
extends RefCounted
## 卡牌数据契约：字段来自 data/cards/catalog.json，卡面组件只负责排版。

const CATALOG_PATH := "res://data/cards/catalog.json"
static var _catalog_cache: Array[SproutCardData] = []

var id: String
var faction: String
var character_name: String
var portrait: Texture2D
var illustration_override: Texture2D
var illustration_path: String
var portrait_path: String
var material_path: String
var role: String
var title: String
var cost: String
var card_type: String
var effect: String
var value: String
var rarity: String
var number: int
var level: int
var level_position: String
var battle_level_default: int
var attack: int
var health: int
var is_role_card: bool
var satiety_max: int
var mana_enabled: bool
var mana_initial: int
var satiety_cost: int
var mana_cost: int
var portable_dish: String
var dish_category: String
## Excel原始显示值；费用仍保留正数供业务扣减，显示值绝不参与结算。
var display_values: Dictionary = {}

func _init(values: Dictionary = {}) -> void:
	id = str(values.get("id", "card_placeholder"))
	faction = str(values.get("faction", "sprout"))
	character_name = str(values.get("character_name", "芽芽"))
	portrait_path = str(values.get("portrait_path", ""))
	material_path = str(values.get("material_path", ""))
	portrait = values.get("portrait", null) as Texture2D
	illustration_override = values.get("illustration_override", null) as Texture2D
	illustration_path = str(values.get("illustration_path", ""))
	role = str(values.get("role", "辅助"))
	title = str(values.get("title", ""))
	cost = str(values.get("cost", ""))
	card_type = str(values.get("card_type", ""))
	if card_type == "形态牌":
		card_type = "赋形牌"
	effect = str(values.get("effect", ""))
	value = str(values.get("value", ""))
	rarity = str(values.get("rarity", "R"))
	number = int(values.get("number", 1))
	# 仅为旧读取方保留无效占位；新模板不显示、编辑或导出等级。
	level = 0
	level_position = ""
	battle_level_default = 0
	attack = int(values.get("attack", 0))
	health = int(values.get("health", 0))
	is_role_card = bool(values.get("is_role_card", card_type == "角色牌"))
	satiety_max = int(values.get("satiety_max", -1))
	mana_enabled = bool(values.get("mana_enabled", false))
	mana_initial = int(values.get("mana_initial", -1))
	satiety_cost = int(values.get("satiety_cost", -1))
	mana_cost = int(values.get("mana_cost", 0))
	portable_dish = str(values.get("portable_dish", "待定"))
	dish_category = str(values.get("dish_category", ""))
	display_values = values.get("display_values", {}).duplicate(true)

static func _read_catalog() -> Array[SproutCardData]:
	var result: Array[SproutCardData] = []
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("CARD_CATALOG_OPEN_FAILED path=%s" % CATALOG_PATH)
		return result
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.has("cards") or not parsed.cards is Array:
		push_error("CARD_CATALOG_SCHEMA_INVALID path=%s" % CATALOG_PATH)
		return result
	for raw in parsed.cards:
		if not raw is Dictionary:
			continue
		var values: Dictionary = raw.duplicate(true)
		var path := str(values.get("portrait_path", ""))
		if not path.is_empty():
			values["portrait"] = load(path) as Texture2D
		result.append(SproutCardData.new(values))
	return result

static func catalog_set() -> Array[SproutCardData]:
	if _catalog_cache.is_empty():
		_catalog_cache = _read_catalog()
	return _catalog_cache.duplicate()

static func formal_set() -> Array[SproutCardData]:
	## 正式可携带的16张技能牌；角色牌单独由 role_set() 提供。
	var result: Array[SproutCardData] = []
	for card in catalog_set():
		if not card.is_role_card:
			result.append(card)
	return result

static func role_set() -> Array[SproutCardData]:
	var result: Array[SproutCardData] = []
	for card in catalog_set():
		if card.is_role_card:
			result.append(card)
	return result

static func preview_set() -> Array[SproutCardData]:
	## 预览顺序：每个角色先显示角色牌，再显示该角色的8张技能牌。
	var result: Array[SproutCardData] = []
	for faction in ["sprout", "tieshan"]:
		for card in catalog_set():
			if card.faction == faction:
				result.append(card)
	return result

static func placeholder_set() -> Array[SproutCardData]:
	## 兼容旧调用方；CH1-10 起统一返回正式设计数据。
	return formal_set()

static func replace_placeholder(data: Array[SproutCardData], replacements: Dictionary) -> Array[SproutCardData]:
	## 后续章节可按 id 替换字段，布局组件无需改动；不写入存档或业务状态。
	var result: Array[SproutCardData] = []
	for item in data:
		var values := {
			"id": item.id, "faction": item.faction, "character_name": item.character_name,
			"portrait": item.portrait, "portrait_path": item.portrait_path, "role": item.role,
			"illustration_path": item.illustration_path, "illustration_override": item.illustration_override,
			"material_path": item.material_path,
			"title": item.title, "cost": item.cost, "card_type": item.card_type,
			"effect": item.effect, "value": item.value, "rarity": item.rarity,
			"number": item.number, "attack": item.attack,
			"health": item.health, "is_role_card": item.is_role_card,
			"satiety_max": item.satiety_max, "mana_enabled": item.mana_enabled,
			"mana_initial": item.mana_initial, "satiety_cost": item.satiety_cost,
			"mana_cost": item.mana_cost, "portable_dish": item.portable_dish,
			"dish_category": item.dish_category,
			"display_values": item.display_values.duplicate(true),
		}
		var replacement: Dictionary = replacements.get(item.id, {})
		for key in replacement:
			values[key] = replacement[key]
		result.append(SproutCardData.new(values))
	return result
