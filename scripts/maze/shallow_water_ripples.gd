extends Node2D
## 脚底白色涟漪：只读实际位移和地形，不改变移动、战斗或存档。
const LIFETIME := 0.9
const STEP_DISTANCE := 13.0
const MAX_RIPPLES := 6
var player: Node2D
var ripples: Array[Dictionary] = []
var _last_position := Vector2.ZERO
var _distance := 0.0
var _moving_in_water := false
var _serial := 0

func _ready() -> void:
	player = get_parent() as Node2D
	_last_position = player.global_position
	process_priority = 10

func _process(delta: float) -> void:
	var current := player.global_position
	var moved := current.distance_to(_last_position)
	_last_position = current
	var paused: bool = player.input_locked or not player.is_physics_processing() or (is_instance_valid(player.capture_flow) and player.capture_flow.combat_paused())
	if paused:
		_distance = 0.0
		_moving_in_water = false
		return
	# 换位/读档不留下横穿地图的波纹；正常移动仍按实际距离产生。
	if moved > 60.0:
		ripples.clear()
		_distance = 0.0
		_moving_in_water = false
		queue_redraw()
		return
	for ripple in ripples: ripple.age += delta
	ripples = ripples.filter(func(ripple): return ripple.age < LIFETIME)
	var wet: bool = player.terrain.has_method("terrain_multiplier") and player.terrain.terrain_multiplier(player.position) < 1.0 and player.terrain.is_walkable(player.position)
	# 渲染帧可能多于物理帧；零位移渲染帧不代表停步，避免每次物理更新都重发首圈。
	var walking: bool = wet and player._walking
	if walking and moved > 0.01:
		_distance += moved
		if not _moving_in_water or _distance >= STEP_DISTANCE:
			_emit(current)
			_distance = fmod(_distance, STEP_DISTANCE)
	elif not walking:
		_distance = 0.0
	_moving_in_water = walking
	queue_redraw()

func _emit(point: Vector2) -> void:
	_serial += 1
	var camera := get_viewport().get_camera_2d()
	var zoom_factor: float = camera.zoom.x if is_instance_valid(camera) else 1.0
	ripples.append({"center":point,"age":0.0,"variant":_serial%3,"scale":1.0/zoom_factor})
	if ripples.size() > MAX_RIPPLES: ripples.pop_front()

func _draw() -> void:
	for ripple in ripples:
		var progress: float = ripple.age/LIFETIME
		var radius: float = lerpf(18.0,72.0,1.0-pow(1.0-progress,1.4))*ripple.scale
		var opacity: float = smoothstep(0.0,0.08,progress)*(1.0-smoothstep(0.25,1.0,progress))
		var center: Vector2 = to_local(ripple.center)
		# 非闭合薄弧与轻微起伏保持手绘感；压扁椭圆贴合俯视水面。
		for arc in [Vector2(0.10,1.12),Vector2(1.33,2.83),Vector2(3.02,4.15),Vector2(4.40,6.12)]:
			var points := PackedVector2Array()
			for i in 15:
				var angle: float = lerpf(arc.x,arc.y,float(i)/14.0)+float(ripple.variant)*0.10
				var organic := 1.0+0.025*sin(angle*5.0+float(ripple.variant))
				points.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*0.30)*organic)
			draw_polyline(points,Color(0.94,1.0,1.0,opacity*0.15),3.6*ripple.scale,true)
			draw_polyline(points,Color(1.0,1.0,0.98,opacity*0.86),1.5*ripple.scale,true)
