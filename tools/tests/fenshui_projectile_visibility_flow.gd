extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const HERO_TEXTURE="res://assets/combat/spatula_projectile_v1.png"
const LIGHT_TEXTURE="res://assets/combat/team_skills/fenshui_yaya_point.png"
const WATER_TEXTURE="res://assets/monsters/wind_frog/waterjet_v2.png"
var hero_sample: Dictionary
var light_sample: Dictionary

func _process(_dt: float) -> void:
 # 测试窗口不能取得系统焦点；只在引擎内部模拟正在操作的游戏上下文。
 if is_instance_valid(maze) and is_instance_valid(maze.capture_flow): maze.capture_flow.window_focused=true

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实七怪场景完成入场")
 maze.player.position=Vector2(840,490)
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 await key(KEY_SPACE)
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and state().combat.action_left<=0.0),"沿原冷却准备真实发射",{"cooldown":state().combat.cooldown,"paused":maze.capture_flow.combat_paused(),"hp":state().combat.hp})
 if failures: return
 var count: int=state().combat.throws
 await click()
 _check(state().combat.throws==count+1,"真实左键发射锅铲，不改模拟或发射次数")
 _check(await until_true(func(): return not state().combat.shots.is_empty() and state().combat.shots[0].time>=0.035,1.0),"锅铲经过真实弹道进入可观察在途段")
 if failures: return
 maze.capture_flow.set_process(false)
 hero_sample=state().combat.shots[0].duplicate(true) if not state().combat.shots.is_empty() else {}
 await get_tree().process_frame
 await get_tree().process_frame
 var sprites:=visible_sprites(maze.capture_flow.skill_visual,HERO_TEXTURE)
 var heads: Array=sprites.filter(func(s): return s.modulate.a>0.99)
 _check(heads.size()==1,"一发锅铲只有一个主弹体")
 if not heads.is_empty():
  var head: Sprite2D=heads[0]
  _check(is_equal_approx(maxf(head.texture.get_width(),head.texture.get_height())*head.scale.x,40.0),"锅铲整图由原28放大到确认的40，保持原坐标口径")
 _check(sprites.filter(func(s): return is_equal_approx(s.modulate.a,0.12) or is_equal_approx(s.modulate.a,0.20)).size()==2,"实际在途锅铲具有两段已认可淡残影")
 await picture("hero_real_flight")
 if failures==0: await light_case()
 if failures==0: await water_case()
 if failures==0: await display_matrix()
 if failures==0: cleanup_rules()

func light_case() -> void:
 sm.data=entry_snapshot.duplicate(true)
 maze.player.position=Vector2(840,490)
 maze.capture_flow.set_process(true)
 maze.capture_flow.window_focused=true
 await key(KEY_1)
 _check(state().combat.selected==1,"真实数字键选中芽芽")
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and state().combat.action_left<=0.0),"重建隔离场景后等待原入场冷却")
 await click()
 _check(await until_true(func(): return not state().combat.shots.is_empty() and state().combat.shots[0].kind=="yaya" and state().combat.shots[0].time>=0.04,1.0),"真实芽芽发射后观察在途光核")
 maze.capture_flow.set_process(false)
 light_sample=state().combat.shots[0].duplicate(true) if not state().combat.shots.is_empty() else {}
 await get_tree().process_frame
 await get_tree().process_frame
 var points:=visible_sprites(maze.capture_flow.skill_visual,LIGHT_TEXTURE)
 _check(points.size()==1,"芽芽只有一个实际在途光核")
 if not points.is_empty():
  var point: Sprite2D=points[0]
  _check(is_equal_approx(maxf(point.texture.get_width(),point.texture.get_height())*point.scale.x*maze.camera.zoom.x,60.0),"芽芽按确认稿显示为60屏幕像素")
  _check(point.offset==Vector2(-373,-23),"增大光核后仍沿用原图偏心锚点")
 var tails=maze.capture_flow.skill_visual.get("short_trails")
 _check(tails is Array and tails.size()==1,"芽芽增加与在途光核同步的一条短拖尾")
 if tails is Array and not tails.is_empty(): _check(tails[0].length*maze.camera.zoom.x<=42.01,"芽芽短拖尾不超过确认的42屏幕像素")
 _check(maze.capture_flow.skill_visual.beams.is_empty(),"芽芽不恢复旧长激光")
 await picture("light_real_flight")

