extends RefCounted
## 只接受真实地区、战斗和成功返程事务；进度跨趟保留，放弃/战败不归档。
const KEY := "salt_pool_progress_v1"
const QUEST := "chapter_1_salt_pool"

static func snapshot(sm: Node) -> Dictionary:
	var raw: Variant = sm.get("_state").get(KEY,{"arrived":false,"defeated":false,"captured":false})
	if not raw is Dictionary: return {}
	for key in ["arrived","defeated","captured"]:
		if not raw.get(key) is bool: return {}
	return raw.duplicate(true)

static func mark(sm: Node, event: String) -> void:
	if not sm.is_ready_to_depart(): return
	var progress := snapshot(sm)
	if progress.is_empty() or event not in progress: return
	progress[event] = true
	if event == "captured": progress.defeated = true
	sm.get("_state")[KEY] = progress

static func finish(sm: Node, bank: bool) -> void:
	var progress := snapshot(sm)
	if not bank or progress.is_empty() or not progress.arrived or not progress.defeated or not progress.captured: return
	var journal: Dictionary = sm._quest_journal()
	preload("res://scripts/quests/quest_registry.gd").ensure_instance(journal,QUEST,true)
	sm.get("_state")[sm.QUEST_JOURNAL_KEY] = journal
