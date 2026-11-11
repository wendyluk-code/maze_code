extends Node
## 调试构建下的轻量运行采样。时间间隔为游戏进程回调间隔，不冒称浏览器实际呈现帧。
const Model = preload("res://scripts/debug/performance_capture_model.gd")
const SAVE_INTERVAL_MS := 15000
var model = Model.new()
var active := false
var detailed := false
var last_frame_us := 0
var last_sample_ms := 0
var last_save_ms := 0
var frame_times: Array[float] = []
var spans: Dictionary = {}
var save_status := "未开始"
var last_report: Dictionary = {}
var web_environment: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func begin_capture(with_detail: bool) -> void:
	if not OS.is_debug_build(): return
	var now := Time.get_ticks_msec()
	var id := "perf_%s_%d" % [Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_"), now]
	model.begin(id, with_detail, now)
	detailed = with_detail
	active = true
	last_frame_us = 0
	last_sample_ms = now
	last_save_ms = now
	frame_times.clear()
	spans.clear()
	save_status = "采集中"
	web_environment = _web_environment()
	set_process(true)

func stop_capture() -> void:
	if not active: return
	_collect(Time.get_ticks_msec())
	model.mark(Time.get_ticks_msec(), "停止采集并保存")
	active = false
	set_process(false)
	_save()

func mark() -> void:
	if active: model.mark(Time.get_ticks_msec(), "手动标记卡顿")

func record_span(label: String, elapsed_us: int) -> void:
	if not active or not detailed: return
	var entry: Dictionary = spans.get(label, {"calls": 0, "total_us": 0, "max_us": 0})
	entry.calls += 1
	entry.total_us += elapsed_us
	entry.max_us = maxi(entry.max_us, elapsed_us)
	spans[label] = entry

func _process(_delta: float) -> void:
	if not active: return
	var now_us := Time.get_ticks_usec()
	if last_frame_us > 0: frame_times.append(float(now_us - last_frame_us) / 1000.0)
	last_frame_us = now_us
	var now := Time.get_ticks_msec()
	if now - last_sample_ms >= 1000:
		_collect(now)
		last_sample_ms = now
	if now - last_save_ms >= SAVE_INTERVAL_MS:
		model.mark(now, "定期保存")
		_save()
		last_save_ms = now
	_read_web_status()

func _collect(now: int) -> void:
	var sorted := frame_times.duplicate()
	sorted.sort()
	var slow50 := 0
	for elapsed in sorted:
		if elapsed > 50.0: slow50 += 1
	var scene := get_tree().current_scene
	var info := {
		"paused": get_tree().paused,
		"scene": scene.scene_file_path if is_instance_valid(scene) else "",
		"game_fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_count": sorted.size(),
		"frame_p95_ms": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))] if not sorted.is_empty() else 0.0,
		"frame_max_ms": sorted[-1] if not sorted.is_empty() else 0.0,
		"frame_over_50ms": slow50,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
	}
	if detailed:
		info["spans"] = spans.duplicate(true)
		info["combat"] = _combat_context()
	if OS.has_feature("web"):
		info["page_visibility"] = str(JavaScriptBridge.eval("document.visibilityState", true))
	model.add_sample(now, info)
	frame_times.clear()
	spans.clear()

func _combat_context() -> Dictionary:
	var sm := get_node_or_null("/root/SaveManager")
	if not is_instance_valid(sm): return {}
	var state: Variant = sm.get("_state")
	if not state is Dictionary: return {}
	var run: Dictionary = state.get("capture_run_v1", {})
	if not run.get("active", false): return {}
	var combat: Dictionary = run.get("combat", {})
	var monster_state: Dictionary = run.get("monsters", {})
	var actors: Array[Dictionary] = []
	for id in combat.get("actors", {}):
		var monster: Dictionary = monster_state.get(id, {})
		if monster.get("status", "") != "alive": continue
		var actor: Dictionary = combat.actors[id]
		actors.append({"id": str(id), "mode": str(actor.get("mode", "")),
			"phase": str(actor.get("rock_phase", actor.get("frog_phase", ""))),
			"position": actor.get("position", [])})
	return {"region": str(combat.get("region", "")), "hero": combat.get("hero", []),
		"action": str(combat.get("action", "")), "actors": actors,
		"shots": combat.get("shots", []).size(), "enemy_shots": combat.get("enemy_shots", []).size()}

func _save() -> void:
	last_report = model.snapshot()
	last_report["engine"] = Engine.get_version_info()
	last_report["platform"] = OS.get_name()
	last_report["browser"] = web_environment
	last_report["measurement"] = "游戏进程回调间隔，不等同浏览器实际呈现帧"
	if OS.has_feature("web"):
		var json_literal := JSON.stringify(JSON.stringify(last_report))
		var script := "(() => { const body = %s; window.__mazePerf = window.__mazePerf || {}; window.__mazePerf.status='保存中'; window.__mazePerf.queue = (window.__mazePerf.queue || Promise.resolve()).catch(() => {}).then(() => fetch('/__performance_capture', {method:'POST',headers:{'Content-Type':'application/json'},body})).then(r => { if (!r.ok) throw Error('HTTP ' + r.status); return r.json(); }).then(() => { window.__mazePerf.status='已保存到本机项目目录'; }).catch(e => { window.__mazePerf.status='保存失败：' + e.message; }); })()" % json_literal
		JavaScriptBridge.eval(script, true)
		save_status = "保存中"
		return
	var directory := ProjectSettings.globalize_path("res://output/performance-captures")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		save_status = "保存失败：无法创建诊断目录"
		return
	var file := FileAccess.open(directory.path_join(model.session + ".json"), FileAccess.WRITE)
	if file == null:
		save_status = "保存失败：无法写入诊断文件"
		return
	file.store_string(JSON.stringify(last_report))
	file.close()
	save_status = "已保存到本机项目目录"

func _read_web_status() -> void:
	if OS.has_feature("web"):
		var status: Variant = JavaScriptBridge.eval("window.__mazePerf && window.__mazePerf.status || ''", true)
		if status is String and not status.is_empty(): save_status = status

func _web_environment() -> Dictionary:
	if not OS.has_feature("web"): return {}
	var script := "JSON.stringify((() => { const c=document.querySelector('canvas'); const gl=c && c.getContext('webgl2'); const ext=gl && gl.getExtension('WEBGL_debug_renderer_info'); return {user_agent:navigator.userAgent, viewport:[innerWidth,innerHeight], device_pixel_ratio:devicePixelRatio, canvas:c ? [c.width,c.height] : null, renderer:ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : null}; })())"
	var result: Variant = JSON.parse_string(str(JavaScriptBridge.eval(script, true)))
	return result if result is Dictionary else {}

func download_report() -> bool:
	if not OS.has_feature("web") or last_report.is_empty(): return false
	JavaScriptBridge.download_buffer(JSON.stringify(last_report).to_utf8_buffer(), model.session + ".json", "application/json")
	return true
