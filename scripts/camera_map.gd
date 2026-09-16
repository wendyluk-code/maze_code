extends Camera2D
## 跟随主角的 2D 相机

@export var target_path: NodePath
@export var smooth := 6.0
## 过场动画期间暂停跟随（由教程/剧情控制）
var paused := false

## 地图边界（世界坐标），任何镜头移动不允许超出
const MAP_W := 1448.0
const MAP_H := 1086.0

func _ready() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(MAP_W)
	limit_bottom = int(MAP_H)
	var t := get_node_or_null(target_path) as Node2D
	if t:
		global_position = t.global_position
		make_current()

func _process(delta: float) -> void:
	var t := get_node_or_null(target_path) as Node2D
	if t == null or paused:
		return
	global_position = global_position.lerp(t.global_position, 1.0 - exp(-smooth * delta))