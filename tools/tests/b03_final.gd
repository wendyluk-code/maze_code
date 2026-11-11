extends "res://b03_tests/b03_baseline.gd"
const EXPECT={"slime":[14,3,20],"snail":[28,5,35],"beetle":[21,4,35],"lizard":[84,8,150],"silverfish":[20,4,25],"thunder_eel":[30,5,40],"wind_frog":[96,6,120],"mimic_crab":[28,5,35],"blind_scorpion":[22,4,30],"rockmane":[120,8,150]}
func _run() -> void:
 sm=get_node("/root/SaveManager");tm=get_node("/root/TutorialManager")
 _check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_b03_isolated","最终B03双重隔离")
 if failures:get_tree().quit(1);return
 for kind in EXPECT:
  _check(Combat.STATS[kind].hp==EXPECT[kind][0] and Combat.STATS[kind].attack==EXPECT[kind][1] and Combat.Balance.EXPERIENCE[kind]==EXPECT[kind][2],"批准数值 "+kind)
 for team in TEAMS:
  for level in [1,5,10,15]:
   for rank in [1,6]:
    var run:=_new_run(TEAMS[team],level,rank)
    if run.is_empty():continue
    var actives: Array=[]
    for id in TEAMS[team]:
     var skill:=Growth.active_skill(id,level)
     actives.append({"id":id,"attack":Growth.record(sm,id).attack,"interval":skill.interval,"level_multiplier":skill.multiplier,"passive":id in ["ahong","chengyan"]})
    samples.append({"team":team,"members":TEAMS[team],"level":level,"rank":rank,"team_attack":run.combat.attack,"team_hp":run.combat.max_hp,"defense":Skills.defense(run),"incoming_3":Skills.incoming_damage(run,3),"incoming_6":Skills.incoming_damage(run,6),"incoming_8":Skills.incoming_damage(run,8),"food":run.satiety,"actives":actives})

 if _arg("--mode=")=="regional":
  for team in TEAMS:
   for region in ["maze_entry","fenshui","salt_pool"]:
    for kind in {"maze_entry":["beetle","lizard"],"fenshui":["silverfish","wind_frog"],"salt_pool":["mimic_crab","rockmane"]}[region]:
     _final_battle(team,region,kind,{"maze_entry":5,"fenshui":10,"salt_pool":15}[region])
 if _arg("--mode=")=="transactions":
  _xp_transactions()
  _thresholds()
 if _arg("--mode=") in ["supply10","supply15"]:await _region_supply(10 if _arg("--mode=")=="supply10" else 15)
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples,"battles":battles,"user_dir":OS.get_user_data_dir()},"\t"))
 get_tree().quit(1 if failures else 0)

func _point_for(target: Dictionary, region: String) -> Vector2:
 for radius in [70.0,110.0,150.0,190.0]:
  for index in 32:
   var candidate: Vector2=target.position+Vector2.RIGHT.rotated(TAU*index/32)*radius
   if Combat.terrain(region).is_walkable(candidate) and Skills.Tide.visible_line(candidate,target.position,region):return candidate
 return Vector2.INF

