extends RefCounted
## 背包展示副本：按 alpha >= 0.1 的可见轮廓裁边，源纹理保持不变。
## 缓存以源纹理资源为键；每种纹理只扫描一次，最多保留128份显示副本。
static var _cache: Dictionary = {}

static func texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	if _cache.has(source):
		return _cache[source]
	# AtlasTexture.get_image() 返回该 atlas 区域的图像，不扫描整张图集。
	var image := source.get_image()
	var result: Texture2D = source
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var minimum := image.get_size()
		var maximum := Vector2i(-1, -1)
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a >= 0.1:
					minimum = minimum.min(Vector2i(x, y))
					maximum = maximum.max(Vector2i(x, y))
		if maximum.x >= 0:
			result = ImageTexture.create_from_image(image.get_region(Rect2i(minimum, maximum - minimum + Vector2i.ONE)))
	if _cache.size() >= 128:
		_cache.erase(_cache.keys()[0])
	_cache[source] = result
	return result
