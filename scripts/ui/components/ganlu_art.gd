extends RefCounted
static var result_textures: Dictionary = {}

static func iced_cup() -> Texture2D:
	if result_textures.has("iced"): return result_textures.iced
	var image := preload("res://assets/ui/ganlu/results/iced_cup.png").get_image()
	image.fix_alpha_edges()
	image.generate_mipmaps()
	result_textures.iced = ImageTexture.create_from_image(image)
	return result_textures.iced

static func result_cup(kind: String = "success") -> Texture2D:
	if result_textures.has(kind): return result_textures[kind]
	var regions := {"low":Rect2i(120,100,480,660),"success":Rect2i(680,100,480,660),"high":Rect2i(1230,100,520,660)}
	var image := preload("res://assets/ui/ganlu/results/cups.png").get_image().get_region(regions.get(kind,regions.success))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	result_textures[kind] = texture
	return texture
static func part(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/ui/ganlu/atlas.png")
	texture.region = region
	texture.filter_clip = true
	return texture
static func cup() -> AtlasTexture:
	return part(Rect2(994, 171, 412, 563))
static func pot() -> AtlasTexture:
	return part(Rect2(62, 137, 865, 604))
static func thermometer() -> AtlasTexture:
	return part(Rect2(1521, 68, 260, 697))
