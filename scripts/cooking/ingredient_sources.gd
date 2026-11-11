extends RefCounted
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Routes := preload("res://data/maze/region_routes.gd")

static func entries() -> Dictionary:
	var result := {}
	var groups := {"maze_entry":preload("res://data/maze/capture_catalog.gd").TYPES,"fenshui":preload("res://data/maze/fenshui_encounters.gd").TYPES,"salt_pool":preload("res://data/maze/salt_pool_encounters.gd").TYPES}
	groups.fenshui = groups.fenshui.duplicate()
	groups.salt_pool = groups.salt_pool.duplicate()
	groups.fenshui["wind_frog"] = preload("res://data/maze/fenshui_boss.gd").TYPE
	groups.salt_pool["rockmane"] = preload("res://data/maze/salt_boss.gd").TYPE
	for region in groups:
		for monster in groups[region].values():
			for item in monster.drops: result[item] = {"region":region,"text":region_name(region)+"·捕获"+monster.name}
	for region in preload("res://data/maze/region_resources.gd").POINTS:
		for point in preload("res://data/maze/region_resources.gd").POINTS[region]:
			if Recipes.is_ingredient(point[3]): result[point[3]] = {"region":region,"text":region_name(region)+"·采集"+Recipes.get_ingredient(point[3]).name}
	result["rock_salt"] = {"region":"salt_pool","text":"盐池·开采盐晶"}
	for item in preload("res://data/maze/elder_firewood.gd").REWARD_ITEMS:
		result[item.id] = {"region":"maze_entry","text":"枯水渠·白虎爷爷任务奖励","elder":true}
	for item in ["white_truffle","jade_lily","golden_bird_nest"]:
		result[item] = {"region":"fenshui","text":"分水庭·御风赠礼","gift":true}
	return result

static func region_name(region: String) -> String:
	return "枯水渠" if region=="maze_entry" else str(Routes.route(region).get("name",region))

static func description(id: String) -> String:
	return str(entries().get(id,{}).get("text",Recipes.get_ingredient(id).get("source","暂无已确认的获取途径")))

static func explored(sm: Node) -> Array:
	var regions: Array = sm._state.get("restaurant_explored_regions",[]).duplicate()
	var current: String = sm.maze_exploration_state().region
	if current != "restaurant" and current not in regions: regions.append(current)
	if sm._state.get("first_exploration_gate_v1","")=="done" and "maze_entry" not in regions: regions.append("maze_entry")
	var combat: Dictionary = sm._state.get("capture_run_v1",{}).get("combat",{})
	if combat.get("fenshui_encounters",false) and "fenshui" not in regions: regions.append("fenshui")
	if combat.get("salt_encounters",false) and "salt_pool" not in regions: regions.append("salt_pool")
	return regions

static func suggestions(sm: Node) -> Array:
	var visited := explored(sm)
	var allowed := visited.duplicate()
	var current: String = sm._state.get("restaurant_last_region","")
	if current.is_empty() and not visited.is_empty(): current = str(visited.back())
	for region in Routes.ROUTES:
		if Routes.ROUTES[region].previous_id==current and region not in allowed: allowed.append(region)
	var sources := entries()
	var stock: Dictionary = sm._state.get("warehouse_stock",{})
	var candidates := []
	for id in sm.unlocked_recipe_ids():
		if Recipes.order_gold(id)<=0: continue
		var recipe := Recipes.get_recipe(id)
		var missing := 0
		var owned := 0
		var valid := true
		for item in recipe.ingredients:
			var need: int = recipe.ingredients[item]
			owned += mini(need,int(stock.get(item,0)))
			var lack := maxi(0,need-int(stock.get(item,0)))
			missing += lack
			if lack==0: continue
			var source: Dictionary = sources.get(item,{})
			if source.get("region","") not in allowed: valid=false
			# 一次性奖励已领完且没有库存，不再推荐重复领取。
			if source.get("elder",false) and sm.elder_backpack_unlocked(): valid=false
			if source.get("gift",false): valid=false
		if valid and missing>0: candidates.append({"id":id,"missing":missing,"owned":owned})
	candidates.sort_custom(func(a,b):
		if a.owned!=b.owned: return a.owned>b.owned
		if a.missing!=b.missing: return a.missing<b.missing
		return Recipes.recipe_ids().find(a.id)<Recipes.recipe_ids().find(b.id))
	return candidates.slice(0,3)
