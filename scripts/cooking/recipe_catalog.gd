class_name CookingRecipeCatalog
extends RefCounted

## 首单配方配置。速度与判定区宽度集中在此，新增料理可复用同一 QTE。
const RECIPES := {
	"salt_grilled_rockmane": {
		"name": "盐烤岩鬃肉",
		"ingredients": {"rockmane_meat": 1, "rock_salt": 1},
		"round_duration": 3.6,
		"perfect_width": 0.16,
		"good_width": 0.38,
	}
}

static func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {}).duplicate(true)
