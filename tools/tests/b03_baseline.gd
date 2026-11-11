extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Combat=preload("res://scripts/maze/combat_simulation.gd")
const Skills=preload("res://scripts/maze/team_attack.gd")
const Growth=preload("res://scripts/characters/character_progression.gd")
const Recipes=preload("res://scripts/cooking/recipe_catalog.gd")
const TEAMS={"story":["yaya","tieshan","yufeng","salia"],"rare":["yaya","dingdang","ahong","lanjiao"],"passive":["ahong","chengyan","yaya","tieshan"],"output":["salia","xiluomei","yufeng","jiaopopo"]}
var samples: Array=[]
var battles: Array=[]
func _run() -> void:
 sm=get_node("/root/SaveManager");tm=get_node("/root/TutorialManager")
 _check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_b03_isolated","双重隔离")
 if failures: get_tree().quit(1);return
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
 if _arg("--mode=")=="combat":
  for team in TEAMS:
   for kind in ["slime","lizard"]:
    _battle(team,kind)
 if _arg("--mode=")=="economy":await _early_resource()
 if _arg("--mode=")=="supply":await _positive_supply()
 if _arg("--mode=")=="long_service":await _positive_supply(true)
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples,"battles":battles,"user_dir":OS.get_user_data_dir(),"status":"B02待确认的当前基线，不是最终平衡验收","limitations":["角色等级星级是合法样本初始化，不代表实测养成过程","战斗为生产模拟器脚本策略，未统计玩家平均表现","仅supply模式覆盖早期单份售尽经营闭环，最终数值版本尚未验证"]},"\t"))
 get_tree().quit(1 if failures else 0)
func _new_run(ids: Array,level: int,rank: int,random_seed: int=7319) -> Dictionary:
 seed(random_seed)
 _completed();tm.active=false
 sm.data["first_exploration_gate_v1"]="done"
 sm.data[Run.SEEN]=true
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 sm.data["owned_characters_v1"]=ids.duplicate()
 sm.data[Growth.KEY]={}
 for id in ids:sm.data[Growth.KEY][id]={"level":level,"exp":0,"rank":rank,"breakthroughs":floori(float(level-1)/5)}
 sm.data["warehouse_stock"]={}
 sm.data.gold=0
 sm.cancel_maze_entry()
 _check(sm.request_maze_entry(ids).success,"真实编队 "+str(ids)+" L"+str(level)+" R"+str(rank))
 var result:=Run.begin(sm,Roads.SPAWN)
 _check(result.success,"真实出发计算属性",result)
 if not result.success:return {}
 var run:=Run.snapshot(sm)
 _check(Run.valid(run),"生产状态校验")
 return run
func _battle(team: String,kind: String) -> void:
 var run:=_new_run(TEAMS[team],5,1)
 if run.is_empty():return
 var target: Dictionary={}
 for row in Run.monsters_for(run):
  if row.kind==kind:target=row;break
 if target.is_empty():
  _check(false,"目标存在 "+kind);return
 var point: Vector2=target.position
 var placed:=false
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  var candidate: Vector2=target.position+direction*70
  if Roads.is_walkable(candidate) and Skills.Tide.visible_line(candidate,target.position,"maze_entry"):
   point=candidate;placed=true;break
 _check(placed,"合法战斗起点 "+team+kind)
 if not placed:return
 run.combat.hero=Combat.pack(point)
 var slot:=1
 for index in TEAMS[team].size():
  if TEAMS[team][index] not in ["ahong","chengyan"]:slot=index+1;break
 Skills.select(run,slot)
 var initial_hp: float=run.combat.hp
 var elapsed:=0.0
 var wall_start:=Time.get_ticks_msec()
 while elapsed<60 and run.combat.hp>0 and run.combat.actors[target.id].hp>0:
  point=Combat.vec(run.combat.hero)
  var at:=Combat.vec(run.combat.actors[target.id].position)
  var direction:=point.direction_to(at)
  if direction.is_zero_approx():direction=Vector2.RIGHT
  Skills.attack(run,point,direction)
  # 所有敌人保留生产状态；固定站位策略，不伪造命中或击杀。
  Combat.advance(run,point,1.0/60.0)
  elapsed+=1.0/60.0
 battles.append({"team":team,"level":5,"rank":1,"target":target.id,"kind":kind,"start_position":str(point),"seconds":elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_start)/1000,"killed":run.combat.actors[target.id].hp<=0,"player_dead":run.combat.hp<=0,"hp_lost":initial_hp-run.combat.hp,"target_remaining":run.combat.actors[target.id].hp,"throws":run.combat.throws,"hits":run.combat.hits,"policy":"选择第一个主动角色、原地朝目标持续攻击；生产模拟时间60秒封顶；无属性覆盖"})
 _check(Combat.valid(run.combat),"战斗结束状态合法 "+team+kind)


