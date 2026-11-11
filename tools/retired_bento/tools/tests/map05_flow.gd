extends "res://tools/tests/combat_02_flow.gd"
const Resources=preload("res://data/maze/region_resources.gd")
const Bento=preload("res://scripts/restaurant/bento_store.gd")
const Recipes=preload("res://scripts/cooking/recipe_catalog.gd")
const Freezer=preload("res://scripts/restaurant/freezer_store.gd")
func calm() -> void:
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
	sm.data[Run.KEY].combat.action_left=0.0
	sm.data[Run.KEY].combat.axe_pending=false
func stand(row: Dictionary) -> Vector2:
	var terrain=sm.maze_terrain(row.region)
	for distance in range(0,51,2):
		for angle in 32:
			var p: Vector2=row.position+Vector2.RIGHT.rotated(angle*TAU/32)*distance
			if terrain.is_walkable(p): return p
	return Vector2.INF
func grant_bento() -> void:
	sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0})
	_check(Bento.grant(sm).success,"原三份赠礼事务不变")
	sm.set_yufeng_salia_record({"version":2,"phase":"bento_unlock","line":0})
	_check(Bento.reveal(sm).success,"原便当解锁事务")
	sm.set_yufeng_salia_record({"version":2,"phase":"done","line":0})
	for slot in Bento.GIFTS: Bento.discard(sm,slot)
