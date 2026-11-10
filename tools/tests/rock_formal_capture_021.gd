extends "res://tools/tests/rock_lunge_flow.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"捕获及结算使用隔离存档")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"正式探索开始")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"正式入口进入盐池")
 var run: Dictionary=Run.snapshot(sm)
 var hero:=Vector2(930,420)
 _check(Salt.is_walkable(hero),"攻击者位于合法地面")
 for id in run.monsters:
  if id!=Boss.ID: run.monsters[id].status="skipped"
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=Run.Combat.pack(Boss.HOME)
 a.mode="chase"
 a.hp=1.0
 a.rock_phase="rest"
 a.rock_left=5.0
 run.combat.cooldown=0.0
 run.combat.hero=Run.Combat.pack(hero)
 run.monsters[Boss.ID].copy_roll=0.99
 sm.data[Run.KEY]=run
 _check(Run.valid(run),"弱点及低生命测试状态有效")
 _check(Run.combat_attack(sm,hero,hero.direction_to(Boss.HOME)).success,"通过正式攻击事务出手")
 var steps_ok:=true
 for i in 20:
  if float(Run.snapshot(sm).combat.actors[Boss.ID].hp)<=0: break
  if not Run.combat_tick(sm,hero,0.05).success:
   steps_ok=false
   break
 _check(steps_ok and float(Run.snapshot(sm).combat.actors[Boss.ID].hp)<=0,"实际飞行攻击在弱点期击败岩鬃兽")
 if steps_ok and float(Run.snapshot(sm).combat.actors[Boss.ID].hp)<=0:
  _check(Run.defeat(sm,Boss.ID,hero).success,"击败后进入正式待捕获事务")
  _check(Run.start_capture(sm,Boss.ID).success,"正式捕获扣费")
  _check(Run.finish_capture(sm,Boss.ID,true).success,"捕获操作结论保存")
  var caught: Dictionary=Run.resolve(sm,Boss.ID,true)
  _check(caught.get("success",false) and caught.get("caught",false),"首次岩鬃兽正式捕获成功")
  _check(Run.snapshot(sm).bag.get("rockmane_meat",0)==1,"岩鬃肉进入探索暂存袋")
  for i in 8:
   if not Run.portal_combat_locked(sm): break
   _check(Run.combat_tick(sm,hero,0.05).success,"等待攻击动作自然结束")
  var bank:=Run.finish(sm,true,Salt.ENTRANCE)
  _check(bank.success,"正式出口结算返回餐厅",{"result":bank})
  _check(sm.warehouse_snapshot().get("rockmane_meat",0)>=1,"岩鬃肉实际进入餐厅仓库")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("ROCK_CAPTURE_021 ",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
