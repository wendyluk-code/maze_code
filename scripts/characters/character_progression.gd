extends RefCounted
## 角色详情只读快照与金币突破事务；抽卡阶位和等级突破严格独立。
const KEY := "character_progression_v1"
const COSTS := {5: 100, 10: 250, 15: 500, 20: 900, 25: 1500}
static var CHARACTERS: Dictionary = _character_catalog()

static func _character_catalog() -> Dictionary:
	var result: Dictionary = BASE_CHARACTERS.duplicate(true)
	var additions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/new_five_catalog.json"))
	if additions is Dictionary:
		for id in additions:
			if not result.has(id): result[id] = additions[id]
	return result

const BASE_CHARACTERS := {
	"salia": {
		"name": "萨莉亚",
		"rarity": "SSR",
		"faction": "lightning",
		"attack": 4,
		"attack_growth": 3,
		"health": 10,
		"health_growth": 2,
		"satiety": 2,
		"recovery": 0.015,
		"recovery_growth": 0.0005,
		"active_name": "引雷",
		"active_description": "追踪雷电，命中水中目标后可在水中连锁。",
		"active_rules_text": "射程360像素，追踪目标，目标失效后消散。\n命中水中目标后，在同一水域内额外连锁3个目标；每段距离120像素，造成60%的直接伤害，不跨岸、不重复命中。\n3星后连锁伤害提高至70%，5星后链距提高至150像素，6星后额外连锁4个目标。",
		"interval_start": 1.0,
		"interval_end": 0.8,
		"range": 360,
		"skills": [
			[
				"引雷",
				"对水系目标伤害增加10%。"
			],
			[
				"引雷",
				"对水系目标伤害加成提高至15%。"
			],
			[
				"引雷",
				"连锁伤害提高至70%。"
			],
			[
				"引雷",
				"对水系目标伤害加成提高至20%。"
			],
			[
				"引雷",
				"连锁距离提高至150像素。"
			],
			[
				"引雷",
				"连锁追加目标提高至4个。"
			]
		],
		"portrait": "res://assets/characters/salia/salia_portrait.png",
		"active_rules": {
			"range": 360,
			"tracking": true,
			"lost_target": "dissipate",
			"water_chain_targets": 3,
			"chain_damage_ratio": 0.6,
			"chain_distance": 120,
			"same_water_only": true,
			"repeat_target": false
		},
		"star_effects": [
			{
				"water_damage_bonus": 0.1
			},
			{
				"water_damage_bonus": 0.15
			},
			{
				"chain_damage_ratio": 0.7
			},
			{
				"water_damage_bonus": 0.2
			},
			{
				"chain_distance": 150
			},
			{
				"water_chain_targets": 4
			}
		],
		"detail_portrait": "res://assets/ui/character_details/salia_front.png",
		"skill_icon": "res://assets/ui/combat_skills/salia.png"
	},
	"yufeng": {
		"name": "御风",
		"rarity": "SR",
		"faction": "wind",
		"attack": 3,
		"attack_growth": 2,
		"health": 18,
		"health_growth": 3,
		"satiety": 2,
		"recovery": 0.015,
		"recovery_growth": 0.0005,
		"active_name": "逐风刃",
		"active_description": "风刃命中首个目标后消散，并短暂击退目标。",
		"active_rules_text": "射程320像素，3星后增加40像素；风刃首次命中后消散。\n击退分3段，每段12像素，总计0.3秒，期间白闪并禁止攻击；碰到障碍时停止位移。同一目标2秒内不能重复受到控制。\n6星后可穿透1个目标，第二个目标承受60%伤害及相同击退。",
		"interval_start": 0.8,
		"interval_end": 0.6,
		"range": 320,
		"skills": [
			[
				"逐风刃",
				"对满血目标伤害增加10%。"
			],
			[
				"逐风刃",
				"对满血目标伤害加成提高至15%。"
			],
			[
				"逐风刃",
				"射程增加40像素。"
			],
			[
				"逐风刃",
				"对满血目标伤害加成提高至20%。"
			],
			[
				"逐风刃",
				"风刃伤害额外增加10%。"
			],
			[
				"逐风刃",
				"穿透1目标，第二目标承受60%伤害及同样击退。"
			]
		],
		"portrait": "res://assets/characters/yufeng/yufeng_portrait.png",
		"active_rules": {
			"range": 320,
			"hit_behavior": "dissipate",
			"knockback_segments": 3,
			"knockback_segment_pixels": 12,
			"knockback_seconds": 0.3,
			"hit_flash": true,
			"disable_attack_during_knockback": true,
			"stop_at_obstacle": true,
			"same_target_control_immunity_seconds": 2
		},
		"star_effects": [
			{
				"full_health_damage_bonus": 0.1
			},
			{
				"full_health_damage_bonus": 0.15
			},
			{
				"range_bonus": 40
			},
			{
				"full_health_damage_bonus": 0.2
			},
			{
				"blade_damage_bonus": 0.1
			},
			{
				"pierce_targets": 1,
				"second_target_damage_ratio": 0.6,
				"second_target_knockback": true
			}
		],
		"detail_portrait": "res://assets/ui/character_details/yufeng_front.png",
		"skill_icon": "res://assets/ui/combat_skills/yufeng.png"
	},
	"dingdang": {
		"name": "叮当",
		"rarity": "R",
		"faction": "earth",
		"attack": 2,
		"attack_growth": 1,
		"health": 20,
		"health_growth": 3,
		"satiety": 3,
		"recovery": 0.02,
		"recovery_growth": 0.001,
		"active_name": "锁印",
		"active_description": "钥匙施加锁印，锅铲或其他主动直接命中引爆。",
		"active_rules_text": "土黄色钥匙能量直线飞行240像素，不穿透。\n首个目标获得锁印，基础持续3秒，3星后延长至5秒；同一目标仅保留一个锁印。\n锅铲或其他角色主动技能直接命中时，伤害增加15%，5星后提高至25%，并消耗锁印。\n钥匙本身不引爆，只刷新锁印；雷电传导不触发锁印。\n锁印不会转移到其他目标。",
		"interval_start": 0.7,
		"interval_end": 0.5,
		"range": 240,
		"skills": [
			[
				"万能钥匙",
				"实际出征时，宝箱基础金币额外增加10%，向下取整；不影响赠礼。"
			],
			[
				"万能钥匙",
				"宝箱金币加成提高至15%。"
			],
			[
				"万能钥匙",
				"锁印持续时间延长至5秒。"
			],
			[
				"万能钥匙",
				"宝箱金币加成提高至20%。"
			],
			[
				"万能钥匙",
				"触发锁印的增伤提高至25%。"
			],
			[
				"万能钥匙",
				"宝箱金币加成提高至30%。"
			]
		],
		"portrait": "res://assets/characters/dingdang/dingdang_portrait.png",
		"active_rules": {
			"range": 240,
			"pierce_targets": 0,
			"mark_seconds": 3,
			"mark_damage_bonus": 0.15,
			"mark_max_per_target": 1,
			"mark_transfer": false,
			"key_refreshes_only": true,
			"trigger": "spatula_or_other_character_active_direct_hit",
			"chain_triggers": false,
			"consume_on_trigger": true
		},
		"star_effects": [
			{
				"chest_gold_bonus": 0.1
			},
			{
				"chest_gold_bonus": 0.15
			},
			{
				"mark_seconds": 5
			},
			{
				"chest_gold_bonus": 0.2
			},
			{
				"mark_damage_bonus": 0.25
			},
			{
				"chest_gold_bonus": 0.3
			}
		],
		"detail_portrait": "res://assets/ui/character_details/dingdang_front.png",
		"skill_icon": "res://assets/ui/combat_skills/dingdang.png"
	},

	"yaya": {"active_name": "光点", "active_description": "沿直线发射一枚光点，命中首个敌人后消散。", "interval_start": 0.42, "interval_end": 0.30, "rarity": "R", "name": "芽芽", "faction": "grass", "portrait": "res://assets/characters/yaya_portrait.png", "detail_portrait": "res://assets/ui/character_details/yaya_front.png", "attack": 1, "attack_growth": 1, "health": 12, "health_growth": 2, "satiety": 2, "recovery": 0.020, "recovery_growth": 0.001,
		"skills": [
			["双份惊喜", "成功捕获后，有15%概率复制本次获得的整组材料一份。"],
			["留心收集", "基础复制概率增加5个百分点，达到20%。"],
			["熟悉食材", "捕获被芽芽元素克制的魔物时，复制概率额外增加10个百分点。"],
			["满载而归", "基础复制概率再增加5个百分点，达到25%。"],
			["好事成双", "复制触发时，有20%概率再额外复制一份。"],
			["丰收拿手菜", "本趟前3次成功捕获克制系魔物，必定触发复制，仍可触发额外复制。"]]},
	"tieshan": {"active_name": "旋斧", "active_description": "挥斧横扫周围敌人，每次挥斧对同一目标仅造成一次伤害。", "interval_start": 0.80, "interval_end": 0.60, "rarity": "R", "name": "铁山", "faction": "earth", "portrait": "res://assets/characters/tieshan/tieshan_portrait.png", "detail_portrait": "res://assets/ui/character_details/tieshan_front.png", "attack": 2, "attack_growth": 2, "health": 24, "health_growth": 4, "satiety": 1, "recovery": 0.010, "recovery_growth": 0.0005,
		"skills": [
			["同心列阵", "每名同元素队友，使团队攻击力增加3%，不计铁山自己。"],
			["并肩前行", "每名同元素队友的加成增加1个百分点，达到4%。"],
			["三人成势", "至少有2名同元素队友时，团队攻击力额外增加3%。"],
			["坚如磐石", "每名同元素队友的加成再增加1个百分点，达到5%。"],
			["四人同心", "有3名同元素队友时，团队攻击力额外增加4%。"],
			["众志成山", "每名同元素队友的加成再增加2个百分点，达到7%。"]]}
}

