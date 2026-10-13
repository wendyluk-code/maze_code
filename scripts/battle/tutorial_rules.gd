extends RefCounted
## 本关规则事务。输入先在副本结算，成功才整体提交；显示层不持有数值规则。

const DATA_PATH := "res://data/battle/tutorial_cards.json"
const SKILLS := ["yaya_restore", "yaya_magic_hit", "yaya_magic_wind", "yaya_heal_wind", "tieshan_strong", "tieshan_axe", "tieshan_guard", "tieshan_hold"]
const DRAWS := ["", "yaya_magic_hit", "tieshan_hold", "tieshan_strong", "yaya_magic_wind", "yaya_heal_wind", "yaya_restore", "tieshan_axe"]
const STEPS := [
	["tieshan_strong", "tieshan_guard"], ["yaya_magic_hit"],
	["tieshan_hold", "attack"], ["tieshan_strong", "attack"],
	["yaya_magic_wind"], ["yaya_heal_wind", "attack"],
	["yaya_restore"], ["tieshan_axe"]
]
const ENEMY_ACTORS := ["slime_a", "slime_b", "slime_a1", "slime_b", "slime_a2", "slime_b1", "slime_b2"]
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		# JSON 数字载入为浮点；规则状态统一使用整数，避免快照类型漂移。
		for card in _data.cards.values():
			for key in ["attack", "health", "shield", "satiety_max", "satiety_cost", "mana_initial", "mana_cost", "conditional_attack"]:
				if card.has(key): card[key] = int(card[key])
	return _data.cards

static func new_state() -> Dictionary:
	var s := {"turn": 0, "owner": "player", "ap": 2, "enemy_ap": 0,
		"player_hp": 30, "enemy_hp": 10, "hand": [], "deck": [], "discard": [],
		"draw_count": 0, "replacements": 0, "step": 0, "normal_used": false,
		"phase": "draft", "winner": "", "zones": {"player": "", "enemy": ""},
		"characters": {}, "events": []}
	for id in SKILLS:
		s.deck.append(id)
		s.deck.append(id)
	for id in ["tieshan_strong", "tieshan_guard"]:
		s.deck.erase(id)
		s.hand.append(id)
	var free: Array = s.deck.duplicate()
	free.shuffle()
	for id in free:
		if s.hand.size() == 5: break
		if s.deck.count(id) > _reserved(id, 0):
			s.deck.erase(id)
			s.hand.append(id)
	s.deck.shuffle()
	s.characters.yaya = _character("yaya", "yaya", "player")
	s.characters.tieshan = _character("tieshan", "tieshan", "player")
	s.characters.slime_a = _character("slime_a", "slime", "enemy")
	s.characters.slime_b = _character("slime_b", "slime", "enemy")
	return s

static func _reserved(id: String, turn: int) -> int:
	var count := 0
	for i in range(maxi(1, turn), DRAWS.size()):
		if DRAWS[i] == id: count += 1
	return count

static func replace(s: Dictionary, index: int) -> Dictionary:
	if s.phase != "draft" or index < 0 or index >= s.hand.size(): return _fail("请选择起手牌")
	if s.replacements >= 3: return _fail("调整次数已用完")
	var old: String = s.hand[index]
	var options: Array = []
	if old in ["tieshan_strong", "tieshan_guard"] and s.hand.count(old) == 1:
		options.append(old)
	else:
		for id in s.deck:
			if id != old and s.deck.count(id) > _reserved(id, 0): options.append(id)
	if options.is_empty(): return _fail("没有可调整的牌")
	var chosen: String = options.pick_random()
	s.deck.erase(chosen)
	s.deck.append(old)
	s.hand[index] = chosen
	s.replacements += 1
	return {"success": true}

static func _character(id: String, source: String, side: String, parent := "") -> Dictionary:
	var d: Dictionary = data()[source]
	return {"id": id, "source": source, "side": side, "parent": parent,
		"base_attack": d.attack, "max_hp": d.health, "hp": d.health,
		"bonus_attack": 0, "bonus_hp": 0, "shield": 0,
		"satiety": d.satiety_max, "satiety_max": d.satiety_max,
		"mana": d.mana_initial, "alive": true, "revive": 0,
		"form": "", "acted": false, "slime_hits": 0}

static func attack_value(c: Dictionary) -> int:
	return maxi(0, int(c.base_attack) + int(c.bonus_attack) - (2 if c.satiety == 0 else 0))