func _final_battle(team: String, region: String, kind: String, level: int) -> void:
 _new_run(TEAMS[team],level,1)
 if region!="maze_entry":_check(Run.change_region(sm,region,Combat.terrain(region).SPAWN).success,"真实区域事务 "+region)
 var run:=Run.snapshot(sm)
 sm.data[sm.YUFENG_SALIA_KEY]=preload("res://scripts/maze/yufeng_salia_story.gd").fresh("done")
 # Boss已解锁的剧情检查点，不改生命、攻击或其他怪物。
 run.combat.frog_unlocked=true
 var target: Dictionary={}
 for row in Run.monsters_for(run):
  if row.kind==kind:target=row;break
 var point:=_point_for(target,region)
 _check(point.is_finite(),"合法站位 "+team+kind)
 if not point.is_finite():return
 run.combat.hero=Combat.pack(point)
 sm.data[Run.KEY]=run
 sm.data[sm.MAZE_STATE_KEY].position=Combat.pack(point)
 var slot:=1
 for i in TEAMS[team].size():
  if TEAMS[team][i] not in ["ahong","chengyan"]:slot=i+1;break
 Run.combat_command(sm,"select",slot)
 var initial: float=run.combat.hp
 var elapsed:=0.0
 var transaction_failure: Dictionary={}
 while elapsed<60:
  run=Run.snapshot(sm)
  if run.combat.hp<=0 or run.combat.actors[target.id].hp<=0:break
  point=Combat.vec(run.combat.hero)
  var aim:=point.direction_to(Combat.vec(run.combat.actors[target.id].position))
  Run.combat_attack(sm,point,Vector2.RIGHT if aim.is_zero_approx() else aim)
  var advanced:=Run.combat_tick(sm,point,1.0/30.0)
  if not advanced.success:transaction_failure=advanced;break
  elapsed+=1.0/30.0
 run=Run.snapshot(sm)
 _check(transaction_failure.is_empty() and Combat.valid(run.combat),"区域战斗事务合法 "+team+kind,transaction_failure)
 var killed: bool=run.combat.actors[target.id].hp<=0
 _check(not killed or run.combat.hp<=0 or run.monsters[target.id].get("experience_generation",-1)==run.monsters[target.id].refresh_count,"击杀实际经验代回执 "+team+kind)
 battles.append({"team":team,"region":region,"kind":kind,"level":level,"seconds":elapsed,"killed":killed,"dead":run.combat.hp<=0,"hp_lost":initial-run.combat.hp,"target_hp":run.combat.actors[target.id].hp,"experience_generation":run.monsters[target.id].get("experience_generation",-1),"growth":sm.data[Growth.KEY].duplicate(true),"throws":run.combat.throws,"hits":run.combat.hits,"policy":"一星第一主动角色原地攻击，生产Run.combat_tick，60模拟秒上限，其他怪物保留；Boss解锁为剧情前置"})
 print("B03_FINAL ",team," ",region," ",kind," ",elapsed)

