extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Encounters=preload("res://data/maze/salt_pool_encounters.gd")
const Boss=preload("res://data/maze/salt_boss.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"正式盐池检查使用隔离存档")
 if failures==0:
  _completed()
  sm.cancel_maze_entry()
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  _check(Run.begin(sm,Roads.SPAWN).success,"真实探索开始")
  _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实探索事务进入盐池")
  var expected_lunge:=_arg("--expect-lunge=")
  if not expected_lunge.is_empty():
   _check(is_equal_approx(Run.Combat.Rock.Tuning.number("rock.lunge","charge",-1.0),expected_lunge.to_float()),"当前游戏资源包读取已保存的岩鬃兽蓄力参数")
  var viewport:=SubViewport.new()
  viewport.size=Vector2i(1280,720)
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  get_tree().root.add_child(viewport)
  var maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
  viewport.add_child(maze)
  await get_tree().process_frame
  await get_tree().process_frame
  maze.capture_flow.set_process(false)
  _check(maze.capture_flow.monsters.size()==7 and maze.capture_flow.monsters.has(Boss.ID),"正式盐池生成六只普通怪和岩鬃兽")
  _check(maze.capture_flow.monsters[Boss.ID].label.text=="ATK:12","正式场景攻击标签显示用户保存的岩鬃兽基础攻击12")
  var base: Dictionary=Run.snapshot(sm)
  for kind in ["mimic_crab","blind_scorpion"]:
   var row: Dictionary={}
   for candidate in Encounters.all():
    if candidate.kind==kind: row=candidate; break
   _check(not row.is_empty(),"正式区域包含怪物："+kind)
   if row.is_empty(): continue
   var run: Dictionary=base.duplicate(true)
   for id in run.monsters:
    if id!=row.id: run.monsters[id].status="skipped"
   var actor: Dictionary=run.combat.actors[row.id]
   actor.mode="windup"
   actor.windup=float(Run.Combat.STATS[kind].windup)
   var point: Vector2=row.position+Vector2(0,25) if kind=="mimic_crab" else row.position+Vector2(0,-25)
   actor.attack_aim=[0.0,-1.0]
   _check(Salt.is_walkable(point),"攻击检查站位合法："+kind)
   var hp: float=run.combat.hp
   Run.Combat.advance(run,point,float(actor.windup)*0.5)
   _check(run.combat.hp==hp,"前摇尚未命中："+kind)
   Run.Combat.advance(run,point,float(Run.Combat.STATS[kind].windup)*0.5+0.01)
   _check(run.combat.hp<hp,"真实怪物攻击状态推进后扣血："+kind)
  var crab: Dictionary=Encounters.all()[0]
  maze.player.position=crab.position+Vector2(0,45)
  maze.camera.snap_to_target()
  await get_tree().process_frame
  RenderingServer.force_draw(false)
  viewport.get_texture().get_image().save_png(_arg("--output-dir=").path_join("salt-scene.png"))
  viewport.queue_free()
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"  "))
 get_tree().quit(1 if failures else 0)
