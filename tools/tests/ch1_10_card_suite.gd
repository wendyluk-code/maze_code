extends Node
## CH1-10 保留卡牌展示数据与存档契约验收；旧战斗规则已移除。

const DATA := preload("res://scripts/ui/components/sprout_card_data.gd")
var checks: Array[Dictionary] = []
var failures := 0

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var cards: Array = DATA.formal_set()
	_check(cards.size() == 16, "formal_card_count")
	_check(cards.slice(0, 8).filter(func(c): return c.rarity == "R").size() == 7, "yaya_seven_r")
	_check(cards.slice(8, 16).filter(func(c): return c.rarity == "R").size() == 7, "tieshan_seven_r")
	_check(cards[0].title == "先吃一口" and cards[2].title == "芽芽找找" and cards[9].title == "站我身后" and cards[10].title == "盾沿猛击", "teaching_names")
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null:
		var seeded: Dictionary = sm._defaults()
		seeded.chapter_1_departure.step = "ready_to_depart"
		seeded.chapter_1_departure.empty_warehouse_checked = true
		seeded.chapter_1_departure.tieshan_name_revealed = true
		seeded.chapter_1_departure.map = {"unlocked_floors": [1], "visible_regions": ["old_salt_pool"], "other_regions": "fog"}
		seeded.chapter_1_departure.party = ["yaya", "tieshan"]
		seeded.chapter_1_departure.objective = "与芽芽、铁山一同进入迷宫浅层"
		seeded.chapter_1_departure.entrance_lit = true
		seeded.first_order_progress = {"ingredients_claimed": true, "next_step": "chapter_wrap_up"}
		seeded.current_order = {"id": "chapter_1_first_order", "item_id": "salt_grilled_rockmane", "item_name": "盐烤岩鬃肉", "quantity": 1, "status": "completed"}
		seeded.first_order_settlement = {"order_id": "chapter_1_first_order", "item_id": "salt_grilled_rockmane", "quantity": 1, "reputation_awarded": 20}
		seeded.reputation = 20
		seeded.inventory = {"rockmane_meat": 0, "rock_salt": 0, "salt_grilled_rockmane": 0}
		sm.data = seeded
		var unlocked: Dictionary = sm.unlock_ch1_cards()
		_check(unlocked.success and sm.cards_unlocked() and sm.cards_state().card_ids.size() == 16, "save_unlock_schema")
		_check(sm.unlock_ch1_cards().success and sm.cards_state().card_ids.size() == 16, "save_unlock_idempotent")
	_write_report()
	print("CH1_10_CARD_CONTRACT %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 2)

func _check(condition: bool, name: String) -> void:
	checks.append({"name": name, "ok": condition})
	if not condition:
		failures += 1

func _write_report() -> void:
	var snapshot: Array = []
	for card in DATA.formal_set():
		snapshot.append({"id": card.id, "character": card.character_name, "title": card.title,
			"type": card.card_type, "cost": card.cost, "rarity": card.rarity, "effect": card.effect})
	var report := {"suite": "CH1-10 卡牌显示与存档", "failures": failures, "checks": checks,
		"card_snapshot": snapshot, "balance_note": "正式设计数值尚未实战平衡"}
	var path := OS.get_environment("CH1_10_REPORT")
	if path.is_empty():
		path = "user://ch1_10_card_contract.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
