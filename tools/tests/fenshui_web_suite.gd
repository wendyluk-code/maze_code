extends Node
## 仅临时网页验收包使用的场景入口；不修改正式主场景或存档。

func _ready() -> void:
 call_deferred("_open")

func _open() -> void:
 if not OS.has_feature("web") or ProjectSettings.get_setting("application/config/name")!="maze_fenshui_lan":
  push_error("网页验收入口只允许独立试玩包")
  return
 var name: String=JavaScriptBridge.eval("new URLSearchParams(location.search).get('scene') || ''",true)
 var scenes:={"fenshui_splash_coverage":"res://tools/tests/fenshui_splash_coverage.tscn","fenshui_slam_visual_area":"res://tools/tests/fenshui_slam_visual_area.tscn","fenshui_frog_counter_flow":"res://tools/tests/fenshui_frog_counter_flow.tscn","":"res://tools/previews/fenshui_feedback_play.tscn"}
 scenes["fenshui_splash_continuity"]="res://tools/tests/fenshui_splash_continuity.tscn"
 if not scenes.has(name):
  push_error("未知网页验收场景")
  return
 get_tree().change_scene_to_file(scenes[name])
