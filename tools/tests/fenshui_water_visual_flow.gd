extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const FS=preload("res://data/maze/fenshui_roads.gd")
var measurements: Array=[]

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"水体适配沿真实七怪入口")
 var water: Node=maze.get_node_or_null("FenshuiWaterVisual")
 _check(water!=null,"正式场景安装已认可水体适配")
 if water==null: return
 maze.capture_flow.set_process(false)
 maze.player.position=Vector2(1090,450)
 var before:=state()
 _check(await until_true(func(): return water.depth>0.8,0.8),"合法浅水渐进浸没")
 _check(maze.player.position==Vector2(1090,450) and state()==before,"下沉仅显示，不改玩家脚底或存档")
 _check(maze.player.body.position.y>0 and water.reflection.visible,"水中身体下沉并出现淡倒影")
 await picture("wet")
 var clock: float=water.clock
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实原地图入口暂停")
 clock=water.clock
 var depth: float=water.depth
 await get_tree().create_timer(0.25).timeout
 _check(water.clock==clock and water.depth==depth and maze.player.body.position.y>0,"暂停冻结水体及浸没，不重置身体高度")
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"关闭地图恢复")
 maze.capture_flow.set_process(false)
 for i in FS.LOW_ISLANDS:
  var island: Vector4=FS.ISLANDS[i]
  maze.player.position=Vector2(island.x,island.y)
  _check(await until_true(func(): return water.depth<0.05,0.8),"七台能自然出水："+str(i))
  _check(water.wet_at(maze.player.position)==0.0,"正式地形遮罩不扭动低台："+str(i))
  await picture("dry-"+str(i))
 maze.player.position=Vector2(1090,450)
 _check(await until_true(func(): return water.depth>0.8,0.8),"回水再渐入")
 var saved: Dictionary=sm.data.duplicate(true)
 water.enabled=false
 await get_tree().process_frame
 _check(maze.player.body.position==Vector2.ZERO and not water.reflection.visible,"关闭水体还原角色，不残留浸没/倒影")
 _check(sm.data==saved,"开关不写玩家存档")
 await picture("disabled")
 water.enabled=true
 await get_tree().process_frame
 _check(maze.player.body.position.y>0 and water.reflection.visible,"重新开启正确恢复当前水中显示")
 var flow: Node=maze.capture_flow
 flow.set_process(true)
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and not Run.Combat.PlayerHurt.recovering(state().combat),2.0),"沿真实战斗等待原入场冷却和受击恢复")
 var throws: int=state().combat.throws
 await click()
 _check(await until_true(func(): return state().combat.throws>throws or Run.Combat.PlayerHurt.recovering(state().combat),0.5),"水体不拦截原攻击/受击事务")
 await picture("battle")
 flow.set_process(false)
 for value in [true,false]:
  water.enabled=value
  for i in 20: await get_tree().process_frame
  var frames: Array=[]
  var previous:=Time.get_ticks_usec()
  for i in 120:
   await get_tree().process_frame
   var now:=Time.get_ticks_usec()
   frames.append(float(now-previous)/1000.0)
   previous=now
  frames.sort()
  measurements.append({"enabled":value,"median_ms":frames[frames.size()/2],"maximum_ms":frames.back(),"samples":frames.size()})
 _check(measurements[0].median_ms<50.0,"当前隔离GPU水体开启帧中位数不超过50毫秒",{"measurements":measurements})
 trace.append({"water_performance":measurements,"scope":"同一隔离GPU/场景的开关对照，不外推手机或其他设备"})
 water.enabled=true
 maze.player.hide()
 await get_tree().process_frame
 await get_tree().process_frame
 _check(not water.reflection.visible and not water.display_active,"玩家隐藏清理倒影与足边显示")
 maze.player.show()
 sm.data=entry_snapshot.duplicate(true)
 _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"原合法区域事务离开分水庭")
 await get_tree().process_frame
 await get_tree().process_frame
 _check(not water.reflection.visible and not water.display_active and maze.player.body.position==Vector2.ZERO,"离开分水庭还原身体和水体显示")
 var old: WeakRef=weakref(water.reflection)
 maze.queue_free()
 await get_tree().process_frame
 _check(old.get_ref()==null,"真实场景销毁连同倒影清理")
