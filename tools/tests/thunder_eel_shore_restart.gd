extends "res://tools/previews/fenshui_borrow_lightning.gd"
## 独立进程恢复正式雷鳗；不离线推进计时。
const PHASES=["charging","stranded","returning","forming"]
const EEL="fenshui_thunder_eel_1"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"雷鳗跨进程使用隔离存档")
 if _arg("--phase=")=="seed":
  _completed()
  sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
  sm.cancel_maze_entry()
  _check(Run.begin(sm,Roads.SPAWN).success,"建立真实探索")
  _check(Run.change_region(sm,"fenshui",Vector2(781,475)).success,"进入正式分水庭")
  var run: Dictionary=Run.snapshot(sm)
  for id in run.monsters: run.monsters[id].status="alive" if id==EEL else "skipped"
  run.combat.actors[EEL].position=[860.0,485.0]
  run.combat.actors[EEL].hp=7.0
  run.bag={"thunder_eel_belly":2}
  sm.data[Run.KEY]=run
  var expected: Dictionary={}
  for phase in PHASES:
   sm._active_save_path="user://eel-"+phase+".json"
   var hero:=Vector2(890,485) if phase=="charging" else Vector2(781,475)
   for i in 300:
    if Run.snapshot(sm).combat.actors[EEL].get("eel_phase","")==phase: break
    if not Run.combat_tick(sm,hero,0.05).success:
     _check(false,"阶段事务推进失败："+phase)
     break
   var saved: Dictionary=Run.snapshot(sm)
   _check(saved.combat.actors[EEL].get("eel_phase","")==phase and Run.valid(saved),"真实推进到可存阶段："+phase)
   _check(sm.save(),"阶段保存："+phase)
   expected[phase]=JSON.parse_string(JSON.stringify(saved))
  FileAccess.open("user://eel-expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
 else:
  var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://eel-expected.json"))
  for phase in PHASES:
   sm._active_save_path="user://eel-"+phase+".json"
   sm.load_data()
   var run: Dictionary=Run.snapshot(sm)
   _check(run==expected[phase] and Run.valid(run),"新进程精确恢复生命位置阶段剩余时间："+phase)
   var raw: Dictionary=sm.data.duplicate(true)
   var path: String=sm._active_save_path
   sm._active_save_path=""
   _check(not Run.combat_tick(sm,Vector2(781,475),0.5).success and sm.data==raw,"保存失败恢复最后成功检查点："+phase)
   sm._active_save_path=path
   _check(Run.combat_tick(sm,Vector2(781,475),0.05).success,"新进程继续原阶段事务："+phase)
   var after: Dictionary=Run.snapshot(sm)
   _check(after.combat.actors[EEL].hp==7 and after.bag==run.bag and after.satiety==run.satiety,"恢复不回血不重复奖励或捕获费："+phase)
   if phase in ["stranded","returning"]:
    _check(after.combat.hp==run.combat.hp and after.combat.actors[EEL].windup==0,"岸上读档不恢复放电："+phase)
  for i in 30: Run.combat_tick(sm,Vector2(1560,218),0.1)
  var before: Dictionary=Run.snapshot(sm)
  _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success and Run.change_region(sm,"fenshui",Vector2(1560,218)).success,"同趟可离开再返回分水庭")
  _check(Run.snapshot(sm).combat.actors[EEL]==before.combat.actors[EEL] and Run.snapshot(sm).bag==before.bag,"跨区往返保留雷鳗伤害阶段及携物")
 _report_and_quit()