func spawn_region(region: String) -> void:
	calm()
	_check(Run.change_region(sm,region,sm.maze_terrain(region).SPAWN).success,"同趟切区："+region)
	await _close_scene()
	maze=load("res://scenes/maze_"+region+".tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	maze.capture_flow.set_process(false)
	calm()
func _combat_scene() -> void:
	await prepare_trip()
	await continue_trip()
func prepare_trip() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	grant_bento()
func region_encounters(_region: String) -> void:
	pass
func continue_trip() -> void:
	for region in ["fenshui","salt_pool"]:
		await spawn_region(region)
		await region_encounters(region)
		if failures>0: return
		_check(maze.chests.size()==3,"三处真宝箱："+region)
		_check(maze.dig_sites.size()==(6 if region=="fenshui" else 2),"采集数量："+region)
		for row in Resources.all(region):
			var point:=stand(row)
			_check(point!=Vector2.INF,"合法交互站位："+row.id)
			_check(Resources.protected(region,point),"资源站位普通怪保护："+row.id)
			maze.player.position=sm.maze_terrain(region).SPAWN
			maze._update_chest_target()
			_check(maze.chest_target==null and maze.dig_target==null,"远距离提示隐藏："+row.id)
			maze.player.position=point
			maze.camera.snap_to_target()
			maze._update_chest_target()
			_check(is_instance_valid(maze.chest_target if row.item=="gold" else maze.dig_target),"近距唯一目标："+row.id)
			if row.id.ends_with("_1"): await _capture_image("before_"+row.id)
			var before: Dictionary=sm.data.duplicate(true)
			var wrong: Dictionary=sm.claim_exploration_dig_site(row.id,point) if row.item=="gold" else sm.claim_exploration_chest(row.id,point)
			_check(not wrong.success and sm.data==before,"资源身份不能冒充另一种奖励")
			var path: String=sm._active_save_path
			sm._active_save_path=""
			var rejected: Dictionary=sm.claim_exploration_chest(row.id,point) if row.item=="gold" else sm.claim_exploration_dig_site(row.id,point)
			_check(not rejected.success and sm.data==before,"保存失败不领取："+row.id)
			sm._active_save_path=path
			await _send_key(KEY_E)
			await get_tree().create_timer(0.15).timeout
			_check(maze.loot_modal.visible and maze.player.input_locked,"真实E领取与奖励输入锁："+row.id)
			if row.item=="gold": _check(sm.gold_balance()==int(before.get(sm.GOLD_KEY,0))+100,"真箱100金币")
			elif row.item=="wood": _check(sm.inventory_quantity("wood")==3,"永久木材3份")
			else: _check(sm.data[Run.KEY].bag.get(row.item,0)==int(before[Run.KEY].bag.get(row.item,0))+2,"植物两份暂存："+row.item)
			if row.id.ends_with("_1"): await _capture_image("resource_"+row.id)
			await _click(maze.loot_modal._confirm_button)
			_check(not maze.player.input_locked and not maze.loot_modal.visible,"领取关闭恢复输入")
			var result: Dictionary=sm.claim_exploration_chest(row.id,point) if row.item=="gold" else sm.claim_exploration_dig_site(row.id,point)
			_check(not result.success,"同趟不能重复领取")
			_check(sm.save(),"已领写盘")
			sm.load_data()
			_check(sm.is_chest_claimed(row.id) if row.item=="gold" else sm.is_dig_site_claimed(row.id),"重载保留已领")
		await _capture_image("region_collected_"+region)
	await capture_checks()
	calm()
	_check(Run.finish(sm,true,sm.maze_terrain("salt_pool").ENTRANCE).success,"采挖捕获实际结算回餐厅")
	_check(sm.warehouse_snapshot().get("cool_whisker_herb",0)==6 and sm.warehouse_snapshot().get("canal_lotus_root",0)==4 and sm.warehouse_snapshot().get("lantern_fruit",0)==4,"草藕果入仓数量")
	await _close_scene()
	await kitchen()
	_check(Run.begin(sm,Roads.SPAWN).success,"装盒再次探索")
	_check(not sm.is_dig_site_claimed("fenshui_resource_herb_1") and sm.is_dig_site_claimed("fenshui_resource_wood_1") and sm.is_chest_claimed("salt_pool_resource_chest_1"),"新趟植物恢复而木材宝箱永久")
	await effects()
	await _close_scene()
func capture_checks() -> void:
	for spec in [["wind_frog","fenshui_wind_frog_1"],["mimic_crab","salt_pool_mimic_crab_1"],["blind_scorpion","salt_pool_blind_scorpion_1"]]:
		var id: String=spec[1]
		var run: Dictionary=sm.data[Run.KEY]
		# 固定成功随机数和已击败样例，执行正式付费/操作/结算事务。
		run.monsters[id].status="pending"
		run.monsters[id].capture_roll=0.0
		run.monsters[id].copy_roll=0.0 if spec[0]=="wind_frog" else 0.99
		run.combat.actors[id].hp=0
		run.pending=id
		var food:=Run.Progression.satiety_snapshot(sm)
		for member in run.members: food.values[member.id]=float(Run.Progression.record(sm,member.id).satiety_max)
		Run.Progression.store_satiety(sm,food,true)
		run.satiety=Run._party_food(food,run.members)
		_check(Run.start_capture(sm,id).success,"实际捕获付费："+id)
		_check(Run.finish_capture(sm,id,true).success,"成功操作结果保存："+id)
		var before: Dictionary=sm.data.duplicate(true)
		var path: String=sm._active_save_path
		sm._active_save_path=""
		_check(not Run.resolve(sm,id,true).success and sm.data==before,"材料食谱解锁同事务失败回滚："+id)
		sm._active_save_path=path
		_check(Run.resolve(sm,id,true).get("caught",false),"成功捕获才给材料食谱："+id)
		for recipe in preload("res://scripts/maze/capture_recipes.gd").RECIPES[spec[0]]:
			_check(recipe in sm.unlocked_recipe_ids(),"新食谱解锁："+recipe)
		var ids: Array=sm.unlocked_recipe_ids()
		_check(not Run.resolve(sm,id,true).success and sm.unlocked_recipe_ids()==ids,"重复解锁拒绝")
	# 去掉新增解锁字段，明确成功记录仍可迁移；失败不能。
	var saved: Dictionary=sm.data.duplicate(true)
	sm.data[sm.UNLOCKED_RECIPES_KEY]=[]
	_check("frog_soup" in sm.unlocked_recipe_ids(),"现存成功捕获兼容")
	sm.data[Run.KEY].monsters.fenshui_wind_frog_1.status="failed"
	_check("frog_soup" not in sm.unlocked_recipe_ids(),"失败记录不解锁")
	sm.data=saved
func kitchen() -> void:
	sm.data.freezer_unlock_notice_seen=true
	# 麦粉仅测试夹具补一份；其余配方原料来自本次探索。
	sm.data.warehouse_stock.burrow_wheat_flour=1
	maze=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	scene=maze
	await get_tree().create_timer(0.6).timeout
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	var player=maze.get_node("Player")
	for id in ["frog_soup","wind_frog_bread"]:
		var ingredients: Dictionary=Recipes.get_recipe(id).ingredients
		_check(sm.take_warehouse_items(ingredients).success,"仓库实际取料："+id)
		player.global_position=_stand(maze.get_node("InteractPoints/Cauldron"))
		player.last_valid=player.global_position
		await _send_key(KEY_E)
		var cooking=get_tree().get_first_node_in_group("cooking_modal")
		_check(cooking.visible and cooking.recipe_id==id,"餐厅E打开配方："+id)
		if cooking._lesson_paused: await _send_key(KEY_E)
		await _capture_image("cooking_"+id)
		await _click(cooking._start_button)
		await get_tree().create_timer(5.9).timeout
		_check(sm.inventory_quantity(id)==1,"真实制作获得星级料理："+id)
		var quality: int=sm.dish_quality(id)
		_check(quality in [1,2,3] and sm.freezer_carried_options()[0].expires_at==0,"星级来自制作，手持不计时")
		for i in 4:
			if not cooking.visible: break
			await _send_key(KEY_E)
			await get_tree().create_timer(0.15).timeout
		player.global_position=_stand(maze.get_node("InteractPoints/Fridge"))
		player.last_valid=player.global_position
		await _send_key(KEY_E)
		_check(hud.freezer.visible,"真实冰柜E打开")
		await _click(hud.freezer.held.get_node("StoreDish"))
		var unit: Dictionary=sm.freezer_snapshot().stored[-1]
		_check(int(unit.expires_at)-int(Time.get_unix_time_from_system()) in range(Freezer.LIFETIME-3,Freezer.LIFETIME+1),"初次入柜七天")
		await _send_key(KEY_ESCAPE)
		await _click(hud.bento_entry)
		var page=hud.bento_modal
		var slot: String=Bento.recipe_slot(id)
		await _click(page.tiles[slot])
		await _click(page.details.find_child("SelectUnit",true,false))
		_check(page.draft.has(slot),"实际选择具体份："+id)
		await _capture_image("assemble_"+id)
		await _click(page.assemble_button)
		_check(Bento.snapshot(sm).slots.get(slot,{}).get("id")==id,"实际保存装配："+id)
		_check(Bento.snapshot(sm).slots[slot].stars==quality,"装配保留真实星级")
		await _send_key(KEY_ESCAPE)
		_check(not player.input_locked,"关闭便当恢复餐厅输入")
	_check(not Bento.eat(sm).success,"餐厅禁止食用")
	for id in ["mimic_crab_gratin","scorpion_lotus_fritters"]:
		_check(sm.take_warehouse_items(Recipes.get_recipe(id).ingredients).success,"订单菜取本次捕获采集原料："+id)
		_check(sm.start_cooking(id).success and sm.finish_first_order_cooking(3).success,"订单菜真实制作事务："+id)
		_check(Recipes.order_gold(id)==30 and Bento.recipe_slot(id)=="","订单菜30金币无探索效果")
		_check(sm.freezer_action("store",0,id,3).success,"订单菜按份入柜")
	await _close_scene()
func effects() -> void:
	var full_food:=Run.Progression.satiety_snapshot(sm)
	for member in sm.data[Run.KEY].members: full_food.values[member.id]=float(Run.Progression.record(sm,member.id).satiety_max)
	Run.Progression.store_satiety(sm,full_food,true)
	sm.data[Run.KEY].satiety=Run._party_food(full_food,sm.data[Run.KEY].members)
	var baseline: Dictionary=sm.data.duplicate(true)
	for stars in [1,2,3]:
		sm.data=baseline.duplicate(true)
		var run: Dictionary=sm.data[Run.KEY]
		calm()
		run.combat.hp=1.0
		sm.data[Bento.KEY].slots.health.stars=stars
		sm.data[Bento.KEY].slots.satiety.stars=stars
		var food:=Run.Progression.satiety_snapshot(sm)
		for member in run.members: food.values[member.id]=0.0
		Run.Progression.store_satiety(sm,food,true)
		run.satiety=0.0
		var before: Dictionary=sm.data.duplicate(true)
		var path: String=sm._active_save_path
		sm._active_save_path=""
		_check(not Bento.eat(sm).success and sm.data==before,"全吃保存失败效果与份数回滚")
		sm._active_save_path=path
		_check(Bento.eat(sm).success,"两新料理全吃："+str(stars))
		run=sm.data[Run.KEY]
		_check(is_equal_approx(run.combat.hp,1.0+run.combat.max_hp*[0.15,0.25,0.35][stars-1]),"汤三档即时恢复")
		_check(is_equal_approx(run.satiety,float(stars)),"鼓鼓包团队总量而非每人")
		food=Run.Progression.satiety_snapshot(sm)
		var yaya_gain:=minf(ceilf(stars/2.0),Run.Progression.record(sm,"yaya").satiety_max)
		_check(food.values.yaya==yaya_gain and food.values.tieshan==stars-yaya_gain,"按队伍顺序轮流补点并跳过满值")
		_check(run.bento.heal_total==0.0 and Run.valid(run),"即时汤不生成持续恢复")
		_check(not Bento.eat(sm).success,"同份只能食用一次")
		sm.save(); sm.load_data()
		_check(Bento.snapshot(sm).slots.health.eaten and Bento.snapshot(sm).slots.satiety.eaten,"食用状态重载")
	sm.data=baseline.duplicate(true)
	calm()
	var full: Dictionary=sm.data.duplicate(true)
	_check(not Bento.eat(sm,"health").success and sm.data==full,"满生命汤不消耗")
	_check(not Bento.eat(sm,"satiety").success and sm.data==full,"全满饱腹不消耗")
	# 战斗拒绝所有新菜且不消耗。
	sm.data[Run.KEY].combat.actors.slime_1.mode="chase"
	var locked: Dictionary=sm.data.duplicate(true)
	_check(not Bento.eat(sm).success and sm.data==locked,"战斗中拒绝食用")
	calm()
	# 一份满、一份有效时，全吃只消费有效的份。
	sm.data[Run.KEY].combat.hp=1.0
	_check(Bento.eat(sm).success and not Bento.snapshot(sm).slots.satiety.eaten,"全吃跳过满饱腹鼓鼓包")
	sm.data=baseline.duplicate(true)
	calm()
	sm.data[Run.KEY].combat.hp=sm.data[Run.KEY].combat.max_hp-1
	_check(Bento.eat(sm,"health").success and sm.data[Run.KEY].combat.hp==sm.data[Run.KEY].combat.max_hp,"汤不溢出")
	_check(Run.finish(sm,false,Roads.SPAWN).success,"食用后结束探索")
	_check(not Bento.snapshot(sm).slots.has("health") and Bento.snapshot(sm).slots.has("satiety"),"已食清除，未食跨趟保留")
	# 实际迷宫便当按钮和鼠标食用，显示已食状态并恢复移动。
	sm.data=baseline.duplicate(true)
	sm.data[Run.KEY].combat.hp=1.0
	var food:=Run.Progression.satiety_snapshot(sm)
	for member in sm.data[Run.KEY].members: food.values[member.id]=0.0
	Run.Progression.store_satiety(sm,food,true)
	sm.data[Run.KEY].satiety=0.0
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.set_process(false)
	calm()
	await _click(maze.bento_entry)
	_check(maze.bento_modal.visible and maze.player.input_locked,"探索实际便当入口")
	await _click(maze.bento_modal.all_button)
	_check(Bento.snapshot(sm).slots.health.eaten and Bento.snapshot(sm).slots.satiety.eaten,"鼠标全吃真实状态")
	await _capture_image("eaten_both")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked,"关闭食用页恢复输入")
