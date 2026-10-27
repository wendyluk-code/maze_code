extends Node2D
const FRAMES := [preload("res://assets/maze_portal_0.png"),preload("res://assets/maze_portal_1.png"),preload("res://assets/maze_portal_2.png"),preload("res://assets/maze_portal_3.png")]
var sprite: Sprite2D
## 只阻挡路标脚下；横向给人物与石阵留间隔，纵向保留前后遮挡。
const CLEARANCE := Vector2(58, 20)
var player: Node2D
func _ready() -> void:
	add_to_group("maze_portals")
	player = get_parent().get_node_or_null("Player")
	if is_instance_valid(player): get_parent().move_child(self, player.get_index())
	sprite = Sprite2D.new()
	sprite.texture = FRAMES[0]
	sprite.position = Vector2(0,-25)
	sprite.scale = Vector2.ONE * 0.11
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
func _process(_delta: float) -> void:
	sprite.texture = FRAMES[int(Time.get_ticks_msec()/180.0)%FRAMES.size()]
	if is_instance_valid(player):
		z_index = player.z_index + (1 if player.global_position.y < global_position.y else 0)

func blocks_step(origin: Vector2, target: Vector2) -> bool:
	var next := target - position
	if absf(next.x) >= CLEARANCE.x or absf(next.y) >= CLEARANCE.y: return false
	var previous := origin - position
	# 旧存档可能位于新增阻挡内，允许向外走出，不把玩家困在原地。
	if absf(previous.x) < CLEARANCE.x and absf(previous.y) < CLEARANCE.y:
		return next.length_squared() <= previous.length_squared()
	return true
