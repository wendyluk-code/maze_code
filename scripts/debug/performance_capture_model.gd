extends RefCounted
## 一秒一条采样，按单调时钟保留最近15分钟；不写入游戏存档。
const WINDOW_MS := 15 * 60 * 1000
var session := ""
var detail := false
var started_ms := 0
var started_at := ""
var samples: Array[Dictionary] = []
var markers: Array[Dictionary] = []

func begin(id: String, detailed: bool, now_ms: int) -> void:
	session = id
	detail = detailed
	started_ms = now_ms
	started_at = Time.get_datetime_string_from_system()
	samples.clear()
	markers.clear()

func add_sample(now_ms: int, sample: Dictionary) -> void:
	var entry := sample.duplicate(true)
	entry["at_ms"] = now_ms - started_ms
	samples.append(entry)
	_trim(now_ms)

func mark(now_ms: int, text: String) -> void:
	markers.append({"at_ms": now_ms - started_ms, "label": text})
	_trim(now_ms)

func _trim(now_ms: int) -> void:
	var cutoff := now_ms - started_ms - WINDOW_MS
	while not samples.is_empty() and int(samples[0].at_ms) < cutoff: samples.pop_front()
	while not markers.is_empty() and int(markers[0].at_ms) < cutoff: markers.pop_front()

func snapshot() -> Dictionary:
	return {"version": 1, "session": session, "detail": detail, "started_at": started_at,
		"window_ms": WINDOW_MS, "samples": samples.duplicate(true), "markers": markers.duplicate(true)}
