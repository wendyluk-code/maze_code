extends "res://tools/tests/fenshui_player_hurt_state.gd"
const Frog=preload("res://scripts/maze/wind_frog_combat.gd")
var observations: Array=[]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"水炮判定只读诊断使用隔离档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HURT_POINT).success,"建立真实七怪水炮检查点")
 original=sm.data.duplicate(true)
 for offset in [0.0,10.0,19.0,20.0,21.0,30.0,67.6]:
  sm.data=original.duplicate(true)
  var run:=state()
  var frog: Dictionary=run.combat.actors[Boss.ID]
  frog.frog_shots=[{"position":[1030.0,450.0],"direction":[1.0,0.0],"distance":0.0}]
  var hero:=Vector2(1090,450+offset)
  var events: Array=[]
  var hp: float=run.combat.hp
  Frog.advance_projectiles(run,hero,0.5,events)
  var hit: bool=run.combat.hp<hp
  observations.append({"offset":offset,"hero":str(hero),"water":Boss.water(hero),"hit":hit,"events":events.size()})
  # 20像素精确边界仅观测：原算法按不超过2像素步长离散采样，
  # 该点的最邻近采样不是线段垂足，不能将解析半径冒充精确实测阈值。
  if offset!=20.0: _check(hit==(offset<20.0),"真实水炮横向命中边界："+str(offset),observations.back())
 var a: Dictionary=state().combat.actors[Boss.ID]
 Frog.prepare_spit(a,Vector2(1000,450),Vector2(1090,450))
 _check(a.windup==0.8 and a.frog_aim==[1.0,0.0],"水炮蓄力开始锁向、前摇800毫秒")
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"observations":observations,"scope":"诊断现行规则，不调整战斗数值"},"  "))
 get_tree().quit(1 if failures else 0)
