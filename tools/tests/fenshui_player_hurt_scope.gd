extends "res://tools/tests/fenshui_player_hurt_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"受击范围检查使用正式入口")
 await begin_hurt("fish")
 var previous: Node=maze.capture_flow.player_hurt_visual
 maze.queue_free()
 await get_tree().process_frame
 _check(not is_instance_valid(previous),"真实场景退出释放受击消费者，不留下跨场景图层")
 for region in ["maze_entry","salt_pool","trial","sparring","fenshui"]:
  sm.data=entry_snapshot.duplicate(true)
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  var path: String="res://scenes/maze_fenshui.tscn"
  if region in ["maze_entry","salt_pool"]:
   var point: Vector2=Roads.SPAWN if region=="maze_entry" else preload("res://data/maze/salt_pool_roads.gd").SPAWN
   _check(Run.change_region(sm,region,point).success,"原换区事务建立非目标入口："+region)
   path="res://scenes/maze_entry.tscn" if region=="maze_entry" else "res://scenes/maze_salt_pool.tscn"
  elif region=="trial": sm.data[Run.KEY].combat.fs01_trial=true
  elif region=="sparring": sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"question","line":0}
  maze=load(path).instantiate()
  viewport.add_child(maze)
  _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实范围回归场景入场："+region)
  maze.capture_flow.window_focused=true
  await get_tree().process_frame
  await get_tree().process_frame
  var visual: Node=maze.capture_flow.player_hurt_visual
  if region in ["maze_entry","salt_pool","fenshui"]:
   _check(maze.capture_flow.character_combat_enabled() and is_instance_valid(visual) and not visual.active(),"正常地图创建干净共用受击消费者，不重播旧命中："+region)
  else:
   _check(not maze.capture_flow.target_lock_enabled() and (not is_instance_valid(visual) or not visual.active()),"旧试玩及剧情不启用正常探索新受击："+region)
   if region!="sparring": _check(visual==null,"非目标场景不安装新图层："+region)
   maze.capture_flow._flash_body(maze.player.body,0.1)
   _check(maze.player.body.material!=null and maze.player.body.material.get_shader_parameter("flash"),"非目标模式保留原玩家白闪："+region)
  maze.queue_free()
  await get_tree().process_frame
