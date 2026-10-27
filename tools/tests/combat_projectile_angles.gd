extends "res://tools/tests/combat_skill_01.gd"
func _combat_scene() -> void:
	await _new_scene()
	for slot in [0,1]:
		for degrees in range(0,360,30):
			_fixture()
			var run: Dictionary=sm.data[Run.KEY]
			run.combat.erase("slime_lesson")
			Skills.select(run,slot)
			var direction := Vector2.RIGHT.rotated(deg_to_rad(degrees))
			_check(Combat.attack(run,CENTER,direction),"角度发射",{"slot":slot,"degrees":degrees})
			Combat.advance(run,CENTER,0.15)
			_check(run.combat.shots.size()==1,"空中弹道不能被脚下道路边缘截断",{"slot":slot,"degrees":degrees})
			if run.combat.shots.size()==1:
				_check(Combat.vec(run.combat.shots[0].position).distance_to(CENTER)>60,"弹道实际前进")
			maze.capture_flow._process(0)
			if degrees in [0,90,180,270]: await _capture_image("slot_%d_angle_%d" % [slot,degrees])
	_check(not Combat.projectile_clear(Vector2(-1,200)),"地图边缘仍阻挡")
	_check(not Combat.projectile_clear(Vector2(650,1085)),"实体栅栏仍阻挡")
	_check(Combat.projectile_clear(CENTER+Vector2(0,80)) and not Combat.walkable(CENTER+Vector2(0,80)),"道路外空中范围与脚下导航分离")
	for slot in [0,1]:
		_fixture()
		var run: Dictionary=sm.data[Run.KEY]
		Skills.select(run,slot)
		Combat.attack(run,CENTER,Vector2.DOWN)
		for step in 14: Combat.advance(run,CENTER,0.05)
		_check(run.combat.shots.is_empty(),"未命中弹道按射程消散")
	await _close_scene()
