extends "res://tools/tests/fenshui_target_lock_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实分水庭入场完成")
 baseline=entry_snapshot.duplicate(true)
 await reset_fixture(Vector2(880,490))
 var run:=state()
 var frog: Dictionary=run.combat.actors[Boss.ID]
 frog.frog_phase="dormant"
 frog.mode="idle"
 frog.frog_left=0.0
 frog.hp=95.0 if _arg("--phase=")=="hurt" else 96.0
 frog.frog_heal_quiet=0.0
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"满血待机输入为合法隔离探索档")
 _check(maze.capture_flow.monsters[Boss.ID].is_visible_in_tree() and maze.capture_flow.visible_world_rect().has_point(Run.Combat.vec(frog.position)),"满血巨蛙实际可见且地面点在视口内")
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(maze.capture_flow.locked_target_id==Boss.ID,"可见满血待机巨蛙可经真实Tab锁定",{"actual":maze.capture_flow.locked_target_id,"phase":frog.frog_phase,"hp":frog.hp})
 if failures: return
 await picture("full_health_frog_locked")
 await healed_to_full()
 if failures: return
 await attack_and_jump()

func healed_to_full() -> void:
 maze.player.position=Vector2(1100,440)
 maze.camera.snap_to_target()
 var run:=state()
 run.combat.actors[Boss.ID].hp=95.0
 run.combat.actors[Boss.ID].frog_heal_quiet=2.0
 sm.data[Run.KEY]=run
 var result:=Run.combat_tick(sm,maze.player.position,0.1)
 _check(result.success and is_equal_approx(float(actor().hp),96.0),"原公开事务真实回血到满血，不直接写满血结果",result)
 maze.capture_flow.set_process(true)
 await get_tree().process_frame
 await get_tree().process_frame
 _check(maze.capture_flow.locked_target_id==Boss.ID,"巨蛙实际回满血后保持原锁定")
 maze.capture_flow.set_process(false)
 await key(KEY_Q)
 _check(maze.capture_flow.locked_target_id.is_empty(),"Q仍立即解除巨蛙锁定")
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(maze.capture_flow.locked_target_id==Boss.ID,"回满血后仍可再次Tab选中")

func attack_and_jump() -> void:
 maze.player.position=Vector2(880,490)
 maze.camera.snap_to_target()
 maze.capture_flow.set_process(true)
 await key(KEY_SPACE)
 var throws: int=state().combat.throws
 await click()
 _check(await until_true(func(): return actor().hp<96.0,1.0),"锁定后真实锅铲能命中满血巨蛙")
 _check(state().combat.throws==throws+1,"锁定满血巨蛙没有吞掉原出手")
 var seen: Dictionary={}
 var held:=true
 var deadline:=Time.get_ticks_msec()+7000
 while Time.get_ticks_msec()<deadline:
  var frog:=actor()
  seen[frog.frog_phase]=true
  if frog.mode!="return" and maze.capture_flow.locked_target_id!=Boss.ID: held=false
  if seen.has("airborne") and seen.has("landing"): break
  await get_tree().process_frame
 _check(seen.has("airborne") and seen.has("landing"),"真实七怪战斗覆盖自然起跳和落地",seen)
 _check(held and maze.capture_flow.locked_target_id==Boss.ID,"自然起跳及落地不会无故脱锁")
 _check(Run.valid(state()),"锁定、回血和实际命中后探索档保持合法")
 await picture("natural_landing_locked")
