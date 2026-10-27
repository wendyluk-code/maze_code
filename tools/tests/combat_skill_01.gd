extends "res://tools/tests/combat_07_flow.gd"
const Skills=preload("res://scripts/maze/team_attack.gd")
const CENTER=Vector2(933,269)
const ALONG=Vector2(0.924,-0.383)

func _fixture() -> void:
	maze.capture_flow.set_process(false)
	maze.player.position=CENTER
	var run: Dictionary=sm.data[Run.KEY]
	run.pending=""
	run.combat=Combat.create(3,36,CENTER,Run.monsters_for(run))
	run.combat.cooldown=0.0
	for id in run.monsters:
		run.monsters[id].status="skipped"
		run.monsters[id].respawn_at=run.maze_elapsed+600
	Skills.ensure(run.combat)
	maze.capture_flow.window_focused=true
	maze.capture_flow.save_retry_delay=0
	maze.capture_flow.busy=false
	maze.capture_flow.combat_time=0
	maze.capture_flow._process(0)

func _tick(dt: float) -> void:
	var result:=Run.combat_tick(sm,maze.player.position,dt)
	_check(result.success,"战斗事务推进",result)
	maze.player.position=Combat.vec(Run.snapshot(sm).combat.hero)
	maze.capture_flow._process(0)