func _early_resource() -> void:
 var run:=_new_run(TEAMS.story,5,1)
 if run.is_empty():return
 var row: Dictionary={}
 for entry in Run.monsters_for(run):
  if entry.kind=="slime":row=entry;break
 var point: Vector2=row.position
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  var candidate: Vector2=row.position+direction*70
  if Roads.is_walkable(candidate) and Skills.Tide.visible_line(candidate,row.position,"maze_entry"):
   point=candidate;break
 # 有界场景样本从合法战斗站位开始，不伪装成整段行走路线。
 sm.data[sm.MAZE_STATE_KEY].position=Combat.pack(point)
 sm.data[Run.KEY].combat.hero=Combat.pack(point)
 sm.save()
 var maze=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze);get_tree().current_scene=maze
 await get_tree().create_timer(0.8).timeout
 var flow=maze.capture_flow
 var started:=Time.get_ticks_msec()
 await _send_key(KEY_1)
 while Time.get_ticks_msec()-started<20000 and not flow.dialog.visible and not flow.attempt.visible:
  var at:=Combat.vec(Run.snapshot(sm).combat.actors[row.id].position)
  await _mouse_at(maze.get_viewport().get_canvas_transform()*at)
  await get_tree().create_timer(0.12).timeout
 _check(flow.dialog.visible or flow.attempt.visible,"真实场景攻击触发捕获窗")
 if flow.dialog.visible:
  await get_tree().create_timer(0.6).timeout
  await _click(flow.dialog._confirm_button)
  await get_tree().create_timer(0.4).timeout
 _check(flow.attempt.visible and flow.attempt.mode=="ready","捕获确认窗口")
 if flow.attempt.visible and flow.attempt.mode=="ready":
  await _click(flow.attempt.yes_button)
  var stop:=Time.get_ticks_msec()+16000
  while Time.get_ticks_msec()<stop and flow.attempt.visible:
   if flow.attempt.mode=="suppress" and flow.attempt.pressure<0.93:await _send_key(KEY_J)
   await get_tree().process_frame
  await get_tree().create_timer(0.8).timeout
 await _shot_b03("early_capture")
 var outcome: String=str(Run.snapshot(sm).monsters[row.id].status)
 _check(outcome in ["captured","failed"],"真实捕获完成并落盘",{"outcome":outcome})
 await get_tree().create_timer(0.7).timeout
 if flow.reward.visible:await _click(flow.reward._confirm_button)
 elif flow.dialog.visible:await _click(flow.dialog._confirm_button)
 await get_tree().create_timer(0.3).timeout
 var bag: Dictionary=Run.snapshot(sm).bag.duplicate(true)
 var food_after: float=Run.snapshot(sm).satiety
 var exp_after: Dictionary=sm.data[Growth.KEY].duplicate(true)
 # 返程段使用合法出口检查点；不计为真实走图耗时。
 maze.player.position=preload("res://data/maze/settlement_exit.gd").FRONT
 await get_tree().create_timer(3.5).timeout
 var exit_stop:=Time.get_ticks_msec()+15000
 while Run.portal_combat_locked(sm) and Time.get_ticks_msec()<exit_stop:
  var live:=Run.snapshot(sm)
  for id in live.combat.actors:
   if live.combat.actors[id].hp>0 and live.combat.actors[id].mode in ["chase","windup"]:
    await _mouse_at(maze.get_viewport().get_canvas_transform()*Combat.vec(live.combat.actors[id].position))
    break
  if flow.dialog.visible:
   await get_tree().create_timer(0.6).timeout
   await _click(flow.dialog._cancel_button)
  await get_tree().create_timer(0.15).timeout
 var returned:=Run.finish(sm,true,maze.player.position)
 _check(returned.success,"返店真实入库事务",returned)
 maze.queue_free();await get_tree().process_frame
 var stock: Dictionary=sm.warehouse_snapshot()
 var menu: Dictionary={}
 var missing: Dictionary={}
 for id in sm.unlocked_recipe_ids():
  var recipe:=Recipes.get_recipe(id)
  if recipe.is_empty():continue
  if Recipes.can_cook(id,stock):menu[id]=1
  else:
   var gaps: Dictionary={}
   for item in recipe.ingredients:
    var amount:=int(recipe.ingredients[item])-int(stock.get(item,0))
    if amount>0:gaps[item]=amount
   missing[id]=gaps
 var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
 get_tree().root.add_child(restaurant);get_tree().current_scene=restaurant
 await get_tree().create_timer(0.8).timeout
 await _shot_b03("early_return")
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 if is_instance_valid(hud.return_loot) and hud.return_loot.visible:
  await _click(hud.return_loot._confirm_button)
  await get_tree().create_timer(0.5).timeout
 hud._open_day_menu()
 await get_tree().create_timer(0.3).timeout
 _check(hud.day_menu.visible and hud.day_menu.confirm_button.disabled,"真实菜单缺料禁用营业")
 await _shot_b03("early_no_menu")
 var spending_before: Dictionary=sm.data.duplicate(true)
 var single:=preload("res://scripts/characters/recruitment.gd").draw(sm,1)
 var ten:=preload("res://scripts/characters/recruitment.gd").draw(sm,10)
 var breakthrough:=Growth.breakthrough(sm,"yaya")
 _check(not single.success and not ten.success and not breakthrough.success and sm.data==spending_before,"零收益无法单抽十抽或突破且不改状态",{"single":single,"ten":ten,"breakthrough":breakthrough})
 var day=preload("res://scripts/restaurant/restaurant_day.gd")
 var empty_result: Dictionary=day.validate_menu(sm,{})
 _check(not empty_result.success,"缺少菜单不能空开店",empty_result)
 battles.append({"sample":"early_resource","level":5,"initial_pantry":{},"gold_at_start":0,"outcome":outcome,"earned_bag":bag,"warehouse_after":stock,"possible_menu":menu,"missing_ingredients":missing,"satiety_after":food_after,"progress_after":exp_after,"elapsed_wall_seconds":float(Time.get_ticks_msec()-started)/1000,"banked":returned.success,"service_run":false,"reason":"无可做菜单时停止，禁止补材料；有可做菜单也尚未执行服务"})
 restaurant.queue_free();await get_tree().process_frame
