class_name CookingRecipeCatalog
extends RefCounted

## 首单配方配置。速度与判定区宽度集中在此，新增料理可复用同一 QTE。
const RECIPES := {
	"frog_soup":{"name":"凉须蛙囊汤","description":"迷宫非战斗时食用。","uses":["探索"],"exploration_category":"生命","ingredients":{"wind_frog_stomach":1,"cool_whisker_herb":1},"round_duration":5.0,"perfect_width":0.16,"good_width":0.8,"icon":"res://assets/ui/region_food/frog_soup.png"},
	"wind_frog_bread":{"name":"风袋蛙鼓鼓包","description":"迷宫非战斗时食用。","uses":["探索"],"exploration_category":"饱腹","ingredients":{"wind_frog_stomach":1,"burrow_wheat_flour":1},"round_duration":5.0,"perfect_width":0.16,"good_width":0.8,"icon":"res://assets/ui/region_food/wind_frog_bread.png"},
	"mimic_crab_gratin":{"name":"爆浆拟态蟹斗","description":"以新鲜捕获食材制作的订单料理。","order_gold":30,"ingredients":{"mimic_crab_meat":1,"lantern_fruit":1},"round_duration":5.0,"perfect_width":0.16,"good_width":0.8,"icon":"res://assets/ui/region_food/mimic_crab_gratin.png"},
	"scorpion_lotus_fritters":{"name":"脆炸水蝎藕夹","description":"以新鲜捕获食材制作的订单料理。","order_gold":30,"ingredients":{"blind_scorpion_tail":1,"canal_lotus_root":1},"round_duration":5.0,"perfect_width":0.16,"good_width":0.8,"icon":"res://assets/ui/region_food/scorpion_lotus_fritters.png"},

	"cool_slime_jelly": {"name": "清凉史莱姆冻", "description": "探索料理，放入便当盒后可在迷宫非战斗时食用。", "uses": ["探索"], "exploration_category": "生命", "ingredients": {"slime_gel": 1, "cool_whisker_herb": 1}, "round_duration": 5.0, "perfect_width": 0.16, "good_width": 0.8, "icon": "res://assets/ui/bento/cool_slime_jelly.png"},
	"salt_crust_silverfish": {"name": "盐壳银鳞鱼", "description": "探索料理，放入便当盒后可在迷宫非战斗时食用。", "uses": ["探索"], "exploration_category": "防御", "ingredients": {"silverfish_meat": 1, "rock_salt": 1}, "round_duration": 5.0, "perfect_width": 0.16, "good_width": 0.8, "icon": "res://assets/ui/bento/salt_crust_silverfish.png"},
	"thunder_eel_roll": {"name": "雷鳗自煎卷", "description": "探索料理，放入便当盒后可在迷宫非战斗时食用。", "uses": ["探索"], "exploration_category": "攻击", "ingredients": {"thunder_eel_belly": 1, "insulating_leaf": 1}, "round_duration": 5.0, "perfect_width": 0.16, "good_width": 0.8, "icon": "res://assets/ui/bento/thunder_eel_roll.png"},
	"slime_candy": {"name": "弹跳史莱姆冻", "description": "以史莱姆核和月露蜜制成，软弹清甜。", "order_gold": 10, "ingredients": {"slime_shell": 1, "moondew_honey": 1}, "round_duration": 5.0, "perfect_width": 0.16, "good_width": 0.80, "icon": "res://assets/ui/ingredients/day1/bouncing_slime_pudding.png"},
	"brick_snail_sashimi": {"name": "砖壳蜗牛刺身", "description": "砖壳蜗牛肉切片后制成，口感脆嫩，鲜味十足。", "order_gold": 20, "ingredients": {"brick_snail_meat": 1, "cooking_sake": 1}, "round_duration": 5.0, "perfect_width": 0.16, "good_width": 0.80, "icon": "res://assets/ui/ingredients/day1/brick_snail_sashimi.png"},
	"lizard_tail_skewer": {"name": "石化蜥蜴脆皮串", "description": "石化蜥蜴尾肉烤至表皮酥脆，肉质紧实，香气浓厚。", "order_gold": 40, "ingredients": {"petrifying_lizard_tail": 1, "sour_vine_juice": 1}, "round_duration": 5.0, "perfect_width": 0.16, "good_width": 0.80, "icon": "res://assets/ui/ingredients/day1/lizard_tail_skewer.png"},
	"salt_grilled_rockmane": {
		"name": "盐烤岩鬃肉",
		"description": "岩鬃肉经过盐烤，肉香浓郁，外焦里嫩。",
		"order_gold": 20,
		"ingredients": {"rockmane_meat": 1, "rock_salt": 1},
		"round_duration": 5.0,
		"perfect_width": 0.16,
		# 含中间绿色：0.16 + 左右黄色各 0.32，单侧黄色为绿色总宽度的两倍。
		"good_width": 0.80,
	}
}

