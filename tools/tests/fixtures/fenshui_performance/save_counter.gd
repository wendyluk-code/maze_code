extends "res://scripts/save_manager.gd"
## 仅用于隔离测试，仍执行原来的真实原子保存。
var save_calls := 0
var force_failure := false

func save() -> bool:
	save_calls += 1
	return false if force_failure else super.save()