# 主动技能与防御的唯一成长来源，界面和实战共用。
static func defense(id: String, level: int) -> int:
	return clampi(level, 1, 30) * (2 if id == "tieshan" else 1) if CHARACTERS.has(id) else 0

static func active_skill(id: String, level: int) -> Dictionary:
	var progress := float(clampi(level, 1, 30) - 1) / 29.0
	if CHARACTERS.has(id):
		var config: Dictionary = CHARACTERS[id]
		return {"multiplier": lerpf(1.0, 1.5, progress), "interval": lerpf(config.interval_start, config.interval_end, progress)}
	return {"multiplier": 1.0, "interval": 0.65}

static func experience_required(level: int) -> int:
	# 公共经验表；击杀事务调用成长，详情只读取。
	return 0 if level >= 30 else 500 + 100 * (level - 1)

## 仅更新内存，由调用者与击杀生命一起保存；调用者负责失败时整体回滚。
static func grant_experience(sm: Node, ids: Array, amount: int) -> Dictionary:
	if amount < 0: return {"success": false, "reason": "invalid_experience"}
	var raw: Variant = sm.get("_state").get(KEY, {})
	if not raw is Dictionary: return {"success": false, "reason": "invalid_record"}
	var records: Dictionary = raw.duplicate(true)
	var seen := {}
	for id in ids:
		if seen.has(id): continue
		seen[id] = true
		var current := record(sm, id)
		if not current.valid: return {"success": false, "reason": current.reason}
		var level: int = current.level
		var experience: int = current.exp + amount
		var breaks: int = current.breakthroughs
		while level < 30:
			if COSTS.has(level) and breaks < floori(level / 5.0): break
			var required := experience_required(level)
			if experience < required: break
			experience -= required
			level += 1
		if level == 30 or (COSTS.has(level) and breaks < floori(level / 5.0)): experience = 0
		records[id] = {"level": level, "exp": experience, "rank": current.rank, "breakthroughs": breaks}
	sm.get("_state")[KEY] = records
	return {"success": true}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func record(sm: Node, id: String) -> Dictionary:
	if not CHARACTERS.has(id) or not sm.owned_characters().has(id):
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
		"defense": defense(id, level),
		"health": int(config.health) + (level - 1) * int(config.health_growth),
		"satiety_max": int(config.satiety) + floori(level / 5.0),
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