func _region_supply(level: int) -> void:
 var region: String="fenshui" if level==10 else "salt_pool"
 var sample_seed:=20110 if level==10 else 20115
 _new_run(TEAMS.story,level,1,sample_seed)
 sm.data.restaurant_arrival_lesson_v1={"phase":"done"}
 sm.data.ganlu_lessons_v1={"warm":true,"iced":true,"spoiled":true,"ready":true}
 var start:=Time.get_ticks_msec()
 var gift: Dictionary={}
 if level==10:
  sm.data[sm.YUFENG_SALIA_KEY]=preload("res://scripts/maze/yufeng_salia_story.gd").fresh("gift_pending")
  gift=preload("res://scripts/restaurant/yufeng_ingredient_gift.gd").grant(sm)
  _check(gift.success,"御风生产赠礼",gift)
 else:sm.data.unlocked_recipe_ids=["mimic_crab_gratin"]
 sm.data[sm.YUFENG_SALIA_KEY]=preload("res://scripts/maze/yufeng_salia_story.gd").fresh("done")
 _check(Run.change_region(sm,region,Combat.terrain(region).SPAWN).success,"供给跨区")
 if level==15:
  var plant: Dictionary=preload("res://data/maze/region_resources.gd").all(region)[0]
  var harvested: Dictionary=sm.claim_exploration_dig_site(plant.id,_regional_near(plant.position,region))
  _check(harvested.success,"灯笼果生产采集",harvested)
 sm.save()
 var maze=load("res://scenes/maze_fenshui.tscn" if level==10 else "res://scenes/maze_salt_pool.tscn").instantiate()
 get_tree().root.add_child(maze);get_tree().current_scene=maze
 await get_tree().create_timer(0.8).timeout
 var attempts: Array=[]
 var recipe_id: String=""
 var planned_menu: Dictionary={}
 for row in Run.monsters_for(Run.snapshot(sm)):
  if row.kind!=("silverfish" if level==10 else "mimic_crab"):continue
  var live:=Run.snapshot(sm)
  if live.monsters[row.id].status not in ["alive","idle"]:continue
  var point:=_point_for(row,region)
  if not point.is_finite():continue
  maze.player.position=point
  await get_tree().process_frame
  await _send_key(KEY_1)
  var flow=maze.capture_flow
  flow.window_focused=true
  var stop:=Time.get_ticks_msec()+60000
  while Time.get_ticks_msec()<stop and not flow.dialog.visible and not flow.attempt.visible:
   await _mouse_at(maze.get_viewport().get_canvas_transform()*Combat.vec(Run.snapshot(sm).combat.actors[row.id].position))
   await get_tree().create_timer(0.12).timeout
  if flow.dialog.visible:
   await get_tree().create_timer(0.6).timeout
   await _click(flow.dialog._confirm_button)
   await get_tree().create_timer(0.4).timeout
  if flow.attempt.visible and flow.attempt.mode=="ready":
   await _click(flow.attempt.yes_button)
   stop=Time.get_ticks_msec()+(35000 if level==10 else 16000)
   while Time.get_ticks_msec()<stop and flow.attempt.visible:
    if level==10:
     flow.attempt.audio_focused=true
     flow.window_focused=true
    if flow.attempt.mode=="suppress" and flow.attempt.pressure<0.93:await _send_key(KEY_J)
    await get_tree().process_frame
  await get_tree().create_timer(0.8).timeout
  attempts.append({"target":row.id,"status":Run.snapshot(sm).monsters[row.id].status,"satiety":Run.snapshot(sm).satiety,"bag":Run.snapshot(sm).bag.duplicate(true)})
  await _shot_b03("supply_capture_"+str(attempts.size()))
  await get_tree().create_timer(0.7).timeout
  if flow.reward.visible:await _click(flow.reward._confirm_button)
  elif flow.dialog.visible:await _click(flow.dialog._confirm_button)
  await get_tree().create_timer(0.3).timeout
  var available: Dictionary=sm.warehouse_snapshot()
  for id in Run.snapshot(sm).bag:available[id]=int(available.get(id,0))+int(Run.snapshot(sm).bag[id])
  for id in ["jade_lily_silverfish" if level==10 else "mimic_crab_gratin"]:
   if Recipes.can_cook(id,available):recipe_id=id;break
  if not recipe_id.is_empty():planned_menu={recipe_id:1};break
  if attempts.size()>=4:break
 _check(not recipe_id.is_empty(),"固定新种子正常捕获获得可营业配方",{"attempts":attempts,"stock":sm.warehouse_snapshot()})
 var flow=maze.capture_flow
 maze.player.position=Combat.terrain(region).ENTRANCE
 await get_tree().create_timer(3.5).timeout
 var exit_stop:=Time.get_ticks_msec()+15000
 while Run.portal_combat_locked(sm) and Time.get_ticks_msec()<exit_stop:
  var live:=Run.snapshot(sm)
  for id in live.combat.actors:
   if live.combat.actors[id].hp>0 and live.combat.actors[id].mode in ["chase","windup"]:
    await _mouse_at(maze.get_viewport().get_canvas_transform()*Combat.vec(live.combat.actors[id].position));break
  if flow.dialog.visible:
   await get_tree().create_timer(0.6).timeout
   await _click(flow.dialog._cancel_button)
  await get_tree().create_timer(0.15).timeout
 _failed_transaction(func(): return Run.finish(sm,true,maze.player.position),"返店")
 var returned:=Run.finish(sm,true,maze.player.position)
 _check(returned.success,"正样本真实返店",returned)
 if returned.success:_repeat_transaction(func(): return Run.finish(sm,true,maze.player.position),"返店")
 maze.queue_free();await get_tree().process_frame
 var supply: Dictionary={"sample":"regional_supply","level":level,"seed":sample_seed,"initial_pantry":{},"initial_gold":0,"gift":gift,"attempts":attempts,"warehouse_returned":sm.warehouse_snapshot(),"planned_menu":planned_menu,"recipe":recipe_id,"service_run":false,"limitations":"剧情和收录配方为前置初始化，位置为合法检查点；原料全由生产事务获得"}
 battles.append(supply)
 if recipe_id.is_empty() or not returned.success:return
 scene=load("res://scenes/restaurant_map_2d.tscn").instantiate()
 get_tree().root.add_child(scene);get_tree().current_scene=scene
 await get_tree().create_timer(0.8).timeout
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 var player=scene.get_node("Player")
 await _shot_b03("supply_return")
 if is_instance_valid(hud.return_loot) and hud.return_loot.visible:
  await _click(hud.return_loot._confirm_button)
  await get_tree().create_timer(0.6).timeout
 hud._open_day_menu()
 await get_tree().create_timer(0.5).timeout
 hud.day_menu.draft=planned_menu.duplicate()
 hud.day_menu._rebuild()
 await _shot_b03("supply_menu")
 await _click(hud.day_menu.confirm_button)
 var day=preload("res://scripts/restaurant/restaurant_day.gd")
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
 await _shot_b03("supply_warehouse")
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
 await _shot_b03("supply_cooked")
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
 await _shot_b03("supply_settlement")
 supply.merge({"service_run":true,"serving_seconds":float(Time.get_ticks_msec()-serving_start)/1000,"total_seconds":float(Time.get_ticks_msec()-start)/1000,"day":day.snapshot(sm),"gold":sm.gold_balance(),"reputation":sm.reputation(),"warehouse_final":sm.warehouse_snapshot(),"receipts":sm.data.get("restaurant_order_receipts",{})},true)
 _check(sm.gold_balance()>0,"零初始金币实际正收入")
 if not day.snapshot(sm).has("settlement"):return
 _economic_attempts(supply,level)
 var expected_settlement: Dictionary=day.snapshot(sm).settlement.duplicate(true)
 sm.save();sm.load_data()
 _check(sm.gold_balance()==supply.gold and day.snapshot(sm).get("settlement",{}).get("income")==expected_settlement.income and day.snapshot(sm).get("settlement",{}).get("menu_sold")==1,"实际结算读档保持",{"after":day.snapshot(sm),"load_error":sm.last_load_error})
 await _wait_ms(func(): return is_instance_valid(hud.day_settlement) and not hud.day_settlement._confirm_button.disabled,10000)
 await _wait_ms(func(): return hud.day_settlement.chart.line_progress>=1.0,3000)
 await _shot_b03("supply_settlement_ready")
 await _click(hud.day_settlement._confirm_button)
 _check(day.snapshot(sm).get("day")==2 and day.snapshot(sm).get("status")=="preparing","真实点击明日准备进入第二天")
 supply["next_day"]=day.snapshot(sm)
 await _shot_b03("supply_next_day")
 scene.queue_free();await get_tree().process_frame

