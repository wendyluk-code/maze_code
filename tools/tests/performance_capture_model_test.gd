extends SceneTree

func _initialize() -> void:
	if not ResourceLoader.exists("res://scripts/debug/performance_capture_model.gd"):
		printerr("采集模型尚不存在")
		quit(1)
		return
	var model = load("res://scripts/debug/performance_capture_model.gd").new()
	model.begin("sample", true, 0)
	model.add_sample(0, {"frame_ms": 16.0})
	model.mark(100, "卡顿")
	model.add_sample(901000, {"frame_ms": 40.0})
	var report: Dictionary = model.snapshot()
	assert(report.session == "sample")
	assert(report.detail == true)
	assert(report.samples.size() == 1 and report.samples[0].frame_ms == 40.0)
	assert(report.markers.is_empty())
	model.mark(901100, "卡顿")
	assert(model.snapshot().markers.size() == 1)
	model.begin("next", false, 10)
	assert(model.snapshot().samples.is_empty() and model.snapshot().markers.is_empty())
	print("性能采集模型：滚动窗口、标记和重开检查通过")
	quit()
