extends "res://tools/tests/map05_flow.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"跨进程隔离正式档")
	var phase:=OS.get_environment("MAP05_PHASE")
	if phase=="seed":
		await prepare_trip()
		await spawn_region("fenshui")
		for id in ["fenshui_resource_herb_1","fenshui_resource_wood_1"]:
			var row:=Resources.find(id)
			_check(sm.claim_exploration_dig_site(id,stand(row)).success,"跨进程领取："+id)
		var chest:=Resources.find("fenshui_resource_chest_1")
		_check(sm.claim_exploration_chest(chest.id,stand(chest)).success,"永久宝箱领取")
		var id: String=Catalog.Frog.ID
		sm.data[Run.KEY].combat.actors[id].hp=0
		sm.data[Run.KEY].monsters[id].capture_roll=0.0
		sm.data[Run.KEY].monsters[id].copy_roll=0.0
		_check(Run.defeat(sm,id,Catalog.Frog.HOME).success,"真实待捕获事务")
		_check(Run.start_capture(sm,id).success and Run.finish_capture(sm,id,true).success,"保存付费操作待结算")
		_check(sm.save(),"退出保存")
		await _close_scene()
	else:
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		_check(Run.valid(Run.snapshot(sm)),"新进程合法探索恢复")
		if phase=="resolve":
			_check(sm.is_dig_site_claimed("fenshui_resource_herb_1") and sm.is_dig_site_claimed("fenshui_resource_wood_1") and sm.is_chest_claimed("fenshui_resource_chest_1"),"三类领取均保持")
			_check("frog_soup" not in sm.unlocked_recipe_ids(),"未结算捕获不提前解锁")
			_check(Run.resolve(sm,Catalog.Frog.ID,true).get("caught",false),"重启成功捕获原子解锁")
			_check("frog_soup" in sm.unlocked_recipe_ids(),"捕获食谱已保存")
			calm()
			_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"真实回餐厅结算")
			for quality in [1,3]:
				_check(sm.take_warehouse_items(Recipes.get_recipe("frog_soup").ingredients).success,"取本趟原料")
				_check(sm.start_cooking("frog_soup").success and sm.finish_first_order_cooking(quality).success,"真实制作两种星级")
				_check(sm.freezer_action("store",0,"frog_soup",quality).success,"独立份入柜")
			var units: Array=sm.freezer_snapshot().stored
			var original_expiry: int=units[0].expires_at
			_check(sm.freezer_action("withdraw",int(units[0].id)).success,"取出已冷藏份")
			_check(sm.freezer_action("store",int(units[0].id),"frog_soup",1).success,"再次入柜")
			_check(sm.freezer_snapshot().stored[-1].expires_at==original_expiry,"再入柜不重置期限")
			_check(Bento.assemble(sm,{"health":units[1].id}).success,"选择三星具体份装配")
			_check(Run.begin(sm,Roads.SPAWN).success,"装盒开始新趟")
			_check(not sm.is_dig_site_claimed("fenshui_resource_herb_1") and sm.is_dig_site_claimed("fenshui_resource_wood_1"),"新趟植物重建永久木材不重建")
			_check(sm.save(),"携带未食料理退出")
		elif phase=="eat":
			_check(Bento.snapshot(sm).slots.health.id=="frog_soup" and Bento.snapshot(sm).slots.health.stars==3 and not Bento.snapshot(sm).slots.health.eaten,"新进程未食三星料理保持")
			calm()
			sm.data[Run.KEY].combat.hp=1.0
			_check(Bento.eat(sm,"health").success,"新进程食用")
			sm.data.map05_hp=sm.data[Run.KEY].combat.hp
			_check(sm.save(),"退出保存已食及即时生命")
		else:
			_check(Bento.snapshot(sm).slots.health.eaten and sm.data[Run.KEY].combat.hp==sm.data.map05_hp,"第三进程已食与生命不重复恢复")
			_check(not Bento.eat(sm,"health").success,"恢复后拒绝重吃")
			_check(Run.finish(sm,false,Roads.SPAWN).success and not Bento.snapshot(sm).slots.has("health"),"结束清除已食格")
			_check("frog_soup" in sm.unlocked_recipe_ids() and sm.is_chest_claimed("fenshui_resource_chest_1"),"永久配方与宝箱跨趟保持")
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
