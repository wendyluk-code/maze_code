extends "res://tools/tests/combat_skill_01.gd"
const Guard=preload("res://scripts/maze/chengyan_guard.gd")
const Frog=preload("res://scripts/maze/wind_frog_combat.gd")
const Rock=preload("res://scripts/maze/rockmane_combat.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation() and ProjectSettings.get_setting("application/config/name")=="maze_c05_chengyan_isolated","项目名与用户目录隔离")
	if failures: get_tree().quit(1); return
	_completed()
	tm.active=false
	sm.data["first_exploration_gate_v1"]="done"
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.data["owned_characters_v1"]=["chengyan","yaya"]
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["chengyan","yaya"]).success,"真实编队出发")
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.8).timeout
	_fixture()
	_rules()
	_damage_paths()
	_story_edges()
	_transactions()
	await _interface()
	_lifecycle()
	maze.queue_free()
	await get_tree().process_frame
	GameAudio.set_world_music(&"")
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _sample(rank: int=1) -> Dictionary:
	var run:=Run.snapshot(sm)
	run.members=[{"id":"chengyan","rank":rank,"level":1,"element":"water"}]
	run.combat=Combat.create(3,100,CENTER,Run.monsters_for(run))
	run.combat.layout=run.layout.duplicate(true)
	Skills.ensure(run.combat)
	run.combat.chengyan_guard=Guard.fresh()
	for id in run.monsters:
		run.monsters[id].status="skipped"
		run.monsters[id].respawn_at=run.maze_elapsed+600
	return run

func _rules() -> void:
	for rank in range(1,7):
		var config:=Guard.rules(rank)
		_check(config.invincible==(2.0 if rank==6 else (1.5 if rank>=4 else 1.0)),"无敌星级 "+str(rank))
		_check(is_equal_approx(config.recovery,[0.1,0.12,0.15,0.15,0.18,0.2][rank-1]),"恢复星级 "+str(rank))
		for step in [1.0/30,1.0/60,1.0/120,0.1,0.5]:
			var run:=_sample(rank)
			run.combat.hp=2.0
			_check(not Guard.damage(run,2) and run.combat.hp==1 and Guard.protected(run.combat),"恰好致死保命 "+str(rank)+"/"+str(step))
			Guard.damage(run,999)
			_check(run.combat.hp==1 and run.combat.chengyan_guard.used,"同帧超额伤害被免疫")
			Guard.advance(run.combat,float(config.invincible))
			_check(not Guard.protected(run.combat) and run.combat.hp==1,"无敌端点不提前回血")
			for i in range(roundi(5.0/step)): Guard.advance(run.combat,step)
			_check(is_equal_approx(run.combat.hp,1.0+100.0*float(config.recovery)) and run.combat.chengyan_guard.heal_left==0,"五秒总回血与步长无关")
			Guard.damage(run,999)
			_check(run.combat.hp==0 and run.combat.chengyan_guard.used,"第二次致死正常死亡")
	var run:=_sample()
	run.combat.hp=1
	Guard.damage(run,100)
	run.combat.max_hp=200
	Guard.advance(run.combat,6)
	_check(is_equal_approx(run.combat.hp,11),"触发后最大生命变化不重算总量")
	run=_sample()
	run.combat.hp=1
	Guard.damage(run,100)
	run.combat.hp=99
	Guard.advance(run.combat,6)
	_check(run.combat.hp==100,"回血封顶最大生命")
	run=_sample()
	run.members=[]
	run.combat.hp=1
	Guard.damage(run,100)
	_check(run.combat.hp==0 and not run.combat.chengyan_guard.used,"不在队不保命")
	run=_sample()
	_check(Guard.damage(run,2) and run.combat.hp==98 and not run.combat.chengyan_guard.used,"普通伤害不消耗次数")
	for field in ["invincible","heal_left","total","paid"]:
		for value in [-1.0,NAN,INF]:
			var invalid: Dictionary=run.combat.duplicate(true)
			invalid.chengyan_guard[field]=value
			_check(not Guard.valid(invalid),"损坏状态拒绝 "+field+str(value))
	var invalid: Dictionary=run.combat.duplicate(true)
	invalid.chengyan_guard.used="false"
	_check(not Guard.valid(invalid),"布尔损坏拒绝")

