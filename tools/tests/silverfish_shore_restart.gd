extends "res://tools/previews/fenshui_borrow_lightning.gd"
## 两个独立进程使用同一隔离档；由Run真实推进生成四个阶段检查点。
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const PHASES=["warning","stranded","returning","forming"]
const ID="fenshui_silverfish_1"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"四阶段跨进程测试使用隔离存档")
 var mode:=_arg("--phase=")
 if mode=="seed":
  _completed()
  sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
  sm.cancel_maze_entry()
  _check(Run.begin(sm,Roads.SPAWN).success,"建立真实探索")
  _check(Run.change_region(sm,"fenshui",Vector2(781,475)).success,"正式分水庭岸线进入")
  var run: Dictionary=Run.snapshot(sm)
  for id in run.monsters: run.monsters[id].status="alive" if id==ID else "skipped"
  run.combat.actors[ID].position=[860.0,485.0]
  run.combat.actors[ID].hp=7.0
  run.bag={"silverfish_meat":2}
  sm.data[Run.KEY]=run
  var expected: Dictionary={}
  for phase in PHASES:
   sm._active_save_path="user://fish-"+phase+".json"
   for i in 300:
    if Run.snapshot(sm).combat.actors[ID].get("fish_phase","")==phase: break
    if not Run.combat_tick(sm,Vector2(781,475),0.05).success:
     _check(false,"阶段推进真实保存失败："+phase)
     break
   var saved: Dictionary=Run.snapshot(sm)
   _check(saved.combat.actors[ID].get("fish_phase","")==phase and Run.valid(saved),"真实推进到可保存阶段："+phase)
   _check(sm.save(),"阶段完整存盘："+phase)
   expected[phase]=JSON.parse_string(JSON.stringify(saved))
  FileAccess.open("user://fish-expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
 else:
  var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://fish-expected.json"))
  for phase in PHASES:
   sm._active_save_path="user://fish-"+phase+".json"
   sm.load_data()
   var run: Dictionary=Run.snapshot(sm)
   _check(run==expected[phase] and Run.valid(run),"新进程恢复位置生命阶段与剩余时间："+phase)
   var raw: Dictionary=sm.data.duplicate(true)
   var path: String=sm._active_save_path
   sm._active_save_path=""
   _check(not Run.combat_tick(sm,Vector2(781,475),0.05).success and sm.data==raw,"保存失败完整回滚阶段生命奖励："+phase)
   sm._active_save_path=path
   _check(Run.combat_tick(sm,Vector2(781,475),0.05).success,"恢复阶段可以继续原事务："+phase)
   var after: Dictionary=Run.snapshot(sm)
   _check(after.combat.actors[ID].hp==7 and after.bag==run.bag and after.satiety==run.satiety,"恢复推进不回血不重发奖励不扣捕获费："+phase)
  for i in 30: Run.combat_tick(sm,Vector2(1560,218),0.1)
  var before_travel: Dictionary=Run.snapshot(sm)
  _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"鱼脱战后可以正常离开分水庭")
  _check(Run.change_region(sm,"fenshui",Vector2(1560,218)).success,"同一趟可返回分水庭")
  var returned: Dictionary=Run.snapshot(sm)
  _check(returned.combat.actors[ID]==before_travel.combat.actors[ID] and returned.monsters[ID]==before_travel.monsters[ID] and returned.bag==before_travel.bag,"同趟跨区往返保留鱼伤害阶段及处理状态")
 _report_and_quit()
