extends Node
## CH1-10A 数据与组件契约测试：不启动正式餐厅、不写入 SaveManager。

const DATA := preload("res://scripts/ui/components/sprout_card_data.gd")
const CARD := preload("res://scripts/ui/components/sprout_card.gd")

var checks: Array[Dictionary] = []
var failures := 0

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var cards: Array[SproutCardData] = DATA.placeholder_set()
	_check(cards.size() == 16, "sixteen_placeholder_cards")
	var portraits := {"sprout": "芽芽", "tieshan": "铁山"}
	for index in range(cards.size()):
		var card: SproutCardData = cards[index]
		var local_number := index % 8 + 1
		_check(card.number == local_number, "sequence_%02d" % (index + 1))
		_check(card.title == "占位卡 %02d" % local_number, "neutral_title_%02d" % (index + 1))
		_check(card.character_name == portraits[card.faction], "character_%02d" % (index + 1))
		_check(card.role == ("辅助" if card.faction == "sprout" else "守卫"), "role_%02d" % (index + 1))
		_check(card.portrait != null, "portrait_%02d" % (index + 1))
		_check(card.cost == "待配置" and card.value == "数值待配置" and card.rarity == "稀有度待配置", "values_pending_%02d" % (index + 1))
		_check(card.effect.begins_with("效果待配置"), "effect_pending_%02d" % (index + 1))
	var replacement := DATA.replace_placeholder(cards, {cards[0].id: {"title": "正式数据入口测试"}})
	_check(replacement.size() == cards.size() and replacement[0].title == "正式数据入口测试", "replace_data_without_layout_change")
	_check(CARD.new().has_method("configure"), "card_configure_contract")
	_write_report()
	print("CH1_10A_CARD_STYLE_CONTRACT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 2)

func _check(condition: bool, name: String) -> void:
	checks.append({"name": name, "ok": condition})
	if not condition:
		failures += 1

func _write_report() -> void:
	var report := {"suite": "CH1-10A card style", "failures": failures, "checks": checks}
	var file := FileAccess.open("user://ch1_10a_card_style_contract.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
