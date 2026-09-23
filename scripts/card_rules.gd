class_name CardRules
extends RefCounted
## CH1-10 最小可验证结算：为首场教学保留清晰接口，不实现敌人 AI 或抽卡经济。

const CHARACTERS := {
	"yaya": {"attack": 2, "max_hp": 5},
	"tieshan": {"attack": 1, "max_hp": 6},
}

static func new_state() -> Dictionary:
	return {
		"turn": 1, "action_points": 2, "deck": ["yaya_01", "yaya_03", "tieshan_02", "tieshan_03"],
		"hand": [], "discard": [], "bottom": [], "draw_count": 0,
		"characters": {"yaya": _character("yaya"), "tieshan": _character("tieshan")},
		"battle_zone": "", "last_enemy_life_damage": false, "料理已使用": false,
		"delayed_heal": {}, "next_damage_reduction": {}, "entered_this_turn": {},
	}

static func _character(id: String) -> Dictionary:
	var base: Dictionary = CHARACTERS[id]
	return {"id": id, "attack": base.attack, "max_hp": base.max_hp, "hp": base.max_hp,
		"armor": 0, "alive": true, "entered": false}

static func heal(state: Dictionary, id: String, amount: int) -> bool:
	if not state.characters.has(id) or not state.characters[id].alive:
		return false
	var c: Dictionary = state.characters[id]
	c.hp = mini(c.max_hp, c.hp + maxi(0, amount))
	return true

static func damage(state: Dictionary, id: String, amount: int) -> int:
	if not state.characters.has(id) or not state.characters[id].alive:
		return 0
	var c: Dictionary = state.characters[id]
	var incoming := maxi(0, amount)
	var reduction := int(state.next_damage_reduction.get(id, 0))
	if reduction > 0:
		incoming = maxi(0, incoming - reduction)
		state.next_damage_reduction.erase(id)
	var absorbed := mini(c.armor, incoming)
	c.armor -= absorbed
	var life_damage := incoming - absorbed
	c.hp -= life_damage
	if c.hp <= 0:
		c.hp = 0
		c.alive = false
	if life_damage > 0 and id == "tieshan":
		state.last_enemy_life_damage = true
	return life_damage

static func enter_battle(state: Dictionary, id: String, armor: int = 0) -> bool:
	if not state.characters.has(id) or not state.characters[id].alive:
		return false
	var previous := str(state.battle_zone)
	if previous != id and not previous.is_empty() and state.characters.has(previous):
		state.characters[previous].entered = false
	state.battle_zone = id
	var c: Dictionary = state.characters[id]
	var first := not bool(state.entered_this_turn.get(id, false))
	c.entered = true
	state.entered_this_turn[id] = true
	if id == "tieshan" and first:
		c.armor += 1 # 站稳：本回合首次入场
	c.armor += maxi(0, armor)
	return true

static func begin_turn(state: Dictionary) -> void:
	state.turn = int(state.turn) + 1
	state.action_points = 2
	state.entered_this_turn = {}
	var c: Dictionary = state.characters.tieshan
	c.armor = 0 # 本版铁山护甲在下个己方回合开始清除
	for id in state.delayed_heal.keys():
		if state.characters.has(id) and state.characters[id].alive:
			heal(state, id, int(state.delayed_heal[id]))
	state.delayed_heal = {}

static func draw(state: Dictionary, count: int) -> Array:
	var drawn: Array = []
	for _i in range(maxi(0, count)):
		if state.deck.is_empty():
			break
		var id: String = str(state.deck.pop_front())
		state.hand.append(id)
		drawn.append(id)
		state.draw_count = int(state.draw_count) + 1
	return drawn

static func draw_two_put_bottom(state: Dictionary, bottom_id: String) -> Dictionary:
	var drawn := draw(state, 2)
	if bottom_id != "" and state.hand.has(bottom_id):
		state.hand.erase(bottom_id)
		state.bottom.append(bottom_id)
		state.deck.append(bottom_id)
	return {"drawn": drawn, "bottom": bottom_id}

static func play_teaching_card(state: Dictionary, card_id: String, target: String = "") -> Dictionary:
	if int(state.action_points) < _cost(card_id):
		return {"success": false, "reason": "insufficient_action_points"}
	state.action_points -= _cost(card_id)
	match card_id:
		"yaya_01":
			if not heal(state, target, 3):
				state.action_points += 1
				return {"success": false, "reason": "invalid_target"}
		"yaya_03":
			return draw_two_put_bottom(state, target)
		"tieshan_02":
			if not enter_battle(state, "tieshan", 2):
				state.action_points += 1
				return {"success": false, "reason": "invalid_entry"}
		"tieshan_03":
			if not enter_battle(state, "tieshan"):
				state.action_points += 1
				return {"success": false, "reason": "invalid_entry"}
			return {"success": true, "attack": 3}
		_:
			state.action_points += _cost(card_id)
			return {"success": false, "reason": "card_not_in_teaching_slice"}
	return {"success": true}

static func _cost(card_id: String) -> int:
	return 2 if card_id in ["yaya_02", "yaya_04", "yaya_08", "tieshan_08"] else 1