func _mouse_at(point: Vector2) -> void:
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.pressed=pressed
  get_viewport().push_input(e);await get_tree().process_frame
func _shot_b03(label: String) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(_arg("--output-dir=")+"/"+label+".png")
func _positive_supply(long_service: bool=false) -> void:
 var sample_seed:=11831 if long_service else 9401
 var run:=_new_run(TEAMS.story,5,1,sample_seed)
 if run.is_empty():return
 seed(sample_seed) # 每个独立样本预先固定种子；不因结果重掷。
 sm.data.unlocked_recipe_ids=["salt_grilled_rockmane","slime_candy","brick_snail_sashimi","lizard_tail_skewer"]
 sm.data.restaurant_arrival_lesson_v1={"phase":"done"}
 sm.data.ganlu_lessons_v1={"warm":true,"iced":true,"spoiled":true,"ready":true}
 var start:=Time.get_ticks_msec()
 var elder=preload("res://data/maze/elder_firewood.gd")
 var accepted: Dictionary=sm.accept_elder_firewood(_walkable_near(elder.POSITION,elder.INTERACT_RADIUS))
 _check(accepted.success,"正收益样本正常接取木柴任务",accepted)
 for site in preload("res://data/maze/entry_dig_sites.gd").all():
  var claimed: Dictionary=sm.claim_exploration_dig_site(site.id,_walkable_near(site.position,52.0))
  _check(claimed.success,"真实挖掘事务 "+site.id,claimed)
 var delivered: Dictionary=sm.deliver_elder_firewood(_walkable_near(elder.POSITION,elder.INTERACT_RADIUS))
 _check(delivered.success,"实际消耗12木柴换取配料",delivered)
 sm.save()
 var maze=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze);get_tree().current_scene=maze
 await get_tree().create_timer(0.8).timeout
 var attempts: Array=[]
 var recipe_id: String=""
 var planned_menu: Dictionary={}
 for row in Run.monsters_for(Run.snapshot(sm)):
  if row.kind not in ["slime","brick_snail","snail","lizard"]:continue
  var live:=Run.snapshot(sm)
  if live.monsters[row.id].status not in ["alive","idle"]:continue
  var point: Vector2=row.position
  for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   var candidate: Vector2=row.position+direction*70
   if Roads.is_walkable(candidate) and Skills.Tide.visible_line(candidate,row.position,"maze_entry"):
    point=candidate;break
  maze.player.position=point
  await get_tree().process_frame
  await _send_key(KEY_1)
  var flow=maze.capture_flow
  var stop:=Time.get_ticks_msec()+20000
  while Time.get_ticks_msec()<stop and not flow.dialog.visible and not flow.attempt.visible:
   await _mouse_at(maze.get_viewport().get_canvas_transform()*Combat.vec(Run.snapshot(sm).combat.actors[row.id].position))
   await get_tree().create_timer(0.12).timeout
  if flow.dialog.visible:
   await get_tree().create_timer(0.6).timeout
   await _click(flow.dialog._confirm_button)
   await get_tree().create_timer(0.4).timeout
  if flow.attempt.visible and flow.attempt.mode=="ready":
   await _click(flow.attempt.yes_button)
   stop=Time.get_ticks_msec()+16000
   while Time.get_ticks_msec()<stop and flow.attempt.visible:
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
  for id in ["slime_candy","brick_snail_sashimi","lizard_tail_skewer"]:
   if Recipes.can_cook(id,available):recipe_id=id;break
  planned_menu=_supply_menu(available,2 if long_service else 1)
  if _menu_count(planned_menu)>=(2 if long_service else 1):break
  if attempts.size()>=6:break
 _check(not recipe_id.is_empty(),"固定新种子正常捕获获得可营业配方",{"attempts":attempts,"stock":sm.warehouse_snapshot()})
 if long_service:_check(_menu_count(planned_menu)>=2,"300秒样本正常供给至少两份菜单",{"menu":planned_menu,"attempts":attempts})
 var flow=maze.capture_flow
 maze.player.position=preload("res://data/maze/settlement_exit.gd").FRONT
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
 var returned:=Run.finish(sm,true,maze.player.position)
 _check(returned.success,"正样本真实返店",returned)
 maze.queue_free();await get_tree().process_frame
 var supply: Dictionary={"sample":"full_300_service" if long_service else "positive_supply","seed":sample_seed,"planned_menu":planned_menu,"service_policy":"首单真实完成，后续不接单以测自然超时和到点损耗" if long_service else "完成唯一菜单订单","initial_pantry":{},"initial_gold":0,"attempts":attempts,"warehouse_returned":sm.warehouse_snapshot(),"recipe":recipe_id,"service_run":false,"limitations":"任务采集和往返采用合法位置检查点及生产事务，非完整步行耗时；已解锁配方与已完成教学为初始化条件"}
 battles.append(supply)
 if recipe_id.is_empty() or not returned.success or (long_service and _menu_count(planned_menu)<2):return
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
 await _send_key(KEY_E)
 _check(sm.restaurant_customer_order(order.id).get("outcome")=="served","真实交付料理获得收入")
 if long_service:
  ready=await _observe_full_service(supply,serving_start)
 else:
  ready=await _wait_ms(func(): return day.snapshot(sm).has("settlement"),20000)
 _check(ready,"真实时钟到点结算" if long_service else "售尽自然提前打烊生成真实结算")
 await get_tree().create_timer(0.5).timeout
 await _shot_b03("supply_settlement")
 supply.merge({"service_run":true,"serving_seconds":float(Time.get_ticks_msec()-serving_start)/1000,"total_seconds":float(Time.get_ticks_msec()-start)/1000,"day":day.snapshot(sm),"gold":sm.gold_balance(),"reputation":sm.reputation(),"warehouse_final":sm.warehouse_snapshot(),"receipts":sm.data.get("restaurant_order_receipts",{})},true)
 _check(sm.gold_balance()>=0 if long_service else sm.gold_balance()>0,"实际金币合法" if long_service else "零初始金币完成正收入闭环")
 if not day.snapshot(sm).has("settlement"):return
 if long_service:_long_ledger(supply,day.snapshot(sm))
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

