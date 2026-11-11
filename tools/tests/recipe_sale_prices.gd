extends "res://tools/tests/b03_final.gd"
const EXPECTED={"cool_slime_jelly":15,"salt_crust_silverfish":25,"thunder_eel_roll":35,"frog_soup":25,"wind_frog_bread":25}
const ALL_PRICES={"truffle_beetle_legs":35,"jade_lily_silverfish":40,"bird_nest_crab":45,"frog_soup":25,"wind_frog_bread":25,"mimic_crab_gratin":30,"scorpion_lotus_fritters":30,"cool_slime_jelly":15,"salt_crust_silverfish":25,"thunder_eel_roll":35,"slime_candy":10,"brick_snail_sashimi":20,"lizard_tail_skewer":40,"salt_grilled_rockmane":20}
func _run() -> void:
 sm=get_node("/root/SaveManager");tm=get_node("/root/TutorialManager")
 _check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_b03_isolated","双重隔离正式存档")
 if failures:get_tree().quit(1);return
 _check(Recipes.recipe_ids().size()==ALL_PRICES.size(),"盘点全部14道料理")
 for id in ALL_PRICES:
  _check(Recipes.order_gold(id)==ALL_PRICES[id] and not Recipes.get_recipe(id).has("exploration_category"),"有效售价与普通料理 "+id)
 for kind in ["slime","silverfish","thunder_eel"]:
  _capture_unlock(kind)
 if _arg("--mode=")=="book":
  await _sell_recipe("cool_slime_jelly")
 else:
  for id in EXPECTED:
   await _sell_recipe(id)
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"sales":battles,"user_dir":OS.get_user_data_dir(),"save_path":sm._active_save_path,"fixture":"经营使用已解锁配方和一份食材；另用已击败目标夹具验证捕获事务解锁，不冒充战斗或采集耗时"},"\t"))
 get_tree().quit(1 if failures else 0)

