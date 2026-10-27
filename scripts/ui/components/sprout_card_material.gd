class_name SproutCardMaterial
extends RefCounted
## 正式卡面素材目录：完整卡图只作为边框与插画来源，文字区由 SproutCard 重绘。

const YAYA_ROLE := "res://assets/ui/battle/cards/yaya/yaya.png"
const YAYA_FORM := "res://assets/ui/battle/cards/yaya/small_spoon_person.png"
const YAYA_SPELL := "res://assets/ui/battle/cards/yaya/warm_care.png"
const YAYA_FIELD := "res://assets/ui/battle/cards/yaya/field_kitchen.png"
const YAYA_COLLAB := "res://assets/ui/battle/cards/yaya/hotpot_collab.png"
const TIESHAN_ROLE := "res://assets/ui/party_cards/tieshan.png"
const EDGE_ROOT := "res://assets/ui/card_materials/edge_v4/"
static var _edge_layout: Dictionary = {}
const STATUS_ATLAS := "res://assets/ui/card_materials/bt_03/status_icons.png"

static func status_icon(id: String) -> AtlasTexture:
	var regions := {
		"attack": Rect2(106, 74, 340, 418),
		"health": Rect2(603, 51, 329, 439),
		"mana": Rect2(1100, 46, 359, 450),
		"satiety": Rect2(57, 574, 414, 376),
		"hunger": Rect2(577, 559, 383, 394),
		"revive": Rect2(1128, 541, 302, 426),
	}
	var result := AtlasTexture.new()
	result.atlas = load(STATUS_ATLAS)
	result.region = regions[id]
	result.filter_clip = true
	return result

static func edge_layer(id: String) -> Dictionary:
	if _edge_layout.is_empty():
		_edge_layout = JSON.parse_string(FileAccess.get_file_as_string(EDGE_ROOT + "slices.json"))
	for layer: Dictionary in _edge_layout.layers:
		if layer.id == id:
			return layer
	return {}

static func edge_rect(id: String) -> Rect2:
	var values: Array = edge_layer(id).rect_300x500
	return Rect2(values[0], values[1], values[2], values[3])

static func path_for(character_name: String, title: String, card_type: String, is_role_card: bool) -> String:
	if character_name == "芽芽":
		if is_role_card or title == "芽芽":
			return YAYA_ROLE
		match title:
			"小小掌勺人": return YAYA_FORM
			"温火照料": return YAYA_SPELL
			"战地小厨": return YAYA_FIELD
			"热锅协作": return YAYA_COLLAB
		match card_type:
			"法术牌": return YAYA_SPELL
			"赋形牌", "形态牌": return YAYA_FORM
			"料理": return YAYA_SPELL
			_: return YAYA_ROLE
	if character_name == "铁山":
		return TIESHAN_ROLE
	return ""

static func is_material_path_valid(path: String) -> bool:
	return not art_path_for(path).is_empty() and ResourceLoader.exists(art_path_for(path))

static func art_path_for(source: String) -> String:
	var names := {YAYA_ROLE: "yaya", YAYA_FORM: "small_spoon_person", YAYA_SPELL: "warm_care", YAYA_FIELD: "field_kitchen", YAYA_COLLAB: "hotpot_collab", TIESHAN_ROLE: "tieshan"}
	if not names.has(source):
		return ""
	return EDGE_ROOT + "layers/illustration_%s.png" % names[source]
