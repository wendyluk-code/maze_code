extends RefCounted
## 招募先一次保存完整结果，再交给界面播放。随机源可注入，正式概率不变。
const Growth = preload("res://scripts/characters/character_progression.gd")
const KEY := "recruitment_v1"
const OWNED_KEY := "owned_characters_v1"
const MAX_BALANCE := 9007199254740991

static func owned(sm: Node) -> Dictionary:
	var state: Dictionary = sm.get("_state")
	var raw: Variant = state.get(OWNED_KEY, sm.departure_state().get("party", []))
	if not raw is Array: return {"valid": false, "ids": []}
	var ids: Array = []
	for id in raw:
		if not id is String or not Growth.CHARACTERS.has(id) or ids.has(id): return {"valid": false, "ids": []}
		ids.append(id)
	return {"valid": true, "ids": ids}

static func balance(sm: Node) -> int:
	var raw: Variant = sm.get("_state").get(KEY, {})
	if not raw is Dictionary or not Growth._integer(raw.get("stardust", 0), 0, MAX_BALANCE): return -1
	return int(raw.get("stardust", 0))

static func pick(rarity_roll: float, member_roll: float, force_ssr := false) -> String:
	var rarity := "SSR" if force_ssr or rarity_roll < 0.10 else ("SR" if rarity_roll < 0.40 else "R")
	var pool: Array = []
	for id in Growth.CHARACTERS:
		if Growth.CHARACTERS[id].rarity == rarity: pool.append(id)
	return str(pool[mini(pool.size() - 1, int(clampf(member_roll, 0.0, 1.0) * pool.size()))]) if not pool.is_empty() else ""

static func draw(sm: Node, count: int, random_source: Callable = Callable()) -> Dictionary:
	if count not in [1, 10]: return {"success": false, "reason": "invalid_count"}
	if bool(sm.get("_recruit_busy")): return {"success": false, "reason": "busy"}
	if bool(sm.get("_replaying")) or bool(sm.get("_prologue_preview")): return {"success": false, "reason": "preview"}
	if sm.maze_exploration_state().get("region") != "restaurant": return {"success": false, "reason": "not_restaurant"}
	var state: Dictionary = sm.get("_state")
	var collection := owned(sm)
	var dust := balance(sm)
	if not collection.valid or dust < 0 or not Growth._integer(state.get("gold"), 0, MAX_BALANCE): return {"success": false, "reason": "invalid_record"}
	var raw: Variant = state.get(Growth.KEY, {})
	if not raw is Dictionary: return {"success": false, "reason": "invalid_record"}
	for id in raw:
		if not collection.ids.has(id): return {"success": false, "reason": "invalid_record"}
	for id in collection.ids:
		if not Growth.record(sm, id).valid: return {"success": false, "reason": "invalid_record"}
	var cost := 1000 if count == 1 else 9000
	if int(state.gold) < cost: return {"success": false, "reason": "insufficient_gold"}
	sm.set("_recruit_busy", true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var random := random_source if random_source.is_valid() else Callable(rng, "randf")
	var ids: Array = []
	var has_ssr := false
	for i in count:
		var id := pick(float(random.call()), float(random.call()))
		ids.append(id)
		has_ssr = has_ssr or Growth.CHARACTERS[id].rarity == "SSR"
	if count == 10 and not has_ssr: ids[9] = pick(0.0, float(random.call()), true)
	var previous := state.duplicate(true)
	var next := state.duplicate(true)
	var records: Dictionary = raw.duplicate(true)
	var results: Array = []
	for id in ids:
		var fresh: bool = not collection.ids.has(id)
		var record: Dictionary = records.get(id, {"level": 1, "exp": 0, "rank": 1, "breakthroughs": 0}).duplicate(true)
		var converted: bool = not fresh and int(record.rank) == 6
		if fresh: collection.ids.append(id)
		elif converted:
			if dust > MAX_BALANCE - 100:
				sm.set("_recruit_busy", false)
				return {"success": false, "reason": "stardust_limit"}
			dust += 100
		else: record.rank = int(record.rank) + 1
		records[id] = record
		results.append({"id": id, "rank": int(record.rank), "kind": "new" if fresh else ("stardust" if converted else "upgrade"), "stardust": 100 if converted else 0})
	next[OWNED_KEY] = collection.ids
	next[Growth.KEY] = records
	next["gold"] = int(state.gold) - cost
	var recruitment: Dictionary = next.get(KEY, {}).duplicate(true)
	recruitment["stardust"] = dust
	recruitment["last_results"] = results.duplicate(true)
	next[KEY] = recruitment
	sm.set("_state", next)
	var saved: bool = sm.save()
	if not saved: sm.set("_state", previous)
	sm.set("_recruit_busy", false)
	return {"success": true, "results": results} if saved else {"success": false, "reason": "save_failed"}
