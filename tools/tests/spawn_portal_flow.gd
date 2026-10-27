extends "res://tools/tests/combat_07_flow.gd"
const FS=preload("res://data/maze/fenshui_roads.gd")
func _run() -> void:
	get_window().size=Vector2i(1280,720)
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.position=maze.SettlementExit.FRONT
	for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
	sm.data[Run.KEY].combat.actors.slime_1.mode="chase"
	maze._open_confirmation("下一区域")
	_check(not maze.confirmation.visible,"追逐中不能打开路标")
	_check(not Run.change_region(sm,"fenshui",FS.SPAWN).success,"事务层拒绝战斗切区")
	sm.data[Run.KEY].combat.actors.slime_1.mode="return"
	_check(not Run.portal_combat_locked(sm),"返航解除传送锁")
	maze._open_confirmation("下一区域")
	sm.data[Run.KEY].combat.actors.slime_1.mode="windup"
	maze._confirm_destination()
	_check(sm.maze_exploration_state().region=="maze_entry","确认时再次检查战斗")
	sm.data[Run.KEY].combat.actors.slime_1.mode="idle"
	maze._open_confirmation("下一区域")
	maze._confirm_destination()
	await get_tree().create_timer(1.2).timeout
	maze=get_tree().current_scene
	_check(maze.region_id=="fenshui" and maze.has_node("SpawnPortal"),"第二地区绿色出生点")
	maze.capture_flow.set_process(false)
	maze._update_prompts()
	_check(FS.is_walkable(maze.player.position),"前往落点可走")
	_check(not maze.entrance_prompt.visible and maze._near_destination()=="","前往落地不触发E")
	await _capture_image("forward_arrival")
	maze.player.position=FS.ENTRANCE+Vector2(-35,13)
	maze._update_prompts()
	_check(maze.entrance_prompt.visible,"走近绿色路标显示E")
	_check(maze.entrance_prompt.world_anchor==FS.ENTRANCE+Vector2(0,-34),"提示锚定路标上方")
	maze._open_confirmation("枯水渠")
	_check(maze.confirmation.visible and maze.confirmation.confirm_button.text=="返回","返回确认显示")
	await _capture_image("green_return_confirm")
	maze._close_confirmation()
	await _capture_image("green_spawn")
	var before: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.change_region(sm,"maze_entry",maze.SettlementExit.FRONT).success and sm.data==before,"返回保存失败完整回滚")
	sm._active_save_path=path
	maze._open_confirmation("枯水渠")
	maze._confirm_destination()
	await get_tree().create_timer(1.2).timeout
	maze=get_tree().current_scene
	maze.capture_flow.set_process(false)
	_check(maze.region_id=="maze_entry" and maze.player.position.distance_to(maze.SettlementExit.ARRIVAL)<1,"返回前方合法站位")
	maze._update_prompts()
	_check(Roads.is_walkable(maze.player.position),"返回落点可走")
	_check(not maze.settlement_prompt.visible and maze._near_destination()=="","返回落地不触发E")
	await _capture_image("return_arrival")
	maze.player.position=maze.SettlementExit.FRONT
	maze._update_prompts()
	_check(maze.settlement_prompt.visible,"走近紫色路标显示E")
	sm.load_data()
	var run=Run.snapshot(sm)
	_check(run.get("returned_regions",{}).get("maze_entry",false),"本趟清空区域标记")
	for m in run.monsters.values(): _check(m.status!="alive","返回无剩余怪")
	run.maze_elapsed=1.0e21
	_check(not Run.refresh_due(run,Roads.SPAWN,Rect2(850,0,300,200)),"后续不刷新")
	maze.capture_flow._process(0)
	for m in maze.capture_flow.monsters.values(): _check(not m.visible,"怪物实机隐藏")
	maze._open_confirmation("下一区域")
	maze._confirm_destination()
	await get_tree().create_timer(1.2).timeout
	maze=get_tree().current_scene
	maze.capture_flow.set_process(false)
	maze.player.position=FS.ENTRANCE+Vector2(-35,13)
	sm.data[Run.KEY].bag={"slime_gel":1}
	var stock: int=int(sm.warehouse_snapshot().get("slime_gel",0))
	maze._open_confirmation("枯水渠")
	maze._finish_exploration_choice()
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and int(sm.warehouse_snapshot().get("slime_gel",0))==stock+1,"出生点结束探索入库餐厅")
	_check(Run.begin(sm,Roads.SPAWN).success,"新趟重新进入")
	_check(not Run.snapshot(sm).get("returned_regions",{}).get("maze_entry",false),"新趟清除返回区域标记")
	for m in Run.snapshot(sm).monsters.values(): _check(m.status=="alive","新趟恢复魔物")
	var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)


