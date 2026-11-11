extends "res://tools/tests/fenshui_ranged_hitstop_flow.gd"
## 正常地图、真实输入，不加载或调用三档试玩控件。

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 _check(get_window().mode==Window.MODE_MINIMIZED and get_window().unfocusable,"正式接入验收不占用用户输入")
 baseline=sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial=false
 baseline[Run.KEY].combat.cooldown=0.0
 baseline[Run.KEY].combat.selected=0
 for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status="alive" if id==Rules.IDS[0] else "skipped"
 var a: Dictionary=baseline[Run.KEY].combat.actors[Rules.IDS[0]]
 a.position=[920.0,440.0]
 a.fish_origin=a.position.duplicate()
 a.fish_aim=[0.0,1.0]
 a.fish_hit=false
 Fish.phase(a,"recover",2.5)
 maze.free()
 sm.data=baseline.duplicate(true)
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 render_view.add_child(maze)
 await get_tree().process_frame
 _check(maze.capture_flow.axe_hitstop!=null,"正常场景已安装时钟，不加载隔离控件")
 if maze.capture_flow.axe_hitstop==null:
  _finish_hitstop()
  return
 RenderingServer.frame_post_draw.connect(_sample_frame)
 for key in [KEY_SPACE,KEY_1,KEY_2]: await _normal_case(key)
 await _normal_case(KEY_1,Vector2i(1152,648))
 _check(not invalid_seen and not maze.player.input_locked,"正式三种攻击结束后输入可用且状态合法")
 _check(not frame_ms.is_empty() and frame_ms.max()<250,"正式场景保留250毫秒长帧门槛",{"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 _finish_hitstop()

func _normal_case(key: Key, size:=Vector2i(1280,720)) -> void:
 render_view.size=size
 await _reset(Vector2(880,490))
 var recoil_start: Vector2=Run.Combat.vec(actor().position)
 maze.capture_flow.axe_hitstop.configure(70)
 maze.capture_flow.axe_hitstop.configure_ranged(50)
 await _send_key(key)
 _begin_trace("normal_%d_%d" % [key,size.x],true)
 RenderingServer.force_draw(false)
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<20,180),"正常场景真实左键命中："+str(key))
 if key==KEY_2:
  _check(maze.capture_flow.axe_hitstop.state.left>0,"正常铁山命中实际启动70毫秒")
 else:
  _check(maze.capture_flow.axe_hitstop.paused(Rules.IDS[0]),"正常远程命中实际启动50毫秒："+str(key))
 var point: Vector2=maze.player.position
 Input.action_press("ui_right")
 await get_tree().physics_frame
 await get_tree().physics_frame
 Input.action_release("ui_right")
 _check(maze.player.position.x>point.x,"命中停顿期间仍可移动："+str(key))
 await get_tree().create_timer(0.7).timeout
 _remote_end()
 _check(actor().hp==19.0 and Run.snapshot(sm).combat.hits==1,"正式场景不重复伤害："+str(key))
 _check(absf(Run.Combat.vec(actor().position).distance_to(recoil_start)-12.0)<0.01,"正式命中保留约12世界单位击退："+str(key))
 _check(not maze.capture_flow.axe_hitstop.paused(Rules.IDS[0]),"正式场景目标自动恢复："+str(key))
 last_frame=0
 recording=true
 await _click(maze.map_ui.mini_button)
 var before: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 await get_tree().create_timer(0.12).timeout
 _check(maze.map_ui.expanded and Run.snapshot(sm).combat==before,"原地图展开仍冻结战斗")
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭原地图恢复输入")
 recording=false

func _remote_end() -> void:
 sampling=false
 recording=false
 var dir:=output+"/"+case_name
 DirAccess.make_dir_recursive_absolute(dir)
 for i in frame_images.size(): frame_images[i].save_png(dir+"/frame_%03d.png" % i)
 traces.append({"case":case_name,"frames":samples.duplicate(true),"candidate_ms":70 if Run.snapshot(sm).combat.selected==2 else 50})
 frame_images=[]
