extends "res://tools/tests/fenshui_heal_state.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 _check(_verify_isolation(),"快速回血通过隔离探索事务验收")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",SAFE).success,"建立原分水庭探索")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.hp=24.0
 a.position=[1040.0,450.0]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.frog_phase="dormant"
 a.mode="idle"
 a.frog_left=0.0
 a.frog_heal_quiet=0.0
 _check(Run.valid(state()),"快速回血检查点合法，未改最大生命")
 for i in 20: _check(Run.combat_tick(sm,SAFE,0.1).success,"原事务累计未受击门槛")
 _check(is_equal_approx(float(actor().hp),24.0),"原2秒未受击门槛保持，不追补")
 for i in 6: _check(Run.combat_tick(sm,SAFE,0.5).success,"原事务连续恢复")
 _check(is_equal_approx(float(actor().hp),72.0),"开始回血后3秒恢复最大生命的一半：24到72",{"hp":actor().hp})
 for i in 4: Run.combat_tick(sm,SAFE,0.5)
 _check(actor().hp==96.0,"高速恢复达到满血仍封顶96")
 _finish()