func water_case() -> void:
 sm.data=entry_snapshot.duplicate(true)
 maze.player.position=Vector2(880,490)
 maze.camera.snap_to_target()
 maze.capture_flow.set_process(true)
 maze.capture_flow.window_focused=true
 _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"真实巨蛙启用当前统一双前向身体")
 _check(await until_true(func(): return not actor().frog_shots.is_empty(),12.0),"等待正常七怪战斗中的巨蛙自然吐水，不手填发射阶段",{"frog":actor(),"hp":state().combat.hp,"paused":maze.capture_flow.combat_paused(),"hero":str(maze.player.position)})
 if actor().frog_shots.is_empty(): return
 maze.capture_flow.set_process(false)
 await get_tree().process_frame
 await get_tree().process_frame
 var layer: Node=water_layer()
 var sprites: Array=[]
 for child in layer.get_children():
  if child is Sprite2D and child.is_visible_in_tree(): sprites.append(child)
 _check(not sprites.is_empty(),"自然吐水的水枪在真实场景可见")
 if sprites.is_empty(): return
 var sprite: Sprite2D=sprites[0]
 _check(sprite.texture!=null,"新水枪资源已通过Godot导入")
 if sprite.texture==null: return
 var shot: Dictionary=actor().frog_shots[0]
 _check(maze.capture_flow.power_label.z_index>sprite.z_index and maze.capture_flow.monsters[Boss.ID].label.z_index>sprite.z_index,"头顶数值始终绘制在长尾水枪之上")
 _check(sprite.texture.resource_path==WATER_TEXTURE,"自然发射消费新水枪PNG，而非旧水团")
 _check(Vector2.RIGHT.rotated(sprite.rotation).dot(Run.Combat.vec(shot.direction))>0.999,"朝右新图沿实际出射方向，不沿用旧图加PI")
 if sprite.texture.resource_path==WATER_TEXTURE:
  _check(is_equal_approx(1694.0*sprite.scale.x,80.0),"水枪按1694内容宽等比显示为80，不按透明画布缩小")
  var direction: int=Run.Combat.Frog.Counter.direction_for(Run.Combat.vec(shot.direction))
  var mouth: Vector2=maze.capture_flow.monsters[Boss.ID].frog_front24.mouth_offset(direction)
  var anchor:=sprite.to_global(Vector2(1645.02,356)-sprite.region_rect.position+sprite.offset)
  _check(anchor.distance_to(Run.Combat.vec(shot.position)+mouth)<0.05,"新水枪前端区域对齐原实际嘴部挂点")
 var stable: Dictionary=state().duplicate(true)
 var transform: Transform2D=sprite.transform
 await get_tree().process_frame
 await get_tree().process_frame
 _check(state()==stable and sprite.transform==transform,"暂停模拟时水枪显示不自行移动或改战斗状态")
 await picture("water_real_spit")