static func begin_turn(s: Dictionary, side: String) -> void:
	if not s.winner.is_empty(): return
	s.owner = side
	s.zones[side] = ""
	for id in s.characters.keys():
		var c: Dictionary = s.characters[id]
		if c.side != side: continue
		c.shield = 0
		c.acted = false
		if not c.alive and c.revive > 0:
			c.revive -= 1
			if c.revive == 0: _revive(c)
	if side == "player":
		s.turn += 1
		s.ap = 2
		s.step = 0
		s.normal_used = false
		if s.characters.yaya.alive: s.characters.yaya.mana = mini(10, s.characters.yaya.mana + 1)
		var next := ""
		if s.turn <= 8: next = DRAWS[s.turn - 1]
		if next.is_empty():
			for id in s.deck:
				if s.deck.count(id) > _reserved(id, s.turn):
					next = id
					break
		if not next.is_empty() and s.deck.has(next):
			s.deck.erase(next)
			s.hand.append(next)
			s.draw_count += 1
		s.phase = "player_turn"
	else:
		s.enemy_ap = 2
		s.phase = "enemy_turn"

static func _revive(c: Dictionary) -> void:
	var d: Dictionary = data()[c.source]
	c.alive = true
	c.form = ""
	c.base_attack = d.attack
	c.max_hp = d.health + c.bonus_hp
	c.hp = c.max_hp
	c.satiety = c.satiety_max
	c.mana = d.mana_initial
	c.shield = 0

static func expected(s: Dictionary) -> String:
	if s.turn < 1 or s.turn > 8: return ""
	var row: Array = STEPS[s.turn - 1]
	return row[s.step] if s.step < row.size() else "end"

static func validate(s: Dictionary, action: String, target := "", guided := true) -> String:
	if s.phase != "player_turn" or s.owner != "player" or not s.winner.is_empty(): return "等待我方回合"
	if action == "end":
		return "" if not guided or expected(s) == "end" else "请先完成当前教学操作"
	if s.ap < 1: return "行动点不足"
	if action != "attack" and not s.hand.has(action): return "手牌中没有这张牌"
	if action != "attack" and not SKILLS.has(action): return "无法使用这张牌"
	var actor: String = target if action == "attack" else ("yaya" if action.begins_with("yaya_") else "tieshan")
	if not s.characters.has(actor) or not s.characters[actor].alive or s.characters[actor].side != "player": return "行动角色无效"
	var c: Dictionary = s.characters[actor]
	var satiety_cost := 1 if action == "attack" else int(data()[action].satiety_cost)
	var mana_cost := 0 if action == "attack" else int(data()[action].mana_cost)
	if c.satiety >= 0 and c.satiety < satiety_cost: return "饱腹度不足"
	if mana_cost > 0 and c.mana < mana_cost: return "魔力不足"
	if action == "attack" and s.normal_used: return "全队本回合已普通出击"
	if action in ["yaya_magic_hit", "yaya_restore"]:
		if not s.characters.has(target) or not s.characters[target].alive: return "请选择存活的角色"
		var side := "enemy" if action == "yaya_magic_hit" else "player"
		if s.characters[target].side != side: return "目标阵营不符"
	elif action.begins_with("tieshan_") and target != "tieshan": return "请选择铁山"
	elif action in ["yaya_magic_wind", "yaya_heal_wind"]:
		var side := "enemy" if action == "yaya_magic_wind" else "player"
		if not s.characters.has(target) or not s.characters[target].alive or s.characters[target].side != side: return "目标阵营不符"
	if guided:
		if action != expected(s): return "请按当前教学步骤操作"
		if action == "attack" and target != "tieshan": return "请让铁山普通出击"
		if action == "yaya_magic_hit" and target != "slime_a": return "请选史莱姆A"
		if action == "yaya_restore" and target != "tieshan": return "请为铁山恢复生命"
	return ""

static func transact(s: Dictionary, action: String, target := "", guided := true) -> Dictionary:
	var reason := validate(s, action, target, guided)
	if not reason.is_empty(): return _fail(reason)
	var work: Dictionary = s.duplicate(true)
	work.events = []
	_apply(work, action, target)
	if guided: work.step += 1
	s.merge(work, true)
	return {"success": true, "events": s.events.duplicate(true)}

static func _apply(s: Dictionary, action: String, target: String) -> void:
	if action == "end":
		end_turn(s, "player")
		return
	var actor: String = target if action == "attack" else ("yaya" if action.begins_with("yaya_") else "tieshan")
	var c: Dictionary = s.characters[actor]
	s.ap -= 1
	c.acted = true
	if c.satiety >= 0: c.satiety -= 1 if action == "attack" else data()[action].satiety_cost
	if action != "attack":
		c.mana -= data()[action].mana_cost
		s.hand.erase(action)
		s.discard.append(action)
	match action:
		"attack":
			s.normal_used = true
			strike(s, actor)
		"tieshan_strong":
			c.bonus_attack += 1
			strike(s, actor)
		"tieshan_guard":
			var bonus := int(data()[action].conditional_attack) if s.zones.player not in ["", actor] else 0
			c.shield += data()[action].shield
			strike(s, actor, bonus)
		"tieshan_axe":
			c.shield += data()[action].shield
			strike(s, actor, data()[action].attack, true)
		"tieshan_hold":
			c.form = action
			c.base_attack = data()[action].attack
			c.max_hp = data()[action].health + c.bonus_hp
			c.hp = c.max_hp
		"yaya_magic_hit": damage(s, target, 3, "spell", actor)
		"yaya_magic_wind":
			for id in s.characters.keys():
				if s.characters[id].side == "enemy" and s.characters[id].alive: damage(s, id, 1, "spell", actor)
		"yaya_heal_wind":
			for id in s.characters:
				if s.characters[id].side == "player" and s.characters[id].alive: heal(s.characters[id], 3, true)
		"yaya_restore": heal(s.characters[target], 2, false)

