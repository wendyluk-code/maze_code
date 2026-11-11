extends "res://tools/tests/pool_clue_flow.gd"
const Join = preload("res://scripts/maze/story_party_join.gd")

func _story_flow() -> void:
	await super._story_flow()
	await _open_map()
	var run := Run.snapshot(sm)
	_check(run.members.map(func(m): return m.id) == ["yaya","tieshan","yufeng","salia"],"剧情入队立即补齐本趟3和4号槽")
	_check(sm.remembered_maze_party()==["yaya","tieshan","yufeng","salia"],"后续出发记住双人队伍")
	var max_hp: int=run.combat.max_hp
	_check(not Join.apply(sm,sm.data[Run.KEY]) and Run.snapshot(sm).combat.max_hp==max_hp,"重复加载不叠加角色属性")
	for slot in [3,4]:
		await _send_key(KEY_3 if slot==3 else KEY_4)
		_check(Run.snapshot(sm).combat.selected==slot,"真实数字键切换新角色：%d" % slot)
		sm.data[Run.KEY].combat.cooldown=0.0
		sm.data[Run.KEY].combat.action_left=0.0
		await _attack_mouse()
		_check(Run.snapshot(sm).combat.action==("yufeng" if slot==3 else "salia"),"真实左键执行新角色招式：%d" % slot)
		await _capture_image("skill_%d" % slot)
		await get_tree().create_timer(0.4).timeout
	await _close_map()
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)) and Run.snapshot(sm).members.size()==4,"新技能战斗状态可保存读档")
	_skill_rules()

func _skill_rules() -> void:
	var run := Run.snapshot(sm).duplicate(true)
	var combat = Run.Combat
	var rows: Array=combat.Catalog.Fenshui.all()
	var first: Dictionary=rows[0]
	var second: Dictionary=rows[1]
	for id in run.monsters: run.monsters[id].status="skipped"
	for row in [first,second]:
		run.monsters[row.id].status="alive"
		run.combat.actors[row.id].hp=20
		run.combat.actors[row.id].mode="idle"
	# 同一水域内的两个等价实际目标。
	run.combat.actors[first.id].position=[1065.0,405.0]
	run.combat.actors[second.id].position=[1060.0,410.0]
	_check(combat.water_line(Vector2(1065,405),Vector2(1060,410)),"连锁样例位于连续水域")
	var shot := {"kind":"salia","rank":1,"damage":10,"lives":combat.life_ids(run),"origin":[1050.0,405.0]}
	_check(combat.skill_damage(run,shot,first)==11,"引雷对水系目标加伤")
	combat.lightning_chain(run,shot,first.id,10)
	_check(run.combat.actors[second.id].hp==14 and run.combat.actors[first.id].hp==20,"雷电连锁60%伤害且不回击首目标")
	shot.kind="yufeng"
	_check(combat.skill_damage(run,shot,first)==11,"风刃对满血目标加伤")
	combat.apply_wind(run,shot,first)
	_check(is_equal_approx(run.combat.actors[first.id].wind_left,0.3),"风刃施加0.3秒控制")
	combat.advance_wind_control(run,0.1)
	_check(run.combat.actors[first.id].wind_steps==1,"击退按0.1秒分段")
	var left: float=run.combat.actors[first.id].wind_left
	combat.apply_wind(run,shot,first)
	_check(run.combat.actors[first.id].wind_left==left,"两秒内重复命中不刷新控制")
	combat.advance_wind_control(run,0.2)
	_check(run.combat.actors[first.id].wind_steps==3,"击退共三段")
	# 真实投射物推进：从选槽发射到追踪命中，不能只检查动作字段。
	for row in [first,second]:
		run.monsters[row.id].status="alive"
		run.combat.actors[row.id].hp=20
		run.combat.actors[row.id].wind_left=0.0
		run.combat.actors[row.id].mode="idle"
	run.combat.actors[first.id].position=[1065.0,405.0]
	run.combat.actors[second.id].position=[1060.0,410.0]
	run.combat.shots=[]
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	run.combat.attack=5
	combat.Skills.select(run,4)
	_check(combat.attack(run,Vector2(1050,405),Vector2.RIGHT),"萨莉亚真实投射物创建")
	for tick in 12: combat.advance(run,Vector2(1050,405),0.05)
	_check(run.combat.actors[first.id].hp<20 and run.combat.actors[second.id].hp<20,"追踪雷电真实推进命中并连锁")
	_check(combat.valid(run.combat),"追踪及控制扩展状态通过存档校验")
	run.combat.shots=[]
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	combat.attack(run,Vector2(1050,405),Vector2.RIGHT)
	for id in run.monsters: run.monsters[id].status="skipped"
	combat.advance(run,Vector2(1050,405),0.05)
	_check(run.combat.shots.is_empty(),"追踪目标失效时雷电消散")
	var before: Dictionary=sm.data.duplicate(true)
	sm.data.erase(Join.MARK)
	sm.data[Run.KEY].members=sm.data[Run.KEY].members.slice(0,2)
	var old_max: int=sm.data[Run.KEY].combat.max_hp
	_check(Join.apply(sm,sm.data[Run.KEY]),"已完成任务旧档可补齐本趟队伍")
	_check(sm.data[Run.KEY].members.size()==4 and sm.data[Run.KEY].combat.max_hp==old_max+28,"补齐时两人生命属性生效")
	sm.data=before
	var full := Run.snapshot(sm).duplicate(true)
	sm.data.erase(Join.MARK)
	var ids: Array=full.members.map(func(m):return m.id)
	sm._maze_entry_pending=true
	sm._maze_entry_party=["yaya","tieshan"]
	_check(Join.apply(sm,full) and full.members.map(func(m):return m.id)==ids,"满队不替换已有队员")
	_check(sm.exploration_entry_party()==ids,"旧档首次入场快照同步补齐成员，不覆盖常用队伍")
	sm.cancel_maze_entry()
	sm.data=before
