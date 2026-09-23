class_name SproutCardData
extends RefCounted
## 卡牌视觉组件的数据契约。当前只提供明确的“待配置”占位数据。

var id: String
var faction: String
var character_name: String
var portrait: Texture2D
var role: String
var title: String
var cost: String
var card_type: String
var effect: String
var value: String
var rarity: String
var number: int

func _init(values: Dictionary = {}) -> void:
	id = str(values.get("id", "placeholder"))
	faction = str(values.get("faction", "sprout"))
	character_name = str(values.get("character_name", "芽芽"))
	portrait = values.get("portrait", null) as Texture2D
	role = str(values.get("role", "辅助"))
	title = str(values.get("title", "占位卡"))
	cost = str(values.get("cost", "待配置"))
	card_type = str(values.get("card_type", "类型待配置"))
	effect = str(values.get("effect", "效果待配置"))
	value = str(values.get("value", "数值待配置"))
	rarity = str(values.get("rarity", "稀有度待配置"))
	number = int(values.get("number", 1))

static func placeholder_set() -> Array[SproutCardData]:
	var sprout_portrait := preload("res://assets/characters/yaya_portrait.png")
	var tieshan_portrait := preload("res://assets/characters/tieshan/tieshan_portrait.png")
	var result: Array[SproutCardData] = []
	for index in range(1, 9):
		result.append(SproutCardData.new({
			"id": "sprout_placeholder_%02d" % index,
			"faction": "sprout",
			"character_name": "芽芽",
			"portrait": sprout_portrait,
			"role": "辅助",
			"title": "占位卡 %02d" % index,
			"cost": "待配置",
			"card_type": "类型待配置",
			"effect": "效果待配置" if index != 8 else "效果待配置\n效果待配置\n效果待配置\n效果待配置",
			"value": "数值待配置",
			"rarity": "稀有度待配置",
			"number": index,
		}))
	for index in range(1, 9):
		result.append(SproutCardData.new({
			"id": "tieshan_placeholder_%02d" % index,
			"faction": "tieshan",
			"character_name": "铁山",
			"portrait": tieshan_portrait,
			"role": "守卫",
			"title": "占位卡 %02d" % index,
			"cost": "待配置",
			"card_type": "类型待配置",
			"effect": "效果待配置" if index != 8 else "效果待配置\n效果待配置\n效果待配置\n效果待配置",
			"value": "数值待配置",
			"rarity": "稀有度待配置",
			"number": index,
		}))
	return result

static func replace_placeholder(data: Array[SproutCardData], replacements: Dictionary) -> Array[SproutCardData]:
	## 后续章节可按 id 替换字段，布局组件无需改动；不写入存档或业务状态。
	var result: Array[SproutCardData] = []
	for item in data:
		var values := {
			"id": item.id, "faction": item.faction, "character_name": item.character_name,
			"portrait": item.portrait, "role": item.role, "title": item.title,
			"cost": item.cost, "card_type": item.card_type, "effect": item.effect,
			"value": item.value, "rarity": item.rarity, "number": item.number,
		}
		var replacement: Dictionary = replacements.get(item.id, {})
		for key in replacement:
			values[key] = replacement[key]
		result.append(SproutCardData.new(values))
	return result
