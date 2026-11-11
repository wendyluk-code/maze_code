extends RefCounted
## 只修改调用方事务中的内存；新入队与旧档补齐均由外层保存、失败回滚。
const Growth = preload("res://scripts/characters/character_progression.gd")
const MARK := "yufeng_salia_party_joined_v1"

static func apply(sm: Node, run: Dictionary, force := false) -> bool:
	var state: Dictionary = sm.get("_state")
	if state.get(MARK,false) or not run.get("active",false): return false
	if not force and sm.yufeng_salia_state() not in ["joined","fade","done"]: return false
	var food := Growth.satiety_snapshot(sm)
	if not food.valid: return false
	for id in ["yufeng","salia"]:
		if run.members.any(func(m): return m.id == id) or run.members.size() >= 4: continue
		var row := Growth.record(sm,id)
		if not row.valid: continue
		run.members.append({"id":id,"rank":row.rank,"level":row.level,"element":Growth.element(id)})
		run.base_power += int(row.attack)
		run.combat.attack += int(row.attack)
		run.combat.max_hp += int(row.health)
		run.combat.hp += int(row.health)
		run.satiety_max += int(row.satiety_max)
		run.satiety += float(food.values[id])
	Growth.store_satiety(sm,food,true)
	state[sm.TEAM_MEMORY_KEY] = run.members.map(func(m): return m.id)
	# 首次入场位置事务会从待出发快照保存常用队伍，同步新增空位成员。
	if bool(sm.get("_maze_entry_pending")):
		sm.set("_maze_entry_party",state[sm.TEAM_MEMORY_KEY].duplicate())
	state[MARK] = true
	return true
