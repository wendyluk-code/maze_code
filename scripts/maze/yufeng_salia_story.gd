extends RefCounted
## 分水庭委托状态；击败记录、调查、奖励与入队分别保存，读档不重发奖励。
const KEY := "yufeng_salia_encounter"
const QUEST := "yufeng_pool_clue"
const Site = preload("res://data/maze/yf_encounter_site.gd")
const Frog = preload("res://data/maze/fenshui_boss.gd")
const Registry = preload("res://scripts/quests/quest_registry.gd")
const Recruitment = preload("res://scripts/characters/recruitment.gd")
const LIMITS := {"unseen":0,"intro":4,"investigate":0,"clue":1,"report":0,"post":2,"gift_pending":0,"gift_reward":0,"farewell":2,"joined":0,"fade":0,"done":0}
const INTRO := [
	["御风","请止步。前方水池有异常。姓名，以及来这里的目的。"],
	["主角","我们来抓魔物，餐厅的肉用完了。"],
	["萨莉亚","哎呀，你把迷宫当食材仓库？挺有想法哟。"],
	["主角","……算是吧。"],
	["御风","既然这样，清理池中巨蛙之后，替我看看下面藏着什么。"]]
const CLUE := [
	["","巨蛙盘踞的地方露出一道石缝，泛着微光的水正从深处缓缓渗出。"],
	["","石缝旁，枯黄的苔藓竟抽出了嫩芽，细根密密地伸向缝中。"]]
const POST := [["御风","看来，这里的水确实与深层相通……"],["萨莉亚","真是不错的发现，值得继续调查呢。"],["御风","你帮了忙，这是报酬。"]]
const FAREWELL := [["萨莉亚","呀，是寻常地方买不到的稀有食材呢。做成料理的话，应该能替你的餐厅招来不少客人。"],["御风","咳，走了。往后需要协助，可以找我们。"],["萨莉亚","回见哟，小可爱。"]]

static func fresh(phase := "unseen") -> Dictionary:
	return {"version":3,"phase":phase,"line":0,"frog_defeated":false}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 3 or not LIMITS.has(value.get("phase")): return false
	if not value.get("frog_defeated", false) is bool or not value.get("legacy_reward", false) is bool: return false
	var line: Variant = value.get("line")
	return typeof(line) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(line)) and line >= 0 and floor(line) == line and line <= LIMITS[value.phase]

static func migrate(old: Dictionary) -> Dictionary:
	if old.get("version") == 3: return old.duplicate(true)
	var phase: String = old.phase
	if phase in ["intro","eat","question","battle"]: return fresh("intro")
	var result := fresh(phase)
	if phase in ["post","gift_pending","gift_reward","bento_unlock","bento_fly","farewell","fade","done"]:
		result.legacy_reward = true
		if phase in ["bento_unlock","bento_fly"]: result.phase = "farewell"
	return result

static func frog_unlocked(sm: Node) -> bool:
	return sm.yufeng_salia_state() not in ["unseen","intro"]

static func can_inspect(sm: Node, point: Vector2) -> bool:
	var record: Dictionary = sm.yufeng_salia_record()
	if record.phase != "investigate" or not record.get("frog_defeated",false): return false
	if sm.maze_exploration_state().region != "fenshui" or point.distance_to(Frog.HOME) > 65 or not Frog.Roads.is_walkable(point): return false
	var run: Dictionary = load("res://scripts/maze/capture_run.gd").snapshot(sm)
	return run.get("active",false) and run.get("pending","") == "" and run.combat.hp > 0 and run.combat.actors.has(Frog.ID) and run.combat.actors[Frog.ID].hp <= 0

static func can_report(sm: Node, point: Vector2) -> bool:
	return sm.yufeng_salia_state() == "report" and sm.maze_exploration_state().region == "fenshui" and point.distance_to(Site.CHAT_FOOT) <= 95 and Frog.Roads.is_walkable(point)

static func advance(sm: Node, next: String, line: int = 0, point := Vector2.ZERO) -> Dictionary:
	var record: Dictionary = sm.yufeng_salia_record()
	var phase: String = record.phase
	var sequence: Array = {"intro":INTRO,"clue":CLUE,"post":POST,"farewell":FAREWELL}.get(phase,[])
	var following: String = {"unseen":"intro","intro":"investigate","investigate":"clue","clue":"report","report":"post","post":"gift_pending","gift_reward":"farewell","farewell":"joined","joined":"fade","fade":"done"}.get(phase,"")
	var next_line: bool = next == phase and not sequence.is_empty() and line == int(record.line)+1 and line < sequence.size()
	var next_phase: bool = next == following and line == 0 and (phase == "clue" or sequence.is_empty() or int(record.line) == sequence.size()-1)
	if not next_line and not next_phase: return {"success":false,"reason":"invalid_transition"}
	if next_phase and next == "clue" and not can_inspect(sm,point): return {"success":false,"reason":"clue_unavailable"}
	if next_phase and next == "post" and not can_report(sm,point): return {"success":false,"reason":"report_unavailable"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	var state: Dictionary = sm.get("_state")
	record.phase = next
	record.line = line
	if next == "investigate" or next == "joined":
		var journal: Dictionary = sm._quest_journal()
		Registry.ensure_instance(journal, QUEST, next == "joined")
		state[sm.QUEST_JOURNAL_KEY] = journal
	if next == "joined":
		var collection := Recruitment.owned(sm)
		if not collection.valid:
			sm.set("_state",before)
			return {"success":false,"reason":"invalid_collection"}
		for id in ["yufeng","salia"]:
			if id not in collection.ids: collection.ids.append(id)
		state[Recruitment.OWNED_KEY] = collection.ids
		preload("res://scripts/maze/story_party_join.gd").apply(sm,state.get("capture_run_v1",{}),true)
	state[KEY] = record
	if sm.save(): return {"success":true}
	sm.set("_state",before)
	return {"success":false,"reason":"save_failed"}
