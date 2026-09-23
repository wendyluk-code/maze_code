extends Node
## CH1-10 隔离规则与存档契约验收。

const DATA := preload("res://scripts/ui/components/sprout_card_data.gd")
const RULES := preload("res://scripts/card_rules.gd")
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
	var state := RULES.new_state()
	state.characters.tieshan.hp = 2
	_check(RULES.heal(state, "tieshan", 3) and state.characters.tieshan.hp == 5, "heal_caps_at_max")
	state.characters.tieshan.alive = false
	state.characters.tieshan.hp = 0
	_check(not RULES.heal(state, "tieshan", 3) and state.characters.tieshan.hp == 0, "heal_does_not_revive")
	state.characters.tieshan.alive = true
	state.characters.tieshan.hp = 6
	state.characters.tieshan.armor = 3
	_check(RULES.damage(state, "tieshan", 4) == 1 and state.characters.tieshan.armor == 0 and state.characters.tieshan.hp == 5, "armor_before_life")
	state.next_damage_reduction["tieshan"] = 2
	state.characters.tieshan.armor = 3
	_check(RULES.damage(state, "tieshan", 4) == 0 and state.characters.tieshan.armor == 1, "reduction_before_armor")
	state.characters.tieshan.armor = 0
	state.entered_this_turn = {}
	_check(RULES.enter_battle(state, "tieshan", 2) and state.characters.tieshan.armor == 3, "entry_no_attack_and_stand_firm")
	_check(RULES.enter_battle(state, "tieshan", 2) and state.characters.tieshan.armor == 5, "entry_replacement_no_duplicate_passive")
	RULES.begin_turn(state)
	_check(state.characters.tieshan.armor == 0, "tieshan_armor_clears")
	state.deck = ["a", "b", "c"]
	state.hand = []
	var draw_result := RULES.draw_two_put_bottom(state, "b")
	_check(draw_result.drawn.size() == 2 and state.deck == ["c", "b"], "draw_two_put_bottom")
	state.action_points = 2
	state.characters.tieshan.hp = 6
	_check(RULES.play_teaching_card(state, "tieshan_02").success and state.battle_zone == "tieshan", "teaching_entry")
	_check(RULES.play_teaching_card(state, "tieshan_03").success, "teaching_attack")
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
	var report := {"suite": "CH1-10 card rules", "failures": failures, "checks": checks,
		"card_snapshot": snapshot, "balance_note": "正式设计数值尚未实战平衡"}
	var path := OS.get_environment("CH1_10_REPORT")
	if path.is_empty():
		path = "user://ch1_10_card_contract.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