func _regional_near(point: Vector2, region: String) -> Vector2:
 for distance in range(0,52):
  for angle in range(0,360,10):
   var candidate:=point+Vector2.RIGHT.rotated(deg_to_rad(angle))*distance
   if Combat.terrain(region).is_walkable(candidate):return candidate
 return point

func _failed_transaction(action: Callable, label: String) -> void:
 _check(sm.save(),label+"故障前真实保存检查点")
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var result: Dictionary=action.call()
 sm._active_save_path=path
 _check(not result.success and result.get("reason")=="save_failed" and sm.data==before,label+"保存失败原子回滚",result)
 sm.load_data()
 _check(_same_business(sm.data,before),label+"保存失败后专门读档保持业务状态",{"load_error":sm.last_load_error})

func _economic_attempts(supply: Dictionary, level: int) -> void:
 var before: Dictionary=sm.data.duplicate(true)
 var single:=preload("res://scripts/characters/recruitment.gd").draw(sm,1)
 var ten:=preload("res://scripts/characters/recruitment.gd").draw(sm,10)
 var breakthrough:=Growth.breakthrough(sm,"yaya")
 supply["spending"]={"single":single,"ten":ten,"breakthrough":breakthrough,"level":level,"gold":sm.gold_balance()}
 _check(not single.success and not ten.success and not breakthrough.success and sm.data==before,"实际余额不足消费拒绝",supply.spending)

func _xp_transactions() -> void:
 for kind in EXPECT:
  var run:=_new_run(TEAMS.story,11,1)
  var region: String="maze_entry" if kind in ["slime","snail","beetle","lizard"] else ("fenshui" if kind in ["silverfish","thunder_eel","wind_frog"] else "salt_pool")
  if region!="maze_entry":
   _check(Run.change_region(sm,region,Combat.terrain(region).SPAWN).success,"经验样本真实跨区 "+kind)
  run=Run.snapshot(sm)
  var target: Dictionary={}
  for row in Run.monsters_for(run):
   if row.kind==kind:target=row;break
  var point: Vector2=Combat.terrain(region).SPAWN
  for radius in [40.0,70.0,100.0]:
   var found:=false
   for index in 32:
    var candidate: Vector2=target.position+Vector2.RIGHT.rotated(TAU*index/32)*radius
    if Combat.terrain(region).is_walkable(candidate):point=candidate;found=true;break
   if found:break
  # 事务夹具仅把目标置为最后1点生命；不作为平衡耗时样本。
  for id in run.monsters:run.monsters[id].status="skipped"
  run.monsters[target.id].status="alive"
  run.combat.actors[target.id].hp=1
  if kind=="wind_frog":
   run.combat.actors[target.id].frog_phase="warning"
   run.combat.actors[target.id].frog_left=1.0
  run.combat.hero=Combat.pack(point)
  Skills.Tide.open(run,target.position,1,10,Vector2.RIGHT)
  sm.data[Run.KEY]=run
  sm.data[sm.MAZE_STATE_KEY].position=Combat.pack(point)
  var path: String=sm._active_save_path
  var before: Dictionary=sm.data.duplicate(true)
  sm._active_save_path=""
  var failed:=Run.combat_tick(sm,point,0.01)
  _check(not failed.success and sm.data==before,"经验与致死事务保存失败回滚 "+kind)
  sm._active_save_path=path
  var result:=Run.combat_tick(sm,point,0.01)
  _check(result.success and Run.snapshot(sm).combat.actors[target.id].hp<=0,"实际致死推进 "+kind,result)
  for id in TEAMS.story:
   _check(Growth.record(sm,id).exp==EXPECT[kind][2],"每名队员批准经验 "+kind+" "+id,{"actual":Growth.record(sm,id).exp})
  _check(Run.combat_tick(sm,point,0.01).success,"重复推进成功 "+kind)
  for id in TEAMS.story:_check(Growth.record(sm,id).exp==EXPECT[kind][2],"同生命只发一次 "+kind+" "+id)
  _check(sm.save(),"经验保存 "+kind)
  sm.load_data()
  _check(Run.snapshot(sm).monsters[target.id].get("experience_generation",-1)==0 and Growth.record(sm,"yaya").exp==EXPECT[kind][2],"经验与回执读档一致 "+kind)

