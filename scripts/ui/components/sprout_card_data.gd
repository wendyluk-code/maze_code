class_name SproutCardData
extends RefCounted
## CH1-10 正式卡牌数据。卡框只消费本契约，卡面素材仍使用角色现有肖像。

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
	id = str(values.get("id", "card_placeholder"))
	faction = str(values.get("faction", "sprout"))
	character_name = str(values.get("character_name", "芽芽"))
	portrait = values.get("portrait", null) as Texture2D
	role = str(values.get("role", "辅助"))
	title = str(values.get("title", ""))
	cost = str(values.get("cost", ""))
	card_type = str(values.get("card_type", ""))
	effect = str(values.get("effect", ""))
	value = str(values.get("value", ""))
	rarity = str(values.get("rarity", "R"))
	number = int(values.get("number", 1))

static func formal_set() -> Array[SproutCardData]:
	var sprout_portrait := preload("res://assets/characters/yaya_portrait.png")
	var tieshan_portrait := preload("res://assets/characters/tieshan/tieshan_portrait.png")
	var result: Array[SproutCardData] = []
	var sprout := [
		["先吃一口", "法术", 1, "一个友方恢复3点生命。", "治疗+3", "R"],
		["大家都有", "法术", 2, "全体友方恢复2点生命。", "全体治疗+2", "R"],
		["芽芽找找", "法术", 1, "抽2张牌，再选1张手牌放牌库底。", "抽2·回底1", "R"],
		["这张有用！", "法术", 2, "抽2张牌。", "抽2", "R"],
		["别睡过去！", "法术", 1, "对未气绝友方恢复2点生命；治疗前生命≤2再抽1张。", "治疗+2·低血抽1", "R"],
		["慢慢养好", "法术", 1, "未气绝友方恢复1点；下个己方回合开始再恢复2点，后续治疗不可叠加。", "1+延迟2", "R"],
		["趁热吃呀", "法术", 1, "友方恢复2点；本回合已使用料理再抽1张。", "治疗+2·料理抽1", "R"],
		["都回来吃饭！", "法术", 2, "全体友方恢复3点生命，再抽1张牌。", "全体治疗+3·抽1", "SR"],
	]
	var tieshan := [
		["横盾", "法术", 1, "铁山获得3点护甲。", "护甲+3", "R"],
		["站我身后", "法术", 1, "铁山进入战斗区并获得2点护甲，不攻击。", "入场·护甲+2", "R"],
		["盾沿猛击", "战斗", 1, "本次攻击+2，然后出击。", "本次攻击+2", "R"],
		["稳步推进", "战斗", 1, "先获得2点护甲，然后出击。", "护甲+2·出击", "R"],
		["还你一下", "战斗", 1, "本次攻击+1；若上个敌方回合曾受到生命伤害则改为+3，然后出击。", "受伤时本次攻击+3", "R"],
		["老兵直觉", "法术", 1, "抽1张牌，铁山获得1点护甲。", "抽1·护甲+1", "R"],
		["守住这里", "法术", 1, "下个己方回合开始前铁山下一次伤害-2，最低为0，不叠加。", "减伤-2", "R"],
		["大伙在我身后", "法术", 2, "铁山进入战斗区并获得5点护甲；牌手下一次伤害-3，不攻击。", "入场·护甲+5·牌手减伤", "SR"],
	]
	for i in range(8):
		var row: Array = sprout[i]
		result.append(SproutCardData.new({"id": "yaya_%02d" % (i + 1), "faction": "sprout", "character_name": "芽芽", "portrait": sprout_portrait, "role": "辅助", "title": row[0], "card_type": row[1], "cost": str(row[2]), "effect": row[3], "value": row[4], "rarity": row[5], "number": i + 1}))
	for i in range(8):
		var row: Array = tieshan[i]
		result.append(SproutCardData.new({"id": "tieshan_%02d" % (i + 1), "faction": "tieshan", "character_name": "铁山", "portrait": tieshan_portrait, "role": "守卫", "title": row[0], "card_type": row[1], "cost": str(row[2]), "effect": row[3], "value": row[4], "rarity": row[5], "number": i + 1}))
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
			"portrait": item.portrait, "role": item.role, "title": item.title,
			"cost": item.cost, "card_type": item.card_type, "effect": item.effect,
			"value": item.value, "rarity": item.rarity, "number": item.number,
		}
		var replacement: Dictionary = replacements.get(item.id, {})
		for key in replacement:
			values[key] = replacement[key]
		result.append(SproutCardData.new(values))
	return result
