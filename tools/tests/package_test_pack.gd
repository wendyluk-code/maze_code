extends SceneTree
func _init() -> void:
	var pack := PCKPacker.new()
	var result := pack.pck_start(OS.get_environment("MAZE_TEST_PCK"))
	if result == OK:
		result = _add_directory(pack, "res://tools/tests")
	if result == OK:
		result = _add_directory(pack, "res://scripts/maze/tests")
	if result == OK:
		result = pack.flush()
	quit(result)

func _add_directory(pack: PCKPacker, path: String) -> int:
	for filename in DirAccess.get_files_at(path):
		if filename.get_extension() not in ["gd", "tscn", "tres", "gdshader", "json"]:
			continue
		var result := pack.add_file(path.path_join(filename), path.path_join(filename))
		if result != OK:
			return result
	for directory in DirAccess.get_directories_at(path):
		var result := _add_directory(pack, path.path_join(directory))
		if result != OK:
			return result
	return OK
