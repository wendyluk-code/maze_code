extends "res://tools/tests/fenshui_frog_counter_flow.gd"
## 左前候选必须从实际试玩入口进入战斗，不以静态动作工具代替。
const LeftFrames=preload("res://scripts/maze/wind_frog_frames.gd")
const PARTS=["base","charge","charge","base","fall","fall","fall","fall","base","breath","breath","breath","rise","rise","rise","base","rise","rise"]
const NORMS={"base":627.0,"charge":887.0,"fall":627.0,"breath":724.0,"rise":512.0}
var observed: Dictionary={}
var geometry: Array=[]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"左前战斗验证使用隔离存档")
 var frames: RefCounted=LeftFrames.new()
 _check(frames.has_method("draw_direction_pose"),"正式帧消费者支持左前完整连续姿态")
 if failures:
  _finish()
  return
 _check(ResourceLoader.exists("res://tools/previews/fenshui_frog_left_play.tscn"),"左前候选具有实际战斗入口")
 if failures:
  _finish()
  return
 await check_geometry(frames)
 if failures or _arg("--phase=")=="geometry":
  FileAccess.open(output+"/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(geometry,"  "))
  _finish()
  return
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 var entry: Node=load("res://tools/previews/fenshui_frog_left_play.tscn").instantiate()
 viewport.add_child(entry)
 _check(await until_true(func(): return entry.gate!=null and entry.gate.visible,8.0),"真实左前试玩显示开始确认窗")
 if failures:
  _finish()
  return
 maze=entry.maze
 _check(maze.capture_flow.monsters.size()==7 and maze.get_node_or_null("FrogMotionControls")==null,"正常4鱼2鳗1蛙，无动作演示控件")
 _check(entry.gate.question.text.contains("固定左前") and entry.gate.question.text.contains("原图"),"入口明示固定方向及击败捕获旧图边界")
 _check(maze.capture_flow.monsters[Boss.ID].frog_motion_direction==1,"实际巨蛙启用左前完整链")
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var original: Texture2D=frog.body.texture
 _check(not frog.set_frog_motion_direction(4) and frog.frog_motion_direction==1 and frog.body.texture==original,"实际节点拒绝非法方向并保留候选方向")
 var before:=state()
 await get_tree().create_timer(0.2).timeout
 _check(before.combat==state().combat and maze.player.input_locked,"等待开始期间原战斗冻结")
 await mouse(entry.gate.confirm_button.get_global_rect().get_center())
 maze.capture_flow.window_focused=true
 _check(not entry.gate.visible and not maze.player.input_locked,"内部鼠标点击开始后恢复真实战斗")
 await battle()
 _check(observed.size()==18,"实际战斗完整消费全部18姿态，不只检查静态映射",observed)
 if failures==0: await pose_pictures()
 FileAccess.open(output+"/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(geometry,"  "))
 _finish()

func check_geometry(frames: RefCounted) -> void:
 frames.load_frames(80.0)
 var body:=Sprite2D.new()
 var base_scale:=0.0
 for index in 18:
  _check(frames.draw_direction_pose(body,index,1),"左前18姿态均可独立消费："+str(index))
  if body.texture==null: continue
  var used: Rect2i=body.texture.get_image().get_used_rect()
  var opaque: Rect2i=visible_bounds(body.texture.get_image())
  var rect:=Rect2(body.get_rect().position+Vector2(used.position),Vector2(used.size))
  _check(not body.flip_h and not body.flip_v and is_zero_approx(body.rotation),"不镜像旋转补造姿态："+str(index))
  _check(used.encloses(opaque),"保留完整源矩形淡边，不为贴地裁掉主体像素："+str(index))
  if index in [0,8,12,13,14,15,16,17]:
   _check(absf((body.get_rect().position.y+opaque.end.y)*body.scale.y)<1.0,"可见落地主体贴合脚底，不以极淡透明边代替："+str(index),{"visible_bottom":(body.get_rect().position.y+opaque.end.y)*body.scale.y,"used":str(used),"opaque":str(opaque)})
  if index==0: _check(absf(rect.size.x*body.scale.x-80.0)<0.01,"透明画布扩大后仍沿原蹲姿80像素参考尺度")
  if index==0: base_scale=body.scale.x
  var expected_source: String="res://assets/monsters/wind_frog/counter_candidate/directions/"+("front-left-padded-v2.png" if PARTS[index]=="base" else "left-chain/"+PARTS[index]+"-padded.png")
  _check(body.texture.atlas.resource_path==expected_source,"姿态采用独立期望的正确分段资源："+str(index))
  _check(is_equal_approx(body.scale.x,base_scale*627.0/NORMS[PARTS[index]]) and is_equal_approx(body.scale.x,body.scale.y),"按每段参考宽统一等比，不按透明画布或逐帧拉伸："+str(index))
  geometry.append({"pose":index,"scale":body.scale.x,"width":rect.size.x*body.scale.x,"height":rect.size.y*body.scale.y,"visible_width":opaque.size.x*body.scale.x,"visible_height":opaque.size.y*body.scale.y,"source":body.texture.atlas.resource_path})
 var saved: Texture2D=body.texture
 for direction in [-1,4]:
  _check(not frames.draw_direction_pose(body,4,direction) and body.texture==saved,"非法完整方向拒绝且不跳回右前："+str(direction))
 _check(not frames.draw_direction_pose(body,18,1) and body.texture==saved,"非法姿态拒绝且不改变身体")
 _check(frames.draw_direction_pose(body,0,0) and body.texture==frames.textures[0],"完整右前消费者仍使用原认可图")
 body.free()

func visible_bounds(image: Image) -> Rect2i:
 var left:=image.get_width()
 var top:=image.get_height()
 var right:=-1
 var bottom:=-1
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a<0.5: continue
   left=mini(left,x)
   top=mini(top,y)
   right=maxi(right,x)
   bottom=maxi(bottom,y)
 return Rect2i(left,top,right-left+1,bottom-top+1)

func _process(_delta: float) -> void:
 if not is_instance_valid(maze) or not maze._entry_ready: return
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 if frog.frog_state.is_empty() or frog.frog_state.hp<=0: return
 var pose: int=LeftFrames.pose(frog.frog_state)
 if frog.frog_motion.left_chain.size()==18 and frog.body.texture==frog.frog_motion.left_chain[pose].texture:
  observed[pose]=true

func pose_pictures() -> void:
 # 实战已另验；这里仅留真实节点逐姿态截图供绘制会话目检，不伪称动画回放。
 maze.process_mode=Node.PROCESS_MODE_DISABLED
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var baseline: Dictionary=state().duplicate(true)
 frog.membrane.hide()
 for index in 18:
  frog.frog_motion.draw_direction_pose(frog.body,index,1)
  await super.picture("pose_"+str(index).pad_zeros(2))
 _check(state()==baseline,"逐姿态取证不改生命、战斗阶段、位置或存档")

func picture(label: String) -> void:
 await super.picture(label)
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 if frog.body.region_enabled:
  _check(frog.body.texture in [frog.action_sheets.idle,frog.action_sheets.attack] and int(frog.body.region_rect.position.y/192)==1,"审定旧待机／吐水仍读取左前行："+label)
 else:
  _check(frog.body.texture is AtlasTexture and frog.body.texture.atlas.resource_path.contains("/directions/"),"完整链持续消费左前图而非右前："+label)
 _check(frog.membrane.global_position.distance_to(bubble_center(frog))<0.01,"实际战斗泡膜跟随左前可见主体："+label)

func bubble_center(frog: Node2D) -> Vector2:
 var image: Image=frog.body.texture.get_image()
 if frog.body.region_enabled: image=image.get_region(Rect2i(frog.body.region_rect))
 var visible:=visible_bounds(image)
 return frog.body.to_global(frog.body.get_rect().position+Vector2(visible.position)+Vector2(visible.size)*0.5)

func mouse(point: Vector2) -> void:
 var motion:=InputEventMouseMotion.new()
 motion.position=point
 viewport.push_input(motion)
 await get_tree().process_frame
 await super.mouse(point)