func _thresholds() -> void:
 for level in [4,9,14]:
  _new_run(TEAMS.story,level,1)
  var amount:=Growth.experience_required(level)+Growth.experience_required(level+1)+123
  _check(Growth.grant_experience(sm,TEAMS.story,amount).success,"临界真实经验事务 "+str(level))
  for id in TEAMS.story:
   var current:=Growth.record(sm,id)
   _check(current.level==level+1 and current.exp==0 and current.needs_breakthrough,"突破卡口停止且不残留溢出 "+id+str(level))
  sm.save();sm.load_data()
  _check(Growth.record(sm,"yaya").level==level+1 and Growth.record(sm,"yaya").exp==0,"卡口经验读档稳定")

func _same_business(a: Dictionary,b: Dictionary) -> bool:
 for key in ["gold","reputation","warehouse_stock",sm.INVENTORY_KEY,sm.PREPARED_DISHES_KEY,sm.COOKING_STATE_KEY,Run.KEY,Growth.KEY,"restaurant_day_v1","restaurant_customers","restaurant_order_receipts"]:
  if JSON.parse_string(JSON.stringify(a.get(key)))!=JSON.parse_string(JSON.stringify(b.get(key))):return false
 return true

func _repeat_transaction(action: Callable,label: String) -> void:
 var before: Dictionary=sm.data.duplicate(true)
 var result: Dictionary=action.call()
 _check(_same_business(sm.data,before),label+"成功后重复事务不重复收益或扣料",result)
 _check(sm.save(),label+"重复后保存")
 sm.load_data()
 _check(_same_business(sm.data,before),label+"重复后读档仍幂等",{"load_error":sm.last_load_error})

func _loss_branch(supply: Dictionary,recipe_id: String) -> void:
 # 从实际捕获/采集并烹饪得到的成品分叉；独立存档，不注入物品。
 var original: Dictionary=sm.data.duplicate(true)
 var original_path: String=sm._active_save_path
 sm._active_save_path="user://b03-nonzero-loss-branch.json"
 _check(sm.carried_dish_count()==1 and sm.save(),"非零损耗分支以真实成品建立独立存档")
 var cycle=preload("res://scripts/restaurant/service_cycle.gd")
 var day=preload("res://scripts/restaurant/restaurant_day.gd")
 _failed_transaction(func(): return cycle.settle(sm,"manual"),"非零损耗日结")
 var result: Dictionary=cycle.settle(sm,"manual")
 var stats: Dictionary=day.snapshot(sm).get("settlement",{})
 _check(result.success and int(stats.get("menu_lost",0))==1 and int(stats.get("losses",{}).get(recipe_id,0))==1 and sm.carried_dish_count()==0,"分支实际损耗一份成品且扣除一次",{"result":result,"stats":stats})
 _repeat_transaction(func(): return cycle.settle(sm,"manual"),"非零损耗日结")
 supply["loss_transaction_branch"]={"source":"本次实际料理在交单前的隔离副本，不是营业收益样本","settlement":day.snapshot(sm).get("settlement",{}),"remaining_dishes":sm.carried_dish_count(),"save_path":sm._active_save_path}
 sm._active_save_path=original_path
 sm.data=original
 _check(sm.save(),"恢复原供给样本继续真实交单")
