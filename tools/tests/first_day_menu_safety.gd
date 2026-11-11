extends "res://tools/tests/first_exploration.gd"
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 _completed()
 sm.complete_chapter_1()
 tm.active=false
 _check(Run.begin(sm,Roads.SPAWN).success,"开始首次探索")
 var id="slime_1"
 sm.data[Run.KEY].combat.actors[id].hp=0
 _check(Run.defeat(sm,id,Run.monster_for(Run.snapshot(sm),id).position).success,"击败首只史莱姆")
 _check(Run.start_capture(sm,id).success,"真实捕获扣费")
 _check(Run.finish_capture(sm,id,false).success,"提交捕获操作")
 _check(Run.resolve(sm,id,true).caught,"首次捕获成功")
 _check(sm.accept_elder_firewood(Vector2(839,503)).success,"接取白虎任务")
 # 夹具仅提供已采集12木材，奖励与返程均走真实事务。
 sm.data[sm.INVENTORY_KEY]["wood"]=12
 _check(sm.deliver_elder_firewood(Vector2(839,503)).success,"真实交付任务奖励")
 var checkpoint: Dictionary=sm.data.duplicate(true)
 _check(Run.finish(sm,true,Vector2(116,724)).success,"正常首次结算")
 _check(Day.validate_menu(sm,{"slime_candy":1}).success,"正常首趟能选一份史莱姆冻")
 sm.data=checkpoint
 sm.data[Run.KEY].combat.hp=0
 _check(Run.finish(sm,false,Roads.SPAWN).success,"捕获后战败返程")
 _check(Gate.pending(sm),"战败仍未完成首次探索")
 _check(Run.begin(sm,Roads.SPAWN).success,"战败后再次进入")
 _check(Run.finish(sm,true,Vector2(116,724)).success,"未再次捕获也能正常结算")
 var cookable: Array=[]
 for recipe in sm.unlocked_recipe_ids():
  if Recipes.order_gold(recipe)>0 and Day.validate_menu(sm,{recipe:1}).success: cookable.append(recipe)
 _check(cookable.is_empty(),"复现首日正常返程后无任何可选料理",{"cookable":cookable,"warehouse":sm.warehouse_snapshot()})
 _check(sm.data.get("first_business_intro_pending",false),"仍触发第一天经营教学")
 var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
 get_tree().root.add_child(restaurant)
 get_tree().current_scene=restaurant
 await get_tree().create_timer(0.7).timeout
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 for index in range(4):
  if is_instance_valid(hud.return_loot) and hud.return_loot.visible:
   hud.return_loot.close_modal()
   await get_tree().create_timer(0.2).timeout
 _check(hud.exploration_guide.reading,"真实餐厅播放首次经营说明")
 hud.exploration_guide._read_done()
 await get_tree().create_timer(0.3).timeout
 _check(hud.day_menu.visible and hud.day_menu.empty_panel.visible and hud.day_menu.confirm_button.disabled,"实景复现第一天无料理且不能开始营业")
 await _shot_gate("first_day_empty_after_defeat")
 restaurant.queue_free()
 await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"所有写档均隔离")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