func display_matrix() -> void:
 # 以下是受控显示对照；自然发射和实际命中另由上文与原交互入口验收。
 var original: Dictionary=state().duplicate(true)
 var water_sample: Dictionary=actor().frog_shots[0].duplicate(true)
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=resolution
  maze.camera.snap_to_target()
  for i in 8:
   var direction:=Vector2.RIGHT.rotated(float(i)*TAU/8.0)
   var fixture: Dictionary=original.duplicate(true)
   var hero_shot:=hero_sample.duplicate(true)
   var light_shot:=light_sample.duplicate(true)
   for pair in [[hero_shot,Vector2(790,430),210.0,0.5],[light_shot,Vector2(850,550),310.0,0.6]]:
    var shot: Dictionary=pair[0]
    var origin: Vector2=pair[1]
    shot.origin=[origin.x,origin.y]
    shot.target=Run.Combat.Skills.pack(origin+direction*pair[2])
    shot.time=0.2
    shot.flight=pair[3]
    shot.position=Run.Combat.Skills.pack(origin.lerp(Run.Combat.vec(shot.target),0.2/float(pair[3])))
   fixture.combat.shots=[hero_shot,light_shot]
   var water:=water_sample.duplicate(true)
   water.direction=[direction.x,direction.y]
   water.distance=90.0
   water.position=Run.Combat.Skills.pack(Run.Combat.vec(fixture.combat.actors[Boss.ID].position)+direction*90.0)
   fixture.combat.actors[Boss.ID].frog_shots=[water]
   fixture.combat.actors[Boss.ID].frog_facing=Run.Combat.Frog.Counter.direction_for(direction)
   sm.data[Run.KEY]=fixture
   await get_tree().process_frame
   await get_tree().process_frame
   var hero_sprites:=visible_sprites(maze.capture_flow.skill_visual,HERO_TEXTURE)
   var heads: Array=hero_sprites.filter(func(s): return s.modulate.a>0.99)
   var lights:=visible_sprites(maze.capture_flow.skill_visual,LIGHT_TEXTURE)
   var waters:=visible_sprites(water_layer(),WATER_TEXTURE)
   var tag:=str(resolution.x)+"/"+str(i)
   _check(heads.size()==1 and lights.size()==1 and waters.size()==1,"受控八向三种投射物同场可见："+tag)
   if heads.size()!=1 or lights.size()!=1 or waters.size()!=1: continue
   _check(Vector2.RIGHT.rotated(lights[0].rotation).dot(direction)>0.999 and Vector2.RIGHT.rotated(waters[0].rotation).dot(direction)>0.999,"光核和新水枪正向飞行："+tag)
   var ghosts: Array=hero_sprites.filter(func(s): return is_equal_approx(s.modulate.a,0.12) or is_equal_approx(s.modulate.a,0.20))
   _check(ghosts.size()==2 and ghosts.all(func(s): return (heads[0].position-s.position).dot(direction)>0.0),"锅铲残影始终位于历史弹道后方："+tag)
   _check(is_equal_approx(lights[0].texture.get_width()*lights[0].scale.x*maze.camera.zoom.x,60.0) and is_equal_approx(waters[0].scale.x*1694.0,80.0),"组合显示保持确认尺寸："+tag)
   _check(maze.capture_flow.skill_visual.beams.is_empty() and maze.capture_flow.skill_visual.short_trails.size()==1,"组合中只有短拖尾，没有旧激光："+tag)
   var facing: int=Run.Combat.Frog.Counter.direction_for(direction)
   var mouth: Vector2=maze.capture_flow.monsters[Boss.ID].frog_front24.mouth_offset(facing)
   var anchor: Vector2=waters[0].to_global(Vector2(1645.02,356)-waters[0].region_rect.position+waters[0].offset)
   _check(anchor.distance_to(Run.Combat.vec(water.position)+mouth)<0.05,"八向水枪前端挂点保持："+tag)
   _check(state()==fixture,"显示组合不回写战斗状态："+tag)
   if i in [0,2,4,6]: await picture("combined_"+str(resolution.x)+"_"+str(i))
 # 消失与旧模式复用同一批池节点，检查不会带入上一种弹体的颜色/偏移。
 var clear: Dictionary=original.duplicate(true)
 clear.combat.shots=[]
 clear.combat.actors[Boss.ID].frog_shots=[]
 sm.data[Run.KEY]=clear
 await get_tree().process_frame
 await get_tree().process_frame
 _check(visible_sprites(maze.capture_flow.skill_visual,HERO_TEXTURE).is_empty() and visible_sprites(maze.capture_flow.skill_visual,LIGHT_TEXTURE).is_empty() and visible_sprites(water_layer(),WATER_TEXTURE).is_empty() and maze.capture_flow.skill_visual.short_trails.is_empty(),"命中或寿命结束后的空状态清除全部弹体和尾迹")
 var legacy: Dictionary=original.duplicate(true)
 legacy.combat.fs01_trial=true
 legacy.combat.shots=[hero_sample.duplicate(true),light_sample.duplicate(true)]
 sm.data[Run.KEY]=legacy
 await get_tree().process_frame
 await get_tree().process_frame
 var old_hero:=visible_sprites(maze.capture_flow.skill_visual,HERO_TEXTURE)
 _check(old_hero.size()==1 and is_equal_approx(old_hero[0].texture.get_width()*old_hero[0].scale.x,28.0),"特殊试玩仍为原锅铲28和无残影")
 _check(visible_sprites(water_layer(),WATER_TEXTURE).is_empty() and maze.capture_flow.skill_visual.short_trails.is_empty(),"特殊试玩不消费新水枪和新拖尾")
 sm.data[Run.KEY]=original
 maze.capture_flow.set_process(true)
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实小地图入口暂停组合战斗")
 var paused: Dictionary=state().duplicate(true)
 await get_tree().create_timer(0.2).timeout
 _check(state()==paused,"真实暂停时所有原战斗与弹体时钟冻结")
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"关闭地图恢复组合战斗")
 _check(await until_true(func(): return actor().frog_shots.is_empty(),2.0),"真实水枪命中或到达原清除条件后结束")
 await get_tree().process_frame
 _check(visible_sprites(water_layer(),WATER_TEXTURE).is_empty(),"实际结束的水枪没有残留长尾")
 _check(Run.valid(state()) and maze.capture_flow.monsters.size()==7,"显示接入后真实七怪战斗与存档状态保持合法")

