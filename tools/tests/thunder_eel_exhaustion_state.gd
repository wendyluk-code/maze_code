extends "res://tools/tests/fenshui_heal_state.gd"
const EEL="fenshui_thunder_eel_1"
const HERO=Vector2(890,485)

func eel() -> Dictionary:
 return state().combat.actors[EEL]

func advance_until(predicate: Callable, seconds: float=12.0) -> bool:
 for i in ceili(seconds/0.05):
  if predicate.call(): return true
  var result:=Run.combat_tick(sm,HERO,0.05)
  if not result.success: return false
 return predicate.call()

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"电鳗事务验收使用独立存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HERO).success,"通过真实探索入口建立事务样例")
 # 单鳗事务隔离样例；自然七怪战斗由flow案独立验证。
 var run: Dictionary=sm.data[Run.KEY]
 for id in run.monsters: run.monsters[id].status="alive" if id==EEL else "skipped"
 run.combat.actors[EEL].position=[860.0,485.0]
 _check(Run.valid(state()),"隔离样例沿正式校验有效")
 _check(advance_until(func(): return eel().get("eel_discharges",0)==2),"通过成功保存事务实际累计两次")
 _check(advance_until(func(): return eel().eel_phase=="discharge" and eel().eel_discharges==2,4.0),"第三次已真实释放，尚未完成余段")
 # 原战斗按0.5秒检查点刷盘；明确跨检查点，不能把仅内存推进当保存失败。
 sm.data[Run.KEY].combat.checkpoint=0.49
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var failed:=Run.combat_tick(sm,HERO,0.35)
 _check(not failed.success and sm.data==before,"跨原检查点刷盘失败时第三次计数与阶段整事务回滚")
 sm._active_save_path=path
 var result:=Run.combat_tick(sm,HERO,0.35)
 _check(result.success and eel().eel_phase=="exhausted" and eel().eel_discharges==3 and is_equal_approx(float(eel().eel_left),4.0),"恢复保存后只完成一次计数并进入完整4秒力竭")
 if failures:
  _finish()
  return
 _check(Run.combat_tick(sm,HERO,0.4).success,"真实事务推进力竭剩时")
 var left: float=eel().eel_left
 var hp: float=eel().hp
 var serial: int=state().combat.electric_serial
 _check(sm.save(),"原保存入口持久化力竭")
 sm.load_data()
 _check(Run.valid(state()) and eel().eel_discharges==3 and is_equal_approx(float(eel().eel_left),left),"实际读档续接次数和剩时")
 _check(Run.combat_tick(sm,HERO,0.1).success and state().combat.electric_serial==serial and is_equal_approx(float(eel().eel_left),left-0.1),"读档不补发放电，不重启4秒")
 var dying: Dictionary=sm.data[Run.KEY].combat.actors[EEL]
 dying.hp=0.0
 before=dying.duplicate(true)
 _check(Run.combat_tick(sm,HERO,0.2).success and eel()==before,"已死亡电鳗不继续推进力竭或攻击")
 sm.data[Run.KEY].combat.actors[EEL].hp=hp
 _check(advance_until(func(): return eel().eel_phase=="forming",5.0),"恢复生命检查点后沿剩时进入成泡")
 _check(advance_until(func(): return eel().eel_discharges==0,2.0) and eel().hp==hp,"实际保存链完成恢复，清零且不回血")
 _finish()
