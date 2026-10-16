extends RefCounted
## 角色详情只读快照与金币突破事务；抽卡阶位和等级突破严格独立。
const KEY := "character_progression_v1"
const COSTS := {5: 100, 10: 250, 15: 500, 20: 900, 25: 1500}
const CHARACTERS := {
	"yaya": {"name": "芽芽", "portrait": "res://assets/characters/yaya_portrait.png", "attack": 12, "attack_growth": 1, "satiety": 30, "satiety_growth": 1, "recovery": 0.020, "recovery_growth": 0.001,
		"skills": [
			["双份惊喜", "成功捕获后，有15%概率复制本次获得的整组材料一份。"],
			["留心收集", "基础复制概率增加5个百分点，达到20%。"],
			["熟悉食材", "捕获被芽芽元素克制的魔物时，复制概率额外增加10个百分点。"],
			["满载而归", "基础复制概率再增加5个百分点，达到25%。"],
			["好事成双", "复制触发时，有20%概率再额外复制一份。"],
			["丰收拿手菜", "本趟前3次成功捕获克制系魔物，必定触发复制，仍可触发额外复制。"]]},
	"tieshan": {"name": "铁山", "portrait": "res://assets/characters/tieshan/tieshan_portrait.png", "attack": 20, "attack_growth": 2, "satiety": 40, "satiety_growth": 2, "recovery": 0.010, "recovery_growth": 0.0005,
		"skills": [
			["同心列阵", "每名同元素队友，使团队基础战力增加3%，不计铁山自己。"],
			["并肩前行", "每名同元素队友的加成增加1个百分点，达到4%。"],
			["三人成势", "至少有2名同元素队友时，团队基础战力额外增加3%。"],
			["坚如磐石", "每名同元素队友的加成再增加1个百分点，达到5%。"],
			["四人同心", "有3名同元素队友时，团队基础战力额外增加4%。"],
			["众志成山", "每名同元素队友的加成再增加2个百分点，达到7%。"]]}
}

static func experience_required(level: int) -> int:
	# 候选公共经验表；地图怪物组合平衡另行接入，不在详情页发放经验。
	return 0 if level >= 30 else 500 + 100 * (level - 1)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func record(sm: Node, id: String) -> Dictionary:
	if not CHARACTERS.has(id) or not sm.departure_state().get("party", []).has(id):
		return {"valid": false, "reason": "not_owned"}
	var state: Dictionary = sm.get("_state")
	var records: Variant = state.get(KEY, {})
	if not records is Dictionary:
		return {"valid": false, "reason": "invalid_record"}
	var raw: Variant = records.get(id, {"level": 1, "exp": 0, "rank": 1, "breakthroughs": 0})
	if not raw is Dictionary:
		return {"valid": false, "reason": "invalid_record"}
	if not _integer(raw.get("level"), 1, 30) or not _integer(raw.get("rank"), 1, 6) or not _integer(raw.get("exp"), 0, 3300) or not _integer(raw.get("breakthroughs"), 0, 5):
		return {"valid": false, "reason": "invalid_record"}
	var level := int(raw.level)
	var breaks := int(raw.breakthroughs)
	var experience := int(raw.exp)
	if breaks < mini(5, floori((level - 1) / 5.0)) or breaks > mini(5, floori(level / 5.0)):
		return {"valid": false, "reason": "invalid_record"}
	var needs_break := COSTS.has(level) and breaks < floori(level / 5.0)
	if (level == 30 or needs_break) and experience != 0:
		return {"valid": false, "reason": "invalid_record"}
	if level < 30 and experience >= experience_required(level):
		return {"valid": false, "reason": "invalid_record"}
	var config: Dictionary = CHARACTERS[id]
	return {"valid": true, "level": level, "exp": experience, "rank": int(raw.rank), "breakthroughs": breaks,
		"required_exp": experience_required(level), "needs_breakthrough": needs_break, "breakthrough_cost": int(COSTS.get(level, 0)),
		"attack": int(config.attack) + (level - 1) * int(config.attack_growth),
		"satiety_max": int(config.satiety) + (level - 1) * int(config.satiety_growth),
		"recovery_percent": float(config.recovery) + (level - 1) * float(config.recovery_growth)}

static func breakthrough(sm: Node, id: String) -> Dictionary:
	if bool(sm.get("_replaying")) or bool(sm.get("_prologue_preview")):
		return {"success": false, "reason": "preview"}
	var state: Dictionary = sm.get("_state")
	var location: Variant = state.get("maze_exploration", {})
	if not location is Dictionary or location.get("region", "") != "restaurant":
		return {"success": false, "reason": "not_restaurant"}
	var current := record(sm, id)
	if not current.valid:
		return {"success": false, "reason": current.reason}
	if not current.needs_breakthrough:
		return {"success": false, "reason": "not_eligible"}
	if not _integer(state.get("gold"), 0, 9007199254740991):
		return {"success": false, "reason": "invalid_gold"}
	var cost: int = current.breakthrough_cost
	if sm.gold_balance() < cost:
		return {"success": false, "reason": "insufficient_gold"}
	var previous := state.duplicate(true)
	var next := state.duplicate(true)
	var records: Dictionary = next.get(KEY, {}).duplicate(true)
	var updated: Dictionary = records[id].duplicate(true)
	updated.breakthroughs = current.breakthroughs + 1
	records[id] = updated
	next[KEY] = records
	next["gold"] = sm.gold_balance() - cost
	sm.set("_state", next)
	if not sm.save():
		sm.set("_state", previous)
		return {"success": false, "reason": "save_failed"}
	return {"success": true, "record": record(sm, id)}