## 只有登记为原料的物品才会出现在汤锅中；料理成品不作为原料。
const INGREDIENTS := {
	"canal_lotus_root":{"name":"细孔渠藕","icon":"res://assets/ui/region_food/canal_lotus_root.png"},
	"lantern_fruit":{"name":"灯笼果","icon":"res://assets/ui/region_food/lantern_fruit.png"},
	"burrow_wheat_flour":{"name":"地穴麦粉","icon":"res://assets/ui/region_food/burrow_wheat_flour.png"},

	"cool_whisker_herb": {"name": "凉须草", "icon": "res://assets/ui/bento/cool_whisker_herb.png"},
	"mimic_crab_meat": {"name":"拟态宝箱蟹肉","icon":"res://assets/monsters/mimic_crab/meat.png"},
	"blind_scorpion_tail": {"name":"盲水蝎尾肉","icon":"res://assets/monsters/blind_scorpion/meat.png"},
	"wind_frog_stomach": {"name":"风袋蛙胃囊","icon":"res://assets/monsters/wind_frog/stomach.png"},
	"silverfish_meat": {"name": "银鳞鱼肉", "icon": "res://assets/ui/bento/silverfish_meat.png"},
	"thunder_eel_belly": {"name": "雷鳗腹肉", "icon": "res://assets/ui/bento/thunder_eel_belly.png"},
	"insulating_leaf": {"name": "绝缘叶", "icon": "res://assets/ui/bento/insulating_leaf.png"},
	# 保留旧存档物品标识，已获得的数量和本趟暂存无需迁移。
	"slime_shell": {"name": "史莱姆核", "icon": "res://assets/ui/ingredients/jelly_slime_core.png"},
	"sword_beetle_leg": {"name": "剑甲虫腿", "icon": "res://assets/ui/ingredients/day1/sword_beetle_leg.png"},
	"slime_gel": {"name": "史莱姆凝胶", "icon": "res://assets/ui/ingredients/slime_gel.png"},
	"moondew_honey": {"source": "支线任务、商店", "name": "月露蜜", "icon": "res://assets/ui/ingredients/day1/moondew_honey.png"},
	"brick_snail_meat": {"name": "砖壳蜗牛肉", "icon": "res://assets/ui/ingredients/day1/brick_snail_meat.png"},
	"cooking_sake": {"source": "支线任务、商店", "name": "烧酒", "icon": "res://assets/ui/ingredients/day1/cooking_sake.png"},
	"petrifying_lizard_tail": {"name": "石化蜥蜴尾肉", "icon": "res://assets/ui/ingredients/day1/petrifying_lizard_tail.png"},
	"sour_vine_juice": {"source": "支线任务、迷宫探索", "name": "酸浆藤汁", "icon": "res://assets/ui/ingredients/sour_vine_juice.png", "icon_region": Rect2(95, 77, 66, 103)},
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

## 每份订单的固定金币，与料理星级无关；无效配置拒绝结算。
static func valid_order_gold(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= 5 and value <= 40

static func order_gold(recipe_id: String) -> int:
	var value = get_recipe(recipe_id).get("order_gold")
	return int(value) if valid_order_gold(value) else 0

static func item_texture(id: String) -> Texture2D:
	var entry := get_ingredient(id) if is_ingredient(id) else get_recipe(id)
	if id == "salt_grilled_rockmane":
		entry = {"icon": "res://assets/ui/ingredients/salt_grilled_rockmane.png", "icon_region": Rect2(279, 424, 696, 505)}
	if not entry.has("icon"): return null
	var source := load(str(entry.icon)) as Texture2D
	if not entry.has("icon_region"): return source
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = entry.icon_region
	return texture



