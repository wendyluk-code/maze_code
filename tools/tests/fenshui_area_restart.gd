extends "res://tools/previews/fenshui_borrow_lightning.gd"
const EEL="fenshui_thunder_eel_1"
const FISH="fenshui_silverfish_1"
const FISH2="fenshui_silverfish_2"
const HERO=Vector2(781,475)

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"范围借电跨进程隔离存档")
 if _arg("--phase=")=="seed": await seed_area()
 else: await restore_area()
 _report_and_quit()

func seed_area() -> void:
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"建立真实探索")
 _check(Run.change_region(sm,"fenshui",HERO).success,"进入正式分水庭")
 _check(Run.combat_tick(sm,HERO,0.02).success,"先完成入图的既有布局与教程同步，不借迁移触发放电保存")
 var run: Dictionary=Run.snapshot(sm)
 run.combat.fs01_trial=false
 for id in run.monsters: run.monsters[id].status="alive" if id in [EEL,FISH,FISH2] else "skipped"
 run.combat.actors[EEL].position=[980.0,440.0]
 for pair in [[FISH,Vector2(930,440)],[FISH2,Vector2(1030,440)]]:
  var a: Dictionary=run.combat.actors[pair[0]]
  a.position=Run.Combat.pack(pair[1])
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  a.fish_phase="recover"
  a.fish_left=2.5
 Run.Combat.advance(run,HERO,0.02)
 var eel: Dictionary=run.combat.actors[EEL]
 eel.eel_phase="charging"
 eel.eel_left=0.01
 eel.mode="windup"
 eel.windup=0.01
 eel.cooldown=2.0
 run.combat.checkpoint=0.0
 sm.data[Run.KEY]=run
 sm._active_save_path="user://area-charging.json"
 _check(sm.save() and Run.valid(run),"保存正式蓄电前置状态")
 var before: Dictionary=sm.data.duplicate(true)
 var expected: Dictionary={"charging":JSON.parse_string(JSON.stringify(Run.snapshot(sm)))}
 sm._active_save_path=""
 var failed: Dictionary=Run.combat_tick(sm,HERO,0.02)
 _check(not failed.success and sm.data==before,"只伤鱼且玩家无损的放电保存失败也全量回滚")
 sm.data=before
 sm._active_save_path="user://area-discharge.json"
 _check(Run.combat_tick(sm,HERO,0.02).success,"只伤鱼的放电提交既有事务")
 var after: Dictionary=Run.snapshot(sm)
 _check(after.combat.actors[FISH].hp==15 and after.combat.actors[FISH2].hp==15 and after.combat.hp==run.combat.hp,"岸上玩家免电，两鱼各受一次5点")
 _check(FileAccess.file_exists(sm._active_save_path),"释放事件不等0.5秒检查点即落盘")
 expected.discharge=JSON.parse_string(JSON.stringify(after))
 FileAccess.open("user://area-expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))

func restore_area() -> void:
 var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://area-expected.json"))
 for phase in ["charging","discharge"]:
  sm._active_save_path="user://area-"+phase+".json"
  sm.load_data()
  var before: Dictionary=Run.snapshot(sm)
  _check(before==expected[phase] and Run.valid(before),"新进程恢复完整生命位置阶段与计时："+phase)
  if not before.has("combat"): continue
  _check(Run.combat_tick(sm,HERO,0.02).success,"新进程继续范围阶段："+phase)
  var after: Dictionary=Run.snapshot(sm)
  var hp: float=before.combat.actors[FISH].hp
  _check(after.combat.actors[FISH].hp==hp-(5 if phase=="charging" else 0),"预警只结算一次，已释放恢复不补伤："+phase)
  _check(after.bag==before.bag and after.satiety==before.satiety,"恢复不扣捕获费不发奖励："+phase)
  _check(after.combat.actors[FISH].get("electric_left",0)>3.9,"恢复破膜剩时不按离线墙钟推进："+phase)
