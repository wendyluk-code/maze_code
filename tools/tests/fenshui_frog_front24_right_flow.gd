extends "res://tools/tests/fenshui_frog_counter_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"右前反击从正常地图进入")
 maze.capture_flow.set_process(false)
 sm.data=entry_snapshot.duplicate(true)
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(frog.enable_frog_front24(),"右前完整反击启用同一新图消费者")
 maze.player.position=Boss.HOME+Vector2(45,35)
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 await super.battle()

func bubble_center(frog: Node2D) -> Vector2:
 return frog.to_global(frog.frog_front24.body_center(frog.body))

func picture(label: String) -> void:
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 if actor().frog_phase in ["airborne","toppling","exposed","recovering"]:
  _check(frog.frog_front24.current_direction==0 and frog.body.texture.atlas.resource_path.ends_with("front24.png"),"右前真实起跳、受击、露腹、起身不混旧图："+label)
 await super.picture(label)