func _sell_recipe(recipe_id: String) -> void:
 _new_run(TEAMS.story,10,1,20110)
 _check(Run.finish(sm,true,preload("res://data/maze/settlement_exit.gd").FRONT).success,"建立返店前置")
 var day=preload("res://scripts/restaurant/restaurant_day.gd")
 while not day.pending_loot(sm).is_empty():day.acknowledge_loot(sm)
 sm.data.restaurant_arrival_lesson_v1={"phase":"done"}
 sm.data.ganlu_lessons_v1={"warm":true,"iced":true,"spoiled":true,"ready":true}
 sm.data[sm.YUFENG_SALIA_KEY]=preload("res://scripts/maze/yufeng_salia_story.gd").fresh("done")
 sm.data.unlocked_recipe_ids=[sm.FIRST_ORDER_ITEM_ID,recipe_id]
 sm.data.warehouse_stock=Recipes.get_recipe(recipe_id).ingredients.duplicate(true)
 sm.data.gold=0
 _check(sm._active_save_path.begins_with("user://") and _verify_isolation(),"每轮写入隔离路径",{"path":sm._active_save_path,"user_dir":OS.get_user_data_dir()})
 _check(sm.save(),"保存一份原料测试前置")
 var planned_menu: Dictionary={recipe_id:1}
 var supply: Dictionary={"recipe":recipe_id}
 battles.append(supply)
 var start:=Time.get_ticks_msec()
 var level:=0
 scene=load("res://scenes/restaurant_map_2d.tscn").instantiate()
 get_tree().root.add_child(scene);get_tree().current_scene=scene
 await get_tree().create_timer(0.8).timeout
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 var player=scene.get_node("Player")
 await _shot_b03(recipe_id+"_supply_return")
 if is_instance_valid(hud.return_loot) and hud.return_loot.visible:
  await _click(hud.return_loot._confirm_button)
  await get_tree().create_timer(0.6).timeout
 if recipe_id=="cool_slime_jelly":
  sm.data.unlocked_recipe_ids=Recipes.recipe_ids()
  await _click(hud._recipe_entry)
  _check(hud._recipe_book.visible and hud._recipe_book.rows.size()==14,"食谱页显示全部14道料理")
  await _shot_b03("all_recipe_prices")
  hud._recipe_book.scroll.scroll_vertical=1120
  await get_tree().process_frame
  await _shot_b03("restored_recipe_prices")
  await _click(hud._recipe_book.close_button)
  _check(not hud._recipe_book.visible and not player.input_locked,"关闭食谱恢复输入")
  sm.data.unlocked_recipe_ids=[sm.FIRST_ORDER_ITEM_ID,recipe_id]
 hud._open_day_menu()
 await get_tree().create_timer(0.5).timeout
 _check(hud.day_menu.list.has_node("Recipe_"+recipe_id),"库存足够时菜单显示 "+recipe_id)
 await _click(hud.day_menu.list.get_node("Recipe_"+recipe_id+"/RecipeRow/Selected"))
 _check(hud.day_menu.draft==planned_menu,"实际勾选料理 "+recipe_id)
 await _shot_b03(recipe_id+"_supply_menu")
 await _click(hud.day_menu.confirm_button)
 _check(day.snapshot(sm).status=="open","真实菜单按钮开业")
 var serving_start:=Time.get_ticks_msec()
 var ready:=await _wait_ms(func(): return sm.restaurant_customers().front.get("phase")=="front",15000)
 _check(ready,"顾客自然到前台")
 if not ready:return
 for prop in scene.get_node("InteractPoints").get_children():
  if str(prop.get("display_name"))=="前台":player.position=_stand(prop);player.last_valid=player.position;break
 await _send_key(KEY_E)
 ready=await _wait_ms(func(): return not sm.restaurant_customers().seated.is_empty() and sm.restaurant_customers().seated[0].phase=="waiting",15000)
 _check(ready,"真实E接单自然落座")
 if not ready:return
 var order: Dictionary=sm.restaurant_customers().seated[0]
 recipe_id=str(order.item_id)
 _check(planned_menu.has(recipe_id) and order.stage=="food","首份按菜单点菜不强制更改订单阶段",order)
 if order.stage!="food":return
 player.position=_stand(scene.get_node("InteractPoints/Store"));player.last_valid=player.position
 await _send_key(KEY_E)
 var warehouse=scene.get_node("UIOverlay/WarehouseModal")
 _check(warehouse.is_visible_in_tree(),"实际打开仓库")
 for id in Recipes.get_recipe(recipe_id).ingredients:
  await _click(warehouse._slot_by_id[id]._icon_button)
 await _shot_b03(recipe_id+"_supply_warehouse")
 await _click(warehouse._claim_button)
 _check(sm.carried_ingredients()==Recipes.get_recipe(recipe_id).ingredients,"真实点击领取捕获和任务原料")
 player.position=_stand(scene.get_node("InteractPoints/Cauldron"));player.last_valid=player.position
 await _send_key(KEY_E)
 var cooking=scene.get_node("HUD/CookingModal")
 _check(cooking.visible,"真实打开烹饪")
 await _click(cooking._start_button)
 var deadline:=Time.get_ticks_msec()+12000
 while Time.get_ticks_msec()<deadline and not cooking._finished:
  if cooking._finish_button.is_visible_in_tree() and not cooking._finish_button.disabled:await _click(cooking._finish_button)
  await get_tree().process_frame
 _check(cooking._finished and sm.carried_dish_count()==1,"真实QTE获得一份料理")
 await _shot_b03(recipe_id+"_supply_cooked")
 if cooking._finished:
  await _wait_ms(func(): return cooking._result_popup.is_visible_in_tree() and not cooking._result_popup._confirm_button.disabled,5000)
  await _click(cooking._result_popup._confirm_button)
 player.position=preload("res://scripts/restaurant/three_seat_layout.gd").service_point(int(order.seat));player.last_valid=player.position
 await get_tree().create_timer(0.2).timeout
 if level==15:_loss_branch(supply,recipe_id)
 _failed_transaction(func(): return preload("res://scripts/restaurant/service_cycle.gd").deliver_food(sm,str(order.id)),"交单")
 await _send_key(KEY_E)
 _check(sm.restaurant_customer_order(order.id).get("outcome")=="served","真实交付料理获得收入")
 _repeat_transaction(func(): return preload("res://scripts/restaurant/service_cycle.gd").deliver_food(sm,str(order.id)),"交单")
 _failed_transaction(func(): return preload("res://scripts/restaurant/service_cycle.gd").settle(sm,"manual"),"日结")
 ready=await _wait_ms(func(): return day.snapshot(sm).has("settlement"),20000)
 _check(ready,"正常服务自然售尽结算")
 if ready:_repeat_transaction(func(): return preload("res://scripts/restaurant/service_cycle.gd").settle(sm,"manual"),"日结")
 await get_tree().create_timer(0.5).timeout
 await _shot_b03(recipe_id+"_supply_settlement")
 supply.merge({"service_run":true,"serving_seconds":float(Time.get_ticks_msec()-serving_start)/1000,"total_seconds":float(Time.get_ticks_msec()-start)/1000,"day":day.snapshot(sm),"gold":sm.gold_balance(),"reputation":sm.reputation(),"warehouse_final":sm.warehouse_snapshot(),"receipts":sm.data.get("restaurant_order_receipts",{})},true)
 _check(sm.gold_balance()==EXPECTED[recipe_id],"每份售价实际入账 "+recipe_id,supply)
 for item in Recipes.get_recipe(recipe_id).ingredients:
  _check(sm.warehouse_snapshot().get(item,0)==0,"只扣除本份原料 "+item)
 if not day.snapshot(sm).has("settlement"):return
 _economic_attempts(supply,level)
 var expected_settlement: Dictionary=day.snapshot(sm).settlement.duplicate(true)
 sm.save();sm.load_data()
 _check(sm.gold_balance()==supply.gold and day.snapshot(sm).get("settlement",{}).get("income")==expected_settlement.income and day.snapshot(sm).get("settlement",{}).get("menu_sold")==1,"实际结算读档保持",{"after":day.snapshot(sm),"load_error":sm.last_load_error})
 await _wait_ms(func(): return is_instance_valid(hud.day_settlement) and not hud.day_settlement._confirm_button.disabled,10000)
 await _wait_ms(func(): return hud.day_settlement.chart.line_progress>=1.0,3000)
 await _shot_b03(recipe_id+"_supply_settlement_ready")
 await _click(hud.day_settlement._confirm_button)
 _check(day.snapshot(sm).get("day")==2 and day.snapshot(sm).get("status")=="preparing","真实点击明日准备进入第二天")
 supply["next_day"]=day.snapshot(sm)
 await _shot_b03(recipe_id+"_supply_next_day")
 scene.queue_free();await get_tree().process_frame

