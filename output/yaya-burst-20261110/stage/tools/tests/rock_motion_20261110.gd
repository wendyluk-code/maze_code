extends "res://tools/tests/rock_lunge_flow.gd"
const Monster=preload("res://scripts/maze/capture_monster.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离用户目录")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"探索初始化")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"盐池初始化")
 var run: Dictionary=Run.snapshot(sm)
 var a: Dictionary=run.combat.actors[Boss.ID]
 var slow:=_walk_changes(a.duplicate(true),run.combat,70.0)
 var fast:=_walk_changes(a.duplicate(true),run.combat,230.0)
 print("WALK_CHANGES slow=",slow," fast=",fast)
 _check(fast>slow,"真实显示节点步频随移动速度增加")
 var m:=_monster()
 a.mode="chase"
 a.rock_combo=true
 a.rock_chain_left=3
 a.rock_phase="lunge_recover"
 a.rock_left=0.1
 a.velocity=[0.0,0.0]
 m.sync_action(a,run.combat)
 a.rock_phase="combo_reposition"
 a.rock_orbit_left=6.0
 a.velocity=[230.0,0.0]
 m.update_motion(Vector2(230,0))
 m.sync_action(a,run.combat)
 _check(not m.rock_lunge_pose.is_empty(),"绕位进入完整姿态表")
 _check(m.rock_lunge_pose.has("entry"),"收势到绕位保留过渡来源")
 m._set_direction(0)
 m.update_motion(Vector2(230,-60))
 a.rock_phase="lunge_charge"
 a.rock_left=0.85
 a.rock_aim=[1.0,0.04]
 m.sync_action(a,run.combat)
 _check(m.facing==0,"近水平锁向不沿用临时绕位背向")
 m._process(0.03)
 var mix_before: float=m.rock_lunge_pose.get("entry_mix",1.0)
 m.sync_action(a,run.combat)
 m._process(0.03)
 _check(float(m.rock_lunge_pose.get("entry_mix",1.0))>mix_before,"重复显示同一战斗快照不重置过渡进度")
 var held: int=m.frame_index()
 m.action_paused=true
 m._process(0.2)
 _check(m.frame_index()==held,"暂停不推进显示帧")
 m.queue_free()
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("ROCK_MOTION ",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
func _monster() -> Node2D:
 var m:=Monster.new()
 m.config=Boss.row()
 add_child(m)
 m.set_process(false)
 m.enable_hit_feedback()
 m.roar_visual.queue_free()
 m.roar_visual=null
 return m
func _walk_changes(a: Dictionary,c: Dictionary,speed: float) -> int:
 var m:=_monster()
 a.mode="chase"
 a.rock_phase="active"
 a.velocity=[speed,0.0]
 m.update_motion(Vector2(speed,0))
 m.sync_action(a,c)
 var previous: int=m.frame_index()
 var changes:=0
 for i in 36:
  m._process(1.0/60.0)
  var frame: int=m.frame_index()
  if frame!=previous: changes+=1
  previous=frame
 m.queue_free()
 return changes