func _damage_paths() -> void:
	for kind in ["melee","slime_shot","frog","rock"]:
		for hp in [1.0,100.0]:
			var run:=_sample()
			run.combat.hp=hp
			if kind=="melee":
				run.monsters.slime_1.status="alive"
				var a: Dictionary=run.combat.actors.slime_1
				a.position=Combat.pack(CENTER+ALONG*20)
				a.mode="windup"
				a.windup=0.001
				a.skill_reuse=5.0
				Combat.advance(run,CENTER,0.01)
			elif kind=="slime_shot":
				run.combat.enemy_shots=[{"position":Combat.pack(CENTER+ALONG*21),"direction":Combat.pack(-ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
				Skills.advance(run,CENTER,0.02)
			elif kind=="frog": Frog.hurt(run,CENTER,CENTER+ALONG*20)
			else: Rock.hurt(run,CENTER,CENTER+ALONG*20)
			_check(run.combat.hp==1 and run.combat.chengyan_guard.used if hp==1 else (run.combat.hp<100 and not run.combat.chengyan_guard.used),"实际承伤入口 "+kind+" hp="+str(hp))
			if hp==1:
				Frog.hurt(run,CENTER,CENTER+ALONG*20)
				Rock.hurt(run,CENTER,CENTER-ALONG*20)
				_check(run.combat.hp==1 and run.combat.get("hit_remaining",0)==0 and run.combat.get("flash_remaining",0)==0,"保命后免疫连续攻击及击退闪红 "+kind)

func _transactions() -> void:
	var run:=_sample()
	run.combat.hp=1
	run.combat.enemy_shots=[{"position":Combat.pack(CENTER+ALONG*21),"direction":Combat.pack(-ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
	sm.data[Run.KEY]=run
	_check(Run.valid(run),"保命前探索有效")
	var before: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.02).success and sm.data==before,"失败回滚致死伤害次数无敌与弹丸")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,CENTER,0.02).success and Run.snapshot(sm).combat.chengyan_guard.used,"恢复保存重试一次保命")
	var state: Dictionary=Run.snapshot(sm).combat.chengyan_guard.duplicate(true)
	_check(sm.save(),"保命进度保存")
	sm.load_data()
	_check(sm.last_load_error.is_empty() and _same_guard(Run.snapshot(sm).combat.chengyan_guard,state),"读档保留次数无敌进度",{"actual":Run.snapshot(sm).combat.chengyan_guard,"expected":state,"valid":Run.valid(Run.snapshot(sm))})
	var resumed:=Run.begin(sm,CENTER)
	_check(resumed.success and _same_guard(Run.snapshot(sm).combat.chengyan_guard,state),"重入保留进度",resumed)
	before=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.1).success and sm.data==before,"无敌时钟保存失败整体回滚")
	sm._active_save_path=path
	run=sm.data[Run.KEY]
	Guard.advance(run.combat,1.0)
	before=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,CENTER,0.1).success and sm.data==before,"回血计时保存失败整体回滚")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,CENTER,0.1).success,"回血恢复保存可重试")

func _story_edges() -> void:
	var run:=_sample()
	var sparring=preload("res://scripts/maze/yf_sparring.gd")
	var duel: Dictionary=sparring.create(run)
	var point: Vector2=preload("res://data/maze/fenshui_roads.gd").ENTRANCE
	duel.combat.hp=1.0
	duel.combat.stop_hp=0.2
	duel.combat.enemy_shots=[{"position":Combat.pack(point),"direction":[0.0,1.0],"distance":0.0,"source":"salia"}]
	sparring.advance(duel,point,0.01,false)
	_check(duel.combat.hp==0.2 and not duel.combat.chengyan_guard.used,"原剧情切磋保底不消耗机会")
	var before: Dictionary=sm.data.duplicate(true)
	run.combat.hp=1
	Guard.damage(run,100)
	sm.data["owned_characters_v1"]=["chengyan","yaya","yufeng","salia"]
	sm.data.erase("yufeng_salia_party_joined_v1")
	_check(preload("res://scripts/maze/story_party_join.gd").apply(sm,run,true),"实际剧情入队增加团队上限")
	var hp: float=run.combat.hp
	Guard.advance(run.combat,6)
	_check(is_equal_approx(run.combat.hp,hp+10),"剧情入队不重算已锁定恢复总量")
	sm.data=before

