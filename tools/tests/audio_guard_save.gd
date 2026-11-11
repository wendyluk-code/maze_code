extends "res://scripts/save_manager.gd"
var audio_guard_root := ""
var audio_guard_blocked := 0
func _write_atomic(path: String, snapshot: Dictionary) -> bool:
 var resolved := ProjectSettings.globalize_path(path).replace("\\","/").simplify_path().to_lower()
 if audio_guard_root.is_empty() or not resolved.begins_with(audio_guard_root + "/"):
  audio_guard_blocked += 1
  return false
 return super._write_atomic(path,snapshot)
