extends RefCounted
## 从动作帧上部可见轮廓定位头顶，兼容透明留白及坐姿水平翻转。
static var _heads: Dictionary = {}

static func local_point(actor: Sprite2D) -> Vector2:
	var texture := actor.texture
	if texture == null: return Vector2.ZERO
	var key := str(texture.get_instance_id())
	if texture is AtlasTexture:
		key = str(texture.atlas.get_instance_id())+str(texture.region)
	if not _heads.has(key):
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		var used := pixels.get_used_rect()
		var band := Rect2i(used.position,Vector2i(used.size.x,maxi(1,roundi(used.size.y*0.28))))
		var head := pixels.get_region(band).get_used_rect()
		_heads[key] = Vector2(band.position.x+head.position.x+head.size.x*0.5,used.position.y)
	var point: Vector2 = _heads[key]
	if actor.flip_h: point.x = texture.get_width()-point.x
	if actor.flip_v: point.y = texture.get_height()-point.y
	return actor.get_rect().position+point-Vector2(0,6.0/actor.scale.y)
