extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const FISH="fenshui_silverfish_1"
var baseline: Dictionary

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"脚底占位事务使用隔离档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"真实建立探索")
 _check(Run.change_region(sm,"fenshui",Vector2(1035,405)).success,"进入真实七怪分水庭")
 baseline=sm.data.duplicate(true)
 var run:=state()
 run.combat.actors[Boss.ID].frog_phase="active"
 run.combat.actors[Boss.ID].frog_left=1.2
 var a: Dictionary=run.combat.actors[FISH]
 a.position=[1065.0,405.0]
 a.fish_phase="rush"
 a.fish_left=0.5
 a.fish_origin=a.position.duplicate()
 a.fish_aim=[-1.0,0.0]
 a.fish_hit=false
 a.mode="chase"
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"鱼原锁向冲刺检查点有效")
 var hp: float=run.combat.hp
 for i in 5:
  _check(Run.combat_tick(sm,Vector2(1035,405),0.05,Rect2(0,0,1715,917)).success,"冲刺从公开战斗事务推进："+str(i))
 _check(Run.Combat.vec(state().combat.actors[FISH].position).x>=1051.9,"鱼冲刺被玩家脚底阻挡而不穿过",{"fish":state().combat.actors[FISH].position})
 _check(state().combat.hp<hp and state().combat.actors[FISH].fish_hit,"碰撞不放大原18像素冲刺判定，原冲刺仍实际命中")
 sm.data=baseline.duplicate(true)
 run=state()
 var frog: Dictionary=run.combat.actors[Boss.ID]
 frog.frog_phase="active"
 frog.frog_left=0.0
 sm.data[Run.KEY]=run
 _check(Run.combat_tick(sm,Vector2(880,490),0.05,Rect2(0,0,1715,917)).success,"通过真实事务选择巨蛙新落点")
 var target:=Run.Combat.vec(actor().frog_target)
 _check(actor().frog_phase=="warning" and target.distance_to(Vector2(880,490))>24.0,"巨蛙有合法靠近落点但不预定玩家脚底中心",{"target":str(target),"phase":actor().frog_phase})
 sm.data=baseline.duplicate(true)
 run=state()
 frog=run.combat.actors[Boss.ID]
 frog.frog_phase="active"
 frog.frog_left=0.0
 var close_fish: Dictionary=run.combat.actors[FISH]
 close_fish.position=[940.0,450.0]
 close_fish.fish_origin=close_fish.position.duplicate()
 close_fish.fish_phase="recover"
 close_fish.fish_left=2.5
 close_fish.fish_aim=[1.0,0.0]
 close_fish.fish_hit=false
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"旧档鱼蛙AI间距重叠但地形合法")
 _check(Boss.water(Vector2(880,490)),"旧重叠恢复目标确在可追击水域，不使用保护区样例")
 _check(Run.combat_tick(sm,Vector2(880,490),0.05,Rect2(0,0,1715,917)).success,"旧重叠经公开事务重新选路")
 _check(actor().frog_phase=="warning" and Run.Combat.vec(actor().frog_target).distance_to(Vector2(900,450))>24.0,"旧重叠巨蛙仍可向外跳出，不因起点占位永久拒绝",{"frog":actor()})
 await monster_spacing_and_release()
 _finish()

func monster_spacing_and_release() -> void:
 sm.data=baseline.duplicate(true)
 var run:=state()
 run.combat.actors[Boss.ID].frog_phase="active"
 run.combat.actors[Boss.ID].frog_left=1.2
 var moving: Dictionary=run.combat.actors[FISH]
 moving.fish_phase="rush"
 moving.fish_left=0.5
 moving.fish_origin=moving.position.duplicate()
 moving.fish_aim=[-1.0,0.0]
 moving.fish_hit=false
 moving.mode="chase"
 var second: Dictionary=run.combat.actors["fenshui_silverfish_2"]
 second.position=[1010.0,405.0]
 second.fish_origin=second.position.duplicate()
 second.fish_phase="recover"
 second.fish_left=2.5
 second.fish_aim=[1.0,0.0]
 second.fish_hit=false
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"多怪相遇检查点保留七怪且地形合法")
 for i in 3: _check(Run.combat_tick(sm,Vector2(1185,405),0.05,Rect2(0,0,1715,917)).success,"怪物相遇真实推进："+str(i))
 var before:=Run.Combat.vec(state().combat.actors[FISH].position)
 _check(before.x>=1060.9,"活鱼彼此保留原避让距离，不互穿")
 run=state()
 run.combat.actors["fenshui_silverfish_2"].hp=0
 moving=run.combat.actors[FISH]
 moving.fish_phase="rush"
 moving.fish_left=0.5
 sm.data[Run.KEY]=run
 for i in 3: _check(Run.combat_tick(sm,Vector2(1185,405),0.05,Rect2(0,0,1715,917)).success,"死亡占位释放后继续推进："+str(i))
 _check(Run.Combat.vec(state().combat.actors[FISH].position).x<before.x-8.0,"另一只怪物死亡即解除阻挡，不等待捕获结算")