func _wait_ms(predicate: Callable, milliseconds: int) -> bool:
 var end:=Time.get_ticks_msec()+milliseconds
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await get_tree().process_frame
 return predicate.call()

func _walkable_near(point: Vector2, radius: float) -> Vector2:
 if Roads.is_walkable(point):return point
 for distance in range(1,int(radius)):
  for angle in range(0,360,10):
   var candidate:=point+Vector2.RIGHT.rotated(deg_to_rad(angle))*distance
   if Roads.is_walkable(candidate):return candidate
 return point

func _menu_count(menu: Dictionary) -> int:
 var count:=0
 for value in menu.values():count+=int(value)
 return count

func _supply_menu(stock: Dictionary, limit: int) -> Dictionary:
 var result: Dictionary={}
 for id in ["slime_candy","brick_snail_sashimi","lizard_tail_skewer"]:
  var count:=limit-_menu_count(result)
  for ingredient in Recipes.get_recipe(id).ingredients:
   count=mini(count,int(stock.get(ingredient,0))/int(Recipes.get_recipe(id).ingredients[ingredient]))
  if count>0:result[id]=count
  if _menu_count(result)>=limit:break
 return result

func _observe_full_service(supply: Dictionary, opened: int) -> bool:
 var day=preload("res://scripts/restaurant/restaurant_day.gd")
 var stop:=Time.get_ticks_msec()+340000
 var next_sample:=0
 var timeline: Array=[]
 while Time.get_ticks_msec()<stop:
  var state: Dictionary=day.snapshot(sm)
  if Time.get_ticks_msec()>=next_sample:
   var customers: Dictionary=sm.restaurant_customers()
   timeline.append({"wall_seconds":float(Time.get_ticks_msec()-opened)/1000,"remaining":state.get("remaining"),"status":state.get("status"),"arrived":state.get("arrived"),"front":customers.front.duplicate(true),"seated":customers.seated.duplicate(true),"gold":sm.gold_balance(),"receipts":sm.data.get("restaurant_order_receipts",{}).duplicate(true)})
   print("B03_LONG ",JSON.stringify(timeline[-1]))
   next_sample=Time.get_ticks_msec()+30000
  if state.has("settlement"):
   supply["timeline"]=timeline
   supply["full_clock_wall_seconds"]=float(Time.get_ticks_msec()-opened)/1000
   return true
  await get_tree().create_timer(0.25).timeout
 supply["timeline"]=timeline
 return false