static func end_turn(s: Dictionary, side: String) -> void:
	var standing: String = s.zones[side]
	for id in s.characters:
		var c: Dictionary = s.characters[id]
		if c.side != side or not c.alive: continue
		if c.source == "tieshan" and standing == id: c.shield += 2
		if not c.acted and c.satiety_max >= 0: c.satiety = mini(c.satiety_max, c.satiety + 2)
	s.phase = "ending"

static func enemy_turn(s: Dictionary) -> Dictionary:
	if not s.winner.is_empty(): return _fail("战斗已结束")
	begin_turn(s, "enemy")
	s.events = []
	var actor: String = ENEMY_ACTORS[s.turn - 1] if s.turn >= 1 and s.turn <= 7 else ""
	if not actor.is_empty() and s.characters.has(actor) and s.characters[actor].alive:
		s.enemy_ap -= 1
		s.characters[actor].acted = true
		strike(s, actor)
	end_turn(s, "enemy")
	return {"success": true, "actor": actor, "events": s.events.duplicate(true)}

static func strike(s: Dictionary, actor: String, bonus := 0, direct := false) -> void:
	var c: Dictionary = s.characters[actor]
	var opposing := "enemy" if c.side == "player" else "player"
	var target: String = s.zones[opposing]
	s.zones[c.side] = actor
	var amount := attack_value(c) + bonus
	s.events.append({"kind": "strike", "actor": actor, "target": opposing if direct or target.is_empty() else target, "attack": amount})
	if direct or target.is_empty():
		var key := "enemy_hp" if opposing == "enemy" else "player_hp"
		s[key] = maxi(0, s[key] - amount)
		if s[key] == 0:
			s.winner = c.side
			s.phase = "result"
		return
	# 同时互伤：先读取反击攻击力；阵亡与粘液不能取消已发生的反击。
	var counter := attack_value(s.characters[target])
	damage(s, target, amount, "combat", actor, false)
	damage(s, actor, counter, "combat", target, false)
	if amount > 0: _slime_contact(s, target, actor)
	if counter > 0: _slime_contact(s, actor, target)

static func damage(s: Dictionary, id: String, amount: int, kind: String, source := "", contact := true) -> int:
	var c: Dictionary = s.characters[id]
	if not c.alive: return 0
	var protector: String = s.zones[c.side]
	if protector != "" and protector != id and s.characters[protector].alive and s.characters[protector].form == "tieshan_hold": return 0
	var incoming := maxi(0, amount + (2 if c.satiety == 0 else 0))
	var absorbed := mini(c.shield, incoming)
	c.shield -= absorbed
	var lost := incoming - absorbed
	c.hp = maxi(0, c.hp - lost)
	s.events.append({"kind": "damage", "target": id, "amount": lost, "absorbed": absorbed, "type": kind})
	if contact and kind == "combat" and incoming > 0: _slime_contact(s, id, source)
	if c.hp <= 0: _die(s, id)
	return lost

static func _slime_contact(s: Dictionary, id: String, source: String) -> void:
	if s.characters[id].source != "small_slime" or not s.characters.has(source): return
	var attacker: Dictionary = s.characters[source]
	if attacker.satiety >= 0:
		attacker.satiety = maxi(0, attacker.satiety - 1)
		attacker.slime_hits += 1
		s.events.append({"kind": "slime", "target": source})

static func _die(s: Dictionary, id: String) -> void:
	var c: Dictionary = s.characters[id]
	c.alive = false
	c.form = ""
	c.shield = 0
	c.base_attack = data()[c.source].attack
	c.max_hp = data()[c.source].health + c.bonus_hp
	if s.zones[c.side] == id: s.zones[c.side] = ""
	c.revive = 3
	if c.source == "slime":
		c.revive = -1 # 两个分裂体都阵亡前，父体不计时。
		for suffix in ["1", "2"]:
			var child: String = id + suffix
			s.characters[child] = _character(child, "small_slime", c.side, id)
	elif not c.parent.is_empty():
		c.revive = 0 # 分裂体不独立复活。
		var parent: String = c.parent
		if not s.characters[parent + "1"].alive and not s.characters[parent + "2"].alive:
			s.characters[parent].revive = 3
	s.events.append({"kind": "death", "target": id})

static func heal(c: Dictionary, amount: int, overflow: bool) -> void:
	var actual := mini(amount, c.max_hp - c.hp)
	c.hp += actual
	if overflow: c.shield += amount - actual

static func _fail(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