func _interface() -> void:
	_fixture()
	var run:=_sample()
	sm.data[Run.KEY]=run
	_check(Run.valid(run),"界面夹具有效",{"combat":Combat.valid(run.combat),"layout":run.layout==run.combat.layout,"actors":run.combat.actors.size(),"monsters":run.monsters.size(),"food_cursor":run.food_cursor})
	maze.capture_flow._process(0)
	_check(maze.capture_flow.skill_bar.key_labels[1].text=="被动","被动键帽")
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected==0,"数字键保留当前主动技能")
	await _click(maze.capture_flow.skill_bar.buttons[1])
	_check(maze.capture_flow.character_details.visible,"点击打开既有详情")
	_check(maze.capture_flow.character_details.active_interval.text=="每趟首次致命伤","详情显示真实触发条件")
	maze.capture_flow._process(0)
	await _capture_image("c05_details")
	await _send_key(KEY_ESCAPE)
	_check(not maze.capture_flow.character_details.visible and not maze.player.input_locked,"关闭恢复输入")
	run=sm.data[Run.KEY]
	run.combat.hp=1
	run.combat.enemy_shots=[{"position":Combat.pack(CENTER+ALONG*21),"direction":Combat.pack(-ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
	_tick(0.02)
	_check(Run.snapshot(sm).combat.chengyan_guard.used and Run.snapshot(sm).combat.hp==1,"场景内真实弹丸触发保命")
	await _capture_image("c05_guard")
	var before:=Run.snapshot(sm)
	maze.capture_flow._focus_lost()
	maze.capture_flow._process(0.5)
	_check(Run.snapshot(sm)==before,"暂停不计时")
	maze.capture_flow.window_focused=true
	for i in 12: _tick(0.5)
	_check(is_equal_approx(Run.snapshot(sm).combat.hp,11),"场景内无敌后五秒回血")
	await _capture_image("c05_recovered")

func _lifecycle() -> void:
	var run:=_sample()
	run.combat.hp=1
	Guard.damage(run,100)
	Guard.advance(run.combat,0.3)
	sm.data[Run.KEY]=run
	var state: Dictionary=run.combat.chengyan_guard.duplicate(true)
	var entrance: Vector2=preload("res://data/maze/fenshui_roads.gd").ENTRANCE
	var previous: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.change_region(sm,"fenshui",entrance).success and sm.data==previous,"跨区失败不丢保命进度")
	sm._active_save_path=path
	var changed:=Run.change_region(sm,"fenshui",entrance)
	_check(changed.success and _same_guard(Run.snapshot(sm).combat.chengyan_guard,state),"跨区成功保留次数与进度",changed)
	run=sm.data[Run.KEY]
	run.members=[]
	Guard.advance(run.combat,0.2)
	_check(run.combat.chengyan_guard.used and run.combat.chengyan_guard.invincible<state.invincible,"移除成员不重置已触发进度")
	run.members=[{"id":"chengyan","rank":1,"level":1,"element":"water"}]
	_check(Guard.rank_for(run)==1 and run.combat.chengyan_guard.used,"换回成员不刷新次数")
	var moss: Vector2=preload("res://data/maze/moss_pool_roads.gd").SPAWN
	_check(Run.change_region(sm,"moss_pool",moss).success,"进入青苔池")
	run=sm.data[Run.KEY]
	var left: float=run.combat.chengyan_guard.invincible
	_check(Run.combat_tick(sm,moss,0.1).success and Run.snapshot(sm).combat.chengyan_guard.invincible<left,"青苔池推进保命时钟")
	run=sm.data[Run.KEY]
	sm.data["first_exploration_gate_v1"]="done"
	for a in run.combat.actors.values(): a.mode="idle"
	run.combat.shots=[]
	run.combat.enemy_shots=[]
	_check(Run.finish(sm,false,moss).success,"正式结束本趟")
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["chengyan"]).success,"再次正式出发请求")
	_check(Run.begin(sm,CENTER).success and not Run.snapshot(sm).combat.chengyan_guard.used,"新趟恢复一次机会")
	# 实际首探回滚清除整个探索，下一次正式入场重新获得一次机会。
	var checkpoint: Dictionary=sm.data.duplicate(true)
	checkpoint.erase(Run.KEY)
	sm.data["first_exploration_checkpoint_v1"]=checkpoint
	sm.data["first_exploration_gate_v1"]="active"
	run=sm.data[Run.KEY]
	run.combat.hp=1
	Guard.damage(run,100)
	Guard.advance(run.combat,6)
	Guard.damage(run,100)
	_check(Run.finish(sm,false,CENTER).success and not sm.data.has(Run.KEY),"首探第二次致死执行原回退")
	sm.cancel_maze_entry()
	_check(sm.request_maze_entry(["chengyan"]).success,"首探回退后再次出发")
	_check(Run.begin(sm,CENTER).success and not Run.snapshot(sm).combat.chengyan_guard.used,"首探新趟恢复机会")

func _same_guard(a: Dictionary,b: Dictionary) -> bool:
	if a.used!=b.used: return false
	for key in ["invincible","heal_left","total","paid"]:
		if not is_equal_approx(float(a[key]),float(b[key])): return false
	return true
