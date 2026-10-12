class_name CookingRecipeCatalog
extends RefCounted

## 首单配方配置。速度与判定区宽度集中在此，新增料理可复用同一 QTE。
const RECIPES := {
	"salt_grilled_rockmane": {
		"name": "盐烤岩鬃肉",
		"ingredients": {"rockmane_meat": 1, "rock_salt": 1},
		"round_duration": 5.0,
		"perfect_width": 0.16,
		# 含中间绿色：0.16 + 左右黄色各 0.32，单侧黄色为绿色总宽度的两倍。
		"good_width": 0.80,
	}
}

## 只有登记为原料的物品才会出现在汤锅中；料理成品不作为原料。
const INGREDIENTS := {
	"rockmane_meat": {"name": "岩鬃肉", "icon": "res://assets/ui/ingredients/rockmane_meat.png", "icon_region": Rect2(77, 83, 106, 95)},
	"rock_salt": {"name": "岩盐", "icon": "res://assets/ui/ingredients/rock_salt.png", "icon_region": Rect2(83, 88, 97, 90)},
}

static func recipe_ids() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in RECIPES:
		result.append(str(recipe_id))
	return result

static func get_ingredient(item_id: String) -> Dictionary:
	return INGREDIENTS.get(item_id, {}).duplicate(true)

static func is_ingredient(item_id: String) -> bool:
	return INGREDIENTS.has(item_id)

static func can_cook(recipe_id: String, inventory: Dictionary) -> bool:
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	for item_id in recipe.ingredients:
		var quantity = inventory.get(item_id, 0)
		if not is_ingredient(str(item_id)) or typeof(quantity) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(quantity)) or quantity < recipe.ingredients[item_id]:
			return false
	return true

static func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {}).duplicate(true)
