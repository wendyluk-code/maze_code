extends "res://tools/tests/fenshui_frog_counter.gd"
## 正式场景原图的前后遮挡；测试只移动隔离样例，不改变生产站位。
const Run=preload("res://scripts/maze/capture_run.gd")
var viewport: SubViewport
var maze: Node2D
var output: String
var samples: Array=[]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"深度检查隔离正式存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"建立真实探索")
 _check(Run.change_region(sm,"fenshui",Vector2(880,490)).success,"进入正式分水庭")
 viewport=SubViewport.new()
 viewport.size=depth_resolution()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 get_tree().root.add_child(viewport)
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 viewport.add_child(maze)
 for i in 5: await get_tree().process_frame
 maze.process_mode=Node.PROCESS_MODE_DISABLED
 _check(maze.capture_flow.monsters.size()==7,"使用正常七怪场景，不用替代显示节点")
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 prepare_frog(frog)
 var standing:=fresh_frog()
 var flying:=airborne()
 tick(flying,0.4)
 var exposed:=airborne()
 tick(exposed,0.12) # 进入已确认的最高点前后0.3秒窗口，再由真实伤害入口打翻。
 Combat.Skills.damage(exposed,Boss.ID,8)
 tick(exposed,0.56)
 for phase in [{"name":"standing","run":standing},{"name":"airborne","run":flying},{"name":"exposed","run":exposed}]:
  if _arg("--phase=")=="minimal" and phase.name!="standing": continue
  for side in [{"name":"front","offset":Vector2(0,20)},{"name":"back","offset":Vector2(0,-20)},{"name":"left_front","offset":Vector2(-18,12)},{"name":"right_back","offset":Vector2(18,-12)}]:
   if _arg("--phase=")=="minimal" and side.name!="front": continue
   var run: Dictionary=phase.run
   frog.position=Boss.HOME
   maze.player.position=Boss.HOME+side.offset
   # 场景已暂停并手动指定本次目标，首张也须建立与后续样例相同的标签可见前置。
   frog.label.show()
   frog.sync_action(run.combat.actors[Boss.ID],run.combat)
   maze.camera.position=Boss.HOME
   maze.camera.reset_smoothing()
   var label: String=phase.name+"_"+side.name
   var before: Dictionary={"hero":str(maze.player.position),"frog":str(frog.position),"body":str(frog.body.position),"hero_z":maze.player.z_index,"frog_z":frog.z_index,"hero_parent":str(maze.player.get_parent().get_path()),"frog_parent":str(frog.get_parent().get_path())}
   await capture(label+"_actual")
   # 去掉界面与膜，仅隔离同一组真实主体像素来判断谁在前，不替换图像。
   var bubble_visible: bool=frog.membrane.visible
   var hero_label_visible: bool=maze.capture_flow.power_label.visible
   frog.membrane.hide()
   frog.label.hide()
   maze.capture_flow.power_label.hide()
   var both:=await capture("")
   frog.hide()
   var hero_only:=await capture("")
   frog.show()
   maze.player.hide()
   var frog_only:=await capture("")
   frog.hide()
   var background:=await capture("")
   frog.show()
   maze.player.show()
   frog.label.show()
   frog.membrane.visible=bubble_visible
   maze.capture_flow.power_label.visible=hero_label_visible
   var hero_votes:=0
   var frog_votes:=0
   for y in both.get_height():
    for x in both.get_width():
     var bg:=background.get_pixel(x,y)
     var h:=hero_only.get_pixel(x,y)
     var f:=frog_only.get_pixel(x,y)
     if distance(h,bg)<0.25 or distance(f,bg)<0.25 or distance(h,f)<0.25: continue
     var p:=both.get_pixel(x,y)
     if distance(p,h)<0.025: hero_votes+=1
     if distance(p,f)<0.025: frog_votes+=1
   var hero_front: bool=side.offset.y>0
   var total:=hero_votes+frog_votes
   var correct:=hero_votes if hero_front else frog_votes
   before.merge({"label":label,"hero_votes":hero_votes,"frog_votes":frog_votes,"expected_front":"hero" if hero_front else "frog","correct_ratio":float(correct)/maxi(1,total)})
   samples.append(before)
   _check(total>10,"真实原图有足够相交像素："+label,{"pixels":total})
   _check(total>10 and float(correct)/total>0.9,"按地面脚底前后自然遮挡："+label,before)
   if phase.name!="airborne":
    var bottom: float=ground_bottom(frog)
    _check(absf(bottom-frog.global_position.y)<1.0,"落地脚底不因遮挡修正漂移："+label,{"delta":bottom-frog.global_position.y})
 if _arg("--phase=")!="minimal": await walk_in_battle(frog)
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples},"  "))
 get_tree().quit(1 if failures else 0)

func depth_resolution() -> Vector2i:
 return Vector2i(960,540)

func prepare_frog(_frog: Node2D) -> void:
 pass

func ground_bottom(frog: Node2D) -> float:
 var image: Image=frog.body.texture.get_image()
 if frog.body.region_enabled: image=image.get_region(Rect2i(frog.body.region_rect))
 for y in range(image.get_height()-1,-1,-1):
  for x in image.get_width():
   if image.get_pixel(x,y).a>=0.5:
    return frog.body.to_global(frog.body.get_rect().position+Vector2(x,y+1)).y
 return INF

func capture(label: String) -> Image:
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 var image:=viewport.get_texture().get_image()
 if not label.is_empty(): image.save_png(output+"/"+label+".png")
 return image

func distance(a: Color,b: Color) -> float:
 return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)

func walk_in_battle(frog: Node2D) -> void:
 maze.player.position=Vector2(880,490)
 maze.process_mode=Node.PROCESS_MODE_INHERIT
 maze.capture_flow.window_focused=true
 for i in 30:
  await get_tree().process_frame
  if maze._entry_ready and not maze.player.input_locked: break
 var initial: Vector2=maze.player.position
 var observed: Dictionary={}
 var mismatches:=0
 var count:=0
 # 新脚底占位不允许穿过蛙身，绕侧再比较前后关系。
 for direction in ["ui_left","ui_up","ui_right","ui_down"]:
  Input.action_press(direction)
  var deadline:=Time.get_ticks_msec()+900
  while Time.get_ticks_msec()<deadline:
   # 结论对应节点完成更新后的实际绘制，不采样帧开始时的过渡状态。
   await RenderingServer.frame_post_draw
   var behind: bool=frog.global_position.y<maze.player.global_position.y
   observed[str(behind)]=true
   count+=1
   if behind!=(frog.get_index()<maze.player.get_index()): mismatches+=1
  Input.action_release(direction)
  await capture("live_"+direction)
 _check(maze.player.position.distance_to(initial)>2.0,"正常战斗接受Godot内部移动输入，不操作系统键鼠")
 _check(observed.size()==2,"实际往返移动覆盖巨蛙在玩家前、后两种关系",observed)
 _check(count>10 and mismatches==0,"实际战斗逐帧切换前后遮挡，不固定压到玩家后面",{"frames":count,"mismatches":mismatches})
 _check(Run.valid(Run.snapshot(sm)),"往返战斗后原存档状态仍有效")
