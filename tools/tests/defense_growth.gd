extends "res://tools/tests/combat_skill_01.gd"
const Growth = preload("res://scripts/characters/character_progression.gd")
func _combat_scene() -> void:
	await _new_scene()
	_fixture()
	var dialog = preload("res://scripts/ui/components/character_details_modal.gd").new()
	maze._ui_root.add_child(dialog)
	await get_tree().process_frame
	maze.set_process(false)
	if is_instance_valid(maze._prompt_host): maze._prompt_host.hide()
	maze.capture_flow.skill_bar.hide()
	maze.capture_flow.controls_hint.hide()
	for level in [1, 15, 30]:
		for id in ["yaya", "tieshan"]:
			var entries: Dictionary = sm.data.get(Growth.KEY, {}).duplicate(true)
			entries[id] = {"level":level,"rank":1,"exp":0,"breakthroughs":mini(5,floori((level-1)/5.0))}
			sm.data[Growth.KEY] = entries
			_fixture()
			var run: Dictionary = sm.data[Run.KEY]
			var slot := 1 if id == "yaya" else 2
			Run.combat_command(sm,"select",slot)
			_check(Run.combat_attack(sm,CENTER,ALONG).get("success",false),"成长技能实际事务发射")
			run = sm.data[Run.KEY]
			var progress := float(level-1)/29.0
			var interval := lerpf(0.42,0.30,progress) if id == "yaya" else lerpf(0.80,0.60,progress)
			_check(is_equal_approx(run.combat.cooldown,interval),"各等级实际攻击间隔")
			var damage := roundi(3.0*(1.0+0.5*progress))
			_check((run.combat.shots[0].damage if id == "yaya" else run.combat.axe_damage)==damage,"各等级伤害整数四舍五入")
			run.monsters.slime_1.status = "alive"
			run.combat.actors.slime_1.position = Combat.pack(CENTER+ALONG*40)
			run.combat.actors.slime_1.mode = "windup"
			run.combat.actors.slime_1.windup = 1.0
			Skills.select(run,0)
			Combat.advance(run,CENTER,0.2)
			_check(run.combat.actors.slime_1.hp == 14-damage,"切换后已释放光点或旋斧保持原伤害")
			dialog.present(id)
			_check(dialog.defense_value.text == str(level*(1 if id=="yaya" else 2)),"详情显示等级防御")
			_check(dialog.active_damage.text.contains("150%") if level==30 else not dialog.active_damage.text.is_empty(),"详情成长倍率")
			_check(sm.save(),"成长状态保存")
			sm.load_data()
			_check(Combat.valid(Run.snapshot(sm).combat),"成长状态读档合法")
			await _capture_image("growth_"+id+"_"+str(level))
	_fixture()
	var run: Dictionary = sm.data[Run.KEY]
	run.combat.skill_levels = {"yaya":1,"tieshan":1}
	_check(Skills.defense(run)==3,"队伍防御汇总")
	_check(Skills.incoming_damage(run,8)==5 and Skills.incoming_damage(run,2)==0,"抵扣伤害且不倒扣加血")
	# 单角色队伍：背面弹丸与近战分别造成3-1=2；举锅不保护近战。
	var original_members: Array = run.members.duplicate(true)
	run.members = [run.members[0]]
	run.combat.guard_left = 0.35
	run.combat.guard_aim = Combat.pack(ALONG)
	run.combat.enemy_shots = [{"position":Combat.pack(CENTER-ALONG*22),"direction":Combat.pack(ALONG.normalized()),"distance":0.0,"source":"slime_1"}]
	Combat.advance(run,CENTER,0.05)
	_check(run.combat.hp==34,"背面技能实际扣除防御后伤害")
	run.monsters.slime_1.status = "alive"
	run.combat.actors.slime_1.position = Combat.pack(CENTER+ALONG*20)
	run.combat.actors.slime_1.mode = "windup"
	run.combat.actors.slime_1.windup = 0.01
	Combat.advance(run,CENTER,0.02)
	_check(run.combat.hp==32,"举锅时普攻仍按防御抵扣伤害")
	run.members = original_members
	# 真实击杀经验跨级，验证事务中同步新等级及其防御。
	sm.data[Growth.KEY].yaya = {"level":1,"rank":1,"exp":490,"breakthroughs":0}
	sm.data[Growth.KEY].tieshan = {"level":1,"rank":1,"exp":0,"breakthroughs":0}
	_fixture()
	run = sm.data[Run.KEY]
	run.monsters.slime_1.status = "alive"
	run.combat.actors.slime_1.position = Combat.pack(CENTER+ALONG*40)
	run.combat.actors.slime_1.hp = 3
	Run.combat_command(sm,"select",2)
	Run.combat_attack(sm,CENTER,ALONG)
	_check(Run.combat_tick(sm,CENTER,0.2).success,"击杀经验事务成功")
	run = Run.snapshot(sm)
	_check(Growth.record(sm,"yaya").level==2 and Skills.level_for(run,"yaya")==2 and Skills.defense(run)==4,"击杀升级立即同步技能等级与防御")
	run.combat.erase("skill_levels")
	_check(Combat.valid(run.combat) and Skills.defense(run)==3,"旧档缺少新字段可按入场等级读取")
	Skills.sync_levels(run,sm)
	_check(Skills.defense(run)==4,"旧档同步当前成长")
	run.combat.skill_levels.yaya = -1
	_check(not Combat.valid(run.combat),"损坏技能等级拒绝")
	dialog.queue_free()
	await _close_scene()