func _capture_unlock(kind: String) -> void:
 _new_run(TEAMS.story,10,1,20110)
 sm.data.unlocked_recipe_ids=[]
 var region: String="maze_entry" if kind=="slime" else "fenshui"
 if region!="maze_entry":_check(Run.change_region(sm,region,Combat.terrain(region).SPAWN).success,"解锁测试跨区")
 var run:=Run.snapshot(sm)
 var target: Dictionary={}
 for row in Run.monsters_for(run):
  if row.kind==kind:target=row;break
 _check(not target.is_empty(),"对应魔物存在 "+kind)
 if target.is_empty():return
 var recipe_id: String={"slime":"cool_slime_jelly","silverfish":"salt_crust_silverfish","thunder_eel":"thunder_eel_roll"}[kind]
 _check(recipe_id not in sm.unlocked_recipe_ids(),"捕获前未解锁 "+kind)
 # 已击败、捕获随机值为成功的事务夹具；不覆盖生产属性或捕获概率。
 run.combat.actors[target.id].hp=0
 run.monsters[target.id].capture_roll=0.0
 sm.data[Run.KEY]=run
 _check(Run.defeat(sm,target.id,Combat.terrain(region).SPAWN).success,"击败进入捕获选择 "+kind)
 _check(recipe_id not in sm.unlocked_recipe_ids(),"仅击败不解锁 "+kind)
 var pending: Dictionary=sm.data.duplicate(true)
 _check(Run.resolve(sm,target.id,false).success and recipe_id not in sm.unlocked_recipe_ids(),"放弃捕获不解锁 "+kind)
 sm.data=pending;sm.save()
 var path: String=sm._active_save_path
 sm._active_save_path=""
 _check(not Run.resolve(sm,target.id,true).success and sm.data==pending,"捕获保存失败回滚食谱与掉落 "+kind)
 sm._active_save_path=path
 var result:=Run.resolve(sm,target.id,true)
 _check(result.success and recipe_id in sm.unlocked_recipe_ids(),"成功捕获解锁 "+kind,result)
 var after: Dictionary=sm.data.duplicate(true)
 _check(not Run.resolve(sm,target.id,true).success and sm.data==after,"重复捕获不重复解锁发料 "+kind)
 sm.load_data()
 _check(recipe_id in sm.unlocked_recipe_ids() and sm.data[sm.UNLOCKED_RECIPES_KEY].count(recipe_id)==1,"读档保留唯一食谱 "+kind)