func water_layer() -> Node:
 for child in maze.get_children():
  if child.get_script()!=null and child.get_script().resource_path=="res://scripts/maze/wind_frog_visual.gd": return child
 return null

func cleanup_rules() -> void:
 var original: Dictionary=state().duplicate(true)
 var sample:={"position":[900.0,450.0],"direction":[1.0,0.0],"distance":315.0}
 var run: Dictionary=original.duplicate(true)
 run.combat.actors[Boss.ID].frog_shots=[sample.duplicate(true)]
 var hp: float=run.combat.hp
 Run.Combat.Frog.advance_projectiles(run,Vector2(250,250),0.02)
 _check(run.combat.actors[Boss.ID].frog_shots.size()==1 and is_equal_approx(run.combat.actors[Boss.ID].frog_shots[0].position[0],903.8),"原水枪仍按190单位每秒推进，没有因新图改弹速")
 run=original.duplicate(true)
 var limit:=sample.duplicate(true)
 limit.distance=319.0
 run.combat.actors[Boss.ID].frog_shots=[limit]
 Run.Combat.Frog.advance_projectiles(run,Vector2(250,250),0.02)
 _check(run.combat.actors[Boss.ID].frog_shots.is_empty() and run.combat.hp==hp,"原320行程上限清除水枪，不因长尾扩大射程")
 var edge:=Vector2.ZERO
 var aim:=Vector2.RIGHT
 for i in 8:
  var direction:=Vector2.RIGHT.rotated(float(i)*TAU/8.0)
  for step in range(1,160):
   var next:=Boss.HOME+direction*float(step)*2.0
   if not Boss.water(next):
    edge=next-direction*2.0
    aim=direction
    break
  if edge!=Vector2.ZERO: break
 _check(edge!=Vector2.ZERO,"地形提供真实水岸交界对照")
 if edge!=Vector2.ZERO:
  run=original.duplicate(true)
  run.combat.actors[Boss.ID].frog_shots=[{"position":[edge.x,edge.y],"direction":[aim.x,aim.y],"distance":0.0}]
  Run.Combat.Frog.advance_projectiles(run,Vector2(250,250),0.02)
  _check(run.combat.actors[Boss.ID].frog_shots.is_empty() and run.combat.hp==hp,"原水岸边界清除长尾水枪，不穿岸制造伤害")
 run=original.duplicate(true)
 var near:=sample.duplicate(true)
 near.distance=0.0
 run.combat.actors[Boss.ID].frog_shots=[near]
 Run.Combat.Frog.advance_projectiles(run,Vector2(922,450),0.02)
 var hurt: float=run.combat.hp
 _check(hurt<hp and run.combat.actors[Boss.ID].frog_shots.is_empty(),"原实际命中后扣血一次并清除水枪")
 Run.Combat.Frog.advance_projectiles(run,Vector2(922,450),0.02)
 _check(run.combat.hp==hurt,"被清除的长尾不追加第二次伤害")

func visible_sprites(layer: Node, path: String) -> Array:
 var sprites: Array=[]
 for child in layer.get_children():
  if child is Sprite2D and child.is_visible_in_tree() and child.texture!=null and child.texture.resource_path==path: sprites.append(child)
 return sprites