# 饱腹度按角色持久化；读取仅投影时间，不因每帧界面刷新写盘。
const FOOD_KEY := "character_satiety_v1"

static func satiety_snapshot(sm: Node, now: float = -1.0) -> Dictionary:
	if now < 0.0: now = Time.get_unix_time_from_system()
	var state: Dictionary = sm.get("_state")
	var raw: Variant = state.get(FOOD_KEY, {})
	if not raw is Dictionary: return {"valid": false, "reason": "invalid_satiety"}
	var values: Variant = raw.get("values", {})
	var stamp: Variant = raw.get("at", now)
	if not values is Dictionary or not _food_number(stamp) or not raw.get("paused", false) is bool:
		return {"valid": false, "reason": "invalid_satiety"}
	var paused: bool = raw.get("paused", false) or sm.maze_exploration_state().region == "maze_entry"
	var result := {}
	for id in sm.owned_characters():
		var stats := record(sm, id)
		if not stats.get("valid", false): return {"valid": false, "reason": "invalid_character"}
		var amount: Variant = values.get(id, float(stats.satiety_max))
		if not _food_number(amount): return {"valid": false, "reason": "invalid_satiety"}
		var elapsed := 0.0 if paused else maxf(0.0, now - float(stamp))
		result[id] = minf(float(stats.satiety_max), float(amount) + elapsed * float(stats.satiety_max) * float(stats.recovery_percent) / 100.0)
	# 保留暂不出战的已拥有角色余额，不因队伍读取删除记录。
	for id in values:
		if result.has(id): continue
		if not _food_number(values[id]): return {"valid": false, "reason": "invalid_satiety"}
		result[id] = values[id]
	return {"valid": true, "values": result, "at": maxf(now, float(stamp)), "paused": paused}

static func _food_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0

static func store_satiety(sm: Node, food: Dictionary, paused: bool) -> void:
	sm.get("_state")[FOOD_KEY] = {"values": food.values.duplicate(true), "at": food.at, "paused": paused}

static func food_text(amount: float) -> String:
	# 向下保留两位，避免0.999被显示为可用的1点。
	var text := "%.2f" % (floor(amount * 100.0) / 100.0)
	return text.trim_suffix("0").trim_suffix("0").trim_suffix(".")

static func portrait_path(id: String) -> String:
	var path: String = CHARACTERS[id].get("detail_portrait", "res://assets/ui/character_details/" + id + "_portrait_v2.png")
	return path if ResourceLoader.exists(path) else str(CHARACTERS[id].portrait)

static func skill_icon_path(id: String) -> String:
	var path: String = CHARACTERS[id].get("skill_icon", "res://assets/ui/combat_skills/" + id + ".png")
	return path if ResourceLoader.exists(path) else str(CHARACTERS[id].portrait)

static func element(id: String) -> String:
	var faction: String = CHARACTERS.get(id, {}).get("faction", "")
	return "thunder" if faction == "lightning" else faction
