extends "res://tools/tests/fenshui_frog_counter_flow.gd"
var baseline: Dictionary
var sequence: Array=[]
var last_pose:=-1
var sampling:=false
var capture_age:=0.0

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"双前向候选从真实七怪场景启动")
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(frog.has_method("enable_frog_front24"),"实际巨蛙支持隔离启用已确认双前向24姿态")
 if failures: return
 _check(frog.call("enable_frog_front24"),"实际节点加载24姿态候选")
 _check(frog.body.texture is AtlasTexture and frog.body.texture.atlas.resource_path.ends_with("front24.png"),"身体实际消费认可原图，不混接旧图")
 baseline=entry_snapshot.duplicate(true)
 _check(absf(frog.frog_front24.reference_width-107.9166667)<0.01,"原77.0833参考可见宽放大40%，不是网页155像素或25%候选叠乘")
 _check(frog.shadow.scale.is_equal_approx(Vector2(0.476,0.308)),"投影同步1.4倍，未放大碰撞节点")
 sampling=true
 for direction in 2:
  maze.capture_flow.set_process(false)
  sm.data=baseline.duplicate(true)
  maze.player.position=Boss.HOME+Vector2(-45 if direction else 45,35)
  maze.camera.snap_to_target()
  maze.capture_flow.set_process(true)
  _check(await until_true(func(): return actor().frog_phase=="airborne",6.0),"双前向自然起跳："+str(direction))
  _check(frog.frog_front24.current_direction==direction,"候选左右前向按战斗锁向显示",{"expected":direction,"shown":frog.frog_front24.current_direction,"facing":actor().get("frog_facing",-1),"origin":actor().frog_origin,"target":actor().frog_target})
  _check(frog.membrane.visible and bubble_center(frog).distance_to(frog.membrane.global_position)<1.0,"放大后腾空保护膜跟随可见身体")
  await picture("front_"+str(direction)+"_air")
  _check(await until_true(func(): return actor().frog_phase=="landing"),"候选不攻击自然落地")
  _check(frog.frog_front24.current_pose==6,"普通落地从新接地缓冲开始")
  await picture("front_"+str(direction)+"_land")
  maze.player.position=Run.Combat.vec(actor().position)+Vector2(-7 if direction else 7,7)
  _check(await until_true(func(): return actor().mode=="windup",5.0),"落地后真实吐水蓄力")
  _check(frog.frog_front24.current_pose==8,"吐水使用新蓄力姿态")
  maze.player.position+=Vector2(40,20)
  _check(await until_true(func(): return float(actor().get("frog_spit_left",0.0))>0.18,2.0),"真实发射触发张口释放")
  _check(frog.frog_front24.current_pose==9,"实际出水时显示新张口姿态")
  check_mouth(frog,direction)
  RenderingServer.force_draw(false)
  var spit_image: Image=viewport.get_texture().get_image()
  _check(await until_true(func(): return frog.frog_front24.current_pose==10,1.0),"张口后按认可100毫秒进入收势")
  spit_image.save_png(output+"/front_"+str(direction)+"_spit.png")
  await picture("front_"+str(direction)+"_close")
  if failures: break
 if failures==0:
  maze.capture_flow.set_process(false)
  sm.data=baseline.duplicate(true)
  maze.player.position=Vector2(880,490)
  maze.capture_flow.set_process(true)
  await super.battle()
 sampling=false
 FileAccess.open(output+"/sequence.json",FileAccess.WRITE).store_string(JSON.stringify(sequence,"  "))

func _process(delta: float) -> void:
 if not sampling or not is_instance_valid(maze): return
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var pose: int=frog.frog_front24.current_pose
 capture_age+=delta
 if pose==last_pose: return
 last_pose=pose
 sequence.append({"seconds":capture_age,"pose":pose,"phase":actor().frog_phase,"direction":frog.frog_front24.current_direction,"scale":frog.body.scale.x,"atlas":frog.body.texture.atlas.resource_path})

func bubble_center(frog: Node2D) -> Vector2:
 return frog.to_global(frog.frog_front24.body_center(frog.body))

func check_mouth(frog: Node2D, direction: int) -> void:
 var visual: Node
 for child in maze.get_children():
  if child.get_script()!=null and child.get_script().resource_path=="res://scripts/maze/wind_frog_visual.gd": visual=child
 var shots: Array=actor().frog_shots
 _check(visual!=null and not shots.is_empty(),"真实离体水团存在")
 if visual==null or shots.is_empty(): return
 var pixel: Vector2=[Vector2(145,96),Vector2(44,82)][direction]
 var expected: Vector2=(frog.body.offset+pixel)*frog.body.scale
 var actual: Vector2=visual.pool[shots.size()-1].position-Run.Combat.vec(shots.back().position)
 _check(actual.distance_to(expected)<1.0,"水团显示出点跟随新图及1.4倍体型",{"actual":str(actual),"expected":str(expected)})

