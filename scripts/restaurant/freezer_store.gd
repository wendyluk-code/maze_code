extends RefCounted
## 冷藏批次账本：一条记录代表一份；carried 只追踪曾冷藏的成品。
const KEY := "freezer_v1"
const CAPACITY := 20
const LIFETIME := 7 * 24 * 60 * 60
const NEAR_EXPIRY := 24 * 60 * 60
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")

static func empty() -> Dictionary:
	return {"version": 1, "next_id": 1, "stored": [], "carried": []}

static func integer(value: Variant, minimum := 0) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value < 9007199254740991

static func valid(raw: Variant, prepared: Dictionary) -> bool:
	if not raw is Dictionary or raw.get("version") != 1 or not integer(raw.get("next_id"), 1): return false
	if not raw.get("stored") is Array or not raw.get("carried") is Array or raw.stored.size() > CAPACITY: return false
	var ids := {}
	var carried_counts := {}
	for location in ["stored", "carried"]:
		for unit in raw[location]:
			if not unit is Dictionary or not integer(unit.get("id"), 1) or unit.id >= raw.next_id: return false
			if ids.has(int(unit.id)) or not Catalog.RECIPES.has(unit.get("recipe_id")): return false
			if not integer(unit.get("quality"), 1) or unit.quality > 3 or not integer(unit.get("expires_at"), 1): return false
			ids[int(unit.id)] = true
			if location == "carried":
				var key := "%s/%s" % [unit.recipe_id, int(unit.quality)]
				carried_counts[key] = int(carried_counts.get(key, 0)) + 1
				if carried_counts[key] > int(prepared.get(unit.recipe_id, {}).get(str(int(unit.quality)), 0)): return false
	return true

static func usable_quality(ledger: Dictionary, prepared: Dictionary, recipe_id: String, now: int) -> int:
	for quality in [3, 2, 1]:
		var count := int(prepared.get(recipe_id, {}).get(str(quality), 0))
		for unit in ledger.carried:
			if unit.recipe_id == recipe_id and int(unit.quality) == quality and int(unit.expires_at) <= now: count -= 1
		if count > 0: return quality
	return 0

static func carried_index(ledger: Dictionary, recipe_id: String, quality: int, now: int) -> int:
	var result := -1
	for index in ledger.carried.size():
		var unit: Dictionary = ledger.carried[index]
		if unit.recipe_id != recipe_id or int(unit.quality) != quality or int(unit.expires_at) <= now: continue
		if result < 0 or unit.expires_at < ledger.carried[result].expires_at: result = index
	return result
