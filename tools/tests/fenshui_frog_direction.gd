extends "res://tools/tests/fenshui_frog_motion.gd"
## 四关键姿态的真实节点核对；不把缺帧方向当连续战斗交付。
const DirectionFrames=preload("res://scripts/maze/wind_frog_frames.gd")
const EXPECTED_KEYS=[0,3,8,15]
const EXPECTED_SOURCES={1:"res://assets/monsters/wind_frog/counter_candidate/directions/front-left-padded-v2.png",2:"res://assets/monsters/wind_frog/counter_candidate/directions/back-right-padded.png",3:"res://assets/monsters/wind_frog/counter_candidate/directions/back-left-padded.png"}

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"三向姿态检查使用隔离存档")
 var frames: RefCounted=DirectionFrames.new()
 _check(frames.has_method("draw_direction_key"),"正式帧消费者具有三向关键姿态接口")
 if failures:
  _finish_motion()
  return
 _check(ResourceLoader.exists("res://tools/previews/fenshui_frog_direction.tscn"),"三向核对入口已接到原巨蛙节点")
 if failures:
  _finish_motion()
  return
 get_tree().paused=true
 entry=load("res://tools/previews/fenshui_frog_direction.tscn").instantiate()
 get_tree().root.add_child(entry)
 for i in 90:
  await get_tree().process_frame
  if entry.controls!=null: break
 _check(entry.controls!=null,"原分水庭与核对控件就绪")
 if entry.controls==null:
  get_tree().paused=false
  _finish_motion()
  return
 var controls: Node=entry.controls
 var maze: Node2D=entry.maze
 var frog: Node2D=controls.frog
 var body: Sprite2D=frog.body
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 maze.reparent(viewport)
 maze.capture_flow.window_focused=true
 get_tree().paused=false
 var baseline: Dictionary=sm.data.duplicate(true)
 var original: Dictionary=controls.saved.duplicate()
 var names=["右前","左前","右后","左后"]
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  for direction in 4:
   for attempt in 4:
    if controls.direction==direction: break
    await _key(KEY_F7)
   _check(controls.direction==direction,"内部F7切至真实朝向："+names[direction])
   var expected_scale:=0.0
   for key in 4:
    if key>0: await _key(KEY_F8)
    _check(controls.key_index==key and controls.pose==EXPECTED_KEYS[key],"实际F8选择对应关键姿态：%d/%d" % [direction,key])
    _check(not body.flip_h and not body.flip_v and is_zero_approx(body.rotation),"未用镜像或旋转伪造方向：%d/%d" % [direction,key])
    _check(body.texture is AtlasTexture and not body.region_enabled,"真实身体消费独立裁切的透明原图")
    if direction>0:
     _check(body.texture.atlas.resource_path==EXPECTED_SOURCES[direction],"实际资源来自认可方向图，不混旧图")
     if key==0: expected_scale=body.scale.x
     _check(is_equal_approx(body.scale.x,expected_scale) and is_equal_approx(body.scale.y,expected_scale),"同方向四姿态共用等比尺度")
    var rect: Rect2=body.get_rect()
    var used: Rect2i=body.texture.get_image().get_used_rect()
    var visible_rect:=Rect2(rect.position+Vector2(used.position),Vector2(used.size))
    if key==0 and direction>0: _check(absf(visible_rect.size.x*body.scale.x-frog.frog_motion.reference_width)<0.01,"增加透明画布后仍保留认可蹲姿体型")
    if direction>0: _check(absf(visible_rect.end.y*body.scale.y)<0.01,"真实主体脚底相对身体锚点为零")
    _check(absf(body.position.y-(-36.0 if key==1 else 0.0))<0.01,"腾空高度与落地锚点明确分离")
    var center: Vector2=body.position+rect.get_center()*body.scale
    _check(frog.membrane.position.distance_to(center)<0.01,"泡膜跟随当前身体取景中心")
    _check(frog.membrane.visible==(key in [0,1]),"蹲姿与腾空有膜，露腹及撑地无膜",{"direction":direction,"key":key,"phase":frog.frog_state.get("frog_phase",""),"form":frog.frog_state.get("frog_form_left",-1),"visible":frog.membrane.visible})
    _check(sm.data==baseline,"方向和姿态核对不改生命、阶段、奖励或存档")
    await _picture("direction_%d_key_%d_%dx%d" % [direction,key,size.x,size.y])
   for index in [1,2,4,5,6,7,9,10,11,12,13,14,16,17]:
    if direction==0: break
    var texture: Texture2D=body.texture
    _check(not frog.preview_frog_direction_key(direction,index) and body.texture==texture,"静态关键姿态接口拒绝连续帧索引，不退回右前：%d/%d" % [direction,index])
 _check(not controls.playing and controls.hint.text.contains("关键姿态"),"核对入口明确静态边界，不自动伪造连续动画")
 _key_now(KEY_F9)
 _check(not controls.active and not maze.player.input_locked and maze.capture_flow.is_processing(),"F9恢复原单向正式战斗及输入")
 _check(body.texture==original.texture and body.transform==original.transform and body.offset==original.offset,"退出当刻恢复原身体取景和尺度")
 _check(frog.membrane.transform==controls.original_membrane_transform and frog.membrane.visible==controls.original_membrane_visible,"退出当刻恢复原保护泡")
 await _click_local(maze.map_ui.mini_button)
 var frozen: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 await get_tree().create_timer(0.15).timeout
 _check(maze.map_ui.expanded and Run.snapshot(sm).combat==frozen and not controls.tool_layer.visible,"恢复后原地图仍暂停战斗且隐藏工具",{"expanded":maze.map_ui.expanded,"frozen":Run.snapshot(sm).combat==frozen,"tool_visible":controls.tool_layer.visible,"active":controls.active})
 await _key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭地图恢复输入")
 _check(Run.valid(Run.snapshot(sm)),"最终原战斗状态合法")
 maze.capture_flow.set_process(false)
 _finish_motion()

func _click_local(control: Control) -> void:
 var motion:=InputEventMouseMotion.new()
 motion.position=control.get_global_rect().get_center()
 viewport.push_input(motion)
 await get_tree().process_frame
 await super._click_local(control)
