extends RefCounted
## 全部卡面的唯一ID→插画入口；不持有战斗规则或可携带卡库。
const ART_PATH := "res://data/battle/tutorial_art.json"
const DISPLAY_PATH := "res://data/cards/xlsx_remaining_cards.json"
static var _illustrations: Dictionary = {}

static func path_for(id: String) -> String:
	if _illustrations.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH))
		if parsed is Dictionary:
			_illustrations = parsed.get("illustrations", {})
	return str(_illustrations.get(id, ""))

static func display_records() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DISPLAY_PATH))
	return parsed.get("cards", []) if parsed is Dictionary else []