func _mouse(button: int, point: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=button
		event.position=point
		event.pressed=pressed
		get_viewport().push_input(event)
		await get_tree().process_frame

func _world(point: Vector2) -> Vector2:
	return maze.get_viewport().get_canvas_transform()*point

func _combat_scene() -> void:
	await _new_scene()
	_fixture()
	var flow=maze.capture_flow
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected==1,"数字1选择芽芽")
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*120))
	var c: Dictionary=Run.snapshot(sm).combat
	_check(c.throws==1 and c.shots[0].kind=="yaya","真实鼠标释放芽芽")
	_check(Combat.vec(c.shots[0].target).distance_to(CENTER+ALONG.normalized()*310)<2,"直线按鼠标方向远射")
	await _send_key(KEY_2)
	_check(Run.snapshot(sm).combat.cooldown==c.cooldown,"切换不刷新攻击冷却")
	await _send_key(KEY_SPACE)
	_check(Run.snapshot(sm).combat.selected==0,"空格恢复锅铲")
	await _send_key(KEY_TAB)
	_check(Run.snapshot(sm).combat.selected==1,"Tab循环选择")
	await _send_key(KEY_4)
	_check(Run.snapshot(sm).combat.selected==1,"空槽不覆盖已选技能")
	await _send_key(KEY_J)
	_check(Run.snapshot(sm).combat.throws==1,"J不攻击")
	await _capture_image("skill_bar")
	_fixture()
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*120))
	_check(Run.snapshot(sm).combat.throws==1,"无目标也按方向投锅铲")
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*120))
	_check(Run.snapshot(sm).combat.throws==1,"冷却中不排队")
	await _capture_image("throw")
	_fixture()
	await _send_key(KEY_2)
	var run: Dictionary=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*50)
	run.combat.actors.slime_1.skill_reuse=2
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*100))
	_tick(0.2)
	_check(Run.snapshot(sm).combat.actors.slime_1.hp==11,"旋斧在范围内伤害一次")
	_tick(0.1)
	_check(Run.snapshot(sm).combat.actors.slime_1.hp==11,"旋转余帧不重复伤害")
	await _capture_image("axe")
	_fixture()
	await _send_key(KEY_1)
	await _mouse(MOUSE_BUTTON_RIGHT,_world(CENTER+ALONG*100))
	c=Run.snapshot(sm).combat
	_check(c.get("guard_left",0)==0 and c.selected==1 and c.throws==0,"右键无动作且保留芽芽选择")
	_check(not flow.skill_visual.hero.visible,"右键不显示举锅动画")
	var captions := []
	for label in flow.controls_hint.find_children("*","Label",true,false): captions.append(label.text)
	_check(not "格挡" in captions and not "右键" in captions and "攻击" in captions and "切换" in captions and "加速" in captions,"提示只保留三组操作")
	# 仅芽芽防御1，才能区分格挡免伤与原队伍防御抵扣。
	sm.data[Run.KEY].members=[sm.data[Run.KEY].members[0]]
	sm.data[Run.KEY].combat.enemy_shots=[{"position":Combat.pack(CENTER+ALONG*22),"direction":Combat.pack(-ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
	_tick(0.05)
	c=Run.snapshot(sm).combat
	_check(c.hp==34 and c.get("blocks",0)==0 and c.enemy_shots.is_empty() and c.get("impacts",[]).is_empty(),"正面弹丸扣2血且无格挡特效")
	await get_tree().process_frame
	await _capture_image("right_click_damage")
	_tick(0.31)
	await _mouse(MOUSE_BUTTON_RIGHT,_world(CENTER+ALONG*100))
	_check(Run.snapshot(sm).combat.get("guard_left",0)==0,"连点右键无格挡")
	await _close_scene()
	await _new_scene()
	_fixture()
	# 旧版本存档正处在格挡与碰撞特效中，读档后也不得免伤或挡住攻击。
	run=sm.data[Run.KEY]
	run.members=[run.members[0]]
	run.combat.guard_left=0.35
	run.combat.guard_reuse=0.8
	run.combat.guard_aim=Combat.pack(ALONG.normalized())
	run.combat.blocks=8
	run.combat.impacts=[{"position":Combat.pack(CENTER),"direction":Combat.pack(ALONG.normalized()),"left":0.4}]
	_check(sm.save(),"遗留格挡状态可保存")
	sm.load_data()
	_check(sm.last_load_error.is_empty() and Run.valid(Run.snapshot(sm)),"旧格挡存档恢复有效")
	flow=maze.capture_flow
	flow.skill_visual._process(0)
	_check(not flow.skill_visual.hero.visible and not flow.skill_visual.textures.has("raise") and not flow.skill_visual.textures.has("impact_sheet"),"旧档不显示举锅或加载格挡素材")
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*100))
	_check(Run.snapshot(sm).combat.throws==1,"旧格挡剩余时间不阻止左键攻击")
	var unchanged:=Run.snapshot(sm)
	_check(not Run.combat_command(sm,"guard",ALONG).get("changed",true) and Run.snapshot(sm)==unchanged,"旧格挡命令不改变状态")
	sm.data[Run.KEY].combat.enemy_shots=[{"position":Combat.pack(CENTER-ALONG*22),"direction":Combat.pack(ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
	_tick(0.05)
	_check(Run.snapshot(sm).combat.hp==34,"旧档背面弹丸按防御扣血")
	_check(not Run.snapshot(sm).combat.has("guard_left") and not Run.snapshot(sm).combat.has("impacts"),"成功事务清除旧格挡字段")
	await _close_scene()
	await _new_scene()
	_fixture()
	run=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*20)
	run.combat.actors.slime_1.mode="windup"
	run.combat.actors.slime_1.windup=0.01
	_tick(0.02)
	_check(Run.snapshot(sm).combat.hp==36,"近战由队伍3防御抵消")
	_fixture()
	run=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	var actor: Dictionary=run.combat.actors.slime_1
	actor.position=Combat.pack(CENTER+ALONG*95)
	actor.mode="chase"
	actor.skill_reuse=0.0
	_tick(0.05)
	_check(Run.snapshot(sm).combat.actors.slime_1.cast>0,"史莱姆启动蓄力预警")
	await _capture_image("slime_charge")
	for i in 14: _tick(0.05)
	_check(Run.snapshot(sm).combat.enemy_shots.size()==1,"蓄力后释放独立飞行弹")
	await _capture_image("slime_shot")
	_fixture()
	var old: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path=""
	_check(not Run.combat_command(sm,"select",1).success,"切换保存失败报告")
	_check(sm.data==old,"切换失败完整回滚")
	_check(not Run.combat_attack(sm,CENTER,ALONG).success,"攻击保存失败报告")
	_check(sm.data==old,"攻击失败完整回滚")
	sm._active_save_path=path
	_check(Run.combat_command(sm,"select",1).success,"恢复切换")
	_check(sm.save(),"新状态可保存")
	var expected: Dictionary=Run.snapshot(sm).combat
	sm.load_data()
	_check(sm.last_load_error.is_empty(),"隔离存档读档成功")
	_check(Run.snapshot(sm).combat.selected==1,"读档恢复选中技能")
	_check(Combat.valid(expected),"新增状态合法")
	var broken:=expected.duplicate(true)
	broken.actors=[]
	_check(not Combat.valid(broken),"损坏技能状态安全拒绝")
	_fixture()
	await _send_key(KEY_1)
	run=sm.data[Run.KEY]
	for id in ["slime_1","slime_2"]:
		run.monsters[id].status="alive"
		run.combat.actors[id].position=Combat.pack(CENTER+ALONG*(60 if id=="slime_1" else 110))
		run.combat.actors[id].mode="windup"
		run.combat.actors[id].windup=1.0
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*150))
	for i in 5: _tick(0.05)
	c=Run.snapshot(sm).combat
	_check(c.actors.slime_1.hp==11 and c.actors.slime_2.hp==14 and c.shots.is_empty(),"光点仅伤首个目标并消失")
	_fixture()
	await _send_key(KEY_1)
	await _mouse_state(true,_world(CENTER+ALONG*150))
	for i in 16: _tick(0.05)
	_check(Run.snapshot(sm).combat.shots.is_empty(),"光点未命中到距离后消散")
	_check(Run.snapshot(sm).combat.throws==1,"长按跨过冷却不连发")
	await _mouse_state(false,_world(CENTER+ALONG*150))
	_fixture()
	await _send_key(KEY_2)
	run=sm.data[Run.KEY]
	run.monsters.slime_1.status="alive"
	run.combat.actors.slime_1.position=Combat.pack(CENTER+ALONG*50)
	run.combat.actors.slime_1.hp=3
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*150))
	_tick(0.2)
	run=Run.snapshot(sm)
	_check(run.combat.actors.slime_1.hp==0 and run.monsters.slime_1.has("experience_generation"),"旋斧击杀进入既有经验结算")
	_check(not run.pending.is_empty() or flow.busy,"击杀进入既有捕获流程")
	await _close_scene()
	await _new_scene()
	flow=maze.capture_flow
	_fixture()
	maze._open_backpack()
	await _mouse(MOUSE_BUTTON_RIGHT,Vector2(400,300))
	await _send_key(KEY_2)
	_check(Run.snapshot(sm).combat.get("guard_left",0)==0 and Run.snapshot(sm).combat.selected==0,"弹窗拦截战斗输入")
	await _send_key(KEY_ESCAPE)
	await _mouse(MOUSE_BUTTON_LEFT,flow.skill_bar.buttons[1].get_global_rect().get_center())
	_check(Run.snapshot(sm).combat.selected==1 and Run.snapshot(sm).combat.throws==0,"按钮切换不穿透攻击")
	flow._focus_lost()
	await _mouse(MOUSE_BUTTON_LEFT,_world(CENTER+ALONG*100))
	_check(Run.snapshot(sm).combat.throws==0,"失焦不攻击")
	flow.window_focused=true
	await _sprint_checks()
	await _close_scene()
