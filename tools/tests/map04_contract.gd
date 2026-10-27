extends "res://tools/tests/maze_capture.gd"
const SR=preload("res://data/maze/salt_pool_roads.gd")
const Crystal=preload("res://scripts/maze/salt_crystals.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"契约样例使用隔离存档")
	_fresh()
	_check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"建立实际盐池模拟")
	var base: Dictionary=sm.data.duplicate(true)
	# 澄砚只有资料尚无普攻实现；此处明确注入未来接入层应提供的命中包，不新增角色技能。
	for element in ["earth","grass","water"]:
		sm.data=base.duplicate(true)
		var c: Dictionary=sm.data[Run.KEY].combat
		c.throws=1
		c.shots=[{"origin":[505,430],"target":[505,330],"position":[505,430],"time":0.0,"flight":0.5,"kind":"chengyan","basic":true,"element":element,"attack_serial":1}]
		_check(Run.valid(Run.snapshot(sm)),"非铁山普攻事件契约合法"+element)
		var feedback: Array=[]
		for i in 10:
			var result:=Run.combat_tick(sm,Vector2(505,430),0.05)
			_check(result.success,"通用投射物沿实际轨迹命中"+element)
			feedback.append_array(result.get("mining_feedback",[]))
		_check(feedback==["salt" if element=="earth" else "dull"],"碰撞边缘实际命中且仅一次正确反馈"+element)
		_check(sm.data[Run.KEY].bag.get("rock_salt",0)==(1 if element=="earth" else 0),"同一非铁山标识只按事件元素采晶"+element)
		sm.load_data()
		_check(sm.data[Run.KEY].bag.get("rock_salt",0)==(1 if element=="earth" else 0),"事件采晶回执持久化"+element)
		Crystal.impact(sm.data[Run.KEY].combat,0,element,1)
		_check(Run.combat_tick(sm,Vector2(505,430),0.05).success and sm.data[Run.KEY].bag.get("rock_salt",0)==(1 if element=="earth" else 0),"JSON重载后同次命中回执继续去重"+element)
	# 不是普攻的相同土属性弹丸不能采晶。
	sm.data=base.duplicate(true)
	var c: Dictionary=sm.data[Run.KEY].combat
	c.throws=1
	c.shots=[{"origin":[505,430],"target":[505,330],"position":[505,430],"time":0.0,"flight":0.5,"kind":"chengyan","basic":false,"element":"earth","attack_serial":1}]
	for i in 10: _check(Run.combat_tick(sm,Vector2(505,430),0.05).success,"土属性技能弹道推进")
	_check(sm.data[Run.KEY].bag.is_empty(),"相同标识相同土属性技能仍不采晶")
	# 跨自然日的同一攻击序号，命中只归属首次提交日。
	var state: Dictionary={}
	var run: Dictionary={"bag":{},"combat":{"throws":1}}
	Crystal.impact(run.combat,0,"earth",1)
	_check(Crystal.apply(state,run,20000).success,"零点前命中归旧日")
	Crystal.impact(run.combat,1,"earth",1)
	_check(Crystal.apply(state,run,20001).success and run.bag.rock_salt==1 and not state[Crystal.KEY].has("right"),"跨零点同次多段不重新发份额")
	var bad: Dictionary=base[Run.KEY].duplicate(true)
	bad.combat.salt_attack_receipts=[1,1]
	bad.combat.throws=1
	_check(not Run.valid(bad),"重复攻击回执损坏档拒绝")
	bad=base[Run.KEY].duplicate(true)
	bad.combat.salt_impacts=[{"id":"unknown","element":"earth"}]
	_check(not Run.valid(bad),"未知盐晶事件拒绝")
	_check(not Crystal.valid({"left":{"day":20000,"used":4}}),"非法日次数拒绝")
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
