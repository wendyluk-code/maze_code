extends Node
## 用导出 EXE 加载全部运行脚本；启动菜单成功不能替代依赖检查。

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("MAZE_PACKAGE_MANIFEST")))
	var failed: Array = []
	for path in paths:
		var resource = load(path)
		if resource == null or (resource is GDScript and not resource.can_instantiate()):
			failed.append(path)
	var result := {"checked": paths.size(), "failed": failed, "checks": paths.size(), "failures": failed.size()}
	var file := FileAccess.open(OS.get_environment("MAZE_PACKAGE_REPORT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("PACKAGE_AUDIT ", JSON.stringify(result))
	get_tree().quit(0 if failed.is_empty() else 1)
