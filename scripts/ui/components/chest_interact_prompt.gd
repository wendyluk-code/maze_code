extends Sprite2D
## 宝箱与已确认的探索挖掘点共用用户指定 E 图形；不替换公共键帽。
const ICON := preload("res://assets/ui/chests/chest_interact_e.png")

func _ready() -> void:
	var region := AtlasTexture.new()
	region.atlas = ICON
	region.region = Rect2(180, 128, 963, 937)
	texture = region
	scale = Vector2.ONE * 24.0 / 963.0
	position = Vector2(0, -48)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
