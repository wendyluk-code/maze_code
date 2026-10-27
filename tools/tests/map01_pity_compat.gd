extends "res://tools/tests/maze_capture.gd"
var service
const FS = preload("res://data/maze/fenshui_roads.gd")
func prepare(kind: String, passed: bool, roll := 0.99) -> String:
 if service.snapshot(sm).get("active",false): _check(service.finish(sm,false,Roads.SPAWN).success,"结束探索保留全局计数")
 sm.data[service.Progression.FOOD_KEY].values={"yaya":2.0,"tieshan":1.0}
 _check(service.begin(sm,Roads.SPAWN).success,"创建下一趟")
 var id := kind+"_1"
 if kind in ["silverfish","thunder_eel","wind_frog"]:
  _check(service.change_region(sm,"fenshui",FS.SPAWN).success,"进入区域建立鱼鳗")
  id="fenshui_"+id
 if kind in ["mimic_crab","blind_scorpion","rockmane"]:
  _check(service.change_region(sm,"salt_pool",preload("res://data/maze/salt_pool_roads.gd").SPAWN).success,"进入盐池建立蟹蝎")
  id="salt_pool_"+id
 var run: Dictionary=sm.data[service.KEY]
 sm.data[service.ROCK_FIRST]=true
 run.first_eligible=false
 run.monsters[id].capture_roll=roll
 run.combat.actors[id].hp=0
 if kind=="wind_frog": run.combat.actors[id].frog_phase="active"
 _check(service.defeat(sm,id,service.monster_for(run,id).position).success,"击败"+kind)
 _check(service.start_capture(sm,id).success,"扣费"+kind)
 _check(service.finish_capture(sm,id,passed).success,"记录操作"+kind)
 return id
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 service=load(OS.get_environment("MAP01_COMPAT_RUN") if not OS.get_environment("MAP01_COMPAT_RUN").is_empty() else "res://scripts/maze/capture_run.gd")
 _check(_verify_isolation(),"隔离正式存档")
 _check(service.has_method("failure_streak"),"需要主区新增失败计数接口")
 if failures==0:
  _fresh()
  for kind in Catalog.capture_kinds():
   for attempt in 3:
    var id := prepare(kind,attempt%2==0)
    _check(not service.resolve(sm,id,true).caught,"前三次失败"+kind)
    sm.load_data()
    _check(service.failure_streak(sm,kind)==attempt+1,"跨趟读档累计"+kind)
   var id := prepare(kind,false)
   var before: Dictionary=sm.data.duplicate(true)
   var path: String=sm._active_save_path
   sm._active_save_path=""
   _check(not service.resolve(sm,id,true).success and sm.data==before,"保底保存失败回滚"+kind)
   sm._active_save_path=path
   var result: Dictionary=service.resolve(sm,id,true)
   _check(result.caught and service.failure_streak(sm,kind)==0,"第四次沿原契约成功清零"+kind)
   _check(not service.resolve(sm,id,true).success,"不重复领奖"+kind)
  sm.data[service.PITY_KEY]={"silverfish":2,"thunder_eel":3,"snail":1}
  var id := prepare("beetle",false)
  _check(not service.resolve(sm,id,true).caught,"首区失败结算")
  _check(service.failure_streak(sm,"silverfish")==2 and service.failure_streak(sm,"thunder_eel")==3 and service.failure_streak(sm,"snail")==1,"结算首区不丢鱼鳗及其他种类计数")
  id=prepare("silverfish",true,0.0)
  _check(service.resolve(sm,id,true).caught and service.failure_streak(sm,"silverfish")==0 and service.failure_streak(sm,"thunder_eel")==3,"鱼正常成功只清自身")
  id=prepare("thunder_eel",false)
  # 已支付流程不允许改成放弃；保底仍需正常支付。
  _check(not service.resolve(sm,id,false).success and service.failure_streak(sm,"thunder_eel")==3,"付费后不能绕过结算消耗保底")
 var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
 get_tree().quit(1 if failures else 0)