func _long_ledger(supply: Dictionary, day: Dictionary) -> void:
 var stats: Dictionary=day.settlement
 var gold_delta:=0
 var reputation_delta:=0
 var timeout_count:=0
 var served_count:=0
 var receipts: Dictionary=sm.data.get("restaurant_order_receipts",{})
 for id in receipts:
  if not str(id).begins_with("service_"):continue
  var receipt: Dictionary=receipts[id]
  gold_delta+=int(receipt.get("gold_delta",0))
  reputation_delta+=int(receipt.get("reputation_delta",0))
  if receipt.get("outcome")=="served":served_count+=1
  elif str(receipt.get("outcome","")).contains("timeout"):timeout_count+=1
 _check(supply.full_clock_wall_seconds>=299.5 and stats.reason=="time" and day.remaining==0,"完整300秒真实营业到点，无加速或强制结算",{"wall":supply.full_clock_wall_seconds,"stats":stats})
 _check(served_count==1 and timeout_count>0 and int(day.arrived)>1,"自然多次来客含完成订单与超时",{"served":served_count,"timeouts":timeout_count,"arrived":day.arrived})
 _check(sm.gold_balance()==int(day.start_gold)+gold_delta and int(stats.net)==gold_delta and int(stats.income)-int(stats.deductions)==gold_delta,"金币余额、逐单账本与日结净额一致",{"gold_delta":gold_delta,"balance":sm.gold_balance(),"stats":stats})
 _check(sm.reputation()==int(day.start_reputation)+reputation_delta and int(stats.reputation)==reputation_delta,"声望逐单账本与日结一致")
 _check(int(stats.menu_sold)==1 and int(stats.menu_lost)==_menu_count(day.menu)-1,"多份菜单未售部分到点实际损耗",stats)
 var expected: Dictionary=supply.warehouse_returned.duplicate(true)
 for recipe in day.menu:
  for ingredient in Recipes.get_recipe(recipe).ingredients:
   expected[ingredient]=int(expected.get(ingredient,0))-int(day.menu[recipe])*int(Recipes.get_recipe(recipe).ingredients[ingredient])
 _check(sm.warehouse_snapshot()==expected,"已售与到点损耗各扣一次真实库存",{"actual":sm.warehouse_snapshot(),"expected":expected})
 supply["ledger"]={"gold_delta":gold_delta,"reputation_delta":reputation_delta,"served":served_count,"timeouts":timeout_count,"expected_stock":expected}
