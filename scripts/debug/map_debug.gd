extends RefCounted
## 调试地图操作只写试玩副本，原档状态留在当前会话中供返回。
const Run = preload("res://scripts/maze/capture_run.gd")
const Roads = preload("res://data/maze/entry_roads.gd")
const Routes = preload("res://data/maze/region_routes.gd")
const SCENES = {
	"maze_entry":"res://scenes/maze_entry.tscn",
	"fenshui":"res://scenes/maze_fenshui.tscn",
	"salt_pool":"res://scenes/maze_salt_pool.tscn",
	"moss_pool":"res://scenes/maze_moss_pool.tscn",
	"waterkeeper_cottage":"res://scenes/maze_waterkeeper_cottage.tscn"
}
var trial_save_path := "user://debug-map-trial.json"
var _original: Dictionary = {}
var _original_path := ""
var _original_pending := false
var _original_party: Array = []

func regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id":"maze_entry","name":"枯水渠"}]
	for id in ["fenshui","salt_pool","moss_pool","waterkeeper_cottage"]:
		result.append({"id":id,"name":Routes.route(id).name})
	return result

func points(region: String) -> Array[Dictionary]:
	if not SCENES.has(region): return []
	var spawn: Vector2 = Roads.SPAWN if region == "maze_entry" else Routes.route(region).spawn
	var result: Array[Dictionary] = [{"id":"entrance","name":"正常入口","position":spawn}]
	if region == "fenshui":
		result.append({"id":"fish_eel","name":"鱼鳗观察点","position":Vector2(1065,450)})
		result.append({"id":"frog","name":"巨蛙附近","position":Vector2(900,510)})
	return result

func is_trial() -> bool:
	return not _original.is_empty()

func prepare(sm: Node, region: String, point_id := "entrance", restart := false) -> Dictionary:
	if not OS.is_debug_build() or sm._replaying or sm._prologue_preview:
		return _error("当前模式不能调试跳图")
	if not SCENES.has(region): return _error("未知地图")
	if not sm.can_enter_maze(): return _error("请先完成第一章并准备探索队伍")
	var run := Run.snapshot(sm)
	if run.get("active",false) and (not Run.valid(run) or not str(run.get("pending","")).is_empty()):
		return _error("请先完成当前捕获或奖励操作")
	var point := Vector2.INF
	if point_id == "current":
		var location: Dictionary = sm.maze_exploration_state()
		if location.region == region and run.get("active",false):
			point = Vector2(location.position[0],location.position[1])
	else:
		for row in points(region):
			if row.id == point_id: point = row.position
	if not point.is_finite() or not sm.maze_terrain(region).is_walkable(point):
		return _error("落点不可用，请选择正常入口")
	var previous: Dictionary = sm.data.duplicate(true)
	var previous_path: String = sm._active_save_path
	var previous_pending: bool = sm._maze_entry_pending
	var previous_party: Array = sm._maze_entry_party.duplicate()
	sm._active_save_path = trial_save_path
	sm.cancel_maze_entry()
	var result := {"success":true}
	if restart and run.get("active",false):
		result = Run.finish(sm,false,Roads.SPAWN)
		run = Run.snapshot(sm)
	if result.success and not run.get("active",false):
		result = Run.begin(sm,Roads.SPAWN)
	if result.success:
		# 调试跳图取消追击和瞬时攻击，保留生命、携物及各地图怪物结果。
		run = Run.snapshot(sm)
		for actor in run.combat.actors.values():
			actor.mode = "idle"
			actor.windup = 0.0
		for key in ["shots","enemy_shots"]: run.combat[key] = []
		run.combat["action_left"] = 0.0
		run.combat["axe_pending"] = false
		sm.data[Run.KEY] = run
		result = Run.change_region(sm,region,point)
	# 同区同落点时位置事务可能无需写盘，仍需保存试玩状态及瞬时清理。
	if result.success and not sm.save(): result = {"success":false}
	if not result.success:
		sm.data = previous
		sm._active_save_path = previous_path
		sm._maze_entry_pending = previous_pending
		sm._maze_entry_party = previous_party
		return _error("试玩准备或保存失败，仍保留原进度")
	if not is_trial():
		_original = previous
		_original_path = previous_path
		_original_pending = previous_pending
		_original_party = previous_party
	return {"success":true,"scene_path":SCENES[region],"message":"已进入试玩副本；原存档未修改"}

func leave(sm: Node) -> Dictionary:
	if not OS.is_debug_build() or not is_trial(): return _error("当前没有地图试玩副本")
	sm.data = _original.duplicate(true)
	sm._active_save_path = _original_path
	sm._maze_entry_pending = _original_pending
	sm._maze_entry_party = _original_party.duplicate()
	_original.clear()
	_original_party.clear()
	return {"success":true,"scene_path":sm.resume_scene_path(),"message":"已返回原存档进度"}

func _error(message: String) -> Dictionary:
	return {"success":false,"message":message}
